import SpriteKit
import UIKit

// Popup screens over the home screen: settings, stats with the outfit picker, and reset.
extension GameScene {
    nonisolated static func isOverlayAction(_ name: String) -> Bool {
        ["action-overlay-", "action-setting-", "action-outfit-", "action-reset-"].contains { name.hasPrefix($0) }
    }

    func setOverlay(_ overlay: MenuOverlay?) {
        menuOverlay = overlay
        haptics.select()
        render()
        if overlay != nil, let card = nodeNamed("overlay-card") {
            card.setScale(0.92)
            card.run(.scale(to: 1, duration: 0.16))
        }
    }

    func handleOverlayAction(_ action: String) {
        switch action {
        case "action-setting-sound":
            sound.isEnabled.toggle()
            haptics.select()
            render()
        case "action-setting-haptics":
            haptics.isEnabled.toggle()
            haptics.select()
            render()
        case "action-setting-tutorial":
            UserDefaults.standard.set(false, forKey: Self.tutorialKey)
            menuOverlay = nil
            render()
            flashMenuNote("The tutorial will play on Storm level 1")
        case "action-setting-reset":
            setOverlay(.confirmReset)
        case "action-reset-confirm":
            resetAllProgress()
        default:
            if let index = Self.number(in: action, after: "action-outfit-"), let outfit = Outfit(rawValue: index) {
                guard outfit.isUnlocked(progress) else {
                    flashMenuNote("Star every \(outfit.world?.title ?? "") level to unlock the \(outfit.title)")
                    return
                }
                Outfit.selected = outfit
                haptics.select()
                render()
            }
        }
    }

    /// Dims the menu and adds a titled card with a close button; content is added to the card.
    @discardableResult
    func drawOverlayCard(title: String, width: CGFloat, height: CGFloat) -> SKShapeNode {
        let safe = safeFrame
        let theme = menuTheme
        let dimmer = SKShapeNode(rect: frame)
        dimmer.fillColor = Palette.ink.withAlphaComponent(0.5)
        dimmer.strokeColor = .clear
        dimmer.zPosition = 100
        addChild(dimmer)

        let card = roundedRect(size: CGSize(width: width, height: height), radius: 26, fill: theme.card, stroke: theme.stroke)
        card.position = CGPoint(x: safe.midX, y: safe.midY)
        card.zPosition = 101
        card.name = "overlay-card"
        addChild(card)

        let titleLabel = makeLabel(title, font: "AvenirNext-Heavy", size: 20, color: Palette.ink, alignment: .left)
        titleLabel.position = CGPoint(x: -width / 2 + 22, y: height / 2 - 34)
        titleLabel.zPosition = 1
        card.addChild(titleLabel)
        let close = roundedRect(size: CGSize(width: 36, height: 36), radius: 18, fill: theme.chip, stroke: theme.stroke)
        close.position = CGPoint(x: width / 2 - 32, y: height / 2 - 34)
        close.zPosition = 1
        close.name = "action-overlay-close"
        card.addChild(close)
        if let icon = makeSymbol("xmark", pointSize: 13, color: theme.deepAccent) {
            icon.name = "action-overlay-close"
            icon.zPosition = 1
            close.addChild(icon)
        }
        return card
    }

    // MARK: Settings

