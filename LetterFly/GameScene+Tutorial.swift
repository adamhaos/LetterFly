import SpriteKit
import UIKit

// The first-time tutorial, which lasts the whole of Storm level 1. With the clock stopped,
// the ladybug tours the screen, explains that the pile is the level's star words stacked
// in layers, and walks the player through spelling the first one. Then the clock starts,
// and the bug drops back in at natural moments with tips on the rest of the controls.
extension GameScene {
    enum TutorialStep: Int {
        // The opening tour, with the clock stopped.
        case welcome, goal, layers, starDots, spellStar, starFound, nextLayer, goalBar
        // Tips during the round, each shown at most once.
        case scoring, redLetter, hint, mix, fixMistakes, timeBonus
    }

    var shouldRunTutorial: Bool {
        !UserDefaults.standard.bool(forKey: Self.tutorialKey)
            && activeLevel == Level(world: .storm, number: 1)
    }

    /// Sets up the tutorial for a new round, if this round gets one.
    func prepareTutorial() {
        coachQueue = []
        coachShown = []
        coachIdle = 0
        coachWords = 0
        tutorialWord = nil
        tutorialWordIsNewStar = false
        isCoachingRound = shouldRunTutorial
        guard isCoachingRound else {
            tutorialStep = nil
            return
        }
        // Level words are stacked top layer first, so the first one is all uncovered.
        tutorialTileIDs = Set(game.exposedTileIDs.compactMap { $0 })
        if let word = game.roundWords.first {
            tutorialWord = word
            if let level = activeLevel {
                tutorialWordIsNewStar = level.starWords.contains(word)
                    && !progress.foundWords(in: level).contains(word.lowercased())
            }
        }
        coachQueue = [.welcome, .goal, .layers, .starDots, .spellStar, .starFound, .nextLayer, .goalBar]
        if tutorialWord == nil { coachQueue.removeAll { [.spellStar, .starFound, .nextLayer].contains($0) } }
        showNextCoachStep()
        statusMessage = ""
    }

    /// Queues tips to show now (or right after the current one), skipping any already seen.
    func coach(_ steps: [TutorialStep]) {
        guard isCoachingRound, screen == .playing else { return }
        let fresh = steps.filter { !coachShown.contains($0) && !coachQueue.contains($0) && $0 != tutorialStep }
        guard !fresh.isEmpty else { return }
        coachQueue += fresh
        if tutorialStep == nil {
            showNextCoachStep()
            render()
        }
    }

    func showNextCoachStep() {
        // A tip about red letters only makes sense while one is showing; it waits for one.
        coachQueue.removeAll { $0 == .redLetter && exposedBonusTileID == nil }
        guard !coachQueue.isEmpty else {
            tutorialStep = nil
            return
        }
        let next = coachQueue.removeFirst()
        coachShown.insert(next)
        tutorialStep = next
        tutorialShownAt = currentTime
        coachIdle = 0
    }

    func advanceTutorial() {
        guard let step = tutorialStep else { return }
        // A short grace period, so a tap meant for the board doesn't skip a tip unread.
        guard currentTime - tutorialShownAt > 0.5 else { return }
        showNextCoachStep()
        if step == .goalBar {
            // The tour is over; the rest of the tutorial happens as the player plays, and
            // the home screen gets its own tour next time the player is there.
            UserDefaults.standard.set(true, forKey: Self.tutorialKey)
            UserDefaults.standard.set(true, forKey: Self.homeTourPendingKey)
            showStatus("The clock is running — go for it!", color: Palette.teal, duration: 2.4)
        }
        haptics.select()
        render()
    }

    /// The player's next move while spelling the tutorial word: a letter to tap, a wrong
    /// letter to take back, or the finished word to submit.
    enum SpellingMove { case tap(Int), takeBack, submit }

    var spellingMove: SpellingMove? {
        guard let word = tutorialWord else { return nil }
        let typed = game.currentWord
        if typed == word { return .submit }
        guard word.hasPrefix(typed) else { return .takeBack }
        let letter = Array(word)[typed.count]
        // Use the word's own top-layer letters, not a match uncovered beneath one, so the
        // next layer's word stays whole.
        let matches = game.exposedTileIDs.compactMap { $0 }.filter { tileLetter($0) == letter }
        let id = matches.first { tutorialTileIDs.contains($0) } ?? matches.first
        return id.map(SpellingMove.tap)
    }

