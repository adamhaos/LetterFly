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

    func emitCelebration(from origin: CGPoint, count: Int, in parent: SKNode? = nil) {
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
            (parent ?? self).addChild(particle)
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

    // MARK: Star word splash

    /// A star word was found: the screen dims, a gold star bursts in with spinning rays,
    /// the word spells itself out, and the level's balls fill in ("2 OF 4 FOUND").
    /// The clock waits while it's up; a tap dismisses it early.
    func showStarWordSplash(word: String, found: Int, total: Int) {
        isShowingStarSplash = true
        let complete = found == total
        let safe = safeFrame
        let center = CGPoint(x: safe.midX, y: safe.midY + 40)
        let splash = SKNode()
        splash.name = "star-splash"
        splash.zPosition = 20
        overlay.addChild(splash)

        let dimmer = SKSpriteNode(color: Palette.ink, size: size)
        dimmer.alpha = 0
        splash.addChild(dimmer)
        dimmer.run(.fadeAlpha(to: 0.72, duration: 0.2))

        // Rays spin slowly behind the star.
        let rays = SKNode()
        rays.position = CGPoint(x: center.x, y: center.y + 70)
        rays.zPosition = 1
        splash.addChild(rays)
        for index in 0..<12 {
            let ray = SKShapeNode(rectOf: CGSize(width: 10, height: 150), cornerRadius: 5)
            ray.fillColor = Palette.gold.withAlphaComponent(0.18)
            ray.strokeColor = .clear
            ray.zRotation = CGFloat(index) * .pi / 6
            rays.addChild(ray)
        }
        rays.setScale(0)
        rays.run(.group([.scale(to: 1, duration: 0.35), .repeatForever(.rotate(byAngle: .pi, duration: 4))]))

        let star = makeStar(radius: complete ? 46 : 38)
        star.position = rays.position
        star.zPosition = 2
        star.setScale(0)
        splash.addChild(star)
        let pop = SKAction.scale(to: 1.25, duration: 0.22)
        pop.timingMode = .easeOut
        star.run(.sequence([.group([pop, .rotate(byAngle: .pi * 2, duration: 0.4)]), .scale(to: 1, duration: 0.14),
                            .repeatForever(.sequence([.scale(to: 1.08, duration: 0.5), .scale(to: 1, duration: 0.5)]))]))

        let title = makeLabel(complete ? "STAR EARNED!" : "STAR WORD!", font: "AvenirNext-Heavy", size: 32, color: Palette.gold)
        title.position = CGPoint(x: center.x, y: center.y - 8)
        title.zPosition = 2
        title.setScale(0.4)
        title.alpha = 0
        splash.addChild(title)
        title.run(.sequence([.wait(forDuration: 0.15), .group([.scale(to: 1, duration: 0.2), .fadeIn(withDuration: 0.15)])]))

        // The word spells itself out, letter by letter.
        let letters = Array(word.uppercased()).map(String.init)
        var fontSize: CGFloat = 36
        func width(_ text: String) -> CGFloat {
            let font = UIFont(name: "AvenirNext-Heavy", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
            return (text as NSString).size(withAttributes: [.font: font]).width
        }
        // Space letters by their real widths, so an I doesn't leave a gap.
        while width(letters.joined()) > safe.width - 60, fontSize > 16 { fontSize -= 2 }
        let wordWidth = width(letters.joined())
        var cursor = center.x - wordWidth / 2
        for (index, letter) in letters.enumerated() {
            let glyph = makeLabel(letter, font: "AvenirNext-Heavy", size: fontSize, color: .white)
            let own = width(letter)
            glyph.position = CGPoint(x: cursor + own / 2, y: center.y - 54)
            cursor += own
            glyph.zPosition = 2
            glyph.setScale(0)
            splash.addChild(glyph)
            glyph.run(.sequence([.wait(forDuration: 0.3 + Double(index) * 0.05),
                                 .scale(to: 1.3, duration: 0.1), .scale(to: 1, duration: 0.08)]))
        }

        // "2 OF 4 FOUND" with the balls; the newest pops in.
        let count = makeLabel(complete ? "ALL \(total) FOUND" : "\(found) OF \(total) FOUND", font: "AvenirNext-Heavy",
                              size: 16, color: .white)
        count.position = CGPoint(x: center.x, y: center.y - 98)
        count.zPosition = 2
        splash.addChild(count)
        let balls = makeStarBalls(total: total, filled: found - 1, radius: 10, spacing: 30, empty: SKColor(white: 1, alpha: 0.6))
        balls.position = CGPoint(x: center.x, y: center.y - 132)
        balls.zPosition = 2
        splash.addChild(balls)
        if let newest = balls.childNode(withName: "star-ball-\(found - 1)") as? SKShapeNode {
            newest.run(.sequence([
                .wait(forDuration: 0.6),
                .run { newest.fillColor = Palette.gold; newest.strokeColor = .white; newest.lineWidth = 2.5 },
                .scale(to: 1.7, duration: 0.14), .scale(to: 1, duration: 0.18)
            ]))
            run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in
                guard let self else { return }
                self.emitCelebration(from: balls.convert(newest.position, to: self.overlay), count: 26, in: splash)
            }]))
        }
        emitCelebration(from: star.position, count: complete ? 70 : 40, in: splash)
        if complete {
            run(.sequence([.wait(forDuration: 0.3), .run { [weak self] in
                self?.emitCelebration(from: CGPoint(x: center.x - 120, y: center.y + 40), count: 30, in: splash)
                self?.emitCelebration(from: CGPoint(x: center.x + 120, y: center.y + 40), count: 30, in: splash)
            }]))
        }
        sound.play(complete ? .levelPassed : .themeWord)
        haptics.themeWord()
        run(.sequence([.wait(forDuration: complete ? 2.6 : 2.1), .run { [weak self] in self?.dismissStarSplash() }]),
            withKey: "star-splash")
    }

    func dismissStarSplash() {
        guard isShowingStarSplash else { return }
        isShowingStarSplash = false
        removeAction(forKey: "star-splash")
        lastUpdateTime = 0
        revealTutorialAfterSplash()
        guard let splash = overlay.childNode(withName: "star-splash") else { return }
        splash.name = nil
        splash.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
    }
}
