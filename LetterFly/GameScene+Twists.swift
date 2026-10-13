import SpriteKit
import UIKit

extension World {
    /// What the world's boss level does, shown when the level starts.
    var bossTwist: String {
        switch self {
        case .storm: "Wind gusts scatter the letters!"
        case .circus: "Letters juggle places!"
        case .road: "Letters drive around in traffic!"
        case .water: "The current sways every letter!"
        case .volcano: "Unused letters burn up in the lava!"
        case .space: "Letters drift in low gravity!"
        }
    }

    var bossSymbol: String {
        switch self {
        case .storm: "wind"
        case .circus: "theatermasks.fill"
        case .road: "car.2.fill"
        case .water: "water.waves"
        case .volcano: "flame.fill"
        case .space: "sparkles"
        }
    }
}

// Endless mode and the boss-level twists, driven from `update`.
extension GameScene {
    // MARK: Endless

    var pileText: String { "\(game.remainingTileCount)/\(game.endlessCapacity)" }

    var pileColor: SKColor {
        let fill = Double(game.remainingTileCount) / Double(max(1, game.endlessCapacity))
        return fill > 0.85 ? Palette.coral : (fill > 0.7 ? Palette.gold : .white)
    }

    /// Drops letters on a schedule that speeds up as the round goes on.
    func updateEndless() {
        guard roundElapsed >= nextEventAt else { return }
        // Wait for word animations to finish so a redraw doesn't cut them off.
        guard !isAnimatingFeedback else { nextEventAt = roundElapsed + 0.3; return }
        nextEventAt = roundElapsed + max(1.6, 5.5 - roundElapsed / 30)
        dropLetters(1)
    }

    /// Drops `count` new letters onto the pile, each falling in from above.
    func dropLetters(_ count: Int) {
        var dropped: [Int] = []
        for _ in 0..<count { dropped.append(game.dropLetter().tile.id) }
        if game.remainingTileCount > game.endlessCapacity {
            finishRound(message: "The pile toppled!")
            return
        }
        render()
        for (index, id) in dropped.enumerated() {
            guard let node = nodeNamed("tile-\(id)") else { continue }
            let target = node.position
            node.position.y += size.height * 0.6
            node.alpha = 0
            let fall = SKAction.move(to: target, duration: 0.45)
            fall.timingMode = .easeIn
            node.run(.sequence([
                .wait(forDuration: Double(index) * 0.12),
                .group([fall, .fadeIn(withDuration: 0.15)]),
                .moveBy(x: 0, y: 8, duration: 0.07), .moveBy(x: 0, y: -8, duration: 0.09)
            ]))
        }
        sound.play(.tick)
        haptics.tap(.soft)
    }

    // MARK: Boss twists

    var bossWorld: World? {
        guard screen == .playing, let level = activeLevel, level.isBoss else { return nil }
        return level.world
    }

    /// Runs the active boss level's twist. Called every frame while playing.
    func updateTwists() {
        guard let world = bossWorld else { return }
        switch world {
        case .water, .space:
            floatLetters(world: world)
        case .volcano:
            updateLava()
        case .storm, .circus, .road:
            guard roundElapsed >= nextEventAt else { return }
            guard !isAnimatingFeedback else { nextEventAt = roundElapsed + 0.3; return }
            nextEventAt = roundElapsed + (world == .storm ? 9 : (world == .circus ? 8 : 7))
            rearrangePile(world: world)
        }
    }

    /// Storm scatters every stack to new spots; Circus swaps two stacks; Road shifts all
    /// stacks one place along, like traffic. Letters glide to their new spots.
    func rearrangePile(world: World) {
        var starts: [String: (CGPoint, CGFloat)] = [:]
        for child in children where child.name?.hasPrefix("tile-") == true {
            starts[child.name!] = (child.position, child.zRotation)
        }
        switch world {
        case .storm:
            layoutSeed = Int.random(in: 0..<1_000_000)
            windGust()
        case .circus:
            if var layout = cachedPileLayout, layout.bases.count > 1 {
                let picks = Array(layout.bases.indices.shuffled().prefix(2))
                layout.bases.swapAt(picks[0], picks[1])
                cachedPileLayout = layout
            }
        default:
            if var layout = cachedPileLayout, let last = layout.bases.last {
                layout.bases = [last] + layout.bases.dropLast()
                cachedPileLayout = layout
            }
        }
        render()
        for child in children where child.name?.hasPrefix("tile-") == true {
            guard let start = starts[child.name!] else { continue }
            let end = (child.position, child.zRotation)
            child.position = start.0
            child.zRotation = start.1
            let move: SKAction
            if world == .circus {
                // Juggled letters arc up and over.
                let path = CGMutablePath()
                path.move(to: start.0)
                path.addQuadCurve(to: end.0, control: CGPoint(x: (start.0.x + end.0.x) / 2,
                                                              y: max(start.0.y, end.0.y) + 110))
                move = .follow(path, asOffset: false, orientToPath: false, duration: 0.6)
            } else {
                move = .move(to: end.0, duration: 0.6)
            }
            move.timingMode = .easeInEaseOut
            child.run(.group([move, .rotate(toAngle: end.1, duration: 0.6, shortestUnitArc: true)]))
        }
        haptics.tap(.medium)
    }

