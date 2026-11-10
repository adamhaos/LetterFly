import SpriteKit
import UIKit

// The in-game board: HUD, pile layout, controls and overlays.
extension GameScene {
    // MARK: Game

    func drawGame() {
        let safe = safeFrame
        let landscape = safe.width > safe.height
        let hudY = safe.maxY - 28
        drawHUD(in: CGRect(x: safe.minX + 8, y: hudY - 26, width: safe.width - 16, height: 52))
        var pileTop = hudY - 54
        if trial != nil {
            // Trials show their next step (or riddle), with the star words just below.
            drawTrialBanner(in: CGRect(x: safe.minX + 12, y: hudY - 82, width: safe.width - 24, height: 46))
            drawThemeDots(centerX: safe.midX, y: hudY - 96)
            pileTop = hudY - 108
        } else {
            drawThemeDots(centerX: safe.midX, y: hudY - 42)
        }
        if landscape {
            let controlsX = safe.minX + safe.width * 0.62
            let controlsWidth = safe.width * 0.35
            drawPile(in: CGRect(x: safe.minX + 12, y: safe.minY + 12, width: safe.width * 0.58, height: pileTop - safe.minY - 12))
            drawControls(in: CGRect(x: controlsX, y: safe.minY + 20,
                                    width: controlsWidth, height: pileTop - safe.minY - 30))
        } else {
            // Levels get extra height for the goal row between SUBMIT and HINT.
            let controlHeight: CGFloat = min(activeLevel == nil ? 230 : 252, safe.height * 0.31)
            drawPile(in: CGRect(x: safe.minX + 12, y: safe.minY + controlHeight + 26,
                                width: safe.width - 24, height: pileTop - safe.minY - controlHeight - 26))
            drawControls(in: CGRect(x: safe.minX + 20, y: safe.minY + 14,
                                    width: safe.width - 40, height: controlHeight))
        }
    }

    /// Before the goal: a slim progress bar toward it. After: a pill that finishes the level now.
    func drawGoalBar(center: CGPoint, width: CGFloat) {
        goalBarCenter = activeLevel == nil ? nil : center
        if trial != nil {
            drawTrialBar(center: center, width: width)
            return
        }
        guard let level = activeLevel else { return }
        let world = game.world
        guard game.score >= level.targetScore else {
            let trackWidth = min(width, 260)
            let track = roundedRect(size: CGSize(width: trackWidth, height: 8), radius: 4, fill: world.glass, stroke: Self.glassEdge)
            track.position = center
            track.zPosition = 2
            track.name = "goal-bar"
            addChild(track)
            let fraction = CGFloat(game.score) / CGFloat(level.targetScore)
            if fraction > 0 {
                let fillWidth = max(8, trackWidth * fraction)
                let fill = roundedRect(size: CGSize(width: fillWidth, height: 8), radius: 4, fill: world.accentLight, stroke: .clear)
                fill.position = CGPoint(x: center.x - trackWidth / 2 + fillWidth / 2, y: center.y)
                fill.zPosition = 3
                addChild(fill)
            }
            return
        }
        let size = CGSize(width: min(width, 300), height: 34)
        let pill = addButton(title: "GOAL REACHED  •  FINISH LEVEL", name: "action-finish", size: size,
                             color: Palette.teal, at: center, fontSize: 13, zPosition: 20,
                             trailingSymbol: "chevron.right")
        if animateGoalBar {
            animateGoalBar = false
            pill.position.y -= 16
            pill.alpha = 0
            let rise = SKAction.moveBy(x: 0, y: 16, duration: 0.35)
            rise.timingMode = .easeOut
            pill.run(.group([rise, .fadeIn(withDuration: 0.25)]))
        }
        let swell = SKAction.scale(to: 1.04, duration: 0.6)
        swell.timingMode = .easeInEaseOut
        let settle = SKAction.scale(to: 1, duration: 0.6)
        settle.timingMode = .easeInEaseOut
        pill.run(.repeatForever(.sequence([swell, settle])), withKey: "pulse")
    }

