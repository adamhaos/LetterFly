import SpriteKit
import UIKit

// Myth trials in play: applying each word to the trial, keeping the pile stocked,
// trial hints, and the trial's banner, progress bar and legend card.
extension GameScene {
    /// Myth piles are topped up as they're used, so a trial is lost only to the clock.
    static let mythRefillBelow = 50

    static let threadColors: [SKColor] = [
        SKColor(red: 0.48, green: 0.78, blue: 1.00, alpha: 1),
        SKColor(red: 1.00, green: 0.82, blue: 0.36, alpha: 1),
        SKColor(red: 1.00, green: 0.52, blue: 0.68, alpha: 1),
    ]

    /// The color a letter is drawn in: trial colors first, then wild and bonus letters.
    func letterColor(for tile: LetterFlyGame.Tile) -> SKColor {
        if let thread = tile.thread, trial?.kind == .fates { return Self.threadColors[thread] }
        if tile.isGold { return Palette.gold }
        return tile.isWild ? Palette.gold : (tile.isBonus ? Palette.bonusLetter : .white)
    }

    // MARK: Turns

    /// Gets the pile ready for the next word: a fresh riddle, or the Hydra's last head.
    func prepareTrialTurn() {
        guard var trial else { return }
        if trial.kind == .sphinx {
            trial.chooseRiddle(in: game)
            // The answer is always somewhere among the uncovered letters.
            if let answer = trial.riddleAnswer, game.surface(oneOf: [answer]) == nil { game.plant(answer) }
        }
        if trial.needsMythWord,
           game.surface(oneOf: game.roundWords.filter { !game.usedWords.contains($0.lowercased()) }) == nil {
            // No myth word is left to spell, so the last head can't demand one.
            trial.allowAnyBurial()
        }
        self.trial = trial
    }

    /// Counts a played word toward the trial and applies its immediate effects.
    func recordTrialWord(_ result: LetterFlyGame.Submission, tiles: [LetterFlyGame.Tile], lanes: [Int]) {
        guard var trial else { return }
        // Star words are fair game in every trial: the Sphinx doesn't count them as wrong answers.
        let upper = result.word.uppercased()
        let isStarWord = activeLevel?.starWords.contains(upper) ?? false
        // Any word from the myth list counts as a myth word (the Hydra's last head accepts all of them).
        let isMythWord = result.isThemeWord || World.mythWords.contains(upper)
        let isThemeWord = trial.kind == .sphinx ? isMythWord && !isStarWord : isMythWord
        var outcome = trial.record(word: result.word, tiles: tiles, isThemeWord: isThemeWord)
        self.trial = trial
        if outcome.gildUncovered { game.gildExposed(inLanes: lanes) }
        if outcome.timePenalty > 0 {
            timeRemaining = max(0, timeRemaining - outcome.timePenalty)
            pulseClock()
        }
        // Remember how many letters to put back once the word's animation is done.
        if game.remainingTileCount < Self.mythRefillBelow { outcome.growLetters += tiles.count }
        pendingOutcome = outcome
        statusMessage = outcome.message
        statusColor = outcome.good ? (trial.isComplete ? Palette.gold : Palette.teal) : Palette.coral
        statusExpiresAt = 0
        if !outcome.good { haptics.warning() }
    }

    /// Runs after a word's animation: ends the trial if it's won or lost, otherwise grows
    /// or refills the pile and readies the next turn.
    func finishTrialTurn() {
        guard let trial else { return }
        let outcome = pendingOutcome
        pendingOutcome = nil
        if trial.isComplete {
            // Leftover seconds still count for something.
            game.score += Int(timeRemaining.rounded(.down)) * 5
            finishRound(message: outcome?.message ?? "Trial complete!")
            return
        }
        if trial.isFailed {
            finishRound(message: "The Hydra overwhelms you!")
            return
        }
        var dropped: [Int] = []
        for _ in 0..<(outcome?.growLetters ?? 0) {
            dropped.append(game.dropLetter(thread: trial.kind == .fates ? Int.random(in: 0..<3) : nil).tile.id)
        }
        prepareTrialTurn()
        if game.remainingTileCount < 3 || game.prepareNextMove() == .none {
            finishRound(message: "No words left!")
            return
        }
        render()
        countUpScore()
        animateDrops(dropped)
    }

    // MARK: Hints

    /// Words the uncovered letters can spell right now, from the system dictionary.
    func spellableWords() -> [String] {
        let letters = game.availableLetters
        let pool = Set(letters.map { String($0).lowercased() })
        var found = Set<String>()
        for first in pool {
            for second in pool {
                let prefix = first + second
                let completions = checker.completions(forPartialWordRange: NSRange(location: 0, length: 2),
                                                      in: prefix, language: "en_US") ?? []
                for word in completions where (3...8).contains(word.count) && word.allSatisfy(\.isLowercase)
                    && !game.usedWords.contains(word) && game.canSpell(word, from: letters) {
                    found.insert(word)
                }
            }
        }
        return found.sorted()
    }

