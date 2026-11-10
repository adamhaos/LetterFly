import SpriteKit
import UIKit

// The daily puzzle card on the home screen, starting and saving the daily round, and
// opening Game Center.
extension GameScene {
    // MARK: Home button

    /// The calendar button at the top of the home screen. A dot shows while today's puzzle is unplayed.
    func drawDailyButton(at point: CGPoint) {
        let theme = menuTheme
        addIconButton(systemName: "calendar", name: "action-daily", size: CGSize(width: 44, height: 40),
                      fillColor: theme.card, iconColor: theme.deepAccent, stroke: theme.stroke, at: point)
        guard !daily.hasStarted(.today()) else { return }
        let dot = SKShapeNode(circleOfRadius: 5)
        dot.fillColor = Palette.coral
        dot.strokeColor = theme.card
        dot.lineWidth = 2
        dot.position = CGPoint(x: point.x + 18, y: point.y + 16)
        dot.zPosition = 6
        addChild(dot)
        dot.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.5), .scale(to: 1, duration: 0.5)])))
    }

    // MARK: Daily card

    static let dailyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMM d")
        return formatter
    }()

    /// How long until the next puzzle opens, e.g. "5h 12m".
    func timeUntilNextPuzzle(after puzzle: DailyPuzzle) -> String {
        let seconds = max(60, Int(puzzle.endDate.timeIntervalSinceNow))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    func drawDaily() {
        let theme = menuTheme
        let puzzle = DailyPuzzle.today()
        let world = puzzle.world
        let played = daily.hasStarted(puzzle)
        let width = min(370, safeFrame.width - 32)
        let inner = width - 32
        let tileHeight: CGFloat = 56
        let buttonHeight: CGFloat = 50
        let height: CGFloat = 64 + 52 + tileHeight + 50 + buttonHeight + (played ? 0 : 56) + 28
        let card = drawOverlayCard(title: "DAILY PUZZLE", width: width, height: height)
        var y = height / 2 - 72

        // Today's world, date and pile.
        let date = Self.dailyDateFormatter.string(from: puzzle.startDate).uppercased()
        let heading = makeInlineRow([.symbol(world.symbolName), .text("\(world.title.uppercased())  •  \(date)")],
                                    font: "AvenirNext-Heavy", size: 13, color: Palette.ink, symbolColor: world.accent)
        heading.position = CGPoint(x: 0, y: y)
        heading.zPosition = 1
        card.addChild(heading)
        y -= 20
        let detail = makeLabel("\(puzzle.boardSize.title) pile  •  \(Int(puzzle.duration)) sec  •  same letters for everyone",
                               font: "AvenirNext-DemiBold", size: 1, color: Palette.muted)
        detail.fontSize = fittedFontSize(for: detail.text ?? "", max: 12, width: inner + 30)
        detail.position = CGPoint(x: 0, y: y)
        detail.zPosition = 1
        card.addChild(detail)
        y -= 32

        // Streak and bests, in the stats card's tile style.
        let streak = daily.currentStreak(on: puzzle)
        let tiles: [(String, String)] = [
            ("STREAK", streak == 1 ? "1 day" : "\(streak) days"),
            ("BEST STREAK", "\(daily.bestStreak)"),
            ("BEST SCORE", daily.bestScore > 0 ? "\(daily.bestScore)" : "—"),
        ]
        let tileWidth = (inner - 16) / 3
        for (index, tile) in tiles.enumerated() {
            let box = roundedRect(size: CGSize(width: tileWidth, height: tileHeight), radius: 12, fill: theme.chip, stroke: .clear)
            box.position = CGPoint(x: -inner / 2 + tileWidth / 2 + CGFloat(index) * (tileWidth + 8), y: y - tileHeight / 2)
            box.zPosition = 1
            card.addChild(box)
            let value = makeLabel(tile.1, font: "AvenirNext-Heavy", size: 1, color: Palette.ink)
            value.fontSize = fittedFontSize(for: tile.1, max: 19, width: tileWidth - 12)
            value.position.y = 7
            value.zPosition = 1
            box.addChild(value)
            let caption = makeLabel(tile.0, font: "AvenirNext-Bold", size: 8, color: theme.deepAccent)
            caption.position.y = -14
            caption.zPosition = 1
            box.addChild(caption)
        }
        y -= tileHeight + 26

        // Today's result, or the house rule.
        let line: String
        if played {
            let score = daily.score(for: puzzle).map { "TODAY: \($0)" } ?? "TODAY: UNFINISHED"
            line = "\(score)  •  NEXT PUZZLE IN \(timeUntilNextPuzzle(after: puzzle).uppercased())"
        } else {
            line = "ONE TRY A DAY. MAKE IT COUNT!"
        }
        let result = makeLabel(line, font: "AvenirNext-Heavy", size: 1, color: played ? theme.deepAccent : Palette.coral)
        result.fontSize = fittedFontSize(for: line, max: 13, width: inner + 20)
        result.position = CGPoint(x: 0, y: y)
        result.zPosition = 1
        card.addChild(result)
        y -= 24 + buttonHeight / 2

        let buttonSize = CGSize(width: min(300, inner), height: buttonHeight)
        if !played {
            addButton(title: "PLAY TODAY'S PUZZLE", name: "action-daily-play", size: buttonSize, color: world.accent,
                      at: CGPoint(x: 0, y: y), fontSize: 15, zPosition: 2, in: card, symbol: "play.fill")
            y -= 56
        }
        addButton(title: "LEADERBOARD", name: "action-daily-leaderboard",
                  size: played ? buttonSize : CGSize(width: buttonSize.width, height: 44),
                  color: Palette.teal, at: CGPoint(x: 0, y: y), fontSize: 14, zPosition: 2, in: card,
                  symbol: "trophy.fill")
    }

    // MARK: Daily round

    func startDailyPuzzle() {
        let puzzle = DailyPuzzle.today()
        guard !daily.hasStarted(puzzle) else {
            flashMenuNote("Today's puzzle is done. Next one in \(timeUntilNextPuzzle(after: puzzle))")
            return
        }
        menuOverlay = nil
        mode = .daily
        dailyPuzzle = puzzle
        haptics.select()
        startRound()
    }

    /// Saves the daily score the first time the puzzle ends and sends it to Game Center.
    /// Returns whether it's a new best daily score.
    @discardableResult
    func saveDailyScore(for puzzle: DailyPuzzle) -> Bool {
        let previousBest = daily.bestScore
        guard daily.recordScore(game.score, for: puzzle) else { return false }
        gameCenter.submit(game.score, to: .daily)
        return game.score > 0 && game.score > previousBest
    }

    // MARK: Game Center

    /// Opens Game Center, or says how to sign in when the player isn't signed in.
    func openGameCenter(_ leaderboard: Leaderboard?) {
        guard gameCenter.show(leaderboard) else {
            flashMenuNote("Sign in to Game Center in Settings first")
            return
        }
        haptics.select()
    }
}
