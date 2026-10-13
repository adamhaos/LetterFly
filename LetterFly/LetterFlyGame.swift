import Foundation

final class LetterFlyGame {
    enum NextMoveState {
        case playable
        case remixed
        case none
    }

    enum BoardSize: Int, CaseIterable {
        case classic = 2
        case big = 3
        case huge = 4

        var columns: Int { 4 }
        var rows: Int { rawValue }
        var stackCount: Int { columns * rows }
        var layerCount: Int {
            switch self {
            case .classic: 4
            case .big: 5
            case .huge: 6
            }
        }
        var title: String { "4×\(rows)" }
        var tileCount: Int { stackCount * layerCount }
        /// Each layer spells `wordsPerLayer` hidden words, filling every stack once.
        var wordsPerLayer: Int { self == .classic ? 1 : 2 }
        var wordLength: Int { stackCount / wordsPerLayer }
    }

    static let roundDurations: [TimeInterval] = [90, 180, 270]

    struct Tile: Equatable {
        let id: Int
        var letter: Character
        let isBonus: Bool
        var removed = false
        /// A "?" letter that stands in for any letter. `letter` still holds the letter the
        /// round's theme word needs there, which the move helpers use behind the scenes.
        var isWild = false

        /// The character shown to the player.
        var shown: Character { isWild ? "?" : letter }
    }

    struct Submission {
        let word: String
        let points: Int
        let isThemeWord: Bool
    }

    static let commonWords: Set<String> = [
        "ace", "act", "age", "ago", "aid", "aim", "air", "and", "ant", "any", "ape", "are", "arm", "art", "ate",
        "bad", "bag", "bar", "bat", "bay", "bed", "bee", "big", "bit", "box", "boy", "bug", "bus", "but", "buy",
        "can", "cap", "car", "cat", "cow", "cry", "cup", "cut", "day", "did", "dig", "dog", "dry", "ear", "eat",
        "egg", "end", "eye", "far", "fat", "fig", "fin", "fit", "fly", "for", "fox", "fun", "get", "goat", "gum",
        "had", "ham", "hat", "hen", "her", "him", "hip", "his", "hop", "hot", "how", "ice", "ink", "its", "jam",
        "jar", "jet", "job", "joy", "key", "kid", "leg", "let", "lid", "log", "low", "map", "mat", "mix", "net",
        "new", "not", "now", "nut", "oak", "odd", "off", "old", "one", "our", "out", "owl", "pan", "pen", "pet",
        "pie", "pig", "pin", "pot", "red", "run", "sad", "say", "sea", "see", "sit", "six", "sky", "sun", "tap",
        "tea", "ten", "the", "tie", "top", "toy", "try", "two", "use", "van", "war", "was", "way", "web", "wet",
        "who", "why", "win", "yes", "you", "zoo"
    ]

    private static let letterValues: [Character: Int] = [
        "A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4, "I": 1,
        "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3, "Q": 10, "R": 1,
        "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8, "Y": 4, "Z": 10
    ]

    static func pointValue(for letter: Character) -> Int {
        letterValues[letter] ?? 1
    }

    private(set) var stacks: [[Tile]] = []
    private(set) var selectedTileIDs: [Int] = []
    private(set) var usedWords: Set<String> = []
    private(set) var roundWords: [String] = []
    private(set) var longestWord = "—"
    private(set) var boardSize: BoardSize = .classic
    private(set) var world: World = .storm
    /// Endless rounds start half full and keep receiving new letters.
    private(set) var isEndless = false
    private(set) var nextTileID = 0
    var score = 0

    var selectedTiles: [Tile] { selectedTileIDs.compactMap { tile(id: $0) } }
    /// The word as the player sees it, with "?" for a wild letter.
    var currentWord: String { String(selectedTiles.map(\.shown)) }
    var remainingTileCount: Int { stacks.flatMap { $0 }.filter { !$0.removed }.count }
    var exposedTileIDs: [Int?] {
        stacks.map { stack in stack.last(where: { !$0.removed && !selectedTileIDs.contains($0.id) })?.id }
    }

    var foundThemeWordCount: Int { roundWords.filter { usedWords.contains($0.lowercased()) }.count }

    init() { startNewRound(boardSize: .classic, world: .storm) }