    /// The bug flies in with a word that moves the trial forward.
    func showTrialHint() {
        guard let trial else { return }
        if trial.kind == .sphinx, let answer = trial.riddleAnswer {
            flyInHintBug(saying: masked(answer))
            return
        }
        if trial.needsMythWord, let word = game.bestAvailableRoundWord() {
            flyInHintBug(saying: masked(word))
            return
        }
        let words = spellableWords()
        let exposed = game.exposedTileIDs.compactMap { $0 }
            .compactMap { id in game.stacks.flatMap { $0 }.first { $0.id == id } }
        func letters(matching keep: (LetterFlyGame.Tile) -> Bool) -> [Character] { exposed.filter(keep).map(\.letter) }
        func overlap(_ word: String, with pool: [Character]) -> Int {
            var pool = pool
            return word.uppercased().reduce(0) { count, letter in
                guard let index = pool.firstIndex(of: letter) else { return count }
                pool.remove(at: index)
                return count + 1
            }
        }
        let pick: String?
        switch trial.kind {
        case .icarus:
            pick = words.filter { $0.count == trial.requiredLength }.randomElement()
        case .ouroboros:
            let start = trial.chainLetter.map { String($0).lowercased() }
            let linking = words.filter { start == nil || $0.hasPrefix(start!) }
            pick = linking.filter { (4...6).contains($0.count) }.randomElement() ?? linking.randomElement()
        case .midas:
            let gold = letters { $0.isGold }
            pick = words.max { overlap($0, with: gold) < overlap($1, with: gold) }
        case .fates:
            let threads = letters { $0.thread == trial.fate }
            pick = words.filter { overlap($0, with: threads) >= 2 }.max { $0.count < $1.count }
        case .hydra:
            pick = words.filter { $0.count >= 5 }.randomElement()
        case .sphinx:
            pick = nil
        }
        if let pick {
            flyInHintBug(saying: masked(pick.uppercased()))
        } else {
            flyInHintBug(saying: "Try MIX to shake things up!")
        }
    }

    private func masked(_ word: String) -> String {
        guard let first = word.first, let last = word.last else { return word }
        let dots = String(repeating: "•", count: max(0, word.count - 2)).map(String.init).joined(separator: " ")
        return "Try  \(first) \(dots) \(last)"
    }

    // MARK: Drawing

