import SpriteKit
import UIKit

extension MythTrial.Kind {
    /// Each trial's own color on the rainbow road.
    var color: SKColor {
        switch self {
        case .icarus: SKColor(red: 1.00, green: 0.58, blue: 0.24, alpha: 1)
        case .ouroboros: SKColor(red: 0.26, green: 0.76, blue: 0.50, alpha: 1)
        case .sphinx: SKColor(red: 0.36, green: 0.64, blue: 0.96, alpha: 1)
        case .midas: SKColor(red: 0.98, green: 0.78, blue: 0.24, alpha: 1)
        case .fates: SKColor(red: 0.68, green: 0.46, blue: 0.96, alpha: 1)
        case .hydra: SKColor(red: 0.90, green: 0.30, blue: 0.36, alpha: 1)
        }
    }
}

// Starting a Myth trial: the trial's name turns into its little character, and the bug
// and the character fly at each other, clash over the trial's stop, then dive into it.
extension GameScene {
    /// A small cartoon of the trial's figure, about `s` points across.
    func makeMythCharacter(_ kind: MythTrial.Kind, size s: CGFloat) -> SKNode {
        let node = SKNode()
        let ink = SKColor(red: 0.13, green: 0.16, blue: 0.26, alpha: 1)
        @discardableResult
        func circle(_ radius: CGFloat, _ color: SKColor, at x: CGFloat, _ y: CGFloat, z: CGFloat = 0) -> SKShapeNode {
            let shape = SKShapeNode(circleOfRadius: radius * s)
            shape.fillColor = color
            shape.strokeColor = .clear
            shape.position = CGPoint(x: x * s, y: y * s)
            shape.zPosition = z
            node.addChild(shape)
            return shape
        }
        func rect(_ w: CGFloat, _ h: CGFloat, _ color: SKColor, at x: CGFloat, _ y: CGFloat, z: CGFloat = 0,
                  rotation: CGFloat = 0, corner: CGFloat = 0) {
            let shape = SKShapeNode(rectOf: CGSize(width: w * s, height: h * s), cornerRadius: corner * s)
            shape.fillColor = color
            shape.strokeColor = .clear
            shape.position = CGPoint(x: x * s, y: y * s)
            shape.zRotation = rotation
            shape.zPosition = z
            node.addChild(shape)
        }
        /// Determined little eyes with brows, looking ahead.
        func face(at x: CGFloat, _ y: CGFloat, scale k: CGFloat = 1, z: CGFloat = 2) {
            for side: CGFloat in [-1, 1] {
                circle(0.11 * k, .white, at: x + side * 0.15 * k, y + 0.04 * k, z: z)
                circle(0.055 * k, ink, at: x + side * 0.15 * k + 0.02 * k, y + 0.03 * k, z: z + 0.1)
                // Inner ends low: a determined frown.
                rect(0.17 * k, 0.045 * k, ink, at: x + side * 0.14 * k, y + 0.17 * k, z: z + 0.1, rotation: side * 0.4, corner: 0.02 * k)
            }
            let mouth = SKShapeNode(rectOf: CGSize(width: 0.16 * k * s, height: 0.035 * k * s), cornerRadius: 0.017 * k * s)
            mouth.fillColor = ink
            mouth.strokeColor = .clear
            mouth.position = CGPoint(x: x * s, y: (y - 0.16 * k) * s)
            mouth.zPosition = z + 0.1
            node.addChild(mouth)
        }
        let color = kind.color
        switch kind {
        case .icarus:
            // A sun halo and wax-and-feather wings.
            let halo = circle(0.62, .clear, at: 0, 0, z: -2)
            halo.strokeColor = Palette.gold.withAlphaComponent(0.7)
            halo.lineWidth = 0.06 * s
            for side: CGFloat in [-1, 1] {
                rect(0.55, 0.26, SKColor(white: 1, alpha: 0.95), at: side * 0.55, 0.08, z: -1, rotation: side * 0.45, corner: 0.13)
                rect(0.4, 0.18, Palette.cream, at: side * 0.62, -0.08, z: -1, rotation: side * 0.25, corner: 0.09)
            }
            circle(0.42, color, at: 0, 0, z: 0)
            face(at: 0, 0)
        case .ouroboros:
            // A serpent curled into a ring, its head biting toward its tail.
            let ring = circle(0.4, .clear, at: 0, -0.04, z: 0)
            ring.strokeColor = color
            ring.lineWidth = 0.16 * s
            for index in 0..<6 {
                let angle = CGFloat(index) * .pi / 3
                circle(0.04, Palette.mix(color, .white, 0.4), at: cos(angle) * 0.4, sin(angle) * 0.4 - 0.04, z: 0.5)
            }
            circle(0.22, color, at: 0.3, 0.26, z: 1)
            face(at: 0.3, 0.26, scale: 0.6, z: 2)
        case .sphinx:
            // A lion-bodied guardian in a striped headdress.
            let blue = SKColor(red: 0.20, green: 0.38, blue: 0.80, alpha: 1)
            for side: CGFloat in [-1, 1] {
                rect(0.24, 0.66, blue, at: side * 0.4, -0.12, z: -1, corner: 0.06)
                rect(0.24, 0.06, Palette.gold, at: side * 0.4, -0.02, z: -0.9)
                rect(0.24, 0.06, Palette.gold, at: side * 0.4, -0.22, z: -0.9)
            }
            rect(0.88, 0.2, blue, at: 0, 0.36, z: 0.5, corner: 0.08)
            rect(0.88, 0.05, Palette.gold, at: 0, 0.32, z: 0.6)
            circle(0.4, SKColor(red: 0.90, green: 0.74, blue: 0.46, alpha: 1), at: 0, 0, z: 0)
            face(at: 0, -0.02)
        case .midas:
            // A golden king in his crown.
            circle(0.42, color, at: 0, 0, z: 0)
            if let crown = makeSymbol("crown.fill", pointSize: 0.5 * s, color: Palette.mix(color, ink, 0.25)) {
                crown.position = CGPoint(x: 0, y: 0.48 * s)
                crown.zPosition = 1
                node.addChild(crown)
            }
            face(at: 0, 0)
        case .fates:
            // A hooded sister holding her shears.
            let hood = CGMutablePath()
            hood.move(to: CGPoint(x: -0.55 * s, y: -0.45 * s))
            hood.addQuadCurve(to: CGPoint(x: 0, y: 0.62 * s), control: CGPoint(x: -0.6 * s, y: 0.45 * s))
            hood.addQuadCurve(to: CGPoint(x: 0.55 * s, y: -0.45 * s), control: CGPoint(x: 0.6 * s, y: 0.45 * s))
            hood.closeSubpath()
            let cloak = SKShapeNode(path: hood)
            cloak.fillColor = Palette.mix(color, ink, 0.35)
            cloak.strokeColor = .clear
            cloak.zPosition = -1
            node.addChild(cloak)
            circle(0.3, Palette.mix(color, .white, 0.35), at: 0, 0.02, z: 0)
            face(at: 0, 0.02, scale: 0.8)
            if let shears = makeSymbol("scissors", pointSize: 0.36 * s, color: .white) {
                shears.position = CGPoint(x: 0.42 * s, y: -0.32 * s)
                shears.zPosition = 3
                node.addChild(shears)
            }
        case .hydra:
            // Three heads on swaying necks.
            for (x, y) in [(-0.36, 0.26), (0.0, 0.42), (0.36, 0.26)] as [(CGFloat, CGFloat)] {
                let neck = CGMutablePath()
                neck.move(to: CGPoint(x: 0, y: -0.45 * s))
                neck.addQuadCurve(to: CGPoint(x: x * s, y: y * s), control: CGPoint(x: x * 0.2 * s, y: 0))
                let stalk = SKShapeNode(path: neck)
                stalk.strokeColor = Palette.mix(color, ink, 0.25)
                stalk.lineWidth = 0.16 * s
                stalk.lineCap = .round
                stalk.zPosition = -1
                node.addChild(stalk)
                circle(0.2, color, at: x, y, z: 0)
                face(at: x, y, scale: 0.55, z: 1)
            }
            circle(0.22, Palette.mix(color, ink, 0.25), at: 0, -0.45, z: -0.5)
        }
        return node
    }

