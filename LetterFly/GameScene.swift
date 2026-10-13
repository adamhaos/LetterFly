import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum Screen { case menu, playing, finished }
    private enum Mode { case playthrough, scoreAttack }

    private enum Palette {
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
    }

    private let game = LetterFlyGame()
    private let checker = UITextChecker()
    private let highScores = HighScoreStore.shared
    private let progress = ProgressStore.shared
    private let sound = SoundPlayer.shared

    private var screen: Screen = .menu
    private var mode: Mode = .playthrough
    private var selectedWorld: World = .storm
    private var selectedLevel = Level(world: .storm, number: 1)
    private var selectedBoardSize: LetterFlyGame.BoardSize = .classic
    private var selectedRoundDuration: TimeInterval = 90

    /// The level being played, or nil during Score Attack.
    private var activeLevel: Level?
    private var roundDuration: TimeInterval = 90
    private var timeRemaining: TimeInterval = 90
    private var lastUpdateTime: TimeInterval = 0
    private var currentTime: TimeInterval = 0
    private var lastTickSecond = 0
    private var statusMessage = ""
    private var statusColor = Palette.muted
    private var statusExpiresAt: TimeInterval = 0
    private var hintWord: String?
    private var isAnimatingFeedback = false
    private var isConfirmingExit = false
    private var hasAnnouncedGoal = false
    /// Varies each round's loose letter layout.
    private var layoutSeed = 0
    private var earnedNewHighScore = false
    private var passedLevel = false
    private var unlockedWorld: World?

    private var backgroundLayer: SKNode?
    private var backgroundKey = ""

    override func didMove(to view: SKView) {
        backgroundColor = Palette.cream
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
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
        guard screen == .playing, !isConfirmingExit else {
            lastUpdateTime = currentTime
            return
        }
        if lastUpdateTime > 0 { timeRemaining = max(0, timeRemaining - (currentTime - lastUpdateTime)) }
        lastUpdateTime = currentTime
        if timeRemaining == 0 {
            finishRound(message: "Time's up")
            return
        }
        updateClockLabel()
        let second = Int(timeRemaining.rounded(.up))
        if second <= 10, second != lastTickSecond {
            lastTickSecond = second
            sound.play(.tick)
        }
        if statusExpiresAt > 0, currentTime >= statusExpiresAt {
            statusMessage = ""
            statusExpiresAt = 0
            updateStatusLabel()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimatingFeedback else { return }
        guard let point = touches.first?.location(in: self) else { return }
        let names = nodes(at: point).compactMap(\.name)
        if isConfirmingExit {
            if names.contains("action-resume") { dismissExitConfirmation() }
            if names.contains("action-exit-confirm") { showMenu() }
            return
        }
        if let id = names.lazy.compactMap({ Self.number(in: $0, after: "tile-") }).first {
            handleTile(id: id)
            return
        }
        guard let action = names.first(where: { $0.hasPrefix("action-") }) else { return }
        switch action {
        case "action-play": startRound()
        case "action-again": replayRound()
        case "action-next": startNextLevel()
        case "action-submit": submitWord()
        case "action-undo": undoLetter()
        case "action-clear": clearWord()
        case "action-shuffle": shuffleAvailableTiles()
        case "action-hint": showHint()
        case "action-home": showMenu()
        case "action-exit": presentExitConfirmation()
        case "action-sound": toggleSound()
        case "action-mode-playthrough": chooseMode(.playthrough)
        case "action-mode-score": chooseMode(.scoreAttack)
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
    private static func number(in name: String, after prefix: String) -> Int? {
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    func shuffleAvailableTiles() {
        guard screen == .playing, !isConfirmingExit else { return }
        game.shuffleExposedLetters()
        hintWord = nil
        showStatus("Tiles shuffled", color: Palette.teal)
        sound.play(.shuffle)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        render()
    }

    // MARK: - Menu choices

    private func chooseMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        UISelectionFeedbackGenerator().selectionChanged()
        render()
    }

    private func chooseWorld(_ world: World) {
        guard progress.isUnlocked(world) else {
            let previous = world.previous?.title ?? ""
            flashMenuNote("Beat \(Level.countToUnlockNext) \(previous) levels to unlock \(world.title)")
            return
        }
        selectedWorld = world
        selectedLevel = progress.nextLevel(in: world)
        UISelectionFeedbackGenerator().selectionChanged()
        render()
    }

    private func chooseLevel(_ number: Int) {
        let level = Level(world: selectedWorld, number: number)
        guard progress.isPlayable(level) else {
            flashMenuNote("Beat level \(number - 1) first")
            return
        }
        selectedLevel = level
        UISelectionFeedbackGenerator().selectionChanged()
        render()
    }

    private func chooseBoard(_ boardSize: LetterFlyGame.BoardSize) {
        selectedBoardSize = boardSize
        UISelectionFeedbackGenerator().selectionChanged()
        render()
    }

    private func chooseDuration(_ duration: TimeInterval) {
        selectedRoundDuration = duration
        UISelectionFeedbackGenerator().selectionChanged()
        render()
    }

    private func toggleSound() {
        sound.isEnabled.toggle()
        UISelectionFeedbackGenerator().selectionChanged()
        render()
    }

    /// Shows a short note on the menu, e.g. when a locked world is tapped.
    private func flashMenuNote(_ text: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        nodeNamed("menu-note")?.removeFromParent()
        let note = addLabel(text, font: "AvenirNext-DemiBold", size: 12, color: Palette.coral,
                            at: CGPoint(x: safeFrame.midX, y: safeFrame.minY + 14), alignment: .center,
                            name: "menu-note", z: 50)
        note.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: - Round flow

    private func startRound() {
        let board: LetterFlyGame.BoardSize
        let world: World
        switch mode {
        case .playthrough:
            activeLevel = selectedLevel
            board = selectedLevel.boardSize
            world = selectedLevel.world
            roundDuration = selectedLevel.duration
        case .scoreAttack:
            activeLevel = nil
            board = selectedBoardSize
            world = selectedWorld
            roundDuration = selectedRoundDuration
        }
        game.startNewRound(boardSize: board, world: world)
        screen = .playing
        timeRemaining = roundDuration
        lastUpdateTime = 0
        lastTickSecond = 0
        statusMessage = activeLevel.map { "Score \($0.targetScore) to pass" } ?? "Make words with the uncovered letters"
        statusColor = Palette.muted
        statusExpiresAt = 0
        hintWord = nil
        isAnimatingFeedback = false
        isConfirmingExit = false
        hasAnnouncedGoal = false
        layoutSeed = Int.random(in: 0..<1_000_000)
        earnedNewHighScore = false
        passedLevel = false
        unlockedWorld = nil
        render()
    }

    /// The level after `activeLevel`: the next in its world, or the next world's first unbeaten level.
    private var levelAfterActive: Level? {
        guard let level = activeLevel else { return nil }
        if level.number < Level.countPerWorld { return Level(world: level.world, number: level.number + 1) }
        guard let next = level.world.next, progress.isUnlocked(next) else { return nil }
        return progress.nextLevel(in: next)
    }

    /// Plays the finished round's setup again. Passing a level already advanced the
    /// menu selection, so point it back at the level just played.
    private func replayRound() {
        if let level = activeLevel {
            selectedWorld = level.world
            selectedLevel = level
        }
        startRound()
    }

    private func startNextLevel() {
        guard let next = levelAfterActive else { return }
        selectedWorld = next.world
        selectedLevel = next
        startRound()
    }

    private func showMenu() {
        screen = .menu
        lastUpdateTime = 0
        isConfirmingExit = false
        if !progress.isPlayable(selectedLevel) { selectedLevel = progress.nextLevel(in: selectedWorld) }
        render()
    }

    private func presentExitConfirmation() {
        guard screen == .playing else { return }
        isConfirmingExit = true
        lastUpdateTime = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        render()
    }

    private func dismissExitConfirmation() {
        isConfirmingExit = false
        lastUpdateTime = 0
        render()
    }

    private func finishRound(message: String) {
        screen = .finished
        statusMessage = message
        lastUpdateTime = 0
        if let level = activeLevel {
            passedLevel = game.score >= level.targetScore
            if passedLevel {
                unlockedWorld = progress.recordPass(of: level)
                selectedLevel = levelAfterActive ?? level
                selectedWorld = selectedLevel.world
            }
            sound.play(passedLevel ? .levelPassed : .levelFailed)
            UINotificationFeedbackGenerator().notificationOccurred(passedLevel ? .success : .warning)
        } else {
            earnedNewHighScore = highScores.record(game.score, board: game.boardSize, duration: roundDuration)
            sound.play(.levelPassed)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        render()
    }

    // MARK: - Play

    private func handleTile(id: Int) {
        guard screen == .playing else { return }
        if game.selectedTileIDs.last == id {
            game.undoLastSelection()
        } else if game.selectTile(id: id) {
            sound.playSelect(letterIndex: game.selectedTileIDs.count - 1)
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            showStatus("That letter is still covered", color: Palette.coral)
        }
        render()
    }

    private func undoLetter() {
        guard game.undoLastSelection() != nil else {
            showStatus("Choose a letter first", color: Palette.muted)
            return
        }
        render()
    }

    private func clearWord() {
        guard game.clearSelection() else {
            showStatus("Choose a letter first", color: Palette.muted)
            return
        }
        hintWord = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        render()
    }

    private func submitWord() {
        let word = game.currentWord.lowercased()
        guard word.count >= 3 else { rejectWord("Words need at least 3 letters"); return }
        guard !game.usedWords.contains(word) else { rejectWord("You already found \(word.uppercased())"); return }
        guard isValidWord(word) else { rejectWord("Not in the dictionary"); return }

        let result = game.commitSelection()
        hintWord = nil
        statusMessage = result.isThemeWord
            ? "\(game.world.title.uppercased()) WORD! +\(result.points)"
            : "+\(result.points)  \(word.uppercased())"
        statusColor = result.isThemeWord ? Palette.gold : Palette.teal
        sound.play(result.isThemeWord ? .themeWord : .accept)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        animateAcceptedWord(result)
    }

    private func rejectWord(_ message: String) {
        showStatus(message, color: Palette.coral)
        sound.play(.reject)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        animateRejectedWord()
    }

    private func completeAcceptedWord() {
        isAnimatingFeedback = false
        if game.remainingTileCount < 3 {
            game.score += Int(timeRemaining.rounded(.down)) * 5
            finishRound(message: game.remainingTileCount == 0 ? "Pile cleared!" : "No words left!")
            return
        }
        if let level = activeLevel, !hasAnnouncedGoal, game.score >= level.targetScore {
            hasAnnouncedGoal = true
            showStatus("Goal reached — keep scoring!", color: Palette.teal, duration: 2.2)
        }

        switch game.prepareNextMove() {
        case .playable:
            render()
        case .remixed:
            showStatus("Stuck letters remixed — keep going!", color: Palette.teal, duration: 2.2)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            render()
        case .none:
            finishRound(message: "No words left!")
        }
    }

    private func isValidWord(_ word: String) -> Bool {
        if game.roundWords.contains(word.uppercased()) || LetterFlyGame.commonWords.contains(word) { return true }
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US").location == NSNotFound
    }

    private func showHint() {
        guard let word = game.bestAvailableRoundWord() else {
            showStatus("Keep uncovering letters", color: Palette.gold)
            return
        }
        hintWord = word
        showStatus("Try finding \(word.count) letters", color: Palette.gold)
        render()
    }

    private func showStatus(_ text: String, color: SKColor, duration: TimeInterval = 1.8) {
        statusMessage = text
        statusColor = color
        statusExpiresAt = currentTime + duration
        updateStatusLabel()
    }

    // MARK: - Feedback animations

    private func animateAcceptedWord(_ result: LetterFlyGame.Submission) {
        guard let card = nodeNamed("word-card") as? SKShapeNode,
              let wordLabel = nodeNamed("word-label") as? SKLabelNode else {
            completeAcceptedWord()
            return
        }
        isAnimatingFeedback = true
        let color = result.isThemeWord ? Palette.gold : Palette.teal
        card.fillColor = color
        card.strokeColor = color
        wordLabel.attributedText = nil
        wordLabel.text = result.word.uppercased()
        wordLabel.fontColor = result.isThemeWord ? Palette.ink : .white
        wordLabel.run(.sequence([
            .scale(to: 1.20, duration: 0.11),
            .scale(to: 0.96, duration: 0.09),
            .scale(to: 1.06, duration: 0.08),
            .scale(to: 1.00, duration: 0.08)
        ]))
        card.run(.sequence([
            .scale(to: 1.04, duration: 0.12),
            .scale(to: 0.98, duration: 0.10),
            .scale(to: 1.00, duration: 0.08)
        ]))

        let glow = SKShapeNode(rectOf: CGSize(width: card.frame.width + 14, height: card.frame.height + 14), cornerRadius: 24)
        glow.fillColor = .clear
        glow.strokeColor = color
        glow.lineWidth = 5
        glow.position = card.position
        glow.zPosition = card.zPosition - 0.2
        addChild(glow)
        glow.run(.sequence([
            .group([.scale(to: 1.18, duration: 0.45), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))

        let points = addLabel("+\(result.points)", font: "AvenirNext-Heavy", size: result.isThemeWord ? 34 : 28,
                              color: color, at: CGPoint(x: card.position.x, y: card.position.y + 52),
                              alignment: .center, z: 40)
        points.setScale(0.35)
        points.run(.sequence([
            .group([.scale(to: 1.18, duration: 0.20), .moveBy(x: 0, y: 22, duration: 0.20)]),
            .group([.scale(to: 1.00, duration: 0.12), .moveBy(x: 0, y: 14, duration: 0.12)]),
            .group([.fadeOut(withDuration: 0.32), .moveBy(x: 0, y: 30, duration: 0.32)]),
            .removeFromParent()
        ]))
        emitCelebration(from: card.position, count: result.isThemeWord ? 44 : 26)

        run(.sequence([.wait(forDuration: 0.72), .run { [weak self] in self?.completeAcceptedWord() }]))
    }

    private func emitCelebration(from origin: CGPoint, count: Int) {
        let colors = [Palette.coral, Palette.gold, Palette.teal, Palette.ink]
        for index in 0..<count {
            let particle: SKShapeNode
            if index.isMultiple(of: 3) {
                particle = SKShapeNode(rectOf: CGSize(width: 7, height: 7), cornerRadius: 2)
            } else {
                particle = SKShapeNode(circleOfRadius: 3.5)
            }
            particle.fillColor = colors[index % colors.count]
            particle.strokeColor = .clear
            particle.position = origin
            particle.zPosition = 35
            particle.zRotation = CGFloat.random(in: 0...(.pi * 2))
            addChild(particle)
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = CGFloat.random(in: 65...150)
            let destination = CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance + 28)
            particle.run(.sequence([
                .group([
                    .move(by: destination, duration: Double.random(in: 0.48...0.72)),
                    .rotate(byAngle: CGFloat.random(in: -4...4), duration: 0.65),
                    .sequence([.wait(forDuration: 0.28), .fadeOut(withDuration: 0.35)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func animateRejectedWord() {
        guard let card = nodeNamed("word-card") as? SKShapeNode,
              let wordLabel = nodeNamed("word-label") as? SKLabelNode else { return }
        isAnimatingFeedback = true
        card.fillColor = Palette.coral
        card.strokeColor = Palette.coral
        wordLabel.attributedText = nil
        wordLabel.text = game.currentWord
        wordLabel.fontColor = .white

        let flash = SKShapeNode(rect: frame)
        flash.fillColor = Palette.coral.withAlphaComponent(0.14)
        flash.strokeColor = .clear
        flash.zPosition = 30
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.28), .removeFromParent()]))

        let badge = makeCrossBadge(radius: 25)
        badge.strokeColor = .white
        badge.lineWidth = 3
        badge.position = CGPoint(x: card.position.x, y: card.position.y + 56)
        badge.zPosition = 42
        badge.setScale(0.15)
        addChild(badge)
        badge.run(.sequence([
            .scale(to: 1.15, duration: 0.13), .scale(to: 1.00, duration: 0.08),
            .wait(forDuration: 0.20),
            .group([.fadeOut(withDuration: 0.18), .scale(to: 1.35, duration: 0.18)]),
            .removeFromParent()
        ]))

        let shake = SKAction.sequence([
            .moveBy(x: -14, y: 0, duration: 0.045), .rotate(byAngle: -0.035, duration: 0.045),
            .moveBy(x: 28, y: 0, duration: 0.07), .rotate(byAngle: 0.07, duration: 0.07),
            .moveBy(x: -25, y: 0, duration: 0.065), .rotate(byAngle: -0.06, duration: 0.065),
            .moveBy(x: 20, y: 0, duration: 0.06), .rotate(byAngle: 0.045, duration: 0.06),
            .moveBy(x: -9, y: 0, duration: 0.05), .rotate(toAngle: 0, duration: 0.05)
        ])
        card.run(shake)
        wordLabel.run(.sequence([.scale(to: 0.86, duration: 0.12), .scale(to: 1.06, duration: 0.12), .scale(to: 1, duration: 0.10)]))
        run(.sequence([.wait(forDuration: 0.58), .run { [weak self] in
            self?.isAnimatingFeedback = false
            self?.render()
        }]))
    }

    // MARK: - Rendering

    private func render() {
        for child in children where child !== backgroundLayer { child.removeFromParent() }
        updateBackground()
        switch screen {
        case .menu: drawMenu()
        case .playing:
            drawGame()
            if isConfirmingExit { drawExitConfirmation() }
        case .finished: drawFinished()
        }
    }

    /// Rebuilds the backdrop only when the world or scene size changes, so its
    /// animations keep running smoothly across re-renders.
    private func updateBackground() {
        let world: World? = screen == .menu ? nil : game.world
        let key = "\(world?.rawValue ?? -1) \(Int(size.width))x\(Int(size.height))"
        guard key != backgroundKey else { return }
        backgroundLayer?.removeFromParent()
        let layer = world?.makeBackground(size: size) ?? makePaperBackground()
        addChild(layer)
        backgroundLayer = layer
        backgroundKey = key
    }

    private var safeFrame: CGRect {
        guard let view else { return frame }
        let insets = view.safeAreaInsets
        let portrait = size.height >= size.width
        let topInset = max(insets.top, portrait ? 64 : 12)
        let leftInset = max(insets.left, portrait ? 0 : 54)
        let rightInset = max(insets.right, portrait ? 0 : 54)
        return CGRect(x: frame.minX + leftInset, y: frame.minY + insets.bottom,
                      width: size.width - leftInset - rightInset,
                      height: size.height - topInset - insets.bottom)
    }

    private func makePaperBackground() -> SKNode {
        let root = SKNode()
        root.zPosition = -100
        let wash = SKShapeNode(rect: frame)
        wash.fillColor = Palette.cream
        wash.strokeColor = .clear
        root.addChild(wash)
        let spacing: CGFloat = 32
        var x = frame.minX - size.height
        while x < frame.maxX + size.height {
            let line = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: frame.minY))
            path.addLine(to: CGPoint(x: x + size.height, y: frame.maxY))
            line.path = path
            line.strokeColor = SKColor(red: 0.88, green: 0.83, blue: 0.70, alpha: 0.18)
            line.lineWidth = 1
            line.zPosition = 1
            root.addChild(line)
            x += spacing
        }
        return root
    }

    /// Lays out blocks of the given heights top to bottom, centered on `centerY`,
    /// calling each block's draw closure with its center.
    private func stack(_ blocks: [(height: CGFloat, draw: (CGFloat) -> Void)], centerY: CGFloat, gap: CGFloat) {
        let total = blocks.map(\.height).reduce(0, +) + gap * CGFloat(max(0, blocks.count - 1))
        var top = centerY + total / 2
        for block in blocks {
            block.draw(top - block.height / 2)
            top -= block.height + gap
        }
    }

    // MARK: Menu

    private func drawMenu() {
        let safe = safeFrame
        let soundIcon = sound.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
        addIconButton(systemName: soundIcon, name: "action-sound", size: CGSize(width: 44, height: 40),
                      fillColor: Palette.paper, iconColor: Palette.ink,
                      at: CGPoint(x: safe.maxX - 30, y: safe.maxY - 24))

        if safe.width > safe.height {
            drawLandscapeMenu(in: safe)
            return
        }
        let compact = safe.height < 720
        let width = min(safe.width - 32, 420)
        var blocks: [(height: CGFloat, draw: (CGFloat) -> Void)] = []
        if !compact {
            blocks.append((60, { [unowned self] y in
                let bug = makeBug(size: 60)
                bug.position = CGPoint(x: safe.midX, y: y)
                addChild(bug)
            }))
        }
        blocks.append((44, { [unowned self] y in
            addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: compact ? 40 : 46, color: Palette.ink,
                     at: CGPoint(x: safe.midX, y: y), alignment: .center)
        }))
        blocks.append((40, { [unowned self] y in
            drawModeToggle(center: CGPoint(x: safe.midX, y: y), width: min(width, 320))
        }))
        blocks.append((setupCardHeight, { [unowned self] y in
            drawSetupCard(center: CGPoint(x: safe.midX, y: y), width: width)
        }))
        blocks.append((56, { [unowned self] y in
            addButton(title: "PLAY", name: "action-play", size: CGSize(width: min(width, 300), height: 56),
                      color: Palette.coral, at: CGPoint(x: safe.midX, y: y))
        }))
        if mode == .scoreAttack {
            let height = leaderboardHeight(compact: compact)
            blocks.append((height, { [unowned self] y in
                drawLeaderboard(centerX: safe.midX, topY: y + height / 2, width: min(width, 350), compact: compact)
            }))
        } else {
            blocks.append((14, { [unowned self] y in
                addLabel("Tip: shake the phone to mix the letters", font: "AvenirNext-Medium", size: 12,
                         color: Palette.muted, at: CGPoint(x: safe.midX, y: y), alignment: .center)
            }))
        }
        stack(blocks, centerY: safe.midY - 6, gap: compact ? 12 : 18)
    }

    private func drawLandscapeMenu(in safe: CGRect) {
        let leftX = safe.minX + safe.width * 0.24
        let rightX = safe.minX + safe.width * 0.70
        let leftWidth = min(300, safe.width * 0.38)
        var blocks: [(height: CGFloat, draw: (CGFloat) -> Void)] = [
            (54, { [unowned self] y in
                let bug = makeBug(size: 50)
                bug.position = CGPoint(x: leftX, y: y)
                addChild(bug)
            }),
            (40, { [unowned self] y in
                addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: 38, color: Palette.ink,
                         at: CGPoint(x: leftX, y: y), alignment: .center)
            }),
            (38, { [unowned self] y in
                drawModeToggle(center: CGPoint(x: leftX, y: y), width: leftWidth)
            }),
            (50, { [unowned self] y in
                addButton(title: "PLAY", name: "action-play", size: CGSize(width: min(250, leftWidth), height: 50),
                          color: Palette.coral, at: CGPoint(x: leftX, y: y))
            })
        ]
        if mode == .scoreAttack {
            let height = leaderboardHeight(compact: true)
            blocks.append((height, { [unowned self] y in
                drawLeaderboard(centerX: leftX, topY: y + height / 2, width: leftWidth, compact: true)
            }))
        }
        stack(blocks, centerY: safe.midY, gap: 12)
        drawSetupCard(center: CGPoint(x: rightX, y: safe.midY), width: min(410, safe.width * 0.5))
    }

    private func drawModeToggle(center: CGPoint, width: CGFloat) {
        let height: CGFloat = 40
        let track = roundedRect(size: CGSize(width: width, height: height), radius: height / 2,
                                fill: Palette.paper, stroke: Palette.border)
        track.position = center
        track.zPosition = 2
        addChild(track)
        let options: [(Mode, String, String)] = [(.playthrough, "PLAYTHROUGH", "action-mode-playthrough"),
                                                 (.scoreAttack, "SCORE ATTACK", "action-mode-score")]
        let halfWidth = width / 2
        for (index, option) in options.enumerated() {
            let selected = mode == option.0
            let x = center.x - halfWidth / 2 + CGFloat(index) * halfWidth
            let pill = roundedRect(size: CGSize(width: halfWidth - 6, height: height - 6), radius: (height - 6) / 2,
                                   fill: selected ? Palette.ink : .clear, stroke: .clear)
            pill.position = CGPoint(x: x, y: center.y)
            pill.zPosition = 3
            pill.name = option.2
            addChild(pill)
            pill.addChild(makeLabel(option.1, font: "AvenirNext-Heavy", size: 12,
                                    color: selected ? .white : Palette.muted, name: option.2))
        }
    }

    private var setupCardHeight: CGFloat { mode == .playthrough ? 236 : 286 }

    /// The menu card: world picker on top, then level or board/time choices.
    private func drawSetupCard(center: CGPoint, width: CGFloat) {
        let height = setupCardHeight
        let card = roundedRect(size: CGSize(width: width, height: height), radius: 22,
                               fill: Palette.paper, stroke: Palette.border)
        card.position = center
        card.zPosition = 2
        addChild(card)
        let top = center.y + height / 2
        let left = center.x - width / 2 + 18
        let inner = width - 30

        addLabel("WORLD", font: "AvenirNext-Bold", size: 11, color: Palette.muted,
                 at: CGPoint(x: left, y: top - 24), alignment: .left, z: 4)
        addLabel(selectedWorld.title.uppercased(), font: "AvenirNext-Heavy", size: 11, color: selectedWorld.accent,
                 at: CGPoint(x: center.x + width / 2 - 18, y: top - 24), alignment: .right, z: 4)
        drawWorldChoices(centerX: center.x, y: top - 72, width: inner)

        switch mode {
        case .playthrough:
            drawLevelChoices(centerX: center.x, top: top - 112, left: left, width: inner)
        case .scoreAttack:
            addLabel("PILE SIZE", font: "AvenirNext-Bold", size: 11, color: Palette.muted,
                     at: CGPoint(x: left, y: top - 124), alignment: .left, z: 4)
            drawBoardChoices(centerX: center.x, y: top - 166, width: inner)
            addLabel("ROUND TIME", font: "AvenirNext-Bold", size: 11, color: Palette.muted,
                     at: CGPoint(x: left, y: top - 212), alignment: .left, z: 4)
            drawTimeChoices(centerX: center.x, y: top - 252, width: inner)
        }
    }

    private func drawWorldChoices(centerX: CGFloat, y: CGFloat, width: CGFloat) {
        let gap: CGFloat = 6
        let count = CGFloat(World.allCases.count)
        let chipWidth = (width - gap * (count - 1)) / count
        for world in World.allCases {
            let unlocked = progress.isUnlocked(world)
            let selected = world == selectedWorld
            let name = "action-world-\(world.rawValue)"
            let x = centerX - width / 2 + chipWidth / 2 + CGFloat(world.rawValue) * (chipWidth + gap)
            let chip = roundedRect(size: CGSize(width: chipWidth, height: 58), radius: 12,
                                   fill: selected ? world.accent : Palette.cream,
                                   stroke: selected ? world.accent : Palette.ink.withAlphaComponent(0.12))
            chip.position = CGPoint(x: x, y: y)
            chip.zPosition = 5
            chip.name = name
            addChild(chip)
            let iconColor = selected ? .white : (unlocked ? world.accent : Palette.muted.withAlphaComponent(0.5))
            if let icon = makeSymbol(unlocked ? world.symbolName : "lock.fill", pointSize: 17, color: iconColor) {
                icon.position.y = 8
                icon.name = name
                chip.addChild(icon)
            }
            let title = makeLabel(world.title.uppercased(), font: "AvenirNext-Bold", size: min(9, chipWidth / 6.2),
                                  color: selected ? .white : (unlocked ? Palette.ink : Palette.muted.withAlphaComponent(0.6)),
                                  name: name)
            title.position.y = -16
            chip.addChild(title)
            if selected {
                chip.run(.sequence([.scale(to: 1.06, duration: 0.10), .scale(to: 1.00, duration: 0.10)]))
            }
        }
    }

    private func drawLevelChoices(centerX: CGFloat, top: CGFloat, left: CGFloat, width: CGFloat) {
        let level = selectedLevel
        let beaten = progress.levelsBeaten(in: level.world)
        addLabel("LEVEL", font: "AvenirNext-Bold", size: 11, color: Palette.muted,
                 at: CGPoint(x: left, y: top - 12), alignment: .left, z: 4)
        addLabel("\(beaten) OF \(Level.countPerWorld) BEATEN", font: "AvenirNext-Heavy", size: 11, color: Palette.teal,
                 at: CGPoint(x: centerX + width / 2 + 3, y: top - 12), alignment: .right, z: 4)

        let spacing = min(58, width / CGFloat(Level.countPerWorld))
        let rowY = top - 52
        for number in 1...Level.countPerWorld {
            let candidate = Level(world: level.world, number: number)
            let playable = progress.isPlayable(candidate)
            let isBeaten = number <= beaten
            let selected = number == level.number
            let name = "action-level-\(number)"
            let x = centerX + (CGFloat(number) - CGFloat(Level.countPerWorld + 1) / 2) * spacing
            let dot = SKShapeNode(circleOfRadius: 20)
            dot.fillColor = isBeaten ? Palette.teal : (selected ? Palette.paper : Palette.cream)
            dot.strokeColor = selected ? Palette.coral : Palette.ink.withAlphaComponent(playable ? 0.25 : 0.1)
            dot.lineWidth = selected ? 3 : 1.5
            dot.position = CGPoint(x: x, y: rowY)
            dot.zPosition = 5
            dot.name = name
            addChild(dot)
            let textColor = isBeaten ? .white : Palette.ink.withAlphaComponent(playable ? 1 : 0.25)
            dot.addChild(makeLabel("\(number)", font: "AvenirNext-Heavy", size: 17, color: textColor, name: name))
        }

        addLabel("Score \(level.targetScore) in \(Int(level.duration)) sec  •  \(level.boardSize.title) pile",
                 font: "AvenirNext-DemiBold", size: 13, color: Palette.ink,
                 at: CGPoint(x: centerX, y: top - 94), alignment: .center, z: 4)
        addLabel(unlockNote(for: level.world), font: "AvenirNext-Medium", size: 11, color: Palette.muted,
                 at: CGPoint(x: centerX, y: top - 115), alignment: .center, z: 4)
    }

    private func unlockNote(for world: World) -> String {
        guard let next = world.next else { return "Spell \(world.title.lowercased()) words for double points" }
        let remaining = Level.countToUnlockNext - progress.levelsBeaten(in: world)
        if remaining <= 0 { return "\(next.title) is unlocked" }
        return "Beat \(remaining) more to unlock \(next.title)"
    }

    private func leaderboardHeight(compact: Bool) -> CGFloat { compact ? 82 : 126 }

    private func drawLeaderboard(centerX: CGFloat, topY: CGFloat, width: CGFloat, compact: Bool) {
        let scores = highScores.scores(for: selectedBoardSize, duration: selectedRoundDuration)
        let height = leaderboardHeight(compact: compact)
        let panel = roundedRect(size: CGSize(width: width, height: height), radius: 17,
                                fill: Palette.paper, stroke: Palette.border)
        panel.position = CGPoint(x: centerX, y: topY - height / 2)
        panel.zPosition = 2
        addChild(panel)

        let headerY = topY - (compact ? 12 : 18)
        addLabel("TOP SCORES", font: "AvenirNext-Heavy", size: compact ? 10 : 12, color: Palette.coral,
                 at: CGPoint(x: centerX - width / 2 + 17, y: headerY), alignment: .left, z: 4)
        let modeText = "\(selectedBoardSize.title)  •  \(Int(selectedRoundDuration)) SEC"
        addLabel(modeText, font: "AvenirNext-Bold", size: compact ? 8 : 10, color: Palette.teal,
                 at: CGPoint(x: centerX + width / 2 - 16, y: headerY), alignment: .right, z: 4)
        guard !scores.isEmpty else {
            addLabel("No scores for this setup yet", font: "AvenirNext-Medium", size: 11,
                     color: Palette.muted, at: CGPoint(x: centerX, y: topY - height * 0.63), alignment: .center, z: 4)
            return
        }

        let firstRowY = topY - (compact ? 31 : 44)
        let rowGap: CGFloat = compact ? 16 : 25
        for (index, score) in scores.prefix(3).enumerated() {
            let y = firstRowY - CGFloat(index) * rowGap
            addLabel("\(index + 1)", font: "AvenirNext-Heavy", size: compact ? 10 : 12, color: Palette.gold,
                     at: CGPoint(x: centerX - width / 2 + 18, y: y), alignment: .left, z: 4)
            addLabel("\(score)", font: "AvenirNext-Heavy", size: compact ? 13 : 17, color: Palette.ink,
                     at: CGPoint(x: centerX - width / 2 + 38, y: y), alignment: .left, z: 4)
        }
    }

    private func drawBoardChoices(centerX: CGFloat, y: CGFloat, width: CGFloat) {
        let gap: CGFloat = 8
        let optionWidth = (width - gap * 2) / 3
        for (index, board) in LetterFlyGame.BoardSize.allCases.enumerated() {
            let x = centerX - width / 2 + optionWidth / 2 + CGFloat(index) * (optionWidth + gap)
            addChoiceButton(title: board.title, subtitle: "\(board.tileCount) letters", name: "action-board-\(board.rows)",
                            size: CGSize(width: optionWidth, height: 56), selected: selectedBoardSize == board,
                            at: CGPoint(x: x, y: y))
        }
    }

    private func drawTimeChoices(centerX: CGFloat, y: CGFloat, width: CGFloat) {
        let subtitles = ["quick", "relaxed", "extended"]
        let gap: CGFloat = 8
        let optionWidth = (width - gap * 2) / 3
        for (index, (duration, subtitle)) in zip(LetterFlyGame.roundDurations, subtitles).enumerated() {
            let x = centerX - width / 2 + optionWidth / 2 + CGFloat(index) * (optionWidth + gap)
            addChoiceButton(title: "\(Int(duration)) sec", subtitle: subtitle,
                            name: "action-time-\(Int(duration))", size: CGSize(width: optionWidth, height: 52),
                            selected: selectedRoundDuration == duration, at: CGPoint(x: x, y: y))
        }
    }

    // MARK: Game

    private func drawGame() {
        let safe = safeFrame
        let landscape = safe.width > safe.height
        let hudY = safe.maxY - 28
        drawHUD(in: CGRect(x: safe.minX + 8, y: hudY - 26, width: safe.width - 16, height: 52))
        drawThemeDots(centerX: safe.midX, y: hudY - 42)

        let pileTop = hudY - 54
        if landscape {
            drawPile(in: CGRect(x: safe.minX + 12, y: safe.minY + 12, width: safe.width * 0.58, height: pileTop - safe.minY - 12))
            drawControls(in: CGRect(x: safe.minX + safe.width * 0.62, y: safe.minY + 20,
                                    width: safe.width * 0.35, height: pileTop - safe.minY - 30))
        } else {
            let controlHeight: CGFloat = min(230, safe.height * 0.28)
            drawPile(in: CGRect(x: safe.minX + 12, y: safe.minY + controlHeight + 26,
                                width: safe.width - 24, height: pileTop - safe.minY - controlHeight - 26))
            drawControls(in: CGRect(x: safe.minX + 20, y: safe.minY + 14,
                                    width: safe.width - 40, height: controlHeight))
        }
    }

    private func drawHUD(in rect: CGRect) {
        let bar = roundedRect(size: rect.size, radius: 18, fill: Palette.paper.withAlphaComponent(0.94), stroke: .clear)
        bar.position = CGPoint(x: rect.midX, y: rect.midY)
        bar.zPosition = 1
        addChild(bar)
        addIconButton(systemName: "xmark", name: "action-exit", size: CGSize(width: 40, height: 36),
                      fillColor: Palette.paper, iconColor: Palette.ink, at: CGPoint(x: rect.minX + 28, y: rect.midY))
        let subtitle = activeLevel.map { "LEVEL \($0.number)" } ?? "SCORE ATTACK"
        addLabel(game.world.title.uppercased(), font: "AvenirNext-Heavy", size: 16, color: game.world.accent,
                 at: CGPoint(x: rect.minX + 58, y: rect.midY + 7), alignment: .left)
        addLabel(subtitle, font: "AvenirNext-Bold", size: 9, color: Palette.muted,
                 at: CGPoint(x: rect.minX + 58, y: rect.midY - 10), alignment: .left)

        let scoreColor = activeLevel.map { game.score >= $0.targetScore ? Palette.teal : Palette.ink } ?? Palette.ink
        addSmallStat(title: "TIME", value: clockText, x: rect.maxX - 14, y: rect.midY, name: "clock-label")
        addSmallStat(title: "SCORE", value: "\(game.score)", x: rect.maxX - 66, y: rect.midY, valueColor: scoreColor)
        if let level = activeLevel {
            addSmallStat(title: "GOAL", value: "\(level.targetScore)", x: rect.maxX - 120, y: rect.midY,
                         valueColor: Palette.muted)
        }
    }

    /// One dot per hidden theme word, filled as each is found.
    private func drawThemeDots(centerX: CGFloat, y: CGFloat) {
        let count = game.roundWords.count
        let found = game.foundThemeWordCount
        let spacing: CGFloat = 13
        let startX = centerX - CGFloat(count - 1) * spacing / 2
        for index in 0..<count {
            let dot = SKShapeNode(circleOfRadius: 4.5)
            dot.fillColor = index < found ? Palette.gold : .clear
            dot.strokeColor = index < found ? Palette.gold : SKColor(white: 1, alpha: 0.6)
            dot.lineWidth = 1.5
            dot.position = CGPoint(x: startX + CGFloat(index) * spacing, y: y)
            dot.zPosition = 2
            addChild(dot)
        }
    }

    private func drawExitConfirmation() {
        let safe = safeFrame
        let dimmer = SKShapeNode(rect: frame)
        dimmer.fillColor = Palette.ink.withAlphaComponent(0.56)
        dimmer.strokeColor = .clear
        dimmer.zPosition = 100
        addChild(dimmer)

        let panelWidth = min(360, safe.width - 42)
        let panelHeight: CGFloat = min(260, safe.height - 40)
        let panel = roundedRect(size: CGSize(width: panelWidth, height: panelHeight), radius: 26,
                                fill: Palette.paper, stroke: .clear)
        panel.position = CGPoint(x: safe.midX, y: safe.midY)
        panel.zPosition = 101
        addChild(panel)

        let badge = makeCrossBadge(radius: 27)
        badge.position = CGPoint(x: safe.midX, y: safe.midY + panelHeight * 0.30)
        badge.zPosition = 102
        addChild(badge)

        addLabel("LEAVE THIS ROUND?", font: "AvenirNext-Heavy", size: 21, color: Palette.ink,
                 at: CGPoint(x: safe.midX, y: safe.midY + 38), alignment: .center, z: 103)
        addLabel("Your current score won't be saved.", font: "AvenirNext-Medium", size: 13,
                 color: Palette.muted, at: CGPoint(x: safe.midX, y: safe.midY + 8), alignment: .center, z: 103)

        let gap: CGFloat = 10
        let buttonWidth = (panelWidth - 54 - gap) / 2
        addButton(title: "NO", name: "action-resume", size: CGSize(width: buttonWidth, height: 48),
                  color: Palette.teal, at: CGPoint(x: -buttonWidth / 2 - gap / 2, y: -65),
                  fontSize: 13, zPosition: 2, in: panel)
        addButton(title: "YES, EXIT", name: "action-exit-confirm", size: CGSize(width: buttonWidth, height: 48),
                  color: Palette.coral, at: CGPoint(x: buttonWidth / 2 + gap / 2, y: -65),
                  fontSize: 13, zPosition: 2, in: panel)
    }

    /// Draws each stack as a bare exposed letter with faded covered letters peeking out
    /// above it, deeper ones fainter. Stacks are scattered freely rather than gridded.
    private func drawPile(in area: CGRect) {
        // Bigger boards show fewer covered letters so the screen stays readable.
        let covered = min(game.stacks.count > 8 ? 1 : 2, game.boardSize.layerCount - 1)
        let layout = pileLayout(count: game.stacks.count, in: area, covered: covered)
        let side = layout.side
        let exposed = game.exposedTileIDs
        for lane in 0..<game.stacks.count {
            let base = layout.bases[lane]
            let stack = game.stacks[lane].filter { !$0.removed && !game.selectedTileIDs.contains($0.id) }
            for (depth, tile) in stack.reversed().prefix(covered + 1).enumerated() {
                let node = makeLetter(tile, side: side, depth: depth, exposed: tile.id == exposed[lane])
                node.position = CGPoint(x: base.x + CGFloat(depth) * side * 0.08,
                                        y: base.y + CGFloat(depth) * side * Self.depthStep)
                node.zPosition = CGFloat(10 - depth)
                node.zRotation = (jitter(tile.id, 3) - 0.5) * 0.36
                addChild(node)
            }
        }
    }

    private static let depthStep: CGFloat = 0.45

    /// Exposed-letter positions for each stack, cached until the round, area or stack count changes.
    private var cachedPileLayout: (key: String, bases: [CGPoint], side: CGFloat)?

    private func pileLayout(count: Int, in area: CGRect, covered: Int) -> (bases: [CGPoint], side: CGFloat) {
        let key = "\(layoutSeed) \(count) \(covered) \(area.integral)"
        if let cached = cachedPileLayout, cached.key == key { return (cached.bases, cached.side) }
        let layout = scatterStacks(count: count, in: area, covered: covered)
        cachedPileLayout = (key, layout.bases, layout.side)
        return layout
    }

    /// Places stacks with best-candidate sampling: each stack tries many random spots and
    /// keeps the one farthest from the others, rejecting any that would overlap. If the
    /// letters don't fit, it shrinks them and tries again.
    private func scatterStacks(count: Int, in area: CGRect, covered: Int) -> (bases: [CGPoint], side: CGFloat) {
        var side = min(64, (area.width * area.height / CGFloat(count)).squareRoot() * 0.62)
        for attempt in 0..<10 {
            // Footprint of one stack: the exposed glyph plus the covered letters above it.
            let width = side * 1.15
            let height = side * (0.85 + Self.depthStep * CGFloat(covered))
            let bounds = area.insetBy(dx: width / 2, dy: height / 2)
            guard bounds.width > 0, bounds.height > 0 else { side *= 0.9; continue }
            var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: layoutSeed &* 31 &+ attempt))
            var centers: [CGPoint] = []
            for _ in 0..<count {
                var best: CGPoint?
                var bestDistance = -CGFloat.infinity
                for _ in 0..<60 {
                    let candidate = CGPoint(x: CGFloat.random(in: bounds.minX...bounds.maxX, using: &rng),
                                            y: CGFloat.random(in: bounds.minY...bounds.maxY, using: &rng))
                    var nearest = CGFloat.infinity
                    var overlaps = false
                    for other in centers {
                        let dx = abs(candidate.x - other.x) / width
                        let dy = abs(candidate.y - other.y) / height
                        if dx < 1.08 && dy < 1.08 { overlaps = true; break }
                        nearest = min(nearest, dx * dx + dy * dy)
                    }
                    if !overlaps && nearest > bestDistance {
                        best = candidate
                        bestDistance = nearest
                    }
                }
                guard let best else { break }
                centers.append(best)
            }
            if centers.count == count {
                // Convert footprint centers to exposed-letter positions (bottom of the footprint).
                let lift = height / 2 - side * 0.45
                return (centers.map { CGPoint(x: $0.x, y: $0.y - lift) }, side)
            }
            side *= 0.92
        }
        // Fallback: a plain grid, which always fits.
        let columns = game.boardSize.columns
        let rows = (count + columns - 1) / columns
        let cell = CGSize(width: area.width / CGFloat(columns), height: area.height / CGFloat(rows))
        let fitted = min(side, cell.width * 0.8, cell.height / (1 + Self.depthStep * CGFloat(covered)) * 0.9)
        let bases = (0..<count).map { lane in
            CGPoint(x: area.minX + cell.width * (CGFloat(lane % columns) + 0.5),
                    y: area.maxY - cell.height * (CGFloat(lane / columns) + 0.5) - fitted * Self.depthStep * CGFloat(covered) / 2)
        }
        return (bases, fitted)
    }

    /// A stable pseudo-random value in 0..<1 for `key`, fixed for the whole round
    /// so letters keep their placement and tilt across re-renders.
    private func jitter(_ key: Int, _ salt: Int) -> CGFloat {
        var hasher = Hasher()
        hasher.combine(layoutSeed)
        hasher.combine(key)
        hasher.combine(salt)
        return CGFloat(UInt(bitPattern: hasher.finalize()) % 10_000) / 10_000
    }

    private func drawControls(in area: CGRect) {
        let panel = roundedRect(size: CGSize(width: area.width + 20, height: area.height + 16), radius: 24,
                                fill: Palette.paper.withAlphaComponent(0.93), stroke: .clear)
        panel.position = CGPoint(x: area.midX, y: area.midY)
        panel.zPosition = 0.5
        addChild(panel)

        let cardWidth = area.width
        let wordCard = roundedRect(size: CGSize(width: cardWidth, height: 64), radius: 18,
                                   fill: Palette.cream, stroke: Palette.border.withAlphaComponent(0.72))
        wordCard.name = "word-card"
        wordCard.position = CGPoint(x: area.midX, y: area.maxY - 34)
        wordCard.zPosition = 1
        addChild(wordCard)
        let display = game.currentWord.isEmpty ? "YOUR WORD" : game.currentWord
        let fontSize = fittedFontSize(for: display, max: 29, width: cardWidth - 48)
        let wordLabel = addLabel(display, font: "AvenirNext-Heavy", size: fontSize,
                                 color: game.currentWord.isEmpty ? Palette.muted.withAlphaComponent(0.45) : Palette.ink,
                                 at: wordCard.position, alignment: .center, name: "word-label", z: 3)
        if !game.currentWord.isEmpty {
            wordLabel.attributedText = attributedWord(game.selectedTiles, fontSize: fontSize)
        }

        let actionY = area.maxY - 104
        let smallWidth = min(74, (cardWidth - 176) / 2)
        addButton(title: "CLEAR", name: "action-clear", size: CGSize(width: smallWidth, height: 42),
                  color: Palette.ink, at: CGPoint(x: area.minX + smallWidth / 2, y: actionY), fontSize: 11)
        addButton(title: "SUBMIT", name: "action-submit", size: CGSize(width: 150, height: 48),
                  color: Palette.coral, at: CGPoint(x: area.midX, y: actionY))
        addIconButton(systemName: "delete.backward.fill", name: "action-undo",
                      size: CGSize(width: smallWidth, height: 42), fillColor: Palette.paper, iconColor: Palette.ink,
                      at: CGPoint(x: area.maxX - smallWidth / 2, y: actionY))

        let lowerY = area.minY + 22
        addButton(title: "HINT", name: "action-hint", size: CGSize(width: 76, height: 36),
                  color: Palette.gold, at: CGPoint(x: area.minX + 38, y: lowerY), fontSize: 12)
        addButton(title: "MIX", name: "action-shuffle", size: CGSize(width: 66, height: 36),
                  color: Palette.teal, at: CGPoint(x: area.maxX - 33, y: lowerY), fontSize: 12)
        addLabel(statusMessage, font: "AvenirNext-DemiBold", size: fittedFontSize(for: statusMessage, max: 13, width: cardWidth - 180),
                 color: statusColor, at: CGPoint(x: area.midX, y: lowerY), alignment: .center, name: "status-label")
        if let hintWord, let first = hintWord.first, let last = hintWord.last {
            let masked = String(repeating: "• ", count: max(0, hintWord.count - 2))
            addLabel("\(first) \(masked)\(last)", font: "AvenirNext-Bold", size: 12, color: Palette.gold,
                     at: CGPoint(x: area.midX, y: lowerY + 27), alignment: .center)
        }
    }

    /// The word in progress, with 2× bonus letters picked out in red.
    private func attributedWord(_ tiles: [LetterFlyGame.Tile], fontSize: CGFloat) -> NSAttributedString {
        let font = UIFont(name: "AvenirNext-Heavy", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        let text = NSMutableAttributedString()
        for tile in tiles {
            text.append(NSAttributedString(string: String(tile.letter), attributes: [
                .font: font,
                .foregroundColor: tile.isBonus ? Palette.coral : Palette.ink
            ]))
        }
        return text
    }

    // MARK: Results

    private func drawFinished() {
        let safe = safeFrame
        let panelWidth = min(430, safe.width - 36)
        let panelHeight = min(450, safe.height - 50)
        let panel = roundedRect(size: CGSize(width: panelWidth, height: panelHeight), radius: 28,
                                fill: Palette.paper.withAlphaComponent(0.97), stroke: Palette.border)
        panel.position = CGPoint(x: safe.midX, y: safe.midY)
        panel.zPosition = 1
        addChild(panel)
        let top = safe.midY + panelHeight / 2
        let bottom = safe.midY - panelHeight / 2

        let title: String
        let titleColor: SKColor
        if activeLevel != nil {
            title = passedLevel ? "LEVEL PASSED!" : "SO CLOSE!"
            titleColor = passedLevel ? Palette.teal : Palette.coral
        } else {
            title = statusMessage.uppercased()
            titleColor = Palette.ink
        }

        let bug = makeBug(size: 58)
        bug.position = CGPoint(x: safe.midX, y: top - 52)
        bug.zPosition = 3
        addChild(bug)
        addLabel(title, font: "AvenirNext-Heavy", size: 28, color: titleColor,
                 at: CGPoint(x: safe.midX, y: top - 112), alignment: .center, z: 3)
        if activeLevel != nil {
            addLabel(statusMessage, font: "AvenirNext-DemiBold", size: 13, color: Palette.muted,
                     at: CGPoint(x: safe.midX, y: top - 136), alignment: .center, z: 3)
        }
        addLabel("\(game.score)", font: "AvenirNext-Heavy", size: 52, color: Palette.coral,
                 at: CGPoint(x: safe.midX, y: top - 182), alignment: .center, z: 3)

        let caption: String
        let captionColor: SKColor
        if let level = activeLevel {
            caption = "GOAL \(level.targetScore)"
            captionColor = passedLevel ? Palette.teal : Palette.muted
        } else {
            caption = earnedNewHighScore ? "NEW HIGH SCORE!" : "POINTS"
            captionColor = earnedNewHighScore ? Palette.gold : Palette.muted
        }
        addLabel(caption, font: "AvenirNext-Bold", size: 12, color: captionColor,
                 at: CGPoint(x: safe.midX, y: top - 220), alignment: .center, z: 3)
        let themeLine = "\(game.foundThemeWordCount)/\(game.roundWords.count) \(game.world.title.lowercased()) words"
        let summary = "\(game.usedWords.count) words  •  \(themeLine)  •  best: \(game.longestWord.uppercased())"
        addLabel(summary, font: "AvenirNext-DemiBold", size: fittedFontSize(for: summary, max: 14, width: panelWidth - 40),
                 color: Palette.muted, at: CGPoint(x: safe.midX, y: top - 246), alignment: .center, z: 3)

        if let unlockedWorld {
            addLabel("\(unlockedWorld.title.uppercased()) UNLOCKED!", font: "AvenirNext-Heavy", size: 15,
                     color: unlockedWorld.accent, at: CGPoint(x: safe.midX, y: top - 274), alignment: .center, z: 3)
        } else if activeLevel == nil {
            let leaders = highScores.scores(for: game.boardSize, duration: roundDuration).prefix(3)
                .map(String.init).joined(separator: "  •  ")
            addLabel("TOP  \(leaders.isEmpty ? "—" : leaders)", font: "AvenirNext-Bold", size: 11,
                     color: Palette.teal, at: CGPoint(x: safe.midX, y: top - 274), alignment: .center, z: 3)
        }

        let buttonY = bottom + 82
        let buttonSize = CGSize(width: min(280, panelWidth - 48), height: 54)
        let linkY = bottom + 30
        if passedLevel, let next = levelAfterActive {
            let label = next.world == activeLevel?.world ? "NEXT LEVEL" : "ON TO \(next.world.title.uppercased())"
            addButton(title: label, name: "action-next", size: buttonSize, color: Palette.coral,
                      at: CGPoint(x: safe.midX, y: buttonY))
            addLabel("REPLAY", font: "AvenirNext-Bold", size: 13, color: Palette.teal,
                     at: CGPoint(x: safe.midX - 50, y: linkY), alignment: .center, name: "action-again", z: 4)
            addLabel("HOME", font: "AvenirNext-Bold", size: 13, color: Palette.teal,
                     at: CGPoint(x: safe.midX + 50, y: linkY), alignment: .center, name: "action-home", z: 4)
        } else {
            addButton(title: activeLevel == nil || passedLevel ? "PLAY AGAIN" : "TRY AGAIN", name: "action-again",
                      size: buttonSize, color: Palette.coral, at: CGPoint(x: safe.midX, y: buttonY))
            addLabel("HOME", font: "AvenirNext-Bold", size: 13, color: Palette.teal,
                     at: CGPoint(x: safe.midX, y: linkY), alignment: .center, name: "action-home", z: 4)
        }
    }

    // MARK: - Node builders

    private func makeLetter(_ tile: LetterFlyGame.Tile, side: CGFloat, depth: Int, exposed: Bool) -> SKNode {
        let container = SKNode()
        let name = "tile-\(tile.id)"
        container.name = name
        // Bare glyphs are hard to hit, so each letter carries an invisible square target.
        let target = SKSpriteNode(color: .clear, size: CGSize(width: side, height: side))
        target.name = name
        container.addChild(target)

        // Deeper letters are smaller and fainter, so they read as further back.
        let coveredAlphas: [CGFloat] = [0.38, 0.18]
        let alpha = exposed ? 1 : coveredAlphas[min(max(depth - 1, 0), coveredAlphas.count - 1)]
        let color = (tile.isBonus ? Palette.bonusLetter : .white).withAlphaComponent(alpha)
        let fontSize = side * (exposed ? 0.9 : 0.78 - 0.12 * CGFloat(depth - 1))
        if exposed {
            let shadow = makeLabel(String(tile.letter), font: "AvenirNext-Heavy", size: fontSize,
                                   color: Palette.ink.withAlphaComponent(0.55), name: name)
            shadow.position = CGPoint(x: 2, y: -3)
            // The view ignores sibling order, so layering needs explicit z values.
            shadow.zPosition = 0.1
            container.addChild(shadow)
        }
        let letter = makeLabel(String(tile.letter), font: "AvenirNext-Heavy", size: fontSize, color: color, name: name)
        letter.zPosition = 0.2
        container.addChild(letter)
        if exposed && tile.isBonus {
            let badge = makeLabel("2×", font: "AvenirNext-Heavy", size: max(9, side * 0.18), color: Palette.gold, name: name)
            badge.position = CGPoint(x: side * 0.4, y: -side * 0.34)
            badge.zPosition = 0.3
            container.addChild(badge)
        }
        return container
    }

    private func makeBug(size: CGFloat) -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(ellipseOf: CGSize(width: size, height: size * 0.82))
        body.fillColor = Palette.coral
        body.strokeColor = Palette.ink
        body.lineWidth = max(2, size * 0.035)
        node.addChild(body)
        let split = SKShapeNode(rectOf: CGSize(width: max(2, size * 0.035), height: size * 0.72), cornerRadius: 2)
        split.fillColor = Palette.ink
        split.strokeColor = .clear
        node.addChild(split)
        for point in [CGPoint(x: -0.22, y: 0.16), CGPoint(x: 0.22, y: 0.16), CGPoint(x: -0.25, y: -0.18), CGPoint(x: 0.25, y: -0.18)] {
            let dot = SKShapeNode(circleOfRadius: size * 0.075)
            dot.fillColor = Palette.ink
            dot.strokeColor = .clear
            dot.position = CGPoint(x: point.x * size, y: point.y * size)
            node.addChild(dot)
        }
        let head = SKShapeNode(ellipseOf: CGSize(width: size * 0.48, height: size * 0.32))
        head.fillColor = Palette.ink
        head.strokeColor = .clear
        head.position.y = size * 0.38
        node.addChild(head)
        return node
    }

    @discardableResult
    private func addLabel(_ text: String, font: String, size: CGFloat, color: SKColor, at point: CGPoint,
                          alignment: SKLabelHorizontalAlignmentMode, name: String? = nil, z: CGFloat = 2) -> SKLabelNode {
        let label = makeLabel(text, font: font, size: size, color: color, alignment: alignment, name: name)
        label.position = point
        label.zPosition = z
        addChild(label)
        return label
    }

    private func makeLabel(_ text: String, font: String, size: CGFloat, color: SKColor,
                           alignment: SKLabelHorizontalAlignmentMode = .center, name: String? = nil) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .center
        label.name = name
        return label
    }

    private func makeSymbol(_ systemName: String, pointSize: CGFloat, color: SKColor) -> SKSpriteNode? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color]))
        guard let symbol = UIImage(systemName: systemName, withConfiguration: configuration) else { return nil }
        // SKTexture ignores symbol tinting, so bake the color into a bitmap first.
        let image = UIGraphicsImageRenderer(size: symbol.size).image { _ in symbol.draw(at: .zero) }
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.size = image.size
        return sprite
    }

    private func makeCrossBadge(radius: CGFloat) -> SKShapeNode {
        let badge = SKShapeNode(circleOfRadius: radius)
        badge.fillColor = Palette.coral
        badge.strokeColor = .clear
        let cross = makeLabel("×", font: "AvenirNext-Heavy", size: 38, color: .white)
        cross.position.y = 1
        badge.addChild(cross)
        return badge
    }

    /// Adds a rounded button body with a drop shadow beneath it. Every node carries
    /// `name` so a tap anywhere on the button resolves to its action.
    private func addButtonBody(name: String, size: CGSize, fill: SKColor, stroke: SKColor = .clear,
                               at point: CGPoint, zPosition: CGFloat, in parent: SKNode) -> SKShapeNode {
        let radius = size.height * 0.35
        let shadow = roundedRect(size: size, radius: radius, fill: Palette.shadow, stroke: .clear)
        shadow.position = CGPoint(x: point.x, y: point.y - 3)
        shadow.name = name
        shadow.zPosition = zPosition - 1
        parent.addChild(shadow)
        let button = roundedRect(size: size, radius: radius, fill: fill, stroke: stroke)
        button.position = point
        button.name = name
        button.zPosition = zPosition
        parent.addChild(button)
        return button
    }

    private func addButton(title: String, name: String, size: CGSize, color: SKColor, at point: CGPoint,
                           fontSize: CGFloat = 16, zPosition: CGFloat = 3, in parent: SKNode? = nil) {
        let button = addButtonBody(name: name, size: size, fill: color, at: point,
                                   zPosition: zPosition, in: parent ?? self)
        let label = makeLabel(title, font: "AvenirNext-Heavy", size: fontSize,
                              color: color == Palette.gold ? Palette.ink : .white, name: name)
        label.zPosition = 1
        button.addChild(label)
    }

    private func addIconButton(systemName: String, name: String, size: CGSize,
                               fillColor: SKColor, iconColor: SKColor, at point: CGPoint) {
        let button = addButtonBody(name: name, size: size, fill: fillColor,
                                   stroke: Palette.ink.withAlphaComponent(0.18), at: point, zPosition: 3, in: self)
        if let icon = makeSymbol(systemName, pointSize: 18, color: iconColor) {
            icon.name = name
            icon.zPosition = 1
            button.addChild(icon)
        } else {
            button.addChild(makeLabel("⌫", font: "AvenirNext-Heavy", size: 21, color: iconColor, name: name))
        }
    }

    private func addChoiceButton(title: String, subtitle: String, name: String, size: CGSize,
                                 selected: Bool, at point: CGPoint) {
        let button = roundedRect(size: size, radius: 14,
                                 fill: selected ? Palette.teal : Palette.cream,
                                 stroke: selected ? Palette.teal : Palette.ink.withAlphaComponent(0.14))
        button.position = point
        button.name = name
        button.zPosition = 5
        addChild(button)
        let titleLabel = makeLabel(title, font: "AvenirNext-Heavy", size: 16,
                                   color: selected ? .white : Palette.ink, name: name)
        titleLabel.position.y = 8
        button.addChild(titleLabel)
        let subtitleLabel = makeLabel(subtitle, font: "AvenirNext-Medium", size: 9,
                                      color: selected ? .white.withAlphaComponent(0.80) : Palette.muted, name: name)
        subtitleLabel.position.y = -12
        button.addChild(subtitleLabel)
        if selected {
            button.run(.sequence([.scale(to: 1.04, duration: 0.10), .scale(to: 1.00, duration: 0.10)]))
        }
    }

    private func roundedRect(size: CGSize, radius: CGFloat, fill: SKColor, stroke: SKColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = stroke == .clear ? 0 : 1.5
        return node
    }

    private func addSmallStat(title: String, value: String, x: CGFloat, y: CGFloat,
                              name: String? = nil, valueColor: SKColor = Palette.ink) {
        addLabel(title, font: "AvenirNext-Bold", size: 8, color: Palette.muted,
                 at: CGPoint(x: x, y: y + 10), alignment: .right)
        addLabel(value, font: "AvenirNext-Heavy", size: 17, color: valueColor,
                 at: CGPoint(x: x, y: y - 5), alignment: .right, name: name)
    }

    // MARK: - Live labels

    private var clockText: String {
        let seconds = max(0, Int(timeRemaining.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func updateClockLabel() {
        guard let label = nodeNamed("clock-label") as? SKLabelNode else { return }
        label.text = clockText
        label.fontColor = timeRemaining < 15 ? Palette.coral : Palette.ink
    }

    private func updateStatusLabel() {
        guard let label = nodeNamed("status-label") as? SKLabelNode else { return }
        label.text = statusMessage
        label.fontColor = statusColor
    }

    private func nodeNamed(_ name: String) -> SKNode? { childNode(withName: "//\(name)") }

    private func fittedFontSize(for text: String, max: CGFloat, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return max }
        return min(max, width / (CGFloat(text.count) * 0.62))
    }
}

/// Deterministic SplitMix64, so a round's scattered layout is stable across re-renders.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