    /// A glass strip under the HUD with the trial's next step (or the Sphinx's riddle).
    func drawTrialBanner(in rect: CGRect) {
        guard let trial else { return }
        let world = game.world
        let banner = roundedRect(size: rect.size, radius: 14, fill: world.glass, stroke: world.accentLight.withAlphaComponent(0.3))
        banner.position = CGPoint(x: rect.midX, y: rect.midY)
        banner.zPosition = 1
        addChild(banner)
        if let icon = makeSymbol(trial.kind.symbol, pointSize: 15, color: world.accentLight) {
            icon.position = CGPoint(x: rect.minX + 20, y: rect.midY)
            icon.zPosition = 2
            addChild(icon)
        }
        let label = SKLabelNode(fontNamed: trial.kind == .sphinx ? "AvenirNext-DemiBoldItalic" : "AvenirNext-Bold")
        label.text = trial.objective
        label.fontSize = 13
        label.fontColor = .white
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = rect.width - 52
        label.lineBreakMode = .byWordWrapping
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: rect.minX + 38, y: rect.midY)
        label.zPosition = 2
        label.name = "trial-banner"
        addChild(label)
    }

    /// The trial's progress in the slot between SUBMIT and HINT.
    func drawTrialBar(center: CGPoint, width: CGFloat) {
        guard let trial else { return }
        let world = game.world
        let trackWidth = min(width, 260)
        let track = roundedRect(size: CGSize(width: trackWidth, height: 8), radius: 4, fill: world.glass, stroke: Self.glassEdge)
        track.position = CGPoint(x: center.x, y: center.y - 8)
        track.zPosition = 2
        addChild(track)
        if trial.fraction > 0 {
            let fillWidth = max(8, trackWidth * trial.fraction)
            let fill = roundedRect(size: CGSize(width: fillWidth, height: 8), radius: 4,
                                   fill: trial.kind == .fates ? Self.threadColors[trial.fate] : world.accentLight, stroke: .clear)
            fill.position = CGPoint(x: center.x - trackWidth / 2 + fillWidth / 2, y: center.y - 8)
            fill.zPosition = 3
            addChild(fill)
        }
        let progressText: String
        switch trial.kind {
        case .icarus: progressText = "CLIMBS \(trial.progress)/\(trial.kind.goal)"
        case .ouroboros: progressText = "CHAIN \(trial.progress)/\(trial.kind.goal)"
        case .sphinx: progressText = "RIDDLES \(trial.progress)/\(trial.kind.goal)"
        case .midas: progressText = "GOLD \(min(trial.progress, trial.kind.goal))/\(trial.kind.goal)"
        case .fates: progressText = "\(MythTrial.fateNames[trial.fate].uppercased()) \(trial.fateOfferings)/\(trial.offeringsPerFate)"
        case .hydra: progressText = "HEADS \(trial.heads)  •  MAX \(MythTrial.hydraMaxHeads)"
        }
        addLabel(progressText, font: "AvenirNext-Heavy", size: 11, color: Self.glassSubtext,
                 at: CGPoint(x: center.x, y: center.y + 8), alignment: .center, z: 3)
    }

    /// The legend card that opens each trial. The clock waits until it's tapped away.
    func drawTrialIntro() {
        guard let trial, isShowingTrialIntro else { return }
        let safe = safeFrame
        let world = game.world
        let dimmer = SKShapeNode(rect: frame)
        dimmer.fillColor = Palette.ink.withAlphaComponent(0.7)
        dimmer.strokeColor = .clear
        dimmer.zPosition = 100
        addChild(dimmer)

        let width = min(350, safe.width - 40)
        let textWidth = width - 48
        func measure(_ text: String, font: String, size: CGFloat) -> CGFloat {
            let uiFont = UIFont(name: font, size: size) ?? .systemFont(ofSize: size)
            return ceil((text as NSString).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                                                        options: .usesLineFragmentOrigin, attributes: [.font: uiFont],
                                                        context: nil).height)
        }
        let legendHeight = measure(trial.kind.legend, font: "AvenirNext-MediumItalic", size: 14)
        let ruleHeight = measure(trial.kind.rule, font: "AvenirNext-DemiBold", size: 14)
        let height = 150 + legendHeight + ruleHeight + 60
        let card = roundedRect(size: CGSize(width: width, height: height), radius: 26,
                               fill: Palette.mix(world.glass, Palette.ink, 0.3).withAlphaComponent(0.96),
                               stroke: world.accent.withAlphaComponent(0.7))
        card.lineWidth = 2
        card.position = CGPoint(x: safe.midX, y: safe.midY)
        card.zPosition = 101
        addChild(card)

        var y = height / 2 - 44
        if let icon = makeSymbol(trial.kind.symbol, pointSize: 34, color: world.accentLight) {
            icon.position = CGPoint(x: 0, y: y)
            icon.zPosition = 2
            card.addChild(icon)
            icon.run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.8), .scale(to: 1, duration: 0.8)])))
        }
        y -= 46
        let level = activeLevel?.number ?? 1
        let kicker = makeLabel("TRIAL \(level) OF \(Level.countPerWorld)", font: "AvenirNext-Bold", size: 11,
                               color: world.accent)
        kicker.position = CGPoint(x: 0, y: y + 14)
        kicker.zPosition = 2
        card.addChild(kicker)
        let title = makeLabel(trial.kind.title.uppercased(), font: "AvenirNext-Heavy", size: 22, color: Palette.cream)
        title.fontSize = fittedFontSize(for: title.text ?? "", max: 22, width: textWidth)
        title.position = CGPoint(x: 0, y: y - 8)
        title.zPosition = 2
        card.addChild(title)
        y -= 34
        for (text, font, color, textHeight) in [
            (trial.kind.legend, "AvenirNext-MediumItalic", SKColor(white: 1, alpha: 0.72), legendHeight),
            (trial.kind.rule, "AvenirNext-DemiBold", world.accentLight, ruleHeight),
        ] {
            let body = SKLabelNode(fontNamed: font)
            body.text = text
            body.fontSize = 14
            body.fontColor = color
            body.numberOfLines = 0
            body.preferredMaxLayoutWidth = textWidth
            body.lineBreakMode = .byWordWrapping
            body.horizontalAlignmentMode = .center
            body.verticalAlignmentMode = .top
            body.position = CGPoint(x: 0, y: y)
            body.zPosition = 2
            card.addChild(body)
            y -= textHeight + 18
        }
        let begin = makeLabel("TAP TO BEGIN", font: "AvenirNext-Heavy", size: 13, color: Palette.cream)
        begin.position = CGPoint(x: 0, y: -height / 2 + 30)
        begin.zPosition = 2
        card.addChild(begin)
        begin.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
    }
}