    /// The Myth version of the portal: name to character, a head-to-head clash over the
    /// stop, then both dive into it and the trial begins.
    func launchIntoTrial(then begin: @escaping () -> Void) {
        let index = selectedLevel.number - 1
        guard let kind = selectedLevel.trial,
              let logo = childNode(withName: "home-logo"),
              let stop = children.first(where: { $0.name == "action-level-\(index + 1)" && $0 is SKShapeNode }) else {
            begin()
            return
        }
        let label = children.first { $0.name == "myth-stop-label" && ($0.userData?["index"] as? Int) == index }
        isAnimatingFeedback = true
        logo.removeAllActions()
        let center = stop.position
        let start = label?.position ?? CGPoint(x: center.x - 70, y: center.y)
        // The two meet from opposite sides of the stop.
        let bugSide: CGFloat = logo.position.x >= center.x ? 1 : -1

        // 1. The name bursts and the character appears in its place.
        label?.run(.group([.scale(to: 0.2, duration: 0.25), .fadeOut(withDuration: 0.25)]))
        for burst in 0..<12 {
            let mote = SKShapeNode(circleOfRadius: 2.5)
            mote.fillColor = burst.isMultiple(of: 2) ? kind.color : .white
            mote.strokeColor = .clear
            mote.position = start
            mote.zPosition = 31
            addChild(mote)
            let angle = CGFloat(burst) / 12 * .pi * 2
            mote.run(.sequence([.group([.moveBy(x: cos(angle) * 30, y: sin(angle) * 30, duration: 0.35),
                                        .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        }
        let foe = makeMythCharacter(kind, size: 46)
        foe.position = start
        foe.zPosition = 32
        foe.setScale(0)
        addChild(foe)
        foe.run(.sequence([.wait(forDuration: 0.15), .scale(to: 1.25, duration: 0.18), .scale(to: 1, duration: 0.12)]))
        sound.play(.shuffle)
        haptics.tap(.medium)

        // 2. Both fly in and square up on either side of the stop.
        let bugSpot = CGPoint(x: center.x + bugSide * 34, y: center.y + 4)
        let foeSpot = CGPoint(x: center.x - bugSide * 34, y: center.y + 4)
        setFacing(logo, left: bugSide > 0)
        logo.zPosition = 33
        let bugFly = SKAction.move(to: bugSpot, duration: 0.45)
        bugFly.timingMode = .easeInEaseOut
        let foeArc = CGMutablePath()
        foeArc.move(to: start)
        foeArc.addQuadCurve(to: foeSpot, control: CGPoint(x: (start.x + foeSpot.x) / 2, y: max(start.y, foeSpot.y) + 40))
        let foeFly = SKAction.follow(foeArc, asOffset: false, orientToPath: false, duration: 0.45)
        foeFly.timingMode = .easeInEaseOut
        logo.run(.sequence([.wait(forDuration: 0.45), .group([bugFly, .scale(to: 0.8, duration: 0.45)])]))
        foe.run(.sequence([.wait(forDuration: 0.45), foeFly]))

        // 3. Head to head: they lunge at each other twice, sparks flying.
        let lunge = { (side: CGFloat) -> SKAction in
            .sequence([.moveBy(x: -side * 10, y: 0, duration: 0.08), .moveBy(x: side * 10, y: 0, duration: 0.1),
                       .wait(forDuration: 0.06),
                       .moveBy(x: -side * 10, y: 0, duration: 0.08), .moveBy(x: side * 10, y: 0, duration: 0.1)])
        }
        // 4. Then the stop opens and both spiral into it.
        let dive = SKAction.group([.move(to: center, duration: 0.35), .rotate(byAngle: .pi * 2.5, duration: 0.35),
                                   .scale(to: 0, duration: 0.35)])
        dive.timingMode = .easeIn
        logo.run(.sequence([.wait(forDuration: 0.95), lunge(bugSide), .wait(forDuration: 0.1), dive]))
        foe.run(.sequence([.wait(forDuration: 0.95), lunge(-bugSide), .wait(forDuration: 0.1), dive, .removeFromParent()]))

        // The timing that matters runs on the scene, so the trial always starts.
        run(.sequence([
            .wait(forDuration: 1.03),
            .run { [weak self] in self?.clashSparks(at: center, color: kind.color) },
            .wait(forDuration: 0.24),
            .run { [weak self] in self?.clashSparks(at: center, color: kind.color) },
            .wait(forDuration: 0.25),
            .run { [weak self] in self?.openTrialPortal(at: center, kind: kind) },
            .wait(forDuration: 0.4),
            .run { [weak self] in self?.floodTrialPortal() },
            .wait(forDuration: 0.45),
            .run { [weak self] in
                self?.isAnimatingFeedback = false
                begin()
            }
        ]), withKey: "portal")
    }

    private func clashSparks(at point: CGPoint, color: SKColor) {
        for index in 0..<10 {
            let spark = SKShapeNode(rectOf: CGSize(width: 2.5, height: 9), cornerRadius: 1.2)
            spark.fillColor = index.isMultiple(of: 2) ? color : Palette.gold
            spark.strokeColor = .clear
            let angle = CGFloat.random(in: 0...(2 * .pi))
            spark.zRotation = angle - .pi / 2
            spark.position = CGPoint(x: point.x, y: point.y + 8)
            spark.zPosition = 34
            addChild(spark)
            spark.run(.sequence([.group([.moveBy(x: cos(angle) * 34, y: sin(angle) * 34, duration: 0.25),
                                         .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        }
        haptics.tap(.heavy)
        sound.play(.reject)
    }

    /// The stop swirls open: rings in the trial's color and a window onto Myth inside it.
    private func openTrialPortal(at center: CGPoint, kind: MythTrial.Kind) {
        let portal = SKNode()
        portal.position = center
        portal.zPosition = 31
        portal.name = "trial-portal"
        addChild(portal)
        let window = SKCropNode()
        let hole = SKShapeNode(circleOfRadius: 24)
        hole.fillColor = .white
        hole.strokeColor = .clear
        hole.name = "portal-hole"
        hole.setScale(0)
        window.maskNode = hole
        let scenery = World.myth.makeBackground(size: size)
        scenery.position = CGPoint(x: -center.x, y: -center.y)
        window.addChild(scenery)
        portal.addChild(window)
        hole.run(.scale(to: 1, duration: 0.3))
        for (index, color) in [kind.color, Palette.gold, Palette.mix(kind.color, .white, 0.5)].enumerated() {
            let ring = SKShapeNode()
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: 28 + CGFloat(index) * 4, startAngle: 0, endAngle: .pi * 1.3, clockwise: false)
            ring.path = path
            ring.strokeColor = color
            ring.lineWidth = 3
            ring.lineCap = .round
            ring.zPosition = 1
            ring.name = "portal-ring"
            ring.setScale(0)
            portal.addChild(ring)
            ring.run(.scale(to: 1, duration: 0.25))
            ring.run(.repeatForever(.rotate(byAngle: (index % 2 == 0 ? 1 : -1) * .pi * 2, duration: 0.6 + Double(index) * 0.1)))
        }
        sound.play(.themeWord)
        haptics.success()
    }

    /// The opening grows until Myth fills the screen.
    private func floodTrialPortal() {
        guard let portal = childNode(withName: "trial-portal") else { return }
        let reach = hypot(size.width, size.height) / 24 + 1
        let flood = SKAction.scale(to: reach, duration: 0.45)
        flood.timingMode = .easeIn
        // The mask isn't in the node tree, so reach it through its crop node.
        portal.children.compactMap { ($0 as? SKCropNode)?.maskNode }.first?.run(flood)
        for ring in portal.children where ring.name == "portal-ring" {
            ring.run(.group([.scale(to: 5, duration: 0.35), .fadeOut(withDuration: 0.35)]))
        }
    }
}
