import Foundation

final class HighScoreStore {
    struct Entry: Codable {
        let score: Int
        let boardRows: Int
        let duration: Int

        var modeText: String { "4×\(boardRows)  •  \(duration) SEC" }
    }

    static let shared = HighScoreStore()

    private let defaults: UserDefaults
    private let maximumSavedScores = 5
    private let maximumOverallScores = 3
    private let overallKey = "highScores.overall"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func scores(for board: LetterFlyGame.BoardSize, duration: TimeInterval) -> [Int] {
        defaults.array(forKey: key(for: board, duration: duration))?.compactMap {
            ($0 as? NSNumber)?.intValue
        } ?? []
    }

    func bestScore(for board: LetterFlyGame.BoardSize, duration: TimeInterval) -> Int {
        scores(for: board, duration: duration).first ?? 0
    }

    func topScores() -> [Entry] {
        if let data = defaults.data(forKey: overallKey),
           let entries = try? JSONDecoder().decode([Entry].self, from: data),
           !entries.isEmpty {
            return Array(entries.prefix(maximumOverallScores))
        }

        // Rebuild from the per-mode lists when no overall list has been saved yet.
        let entries = LetterFlyGame.BoardSize.allCases.flatMap { board in
            LetterFlyGame.roundDurations.flatMap { duration in
                scores(for: board, duration: duration).map {
                    Entry(score: $0, boardRows: board.rows, duration: Int(duration))
                }
            }
        }
        return Array(entries.sorted { $0.score > $1.score }.prefix(maximumOverallScores))
    }

    @discardableResult
    func record(_ score: Int, board: LetterFlyGame.BoardSize, duration: TimeInterval) -> Bool {
        guard score > 0 else { return false }
        let previousBest = bestScore(for: board, duration: duration)
        // Read before saving the mode list: topScores() may rebuild from it.
        let overall = (topScores() + [Entry(score: score, boardRows: board.rows, duration: Int(duration))])
            .sorted { $0.score > $1.score }

        let modeScores = (scores(for: board, duration: duration) + [score]).sorted(by: >)
        defaults.set(Array(modeScores.prefix(maximumSavedScores)), forKey: key(for: board, duration: duration))
        if let data = try? JSONEncoder().encode(Array(overall.prefix(maximumOverallScores))) {
            defaults.set(data, forKey: overallKey)
        }
        return score > previousBest
    }

    private func key(for board: LetterFlyGame.BoardSize, duration: TimeInterval) -> String {
        "highScores.\(board.rows).\(Int(duration))"
    }
}
