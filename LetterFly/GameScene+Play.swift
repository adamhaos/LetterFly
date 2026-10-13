import SpriteKit
import UIKit

// In-round actions: tapping letters, submitting, hints and flying letters.
extension GameScene {
    // MARK: - Play

    func handleTile(id: Int) {
        guard screen == .playing else { return }
        // Capture where the letter sits in the pile before it leaves.
        let start = (nodeNamed("tile-\(id)")).map { ($0.position, $0.zRotation) }
        guard game.selectTile(id: id) else {
            showStatus("That letter is still covered", color: Palette.coral)
            render()
            return
        }
        sound.playSelect(letterIndex: game.selectedTileIDs.count - 1, world: game.world)
        if game.selectedTiles.last?.isBonus == true { haptics.bonusLetter() } else { haptics.select() }
        hiddenInWord.insert(id)
        if tutorialStep == .tapLetter { tutorialStep = .spellAndSubmit }
        render()
        if let start, let tile = game.selectedTiles.last,
           let end = wordLetterPosition(at: game.selectedTileIDs.count - 1) {
            flyLetter(tile, from: start.0, rotation: start.1, scale: 1,
                      to: end.point, endRotation: 0, endScale: end.fontSize / pileFontSize) { [weak self] in
                self?.hiddenInWord.remove(id)
                self?.refreshWordLabel()
            }
        } else {
            hiddenInWord.remove(id)
            refreshWordLabel()
        }
    }

    func undoLetter() {
        guard let tile = game.selectedTiles.last else {
            showStatus("Choose a letter first", color: Palette.muted)
            return
        }
        sendBack([tile])
    }

    func clearWord() {
        let tiles = game.selectedTiles
        guard !tiles.isEmpty else {
            showStatus("Choose a letter first", color: Palette.muted)
            return
        }
        haptics.tap(.light)
        sendBack(tiles)
    }

    /// Returns letters from the word bar to their stacks, the last ones leaving first.
    func sendBack(_ tiles: [LetterFlyGame.Tile]) {
        let starts = tiles.indices.map { offset in
            wordLetterPosition(at: game.selectedTileIDs.count - tiles.count + offset)
        }
        for _ in tiles { game.undoLastSelection() }
        tiles.forEach { hiddenInPile.insert($0.id); hiddenInWord.remove($0.id) }
        render()
        for (offset, tile) in tiles.enumerated().reversed() {
            guard let start = starts[offset], let node = nodeNamed("tile-\(tile.id)") else {
                hiddenInPile.remove(tile.id)
                nodeNamed("tile-\(tile.id)")?.alpha = 1
                continue
            }
            let delay = Double(tiles.count - 1 - offset) * 0.04
            flyLetter(tile, from: start.point, rotation: 0, scale: start.fontSize / pileFontSize,
                      to: node.position, endRotation: node.zRotation, endScale: 1, delay: delay) { [weak self] in
                self?.hiddenInPile.remove(tile.id)
                self?.nodeNamed("tile-\(tile.id)")?.alpha = 1
            }
        }
    }

