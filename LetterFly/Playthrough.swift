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

    var isBoss: Bool { number > Level.regularCount }

    var boardSize: LetterFlyGame.BoardSize {
        switch number {
        case 1, 2: .classic
        case 3, 4: .big
        default: .huge
        }
    }

    var duration: TimeInterval {
        switch boardSize {
        case .classic: 90
        case .big: 180
        case .huge: 270
        }
    }

    /// Targets climb within a world and by 4% per world after Storm. Tuned with a
    /// simulated casual player (3–5 letter words, ~10 s each): the first level of each
    /// board size is passed most of the time, the last level about half the time.
    var targetScore: Int {
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
        guard let previous = world.previous else { return true }
        return levelsBeaten(in: previous) >= Level.countToUnlockNext
    }

    /// Free Play opens in a world once all of its levels are beaten.
    func isFreePlayUnlocked(in world: World) -> Bool {
        levelsBeaten(in: world) >= Level.regularCount
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

    private func starredLevels(in world: World) -> Set<Int> {
        Set((defaults.array(forKey: starKey(for: world)) ?? []).compactMap { ($0 as? NSNumber)?.intValue })
    }

    private func key(for world: World) -> String { "progress.\(world.rawValue)" }
    private func starKey(for world: World) -> String { "stars.\(world.rawValue)" }
}