    func tileLetter(_ id: Int) -> Character? {
        game.stacks.lazy.flatMap { $0 }.first { $0.id == id }?.letter
    }

    var exposedBonusTileID: Int? {
        game.exposedTileIDs.compactMap { $0 }.first { id in
            game.stacks.lazy.flatMap { $0 }.first { $0.id == id }?.isBonus == true
        }
    }

    /// Steps that only explain wait for a tap; spelling the word waits for the player.
    var tutorialWaitsForTap: Bool {
        tutorialStep != nil && tutorialStep != .spellStar
    }

    /// While the player spells the tutorial word, only the controls for spelling it work.
    func tutorialAllowsTap(on names: [String]) -> Bool {
        guard tutorialStep == .spellStar else { return true }
        if names.contains(where: { $0.hasPrefix("tile-") }) { return true }
        if names.contains("action-submit") { return game.currentWord == tutorialWord }
        return names.contains { ["action-undo", "action-clear", "action-exit"].contains($0) }
    }

    /// Counts toward the "stuck?" tip; called while the clock runs.
    func updateCoaching(delta: TimeInterval) {
        guard isCoachingRound, tutorialStep == nil, !isAnimatingFeedback else { return }
        if !game.isEndless, timeRemaining <= 20, !coachShown.contains(.timeBonus) {
            coach([.timeBonus])
            return
        }
        coachIdle = game.selectedTileIDs.isEmpty ? coachIdle + delta : 0
        if coachIdle >= 12 { coach([.hint, .mix]) }
        if coachWords > 0, game.selectedTileIDs.isEmpty, exposedBonusTileID != nil { coach([.redLetter]) }
    }

    /// Called once each accepted word has finished animating.
    func coachAfterWord() {
        // The guided word is part of the tour; tips start with the player's own words.
        guard isCoachingRound, coachShown.contains(.goalBar) else { return }
        coachWords += 1
        switch coachWords {
        case 1: coach([.scoring, .redLetter])
        case 2: coach([.hint, .mix])
        case 3: coach([.fixMistakes])
        default: break
        }
    }

    func endCoaching() {
        isCoachingRound = false
        tutorialStep = nil
        coachQueue = []
    }

    // MARK: Drawing

    /// The text and spotlight target for the current step.
    func tutorialContent(for step: TutorialStep) -> (text: String, target: SKNode?) {
        let world = game.world.title
        let word = tutorialWord ?? ""
        let goal = activeLevel?.targetScore ?? 0
        let starCount = Level.starWordCount
        switch step {
        case .welcome:
            return ("Hi! I'm your ladybug guide. TIME stops whenever I'm talking. Tap to go on.", nil)
        case .goal:
            return ("Reach the GOAL of \(goal) points before TIME runs out to pass. Your SCORE is up here too.",
                    nodeNamed("goal-label"))
        case .layers:
            return ("Each layer of this pile is a scrambled \(world) word. Taking a top letter uncovers the one below.",
                    nodeNamed("pile-area"))
        case .starDots:
            let all = activeLevel.map { $0.themeWords.count <= starCount } ?? false
            return ("\(all ? "All \(starCount) layers are" : "\(starCount) of these words are") this level's STAR WORDS. You can pass without them, but each one lights a dot.",
                    nodeNamed("star-balls"))
        case .spellStar:
            switch spellingMove {
            case .tap(let id)?:
                let text = game.currentWord.isEmpty
                    ? "The top letters spell \(word)\(tutorialWordIsNewStar ? ", a STAR WORD" : "")! Tap the letters I point to — they'll fill YOUR WORD."
                    : "Tap the letters I point to, in order."
                return (text, nodeNamed("tile-\(id)"))
            case .takeBack?:
                return ("Oops, not that one! Tap backspace to put it back.", nodeNamed("action-undo"))
            case .submit?:
                return ("You spelled \(word)! Tap SUBMIT to score it.", nodeNamed("action-submit"))
            case nil:
                return ("Spell \(word) with the top letters, then tap SUBMIT.", nodeNamed("action-submit"))
            }
        case .starFound:
            if tutorialWordIsNewStar {
                return ("STAR WORDS score double and stay found, even on replays. Find all \(starCount) for this level's bonus ★.",
                        nodeNamed("star-balls"))
            }
            return ("\(world) words score double! These \(starCount) dots are this level's STAR WORDS — find them all for a bonus ★.",
                    nodeNamed("star-balls"))
        case .nextLayer:
            return ("You uncovered another STAR WORD! Unscramble it, or make any word of 3+ letters. Every \(world) word scores double.",
                    nodeNamed("pile-area"))
        case .goalBar:
            if let level = activeLevel, game.score >= level.targetScore {
                return ("You reached the GOAL! Tap FINISH LEVEL anytime, or keep scoring. The clock starts now!",
                        nodeNamed("action-finish"))
            }
            return ("Each word fills this bar. Reach the GOAL to pass! The clock starts now.", nodeNamed("goal-bar"))
        case .scoring:
            return ("Nice! Rare letters are worth more, and longer words multiply them — a 6-letter word pays 4×.",
                    nodeNamed("score-label"))
        case .redLetter:
            return ("See this red letter? It's worth double points!", exposedBonusTileID.flatMap { nodeNamed("tile-\($0)") })
        case .hint:
            return ("Stuck? HINT shows the first and last letters of a word you can make.", nodeNamed("action-hint"))
        case .mix:
            return ("MIX shuffles the top letters to help you spot words. Shaking your phone works too!",
                    nodeNamed("action-shuffle"))
        case .fixMistakes:
            return ("Made a slip? Backspace removes your last letter, and CLEAR empties YOUR WORD.", nodeNamed("action-undo"))
        case .timeBonus:
            return ("20 seconds left! Clear every letter before TIME runs out for 5 bonus points per second left.",
                    nodeNamed("clock-label"))
        }
    }

