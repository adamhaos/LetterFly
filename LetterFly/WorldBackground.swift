import SpriteKit
import UIKit

/// Look and feel for each world: colors, a menu symbol, and an animated backdrop
/// drawn entirely from SpriteKit shapes.
extension World {
    var accent: SKColor {
        switch self {
        case .storm: SKColor(red: 0.36, green: 0.48, blue: 0.64, alpha: 1)
        case .circus: SKColor(red: 0.85, green: 0.22, blue: 0.25, alpha: 1)
        case .road: SKColor(red: 0.93, green: 0.55, blue: 0.25, alpha: 1)
        case .water: SKColor(red: 0.12, green: 0.58, blue: 0.62, alpha: 1)
        case .volcano: SKColor(red: 0.90, green: 0.35, blue: 0.12, alpha: 1)
        case .space: SKColor(red: 0.42, green: 0.32, blue: 0.75, alpha: 1)
        case .myth: SKColor(red: 0.80, green: 0.60, blue: 0.22, alpha: 1)
        }
    }

    /// Dark tint for in-game panels, so the controls read as tinted glass over the world.
    var glass: SKColor {
        switch self {
        case .storm: SKColor(red: 0.09, green: 0.12, blue: 0.19, alpha: 0.8)
        case .circus: SKColor(red: 0.22, green: 0.04, blue: 0.07, alpha: 0.8)
        case .road: SKColor(red: 0.09, green: 0.09, blue: 0.20, alpha: 0.8)
        case .water: SKColor(red: 0.02, green: 0.13, blue: 0.19, alpha: 0.8)
        case .volcano: SKColor(red: 0.14, green: 0.04, blue: 0.04, alpha: 0.8)
        case .space: SKColor(red: 0.05, green: 0.04, blue: 0.14, alpha: 0.8)
        case .myth: SKColor(red: 0.10, green: 0.06, blue: 0.16, alpha: 0.8)
        }
    }

    /// A brighter accent for text and highlights on the dark glass panels.
    var accentLight: SKColor {
        switch self {
        case .storm: SKColor(red: 0.62, green: 0.76, blue: 0.96, alpha: 1)
        case .circus: SKColor(red: 1.00, green: 0.58, blue: 0.56, alpha: 1)
        case .road: SKColor(red: 1.00, green: 0.76, blue: 0.48, alpha: 1)
        case .water: SKColor(red: 0.48, green: 0.90, blue: 0.92, alpha: 1)
        case .volcano: SKColor(red: 1.00, green: 0.64, blue: 0.38, alpha: 1)
        case .space: SKColor(red: 0.74, green: 0.64, blue: 1.00, alpha: 1)
        case .myth: SKColor(red: 1.00, green: 0.86, blue: 0.52, alpha: 1)
        }
    }

    var symbolName: String {
        switch self {
        case .storm: "cloud.bolt.rain.fill"
        case .circus: "tent.fill"
        case .road: "car.fill"
        case .water: "fish.fill"
        case .volcano: "flame.fill"
        case .space: "moon.stars.fill"
        case .myth: "building.columns.fill"
        }
    }

    private var skyColors: (top: SKColor, bottom: SKColor) {
        switch self {
        case .storm: (SKColor(red: 0.13, green: 0.16, blue: 0.23, alpha: 1), SKColor(red: 0.29, green: 0.34, blue: 0.42, alpha: 1))
        case .circus: (SKColor(red: 0.42, green: 0.07, blue: 0.11, alpha: 1), SKColor(red: 0.20, green: 0.04, blue: 0.09, alpha: 1))
        case .road: (SKColor(red: 0.12, green: 0.14, blue: 0.30, alpha: 1), SKColor(red: 0.58, green: 0.33, blue: 0.36, alpha: 1))
        case .water: (SKColor(red: 0.09, green: 0.40, blue: 0.48, alpha: 1), SKColor(red: 0.03, green: 0.14, blue: 0.24, alpha: 1))
        case .volcano: (SKColor(red: 0.16, green: 0.05, blue: 0.06, alpha: 1), SKColor(red: 0.40, green: 0.11, blue: 0.05, alpha: 1))
        case .space: (SKColor(red: 0.02, green: 0.02, blue: 0.09, alpha: 1), SKColor(red: 0.10, green: 0.06, blue: 0.22, alpha: 1))
        case .myth: (SKColor(red: 0.07, green: 0.05, blue: 0.18, alpha: 1), SKColor(red: 0.36, green: 0.18, blue: 0.34, alpha: 1))
        }
    }

