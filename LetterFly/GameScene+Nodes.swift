import SpriteKit
import UIKit

// Reusable node builders: letters, the mascot, buttons and labels.
extension GameScene {
    // MARK: - Node builders

    func makeLetter(_ tile: LetterFlyGame.Tile, side: CGFloat, depth: Int, exposed: Bool) -> SKNode {
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
        let color = letterColor(for: tile).withAlphaComponent(alpha)
        let fontSize = side * (exposed ? 0.9 : 0.78 - 0.12 * CGFloat(depth - 1))
        if exposed {
            let shadow = makeLabel(String(tile.shown), font: "AvenirNext-Heavy", size: fontSize,
                                   color: Palette.ink.withAlphaComponent(0.55), name: name)
            shadow.position = CGPoint(x: 2, y: -3)
            // The view ignores sibling order, so layering needs explicit z values.
            shadow.zPosition = 0.1
            container.addChild(shadow)
        }
        let letter = makeLabel(String(tile.shown), font: "AvenirNext-Heavy", size: fontSize, color: color, name: name)
        letter.zPosition = 0.2
        container.addChild(letter)
        if exposed && tile.isWild {
            let badge = makeLabel("ANY", font: "AvenirNext-Heavy", size: max(8, side * 0.15), color: Palette.gold, name: name)
            badge.position = CGPoint(x: side * 0.42, y: -side * 0.34)
            badge.zPosition = 0.3
            container.addChild(badge)
            // A gentle shimmer so the wild letter stands out.
            letter.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
        }
        if exposed && tile.isGold {
            // Midas's gold glints.
            letter.run(.repeatForever(.sequence([.colorize(with: .white, colorBlendFactor: 0, duration: 0),
                                                 .fadeAlpha(to: 0.75, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        }
        if exposed && tile.isBonus {
            let badge = makeLabel("2×", font: "AvenirNext-Heavy", size: max(9, side * 0.18), color: Palette.gold, name: name)
            badge.position = CGPoint(x: side * 0.4, y: -side * 0.34)
            badge.zPosition = 0.3
            container.addChild(badge)
        }
        return container
    }

    /// A five-pointed gold star with a dark outline.
    func makeStar(radius: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        for point in 0..<10 {
            let r = point.isMultiple(of: 2) ? radius : radius * 0.45
            let angle = CGFloat(point) * .pi / 5 + .pi / 2
            let p = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            point == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.fillColor = Palette.gold
        star.strokeColor = Palette.ink.withAlphaComponent(0.55)
        star.lineWidth = max(1, radius * 0.12)
        star.lineJoin = .round
        return star
    }

    /// The results-screen star: pops in, spins once, then shimmers.
    func drawStarAward(at point: CGPoint) {
        let star = makeStar(radius: 15)
        star.position = CGPoint(x: point.x - 96, y: point.y)
        star.zPosition = 4
        addChild(star)
        let text = masteredWorld
            ? "ALL \(Level.countPerWorld) STARS — \(game.world.title.uppercased()) MASTERED!"
            : (isNewStar ? "STAR EARNED — ALL THEME WORDS!" : "ALL THEME WORDS IN ONE ROUND!")
        addLabel(text, font: "AvenirNext-Heavy", size: 12, color: Palette.mix(Palette.gold, Palette.ink, 0.25),
                 at: CGPoint(x: point.x + 16, y: point.y), alignment: .center, z: 4)
        star.setScale(0)
        let pop = SKAction.scale(to: 1.3, duration: 0.25)
        pop.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.15)
        let shimmer = SKAction.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.6), .scale(to: 1, duration: 0.6)
        ]))
        star.run(.sequence([
            .wait(forDuration: 0.35),
            .group([.sequence([pop, settle]), .rotate(byAngle: .pi * 2, duration: 0.4)]),
            shimmer
        ]))
        if isNewStar {
            run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in
                guard let self else { return }
                self.emitCelebration(from: star.position, count: self.masteredWorld ? 60 : 30)
                if self.masteredWorld {
                    // A second burst from the far side for the world star.
                    self.emitCelebration(from: CGPoint(x: point.x + 110, y: point.y), count: 40)
                }
            }]))
        }
    }

    /// An invisible hit area so a drawing can be tapped anywhere inside it.
    func addTapTarget(to node: SKNode, size: CGSize) {
        let target = SKSpriteNode(color: .clear, size: size)
        target.name = "action-logo"
        target.zPosition = 50
        node.addChild(target)
    }

    /// The home-screen mascot loops off the right edge, sweeps back in from the left and lands home.
    func flyAcross(_ logo: SKNode) {
        guard logo.action(forKey: "fly-across") == nil, logo.action(forKey: "roam") == nil else { return }
        let home = logo.position
        let width = frame.width
        let out = CGMutablePath()
        out.move(to: home)
        out.addCurve(to: CGPoint(x: frame.maxX + 120, y: home.y + 60),
                     control1: CGPoint(x: home.x + width * 0.25, y: home.y + 140),
                     control2: CGPoint(x: frame.maxX - 40, y: home.y - 80))
        let back = CGMutablePath()
        back.move(to: CGPoint(x: frame.minX - 120, y: home.y - 40))
        back.addCurve(to: home,
                      control1: CGPoint(x: frame.minX + width * 0.2, y: home.y - 150),
                      control2: CGPoint(x: home.x - 90, y: home.y + 90))
        let flyOut = SKAction.follow(out, asOffset: false, orientToPath: false, duration: 0.9)
        flyOut.timingMode = .easeIn
        let flyBack = SKAction.follow(back, asOffset: false, orientToPath: false, duration: 1.0)
        flyBack.timingMode = .easeOut
        logo.run(.sequence([
            .group([flyOut, .sequence([.scale(to: 0.8, duration: 0.45), .scale(to: 1, duration: 0.45)])]),
            .wait(forDuration: 0.15),
            .group([flyBack, .sequence([.scale(to: 0.8, duration: 0.5), .scale(to: 1, duration: 0.5)])]),
            .sequence([.moveBy(x: 0, y: 10, duration: 0.1), .moveBy(x: 0, y: -10, duration: 0.12)])
        ]), withKey: "fly-across")
        sound.playSelect(letterIndex: 6)
        haptics.tap(.light)
    }

    /// The mascot swoops in from off screen, lands above the results, hops and cheers.
    func flyInMascot(to target: CGPoint, panelRight: CGFloat) {
        let flyer = SKNode()
        flyer.zPosition = 6
        addChild(flyer)
        flyer.addChild(makeLogo(size: 76))

        // Enter high on the left, loop out to the right, then glide back to the landing spot.
        let start = CGPoint(x: frame.minX - 80, y: target.y + 170)
        let path = CGMutablePath()
        path.move(to: start)
        path.addCurve(to: CGPoint(x: frame.maxX - 70, y: target.y + 40),
                      control1: CGPoint(x: frame.midX - 60, y: target.y + 260),
                      control2: CGPoint(x: frame.maxX + 20, y: target.y + 160))
        path.addCurve(to: target,
                      control1: CGPoint(x: frame.maxX - 120, y: target.y - 70),
                      control2: CGPoint(x: target.x + 70, y: target.y - 40))
        flyer.position = start
        flyer.setScale(0.6)
        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.3)
        fly.timingMode = .easeInEaseOut
        let grow = SKAction.scale(to: 1, duration: 1.3)
        grow.timingMode = .easeOut
        let hop = SKAction.sequence([
            .moveBy(x: 0, y: 14, duration: 0.12), .moveBy(x: 0, y: -14, duration: 0.14),
            .moveBy(x: 0, y: 7, duration: 0.08), .moveBy(x: 0, y: -7, duration: 0.10)
        ])
        flyer.run(.sequence([
            .wait(forDuration: 0.15),
            // It swoops right, turns back toward the card, then faces front to land.
            .group([fly, grow, .sequence([
                .wait(forDuration: 0.55),
                .run { [weak self, weak flyer] in if let flyer { self?.setFacing(flyer, left: true) } },
                .wait(forDuration: 0.55),
                .run { [weak self, weak flyer] in if let flyer { self?.setFacing(flyer, left: false) } },
            ])]),
            .run { [weak self] in
                guard let self else { return }
                self.emitCelebration(from: target, count: 24)
                self.showCheer(near: target, panelRight: panelRight)
            },
            hop
        ]))
    }

    /// A speech bubble from the mascot after it lands.
    func showCheer(near target: CGPoint, panelRight: CGFloat) {
        let lines = ["Bug-tastic!", "Wing-credible!", "You're buzzing!", "Nailed it!", "Spell-tacular!", "Fly-mazing!"]
        let text = masteredWorld ? "Legendary!" : (earnedStar ? "Perfect round!" : lines.randomElement()!)
        let color = Palette.mix(game.world.accent, Palette.ink, 0.2)
        let label = makeLabel(text, font: "AvenirNext-Heavy", size: 14, color: .white)
        let width = label.frame.width + 26
        let height: CGFloat = 32
        // Keep the bubble inside the results card.
        let x = min(target.x + 48 + width / 2, panelRight - 10 - width / 2)
        let bubble = roundedRect(size: CGSize(width: width, height: height), radius: height / 2,
                                 fill: color, stroke: .clear)
        bubble.position = CGPoint(x: x, y: target.y + 22)
        bubble.zPosition = 7
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -width / 2 + 10, y: -height / 2 + 6))
        tail.addLine(to: CGPoint(x: -width / 2 + 24, y: -height / 2 + 2))
        tail.addLine(to: CGPoint(x: -width / 2 - 2, y: -height / 2 - 10))
        tail.closeSubpath()
        let tailNode = SKShapeNode(path: tail)
        tailNode.fillColor = color
        tailNode.strokeColor = .clear
        bubble.addChild(tailNode)
        label.zPosition = 1
        bubble.addChild(label)
        addChild(bubble)
        bubble.setScale(0)
        let pop = SKAction.scale(to: 1.12, duration: 0.16)
        pop.timingMode = .easeOut
        bubble.run(.sequence([pop, .scale(to: 1, duration: 0.1),
                              .repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.7),
                                                        .moveBy(x: 0, y: -3, duration: 0.7)]))]))
    }

    /// The app icon's ladybug, drawn in shapes and animated with smooth sine motion: wing
    /// cases flap, the hind wing flutters, antennae wiggle, the eyes blink and the whole bug
    /// bobs while carrying its letter tile. `size` is roughly the drawing's width. It faces
    /// right; use `setFacing` to turn it. `animated: false` skips the whole-body bob.
    func makeLogo(size s: CGFloat, outfit: Outfit? = nil, animated: Bool = true) -> SKNode {
        // Wear the chosen outfit only while it's still unlocked (e.g. not after a reset).
        let outfit = outfit ?? (Outfit.selected.isUnlocked(progress) ? Outfit.selected : .none)
        let navy = SKColor(red: 0.13, green: 0.16, blue: 0.26, alpha: 1)
        let navyLight = SKColor(red: 0.24, green: 0.28, blue: 0.42, alpha: 1)
        let red = SKColor(red: 0.93, green: 0.30, blue: 0.22, alpha: 1)
        let redDark = SKColor(red: 0.70, green: 0.17, blue: 0.13, alpha: 1)
        let face = SKColor(red: 0.98, green: 0.93, blue: 0.84, alpha: 1)
        let teal = SKColor(red: 0.28, green: 0.72, blue: 0.72, alpha: 1)
        let gold = SKColor(red: 0.90, green: 0.68, blue: 0.20, alpha: 1)
        let pink = SKColor(red: 0.98, green: 0.58, blue: 0.52, alpha: 1)

        func ellipse(_ w: CGFloat, _ h: CGFloat, _ color: SKColor, at x: CGFloat, _ y: CGFloat) -> SKShapeNode {
            let node = SKShapeNode(ellipseOf: CGSize(width: w * s, height: h * s))
            node.fillColor = color
            node.strokeColor = .clear
            node.position = CGPoint(x: x * s, y: y * s)
            return node
        }

        let logo = SKNode()
        // Everything that should mirror when the bug turns lives in `body`.
        let body = SKNode()
        body.name = "bug-body"
        logo.addChild(body)
        // A bright cream rim on the dark parts, so the bug's outline stands out against dark
        // skies and the dark app icon.
        let rim = SKColor(red: 0.98, green: 0.94, blue: 0.86, alpha: 0.9)
        let rimWidth = max(1.5, 0.024 * s)
        // The view ignores sibling order, so each part gets an explicit, increasing z.
        var depth: CGFloat = 0
        func add(_ node: SKNode, to parent: SKNode? = nil) {
            depth += 1
            node.zPosition = depth
            (parent ?? body).addChild(node)
        }

        // A soft halo behind the bug lifts it off busy or dark backdrops.
        // Several faint layers stack into a smooth fade rather than visible rings.
        for (radius, alpha) in [(0.56, 0.018), (0.50, 0.02), (0.44, 0.022), (0.38, 0.025), (0.32, 0.028)] {
            let halo = SKShapeNode(ellipseOf: CGSize(width: radius * 2.1 * s, height: radius * 1.8 * s))
            halo.fillColor = SKColor(red: 1, green: 0.96, blue: 0.85, alpha: alpha)
            halo.strokeColor = .clear
            halo.position = CGPoint(x: 0.04 * s, y: 0.0)
            add(halo)
        }

        // Speed streaks trailing behind (a rainbow trail with the rainbow skin).
        for (index, offset) in [(-0.42, -0.10), (-0.36, -0.24)].enumerated() {
            let streak = SKShapeNode(rectOf: CGSize(width: 0.26 * s, height: 0.035 * s), cornerRadius: 0.0175 * s)
            streak.fillColor = teal
            if outfit == .rainbow {
                streak.fillColor = .white
                streak.fillShader = Self.rainbowShader(brightness: 1)
            }
            streak.strokeColor = .clear
            streak.position = CGPoint(x: offset.0 * s, y: offset.1 * s)
            streak.zRotation = 0.5
            add(streak)
            let base = streak.position
            oscillate(streak, period: 1.0, phase: CGFloat(index) * 1.6) { node, wave in
                node.alpha = 0.55 + 0.3 * wave
                node.position = CGPoint(x: base.x - 0.03 * s * (1 - wave), y: base.y - 0.015 * s * (1 - wave))
            }
        }

        // Two translucent hind wings, fluttering fast and slightly out of step.
        for (index, spec) in [(0.50, 0.21, -0.27, -0.01, 0.15), (0.40, 0.17, -0.22, 0.05, 0.45)].enumerated() {
            let pivot = SKNode()
            pivot.position = CGPoint(x: -0.04 * s, y: 0.06 * s)
            add(pivot)
            let wing = ellipse(spec.0, spec.1, teal.withAlphaComponent(index == 0 ? 0.5 : 0.35), at: spec.2, spec.3)
            wing.zRotation = spec.4
            wing.strokeColor = SKColor(white: 1, alpha: 0.35)
            wing.lineWidth = 0.008 * s
            pivot.addChild(wing)
            let vein = SKShapeNode(rectOf: CGSize(width: spec.0 * 0.7 * s, height: 0.006 * s))
            vein.fillColor = SKColor(white: 1, alpha: 0.35)
            vein.strokeColor = .clear
            vein.zPosition = 0.1
            wing.addChild(vein)
            oscillate(pivot, period: 0.14, phase: CGFloat(index) * 1.2) { node, wave in
                node.zRotation = 0.12 + 0.22 * wave
            }
        }

        // Three legs with little round feet.
        for (x, y, angle) in [(-0.17, -0.18, 0.55), (-0.07, -0.22, 0.35), (0.04, -0.22, 0.1)] {
            let leg = SKShapeNode(rectOf: CGSize(width: 0.045 * s, height: 0.13 * s), cornerRadius: 0.022 * s)
            leg.fillColor = navy
            leg.strokeColor = rim
            leg.lineWidth = rimWidth * 0.7
            leg.position = CGPoint(x: x * s, y: y * s)
            leg.zRotation = angle
            add(leg)
            let foot = SKShapeNode(circleOfRadius: 0.03 * s)
            foot.fillColor = navy
            foot.strokeColor = .clear
            foot.position = CGPoint(x: 0, y: -0.065 * s)
            leg.addChild(foot)
            oscillate(leg, period: 1.2, phase: x * 9) { node, wave in node.zRotation = angle + 0.12 * wave }
        }

        // Body with a soft highlight along the back.
        let bodyShape = ellipse(0.44, 0.34, navy, at: -0.06, -0.06)
        bodyShape.strokeColor = rim
        bodyShape.lineWidth = rimWidth
        add(bodyShape)
        let sheen = ellipse(0.24, 0.07, navyLight, at: -0.10, 0.04)
        sheen.zRotation = 0.2
        add(sheen)

        // Glossy red wing cases with dark rims, flapping smoothly; the back one leads.
        // (width, height, x, y, tilt): the back case stands up, the front one sweeps back.
        for (index, spec) in [(0.36, 0.22, -0.01, 0.20, 1.0), (0.50, 0.27, -0.19, 0.11, 0.38)].enumerated() {
            let pivot = SKNode()
            pivot.position = CGPoint(x: 0.0, y: 0.06 * s)
            add(pivot)
            let wing = ellipse(spec.0, spec.1, index == 0 ? redDark : red, at: spec.2, spec.3)
            if outfit == .rainbow {
                wing.fillColor = .white
                wing.fillShader = Self.rainbowShader(brightness: index == 0 ? 0.72 : 1)
            }
            wing.zRotation = spec.4
            // The front case gets the light rim; the back one keeps a dark edge for depth.
            wing.strokeColor = index == 0 ? redDark : rim
            wing.lineWidth = index == 0 ? 0.014 * s : rimWidth
            pivot.addChild(wing)
            for (sx, sy, r) in [(-0.07, 0.03, 0.045), (0.06, -0.02, 0.04), (0.0, -0.06, 0.03), (-0.13, -0.04, 0.025)] {
                let spot = SKShapeNode(circleOfRadius: r * s * (index == 0 ? 0.8 : 1))
                spot.fillColor = navy
                spot.strokeColor = .clear
                spot.position = CGPoint(x: sx * s, y: sy * s)
                spot.zPosition = 0.1
                wing.addChild(spot)
            }
            let gloss = SKShapeNode(ellipseOf: CGSize(width: spec.0 * 0.45 * s, height: spec.1 * 0.22 * s))
            gloss.fillColor = SKColor(white: 1, alpha: index == 0 ? 0.2 : 0.38)
            gloss.strokeColor = .clear
            gloss.position = CGPoint(x: spec.0 * 0.12 * s, y: spec.1 * 0.26 * s)
            gloss.zPosition = 0.2
            wing.addChild(gloss)
            oscillate(pivot, period: 0.36, phase: CGFloat(index) * 0.9) { node, wave in
                node.zRotation = 0.11 + 0.11 * wave
            }
        }

        // Antennae, wiggling together around the head.
        let antennae = SKNode()
        antennae.position = CGPoint(x: 0.21 * s, y: 0.02 * s)
        add(antennae)
        for (end, control) in [((-0.05, 0.40), (-0.10, 0.28)), ((0.18, 0.34), (0.14, 0.27))] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 0.14 * s))
            path.addQuadCurve(to: CGPoint(x: end.0 * s, y: end.1 * s), control: CGPoint(x: control.0 * s, y: control.1 * s))
            // A rim-colored stroke underneath outlines the thin stalk.
            let outline = SKShapeNode(path: path)
            outline.strokeColor = rim
            outline.lineWidth = 0.025 * s + rimWidth * 1.4
            outline.lineCap = .round
            antennae.addChild(outline)
            let stalk = SKShapeNode(path: path)
            stalk.strokeColor = navy
            stalk.lineWidth = 0.025 * s
            stalk.lineCap = .round
            stalk.zPosition = 0.05
            antennae.addChild(stalk)
            let tip = SKShapeNode(circleOfRadius: 0.04 * s)
            tip.fillColor = gold
            tip.strokeColor = SKColor(red: 0.75, green: 0.52, blue: 0.10, alpha: 1)
            tip.lineWidth = 0.01 * s
            tip.position = CGPoint(x: end.0 * s, y: end.1 * s)
            tip.zPosition = 0.1
            antennae.addChild(tip)
            let glint = SKShapeNode(circleOfRadius: 0.012 * s)
            glint.fillColor = SKColor(white: 1, alpha: 0.8)
            glint.strokeColor = .clear
            glint.position = CGPoint(x: -0.012 * s, y: 0.012 * s)
            glint.zPosition = 0.1
            tip.addChild(glint)
        }
        oscillate(antennae, period: 1.0) { node, wave in node.zRotation = 0.07 * wave }

        // Head with a highlight, and the face.
        let head = ellipse(0.42, 0.40, navy, at: 0.21, 0.02)
        head.strokeColor = rim
        head.lineWidth = rimWidth
        add(head)
        let headShine = ellipse(0.12, 0.05, navyLight, at: 0.12, 0.17)
        headShine.zRotation = 0.5
        add(headShine)
        add(ellipse(0.31, 0.28, face, at: 0.25, -0.01))
        add(ellipse(0.065, 0.04, pink.withAlphaComponent(0.7), at: 0.15, -0.07))
        add(ellipse(0.065, 0.04, pink.withAlphaComponent(0.7), at: 0.35, -0.08))
        let eyes = SKNode()
        add(eyes)
        for (x, y) in [(0.19, 0.03), (0.31, 0.01)] {
            let eye = ellipse(0.075, 0.09, navy, at: x, y)
            eyes.addChild(eye)
            for (dx, dy, r) in [(0.013, 0.022, 0.015), (-0.014, -0.02, 0.007)] {
                let shine = SKShapeNode(circleOfRadius: r * s)
                shine.fillColor = .white
                shine.strokeColor = .clear
                shine.position = CGPoint(x: dx * s, y: dy * s)
                shine.zPosition = 0.1
                eye.addChild(shine)
            }
        }
        let close = SKAction.scaleY(to: 0.08, duration: 0.07)
        close.timingMode = .easeIn
        let open = SKAction.scaleY(to: 1, duration: 0.1)
        open.timingMode = .easeOut
        eyes.run(.repeatForever(.sequence([.wait(forDuration: 2.8, withRange: 1.8), close, open])))
        let smile = CGMutablePath()
        smile.move(to: CGPoint(x: 0.21 * s, y: -0.07 * s))
        smile.addQuadCurve(to: CGPoint(x: 0.30 * s, y: -0.075 * s), control: CGPoint(x: 0.26 * s, y: -0.16 * s))
        smile.closeSubpath()
        let mouth = SKShapeNode(path: smile)
        mouth.fillColor = navy
        mouth.strokeColor = .clear
        add(mouth)
        add(ellipse(0.04, 0.025, pink, at: 0.255, -0.10))

        addOutfit(outfit, size: s, ellipse: ellipse, add: { add($0) })

        // The letter tile, swinging gently from its little hands.
        let tilePivot = SKNode()
        tilePivot.position = CGPoint(x: 0.24 * s, y: -0.16 * s)
        add(tilePivot)
        let tileShadow = SKShapeNode(rectOf: CGSize(width: 0.30 * s, height: 0.30 * s), cornerRadius: 0.05 * s)
        tileShadow.fillColor = navy.withAlphaComponent(0.25)
        tileShadow.strokeColor = .clear
        tileShadow.position = CGPoint(x: 0.015 * s, y: -0.165 * s)
        tilePivot.addChild(tileShadow)
        let tile = SKShapeNode(rectOf: CGSize(width: 0.30 * s, height: 0.30 * s), cornerRadius: 0.05 * s)
        tile.fillColor = face
        tile.strokeColor = gold.withAlphaComponent(0.85)
        tile.lineWidth = 0.02 * s
        tile.position = CGPoint(x: 0, y: -0.15 * s)
        tile.zPosition = 0.05
        tilePivot.addChild(tile)
        let letter = makeCenteredLabel("Y", font: "AvenirNext-Heavy", size: 0.24 * s, color: navy)
        letter.name = "bug-letter"
        letter.zPosition = 0.1
        tile.addChild(letter)
        for x in [-0.10, 0.10] {
            let hand = SKShapeNode(circleOfRadius: 0.04 * s)
            hand.fillColor = navy
            hand.strokeColor = .clear
            hand.position = CGPoint(x: x * s, y: -0.005 * s)
            hand.zPosition = 0.2
            tilePivot.addChild(hand)
        }
        oscillate(tilePivot, period: 1.4) { node, wave in node.zRotation = -0.10 + 0.06 * wave }

        // Gentle bob and sway for the whole bug.
        guard animated else { return logo }
        oscillate(body, period: 1.6) { node, wave in node.position.y = 0.025 * s * wave }
        oscillate(body, period: 2.2, key: "bug-sway") { node, wave in node.zRotation = 0.005 + 0.035 * wave }
        return logo
    }

    /// A shimmering rainbow that slides slowly across a shape, for the rainbow skin.
    static func rainbowShader(brightness: Float) -> SKShader {
        let key = Int(brightness * 100)
        if let cached = rainbowShaders[key] { return cached }
        let shader = SKShader(source: """
        void main() {
            vec2 uv = v_tex_coord;
            float hue = fract(uv.x * 0.85 + uv.y * 0.35 - u_time * 0.12);
            vec3 rgb = clamp(abs(mod(hue * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
            rgb = mix(rgb, vec3(1.0), 0.18) * u_brightness;
            gl_FragColor = vec4(rgb, 1.0) * v_color_mix.a;
        }
        """)
        shader.uniforms = [SKUniform(name: "u_brightness", float: brightness)]
        rainbowShaders[key] = shader
        return shader
    }

    /// Turns the ladybug to face left or right with a quick, smooth flip. The letter it
    /// carries counter-flips so it always reads correctly.
    func setFacing(_ logo: SKNode, left: Bool, duration: TimeInterval = 0.2) {
        // ".//" searches only below this node; "//" alone would search the whole scene.
        guard let body = logo.childNode(withName: ".//bug-body"),
              let letter = body.childNode(withName: ".//bug-letter") else { return }
        let target: CGFloat = left ? -1 : 1
        guard body.xScale != target else { return }
        if duration == 0 {
            body.xScale = target
            letter.xScale = target
            return
        }
        let turn = SKAction.scaleX(to: target, duration: duration)
        turn.timingMode = .easeInEaseOut
        body.run(turn, withKey: "bug-turn")
        letter.run(.scaleX(to: target, duration: duration), withKey: "bug-turn")
    }

    /// Runs a smooth, endless sine wave on `node`, calling `apply` with values in -1...1.
    func oscillate(_ node: SKNode, period: TimeInterval, phase: CGFloat = 0, key: String? = nil,
                   apply: @escaping (SKNode, CGFloat) -> Void) {
        let action = SKAction.repeatForever(.customAction(withDuration: period) { node, elapsed in
            apply(node, sin(2 * .pi * elapsed / CGFloat(period) + phase))
        })
        if let key { node.run(action, withKey: key) } else { node.run(action) }
    }

    /// Draws an outfit on the ladybug's head (head center ≈ (0.21, 0.02), top ≈ 0.22, in units of `s`).
    private func addOutfit(_ outfit: Outfit, size s: CGFloat,
                           ellipse: (CGFloat, CGFloat, SKColor, CGFloat, CGFloat) -> SKShapeNode,
                           add: (SKNode) -> Void) {
        func shape(_ path: CGPath, _ color: SKColor) -> SKShapeNode {
            let node = SKShapeNode(path: path)
            node.fillColor = color
            node.strokeColor = .clear
            return node
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        switch outfit {
        case .none, .rainbow:
            // The rainbow is a skin, painted on the wing cases rather than worn.
            break
        case .rainHat:
            let yellow = SKColor(red: 0.99, green: 0.80, blue: 0.20, alpha: 1)
            let brim = ellipse(0.54, 0.10, yellow.withAlphaComponent(1), 0.20, 0.19)
            brim.zRotation = -0.12
            add(brim)
            add(ellipse(0.30, 0.20, yellow, 0.21, 0.27))
            add(ellipse(0.30, 0.04, SKColor(red: 0.85, green: 0.62, blue: 0.10, alpha: 1), 0.21, 0.21))
        case .partyHat:
            let cone = CGMutablePath()
            cone.move(to: point(0.10, 0.18))
            cone.addLine(to: point(0.32, 0.18))
            cone.addLine(to: point(0.24, 0.52))
            cone.closeSubpath()
            add(shape(cone, SKColor(red: 0.95, green: 0.42, blue: 0.68, alpha: 1)))
            for (x, y) in [(0.17, 0.25), (0.25, 0.30), (0.21, 0.38)] {
                add(ellipse(0.045, 0.045, SKColor(red: 0.99, green: 0.85, blue: 0.30, alpha: 1), x, y))
            }
            add(ellipse(0.08, 0.08, SKColor(red: 0.28, green: 0.72, blue: 0.72, alpha: 1), 0.24, 0.53))
        case .racingCap:
            let red = SKColor(red: 0.85, green: 0.16, blue: 0.18, alpha: 1)
            add(ellipse(0.38, 0.22, red, 0.20, 0.20))
            add(ellipse(0.26, 0.07, SKColor(red: 0.62, green: 0.08, blue: 0.10, alpha: 1), 0.38, 0.15))
            let stripe = SKShapeNode(rectOf: CGSize(width: 0.05 * s, height: 0.18 * s), cornerRadius: 0.02 * s)
            stripe.fillColor = .white
            stripe.strokeColor = .clear
            stripe.position = point(0.20, 0.22)
            add(stripe)
        case .snorkel:
            let tube = SKShapeNode(rectOf: CGSize(width: 0.05 * s, height: 0.32 * s), cornerRadius: 0.025 * s)
            tube.fillColor = SKColor(red: 0.99, green: 0.75, blue: 0.15, alpha: 1)
            tube.strokeColor = .clear
            tube.position = point(0.43, 0.10)
            add(tube)
            let mask = SKShapeNode(rectOf: CGSize(width: 0.30 * s, height: 0.14 * s), cornerRadius: 0.05 * s)
            mask.fillColor = SKColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 0.45)
            mask.strokeColor = SKColor(red: 0.20, green: 0.55, blue: 0.85, alpha: 1)
            mask.lineWidth = 0.022 * s
            mask.position = point(0.25, 0.025)
            add(mask)
        case .fireHelmet:
            let red = SKColor(red: 0.84, green: 0.18, blue: 0.12, alpha: 1)
            add(ellipse(0.56, 0.08, SKColor(red: 0.55, green: 0.08, blue: 0.06, alpha: 1), 0.21, 0.16))
            add(ellipse(0.40, 0.24, red, 0.21, 0.23))
            add(ellipse(0.09, 0.09, SKColor(red: 0.99, green: 0.80, blue: 0.25, alpha: 1), 0.25, 0.24))
        case .spaceHelmet:
            let glass = SKShapeNode(circleOfRadius: 0.30 * s)
            glass.fillColor = SKColor(red: 0.70, green: 0.88, blue: 1.0, alpha: 0.22)
            glass.strokeColor = SKColor(white: 1, alpha: 0.85)
            glass.lineWidth = 0.025 * s
            glass.position = point(0.22, 0.05)
            add(glass)
            let shine = ellipse(0.09, 0.04, SKColor(white: 1, alpha: 0.75), 0.12, 0.22)
            shine.zRotation = 0.6
            add(shine)
            add(ellipse(0.44, 0.08, SKColor(white: 0.82, alpha: 1), 0.22, -0.22))
        }
    }

    /// Text drawn from the font's glyph outlines and centered on its visible shape, so
    /// narrow digits like "1" sit exactly in the middle of a circle.
    func makeCenteredLabel(_ text: String, font fontName: String, size: CGFloat, color: SKColor,
                           name: String? = nil) -> SKNode {
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let characters = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        guard CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count) else {
            return makeLabel(text, font: fontName, size: size, color: color, name: name)
        }
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
        let outline = CGMutablePath()
        var penX: CGFloat = 0
        for (glyph, advance) in zip(glyphs, advances) {
            if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
                outline.addPath(path, transform: CGAffineTransform(translationX: penX, y: 0))
            }
            penX += advance.width
        }
        let box = outline.boundingBoxOfPath
        let centered = CGMutablePath()
        centered.addPath(outline, transform: CGAffineTransform(translationX: -box.midX, y: -box.midY))
        let shape = SKShapeNode(path: centered)
        shape.fillColor = color
        shape.strokeColor = .clear
        shape.isAntialiased = true
        shape.name = name
        return shape
    }

    @discardableResult
    func addLabel(_ text: String, font: String, size: CGFloat, color: SKColor, at point: CGPoint,
                          alignment: SKLabelHorizontalAlignmentMode, name: String? = nil, z: CGFloat = 2) -> SKLabelNode {
        let label = makeLabel(text, font: font, size: size, color: color, alignment: alignment, name: name)
        label.position = point
        label.zPosition = z
        addChild(label)
        return label
    }

    func makeLabel(_ text: String, font: String, size: CGFloat, color: SKColor,
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

    func makeSymbol(_ systemName: String, pointSize: CGFloat, color: SKColor) -> SKSpriteNode? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
            .applying(UIImage.SymbolConfiguration(paletteColors: [color]))
        guard let symbol = UIImage(systemName: systemName, withConfiguration: configuration) else { return nil }
        // SKTexture ignores symbol tinting, so bake the color into a bitmap first.
        let image = UIGraphicsImageRenderer(size: symbol.size).image { _ in symbol.draw(at: .zero) }
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.size = image.size
        return sprite
    }

    func makeCrossBadge(radius: CGFloat) -> SKShapeNode {
        let badge = SKShapeNode(circleOfRadius: radius)
        badge.fillColor = Palette.coral
        badge.strokeColor = .clear
        if let cross = makeSymbol("xmark", pointSize: radius * 0.8, color: .white) {
            cross.zPosition = 1
            badge.addChild(cross)
        }
        return badge
    }

    /// A piece of an inline row: some text, or an SF Symbol.
    enum InlinePart {
        case text(String)
        case symbol(String)
    }

    /// Lays text and SF Symbols out left to right on one line, aligned around the node's origin.
    func makeInlineRow(_ parts: [InlinePart], font: String, size: CGFloat, color: SKColor,
                       symbolColor: SKColor? = nil, alignment: SKLabelHorizontalAlignmentMode = .center,
                       name: String? = nil) -> SKNode {
        let row = SKNode()
        row.name = name
        var pieces: [(node: SKNode, width: CGFloat)] = []
        for part in parts {
            switch part {
            case .text(let text):
                let label = makeLabel(text, font: font, size: size, color: color, alignment: .left, name: name)
                pieces.append((label, label.frame.width))
            case .symbol(let symbolName):
                guard let symbol = makeSymbol(symbolName, pointSize: size * 0.9, color: symbolColor ?? color) else { continue }
                symbol.name = name
                pieces.append((symbol, symbol.size.width))
            }
        }
        let gap = size * 0.3
        let total = pieces.map(\.width).reduce(0, +) + gap * CGFloat(max(0, pieces.count - 1))
        var x: CGFloat = alignment == .left ? 0 : (alignment == .right ? -total : -total / 2)
        for piece in pieces {
            piece.node.position = CGPoint(x: piece.node is SKLabelNode ? x : x + piece.width / 2, y: 0)
            row.addChild(piece.node)
            x += piece.width + gap
        }
        return row
    }

    /// Adds a rounded button body with a drop shadow beneath it. Every node carries
    /// `name` so a tap anywhere on the button resolves to its action.
    func addButtonBody(name: String, size: CGSize, fill: SKColor, stroke: SKColor = .clear,
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

    @discardableResult
    func addButton(title: String, name: String, size: CGSize, color: SKColor, at point: CGPoint,
                           fontSize: CGFloat = 16, zPosition: CGFloat = 3, in parent: SKNode? = nil,
                           symbol: String? = nil, trailingSymbol: String? = nil) -> SKShapeNode {
        let button = addButtonBody(name: name, size: size, fill: color, at: point,
                                   zPosition: zPosition, in: parent ?? self)
        let textColor = color == Palette.gold ? Palette.ink : SKColor.white
        var parts: [InlinePart] = []
        if let symbol { parts.append(.symbol(symbol)) }
        parts.append(.text(title))
        if let trailingSymbol { parts.append(.symbol(trailingSymbol)) }
        let label = makeInlineRow(parts, font: "AvenirNext-Heavy", size: fontSize, color: textColor, name: name)
        label.zPosition = 1
        button.addChild(label)
        return button
    }

    /// A quieter outlined button for secondary actions such as HOME and REPLAY.
    func addSecondaryButton(title: String, name: String, size: CGSize, at point: CGPoint, symbol: String? = nil) {
        let accent = game.world.accent
        let button = addButtonBody(name: name, size: size, fill: Palette.mix(Palette.cream, accent, 0.10),
                                   stroke: accent.withAlphaComponent(0.45), at: point, zPosition: 3, in: self)
        let label = makeInlineRow((symbol.map { [InlinePart.symbol($0)] } ?? []) + [.text(title)],
                                  font: "AvenirNext-Heavy", size: 13, color: Palette.mix(accent, Palette.ink, 0.35),
                                  name: name)
        label.zPosition = 1
        button.addChild(label)
    }

    /// Makes a call-to-action breathe: the button swells gently while a ring ripples out behind it.
    func pulse(_ button: SKShapeNode, size: CGSize, color: SKColor) {
        let grow = SKAction.scale(to: 1.05, duration: 0.6)
        grow.timingMode = .easeInEaseOut
        let shrink = SKAction.scale(to: 1.0, duration: 0.6)
        shrink.timingMode = .easeInEaseOut
        button.run(.repeatForever(.sequence([grow, shrink])), withKey: "pulse")

        let ring = SKShapeNode(rectOf: size, cornerRadius: size.height * 0.35)
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.position = button.position
        ring.zPosition = button.zPosition - 0.5
        ring.alpha = 0
        button.parent?.addChild(ring)
        ring.run(.repeatForever(.sequence([
            .group([.scale(to: 1, duration: 0), .fadeAlpha(to: 0.6, duration: 0)]),
            .group([.scale(to: 1.16, duration: 1.2), .fadeOut(withDuration: 1.2)])
        ])))
    }

    func addIconButton(systemName: String, name: String, size: CGSize, fillColor: SKColor, iconColor: SKColor,
                               stroke: SKColor = Palette.ink.withAlphaComponent(0.18), at point: CGPoint) {
        let button = addButtonBody(name: name, size: size, fill: fillColor,
                                   stroke: stroke, at: point, zPosition: 3, in: self)
        if let icon = makeSymbol(systemName, pointSize: 18, color: iconColor) {
            icon.name = name
            icon.zPosition = 1
            button.addChild(icon)
        } else {
            button.addChild(makeLabel("DEL", font: "AvenirNext-Heavy", size: 13, color: iconColor, name: name))
        }
    }

    func addChoiceButton(title: String, subtitle: String, name: String, size: CGSize,
                                 selected: Bool, at point: CGPoint, titleSymbol: String? = nil) {
        let theme = menuTheme
        let button = roundedRect(size: size, radius: 14,
                                 fill: selected ? theme.accent : theme.chip,
                                 stroke: selected ? theme.accent : theme.line.withAlphaComponent(0.14))
        button.position = point
        button.name = name
        button.zPosition = 5
        addChild(button)
        let titleParts: [InlinePart] = titleSymbol.map { [.symbol($0)] } ?? [.text(title)]
        let titleLabel = makeInlineRow(titleParts, font: "AvenirNext-Heavy", size: size.height < 50 ? 14 : 16,
                                       color: selected ? .white : theme.text, name: name)
        titleLabel.position.y = size.height * 0.15
        button.addChild(titleLabel)
        let subtitleLabel = makeLabel(subtitle, font: "AvenirNext-Medium", size: 9,
                                      color: selected ? .white.withAlphaComponent(0.80) : theme.subtext, name: name)
        subtitleLabel.position.y = -size.height * 0.22
        button.addChild(subtitleLabel)
        if selected {
            button.run(.sequence([.scale(to: 1.04, duration: 0.10), .scale(to: 1.00, duration: 0.10)]))
        }
    }

    func roundedRect(size: CGSize, radius: CGFloat, fill: SKColor, stroke: SKColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = stroke == .clear ? 0 : 1.5
        return node
    }

    func addSmallStat(title: String, value: String, x: CGFloat, y: CGFloat, name: String? = nil,
                              valueColor: SKColor = Palette.ink, titleColor: SKColor = Palette.muted) {
        addLabel(title, font: "AvenirNext-Bold", size: 8, color: titleColor,
                 at: CGPoint(x: x, y: y + 10), alignment: .right)
        addLabel(value, font: "AvenirNext-Heavy", size: 17, color: valueColor,
                 at: CGPoint(x: x, y: y - 5), alignment: .right, name: name)
    }
}
