import Foundation

/// The daily puzzle: one board a day, dealt the same for every player, so scores can be
/// compared on the Game Center daily leaderboard. Each player gets one try per puzzle.
struct DailyPuzzle: Equatable {
    /// A new puzzle starts at 08:00 UTC, which is midnight Pacific (1 AM in summer) and early
    /// morning on the East Coast, so every US player gets it overnight. The daily leaderboard
    /// in App Store Connect must restart at this same hour.
    static let resetHourUTC = 8
    private static let secondsPerDay: TimeInterval = 86_400

    /// Days since January 1, 1970, counted from the reset hour.
    let day: Int

    static func day(for date: Date) -> Int {
        let shifted = date.timeIntervalSince1970 - TimeInterval(resetHourUTC) * 3600
        return Int((shifted / secondsPerDay).rounded(.down))
    }

    static func today(now: Date = Date()) -> DailyPuzzle { DailyPuzzle(day: day(for: now)) }

    /// When this puzzle opened and when the next one opens.
    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(day) * Self.secondsPerDay + TimeInterval(Self.resetHourUTC) * 3600)
    }
    var endDate: Date { startDate.addingTimeInterval(Self.secondsPerDay) }

    /// The worlds take turns, one a day.
    var world: World { World.main[((day % World.main.count) + World.main.count) % World.main.count] }

    /// A 4×3 pile on a three-minute clock: long enough to dig in, short enough for a coffee break.
    var boardSize: LetterFlyGame.BoardSize { .big }
    var duration: TimeInterval { 180 }

    private var seed: UInt64 { UInt64(bitPattern: Int64(day)) &* 0x9E37_79B9_7F4A_7C15 ^ 0xDA11_7F11_E5ED_0001 }

    /// The day's theme words, top layer first, the same on every device.
    var themeWords: [String] {
        var generator = SeededGenerator(seed: seed)
        let pool = world.words(ofLength: boardSize.wordLength)
        return Array(pool.shuffled(using: &generator).prefix(boardSize.layerCount * boardSize.wordsPerLayer))
    }

    /// Fixes how the letters, red letters and the wild are dealt.
    var dealSeed: UInt64 { seed &+ 0x5EED }
}

/// The player's daily puzzle record, in UserDefaults. Only the latest day is kept, so the
/// data doesn't grow over time. A progress reset leaves it alone, so it can't be used to
/// replay a day.
final class DailyStore {
    static let shared = DailyStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let day = "daily.day"
        static let score = "daily.score"
        static let streak = "daily.streak"
        static let bestStreak = "daily.bestStreak"
        static let bestScore = "daily.bestScore"
        static let played = "daily.played"
    }

    /// The last day a puzzle was started.
    private var lastDay: Int? { defaults.object(forKey: Key.day) as? Int }

    /// A puzzle's one try is used up as soon as it starts. A later puzzle already started
    /// (the clock was set forward, then back) locks it too, so changing the date can't buy
    /// a second try.
    func hasStarted(_ puzzle: DailyPuzzle) -> Bool {
        guard let lastDay else { return false }
        return lastDay >= puzzle.day
    }

    /// The puzzle's saved score, or nil if it hasn't been finished.
    func score(for puzzle: DailyPuzzle) -> Int? {
        lastDay == puzzle.day ? defaults.object(forKey: Key.score) as? Int : nil
    }

    /// Days in a row with a puzzle played. Missing yesterday's puzzle breaks it.
    func currentStreak(on puzzle: DailyPuzzle) -> Int {
        guard let lastDay, lastDay == puzzle.day || lastDay == puzzle.day - 1 else { return 0 }
        return defaults.integer(forKey: Key.streak)
    }

    var bestStreak: Int { defaults.integer(forKey: Key.bestStreak) }
    var bestScore: Int { defaults.integer(forKey: Key.bestScore) }
    var puzzlesPlayed: Int { defaults.integer(forKey: Key.played) }

    /// Uses up the puzzle's try and extends the streak (or starts a new one).
    func recordStart(of puzzle: DailyPuzzle) {
        guard !hasStarted(puzzle) else { return }
        let streak = lastDay == puzzle.day - 1 ? defaults.integer(forKey: Key.streak) + 1 : 1
        defaults.set(puzzle.day, forKey: Key.day)
        defaults.removeObject(forKey: Key.score)
        defaults.set(streak, forKey: Key.streak)
        defaults.set(max(streak, bestStreak), forKey: Key.bestStreak)
        defaults.set(puzzlesPlayed + 1, forKey: Key.played)
    }

    /// Saves the puzzle's score the first time it ends. Returns false if it was already saved.
    @discardableResult
    func recordScore(_ score: Int, for puzzle: DailyPuzzle) -> Bool {
        guard lastDay == puzzle.day, self.score(for: puzzle) == nil else { return false }
        defaults.set(score, forKey: Key.score)
        if score > bestScore { defaults.set(score, forKey: Key.bestScore) }
        return true
    }
}