    /// Finds the clearest open patch on the board for the bug and its bubble (side by side),
    /// scanning the whole board. Corners win when patches are equally clear.
    func hintSpot(bubbleSize: CGSize) -> (bug: CGPoint, bubble: CGPoint, fromLeft: Bool) {
        let area = pileArea == .zero ? safeFrame : pileArea
        let bugSize = CGSize(width: 60, height: 56)
        let bubbleWidth = min(bubbleSize.width, area.width - bugSize.width - 16)
        let blockSize = CGSize(width: bugSize.width + 4 + bubbleWidth, height: max(bugSize.height, bubbleSize.height))
        let letterBoxes = children.compactMap { node -> CGRect? in
            guard node.name?.hasPrefix("tile-") == true, node.alpha > 0 else { return nil }
            return node.calculateAccumulatedFrame().insetBy(dx: -3, dy: -3)
        }
        func coverage(_ rect: CGRect) -> CGFloat {
            letterBoxes.reduce(0) { total, box in
                let overlap = rect.intersection(box)
                return overlap.isNull ? total : total + overlap.width * overlap.height
            }
        }
        let corners = [CGPoint(x: area.minX, y: area.maxY), CGPoint(x: area.maxX, y: area.maxY),
                       CGPoint(x: area.minX, y: area.minY), CGPoint(x: area.maxX, y: area.minY)]
        var best: (block: CGRect, bugOnLeft: Bool, cost: CGFloat)?
        let step: CGFloat = 8
        var y = area.minY + 4
        while y + blockSize.height <= area.maxY - 4 {
            var x = area.minX + 4
            while x + blockSize.width <= area.maxX - 4 {
                let block = CGRect(origin: CGPoint(x: x, y: y), size: blockSize)
                // Small pull toward the nearest corner breaks ties between clear patches.
                let nearestCorner = corners.map { hypot($0.x - block.midX, $0.y - block.midY) }.min() ?? 0
                let cost = coverage(block) * 10 + nearestCorner * 0.5
                if best == nil || cost < best!.cost {
                    // The bug sits on the side nearer its screen edge.
                    best = (block, block.midX < area.midX, cost)
                }
                x += step
            }
            y += step
        }
        guard let best else {
            return (CGPoint(x: area.minX + 40, y: area.maxY - 36), CGPoint(x: area.midX, y: area.maxY - 36), true)
        }
        let block = best.block
        let bug = CGPoint(x: best.bugOnLeft ? block.minX + bugSize.width / 2 : block.maxX - bugSize.width / 2,
                          y: block.midY)
        let bubble = CGPoint(x: best.bugOnLeft ? block.maxX - bubbleWidth / 2 : block.minX + bubbleWidth / 2,
                             y: block.midY + 4)
        return (bug, bubble, best.bugOnLeft)
    }

    /// Font size of an exposed pile letter, which flying copies are drawn at.
    var pileFontSize: CGFloat { (cachedPileLayout?.side ?? 56) * 0.9 }

