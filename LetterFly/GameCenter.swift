import GameKit
import UIKit

/// Signs the player in to Game Center and sends scores and achievements. All of it is
/// optional: when the player isn't signed in, every call does nothing and the game plays
/// the same. Nothing is sent anywhere except Apple's Game Center.
final class GameCenter {
    static let shared = GameCenter()

    var isSignedIn: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Achievement progress already on Game Center (or sent this session), so only gains are sent.
    private var reportedPercent: [String: Double] = [:]
    /// The best score sent to each all-time leaderboard this session, so unchanged scores aren't resent.
    private var submittedScores: [Leaderboard: Int] = [:]
    /// The daily puzzle whose score has reached the daily leaderboard this session.
    private var submittedDailyDay: Int?
    private var hasStartedSignIn = false

    /// Starts sign-in once per launch. If the player needs to sign in, Game Center's own
    /// sheet is shown over `presenter`; if they decline, nothing else happens.
    func authenticate(from presenter: UIViewController) {
        guard !hasStartedSignIn else { return }
        hasStartedSignIn = true
        GKLocalPlayer.local.authenticateHandler = { [weak self, weak presenter] signInSheet, _ in
            if let signInSheet {
                presenter?.present(signInSheet, animated: true)
                return
            }
            guard let self, GKLocalPlayer.local.isAuthenticated else { return }
            Task { await self.didSignIn() }
        }
    }

    /// Learns what Game Center already has, then sends anything earned while signed out.
    /// Runs again when the player switches accounts, so the last account's caches are dropped.
    private func didSignIn() async {
        reportedPercent = [:]
        submittedScores = [:]
        submittedDailyDay = nil
        if let achievements = try? await GKAchievement.loadAchievements() {
            for achievement in achievements {
                reportedPercent[achievement.identifier] = achievement.percentComplete
            }
        }
        sync()
    }

    /// Sends achievement progress, the all-time leaderboards, and today's daily score (in case
    /// it was played while signed out) from saved progress.
    func sync(progress: ProgressStore = .shared, stats: StatsStore = .shared,
              daily: DailyStore = .shared, highScores: HighScoreStore = .shared) {
        guard isSignedIn else { return }
        let snapshot = AchievementProgress(progress: progress, stats: stats, daily: daily, highScores: highScores)
        report(snapshot)
        submit(snapshot.totalStars, to: .stars)
        submit(snapshot.bestDailyStreak, to: .dailyStreak)
        submit(snapshot.bestEndlessScore, to: .endless)
        let today = DailyPuzzle.today()
        if let score = daily.score(for: today) { submitDaily(score, for: today) }
    }

    /// Sends a score to an all-time leaderboard. Game Center keeps each player's best; scores
    /// no better than one already sent this session are skipped. A failed send is retried on
    /// the next sync.
    func submit(_ score: Int, to leaderboard: Leaderboard) {
        guard isSignedIn, score > 0, leaderboard != .daily,
              score > (submittedScores[leaderboard] ?? 0) else { return }
        Task {
            guard (try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                                        leaderboardIDs: [leaderboard.rawValue])) != nil else { return }
            submittedScores[leaderboard] = max(score, submittedScores[leaderboard] ?? 0)
        }
    }

    /// Sends a daily puzzle score, once. The daily leaderboard restarts at the puzzle reset,
    /// so a score is only sent while its own puzzle is still today's; a round that ran past
    /// the reset stays off the new day's board.
    func submitDaily(_ score: Int, for puzzle: DailyPuzzle, now: Date = Date()) {
        guard isSignedIn, score > 0, now < puzzle.endDate, submittedDailyDay != puzzle.day else { return }
        // Marked before sending so a sync right after doesn't send it twice; cleared if it fails.
        submittedDailyDay = puzzle.day
        Task {
            guard (try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                                        leaderboardIDs: [Leaderboard.daily.rawValue])) != nil else {
                if submittedDailyDay == puzzle.day { submittedDailyDay = nil }
                return
            }
        }
    }

    private func report(_ snapshot: AchievementProgress) {
        let gains: [GKAchievement] = Achievement.allCases.compactMap { achievement in
            let id = achievement.rawValue
            let percent = achievement.percentComplete(snapshot)
            guard percent > (reportedPercent[id] ?? 0) else { return nil }
            let update = GKAchievement(identifier: id)
            update.percentComplete = percent
            update.showsCompletionBanner = true
            return update
        }
        guard !gains.isEmpty else { return }
        // Progress is only marked as sent once Game Center accepts it, so a failure retries later.
        Task {
            guard (try? await GKAchievement.report(gains)) != nil else { return }
            for gain in gains {
                reportedPercent[gain.identifier] = max(gain.percentComplete, reportedPercent[gain.identifier] ?? 0)
            }
        }
    }

    /// Opens Game Center on a leaderboard, or on the player's dashboard when `leaderboard` is nil.
    /// Returns false when the player isn't signed in, so the caller can say how to sign in.
    @discardableResult
    func show(_ leaderboard: Leaderboard? = nil) -> Bool {
        guard isSignedIn else { return false }
        if let leaderboard {
            if #available(iOS 18.0, *) {
                GKAccessPoint.shared.trigger(leaderboardID: leaderboard.rawValue, playerScope: .global, timeScope: .allTime) {}
            } else {
                GKAccessPoint.shared.trigger(state: .leaderboards) {}
            }
        } else {
            GKAccessPoint.shared.trigger(state: .dashboard) {}
        }
        return true
    }
}
