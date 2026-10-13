import SpriteKit
import UIKit

// The first-time tutorial: the ladybug coaches the player through their first word on
// Storm level 1. The clock waits until it's done.
extension GameScene {
    enum TutorialStep: Int {
        case tapLetter, spellAndSubmit, goalBar, hint
    }

    var shouldRunTutorial: Bool {
        !UserDefaults.standard.bool(forKey: Self.tutorialKey)
            && activeLevel == Level(world: .storm, number: 1)
    }

    func advanceTutorial() {
        guard let step = tutorialStep else { return }
        if let next = TutorialStep(rawValue: step.rawValue + 1) {
            tutorialStep = next
        } else {
            tutorialStep = nil
            UserDefaults.standard.set(true, forKey: Self.tutorialKey)
            showStatus("Go for it!", color: Palette.teal)
        }
        haptics.select()
        render()
    }

    /// Steps 3 and 4 are read-and-tap; the first two wait for the player to act.
    var tutorialWaitsForTap: Bool {
        tutorialStep == .goalBar || tutorialStep == .hint
    }

    /// Draws the coach: a spotlight ring and bouncing pointer on the target, and the
    /// ladybug with a speech bubble explaining what to do.
    func drawTutorial() {
        guard let step = tutorialStep else { return }
        let area = pileArea == .zero ? safeFrame : pileArea
        let text: String
        var target: CGPoint?
        switch step {
        case .tapLetter:
            text = "Tap a bright letter to pick it up!"
            let firstLetter = game.bestAvailableRoundWord()?.first
            let exposed = game.exposedTileIDs.compactMap { $0 }
            let id = exposed.first { id in game.stacks.flatMap { $0 }.first { $0.id == id }?.letter == firstLetter }
                ?? exposed.first
            target = id.flatMap { nodeNamed("tile-\($0)")?.position }
        case .spellAndSubmit:
            text = "Spell a word of 3+ letters, then press SUBMIT!"
            target = nodeNamed("action-submit")?.position
        case .goalBar:
            text = "Words fill this bar. Reach the goal to pass!"
            target = goalBarCenter
        case .hint:
            text = "Stuck? Tap HINT and I'll fly in with a clue!"
            target = nodeNamed("action-hint")?.position
        }

        // The bubble and ladybug sit at the top of the board.
        let label = makeLabel(text, font: "AvenirNext-Heavy", size: 15, color: .white)
        let bubbleWidth = min(label.frame.width + 30, safeFrame.width - 96)
        label.fontSize = fittedFontSize(for: text, max: 15, width: bubbleWidth - 24)
        let bubbleHeight: CGFloat = 42
        let bubbleCenter = CGPoint(x: area.midX + 30, y: area.maxY - 34)
        let color = Palette.mix(game.world.accent, Palette.ink, 0.2).withAlphaComponent(0.92)
        let bubble = roundedRect(size: CGSize(width: bubbleWidth, height: bubbleHeight), radius: 21,
                                 fill: color, stroke: SKColor(white: 1, alpha: 0.35))
        bubble.position = bubbleCenter
        bubble.zPosition = 95
        label.zPosition = 1
        bubble.addChild(label)
        addChild(bubble)
        let bug = makeLogo(size: 58)
        bug.position = CGPoint(x: bubbleCenter.x - bubbleWidth / 2 - 32, y: bubbleCenter.y - 4)
        bug.zPosition = 96
        addChild(bug)
        if tutorialWaitsForTap {
            addLabel("Tap anywhere to continue", font: "AvenirNext-Bold", size: 11, color: SKColor(white: 1, alpha: 0.8),
                     at: CGPoint(x: bubbleCenter.x, y: bubbleCenter.y - 34), alignment: .center, z: 95)
        }

        // A pulsing ring and a bouncing pointer on whatever the player should look at.
        guard let target else { return }
        let ring = SKShapeNode(circleOfRadius: 34)
        ring.strokeColor = Palette.gold
        ring.lineWidth = 3
        ring.fillColor = Palette.gold.withAlphaComponent(0.12)
        ring.position = target
        ring.zPosition = 94
        addChild(ring)
        ring.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 0.95, duration: 0.5)])))
        // On the board the hand points down from above; on the controls it points in from
        // the side, so it never hides the word box or buttons.
        let onControls = target.y < area.minY
        let fromLeft = target.x > safeFrame.midX + 40
        let symbol = onControls ? (fromLeft ? "hand.point.right.fill" : "hand.point.left.fill") : "hand.point.down.fill"
        if let hand = makeSymbol(symbol, pointSize: 30, color: Palette.gold) {
            let offset = onControls ? CGPoint(x: fromLeft ? -64 : 64, y: 0) : CGPoint(x: 0, y: 58)
            hand.position = CGPoint(x: target.x + offset.x, y: target.y + offset.y)
            hand.zPosition = 96
            addChild(hand)
            let bob = onControls ? CGVector(dx: fromLeft ? 10 : -10, dy: 0) : CGVector(dx: 0, dy: -10)
            hand.run(.repeatForever(.sequence([.move(by: bob, duration: 0.4),
                                               .move(by: CGVector(dx: -bob.dx, dy: -bob.dy), duration: 0.4)])))
        }
    }
}