    func drawHUD(in rect: CGRect) {
        let world = game.world
        let bar = roundedRect(size: rect.size, radius: 18, fill: world.glass, stroke: Self.glassEdge)
        bar.position = CGPoint(x: rect.midX, y: rect.midY)
        bar.zPosition = 1
        addChild(bar)
        addIconButton(systemName: "pause.fill", name: "action-exit", size: CGSize(width: 40, height: 36),
                      fillColor: Self.glassButton, iconColor: .white, stroke: Self.glassEdge,
                      at: CGPoint(x: rect.minX + 28, y: rect.midY))
        let subtitle = trial.map { $0.kind.shortTitle.uppercased() }
            ?? activeLevel.map { $0.isBoss ? "BOSS LEVEL" : "LEVEL \($0.number)" }
            ?? (game.isEndless ? "ENDLESS" : "FREE PLAY")
        addLabel(world.title.uppercased(), font: "AvenirNext-Heavy", size: 16, color: world.accentLight,
                 at: CGPoint(x: rect.minX + 58, y: rect.midY + 7), alignment: .left)
        addLabel(subtitle, font: "AvenirNext-Bold", size: 9, color: Self.glassSubtext,
                 at: CGPoint(x: rect.minX + 58, y: rect.midY - 10), alignment: .left)

        let scoreColor = trial == nil ? activeLevel.map { game.score >= $0.targetScore ? Palette.mint : .white } ?? .white : .white
        addSmallStat(title: "TIME", value: clockText, x: rect.maxX - 14, y: rect.midY, name: "clock-label",
                     valueColor: clockColor, titleColor: Self.glassSubtext)
        addSmallStat(title: "SCORE", value: "\(displayedScore)", x: rect.maxX - 66, y: rect.midY, name: "score-label",
                     valueColor: scoreColor, titleColor: Self.glassSubtext)
        if let trial {
            addSmallStat(title: "TRIAL", value: "\(min(trial.progress, trial.kind.goal))/\(trial.kind.goal)",
                         x: rect.maxX - 120, y: rect.midY, valueColor: Self.glassSubtext, titleColor: Self.glassSubtext)
        } else if let level = activeLevel {
            addSmallStat(title: "GOAL", value: "\(level.targetScore)", x: rect.maxX - 120, y: rect.midY, name: "goal-label",
                         valueColor: Self.glassSubtext, titleColor: Self.glassSubtext)
        } else if game.isEndless {
            addSmallStat(title: "PILE", value: pileText, x: rect.maxX - 120, y: rect.midY, name: "pile-label",
                         valueColor: pileColor, titleColor: Self.glassSubtext)
        }
    }

    /// One ball per star word under the top bar, filled for every one found so far (on any
    /// play of this level); this round's finds wear a white ring.
    func drawThemeDots(centerX: CGFloat, y: CGFloat) {
        let count = starWords.count
        let thisRound = starWordsFoundThisRound
        let collected = activeLevel.map(collectedThemeWords) ?? thisRound
        // Balls fill left to right: every star word found so far, ringed if found this round.
        let row = makeStarBalls(total: count, filled: collected, ringed: (collected - thisRound)..<collected,
                                radius: 6, spacing: 18, empty: SKColor(white: 1, alpha: 0.6))
        row.position = CGPoint(x: centerX, y: y)
        row.zPosition = 2
        row.name = "star-balls"
        addChild(row)
        let width = CGFloat(count - 1) * 18
        addLabel("STAR WORDS", font: "AvenirNext-Heavy", size: 9, color: Self.glassSubtext,
                 at: CGPoint(x: centerX - width / 2 - 14, y: y), alignment: .right, z: 2)
        addLabel("\(collected)/\(count)", font: "AvenirNext-Heavy", size: 10,
                 color: collected == count ? Palette.gold : Self.glassSubtext,
                 at: CGPoint(x: centerX + width / 2 + 14, y: y), alignment: .left, z: 2)
    }

