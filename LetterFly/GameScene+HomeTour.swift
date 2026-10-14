import SpriteKit
import UIKit

// The home-screen tour: the first time the player is back home after the tutorial level,
// the ladybug points out the worlds, levels, star words and the buttons along the top.
extension GameScene {
    enum HomeTourStep: Int, CaseIterable {
        case welcome, worlds, levels, starWords, stats, rules, settings, play
    }

    static let homeTourPendingKey = "tutorial.homeTourPending"

    /// Starts the tour if it's waiting and the home screen can show it.
    func startHomeTourIfPending() {
        guard homeTourStep == nil, screen == .menu, menuOverlay == nil, selectedWorld != .myth,
              UserDefaults.standard.bool(forKey: Self.homeTourPendingKey) else { return }
        homeTourStep = .welcome
        tutorialShownAt = currentTime
    }

    func advanceHomeTour() {
        guard let step = homeTourStep, currentTime - tutorialShownAt > 0.5 else { return }
        if let next = HomeTourStep(rawValue: step.rawValue + 1) {
            homeTourStep = next
            tutorialShownAt = currentTime
        } else {
            homeTourStep = nil
            UserDefaults.standard.set(false, forKey: Self.homeTourPendingKey)
        }
        haptics.select()
        render()
    }

    func homeTourContent(for step: HomeTourStep) -> (text: String, target: SKNode?) {
        switch step {
        case .welcome:
            return ("Welcome home! Let me show you around.", nil)
        case .worlds:
            return ("These are the worlds, each with its own theme words. Pass \(Level.countToUnlockNext) levels in one to unlock the next.",
                    nodeNamed("menu-worlds"))
        case .levels:
            return ("Each world has \(Level.regularCount) levels plus a boss level with a twist. Beat all \(Level.regularCount) to unlock FREE play.",
                    nodeNamed("menu-levels"))
        case .starWords:
            return ("These dots track this level's STAR WORDS. Find all \(Level.starWordCount) to earn its bonus ★.",
                    nodeNamed("menu-stars"))
        case .stats:
            return ("STATS tracks your words, stars and best scores. Earn every ★ in a world to unlock a new outfit for me!",
                    nodeNamed("action-stats"))
        case .rules:
            return ("Need a reminder? HOW TO PLAY has all the rules.", nodeNamed("action-rules"))
        case .settings:
            return ("SETTINGS has sound, vibration, and Replay Tutorial to see all this again.",
                    nodeNamed("action-settings"))
        case .play:
            return ("That's it! Tap PLAY whenever you're ready for the next level.", nodeNamed("action-play"))
        }
    }

    /// How big the home bug shrinks while it's guiding, to match the speech bubble.
    static let homeTourBugScale: CGFloat = 0.5

    /// The home screen's own bug does the talking: it flies from its perch to each stop,
    /// then back home when the tour ends.
    func drawHomeTour() {
        guard menuOverlay == nil else { return }
        // The bug isn't drawn on short or landscape home screens; the bubble brings its own.
        let logo = childNode(withName: "home-logo")
        guard let step = homeTourStep else {
            if let logo, let spot = homeTourBugSpot {
                let home = logo.position
                logo.position = spot
                logo.setScale(Self.homeTourBugScale)
                logo.zPosition = 96
                logo.run(.scale(to: 1, duration: 1.1))
                flyMascot(logo, to: home, then: [])
            }
            homeTourBugSpot = nil
            return
        }
        let (text, target) = homeTourContent(for: step)
        // The buttons along the top count as "above", so the pointer comes up from below them.
        let safe = safeFrame
        var area = CGRect(x: safe.minX + 8, y: safe.minY + 8, width: safe.width - 16, height: safe.height - 64)
        // With nothing to point at, the bug talks over the logo, clear of the menu card.
        if target == nil { area = CGRect(x: area.minX, y: safe.midY, width: area.width, height: area.maxY - safe.midY) }
        let spot = drawCoach(text: text, targetNode: target, area: area, waitsForTap: true, hidden: false,
                             drawsBug: logo == nil)
        guard let logo else { return }

        // No wandering off mid-tour.
        logo.removeAction(forKey: "roam-timer")
        logo.zPosition = 96
        let start = homeTourBugSpot ?? logo.position
        if homeTourBugSpot == nil {
            logo.run(.scale(to: Self.homeTourBugScale, duration: 1.1))
        } else {
            logo.setScale(Self.homeTourBugScale)
        }
        logo.position = start
        homeTourBugSpot = spot
        guard hypot(spot.x - start.x, spot.y - start.y) > 2 else { return }
        flyMascot(logo, to: spot, then: [])
        // The bubble pops up once the bug has arrived.
        if let bubble = childNode(withName: "tutorial") {
            bubble.alpha = 0
            bubble.run(.sequence([.wait(forDuration: 0.8), .fadeIn(withDuration: 0.2)]))
        }
        // Taps wait until the bug has landed (flight plus its little bounce).
        tutorialShownAt = currentTime + 0.85
    }
}
