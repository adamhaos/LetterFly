import SpriteKit
import UIKit

final class GameScene: SKScene {
    enum Screen { case menu, playing, finished }
    enum Mode { case playthrough, freePlay }

    enum Palette {
        static let ink = SKColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 1)
        static let cream = SKColor(red: 0.98, green: 0.95, blue: 0.86, alpha: 1)
        static let paper = SKColor(red: 1.00, green: 0.99, blue: 0.95, alpha: 1)
        static let coral = SKColor(red: 0.94, green: 0.31, blue: 0.25, alpha: 1)
        static let gold = SKColor(red: 0.98, green: 0.72, blue: 0.24, alpha: 1)
        static let teal = SKColor(red: 0.12, green: 0.58, blue: 0.54, alpha: 1)
        static let muted = SKColor(red: 0.42, green: 0.43, blue: 0.40, alpha: 1)
        static let shadow = SKColor(red: 0.10, green: 0.13, blue: 0.18, alpha: 0.15)
        static let border = SKColor(red: 0.84, green: 0.79, blue: 0.67, alpha: 1)
        /// Bonus letters, bright enough to read on every world's backdrop.
        static let bonusLetter = SKColor(red: 1.00, green: 0.36, blue: 0.30, alpha: 1)
        /// Lighter status colors that stay readable on the dark in-game glass.
        static let mint = SKColor(red: 0.50, green: 0.92, blue: 0.82, alpha: 1)
        static let softCoral = SKColor(red: 1.00, green: 0.56, blue: 0.50, alpha: 1)