    /// A row of star-word balls centered on the origin: `filled` gold ones, then empty rings.
    func makeStarBalls(total: Int, filled: Int, ringed: Range<Int> = 0..<0, radius: CGFloat, spacing: CGFloat,
                       empty: SKColor) -> SKNode {
        let row = SKNode()
        let startX = -CGFloat(total - 1) * spacing / 2
        for index in 0..<total {
            let ball = SKShapeNode(circleOfRadius: radius)
            let isFilled = index < filled
            ball.fillColor = isFilled ? Palette.gold : .clear
            ball.strokeColor = isFilled ? (ringed.contains(index) ? .white : Palette.gold) : empty
            ball.lineWidth = isFilled && ringed.contains(index) ? 2 : 1.5
            ball.position = CGPoint(x: startX + CGFloat(index) * spacing, y: 0)
            ball.name = "star-ball-\(index)"
            row.addChild(ball)
        }
        return row
    }

    static let rules: [(symbol: String, title: String, text: String)] = [
        ("hand.tap.fill", "Spell words",
         "Tap the bright letters to spell words of 3 or more letters. Taking a letter uncovers the one behind it."),
        ("delete.backward.fill", "Fix mistakes",
         "Tap the last letter again or press the backspace button to take it back. CLEAR starts the word over."),
        ("star.fill", "Score points",
         "Rare letters like Q, Z, X and J are worth the most. A word's letter values are multiplied by its length minus 2, so longer words pay far more."),
        ("sparkles", "Bonuses",
         "Red letters count double. Each round hides themed words — spell one for double points. Each level has 4 star words, tracked by the dots under the top bar. Ones you haven't found yet start on top, and finds carry over between plays: get all 4 for the level's star."),
        ("timer", "Beat the clock",
         "Clear every letter before time runs out for 5 bonus points per second left."),
        ("flag.checkered", "Playthrough",
         "Reach the goal score to pass a level. Pass 3 levels in a world to unlock the next."),
        ("crown.fill", "Boss levels",
         "Each world ends with a boss level with a twist — wind, juggling, traffic, currents, lava or low gravity."),
        ("trophy.fill", "Free Play & Endless",
         "Beat a world's 5 levels to open its Free Play: any pile size and time, or Endless where letters keep falling."),
        ("questionmark", "Wild letters",
         "A gold ? on bigger boards can be any letter you need. It's free to use but worth no points itself."),
        ("lightbulb.fill", "Stuck?",
         "HINT shows a word to look for. MIX — or shaking your phone — shuffles the uncovered letters."),
    ]

    /// A rules card over the menu, themed to the selected world.
    func drawRules() {
        let safe = safeFrame
        let theme = menuTheme
        let width = min(390, safe.width - 32)
        let textWidth = width - 86
        let font = UIFont(name: "AvenirNext-Medium", size: 13) ?? .systemFont(ofSize: 13)
        // Measure each rule so the card fits its text exactly.
        let bodyHeights = Self.rules.map { rule in
            ceil((rule.text as NSString).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                                                     options: .usesLineFragmentOrigin, attributes: [.font: font],
                                                     context: nil).height)
        }
        let rowGap: CGFloat = 12
        let headerHeight: CGFloat = 64
        let contentHeight = bodyHeights.reduce(0) { $0 + $1 + 18 + rowGap }
        let height = min(headerHeight + contentHeight + 12, safe.height - 24)
        // Squeeze the font a little on short screens rather than overflow.
        let scale = min(1, (height - headerHeight - 12) / contentHeight)

        let card = drawOverlayCard(title: "HOW TO PLAY", width: width, height: height)
        let top = height / 2
        let left = -width / 2

