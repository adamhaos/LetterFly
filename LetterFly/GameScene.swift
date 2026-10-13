import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum Screen { case menu, playing, finished }

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
        static let vowel = SKColor(red: 0.81, green: 0.94, blue: 0.90, alpha: 1)
        static let coveredVowel = SKColor(red: 0.70, green: 0.81, blue: 0.76, alpha: 1)
    }

    private let game = LetterFlyGame()
    private let checker = UITextChecker()
    private let highScores = HighScoreStore.shared
    private var screen: Screen = .menu
    private var timeRemaining: TimeInterval = 90
    private var lastUpdateTime: TimeInterval = 0
    private var statusMessage = ""
    private var statusColor = Palette.muted
    private var statusExpiresAt: TimeInterval = 0
    private var currentTime: TimeInterval = 0
    private var hintWord: String?
    private var selectedBoardSize: LetterFlyGame.BoardSize = .classic
    private var selectedRoundDuration: TimeInterval = 90
    private var isAnimatingFeedback = false
    private var earnedNewHighScore = false
    private var isConfirmingExit = false

    override func didMove(to view: SKView) {
        backgroundColor = Palette.cream
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
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
        } else {
            updateClockLabel()
            if statusExpiresAt > 0, currentTime >= statusExpiresAt {
                statusMessage = ""
                statusExpiresAt = 0
                updateStatusLabel()
            }
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
        case "action-play", "action-again": startRound()
        case "action-submit": submitWord()
        case "action-undo": undoLetter()
        case "action-clear": clearWord()
        case "action-shuffle": shuffleAvailableTiles()
        case "action-hint": showHint()
        case "action-home": showMenu()
        case "action-exit": presentExitConfirmation()
        default:
            if let rows = Self.number(in: action, after: "action-board-"),
               let board = LetterFlyGame.BoardSize(rawValue: rows) {
                chooseBoard(board)
            } else if let seconds = Self.number(in: action, after: "action-time-") {
                chooseDuration(TimeInterval(seconds))
            }
        }
    }

    /// Parses node names like "tile-12" or "action-time-90".
    private static func number(in name: String, after prefix: String) -> Int? {
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    func shuffleAvailableTiles() {
        guard screen == .playing else { return }
        game.shuffleExposedLetters()
        hintWord = nil
        showStatus("Tiles shuffled", color: Palette.teal)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        render()
    }

    private func startRound() {
        game.startNewRound(boardSize: selectedBoardSize)
        screen = .playing
        timeRemaining = selectedRoundDuration
        lastUpdateTime = 0
        statusMessage = "Make words with the uncovered letters"
        statusColor = Palette.muted
        statusExpiresAt = 0
        hintWord = nil
        isAnimatingFeedback = false
        earnedNewHighScore = false
        isConfirmingExit = false
        render()
    }

    private func chooseBoard(_ boardSize: LetterFlyGame.BoardSize) {
        selectedBoardSize = boardSize
        render()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func chooseDuration(_ duration: TimeInterval) {
        selectedRoundDuration = duration
        render()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func showMenu() {
        screen = .menu
        lastUpdateTime = 0
        isConfirmingExit = false
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
        earnedNewHighScore = highScores.record(game.score, board: game.boardSize, duration: selectedRoundDuration)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        render()
    }

    private func handleTile(id: Int) {
        guard screen == .playing else { return }
        if game.selectedTileIDs.last == id {
            game.undoLastSelection()
        } else if game.selectTile(id: id) {
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            showStatus("That tile is still covered", color: Palette.coral)
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
        statusMessage = "+\(result.points)  \(word.uppercased())"
        statusColor = Palette.teal
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        animateAcceptedWord(result)
    }

    private func rejectWord(_ message: String) {
        showStatus(message, color: Palette.coral)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        animateRejectedWord()
    }

    private func animateAcceptedWord(_ result: LetterFlyGame.Submission) {
        guard let card = nodeNamed("word-card") as? SKShapeNode,
              let wordLabel = nodeNamed("word-label") as? SKLabelNode else {
            completeAcceptedWord()
            return
        }
        isAnimatingFeedback = true
        card.fillColor = Palette.teal
        card.strokeColor = Palette.teal
        wordLabel.fontColor = .white
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
        glow.strokeColor = Palette.teal
        glow.lineWidth = 5
        glow.position = card.position
        glow.zPosition = card.zPosition - 0.2
        addChild(glow)
        glow.run(.sequence([
            .group([.scale(to: 1.18, duration: 0.45), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))

        let points = addLabel("+\(result.points)", font: "AvenirNext-Heavy", size: 28, color: Palette.teal,
                              at: CGPoint(x: card.position.x, y: card.position.y + 52), alignment: .center, z: 40)
        points.setScale(0.35)
        points.run(.sequence([
            .group([.scale(to: 1.18, duration: 0.20), .moveBy(x: 0, y: 22, duration: 0.20)]),
            .group([.scale(to: 1.00, duration: 0.12), .moveBy(x: 0, y: 14, duration: 0.12)]),
            .group([.fadeOut(withDuration: 0.32), .moveBy(x: 0, y: 30, duration: 0.32)]),
            .removeFromParent()
        ]))
        emitCelebration(from: card.position)

        run(.sequence([.wait(forDuration: 0.72), .run { [weak self] in self?.completeAcceptedWord() }]))
    }

    private func completeAcceptedWord() {
        isAnimatingFeedback = false
        if game.remainingTileCount < 3 {
            game.score += Int(timeRemaining.rounded(.down)) * 5
            finishRound(message: game.remainingTileCount == 0 ? "Pile cleared!" : "No words left!")
            return
        }

        switch game.prepareNextMove() {
        case .playable:
            render()
        case .remixed:
            showStatus("Stuck tiles remixed — keep going!", color: Palette.teal, duration: 2.2)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            render()
        case .none:
            finishRound(message: "No words left!")
        }
    }

    private func emitCelebration(from origin: CGPoint) {
        let colors = [Palette.coral, Palette.gold, Palette.teal, Palette.ink]
        for index in 0..<26 {
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
        let originalFill = card.fillColor
        let originalStroke = card.strokeColor
        let originalTextColor = wordLabel.fontColor
        card.fillColor = Palette.coral
        card.strokeColor = Palette.coral
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
        run(.sequence([.wait(forDuration: 0.58), .run { [weak self, weak card, weak wordLabel] in
            card?.fillColor = originalFill
            card?.strokeColor = originalStroke
            wordLabel?.fontColor = originalTextColor
            self?.isAnimatingFeedback = false
        }]))
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

    private func render() {
        removeAllChildren()
        drawBackground()
        switch screen {
        case .menu: drawMenu()
        case .playing:
            drawGame()
            if isConfirmingExit { drawExitConfirmation() }
        case .finished: drawFinished()
        }
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

    private func drawBackground() {
        let wash = SKShapeNode(rect: frame)
        wash.fillColor = Palette.cream
        wash.strokeColor = .clear
        wash.zPosition = -100
        addChild(wash)
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
            line.zPosition = -90
            addChild(line)
            x += spacing
        }
    }

    private func drawMenu() {
        let safe = safeFrame
        if safe.width > safe.height {
            drawLandscapeMenu(in: safe)
            return
        }
        let compact = safe.height < 700
        let centerY = safe.midY + (compact ? 4 : 12)
        let bug = makeBug(size: compact ? 62 : 76)
        bug.position = CGPoint(x: safe.midX, y: centerY + (compact ? 250 : 290))
        addChild(bug)

        addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: compact ? 43 : 49, color: Palette.ink,
                 at: CGPoint(x: safe.midX, y: centerY + (compact ? 195 : 225)), alignment: .center)
        addLabel("Choose your challenge", font: "AvenirNext-DemiBold", size: compact ? 14 : 16,
                 color: Palette.muted, at: CGPoint(x: safe.midX, y: centerY + (compact ? 158 : 183)), alignment: .center)

        let cardWidth = min(safe.width - 40, 420)
        let cardHeight: CGFloat = compact ? 280 : 300
        let card = roundedRect(size: CGSize(width: cardWidth, height: cardHeight), radius: 22,
                               fill: Palette.paper, stroke: Palette.border)
        card.position = CGPoint(x: safe.midX, y: centerY - (compact ? 5 : 12))
        card.zPosition = 2
        addChild(card)

        let titleX = card.position.x - cardWidth / 2 + 22
        addLabel("PILE SIZE", font: "AvenirNext-Bold", size: 11, color: Palette.muted,
                 at: CGPoint(x: titleX, y: card.position.y + cardHeight / 2 - 30), alignment: .left, z: 4)
        drawBoardChoices(centerX: card.position.x, y: card.position.y + cardHeight / 2 - 76, width: cardWidth - 36)
        addLabel("ROUND TIME", font: "AvenirNext-Bold", size: 11, color: Palette.muted,
                 at: CGPoint(x: titleX, y: card.position.y + 22), alignment: .left, z: 4)
        drawTimeChoices(centerX: card.position.x, y: card.position.y - 22, width: cardWidth - 36)

        addLabel("\(selectedBoardSize.tileCount) letters  •  \(Int(selectedRoundDuration))-second round",
                 font: "AvenirNext-DemiBold", size: 13, color: Palette.teal,
                 at: CGPoint(x: card.position.x, y: card.position.y - cardHeight / 2 + 48), alignment: .center, z: 4)
        addLabel("Tap exposed tiles • make words • clear the pile", font: "AvenirNext-Medium", size: 11,
                 color: Palette.muted, at: CGPoint(x: card.position.x, y: card.position.y - cardHeight / 2 + 21),
                 alignment: .center, z: 4)

        addButton(title: "PLAY", name: "action-play", size: CGSize(width: min(cardWidth, 300), height: 58),
                  color: Palette.coral, at: CGPoint(x: safe.midX, y: centerY - (compact ? 190 : 205)))
        addLabel("Tip: shake the phone to shuffle", font: "AvenirNext-Medium", size: 12, color: Palette.muted,
                 at: CGPoint(x: safe.midX, y: centerY - (compact ? 233 : 248)), alignment: .center)
        drawLeaderboard(centerX: safe.midX, topY: centerY - (compact ? 244 : 273),
                        width: min(cardWidth, 350), compact: compact)
    }

    private func drawLandscapeMenu(in safe: CGRect) {
        let leftX = safe.minX + safe.width * 0.24
        let rightX = safe.minX + safe.width * 0.70
        let bug = makeBug(size: 66)
        bug.position = CGPoint(x: leftX, y: safe.midY + 105)
        addChild(bug)
        addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: 42, color: Palette.ink,
                 at: CGPoint(x: leftX, y: safe.midY + 42), alignment: .center)
        addLabel("A word game with hidden depths", font: "AvenirNext-DemiBold", size: 14, color: Palette.muted,
                 at: CGPoint(x: leftX, y: safe.midY + 4), alignment: .center)
        drawLeaderboard(centerX: leftX, topY: safe.midY - 18,
                        width: min(300, safe.width * 0.38), compact: true)
        addButton(title: "PLAY", name: "action-play", size: CGSize(width: min(250, safe.width * 0.34), height: 50),
                  color: Palette.coral, at: CGPoint(x: leftX, y: safe.midY - 145))

        let cardWidth = min(410, safe.width * 0.48)
        let cardHeight = min(300, safe.height - 38)
        let card = roundedRect(size: CGSize(width: cardWidth, height: cardHeight), radius: 22,
                               fill: Palette.paper, stroke: Palette.border)
        card.position = CGPoint(x: rightX, y: safe.midY)
        card.zPosition = 2
        addChild(card)
        let titleX = rightX - cardWidth / 2 + 20
        addLabel("PILE SIZE", font: "AvenirNext-Bold", size: 10, color: Palette.muted,
                 at: CGPoint(x: titleX, y: safe.midY + cardHeight / 2 - 27), alignment: .left, z: 4)
        drawBoardChoices(centerX: rightX, y: safe.midY + cardHeight / 2 - 68, width: cardWidth - 30)
        addLabel("ROUND TIME", font: "AvenirNext-Bold", size: 10, color: Palette.muted,
                 at: CGPoint(x: titleX, y: safe.midY + 16), alignment: .left, z: 4)
        drawTimeChoices(centerX: rightX, y: safe.midY - 24, width: cardWidth - 30)
        addLabel("\(selectedBoardSize.tileCount) letters • \(Int(selectedRoundDuration)) seconds", font: "AvenirNext-DemiBold",
                 size: 12, color: Palette.teal, at: CGPoint(x: rightX, y: safe.midY - cardHeight / 2 + 25), alignment: .center, z: 4)
    }

    private func drawLeaderboard(centerX: CGFloat, topY: CGFloat, width: CGFloat, compact: Bool) {
        let scores = highScores.scores(for: selectedBoardSize, duration: selectedRoundDuration)
        let height: CGFloat = compact ? 82 : 126
        let panel = roundedRect(size: CGSize(width: width, height: height), radius: 17,
                                fill: Palette.paper, stroke: Palette.border)
        panel.position = CGPoint(x: centerX, y: topY - height / 2)
        panel.zPosition = 2
        addChild(panel)

        let headerY = topY - (compact ? 12 : 18)
        addLabel("TOP SCORES", font: "AvenirNext-Heavy", size: compact ? 10 : 12, color: Palette.coral,
                 at: CGPoint(x: centerX - width / 2 + 17, y: headerY), alignment: .left, z: 4)
        let mode = "\(selectedBoardSize.title)  •  \(Int(selectedRoundDuration)) SEC"
        addLabel(mode, font: "AvenirNext-Bold", size: compact ? 8 : 10, color: Palette.teal,
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
            addChoiceButton(title: board.title, subtitle: "\(board.tileCount) tiles", name: "action-board-\(board.rows)",
                            size: CGSize(width: optionWidth, height: 58), selected: selectedBoardSize == board,
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
                            name: "action-time-\(Int(duration))", size: CGSize(width: optionWidth, height: 54),
                            selected: selectedRoundDuration == duration, at: CGPoint(x: x, y: y))
        }
    }

    private func drawGame() {
        let safe = safeFrame
        let landscape = safe.width > safe.height
        let topY = safe.maxY - 28
        addIconButton(systemName: "xmark", name: "action-exit", size: CGSize(width: 44, height: 44),
                      fillColor: Palette.paper, iconColor: Palette.ink, at: CGPoint(x: safe.minX + 24, y: topY))
        addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: 22, color: Palette.ink,
                 at: CGPoint(x: safe.minX + 54, y: topY), alignment: .left)
        addSmallStat(title: "SCORE", value: "\(game.score)", x: safe.maxX - 72, y: topY)
        addSmallStat(title: "TIME", value: clockText, x: safe.maxX - 22, y: topY, name: "clock-label")
        if landscape {
            drawPile(in: CGRect(x: safe.minX + 20, y: safe.minY + 20, width: safe.width * 0.58, height: safe.height - 90))
            drawControls(in: CGRect(x: safe.minX + safe.width * 0.62, y: safe.minY + 24,
                                    width: safe.width * 0.35, height: safe.height - 105))
        } else {
            let controlHeight: CGFloat = min(230, safe.height * 0.28)
            drawPile(in: CGRect(x: safe.minX + 12, y: safe.minY + controlHeight + 12,
                                width: safe.width - 24, height: safe.height - controlHeight - 90))
            drawControls(in: CGRect(x: safe.minX + 16, y: safe.minY + 12,
                                    width: safe.width - 32, height: controlHeight))
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

    private func drawPile(in area: CGRect) {
        let cellWidth = area.width / 4
        let rowCount = game.boardSize.rows
        let cellHeight = area.height / CGFloat(rowCount)
        let tileSide = min(66, min(cellWidth * 0.72, cellHeight * 0.66))
        let depthOffset = min(7, tileSide * 0.10)
        let rowGap = min(12, max(7, tileSide * 0.17))
        let rowPitch = tileSide + rowGap
        let topRowY = area.midY + CGFloat(rowCount - 1) * rowPitch / 2 - depthOffset * 1.5
        let exposed = game.exposedTileIDs
        for lane in 0..<game.stacks.count {
            let column = lane % 4
            let row = lane / 4
            let baseX = area.minX + cellWidth * (CGFloat(column) + 0.5) - depthOffset * 1.5
            let baseY = topRowY - CGFloat(row) * rowPitch
            let stack = game.stacks[lane].filter { !$0.removed && !game.selectedTileIDs.contains($0.id) }
            for (visibleDepth, tile) in stack.enumerated() {
                let tileNode = makeTile(tile, side: tileSide, enabled: tile.id == exposed[lane])
                tileNode.position = CGPoint(x: baseX + CGFloat(visibleDepth) * depthOffset,
                                            y: baseY + CGFloat(visibleDepth) * depthOffset)
                tileNode.zPosition = CGFloat(visibleDepth + 5)
                addChild(tileNode)
            }
        }
    }

    private func drawControls(in area: CGRect) {
        let cardWidth = area.width
        let wordCard = roundedRect(size: CGSize(width: cardWidth, height: 70), radius: 18,
                                   fill: Palette.paper.withAlphaComponent(0.84),
                                   stroke: Palette.border.withAlphaComponent(0.72))
        wordCard.name = "word-card"
        wordCard.position = CGPoint(x: area.midX, y: area.maxY - 38)
        addChild(wordCard)
        let display = game.currentWord.isEmpty ? "YOUR WORD" : game.currentWord
        addLabel(display, font: "AvenirNext-Heavy", size: fittedFontSize(for: display, max: 29, width: cardWidth - 48),
                 color: game.currentWord.isEmpty ? Palette.muted.withAlphaComponent(0.45) : Palette.ink,
                 at: wordCard.position, alignment: .center, name: "word-label", z: 3)

        let actionY = area.maxY - 111
        let smallWidth = min(74, (cardWidth - 176) / 2)
        addButton(title: "CLEAR", name: "action-clear", size: CGSize(width: smallWidth, height: 42),
                  color: Palette.ink, at: CGPoint(x: area.minX + smallWidth / 2, y: actionY), fontSize: 11)
        addButton(title: "SUBMIT", name: "action-submit", size: CGSize(width: 150, height: 48),
                  color: Palette.coral, at: CGPoint(x: area.midX, y: actionY))
        addIconButton(systemName: "delete.backward.fill", name: "action-undo",
                      size: CGSize(width: smallWidth, height: 42), fillColor: Palette.paper, iconColor: Palette.ink,
                      at: CGPoint(x: area.maxX - smallWidth / 2, y: actionY))

        let lowerY = area.minY + 24
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

    private func drawFinished() {
        let safe = safeFrame
        let panelWidth = min(430, safe.width - 36)
        let panelHeight = min(440, safe.height - 70)
        let panel = roundedRect(size: CGSize(width: panelWidth, height: panelHeight), radius: 28,
                                fill: Palette.paper, stroke: Palette.border)
        panel.position = CGPoint(x: safe.midX, y: safe.midY)
        panel.zPosition = 1
        addChild(panel)
        let bug = makeBug(size: 74)
        bug.position = CGPoint(x: safe.midX, y: safe.midY + panelHeight * 0.31)
        bug.zPosition = 3
        addChild(bug)
        addLabel(statusMessage.uppercased(), font: "AvenirNext-Heavy", size: 28, color: Palette.ink,
                 at: CGPoint(x: safe.midX, y: safe.midY + panelHeight * 0.14), alignment: .center, z: 3)
        addLabel("\(game.score)", font: "AvenirNext-Heavy", size: 54, color: Palette.coral,
                 at: CGPoint(x: safe.midX, y: safe.midY + 12), alignment: .center, z: 3)
        addLabel(earnedNewHighScore ? "NEW HIGH SCORE!" : "POINTS", font: "AvenirNext-Bold", size: 12,
                 color: earnedNewHighScore ? Palette.gold : Palette.muted,
                 at: CGPoint(x: safe.midX, y: safe.midY - 30), alignment: .center, z: 3)
        addLabel("\(game.usedWords.count) words  •  best: \(game.longestWord.uppercased())", font: "AvenirNext-DemiBold", size: 15,
                 color: Palette.muted, at: CGPoint(x: safe.midX, y: safe.midY - 58), alignment: .center, z: 3)
        let leaders = highScores.scores(for: game.boardSize, duration: selectedRoundDuration).prefix(3).map(String.init).joined(separator: "  •  ")
        addLabel("TOP  \(leaders.isEmpty ? "—" : leaders)", font: "AvenirNext-Bold", size: 11,
                 color: Palette.teal, at: CGPoint(x: safe.midX, y: safe.midY - 84), alignment: .center, z: 3)
        addButton(title: "PLAY AGAIN", name: "action-again", size: CGSize(width: min(280, panelWidth - 48), height: 56),
                  color: Palette.coral, at: CGPoint(x: safe.midX, y: safe.midY - panelHeight * 0.32))
        addLabel("HOME", font: "AvenirNext-Bold", size: 13, color: Palette.teal,
                 at: CGPoint(x: safe.midX, y: safe.midY - panelHeight * 0.44), alignment: .center, name: "action-home", z: 4)
    }

    private func makeTile(_ tile: LetterFlyGame.Tile, side: CGFloat, enabled: Bool) -> SKNode {
        let container = SKNode()
        container.name = "tile-\(tile.id)"
        let shadow = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: side * 0.2)
        shadow.fillColor = Palette.ink.withAlphaComponent(enabled ? 0.10 : 0.045)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: -3)
        shadow.name = container.name
        container.addChild(shadow)
        let shape = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: side * 0.2)
        let isVowel = "AEIOU".contains(tile.letter)
        let normalColor = isVowel ? Palette.vowel.withAlphaComponent(0.76) : Palette.paper.withAlphaComponent(0.72)
        let coveredColor = isVowel
            ? Palette.coveredVowel.withAlphaComponent(0.30)
            : SKColor(red: 0.84, green: 0.81, blue: 0.72, alpha: 0.28)
        let bonusColor = Palette.gold.withAlphaComponent(enabled ? 0.82 : 0.36)
        shape.fillColor = tile.isBonus ? bonusColor : (enabled ? normalColor : coveredColor)
        shape.strokeColor = enabled ? Palette.ink.withAlphaComponent(0.24) : Palette.ink.withAlphaComponent(0.065)
        shape.lineWidth = enabled ? 2 : 1
        shape.name = container.name
        container.addChild(shape)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = String(tile.letter)
        label.fontSize = side * 0.46
        label.fontColor = enabled ? Palette.ink.withAlphaComponent(0.94) : Palette.ink.withAlphaComponent(0.20)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.name = container.name
        shape.addChild(label)

        let value = SKLabelNode(fontNamed: "AvenirNext-Bold")
        value.text = "\(LetterFlyGame.pointValue(for: tile.letter))"
        value.fontSize = max(7, side * 0.13)
        value.fontColor = Palette.ink.withAlphaComponent(enabled ? 0.30 : 0.09)
        value.horizontalAlignmentMode = .left
        value.verticalAlignmentMode = .center
        value.position = CGPoint(x: -side * 0.36, y: side * 0.32)
        value.name = container.name
        shape.addChild(value)

        if tile.isBonus {
            let bonus = SKLabelNode(fontNamed: "AvenirNext-Bold")
            bonus.text = "2×"
            bonus.fontSize = max(8, side * 0.15)
            bonus.fontColor = Palette.ink.withAlphaComponent(enabled ? 0.62 : 0.14)
            bonus.position = CGPoint(x: side * 0.30, y: -side * 0.31)
            bonus.verticalAlignmentMode = .center
            bonus.name = container.name
            shape.addChild(bonus)
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
        let configuration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        if let image = UIImage(systemName: systemName, withConfiguration: configuration)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal) {
            let icon = SKSpriteNode(texture: SKTexture(image: image))
            icon.size = CGSize(width: 23, height: 18)
            icon.name = name
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
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        titleLabel.text = title
        titleLabel.fontSize = 16
        titleLabel.fontColor = selected ? .white : Palette.ink
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position.y = 8
        titleLabel.name = name
        button.addChild(titleLabel)
        let subtitleLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 9
        subtitleLabel.fontColor = selected ? .white.withAlphaComponent(0.80) : Palette.muted
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.position.y = -12
        subtitleLabel.name = name
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

    private func addSmallStat(title: String, value: String, x: CGFloat, y: CGFloat, name: String? = nil) {
        addLabel(title, font: "AvenirNext-Bold", size: 8, color: Palette.muted,
                 at: CGPoint(x: x, y: y + 10), alignment: .right)
        addLabel(value, font: "AvenirNext-Heavy", size: 17, color: Palette.ink,
                 at: CGPoint(x: x, y: y - 5), alignment: .right, name: name)
    }

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