    /// The node's frame in scene coordinates.
    func sceneFrame(of node: SKNode) -> CGRect {
        let frame = node.calculateAccumulatedFrame()
        guard let parent = node.parent, parent !== self else { return frame }
        let origin = parent.convert(frame.origin, to: self)
        return CGRect(origin: origin, size: frame.size)
    }

    /// Draws the coach: a spotlight and bouncing pointer on the target, and the ladybug
    /// with a speech bubble explaining what to do.
    func drawTutorial() {
        // The pause menu covers the bug; its artwork would otherwise poke through.
        guard let step = tutorialStep, !isConfirmingExit else { return }
        let (text, targetNode) = tutorialContent(for: step)
        drawCoach(text: text, targetNode: targetNode, area: pileArea == .zero ? safeFrame : pileArea,
                  waitsForTap: tutorialWaitsForTap, hidden: isShowingStarSplash)
    }

    /// The bug's speech bubble, kept within `area`, with a spotlight and pointer on the
    /// target: pointing up at things above the area, down at things in it, and in from
    /// the side at things beside or below it.
    /// Returns where the bug sits; pass `drawsBug: false` to bring your own bug there.
    @discardableResult
    func drawCoach(text: String, targetNode: SKNode?, area: CGRect, waitsForTap: Bool, hidden: Bool,
                   drawsBug: Bool = true) -> CGPoint {
        let target = targetNode.map(sceneFrame)
        // The whole pile gets a spotlight but no pointer.
        let isPile = targetNode?.name == "pile-area"

        // The bubble wraps long tips over a few lines.
        let bubbleWidth = min(area.width - 88, 320)
        let label = makeLabel(text, font: "AvenirNext-Heavy", size: 15, color: .white)
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = bubbleWidth - 28
        label.lineBreakMode = .byWordWrapping
        label.verticalAlignmentMode = .center
        let bubbleHeight = label.frame.height + 24 + (waitsForTap ? 16 : 0)

        // Region of the target decides where the pointer and bubble go.
        enum Region { case none, above, pile, controls }
        let region: Region = {
            guard let target, !isPile else { return .none }
            if target.minY >= area.maxY - 4 { return .above }
            return area.intersects(target) ? .pile : .controls
        }()
        let bubbleY: CGFloat
        switch region {
        case .none: bubbleY = area.midY
        case .above: bubbleY = min(target!.minY - 62, area.maxY - 8) - bubbleHeight / 2
        case .pile: bubbleY = target!.midY > area.midY ? area.minY + bubbleHeight / 2 + 8 : area.maxY - bubbleHeight / 2 - 8
        case .controls: bubbleY = area.minY + bubbleHeight / 2 + 8
        }
        let bubbleCenter = CGPoint(x: area.midX + 30, y: bubbleY)

        let tutorial = SKNode()
        tutorial.name = "tutorial"
        tutorial.zPosition = 94
        // The bug waits for a star-word splash to clear before speaking.
        if hidden { tutorial.alpha = 0 }
        addChild(tutorial)

        let color = Palette.mix(game.world.accent, Palette.ink, 0.2).withAlphaComponent(0.94)
        let bubble = roundedRect(size: CGSize(width: bubbleWidth, height: bubbleHeight), radius: min(21, bubbleHeight / 2),
                                 fill: color, stroke: SKColor(white: 1, alpha: 0.35))
        bubble.position = bubbleCenter
        bubble.zPosition = 1
        label.position = CGPoint(x: 0, y: waitsForTap ? 8 : 0)
        label.zPosition = 1
        bubble.addChild(label)
        if waitsForTap {
            let more = makeLabel("Tap anywhere to continue", font: "AvenirNext-Bold", size: 11,
                                 color: SKColor(white: 1, alpha: 0.7))
            more.position = CGPoint(x: 0, y: -bubbleHeight / 2 + 14)
            more.zPosition = 1
            bubble.addChild(more)
        }
        tutorial.addChild(bubble)
        let bugSpot = CGPoint(x: bubbleCenter.x - bubbleWidth / 2 - 32, y: bubbleCenter.y + min(0, bubbleHeight / 2 - 30))
        if drawsBug {
            let bug = makeLogo(size: 58)
            bug.position = bugSpot
            bug.zPosition = 2
            tutorial.addChild(bug)
        }

        // A pulsing spotlight on whatever the player should look at.
        guard let target else { return bugSpot }
        let size = CGSize(width: max(target.width + 18, 52), height: max(target.height + 14, 44))
        let ring = SKShapeNode(rectOf: size, cornerRadius: min(22, size.height / 2))
        ring.strokeColor = Palette.gold
        ring.lineWidth = 3
        ring.fillColor = Palette.gold.withAlphaComponent(isPile ? 0.04 : 0.12)
        ring.position = CGPoint(x: target.midX, y: target.midY)
        tutorial.addChild(ring)
        if !isPile {
            ring.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.5), .scale(to: 0.96, duration: 0.5)])))
        }

        // A bouncing hand: down onto letters, up at the top bar, in from the side on the
        // controls, so it never hides what it points at.
        let symbol: String
        let offset: CGPoint
        let fromLeft = target.midX > safeFrame.midX + 40
        switch region {
        case .none: return bugSpot
        case .above:
            symbol = "hand.point.up.fill"
            offset = CGPoint(x: 0, y: -size.height / 2 - 24)
        case .pile:
            symbol = "hand.point.down.fill"
            offset = CGPoint(x: 0, y: size.height / 2 + 26)
        case .controls:
            symbol = fromLeft ? "hand.point.right.fill" : "hand.point.left.fill"
            offset = CGPoint(x: (fromLeft ? -1 : 1) * (size.width / 2 + 28), y: 0)
        }
        guard let hand = makeSymbol(symbol, pointSize: 30, color: Palette.gold) else { return bugSpot }
        // Wide buttons would push a side-on hand off the screen.
        hand.position = CGPoint(x: min(max(target.midX + offset.x, safeFrame.minX + 18), safeFrame.maxX - 18),
                                y: target.midY + offset.y)
        hand.zPosition = 3
        tutorial.addChild(hand)
        let bob: CGVector = switch region {
        case .above: CGVector(dx: 0, dy: 10)
        case .pile: CGVector(dx: 0, dy: -10)
        default: CGVector(dx: fromLeft ? 10 : -10, dy: 0)
        }
        hand.run(.repeatForever(.sequence([.move(by: bob, duration: 0.4),
                                           .move(by: CGVector(dx: -bob.dx, dy: -bob.dy), duration: 0.4)])))
        return bugSpot
    }

    /// Shows a tip that was waiting behind a star-word splash.
    func revealTutorialAfterSplash() {
        guard let tutorial = childNode(withName: "tutorial"), tutorial.alpha < 1 else { return }
        tutorialShownAt = currentTime
        tutorial.run(.fadeIn(withDuration: 0.2))
    }
}