        var y = top - headerHeight
        for (rule, bodyHeight) in zip(Self.rules, bodyHeights) {
            let rowTop = y
            if let icon = makeSymbol(rule.symbol, pointSize: 15 * scale, color: theme.accent) {
                let badge = SKShapeNode(circleOfRadius: 17 * scale)
                badge.fillColor = theme.chip
                badge.strokeColor = .clear
                badge.position = CGPoint(x: left + 38, y: rowTop - 17 * scale)
                badge.zPosition = 1
                icon.zPosition = 1
                badge.addChild(icon)
                card.addChild(badge)
            }
            let heading = makeLabel(rule.title.uppercased(), font: "AvenirNext-Heavy", size: 12 * scale,
                                    color: theme.deepAccent, alignment: .left)
            heading.verticalAlignmentMode = .top
            heading.position = CGPoint(x: left + 66, y: rowTop)
            heading.zPosition = 1
            card.addChild(heading)
            let body = SKLabelNode(fontNamed: "AvenirNext-Medium")
            body.text = rule.text
            body.fontSize = 13 * scale
            body.fontColor = Palette.ink.withAlphaComponent(0.8)
            body.numberOfLines = 0
            body.preferredMaxLayoutWidth = textWidth
            body.lineBreakMode = .byWordWrapping
            body.horizontalAlignmentMode = .left
            body.verticalAlignmentMode = .top
            body.position = CGPoint(x: left + 66, y: rowTop - 17 * scale)
            body.zPosition = 1
            card.addChild(body)
            y -= (bodyHeight + 18 + rowGap) * scale
        }
    }

    /// The pause menu: resume, restart, sound and exit, themed to the world.
    func drawExitConfirmation() {
        let safe = safeFrame
        let world = game.world
        let dimmer = SKShapeNode(rect: frame)
        dimmer.fillColor = Palette.ink.withAlphaComponent(0.6)
        dimmer.strokeColor = .clear
        dimmer.zPosition = 100
        addChild(dimmer)

        let panelWidth = min(340, safe.width - 42)
        let buttonWidth = panelWidth - 48
        let panelHeight: CGFloat = 340
        let panel = roundedRect(size: CGSize(width: panelWidth, height: panelHeight), radius: 26,
                                fill: Palette.paper, stroke: world.accent.withAlphaComponent(0.4))
        panel.position = CGPoint(x: safe.midX, y: safe.midY)
        panel.zPosition = 101
        panel.name = "exit-card"
        addChild(panel)

        let top = panelHeight / 2
        if let icon = makeSymbol("pause.circle.fill", pointSize: 34, color: world.accent) {
            icon.position = CGPoint(x: 0, y: top - 40)
            icon.zPosition = 2
            panel.addChild(icon)
        }
        let title = makeLabel("PAUSED", font: "AvenirNext-Heavy", size: 24, color: Palette.ink)
        title.position = CGPoint(x: 0, y: top - 82)
        title.zPosition = 2
        panel.addChild(title)
        let roundName = trial.map { "Myth trial: \($0.kind.title)" }
            ?? activeLevel.map { $0.isBoss ? "\(world.title) boss level" : "\(world.title) level \($0.number)" }
            ?? (game.isEndless ? "\(world.title) Endless" : "\(world.title) Free Play")
        let subtitle = makeLabel(roundName, font: "AvenirNext-DemiBold", size: 13, color: Palette.muted)
        subtitle.position = CGPoint(x: 0, y: top - 106)
        subtitle.zPosition = 2
        panel.addChild(subtitle)

        var y = top - 150
        addButton(title: "RESUME", name: "action-resume", size: CGSize(width: buttonWidth, height: 50),
                  color: world.accent, at: CGPoint(x: 0, y: y), fontSize: 15, zPosition: 2, in: panel,
                  symbol: "play.fill")
        y -= 58
        let half = (buttonWidth - 10) / 2
        addButton(title: "RESTART", name: "action-restart", size: CGSize(width: half, height: 44),
                  color: Palette.gold, at: CGPoint(x: -half / 2 - 5, y: y), fontSize: 13, zPosition: 2, in: panel,
                  symbol: "arrow.counterclockwise")
        addButton(title: sound.isEnabled ? "SOUND" : "MUTED", name: "action-pause-sound",
                  size: CGSize(width: half, height: 44), color: Palette.muted,
                  at: CGPoint(x: half / 2 + 5, y: y), fontSize: 13, zPosition: 2, in: panel,
                  symbol: sound.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
        y -= 54
        addButton(title: "EXIT TO HOME", name: "action-exit-confirm", size: CGSize(width: buttonWidth, height: 44),
                  color: Palette.coral, at: CGPoint(x: 0, y: y), fontSize: 13, zPosition: 2, in: panel)
        let note = makeLabel("Exiting won't save this round's score.", font: "AvenirNext-Medium", size: 11,
                             color: Palette.muted)
        note.position = CGPoint(x: 0, y: y - 36)
        note.zPosition = 2
        panel.addChild(note)
    }

    /// Draws each stack as a bare exposed letter with faded covered letters peeking out
    /// above it, deeper ones fainter. Stacks are scattered freely rather than gridded.
    func drawPile(in area: CGRect) {
        pileArea = area
        addMarker("pile-area", frame: area)
        // Bigger boards show fewer covered letters so the screen stays readable.
        let covered = min(game.stacks.count > 8 ? 1 : 2, game.boardSize.layerCount - 1)
        let layout = pileLayout(count: game.stacks.count, in: area, covered: covered)
        let side = layout.side
        let exposed = game.exposedTileIDs
        for lane in 0..<game.stacks.count {
            let base = layout.bases[lane]
            let stack = game.stacks[lane].filter { !$0.removed && !game.selectedTileIDs.contains($0.id) }
            for (depth, tile) in stack.reversed().prefix(covered + 1).enumerated() {
                let node = makeLetter(tile, side: side, depth: depth, exposed: tile.id == exposed[lane])
                node.position = CGPoint(x: base.x + CGFloat(depth) * side * 0.08,
                                        y: base.y + CGFloat(depth) * side * Self.depthStep)
                node.zPosition = CGFloat(10 - depth)
                node.zRotation = (jitter(tile.id, 3) - 0.5) * 0.36
                if hiddenInPile.contains(tile.id) { node.alpha = 0 }
                // Remember the resting spot, for bosses that make letters float around it.
                node.userData = ["base": NSValue(cgPoint: node.position), "rotation": node.zRotation]
                addChild(node)
            }
        }
    }

    static let depthStep: CGFloat = 0.45

    /// Exposed-letter positions for each stack, cached until the round, area or stack count changes.

    func pileLayout(count: Int, in area: CGRect, covered: Int) -> (bases: [CGPoint], side: CGFloat) {
        let key = "\(layoutSeed) \(count) \(covered) \(area.integral)"
        if let cached = cachedPileLayout, cached.key == key { return (cached.bases, cached.side) }
        let layout = scatterStacks(count: count, in: area, covered: covered)
        cachedPileLayout = (key, layout.bases, layout.side)
        return layout
    }

    /// Places stacks with best-candidate sampling: each stack tries many random spots and
    /// keeps the one farthest from the others, rejecting any that would overlap. If the
    /// letters don't fit, it shrinks them and tries again.
    func scatterStacks(count: Int, in area: CGRect, covered: Int) -> (bases: [CGPoint], side: CGFloat) {
        var side = min(64, (area.width * area.height / CGFloat(count)).squareRoot() * 0.62)
        for attempt in 0..<10 {
            // Footprint of one stack: the exposed glyph plus the covered letters above it.
            let width = side * 1.15
            let height = side * (0.85 + Self.depthStep * CGFloat(covered))
            let bounds = area.insetBy(dx: width / 2, dy: height / 2)
            guard bounds.width > 0, bounds.height > 0 else { side *= 0.9; continue }
            var rng = SeededGenerator(seed: UInt64(truncatingIfNeeded: layoutSeed &* 31 &+ attempt))
            var centers: [CGPoint] = []
            for _ in 0..<count {
                var best: CGPoint?
                var bestDistance = -CGFloat.infinity
                for _ in 0..<60 {
                    let candidate = CGPoint(x: CGFloat.random(in: bounds.minX...bounds.maxX, using: &rng),
                                            y: CGFloat.random(in: bounds.minY...bounds.maxY, using: &rng))
                    var nearest = CGFloat.infinity
                    var overlaps = false
                    for other in centers {
                        let dx = abs(candidate.x - other.x) / width
                        let dy = abs(candidate.y - other.y) / height
                        if dx < 1.08 && dy < 1.08 { overlaps = true; break }
                        nearest = min(nearest, dx * dx + dy * dy)
                    }
                    if !overlaps && nearest > bestDistance {
                        best = candidate
                        bestDistance = nearest
                    }
                }
                guard let best else { break }
                centers.append(best)
            }
            if centers.count == count {
                // Convert footprint centers to exposed-letter positions (bottom of the footprint).
                let lift = height / 2 - side * 0.45
                return (centers.map { CGPoint(x: $0.x, y: $0.y - lift) }, side)
            }
            side *= 0.92
        }
        // Fallback: a plain grid, which always fits.
        let columns = game.boardSize.columns
        let rows = (count + columns - 1) / columns
        let cell = CGSize(width: area.width / CGFloat(columns), height: area.height / CGFloat(rows))
        let fitted = min(side, cell.width * 0.8, cell.height / (1 + Self.depthStep * CGFloat(covered)) * 0.9)
        let bases = (0..<count).map { lane in
            CGPoint(x: area.minX + cell.width * (CGFloat(lane % columns) + 0.5),
                    y: area.maxY - cell.height * (CGFloat(lane / columns) + 0.5) - fitted * Self.depthStep * CGFloat(covered) / 2)
        }
        return (bases, fitted)
    }

    /// A stable pseudo-random value in 0..<1 for `key`, fixed for the whole round
    /// so letters keep their placement and tilt across re-renders.
    func jitter(_ key: Int, _ salt: Int) -> CGFloat {
        var hasher = Hasher()
        hasher.combine(layoutSeed)
        hasher.combine(key)
        hasher.combine(salt)
        return CGFloat(UInt(bitPattern: hasher.finalize()) % 10_000) / 10_000
    }

    /// An invisible node covering `frame`, for the tutorial to spotlight.
    func addMarker(_ name: String, frame: CGRect) {
        let marker = SKSpriteNode(color: .clear, size: frame.size)
        marker.position = CGPoint(x: frame.midX, y: frame.midY)
        marker.name = name
        addChild(marker)
    }

    func drawControls(in area: CGRect) {
        let world = game.world
        let panel = roundedRect(size: CGSize(width: area.width + 20, height: area.height + 16), radius: 24,
                                fill: world.glass, stroke: Self.glassEdge)
        panel.position = CGPoint(x: area.midX, y: area.midY)
        panel.zPosition = 0.5
        addChild(panel)

        let cardWidth = area.width
        let wordCard = roundedRect(size: CGSize(width: cardWidth, height: 64), radius: 18,
                                   fill: SKColor(white: 1, alpha: 0.08), stroke: world.accentLight.withAlphaComponent(0.35))
        wordCard.name = "word-card"
        wordCard.position = CGPoint(x: area.midX, y: area.maxY - 34)
        wordCard.zPosition = 1
        addChild(wordCard)
        let display = game.currentWord.isEmpty ? "YOUR WORD" : game.currentWord
        let fontSize = fittedFontSize(for: display, max: 29, width: cardWidth - 48)
        let wordLabel = addLabel(display, font: "AvenirNext-Heavy", size: fontSize,
                                 color: game.currentWord.isEmpty ? SKColor(white: 1, alpha: 0.28) : .white,
                                 at: wordCard.position, alignment: .center, name: "word-label", z: 3)
        if !game.currentWord.isEmpty {
            wordLabel.attributedText = attributedWord(game.selectedTiles, fontSize: fontSize)
        }

        let actionY = area.maxY - 104
        let smallWidth = min(74, (cardWidth - 176) / 2)
        let eraseTint = tintedGlass(Self.eraseRed, world: world)
        addButton(title: "CLEAR", name: "action-clear", size: CGSize(width: smallWidth, height: 42),
                  color: eraseTint, at: CGPoint(x: area.minX + smallWidth / 2, y: actionY), fontSize: 11)
        addButton(title: "SUBMIT", name: "action-submit", size: CGSize(width: 150, height: 48),
                  color: world.accent, at: CGPoint(x: area.midX, y: actionY))
        addIconButton(systemName: "delete.backward.fill", name: "action-undo",
                      size: CGSize(width: smallWidth, height: 42), fillColor: eraseTint, iconColor: .white,
                      stroke: Self.glassEdge, at: CGPoint(x: area.maxX - smallWidth / 2, y: actionY))

        let lowerY = area.minY + 22
        addButton(title: "HINT", name: "action-hint", size: CGSize(width: 76, height: 36),
                  color: Palette.gold, at: CGPoint(x: area.minX + 38, y: lowerY), fontSize: 12)
        addButton(title: "MIX", name: "action-shuffle", size: CGSize(width: 66, height: 36),
                  color: tintedGlass(Self.mixGreen, world: world), at: CGPoint(x: area.maxX - 33, y: lowerY), fontSize: 12)
        // Long messages wrap onto a second line instead of shrinking to an unreadable size.
        let status = addLabel(statusMessage, font: "AvenirNext-DemiBold", size: 12,
                              color: onGlass(statusColor), at: CGPoint(x: area.midX, y: lowerY), alignment: .center,
                              name: "status-label")
        status.numberOfLines = 2
        status.preferredMaxLayoutWidth = cardWidth - 176
        status.lineBreakMode = .byWordWrapping
        // The slot between the action rows holds goal progress, then the finish button.
        let slotY = (actionY - 24 + lowerY + 18) / 2
        drawGoalBar(center: CGPoint(x: area.midX, y: slotY), width: cardWidth)
    }

    static let glassEdge = SKColor(white: 1, alpha: 0.10)
    static let eraseRed = SKColor(red: 0.86, green: 0.36, blue: 0.34, alpha: 1)
    static let mixGreen = SKColor(red: 0.36, green: 0.70, blue: 0.48, alpha: 1)

    /// A muted, see-through tint for a control, pulled a little toward the world's accent
    /// so it sits in every world's glass panel.
    func tintedGlass(_ color: SKColor, world: World) -> SKColor {
        Palette.mix(color, world.accent, 0.2).withAlphaComponent(0.42)
    }
    static let glassButton = SKColor(white: 1, alpha: 0.14)
    static let glassSubtext = SKColor(white: 1, alpha: 0.62)

    /// Status colors are chosen for light backgrounds; lift them for the dark glass.
    func onGlass(_ color: SKColor) -> SKColor {
        switch color {
        case Palette.teal: Palette.mint
        case Palette.coral: Palette.softCoral
        case Palette.muted: Self.glassSubtext
        default: color
        }
    }

    var clockColor: SKColor {
        // Endless counts up, so it never runs low.
        guard !game.isEndless else { return .white }
        return timeRemaining <= 10 ? Palette.coral : (timeRemaining < 15 ? Palette.softCoral : .white)
    }

    /// The word in progress, with 2× bonus letters picked out in red.
    func attributedWord(_ tiles: [LetterFlyGame.Tile], fontSize: CGFloat) -> NSAttributedString {
        let font = UIFont(name: "AvenirNext-Heavy", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        let text = NSMutableAttributedString()
        for tile in tiles {
            let color = letterColor(for: tile)
            text.append(NSAttributedString(string: String(tile.shown), attributes: [
                .font: font,
                .foregroundColor: hiddenInWord.contains(tile.id) ? SKColor.clear : color
            ]))
        }
        return text
    }
}