        /// Mixes `color` toward `other` by `amount` (0–1), keeping `color`'s alpha.
        static func mix(_ color: SKColor, _ other: SKColor, _ amount: CGFloat) -> SKColor {
            var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            color.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            return SKColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                           blue: b1 + (b2 - b1) * amount, alpha: a1)
        }
    }

    /// Home-screen colors, lightly tinted by the selected world.
    struct MenuTheme {
        let card: SKColor
        let stroke: SKColor
        let chip: SKColor
        let accent: SKColor
        /// The accent darkened for text and selected states on light cards.
        let deepAccent: SKColor

        init(world: World) {
            card = Palette.mix(Palette.paper, world.accent, 0.06)
            stroke = world.accent.withAlphaComponent(0.35)
            chip = Palette.mix(Palette.cream, world.accent, 0.10)
            accent = world.accent
            deepAccent = Palette.mix(world.accent, Palette.ink, 0.35)
        }
    }

    var menuTheme: MenuTheme { MenuTheme(world: selectedWorld) }

    let game = LetterFlyGame()
    let checker = UITextChecker()
    let highScores = HighScoreStore.shared
    let progress = ProgressStore.shared
    let sound = SoundPlayer.shared
    let haptics = Haptics.shared
    let stats = StatsStore.shared

    var screen: Screen = .menu
    var mode: Mode = .playthrough
    var selectedWorld: World = .storm
    var selectedLevel = Level(world: .storm, number: 1)
    var selectedBoardSize: LetterFlyGame.BoardSize = .classic
    var selectedRoundDuration: TimeInterval = 90
    /// True when the FREE item in the level row is picked, expanding the card into Free Play options.
    var isFreePlaySelected = false

    /// The level being played, or nil during Free Play.
    var activeLevel: Level?
    var roundDuration: TimeInterval = 90
    var timeRemaining: TimeInterval = 90
    var lastUpdateTime: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var lastTickSecond = 0
    /// The score shown in the HUD, which counts up toward the real score.
    var displayedScore = 0
    /// True during the final ten seconds, when the clock pulses and the world speeds up.
    var isClockUrgent = false
    /// Seconds played this round (pauses excluded); drives Endless drops and boss twists.
    var roundElapsed: TimeInterval = 0
    var nextEventAt: TimeInterval = 0
    /// When each uncovered letter was first exposed, for the Volcano boss's lava.
    var exposedSince: [Int: TimeInterval] = [:]
    var statusMessage = ""
    var statusColor = Palette.muted
    var statusExpiresAt: TimeInterval = 0
    var isAnimatingFeedback = false
    var isConfirmingExit = false
    /// A popup card shown over the home screen.
    enum MenuOverlay { case rules, settings, stats, confirmReset }
    var menuOverlay: MenuOverlay?
    static let tutorialKey = "tutorial.done"
    /// The current tutorial step, or nil when no tutorial is running.
    var tutorialStep: TutorialStep?
    /// Where the goal bar was last drawn, so the tutorial can point at it.
    var goalBarCenter: CGPoint?
    var hasAnnouncedGoal = false
    /// Set for the render right after the goal is reached, so the finish bar slides in once.
    var animateGoalBar = false
    /// Varies each round's loose letter layout.
    var layoutSeed = 0
    var earnedNewHighScore = false
    var passedLevel = false
    var unlockedWorld: World?
    var earnedStar = false
    var isNewStar = false
    /// Set when this round's star was the last one the world needed.
    var masteredWorld = false
    /// Set when this round beat the world's last level and opened its Free Play.
    var unlockedFreePlay = false

    /// Holds the world backdrops. It survives re-renders so animations run smoothly
    /// and an outgoing backdrop can fade out under the incoming one.
    let backdrop = SKNode()
    /// Transient animations (the hint bug) that must survive re-renders mid-flight.
    let overlay = SKNode()
    /// Letters mid-flight: hidden in the word bar (by tile id) or in the pile until their copy lands.
    var hiddenInWord: Set<Int> = []
    var hiddenInPile: Set<Int> = []
    /// The board area from the last render, used to park the hint bug clear of letters.
    var pileArea: CGRect = .zero
    var cachedPileLayout: (key: String, bases: [CGPoint], side: CGFloat)?
    var backgroundLayer: SKNode?
    var backgroundKey = ""
    var lastRenderedScreen: Screen?
    weak var pressedNode: SKNode?
    /// Live mini backdrops for the world tiles, kept between redraws so they animate smoothly.
    var worldPreviews: [World: SKCropNode] = [:]
    var lastDarkMode: Bool?

    override func didMove(to view: SKView) {
        backgroundColor = Palette.cream
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backdrop.zPosition = -100
        if backdrop.parent == nil { addChild(backdrop) }
        overlay.zPosition = 90
        if overlay.parent == nil { addChild(overlay) }
        selectedLevel = progress.nextLevel(in: selectedWorld)
        render()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard view != nil else { return }
        render()
    }

    override func update(_ currentTime: TimeInterval) {
        self.currentTime = currentTime
        // Follow the phone's light/dark setting on the home screen.
        if screen == .menu, let dark = view.map({ $0.traitCollection.userInterfaceStyle == .dark }), dark != lastDarkMode {
            lastDarkMode = dark
            render()
        }
        // The clock waits while paused or while the tutorial is explaining things.
        guard screen == .playing, !isConfirmingExit, tutorialStep == nil else {
            lastUpdateTime = currentTime
            return
        }
        let delta = lastUpdateTime > 0 ? min(currentTime - lastUpdateTime, 0.25) : 0
        lastUpdateTime = currentTime
        roundElapsed += delta
        updateTwists()
        guard screen == .playing else { return }
        if game.isEndless {
            updateEndless()
            updateClockLabel()
            return
        }
        timeRemaining = max(0, timeRemaining - delta)
        if timeRemaining == 0 {
            finishRound(message: "Time's up")
            return
        }
        updateClockLabel()
        setClockUrgent(timeRemaining <= 10)
        let second = Int(timeRemaining.rounded(.up))
        if second <= 10, second != lastTickSecond {
            lastTickSecond = second
            sound.play(.tick)
            haptics.clockTick(secondsLeft: second)
            pulseClock()
        }
        if statusExpiresAt > 0, currentTime >= statusExpiresAt {
            statusMessage = ""
            statusExpiresAt = 0
            updateStatusLabel()
        }
    }

    /// Squashes a button (or lifts a letter) under the finger so taps feel physical.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimatingFeedback, let point = touches.first?.location(in: self) else { return }
        let modalActions: Set<String> = ["action-resume", "action-exit-confirm", "action-restart", "action-pause-sound"]
        let targets = nodes(at: point).filter { node in
            guard let name = node.name, name.hasPrefix("action-") || name.hasPrefix("tile-") else { return false }
            if isConfirmingExit && !modalActions.contains(name) { return false }
            if menuOverlay != nil && !Self.isOverlayAction(name) { return false }
            return node.parent?.name != name // the control itself, not its labels
        }
        guard let node = targets.max(by: { $0.zPosition < $1.zPosition }) else { return }
        pressedNode = node
        node.removeAction(forKey: "pulse")
        let pressedScale: CGFloat = node.name?.hasPrefix("tile-") == true ? 1.12 : 0.94
        node.run(.scale(to: pressedScale, duration: 0.06), withKey: "press")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releasePress()
    }

    func releasePress() {
        pressedNode?.run(.scale(to: 1, duration: 0.08), withKey: "press")
        pressedNode = nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releasePress()
        guard !isAnimatingFeedback else { return }
        guard let point = touches.first?.location(in: self) else { return }
        let names = nodes(at: point).compactMap(\.name)
        if isConfirmingExit {
            if names.contains("action-exit-confirm") { showMenu() }
            else if names.contains("action-restart") { replayRound() }
            else if names.contains("action-pause-sound") {
                sound.isEnabled.toggle()
                haptics.select()
                render()
            }
            // NO, or any tap outside the dialog, goes back to the round.
            else if names.contains("action-resume") || !names.contains("exit-card") { dismissExitConfirmation() }
            return
        }
        if tutorialStep != nil && screen == .playing && !isConfirmingExit && tutorialWaitsForTap {
            advanceTutorial()
            return
        }
        if let overlay = menuOverlay {
            // The close button, or any tap outside the card, dismisses the popup.
            if names.contains("action-overlay-close") || !names.contains("overlay-card") {
                setOverlay(overlay == .confirmReset ? .settings : nil)
            } else if let action = names.first(where: Self.isOverlayAction) {
                handleOverlayAction(action)
            }
            return
        }
        if let id = names.lazy.compactMap({ Self.number(in: $0, after: "tile-") }).first {
            handleTile(id: id)
            return
        }
        guard let action = names.first(where: { $0.hasPrefix("action-") }) else { return }
        switch action {
        case "action-play":
            mode = .playthrough
            startRound()
        case "action-free-play": startFreePlay()
        case "action-free-select": selectFreePlay()
        case "action-again": replayRound()
        case "action-next": startNextLevel()
        case "action-submit": submitWord()
        case "action-undo": undoLetter()
        case "action-clear": clearWord()
        case "action-shuffle": shuffleAvailableTiles()
        case "action-hint": showHint()
        case "action-home": showMenu()
        case "action-exit": presentExitConfirmation()
        case "action-logo":
            if let logo = nodes(at: point).first(where: { $0.name == "action-logo" })?.parent { flyAcross(logo) }
        case "action-finish": finishEarly()
        case "action-rules": setOverlay(.rules)
        case "action-settings": setOverlay(.settings)
        case "action-stats": setOverlay(.stats)
        default:
            if let rows = Self.number(in: action, after: "action-board-"),
               let board = LetterFlyGame.BoardSize(rawValue: rows) {
                chooseBoard(board)
            } else if let seconds = Self.number(in: action, after: "action-time-") {
                chooseDuration(TimeInterval(seconds))
            } else if let index = Self.number(in: action, after: "action-world-"),
                      let world = World(rawValue: index) {
                chooseWorld(world)
            } else if let number = Self.number(in: action, after: "action-level-") {
                chooseLevel(number)
            }
        }
    }

    /// Parses node names like "tile-12" or "action-time-90".
    static func number(in name: String, after prefix: String) -> Int? {
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    /// Shuffles the uncovered letters, flying each one to its new spot.
    func shuffleAvailableTiles() {
        guard screen == .playing, !isConfirmingExit else { return }
        // Remember where every uncovered letter sits before they swap.
        var starts: [Int: (CGPoint, CGFloat)] = [:]
        for id in game.exposedTileIDs.compactMap({ $0 }) {
            if let node = nodeNamed("tile-\(id)") { starts[id] = (node.position, node.zRotation) }
        }
        let moves = game.shuffleExposedLetters()
        moves.forEach { hiddenInPile.insert($0.to) }
        showStatus("Tiles shuffled", color: Palette.teal)
        sound.play(.shuffle)
        haptics.tap(.light)
        render()
        for (index, move) in moves.enumerated() {
            guard let start = starts[move.from], let target = nodeNamed("tile-\(move.to)"),
                  let tile = game.stacks.flatMap({ $0 }).first(where: { $0.id == move.to }) else {
                hiddenInPile.remove(move.to)
                nodeNamed("tile-\(move.to)")?.alpha = 1
                continue
            }
            flyLetter(tile, from: start.0, rotation: start.1, scale: 1, to: target.position,
                      endRotation: target.zRotation, endScale: 1, delay: Double(index) * 0.025,
                      duration: 0.38, arc: true) { [weak self] in
                self?.hiddenInPile.remove(move.to)
                self?.nodeNamed("tile-\(move.to)")?.alpha = 1
            }
        }
    }

    /// Thumps the clock label once per second in the final ten seconds.
    func pulseClock() {
        guard timeRemaining <= 10, let label = nodeNamed("clock-label") else { return }
        label.run(.sequence([.scale(to: 1.35, duration: 0.08), .scale(to: 1, duration: 0.22)]), withKey: "pulse")
    }

    /// Speeds up the world's background animation when time is nearly out.
    func setClockUrgent(_ urgent: Bool) {
        guard urgent != isClockUrgent else { return }
        isClockUrgent = urgent
        backgroundLayer?.run(.speed(to: urgent ? 2.4 : 1, duration: 0.6))
    }

    /// Ticks the HUD score up to the real score.
    func countUpScore() {
        let from = displayedScore
        let to = game.score
        guard to != from else { return }
        displayedScore = to
        let duration = min(0.9, 0.25 + Double(abs(to - from)) / 400)
        removeAction(forKey: "score-count")
        run(.customAction(withDuration: duration) { [weak self] _, elapsed in
            guard let label = self?.nodeNamed("score-label") as? SKLabelNode else { return }
            let t = min(1, elapsed / CGFloat(duration))
            let eased = 1 - pow(1 - t, 3)
            label.text = "\(from + Int((CGFloat(to - from) * eased).rounded()))"
            label.setScale(1 + 0.18 * sin(.pi * t))
        }, withKey: "score-count")
    }

    // MARK: - Live labels

    var clockText: String {
        // Endless counts up instead of down.
        let seconds = game.isEndless ? Int(roundElapsed) : max(0, Int(timeRemaining.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func updateClockLabel() {
        guard let label = nodeNamed("clock-label") as? SKLabelNode else { return }
        label.text = clockText
        label.fontColor = clockColor
    }

    func updateStatusLabel() {
        guard let label = nodeNamed("status-label") as? SKLabelNode else { return }
        label.text = statusMessage
        label.fontColor = onGlass(statusColor)
    }

    func nodeNamed(_ name: String) -> SKNode? { childNode(withName: "//\(name)") }

    func fittedFontSize(for text: String, max: CGFloat, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return max }
        return min(max, width / (CGFloat(text.count) * 0.62))
    }
}

/// Deterministic SplitMix64, so a round's scattered layout is stable across re-renders.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
