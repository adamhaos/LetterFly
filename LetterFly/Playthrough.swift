import Foundation

/// One playthrough level: a fixed board and clock with a score to beat.
struct Level: Equatable {
    /// Five regular levels, then a boss level with a world-specific twist.
    static let countPerWorld = 6
    static let regularCount = 5
    /// Levels a player must beat in a world to unlock the next one.
    static let countToUnlockNext = 3

    let world: World
    let number: Int

    var isBoss: Bool { world != .myth && number > Level.regularCount }

    /// Myth levels are trials, one per level, each with its own rules.
    var trial: MythTrial.Kind? { world == .myth ? MythTrial.Kind(rawValue: number - 1) : nil }

    /// Picks this level's theme words, the same on every play.
    var wordSeed: UInt64 { UInt64(world.rawValue * 100 + number) &* 2_654_435_761 }

    /// How many theme words a level's star asks for, across as many plays as it takes.
    static let starWordCount = 4

    /// Every theme word hidden in this level's pile, the same on every play.
    var themeWords: [String] {
        var generator = SeededGenerator(seed: wordSeed)
        let pool = world.words(ofLength: boardSize.wordLength)
        return Array(pool.shuffled(using: &generator).prefix(boardSize.layerCount * boardSize.wordsPerLayer))
    }

    /// The theme words that earn this level's star.
    var starWords: [String] { Array(themeWords.prefix(Level.starWordCount)) }

    /// The order to stack this play's words in, top layer first: star words not yet found go
    /// on top, where all their letters start uncovered, so each play offers a new one.
    func wordOrder(found: Set<String>) -> [String] {
        let missing = starWords.filter { !found.contains($0.lowercased()) }
        return missing.shuffled() + themeWords.filter { !missing.contains($0) }.shuffled()
    }

    var boardSize: LetterFlyGame.BoardSize {
        if world == .myth { return .grand }
        return switch number {
        case 1, 2: .classic
        case 3, 4: .big
        default: .huge
        }
    }

    var duration: TimeInterval {
        if let trial { return trial.duration }
        return switch boardSize {
        case .classic: 90
        case .big: 180
        case .huge, .grand: 270
        }
    }

    /// Targets climb within a world and by 4% per world after Storm. Tuned with a
    /// simulated casual player (3–5 letter words, ~10 s each): the first level of each
    /// board size is passed most of the time, the last level about half the time.
    var targetScore: Int {
        // Trials are won by their own goal, not by score.
        if world == .myth { return 0 }
        let base = [70, 85, 165, 190, 320, 350][number - 1]
        let scaled = Double(base) * (1 + 0.04 * Double(world.rawValue))
        return Int((scaled / 5).rounded()) * 5
    }
}

final class ProgressStore {
    static let shared = ProgressStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func levelsBeaten(in world: World) -> Int {
        defaults.integer(forKey: key(for: world))
    }

    func isUnlocked(_ world: World) -> Bool {
        // Myth opens once every main-world level is beaten; stars aren't needed for it.
        if world == .myth { return World.main.allSatisfy { levelsBeaten(in: $0) >= Level.countPerWorld } }
        guard let previous = world.previous else { return true }
        return levelsBeaten(in: previous) >= Level.countToUnlockNext
    }

    /// Free Play opens in a world once all of its levels are beaten.
    func isFreePlayUnlocked(in world: World) -> Bool {
        world != .myth && levelsBeaten(in: world) >= Level.regularCount
    }

    /// Beating all six Myth trials earns the rainbow skin. It's saved under its own key so a
    /// progress reset doesn't take it away.
    var hasRainbow: Bool { defaults.bool(forKey: Self.rainbowKey) }
    static let rainbowKey = "rainbow.earned"

    func recordRainbow() { defaults.set(true, forKey: Self.rainbowKey) }

    /// The rainbow skin takes every Myth trial beaten and every Myth star word found.
    /// Saves it the first time that's true and returns whether it was just earned.
    @discardableResult
    func awardRainbowIfEarned() -> Bool {
        guard !hasRainbow, levelsBeaten(in: .myth) >= Level.countPerWorld, isMastered(.myth) else { return false }
        recordRainbow()
        return true
    }

    /// Whether the road-straightening finale has played.
    var hasSeenRainbowFinale: Bool {
        get { defaults.bool(forKey: "myth.finaleSeen") }
        set { defaults.set(newValue, forKey: "myth.finaleSeen") }
    }

    func isPlayable(_ level: Level) -> Bool {
        isUnlocked(level.world) && level.number <= levelsBeaten(in: level.world) + 1
    }

    /// The first unbeaten level in `world`, or its last level once all are beaten.
    func nextLevel(in world: World) -> Level {
        Level(world: world, number: min(levelsBeaten(in: world) + 1, Level.countPerWorld))
    }

    /// Records a beaten level and returns the world it unlocked, if any.
    @discardableResult
    func recordPass(of level: Level) -> World? {
        let wasNextLocked = level.world.next.map { !isUnlocked($0) } ?? false
        if level.number > levelsBeaten(in: level.world) {
            defaults.set(level.number, forKey: key(for: level.world))
        }
        guard wasNextLocked, let next = level.world.next, isUnlocked(next) else { return nil }
        return next
    }

    /// A star marks a level passed while finding every theme word in the round.
    func hasStar(_ level: Level) -> Bool {
        starredLevels(in: level.world).contains(level.number)
    }

    func starCount(in world: World) -> Int { starredLevels(in: world).count }

    /// A world is mastered once every one of its levels has a star.
    func isMastered(_ world: World) -> Bool { starCount(in: world) == Level.countPerWorld }

    /// Records a star and returns whether it is new.
    @discardableResult
    func recordStar(for level: Level) -> Bool {
        var starred = starredLevels(in: level.world)
        guard starred.insert(level.number).inserted else { return false }
        defaults.set(starred.sorted(), forKey: starKey(for: level.world))
        return true
    }

    /// Theme words found in `level` across every play; finding them all earns the star.
    func foundWords(in level: Level) -> Set<String> {
        Set(defaults.stringArray(forKey: foundKey(for: level)) ?? [])
    }

    /// Saves a theme word found in `level` and returns whether it's new to the collection.
    @discardableResult
    func recordFoundWord(_ word: String, in level: Level) -> Bool {
        var found = foundWords(in: level)
        guard found.insert(word.lowercased()).inserted else { return false }
        defaults.set(found.sorted(), forKey: foundKey(for: level))
        return true
    }

    private func foundKey(for level: Level) -> String { "found.\(level.world.rawValue).\(level.number)" }

    private func starredLevels(in world: World) -> Set<Int> {
        Set((defaults.array(forKey: starKey(for: world)) ?? []).compactMap { ($0 as? NSNumber)?.intValue })
    }

    private func key(for world: World) -> String { "progress.\(world.rawValue)" }
    private func starKey(for world: World) -> String { "stars.\(world.rawValue)" }
}
