import Foundation

/// Lifetime play stats shown on the stats page.
final class StatsStore {
    static let shared = StatsStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var totalWords: Int { defaults.integer(forKey: "stats.words") }
    var roundsPlayed: Int { defaults.integer(forKey: "stats.rounds") }
    var longestWord: String { defaults.string(forKey: "stats.longest") ?? "" }
    var themeWords: Int { defaults.integer(forKey: "stats.theme") }

    func bestScore(in world: World) -> Int {
        defaults.integer(forKey: "stats.best.\(world.rawValue)")
    }

    /// The letter the player has used most, with its count.
    var mostUsedLetter: (letter: Character, count: Int)? {
        let counts = letterCounts
        guard let best = counts.max(by: { $0.value < $1.value }), best.value > 0 else { return nil }
        return (Character(best.key), best.value)
    }

    func recordWord(_ word: String, isThemeWord: Bool) {
        defaults.set(totalWords + 1, forKey: "stats.words")
        if isThemeWord { defaults.set(themeWords + 1, forKey: "stats.theme") }
        let upper = word.uppercased()
        if upper.count > longestWord.count { defaults.set(upper, forKey: "stats.longest") }
        var counts = letterCounts
        for letter in upper where letter.isLetter { counts[String(letter), default: 0] += 1 }
        defaults.set(counts, forKey: "stats.letters")
    }

    func recordRound(score: Int, world: World) {
        defaults.set(roundsPlayed + 1, forKey: "stats.rounds")
        if score > bestScore(in: world) { defaults.set(score, forKey: "stats.best.\(world.rawValue)") }
    }

    private var letterCounts: [String: Int] {
        (defaults.dictionary(forKey: "stats.letters") as? [String: Int]) ?? [:]
    }
}

/// Costumes for the ladybug. Each is unlocked by mastering its world (every level starred).
enum Outfit: Int, CaseIterable {
    case none, rainHat, partyHat, racingCap, snorkel, fireHelmet, spaceHelmet

    /// The world whose mastery unlocks this outfit.
    var world: World? {
        switch self {
        case .none: nil
        case .rainHat: .storm
        case .partyHat: .circus
        case .racingCap: .road
        case .snorkel: .water
        case .fireHelmet: .volcano
        case .spaceHelmet: .space
        }
    }

    var title: String {
        switch self {
        case .none: "Classic"
        case .rainHat: "Rain Hat"
        case .partyHat: "Party Hat"
        case .racingCap: "Racing Cap"
        case .snorkel: "Snorkel"
        case .fireHelmet: "Fire Helmet"
        case .spaceHelmet: "Space Helmet"
        }
    }

    /// A one-word name that fits under the outfit in the picker.
    var shortTitle: String {
        switch self {
        case .none: "Classic"
        case .rainHat: "Rain"
        case .partyHat: "Party"
        case .racingCap: "Racer"
        case .snorkel: "Snorkel"
        case .fireHelmet: "Fire"
        case .spaceHelmet: "Space"
        }
    }

    static var selected: Outfit {
        get { Outfit(rawValue: UserDefaults.standard.integer(forKey: "outfit.selected")) ?? .none }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "outfit.selected") }
    }

    func isUnlocked(_ progress: ProgressStore) -> Bool {
        guard let world else { return true }
        return progress.isMastered(world)
    }
}
