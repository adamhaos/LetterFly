import SpriteKit
import UIKit

// Feedback animations for accepted and rejected words.
extension GameScene {
    // MARK: - Feedback animations

    func animateAcceptedWord(_ result: LetterFlyGame.Submission) {
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
        // Bigger words get bigger celebrations.
        let length = result.word.count
        let confetti = length <= 4 ? 14 : (length == 5 ? 26 : 40)
        emitCelebration(from: card.position, count: result.isThemeWord ? confetti + 18 : confetti)
        if length >= 6 { flashAndShake(strength: length >= 8 ? 1.6 : 1) }
        if length >= 8 { victoryLap() }

        run(.sequence([.wait(forDuration: 0.72), .run { [weak self] in self?.completeAcceptedWord() }]))
    }

    /// A bright flash and a short shake of the whole screen.
    func flashAndShake(strength: CGFloat) {
        let flash = SKSpriteNode(color: .white, size: size)
        flash.alpha = 0.32 * strength
        flash.zPosition = 80
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
        let amount = 9 * strength
        let shake = SKAction.sequence([
            .moveBy(x: -amount, y: amount * 0.4, duration: 0.04), .moveBy(x: amount * 2, y: -amount * 0.8, duration: 0.05),
            .moveBy(x: -amount * 1.6, y: amount * 0.6, duration: 0.05), .moveBy(x: amount * 1.0, y: -amount * 0.3, duration: 0.05),
            .moveBy(x: -amount * 0.4, y: amount * 0.1, duration: 0.04)
        ])
        for child in children where child !== flash && child !== overlay { child.run(shake) }
        haptics.tap(.heavy)
    }

    /// For eight-letter words: the ladybug loops a lap of honor around the board.
    func victoryLap() {
        let area = pileArea == .zero ? frame : pileArea
        let bug = makeLogo(size: 64)
        bug.position = CGPoint(x: frame.minX - 60, y: area.midY)
        overlay.addChild(bug)
        let path = CGMutablePath()
        path.move(to: bug.position)
        path.addCurve(to: CGPoint(x: area.midX, y: area.maxY - 30),
                      control1: CGPoint(x: area.minX + 20, y: area.midY + 40),
                      control2: CGPoint(x: area.minX + 40, y: area.maxY - 10))
        path.addCurve(to: CGPoint(x: area.midX, y: area.minY + 40),
                      control1: CGPoint(x: area.maxX + 40, y: area.maxY), control2: CGPoint(x: area.maxX + 40, y: area.minY))
        path.addCurve(to: CGPoint(x: frame.maxX + 80, y: area.midY + 60),
                      control1: CGPoint(x: area.minX - 20, y: area.minY + 60), control2: CGPoint(x: area.midX, y: area.midY + 80))
        let lap = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.8)
        lap.timingMode = .easeInEaseOut
        bug.run(.sequence([
            .group([lap, .sequence([
                .wait(forDuration: 0.75), .run { [weak self] in self?.setFacing(bug, left: true) },
                .wait(forDuration: 0.6), .run { [weak self] in self?.setFacing(bug, left: false) }
            ])]),
            .removeFromParent()
        ]))
        for delay in [0.3, 0.8, 1.3] {
            run(.sequence([.wait(forDuration: delay), .run { [weak self, weak bug] in
                guard let self, let bug else { return }
                self.emitCelebration(from: bug.position, count: 12)
            }]))
        }
    }

    func emitCelebration(from origin: CGPoint, count: Int) {
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

    func animateRejectedWord() {
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
}