    func startNewRound(boardSize: BoardSize, world: World, endless: Bool = false) {
        self.boardSize = boardSize
        self.world = world
        isEndless = endless
        let wordsPerLayer = boardSize.wordsPerLayer
        roundWords = Array(world.words(ofLength: boardSize.wordLength).shuffled().prefix(boardSize.layerCount * wordsPerLayer))
        stacks = Array(repeating: [], count: boardSize.stackCount)
        selectedTileIDs = []
        usedWords = []
        longestWord = "—"
        score = 0

        var nextID = 0
        let layers = stride(from: 0, to: roundWords.count, by: wordsPerLayer).map {
            Array(roundWords[$0..<min($0 + wordsPerLayer, roundWords.count)])
        }
        for layer in layers.reversed() {
            let letters = layer.flatMap(Array.init).shuffled()
            for (lane, letter) in letters.enumerated() {
                stacks[lane].append(Tile(id: nextID, letter: letter, isBonus: Int.random(in: 0..<7) == 0))
                nextID += 1
            }
        }
        // Endless rounds start with only the top half of the pile.
        if endless {
            let keep = (boardSize.layerCount + 1) / 2
            stacks = stacks.map { Array($0.suffix(keep)) }
            // Only the kept (top) layers' words can still be found; the top layer is the first word.
            roundWords = Array(roundWords.prefix(keep * wordsPerLayer))
        }
        // Bigger boards hide one wild "?" letter somewhere in the pile.
        if boardSize != .classic, let lane = stacks.indices.randomElement(), let index = stacks[lane].indices.randomElement() {
            let tile = stacks[lane][index]
            stacks[lane][index] = Tile(id: tile.id, letter: tile.letter, isBonus: false, isWild: true)
        }
        nextTileID = nextID
    }

    /// The most letters the pile can hold in Endless before it topples.
    var endlessCapacity: Int { boardSize.stackCount * (boardSize.layerCount + 1) }

    /// Drops a new letter onto a random stack (Endless mode). Common letters come up more often.
    @discardableResult
    func dropLetter() -> (tile: Tile, lane: Int) {
        let bag: [(Character, Int)] = [
            ("E", 12), ("A", 9), ("I", 8), ("O", 8), ("N", 6), ("R", 6), ("T", 6), ("L", 4), ("S", 5), ("U", 4),
            ("D", 4), ("G", 3), ("B", 2), ("C", 2), ("M", 2), ("P", 2), ("F", 2), ("H", 2), ("V", 1), ("W", 2),
            ("Y", 2), ("K", 1), ("J", 1), ("X", 1), ("Q", 1), ("Z", 1)
        ]
        var roll = Int.random(in: 0..<bag.reduce(0) { $0 + $1.1 })
        var letter: Character = "E"
        for (candidate, weight) in bag {
            if roll < weight { letter = candidate; break }
            roll -= weight
        }
        let lane = stacks.indices.randomElement() ?? 0
        let tile = Tile(id: nextTileID, letter: letter, isBonus: Int.random(in: 0..<8) == 0)
        nextTileID += 1
        stacks[lane].append(tile)
        return (tile, lane)
    }

    /// Removes an uncovered letter without scoring it (the Volcano boss's lava).
    @discardableResult
    func burnTile(id: Int) -> Bool {
        guard exposedTileIDs.compactMap({ $0 }).contains(id) else { return false }
        mutateTile(id: id) { $0.removed = true }
        return true
    }

    @discardableResult
    func selectTile(id: Int) -> Bool {
        guard exposedTileIDs.compactMap({ $0 }).contains(id) else { return false }
        selectedTileIDs.append(id)
        return true
    }

    @discardableResult
    func undoLastSelection() -> Int? { selectedTileIDs.popLast() }

    @discardableResult
    func clearSelection() -> Bool {
        guard !selectedTileIDs.isEmpty else { return false }
        selectedTileIDs.removeAll()
        return true
    }