    /// A backdrop filling `size`, centered on the origin.
    func makeBackground(size: CGSize) -> SKNode {
        let root = SKNode()
        root.zPosition = -100
        let sky = SKSpriteNode(texture: Self.gradientTexture(top: skyColors.top, bottom: skyColors.bottom), size: size)
        root.addChild(sky)
        let bounds = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        switch self {
        case .storm: Self.decorateStorm(root, in: bounds)
        case .circus: Self.decorateCircus(root, in: bounds)
        case .road: Self.decorateRoad(root, in: bounds)
        case .water: Self.decorateWater(root, in: bounds)
        case .volcano: Self.decorateVolcano(root, in: bounds)
        case .space: Self.decorateSpace(root, in: bounds)
        case .myth: Self.decorateMyth(root, in: bounds)
        }
        // SKView ignores sibling order, so paint in insertion order with explicit z values.
        for (index, child) in root.children.enumerated() { child.zPosition = CGFloat(index) * 0.01 }
        return root
    }

    // MARK: - Worlds

    private static func decorateStorm(_ root: SKNode, in bounds: CGRect) {
        for index in 0..<4 {
            // Opaque puffs: translucent ones show seams where they overlap.
            let shade = 0.30 + 0.05 * CGFloat(index % 2)
            let cloud = makeCloud(width: bounds.width * CGFloat.random(in: 0.45...0.7),
                                  color: SKColor(red: shade, green: shade + 0.04, blue: shade + 0.12, alpha: 1))
            cloud.position = CGPoint(x: bounds.minX + bounds.width * CGFloat(index) / 3,
                                     y: bounds.maxY - CGFloat.random(in: 10...90))
            root.addChild(cloud)
            let drift = CGFloat.random(in: 18...40)
            cloud.run(.repeatForever(.sequence([
                .moveBy(x: drift, y: 0, duration: Double.random(in: 5...8)),
                .moveBy(x: -drift, y: 0, duration: Double.random(in: 5...8))
            ])))
        }
        for _ in 0..<70 {
            let drop = SKShapeNode(rectOf: CGSize(width: 1.5, height: CGFloat.random(in: 10...18)))
            drop.fillColor = SKColor(white: 1, alpha: CGFloat.random(in: 0.12...0.3))
            drop.strokeColor = .clear
            drop.zRotation = 0.2
            root.addChild(drop)
            loopAcross(drop, by: CGVector(dx: -bounds.height * 0.2, dy: -bounds.height - 40),
                     duration: Double.random(in: 0.7...1.1), in: bounds)
        }
        let flash = SKSpriteNode(color: .white, size: bounds.size)
        flash.alpha = 0
        root.addChild(flash)
        flash.run(.repeatForever(.sequence([
            .wait(forDuration: 5, withRange: 4),
            .fadeAlpha(to: 0.16, duration: 0.04), .fadeAlpha(to: 0, duration: 0.12),
            .fadeAlpha(to: 0.1, duration: 0.04), .fadeAlpha(to: 0, duration: 0.35)
        ])))
    }

