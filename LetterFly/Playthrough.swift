import Foundation

/// One playthrough level: a fixed board and clock with a score to beat.
struct Level: Equatable {
    static let countPerWorld = 5
    /// Levels a player must beat in a world to unlock the next one.
    static let countToUnlockNext = 3

    let world: World
    let number: Int

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

    /// Targets climb within a world and by 10% per world after Storm.
    var targetScore: Int {
        let base = [90, 130, 230, 290, 460][number - 1]
        let scaled = Double(base) * (1 + 0.10 * Double(world.rawValue))
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

    private func key(for world: World) -> String { "progress.\(world.rawValue)" }
}