    /// Scores and removes the selected letters. `resolvedWord` spells out any wild letter.
    func commitSelection(as resolvedWord: String? = nil) -> Submission {
        let word = (resolvedWord ?? currentWord).lowercased()
        var points = 0
        for id in selectedTileIDs {
            guard let tile = tile(id: id) else { continue }
            // A wild letter is free to use but worth nothing itself.
            let base = tile.isWild ? 0 : Self.pointValue(for: tile.letter)
            points += tile.isBonus ? base * 2 : base
            mutateTile(id: id) { $0.removed = true }
        }
        points = points * max(1, word.count - 2)
        let isThemeWord = roundWords.contains(word.uppercased())
        if isThemeWord { points *= 2 }
        score += points
        usedWords.insert(word)
        if longestWord == "—" || word.count > longestWord.count { longestWord = word }
        selectedTileIDs = []
        return Submission(word: word, points: points, isThemeWord: isThemeWord)
    }

    /// Shuffles the uncovered letters and returns where each one moved, as (from, to) tile ids.
    @discardableResult
    func shuffleExposedLetters() -> [(from: Int, to: Int)] {
        // The wild "?" stays put; only ordinary letters trade places.
        let ids = exposedTileIDs.compactMap { $0 }.filter { tile(id: $0)?.isWild == false }
        let letters = ids.compactMap { tile(id: $0)?.letter }
        let order = Array(ids.indices).shuffled()
        for (index, source) in order.enumerated() {
            let letter = letters[source]
            mutateTile(id: ids[index]) { $0.letter = letter }
        }
        return order.enumerated().compactMap { index, source in
            source == index ? nil : (from: ids[source], to: ids[index])
        }
    }

    func bestAvailableRoundWord() -> String? {
        let available = selectedTileIDs.compactMap { tile(id: $0)?.letter } +
            exposedTileIDs.compactMap { $0 }.compactMap { tile(id: $0)?.letter }
        return knownUnusedWords.first { canBuild($0, from: available) }
    }

    /// Keeps unevenly cleared stacks from stranding the player. If the exposed
    /// letters are stuck, letters are swapped with covered tiles so the total
    /// letter bag stays unchanged while a known valid word becomes available.
    func prepareNextMove() -> NextMoveState {
        guard remainingTileCount >= 3 else { return .none }

        let exposedIDs = exposedTileIDs.compactMap { $0 }
        let exposedLetters = exposedIDs.compactMap { tile(id: $0)?.letter }
        if knownUnusedWords.contains(where: { canBuild($0, from: exposedLetters) }) {
            return .playable
        }

        guard exposedIDs.count >= 3 else { return .none }
        let remainingIDs = stacks.flatMap { stack in
            stack.filter { !$0.removed }.map(\.id)
        }
        let remainingLetters = remainingIDs.compactMap { tile(id: $0)?.letter }
        guard let rescueWord = knownUnusedWords.first(where: {
            $0.count <= exposedIDs.count && canBuild($0, from: remainingLetters)
        }) else { return .none }

        var reserved = Set<Int>()
        for (targetID, desiredLetter) in zip(exposedIDs, rescueWord) {
            if tile(id: targetID)?.letter == desiredLetter {
                reserved.insert(targetID)
                continue
            }
            guard let sourceID = remainingIDs.first(where: {
                !reserved.contains($0) && tile(id: $0)?.letter == desiredLetter
            }), let targetLetter = tile(id: targetID)?.letter else {
                return .none
            }
            mutateTile(id: targetID) { $0.letter = desiredLetter }
            mutateTile(id: sourceID) { $0.letter = targetLetter }
            reserved.insert(targetID)
        }
        return .remixed
    }

    private var knownUnusedWords: [String] {
        let unusedRoundWords = roundWords.filter { !usedWords.contains($0.lowercased()) }
        let common = Self.commonWords
            .filter { !usedWords.contains($0) }
            .map { $0.uppercased() }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs < rhs : lhs.count < rhs.count
            }
        return unusedRoundWords + common
    }

    private func canBuild(_ word: String, from availableLetters: [Character]) -> Bool {
        var letters = availableLetters
        for character in word {
            guard let index = letters.firstIndex(of: character) else { return false }
            letters.remove(at: index)
        }
        return true
    }

    private func tile(id: Int) -> Tile? {
        for stack in stacks {
            if let tile = stack.first(where: { $0.id == id }) { return tile }
        }
        return nil
    }

    private func mutateTile(id: Int, change: (inout Tile) -> Void) {
        for lane in stacks.indices {
            guard let index = stacks[lane].firstIndex(where: { $0.id == id }) else { continue }
            change(&stacks[lane][index])
            return
        }
    }
}
