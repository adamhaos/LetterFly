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
    /// The best score sent to each leaderboard this session, so unchanged scores aren't resent.
    private var submittedScores: [Leaderboard: Int] = [:]
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
    private func didSignIn() async {
        if let achievements = try? await GKAchievement.loadAchievements() {
            for achievement in achievements {
                reportedPercent[achievement.identifier] = achievement.percentComplete
            }
        }
        sync()
    }

    /// Sends achievement progress and the all-time leaderboards from saved progress.
    func sync(progress: ProgressStore = .shared, stats: StatsStore = .shared,
              daily: DailyStore = .shared, highScores: HighScoreStore = .shared) {
        guard isSignedIn else { return }
        let snapshot = AchievementProgress(progress: progress, stats: stats, daily: daily, highScores: highScores)
        report(snapshot)
        submit(snapshot.totalStars, to: .stars)
        submit(snapshot.bestDailyStreak, to: .dailyStreak)
        submit(snapshot.bestEndlessScore, to: .endless)
    }

    /// Sends a score. Game Center keeps each player's best, per day for the daily board.
    /// All-time boards skip scores no better than one already sent this session; the daily
    /// board always sends, since each day starts a fresh board.
    func submit(_ score: Int, to leaderboard: Leaderboard) {
        guard isSignedIn, score > 0 else { return }
        if leaderboard != .daily {
            guard score > (submittedScores[leaderboard] ?? 0) else { return }
            submittedScores[leaderboard] = score
        }
        Task {
            try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [leaderboard.rawValue])
        }
    }

    private func report(_ snapshot: AchievementProgress) {
        let gains: [GKAchievement] = Achievement.allCases.compactMap { achievement in
            let id = achievement.rawValue
            let percent = achievement.percentComplete(snapshot)
            guard percent > (reportedPercent[id] ?? 0) else { return nil }
            reportedPercent[id] = percent
            let update = GKAchievement(identifier: id)
            update.percentComplete = percent
            update.showsCompletionBanner = true
            return update
        }
        guard !gains.isEmpty else { return }
        Task { try? await GKAchievement.report(gains) }
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