    /// A copy of the letter glides between spots on the overlay layer; `arc` lifts it on a curve.
    func flyLetter(_ tile: LetterFlyGame.Tile, from: CGPoint, rotation: CGFloat, scale: CGFloat,
                           to: CGPoint, endRotation: CGFloat, endScale: CGFloat, delay: TimeInterval = 0,
                           duration: TimeInterval = 0.24, arc: Bool = false,
                           completion: @escaping () -> Void) {
        let ghost = makeLabel(String(tile.shown), font: "AvenirNext-Heavy", size: pileFontSize,
                              color: tile.isWild ? Palette.gold : (tile.isBonus ? Palette.bonusLetter : .white))
        ghost.position = from
        ghost.zRotation = rotation
        ghost.setScale(scale)
        overlay.addChild(ghost)
        let move: SKAction
        if arc {
            let path = CGMutablePath()
            path.move(to: from)
            let lift = min(90, hypot(to.x - from.x, to.y - from.y) * 0.35)
            path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + lift))
            move = .follow(path, asOffset: false, orientToPath: false, duration: duration)
        } else {
            move = .move(to: to, duration: duration)
        }
        move.timingMode = .easeInEaseOut
        let spin = SKAction.rotate(toAngle: endRotation, duration: duration, shortestUnitArc: true)
        let size = SKAction.scale(to: endScale, duration: duration)
        size.timingMode = .easeInEaseOut
        ghost.run(.sequence([
            .wait(forDuration: delay),
            .group([move, spin, size]),
            .run(completion),
            .removeFromParent()
        ]))
    }

    /// Where letter `index` of the current word sits in the word bar, and its font size.
    func wordLetterPosition(at index: Int) -> (point: CGPoint, fontSize: CGFloat)? {
        guard let label = nodeNamed("word-label") as? SKLabelNode,
              index >= 0, index < game.selectedTiles.count else { return nil }
        let font = UIFont(name: "AvenirNext-Heavy", size: label.fontSize) ?? .boldSystemFont(ofSize: label.fontSize)
        let letters = game.selectedTiles.map { String($0.shown) }
        func width(_ text: String) -> CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }
        let total = width(letters.joined())
        let before = width(letters[..<index].joined())
        let own = width(letters[index])
        let center = label.convert(CGPoint.zero, to: self)
        return (CGPoint(x: center.x - total / 2 + before + own / 2, y: center.y), label.fontSize)
    }

    func refreshWordLabel() {
        guard screen == .playing, !game.currentWord.isEmpty,
              let label = nodeNamed("word-label") as? SKLabelNode else { return }
        label.attributedText = attributedWord(game.selectedTiles, fontSize: label.fontSize)
    }

    func submitWord() {
        let typed = game.currentWord.lowercased()
        guard typed.count >= 3 else { rejectWord("Words need at least 3 letters"); return }
        let word: String
        if typed.contains("?") {
            guard let resolved = resolveWild(typed) else { rejectWord("No word fits the ?"); return }
            word = resolved
        } else {
            word = typed
        }
        guard !game.usedWords.contains(word) else { rejectWord("You already found \(word.uppercased())"); return }
        guard isValidWord(word) else { rejectWord("Not in the dictionary"); return }

        let result = game.commitSelection(as: word)
        if tutorialStep == .spellAndSubmit { tutorialStep = .goalBar }
        statusMessage = result.isThemeWord
            ? "\(game.world.title.uppercased()) WORD! +\(result.points)"
            : "+\(result.points)  \(word.uppercased())"
        statusColor = result.isThemeWord ? Palette.gold : Palette.teal
        sound.play(result.isThemeWord ? .themeWord : .accept)
        result.isThemeWord ? haptics.themeWord() : haptics.success()
        stats.recordWord(result.word, isThemeWord: result.isThemeWord)
        animateAcceptedWord(result)
    }

    func rejectWord(_ message: String) {
        showStatus(message, color: Palette.coral)
        sound.play(.reject)
        haptics.error()
        animateRejectedWord()
    }

    func completeAcceptedWord() {
        isAnimatingFeedback = false
        if game.isEndless, game.remainingTileCount < 6 || game.prepareNextMove() == .none {
            // Endless never runs dry: refill instead of ending.
            countUpScore()
            dropLetters(3)
            return
        }
        if game.remainingTileCount < 3 {
            game.score += Int(timeRemaining.rounded(.down)) * 5
            finishRound(message: game.remainingTileCount == 0 ? "Pile cleared!" : "No words left!")
            return
        }
        if let level = activeLevel, !hasAnnouncedGoal, game.score >= level.targetScore {
            hasAnnouncedGoal = true
            animateGoalBar = true
            showStatus("Goal reached — keep scoring!", color: Palette.teal, duration: 2.2)
        }

        switch game.prepareNextMove() {
        case .playable:
            render()
            countUpScore()
        case .remixed:
            showStatus("Stuck letters remixed — keep going!", color: Palette.teal, duration: 2.2)
            haptics.tap(.medium)
            render()
            countUpScore()
        case .none:
            finishRound(message: "No words left!")
        }
    }

    /// Picks a letter for the wild "?" that makes a valid, unused word, preferring theme words.
    func resolveWild(_ typed: String) -> String? {
        let candidates = "abcdefghijklmnopqrstuvwxyz".map { typed.replacingOccurrences(of: "?", with: String($0)) }
            .filter { !game.usedWords.contains($0) }
        return candidates.first { game.roundWords.contains($0.uppercased()) }
            ?? candidates.first { isValidWord($0) }
    }

    func isValidWord(_ word: String) -> Bool {
        if game.roundWords.contains(word.uppercased()) || LetterFlyGame.commonWords.contains(word) { return true }
        let range = NSRange(location: 0, length: (word as NSString).length)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US").location == NSNotFound
    }

    func showHint() {
        guard let word = game.bestAvailableRoundWord(), let first = word.first, let last = word.last else {
            flyInHintBug(saying: "Keep uncovering letters!")
            return
        }
        let masked = String(repeating: "•", count: max(0, word.count - 2)).map(String.init).joined(separator: " ")
        flyInHintBug(saying: "Try  \(first) \(masked) \(last)")
    }

    /// The mascot zips in from the left, says the hint, then flies back off.
    func flyInHintBug(saying text: String) {
        overlay.removeAllChildren()
        let safe = safeFrame
        let bug = makeLogo(size: 58)
        bug.setScale(0.7)
        overlay.addChild(bug)

        let label = makeLabel(text, font: "AvenirNext-Heavy", size: 17, color: .white)
        let width = label.frame.width + 28
        let height: CGFloat = 38
        let spot = hintSpot(bubbleSize: CGSize(width: width, height: height))
        let rest = spot.bug
        let fromLeft = spot.fromLeft
        let edgeX = fromLeft ? frame.minX - 60 : frame.maxX + 60
        bug.position = CGPoint(x: edgeX, y: rest.y + 40)
        // Face the board on the way in; turn around to leave.
        setFacing(bug, left: !fromLeft, duration: 0)

        // Translucent so the letters underneath still show through.
        let color = Palette.mix(game.world.accent, Palette.ink, 0.2).withAlphaComponent(0.62)
        let bubble = roundedRect(size: CGSize(width: width, height: height), radius: height / 2, fill: color,
                                 stroke: SKColor(white: 1, alpha: 0.25))
        bubble.position = spot.bubble
        bubble.zPosition = 2
        // The tail points back toward the bug, from whichever edge faces it.
        let toBug = CGPoint(x: rest.x - spot.bubble.x, y: rest.y - spot.bubble.y)
        let tail = CGMutablePath()
        if abs(toBug.x) > width / 2 {
            let side: CGFloat = toBug.x < 0 ? -1 : 1
            tail.move(to: CGPoint(x: side * (width / 2 - 16), y: -height / 2 + 4))
            tail.addLine(to: CGPoint(x: side * (width / 2 - 2), y: -height / 2 + 10))
            tail.addLine(to: CGPoint(x: side * (width / 2 + 10), y: -height / 2 - 6))
        } else {
            let edge: CGFloat = toBug.y < 0 ? -1 : 1
            let x = min(max(toBug.x, -width / 2 + 20), width / 2 - 20)
            tail.move(to: CGPoint(x: x - 8, y: edge * (height / 2 - 2)))
            tail.addLine(to: CGPoint(x: x + 8, y: edge * (height / 2 - 2)))
            tail.addLine(to: CGPoint(x: x, y: edge * (height / 2 + 10)))
        }
        tail.closeSubpath()
        let tailNode = SKShapeNode(path: tail)
        tailNode.fillColor = color
        tailNode.strokeColor = .clear
        bubble.addChild(tailNode)
        label.zPosition = 1
        bubble.addChild(label)
        bubble.setScale(0)
        overlay.addChild(bubble)

        let arrive = SKAction.move(to: rest, duration: 0.35)
        arrive.timingMode = .easeOut
        let leave = SKAction.move(to: CGPoint(x: edgeX + (fromLeft ? -20 : 20), y: rest.y + 60), duration: 0.4)
        leave.timingMode = .easeIn
        let grow = SKAction.scale(to: 1, duration: 0.35)
        bug.run(.sequence([
            .group([arrive, grow]),
            .run { bubble.run(.sequence([.scale(to: 1.1, duration: 0.12), .scale(to: 1, duration: 0.08)])) },
            .wait(forDuration: 2.6),
            .run { bubble.run(.sequence([.scale(to: 0, duration: 0.12), .removeFromParent()])) },
            .run { [weak self] in self?.setFacing(bug, left: fromLeft) },
            .wait(forDuration: 0.12),
            leave,
            .removeFromParent()
        ]))
        haptics.tap(.light)
    }

    func showStatus(_ text: String, color: SKColor, duration: TimeInterval = 1.8) {
        statusMessage = text
        statusColor = color
        statusExpiresAt = currentTime + duration
        updateStatusLabel()
    }
}