    func drawSettings() {
        let theme = menuTheme
        let width = min(370, safeFrame.width - 32)
        let rowHeight: CGFloat = 52
        let height: CGFloat = 64 + rowHeight * 4 + 20
        let card = drawOverlayCard(title: "SETTINGS", width: width, height: height)
        var y = height / 2 - 64 - rowHeight / 2

        func row(icon: String, title: String, name: String, trailing: (SKNode) -> Void) {
            let rowNode = roundedRect(size: CGSize(width: width - 32, height: rowHeight - 8), radius: 14,
                                      fill: theme.chip, stroke: .clear)
            rowNode.position = CGPoint(x: 0, y: y)
            rowNode.zPosition = 1
            rowNode.name = name
            card.addChild(rowNode)
            if let symbol = makeSymbol(icon, pointSize: 15, color: theme.deepAccent) {
                symbol.position = CGPoint(x: -(width - 32) / 2 + 24, y: 0)
                symbol.zPosition = 1
                symbol.name = name
                rowNode.addChild(symbol)
            }
            let label = makeLabel(title, font: "AvenirNext-Bold", size: 15, color: Palette.ink, alignment: .left, name: name)
            label.position = CGPoint(x: -(width - 32) / 2 + 46, y: 0)
            label.zPosition = 1
            rowNode.addChild(label)
            trailing(rowNode)
            y -= rowHeight
        }
        func toggle(_ on: Bool, name: String) -> (SKNode) -> Void {
            { rowNode in
                let pill = self.roundedRect(size: CGSize(width: 52, height: 28), radius: 14,
                                            fill: on ? theme.accent : Palette.muted.withAlphaComponent(0.35), stroke: .clear)
                pill.position = CGPoint(x: (width - 32) / 2 - 38, y: 0)
                pill.zPosition = 1
                pill.name = name
                rowNode.addChild(pill)
                let knob = SKShapeNode(circleOfRadius: 11)
                knob.fillColor = .white
                knob.strokeColor = .clear
                knob.position = CGPoint(x: on ? 12 : -12, y: 0)
                knob.zPosition = 1
                knob.name = name
                pill.addChild(knob)
            }
        }
        func chevron(_ name: String, color: SKColor = Palette.muted) -> (SKNode) -> Void {
            { rowNode in
                if let symbol = self.makeSymbol("chevron.right", pointSize: 13, color: color) {
                    symbol.position = CGPoint(x: (width - 32) / 2 - 22, y: 0)
                    symbol.zPosition = 1
                    symbol.name = name
                    rowNode.addChild(symbol)
                }
            }
        }
        row(icon: sound.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill", title: "Sound",
            name: "action-setting-sound", trailing: toggle(sound.isEnabled, name: "action-setting-sound"))
        row(icon: "iphone.radiowaves.left.and.right", title: "Vibration",
            name: "action-setting-haptics", trailing: toggle(haptics.isEnabled, name: "action-setting-haptics"))
        row(icon: "graduationcap.fill", title: "Replay Tutorial",
            name: "action-setting-tutorial", trailing: chevron("action-setting-tutorial"))
        row(icon: "arrow.counterclockwise", title: "Reset Progress",
            name: "action-setting-reset", trailing: chevron("action-setting-reset", color: Palette.coral))
    }

    func drawConfirmReset() {
        let width = min(340, safeFrame.width - 40)
        let height: CGFloat = 220
        let card = drawOverlayCard(title: "RESET?", width: width, height: height)
        let body = SKLabelNode(fontNamed: "AvenirNext-Medium")
        body.text = "This erases every level, star, high score, stat and outfit. It can't be undone."
        body.fontSize = 14
        body.fontColor = Palette.ink.withAlphaComponent(0.8)
        body.numberOfLines = 0
        body.preferredMaxLayoutWidth = width - 44
        body.horizontalAlignmentMode = .center
        body.verticalAlignmentMode = .center
        body.position = CGPoint(x: 0, y: 10)
        body.zPosition = 1
        card.addChild(body)
        let buttonWidth = (width - 54) / 2
        addButton(title: "CANCEL", name: "action-overlay-close", size: CGSize(width: buttonWidth, height: 46),
                  color: Palette.teal, at: CGPoint(x: -buttonWidth / 2 - 5, y: -height / 2 + 42),
                  fontSize: 13, zPosition: 2, in: card)
        addButton(title: "ERASE ALL", name: "action-reset-confirm", size: CGSize(width: buttonWidth, height: 46),
                  color: Palette.coral, at: CGPoint(x: buttonWidth / 2 + 5, y: -height / 2 + 42),
                  fontSize: 13, zPosition: 2, in: card)
    }

    func resetAllProgress() {
        let defaults = UserDefaults.standard
        // The rainbow skin is kept for good (its key isn't listed), and stays on if it was being worn.
        let wasWearingRainbow = Outfit.selected == .rainbow
        let prefixes = ["progress.", "stars.", "found.", "highScores.", "stats.", "outfit.", "tutorial.", "seenUnlock.", "myth."]
        for key in defaults.dictionaryRepresentation().keys where prefixes.contains(where: key.hasPrefix) {
            defaults.removeObject(forKey: key)
        }
        if wasWearingRainbow { Outfit.selected = .rainbow }
        selectedWorld = .storm
        selectedLevel = progress.nextLevel(in: .storm)
        isFreePlaySelected = false
        menuOverlay = nil
        haptics.warning()
        render()
        flashMenuNote("Progress reset")
    }

    // MARK: Stats

