import SpriteKit
import UIKit

// The results screen.
extension GameScene {
    // MARK: Results

    func drawFinished() {
        let safe = safeFrame
        let panelWidth = min(430, safe.width - 36)

        let title: String
        let titleColor: SKColor
        if activeLevel != nil {
            title = passedLevel ? "LEVEL PASSED!" : "SO CLOSE!"
            titleColor = passedLevel ? Palette.teal : Palette.coral
        } else {
            title = statusMessage.uppercased()
            titleColor = Palette.ink
        }
        let caption: String
        let captionColor: SKColor
        if let level = activeLevel {
            caption = "GOAL \(level.targetScore)"
            captionColor = passedLevel ? Palette.teal : Palette.muted
        } else {
            caption = earnedNewHighScore ? "NEW HIGH SCORE!" : "POINTS"
            captionColor = earnedNewHighScore ? Palette.gold : Palette.muted
        }
        let themeLine = "\(game.foundThemeWordCount)/\(game.roundWords.count) \(game.world.title.lowercased()) words"
        let wordCount = game.usedWords.count == 1 ? "1 word" : "\(game.usedWords.count) words"
        let summary = "\(wordCount)  •  \(themeLine)  •  best: \(game.longestWord.uppercased())"

        // Optional lines under the summary.
        var notes: [(text: String, color: SKColor, size: CGFloat, symbol: String?)] = []
        if let unlockedWorld {
            notes.append(("\(unlockedWorld.title.uppercased()) UNLOCKED!", unlockedWorld.accent, 15, nil))
        }
        if unlockedFreePlay {
            notes.append(("\(game.world.title.uppercased()) FREE PLAY UNLOCKED!", game.world.accent, 15, nil))
        }
        if let level = activeLevel, passedLevel, !earnedStar, !progress.hasStar(level), notes.isEmpty {
            notes.append(("Find all \(game.roundWords.count) \(game.world.title.lowercased()) words to earn a", Palette.muted, 12, "star.fill"))
        }
        if activeLevel == nil {
            let leaders = highScores.scores(for: game.boardSize, duration: roundDuration).prefix(3)
                .map(String.init).joined(separator: "  •  ")
            notes.append(("TOP  \(leaders.isEmpty ? "—" : leaders)", Palette.teal, 11, nil))
        }

        // Heights of each row, top to bottom; the card is sized to fit them.
        let padding: CGFloat = 22
        let mascotHeight: CGFloat = 84
        let titleHeight: CGFloat = 34
        let subtitleHeight: CGFloat = activeLevel != nil ? 20 : 0
        let scoreHeight: CGFloat = 60
        let captionHeight: CGFloat = 18
        let summaryHeight: CGFloat = 24
        let starHeight: CGFloat = earnedStar ? 34 : 0
        let noteHeight: CGFloat = 24
        let notesHeight = CGFloat(notes.count) * noteHeight
        let primaryHeight: CGFloat = 54
        let secondaryHeight: CGFloat = 44
        let buttonGap: CGFloat = 12
        let contentHeight = mascotHeight + titleHeight + subtitleHeight + scoreHeight + captionHeight
            + summaryHeight + starHeight + notesHeight + 18 + primaryHeight + buttonGap + secondaryHeight
        let panelHeight = min(contentHeight + padding * 2, safe.height - 30)

        let panel = roundedRect(size: CGSize(width: panelWidth, height: panelHeight), radius: 28,
                                fill: Palette.paper.withAlphaComponent(0.97), stroke: Palette.border)
        panel.position = CGPoint(x: safe.midX, y: safe.midY)
        panel.zPosition = 1
        addChild(panel)

        var y = safe.midY + panelHeight / 2 - padding
        func next(_ height: CGFloat) -> CGFloat {
            let center = y - height / 2
            y -= height
            return center
        }

        let mascotSpot = CGPoint(x: safe.midX, y: next(mascotHeight) + 4)
        if passedLevel {
            flyInMascot(to: mascotSpot, panelRight: safe.midX + panelWidth / 2)
        } else {
            let logo = makeLogo(size: 76)
            logo.position = mascotSpot
            logo.zPosition = 3
            addChild(logo)
        }
        addLabel(title, font: "AvenirNext-Heavy", size: 28, color: titleColor,
                 at: CGPoint(x: safe.midX, y: next(titleHeight)), alignment: .center, z: 3)
        if subtitleHeight > 0 {
            addLabel(statusMessage, font: "AvenirNext-DemiBold", size: 13, color: Palette.muted,
                     at: CGPoint(x: safe.midX, y: next(subtitleHeight)), alignment: .center, z: 3)
        }
        addLabel("\(game.score)", font: "AvenirNext-Heavy", size: 52, color: Palette.coral,
                 at: CGPoint(x: safe.midX, y: next(scoreHeight)), alignment: .center, z: 3)
        addLabel(caption, font: "AvenirNext-Bold", size: 12, color: captionColor,
                 at: CGPoint(x: safe.midX, y: next(captionHeight)), alignment: .center, z: 3)
        addLabel(summary, font: "AvenirNext-DemiBold", size: fittedFontSize(for: summary, max: 14, width: panelWidth - 40),
                 color: Palette.muted, at: CGPoint(x: safe.midX, y: next(summaryHeight)), alignment: .center, z: 3)
        if earnedStar {
            drawStarAward(at: CGPoint(x: safe.midX, y: next(starHeight)))
        }
        for note in notes {
            let row = makeInlineRow([.text(note.text)] + (note.symbol.map { [InlinePart.symbol($0)] } ?? []),
                                    font: "AvenirNext-Heavy", size: note.size, color: note.color,
                                    symbolColor: note.symbol == nil ? nil : Palette.gold)
            row.position = CGPoint(x: safe.midX, y: next(noteHeight))
            row.zPosition = 3
            addChild(row)
        }
        y -= 18

        let buttonWidth = min(300, panelWidth - 48)
        let primaryY = next(primaryHeight)
        y -= buttonGap
        let secondaryY = next(secondaryHeight)
        let primarySize = CGSize(width: buttonWidth, height: primaryHeight)
        if passedLevel, let following = levelAfterActive {
            let label = following.world == activeLevel?.world ? "NEXT LEVEL" : "ON TO \(following.world.title.uppercased())"
            addButton(title: label, name: "action-next", size: primarySize, color: Palette.coral,
                      at: CGPoint(x: safe.midX, y: primaryY))
            let half = CGSize(width: (buttonWidth - 12) / 2, height: secondaryHeight)
            addSecondaryButton(title: "REPLAY", name: "action-again", size: half,
                               at: CGPoint(x: safe.midX - half.width / 2 - 6, y: secondaryY), symbol: "arrow.counterclockwise")
            addSecondaryButton(title: "HOME", name: "action-home", size: half,
                               at: CGPoint(x: safe.midX + half.width / 2 + 6, y: secondaryY))
        } else {
            addButton(title: activeLevel == nil || passedLevel ? "PLAY AGAIN" : "TRY AGAIN", name: "action-again",
                      size: primarySize, color: Palette.coral, at: CGPoint(x: safe.midX, y: primaryY))
            addSecondaryButton(title: "HOME", name: "action-home", size: CGSize(width: buttonWidth, height: secondaryHeight),
                               at: CGPoint(x: safe.midX, y: secondaryY))
        }
    }
}
