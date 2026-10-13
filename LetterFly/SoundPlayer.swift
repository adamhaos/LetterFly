import AVFoundation

/// Plays short sound effects synthesized at launch, so the app ships no audio files.
/// Uses the ambient session category: it honors the silent switch and mixes with
/// the player's own music.
final class SoundPlayer {
    enum Effect: CaseIterable {
        case accept, themeWord, reject, shuffle, tick, levelPassed, levelFailed
    }

    static let shared = SoundPlayer()

    var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    private let defaults = UserDefaults.standard
    private let enabledKey = "sound.enabled"
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var effects: [Effect: AVAudioPCMBuffer] = [:]
    private var selectNotes: [AVAudioPCMBuffer] = []

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        for effect in Effect.allCases { effects[effect] = render(Self.tones(for: effect)) }
        // A rising pentatonic run, one step per selected letter.
        selectNotes = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21].map { step in
            render([Tone(note: 72 + step, start: 0, duration: 0.07, volume: 0.22, wave: .triangle)])
        }
    }

    func play(_ effect: Effect) {
        guard let buffer = effects[effect] else { return }
        schedule(buffer)
    }

    /// Plays the letter-selection blip, pitched up for each letter already in the word.
    func playSelect(letterIndex: Int) {
        guard !selectNotes.isEmpty else { return }
        schedule(selectNotes[min(max(letterIndex, 0), selectNotes.count - 1)])
    }

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled else { return }
        if !engine.isRunning {
            // The engine stops on interruptions such as phone calls; restart lazily.
            do { try engine.start() } catch { return }
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    // MARK: - Synthesis

    private enum Wave { case sine, triangle, square, noise }

    private struct Tone {
        /// MIDI note number; 69 is A4.
        var note: Int
        var start: Double
        var duration: Double
        var volume: Float
        var wave: Wave
        /// Semitones to glide over the tone's duration.
        var glide: Double = 0
    }

    private static func tones(for effect: Effect) -> [Tone] {
        switch effect {
        case .accept:
            [72, 76, 79, 84].enumerated().map { index, note in
                Tone(note: note, start: Double(index) * 0.055, duration: 0.18, volume: 0.22, wave: .triangle)
            }
        case .themeWord:
            [72, 76, 79, 84, 88, 91].enumerated().map { index, note in
                Tone(note: note, start: Double(index) * 0.05, duration: 0.24, volume: 0.2, wave: .triangle)
            } + [Tone(note: 96, start: 0.3, duration: 0.35, volume: 0.1, wave: .sine)]
        case .reject:
            [Tone(note: 50, start: 0, duration: 0.12, volume: 0.12, wave: .square),
             Tone(note: 45, start: 0.11, duration: 0.2, volume: 0.12, wave: .square, glide: -3)]
        case .shuffle:
            [Tone(note: 0, start: 0, duration: 0.2, volume: 0.16, wave: .noise),
             Tone(note: 67, start: 0, duration: 0.2, volume: 0.1, wave: .sine, glide: 12)]
        case .tick:
            [Tone(note: 95, start: 0, duration: 0.035, volume: 0.18, wave: .sine)]
        case .levelPassed:
            [(67, 0.0), (72, 0.12), (76, 0.24), (79, 0.36)].map { note, start in
                Tone(note: note, start: start, duration: 0.16, volume: 0.22, wave: .triangle)
            } + [Tone(note: 84, start: 0.5, duration: 0.6, volume: 0.24, wave: .triangle),
                 Tone(note: 76, start: 0.5, duration: 0.6, volume: 0.12, wave: .sine)]
        case .levelFailed:
            [(67, 0.0), (64, 0.2), (60, 0.4)].map { note, start in
                Tone(note: note, start: start, duration: 0.24, volume: 0.2, wave: .triangle)
            } + [Tone(note: 55, start: 0.62, duration: 0.5, volume: 0.2, wave: .triangle, glide: -1)]
        }
    }

    private func render(_ tones: [Tone]) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let length = (tones.map { $0.start + $0.duration }.max() ?? 0) + 0.02
        let frameCount = AVAudioFrameCount(length * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) { samples[frame] = 0 }

        for tone in tones {
            let firstFrame = Int(tone.start * sampleRate)
            let toneFrames = Int(tone.duration * sampleRate)
            var phase = 0.0
            var noiseLevel: Float = 0
            for offset in 0..<toneFrames {
                let frame = firstFrame + offset
                guard frame < Int(frameCount) else { break }
                let progress = Double(offset) / Double(toneFrames)
                let note = Double(tone.note) + tone.glide * progress
                phase += 440 * pow(2, (note - 69) / 12) / sampleRate
                phase -= phase.rounded(.down)

                let value: Float
                switch tone.wave {
                case .sine: value = Float(sin(2 * .pi * phase))
                case .triangle: value = Float(4 * abs(phase - 0.5) - 1)
                case .square: value = phase < 0.5 ? 0.6 : -0.6
                case .noise:
                    // One-pole low-pass keeps the hiss soft.
                    noiseLevel += (Float.random(in: -1...1) - noiseLevel) * 0.25
                    value = noiseLevel
                }
                // 5 ms attack, then an exponential decay to silence.
                let attack = min(1, Double(offset) / (0.005 * sampleRate))
                let decay = exp(-4 * progress) * (1 - progress)
                samples[frame] += value * tone.volume * Float(attack * decay)
            }
        }
        return buffer
    }
}