    func drawStats() {
        let theme = menuTheme
        let width = min(390, safeFrame.width - 28)
        let inner = width - 32
        // Header, stat grid, world scores and outfit row, top to bottom.
        let outfits = Outfit.shown(progress)
        let slotGuess = inner / CGFloat(outfits.count)
        let height = min(66 + 120 + 22 + 22 + 78 + 12 + 44 + slotGuess / 2 + 34, safeFrame.height - 24)
        let card = drawOverlayCard(title: "STATS", width: width, height: height)
        var y = height / 2 - 66

        // Headline numbers in a 3×2 grid.
        let totalLevels = World.main.count * Level.countPerWorld
        let stars = World.main.map(progress.starCount).reduce(0, +)
        let top = stats.mostUsedLetter
        let tiles: [(String, String)] = [
            ("WORDS", "\(stats.totalWords)"),
            ("ROUNDS", "\(stats.roundsPlayed)"),
            ("THEME WORDS", "\(stats.themeWords)"),
            ("STARS", "\(stars)/\(totalLevels)"),
            ("LONGEST", stats.longestWord.isEmpty ? "—" : stats.longestWord),
            ("TOP LETTER", top.map { "\($0.letter) ×\($0.count)" } ?? "—"),
        ]
        let tileWidth = (inner - 16) / 3
        let tileHeight: CGFloat = 56
        for (index, tile) in tiles.enumerated() {
            let column = CGFloat(index % 3)
            let row = CGFloat(index / 3)
            let box = roundedRect(size: CGSize(width: tileWidth, height: tileHeight), radius: 12, fill: theme.chip, stroke: .clear)
            box.position = CGPoint(x: -inner / 2 + tileWidth / 2 + column * (tileWidth + 8),
                                   y: y - tileHeight / 2 - row * (tileHeight + 8))
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
        y -= tileHeight * 2 + 8 + 22

        // Best score per world, two columns.
        let heading = makeLabel("BEST SCORE BY WORLD", font: "AvenirNext-Heavy", size: 11, color: Palette.muted, alignment: .left)
        heading.position = CGPoint(x: -inner / 2, y: y)
        heading.zPosition = 1
        card.addChild(heading)
        y -= 22
        for world in World.main {
            let column = CGFloat(world.rawValue % 2)
            let row = CGFloat(world.rawValue / 2)
            let x = -inner / 2 + column * (inner / 2 + 8)
            let rowY = y - row * 26
            if let icon = makeSymbol(world.symbolName, pointSize: 12, color: world.accent) {
                icon.position = CGPoint(x: x + 9, y: rowY)
                icon.zPosition = 1
                card.addChild(icon)
            }
            let name = makeLabel(world.title, font: "AvenirNext-DemiBold", size: 13, color: Palette.ink, alignment: .left)
            name.position = CGPoint(x: x + 24, y: rowY)
            name.zPosition = 1
            card.addChild(name)
            let best = stats.bestScore(in: world)
            let score = makeLabel(best > 0 ? "\(best)" : "—", font: "AvenirNext-Heavy", size: 13,
                                  color: theme.deepAccent, alignment: .right)
            score.position = CGPoint(x: x + inner / 2 - 14, y: rowY)
            score.zPosition = 1
            card.addChild(score)
        }
        y -= 26 * 3 + 12

        // Outfits: tap one to wear it; locked ones say how to earn them.
        let outfitHeading = makeLabel("OUTFITS", font: "AvenirNext-Heavy", size: 11, color: Palette.muted, alignment: .left)
        outfitHeading.position = CGPoint(x: -inner / 2, y: y)
        outfitHeading.zPosition = 1
        card.addChild(outfitHeading)
        y -= 44
        let slot = inner / CGFloat(outfits.count)
        for (index, outfit) in outfits.enumerated() {
            let name = "action-outfit-\(outfit.rawValue)"
            let unlocked = outfit.isUnlocked(progress)
            let worn = Outfit.selected.isUnlocked(progress) ? Outfit.selected : .none
            let selected = outfit == worn
            let x = -inner / 2 + slot * (CGFloat(index) + 0.5)
            let ring = SKShapeNode(circleOfRadius: slot / 2 - 2)
            ring.fillColor = selected ? theme.accent.withAlphaComponent(0.18) : theme.chip
            ring.strokeColor = selected ? theme.deepAccent : .clear
            ring.lineWidth = 2.5
            ring.position = CGPoint(x: x, y: y)
            ring.zPosition = 1
            ring.name = name
            card.addChild(ring)
            let bug = makeLogo(size: slot * 0.78, outfit: outfit, animated: false)
            bug.position = CGPoint(x: -slot * 0.04, y: 0)
            bug.alpha = unlocked ? 1 : 0.25
            bug.zPosition = 1
            ring.addChild(bug)
            if !unlocked, let lock = makeSymbol("lock.fill", pointSize: 12, color: Palette.ink.withAlphaComponent(0.7)) {
                lock.zPosition = 30
                lock.name = name
                ring.addChild(lock)
            }
            let label = makeLabel(outfit.shortTitle, font: "AvenirNext-Bold", size: 9,
                                  color: selected ? theme.deepAccent : Palette.muted, name: name)
            label.position = CGPoint(x: x, y: y - slot / 2 - 8)
            label.zPosition = 1
            card.addChild(label)
        }
    }
}
