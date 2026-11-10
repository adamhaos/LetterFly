import Foundation

/// Game Center leaderboards. Each ID must match App Store Connect exactly.
enum Leaderboard: String, CaseIterable {
    /// Today's daily puzzle score. A recurring leaderboard that restarts every day at
    /// `DailyPuzzle.resetHourUTC`.
    case daily = "letterfly.daily"
    /// Best Endless score on any pile.
    case endless = "letterfly.endless"
    /// Level stars earned, out of 42.
    case stars = "letterfly.stars"
    /// Longest run of daily puzzles played on consecutive days.
    case dailyStreak = "letterfly.daily_streak"
}

/// Game Center achievements. Each ID must match App Store Connect exactly.
enum Achievement: String, CaseIterable {
    case firstFlight = "letterfly.first_flight"
    case stormCleared = "letterfly.storm_cleared"
    case circusCleared = "letterfly.circus_cleared"
    case roadCleared = "letterfly.road_cleared"
    case waterCleared = "letterfly.water_cleared"
    case volcanoCleared = "letterfly.volcano_cleared"
    case spaceCleared = "letterfly.space_cleared"
    case mythOpened = "letterfly.myth_opened"
    case firstMastery = "letterfly.first_mastery"
    case rainbow = "letterfly.rainbow"
    case longWord = "letterfly.long_word"
    case wordsSpelled = "letterfly.words_500"
    case firstDaily = "letterfly.daily_first"
    case weekStreak = "letterfly.daily_streak_7"

    /// How far along the player is, from 0 to 100.
    func percentComplete(_ p: AchievementProgress) -> Double {
        func fraction(_ value: Int, of goal: Int) -> Double { min(100, 100 * Double(value) / Double(goal)) }
        func cleared(_ world: World) -> Double { fraction(p.levelsBeaten[world] ?? 0, of: Level.countPerWorld) }
        switch self {
        case .firstFlight: return fraction(p.levelsBeaten[.storm] ?? 0, of: 1)
        case .stormCleared: return cleared(.storm)
        case .circusCleared: return cleared(.circus)
        case .roadCleared: return cleared(.road)
        case .waterCleared: return cleared(.water)
        case .volcanoCleared: return cleared(.volcano)
        case .spaceCleared: return cleared(.space)
        case .mythOpened: return p.mythUnlocked ? 100 : 0
        case .firstMastery: return fraction(p.starCounts.values.max() ?? 0, of: Level.countPerWorld)
        case .rainbow: return p.hasRainbow ? 100 : 0
        case .longWord: return p.longestWordLength >= 8 ? 100 : 0
        case .wordsSpelled: return fraction(p.totalWords, of: 500)
        case .firstDaily: return fraction(p.dailyPuzzlesPlayed, of: 1)
        case .weekStreak: return fraction(p.bestDailyStreak, of: 7)
        }
    }
}

/// A snapshot of saved progress, enough to work out every achievement and leaderboard score.
struct AchievementProgress {
    var levelsBeaten: [World: Int] = [:]
    var starCounts: [World: Int] = [:]
    var mythUnlocked = false
    var hasRainbow = false
    var totalWords = 0
    var longestWordLength = 0
    var dailyPuzzlesPlayed = 0
    var bestDailyStreak = 0
    var bestEndlessScore = 0

    var totalStars: Int { starCounts.values.reduce(0, +) }

    init(progress: ProgressStore, stats: StatsStore, daily: DailyStore, highScores: HighScoreStore) {
        for world in World.allCases {
            levelsBeaten[world] = progress.levelsBeaten(in: world)
            starCounts[world] = progress.starCount(in: world)
        }
        mythUnlocked = progress.isUnlocked(.myth)
        hasRainbow = progress.hasRainbow
        totalWords = stats.totalWords
        longestWordLength = stats.longestWord.count
        dailyPuzzlesPlayed = daily.puzzlesPlayed
        bestDailyStreak = daily.bestStreak
        bestEndlessScore = highScores.bestEndlessScore
    }
}