    private static func decorateCircus(_ root: SKNode, in bounds: CGRect) {
        let apex = CGPoint(x: bounds.midX, y: bounds.maxY + 40)
        let stripeCount = 14
        for index in stride(from: 0, to: stripeCount, by: 2) {
            let left = bounds.minX - bounds.width * 0.5 + bounds.width * 2 * CGFloat(index) / CGFloat(stripeCount)
            let right = left + bounds.width * 2 / CGFloat(stripeCount)
            let path = CGMutablePath()
            path.move(to: apex)
            path.addLine(to: CGPoint(x: left, y: bounds.minY))
            path.addLine(to: CGPoint(x: right, y: bounds.minY))
            path.closeSubpath()
            let stripe = SKShapeNode(path: path)
            stripe.fillColor = SKColor(red: 1, green: 0.93, blue: 0.82, alpha: 0.07)
            stripe.strokeColor = .clear
            root.addChild(stripe)
        }
        for side in [-1.0, 1.0] {
            let beam = SKShapeNode(ellipseOf: CGSize(width: bounds.width * 0.5, height: bounds.height * 1.4))
            beam.fillColor = SKColor(red: 1, green: 0.95, blue: 0.75, alpha: 0.06)
            beam.strokeColor = .clear
            let pivot = SKNode()
            pivot.position = CGPoint(x: bounds.midX + side * bounds.width * 0.45, y: bounds.minY)
            beam.position = CGPoint(x: -side * bounds.width * 0.15, y: bounds.height * 0.6)
            pivot.addChild(beam)
            root.addChild(pivot)
            pivot.zRotation = side * 0.25
            pivot.run(.repeatForever(.sequence([
                .rotate(toAngle: -side * 0.25, duration: 4.5),
                .rotate(toAngle: side * 0.25, duration: 4.5)
            ])))
        }
        let pennantColors = [SKColor(red: 0.98, green: 0.72, blue: 0.24, alpha: 0.9),
                             SKColor(red: 0.12, green: 0.58, blue: 0.54, alpha: 0.9),
                             SKColor(red: 1, green: 0.95, blue: 0.85, alpha: 0.9)]
        let count = max(8, Int(bounds.width / 34))
        for index in 0..<count {
            let t = (CGFloat(index) + 0.5) / CGFloat(count)
            let sag = sin(t * .pi) * 26
            let pennant = SKShapeNode(path: triangle(width: 22, height: 26))
            pennant.fillColor = pennantColors[index % pennantColors.count]
            pennant.strokeColor = .clear
            pennant.position = CGPoint(x: bounds.minX + bounds.width * t, y: bounds.maxY - 12 - sag)
            root.addChild(pennant)
            pennant.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.08, duration: Double.random(in: 0.8...1.3)),
                .rotate(toAngle: -0.08, duration: Double.random(in: 0.8...1.3))
            ])))
        }
    }

    private static func decorateRoad(_ root: SKNode, in bounds: CGRect) {
        let horizonY = bounds.minY + bounds.height * 0.42
        for _ in 0..<30 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...1.4))
            star.fillColor = SKColor(white: 1, alpha: CGFloat.random(in: 0.3...0.7))
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat.random(in: bounds.minX...bounds.maxX),
                                    y: CGFloat.random(in: (horizonY + bounds.height * 0.25)...bounds.maxY))
            root.addChild(star)
        }
        let hills = CGMutablePath()
        hills.move(to: CGPoint(x: bounds.minX, y: horizonY))
        var x = bounds.minX
        while x < bounds.maxX {
            let width = CGFloat.random(in: 80...160)
            hills.addQuadCurve(to: CGPoint(x: x + width, y: horizonY),
                               control: CGPoint(x: x + width / 2, y: horizonY + CGFloat.random(in: 30...70)))
            x += width
        }
        hills.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        hills.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY))
        hills.closeSubpath()
        let land = SKShapeNode(path: hills)
        land.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1)
        land.strokeColor = .clear
        root.addChild(land)

        let road = CGMutablePath()
        road.move(to: CGPoint(x: bounds.midX - 6, y: horizonY))
        road.addLine(to: CGPoint(x: bounds.midX + 6, y: horizonY))
        road.addLine(to: CGPoint(x: bounds.midX + bounds.width * 0.7, y: bounds.minY))
        road.addLine(to: CGPoint(x: bounds.midX - bounds.width * 0.7, y: bounds.minY))
        road.closeSubpath()
        let asphalt = SKShapeNode(path: road)
        asphalt.fillColor = SKColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1)
        asphalt.strokeColor = SKColor(white: 1, alpha: 0.25)
        asphalt.lineWidth = 2
        root.addChild(asphalt)

        // Lane dashes rush toward the viewer, growing as they approach.
        let travel = horizonY - bounds.minY
        for index in 0..<6 {
            let dash = SKShapeNode(rectOf: CGSize(width: 6, height: 26), cornerRadius: 2)
            dash.fillColor = SKColor(red: 0.98, green: 0.82, blue: 0.35, alpha: 0.8)
            dash.strokeColor = .clear
            root.addChild(dash)
            let cycle = 2.4
            let run = SKAction.customAction(withDuration: cycle) { node, elapsed in
                let t = (CGFloat(elapsed) / CGFloat(cycle) + CGFloat(index) / 6).truncatingRemainder(dividingBy: 1)
                let eased = t * t
                node.position = CGPoint(x: bounds.midX, y: horizonY - travel * eased)
                node.setScale(0.1 + eased * 1.4)
            }
            dash.run(.repeatForever(run))
        }
    }

    private static func decorateWater(_ root: SKNode, in bounds: CGRect) {
        for index in 0..<4 {
            let top = bounds.minX + bounds.width * (0.1 + 0.25 * CGFloat(index))
            let path = CGMutablePath()
            path.move(to: CGPoint(x: top, y: bounds.maxY))
            path.addLine(to: CGPoint(x: top + 50, y: bounds.maxY))
            path.addLine(to: CGPoint(x: top - bounds.width * 0.1, y: bounds.minY + bounds.height * 0.2))
            path.addLine(to: CGPoint(x: top - bounds.width * 0.2, y: bounds.minY + bounds.height * 0.2))
            path.closeSubpath()
            let ray = SKShapeNode(path: path)
            ray.fillColor = SKColor(white: 1, alpha: 0.05)
            ray.strokeColor = .clear
            root.addChild(ray)
            ray.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.4, duration: Double.random(in: 2...3.5)),
                .fadeAlpha(to: 1, duration: Double.random(in: 2...3.5))
            ])))
        }
        let sand = SKShapeNode(ellipseOf: CGSize(width: bounds.width * 1.6, height: 120))
        sand.fillColor = SKColor(red: 0.55, green: 0.47, blue: 0.33, alpha: 0.55)
        sand.strokeColor = .clear
        sand.position = CGPoint(x: bounds.midX, y: bounds.minY)
        root.addChild(sand)
        for index in 0..<7 {
            let height = CGFloat.random(in: 70...150)
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addCurve(to: CGPoint(x: 0, y: height),
                          control1: CGPoint(x: 18, y: height * 0.33), control2: CGPoint(x: -18, y: height * 0.66))
            let weed = SKShapeNode(path: path)
            weed.strokeColor = SKColor(red: 0.20, green: 0.55, blue: 0.35, alpha: 0.6)
            weed.lineWidth = 5
            weed.lineCap = .round
            weed.position = CGPoint(x: bounds.minX + bounds.width * (CGFloat(index) + CGFloat.random(in: 0.2...0.8)) / 7,
                                    y: bounds.minY + 10)
            root.addChild(weed)
            weed.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.12, duration: Double.random(in: 1.6...2.4)),
                .rotate(toAngle: -0.12, duration: Double.random(in: 1.6...2.4))
            ])))
        }
        for _ in 0..<26 {
            let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            bubble.fillColor = SKColor(white: 1, alpha: 0.06)
            bubble.strokeColor = SKColor(white: 1, alpha: 0.35)
            bubble.lineWidth = 1
            root.addChild(bubble)
            loopAcross(bubble, by: CGVector(dx: 0, dy: bounds.height + 40),
                     duration: Double.random(in: 5...9), in: bounds)
        }
    }

    private static func decorateVolcano(_ root: SKNode, in bounds: CGRect) {
        let craterY = bounds.minY + bounds.height * 0.42
        let mountain = CGMutablePath()
        mountain.move(to: CGPoint(x: bounds.minX - 40, y: bounds.minY))
        mountain.addLine(to: CGPoint(x: bounds.midX - 50, y: craterY))
        mountain.addLine(to: CGPoint(x: bounds.midX + 50, y: craterY))
        mountain.addLine(to: CGPoint(x: bounds.maxX + 40, y: bounds.minY))
        mountain.closeSubpath()
        let rock = SKShapeNode(path: mountain)
        rock.fillColor = SKColor(red: 0.11, green: 0.05, blue: 0.05, alpha: 1)
        rock.strokeColor = .clear
        root.addChild(rock)

        let glow = SKShapeNode(ellipseOf: CGSize(width: 200, height: 90))
        glow.fillColor = SKColor(red: 1, green: 0.45, blue: 0.1, alpha: 0.16)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: bounds.midX, y: craterY + 6)
        root.addChild(glow)
        glow.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 0.5, duration: 1.4), .scale(to: 0.92, duration: 1.4)]),
            .group([.fadeAlpha(to: 1, duration: 1.4), .scale(to: 1, duration: 1.4)])
        ])))
        let lava = SKShapeNode(rectOf: CGSize(width: 100, height: 6), cornerRadius: 3)
        lava.fillColor = SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1)
        lava.strokeColor = .clear
        lava.position = CGPoint(x: bounds.midX, y: craterY)
        root.addChild(lava)

        let emberColors = [SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), SKColor(red: 1, green: 0.35, blue: 0.1, alpha: 1)]
        for index in 0..<30 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...3))
            ember.fillColor = emberColors[index % 2]
            ember.strokeColor = .clear
            root.addChild(ember)
            let rise = Double.random(in: 3...6)
            let drift = CGFloat.random(in: -120...120)
            ember.run(.repeatForever(.sequence([
                .run { ember.position = CGPoint(x: bounds.midX + CGFloat.random(in: -40...40), y: craterY); ember.alpha = 1 },
                .group([
                    .moveBy(x: drift, y: bounds.height * CGFloat.random(in: 0.4...0.75), duration: rise),
                    .fadeOut(withDuration: rise)
                ]),
                .wait(forDuration: Double.random(in: 0...1.5))
            ])))
        }
    }

    private static func decorateSpace(_ root: SKNode, in bounds: CGRect) {
        for _ in 0..<110 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.6))
            star.fillColor = .white
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.25...0.9)
            star.position = randomPoint(in: bounds)
            root.addChild(star)
            if Bool.random() {
                star.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.15, duration: Double.random(in: 0.8...2.5)),
                    .fadeAlpha(to: 0.9, duration: Double.random(in: 0.8...2.5))
                ])))
            }
        }
        let radius = min(bounds.width, bounds.height) * 0.28
        let planet = SKShapeNode(circleOfRadius: radius)
        planet.fillColor = SKColor(red: 0.55, green: 0.32, blue: 0.62, alpha: 0.55)
        planet.strokeColor = .clear
        planet.position = CGPoint(x: bounds.maxX - radius * 0.35, y: bounds.minY + bounds.height * 0.45)
        root.addChild(planet)
        let ring = SKShapeNode(ellipseOf: CGSize(width: radius * 3, height: radius * 0.7))
        ring.strokeColor = SKColor(red: 0.95, green: 0.75, blue: 0.5, alpha: 0.35)
        ring.lineWidth = 4
        ring.zRotation = 0.3
        ring.position = planet.position
        root.addChild(ring)

        let meteor = SKShapeNode(rectOf: CGSize(width: 70, height: 2), cornerRadius: 1)
        meteor.fillColor = SKColor(white: 1, alpha: 0.8)
        meteor.strokeColor = .clear
        meteor.zRotation = -0.45
        meteor.alpha = 0
        root.addChild(meteor)
        meteor.run(.repeatForever(.sequence([
            .wait(forDuration: 6, withRange: 6),
            .run {
                meteor.position = CGPoint(x: CGFloat.random(in: bounds.minX...bounds.midX), y: bounds.maxY - CGFloat.random(in: 20...140))
            },
            .fadeAlpha(to: 1, duration: 0.05),
            .group([.moveBy(x: 260, y: -125, duration: 0.6), .fadeOut(withDuration: 0.6)])
        ])))
    }

    /// Twilight over Olympus: twinkling stars, a temple on the horizon, golden embers
    /// rising and a faint aurora that drifts in rainbow colors.
    private static func decorateMyth(_ root: SKNode, in bounds: CGRect) {
        for _ in 0..<70 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.4))
            star.fillColor = SKColor(red: 1, green: 0.95, blue: 0.82, alpha: 1)
            star.strokeColor = .clear
            star.alpha = CGFloat.random(in: 0.2...0.8)
            star.position = CGPoint(x: CGFloat.random(in: bounds.minX...bounds.maxX),
                                    y: CGFloat.random(in: bounds.midY - bounds.height * 0.1...bounds.maxY))
            root.addChild(star)
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.15, duration: Double.random(in: 1...3)),
                .fadeAlpha(to: 0.85, duration: Double.random(in: 1...3))
            ])))
        }
        // A soft aurora: wide translucent bands that slowly shift hue.
        for index in 0..<3 {
            let band = SKShapeNode(ellipseOf: CGSize(width: bounds.width * 1.6, height: bounds.height * 0.16))
            band.fillColor = SKColor(hue: CGFloat(index) * 0.3, saturation: 0.6, brightness: 1, alpha: 0.07)
            band.strokeColor = .clear
            band.position = CGPoint(x: bounds.midX, y: bounds.maxY - bounds.height * (0.18 + 0.1 * CGFloat(index)))
            band.zRotation = -0.12 + 0.1 * CGFloat(index)
            root.addChild(band)
            band.run(.repeatForever(.customAction(withDuration: 12) { node, elapsed in
                guard let band = node as? SKShapeNode else { return }
                let hue = (CGFloat(elapsed) / 12 + CGFloat(index) * 0.3).truncatingRemainder(dividingBy: 1)
                band.fillColor = SKColor(hue: hue, saturation: 0.6, brightness: 1, alpha: 0.07)
            }))
            band.run(.repeatForever(.sequence([
                .moveBy(x: 30, y: 6, duration: 7), .moveBy(x: -30, y: -6, duration: 7)
            ])))
        }
        // A temple on the horizon: steps, six columns and a pediment.
        let stone = SKColor(red: 0.16, green: 0.10, blue: 0.22, alpha: 0.85)
        let width = min(bounds.width * 0.7, 340)
        let base = bounds.minY + bounds.height * 0.06
        let temple = SKNode()
        temple.position = CGPoint(x: bounds.midX, y: base)
        for (step, inset) in [(0, 0.0), (1, 0.04), (2, 0.08)] {
            let slab = SKShapeNode(rectOf: CGSize(width: width * (1 - inset * 2), height: 8))
            slab.fillColor = stone
            slab.strokeColor = .clear
            slab.position = CGPoint(x: 0, y: CGFloat(step) * 8 + 4)
            temple.addChild(slab)
        }
        let columnWidth = width * 0.07
        let columnHeight = width * 0.36
        for index in 0..<6 {
            let column = SKShapeNode(rectOf: CGSize(width: columnWidth, height: columnHeight))
            column.fillColor = stone
            column.strokeColor = .clear
            column.position = CGPoint(x: -width * 0.36 + CGFloat(index) * width * 0.144, y: 24 + columnHeight / 2)
            temple.addChild(column)
        }
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: -width * 0.46, y: 24 + columnHeight))
        roof.addLine(to: CGPoint(x: width * 0.46, y: 24 + columnHeight))
        roof.addLine(to: CGPoint(x: 0, y: 24 + columnHeight + width * 0.16))
        roof.closeSubpath()
        let pediment = SKShapeNode(path: roof)
        pediment.fillColor = stone
        pediment.strokeColor = .clear
        temple.addChild(pediment)
        root.addChild(temple)
        let ground = SKSpriteNode(color: stone, size: CGSize(width: bounds.width, height: base - bounds.minY + 1))
        ground.position = CGPoint(x: bounds.midX, y: (bounds.minY + base) / 2)
        root.addChild(ground)
        // Golden embers drift up past the temple.
        for _ in 0..<26 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.4))
            ember.fillColor = SKColor(red: 1, green: 0.8, blue: 0.4, alpha: 1)
            ember.strokeColor = .clear
            ember.alpha = CGFloat.random(in: 0.3...0.8)
            root.addChild(ember)
            loopAcross(ember, by: CGVector(dx: CGFloat.random(in: -40...40), dy: bounds.height + 40),
                       duration: Double.random(in: 9...16), in: bounds)
        }
    }

    // MARK: - Helpers

    private static func gradientTexture(top: SKColor, bottom: SKColor) -> SKTexture {
        let size = CGSize(width: 4, height: 256)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])
            else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: image)
    }

    private static func makeCloud(width: CGFloat, color: SKColor) -> SKNode {
        let cloud = SKNode()
        for (x, y, radius) in [(-0.32, 0.0, 0.2), (-0.1, 0.08, 0.27), (0.15, 0.04, 0.24), (0.34, -0.02, 0.17)] {
            let puff = SKShapeNode(circleOfRadius: width * radius)
            puff.fillColor = color
            puff.strokeColor = .clear
            puff.position = CGPoint(x: width * x, y: width * y)
            cloud.addChild(puff)
        }
        return cloud
    }

    private static func triangle(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: 0))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -height))
        path.closeSubpath()
        return path
    }

    private static func randomPoint(in bounds: CGRect) -> CGPoint {
        CGPoint(x: CGFloat.random(in: bounds.minX...bounds.maxX), y: CGFloat.random(in: bounds.minY...bounds.maxY))
    }

    /// Sweeps `node` across the screen along `vector` forever, starting just past the edge it
    /// travels away from. A random phase spreads nodes out from the first frame.
    private static func loopAcross(_ node: SKNode, by vector: CGVector, duration: TimeInterval, in bounds: CGRect) {
        let startY = vector.dy < 0 ? bounds.maxY + 20 : bounds.minY - 20
        let startX = CGFloat.random(in: min(bounds.minX, bounds.minX - vector.dx)...max(bounds.maxX, bounds.maxX - vector.dx))
        let phase = CGFloat.random(in: 0..<1)
        node.run(.repeatForever(.customAction(withDuration: duration) { node, elapsed in
            let t = (CGFloat(elapsed / duration) + phase).truncatingRemainder(dividingBy: 1)
            node.position = CGPoint(x: startX + vector.dx * t, y: startY + vector.dy * t)
        }))
    }
}