    /// Streaks of wind blow across the board.
    func windGust() {
        let area = pileArea == .zero ? frame : pileArea
        for index in 0..<7 {
            let streak = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 60...140), height: 3), cornerRadius: 1.5)
            streak.fillColor = SKColor(white: 1, alpha: 0.5)
            streak.strokeColor = .clear
            streak.position = CGPoint(x: frame.minX - 100, y: CGFloat.random(in: area.minY...area.maxY))
            streak.zPosition = 60
            overlay.addChild(streak)
            streak.run(.sequence([
                .wait(forDuration: Double(index) * 0.05),
                .moveBy(x: frame.width + 250, y: -30, duration: 0.55),
                .removeFromParent()
            ]))
        }
        sound.play(.shuffle)
    }

    /// Water sways letters gently; Space lets them drift and turn slowly.
    func floatLetters(world: World) {
        let t = CGFloat(roundElapsed)
        for child in children where child.name?.hasPrefix("tile-") == true {
            guard child.action(forKey: "press") == nil,
                  let base = (child.userData?["base"] as? NSValue)?.cgPointValue,
                  let rotation = child.userData?["rotation"] as? CGFloat,
                  let id = Self.number(in: child.name!, after: "tile-") else { continue }
            let seed = CGFloat(id)
            if world == .water {
                child.position = CGPoint(x: base.x + 7 * sin(t * 1.3 + seed), y: base.y + 4 * sin(t * 1.7 + seed * 0.7))
                child.zRotation = rotation + 0.09 * sin(t * 1.1 + seed)
            } else {
                child.position = CGPoint(x: base.x + 9 * sin(t * 0.6 + seed), y: base.y + 11 * sin(t * 0.45 + seed * 1.3))
                child.zRotation = rotation + 0.28 * sin(t * 0.5 + seed)
            }
        }
    }

    /// Volcano: a letter left uncovered too long starts glowing, then burns away.
    func updateLava() {
        let glowAfter: TimeInterval = 10
        let burnAfter: TimeInterval = 15
        let exposed = Set(game.exposedTileIDs.compactMap { $0 })
        exposedSince = exposedSince.filter { exposed.contains($0.key) }
        for id in exposed where exposedSince[id] == nil { exposedSince[id] = roundElapsed }

        for (id, since) in exposedSince {
            let age = roundElapsed - since
            guard let node = nodeNamed("tile-\(id)") else { continue }
            if age >= burnAfter {
                guard !isAnimatingFeedback else { continue }
                burn(id: id, at: node.position)
                return
            }
            if age >= glowAfter, node.childNode(withName: "heat") == nil {
                let heat = SKShapeNode(circleOfRadius: 30)
                heat.name = "heat"
                heat.fillColor = SKColor(red: 1, green: 0.4, blue: 0.1, alpha: 0.35)
                heat.strokeColor = SKColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.8)
                heat.lineWidth = 2
                heat.zPosition = -0.1
                node.addChild(heat)
                heat.run(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.3), .scale(to: 0.9, duration: 0.3)])))
            }
        }
    }

    func burn(id: Int, at point: CGPoint) {
        guard game.burnTile(id: id) else { return }
        exposedSince[id] = nil
        let colors = [SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1), SKColor(red: 1, green: 0.3, blue: 0.1, alpha: 1),
                      SKColor(white: 0.3, alpha: 1)]
        for index in 0..<16 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            ember.fillColor = colors[index % colors.count]
            ember.strokeColor = .clear
            ember.position = point
            ember.zPosition = 60
            overlay.addChild(ember)
            ember.run(.sequence([
                .group([.moveBy(x: CGFloat.random(in: -40...40), y: CGFloat.random(in: 30...90), duration: 0.7),
                        .fadeOut(withDuration: 0.7)]),
                .removeFromParent()
            ]))
        }
        showStatus("A letter burned up!", color: Palette.coral)
        haptics.warning()
        if game.remainingTileCount < 3 {
            finishRound(message: "The lava won!")
            return
        }
        if game.prepareNextMove() == .none {
            finishRound(message: "No words left!")
            return
        }
        render()
    }
}
