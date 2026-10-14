import SpriteKit
import UIKit

// Rendering, backgrounds and the home screen.
extension GameScene {
    // MARK: - Rendering

    func render() {
        pressedNode = nil
        for child in children where child !== backdrop && child !== overlay && child !== transitionLayer {
            child.removeFromParent()
        }
        if screen != .playing { overlay.removeAllChildren() }
        updateBackground()
        switch screen {
        case .menu:
            drawMenu()
            isDrawingMenuOverlay = true
            defer { isDrawingMenuOverlay = false }
            switch menuOverlay {
            case .rules: drawRules()
            case .settings: drawSettings()
            case .stats: drawStats()
            case .confirmReset: drawConfirmReset()
            case nil:
                startHomeTourIfPending()
                drawHomeTour()
            }
        case .playing:
            drawGame()
            drawTutorial()
            drawTrialIntro()
            if isConfirmingExit { drawExitConfirmation() }
        case .finished: drawFinished()
        }
        // Ease each new screen in rather than cutting to it.
        if lastRenderedScreen != screen {
            for child in children where child !== backdrop && child !== overlay && child !== transitionLayer {
                child.alpha = 0
                child.run(.fadeIn(withDuration: 0.22))
            }
            lastRenderedScreen = screen
        }
    }

    /// Rebuilds the backdrop only when the world, screen style or scene size changes,
    /// cross-fading from the old one. The menu shows the selected world under a deep,
    /// tinted veil so it reads as a quiet background, whatever the phone's appearance.
    func updateBackground() {
        let onMenu = screen == .menu
        let world = onMenu ? selectedWorld : game.world
        let key = "\(world.rawValue) \(onMenu) \(Int(size.width))x\(Int(size.height))"
        guard key != backgroundKey else { return }
        let sizeChanged = !backgroundKey.hasSuffix("\(Int(size.width))x\(Int(size.height))")
        backgroundKey = key

        let layer = world.makeBackground(size: size)
        layer.zPosition = 0
        if onMenu {
            let veil = SKSpriteNode(color: Palette.mix(Palette.ink, world.accent, 0.18), size: size)
            veil.alpha = 0.8
            veil.zPosition = 50
            layer.addChild(veil)
        }
        if let old = backgroundLayer {
            if sizeChanged {
                old.removeFromParent()
            } else {
                old.zPosition = 1
                old.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
            }
        }
        backdrop.addChild(layer)
        backgroundLayer = layer
    }

    var safeFrame: CGRect {
        guard let view else { return frame }
        let insets = view.safeAreaInsets
        let portrait = size.height >= size.width
        let topInset = max(insets.top, portrait ? 64 : 12)
        let leftInset = max(insets.left, portrait ? 0 : 54)
        let rightInset = max(insets.right, portrait ? 0 : 54)
        return CGRect(x: frame.minX + leftInset, y: frame.minY + insets.bottom,
                      width: size.width - leftInset - rightInset,
                      height: size.height - topInset - insets.bottom)
    }

    /// Lays out blocks of the given heights top to bottom, centered on `centerY`,
    /// calling each block's draw closure with its center.
    func stack(_ blocks: [(height: CGFloat, draw: (CGFloat) -> Void)], centerY: CGFloat, gap: CGFloat) {
        let total = blocks.map(\.height).reduce(0, +) + gap * CGFloat(max(0, blocks.count - 1))
        var top = centerY + total / 2
        for block in blocks {
            block.draw(top - block.height / 2)
            top -= block.height + gap
        }
    }

    // MARK: Menu

    func drawMenu() {
        let safe = safeFrame
        let theme = menuTheme
        addIconButton(systemName: "gearshape.fill", name: "action-settings", size: CGSize(width: 44, height: 40),
                      fillColor: theme.card, iconColor: theme.deepAccent, stroke: theme.stroke,
                      at: CGPoint(x: safe.maxX - 30, y: safe.maxY - 24))
        addIconButton(systemName: "chart.bar.fill", name: "action-stats", size: CGSize(width: 44, height: 40),
                      fillColor: theme.card, iconColor: theme.deepAccent, stroke: theme.stroke,
                      at: CGPoint(x: safe.maxX - 82, y: safe.maxY - 24))
        addIconButton(systemName: "questionmark", name: "action-rules", size: CGSize(width: 44, height: 40),
                      fillColor: theme.card, iconColor: theme.deepAccent, stroke: theme.stroke,
                      at: CGPoint(x: safe.minX + 30, y: safe.maxY - 24))

        if selectedWorld == .myth {
            drawMythMenu(in: safe)
            return
        }
        mythBugStop = nil
        if safe.width > safe.height {
            drawLandscapeMenu(in: safe)
            return
        }
        let compact = safe.height < 720
        let width = min(safe.width - 32, 420)
        var blocks: [(height: CGFloat, draw: (CGFloat) -> Void)] = []
        if !compact {
            blocks.append((104, { [unowned self] y in
                let logo = makeLogo(size: Self.homeLogoSize)
                logo.name = "home-logo"
                logo.position = CGPoint(x: safe.midX, y: y)
                addTapTarget(to: logo, size: CGSize(width: 130, height: 110))
                addChild(logo)
            }))
        }
        blocks.append((44, { [unowned self] y in
            addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: compact ? 40 : 46,
                     color: Palette.cream,
                     at: CGPoint(x: safe.midX, y: y), alignment: .center, name: "home-title")
        }))
        blocks.append((setupCardHeight, { [unowned self] y in
            drawSetupCard(center: CGPoint(x: safe.midX, y: y), width: width)
        }))
        blocks.append((56, { [unowned self] y in
            let size = CGSize(width: min(width, 300), height: 56)
            let play = addButton(title: playButtonTitle, name: playButtonAction, size: size,
                                 color: theme.accent, at: CGPoint(x: safe.midX, y: y))
            pulse(play, size: size, color: theme.accent)
        }))
        stack(blocks, centerY: safe.midY - 6, gap: compact ? 12 : 16)
        startRoaming()
    }

    func drawLandscapeMenu(in safe: CGRect) {
        let leftX = safe.minX + safe.width * 0.25
        let rightX = safe.minX + safe.width * 0.70
        let leftWidth = min(330, safe.width * 0.42)
        let blocks: [(height: CGFloat, draw: (CGFloat) -> Void)] = [
            (40, { [unowned self] y in
                addLabel("LETTERFLY", font: "AvenirNext-Heavy", size: 38, color: Palette.cream,
                         at: CGPoint(x: leftX, y: y), alignment: .center)
            }),
            (50, { [unowned self] y in
                let size = CGSize(width: min(250, leftWidth), height: 50)
                let play = addButton(title: playButtonTitle, name: playButtonAction, size: size,
                                     color: menuTheme.accent, at: CGPoint(x: leftX, y: y))
                pulse(play, size: size, color: menuTheme.accent)
            })
        ]
        stack(blocks, centerY: safe.midY, gap: 12)
        drawSetupCard(center: CGPoint(x: rightX, y: safe.midY), width: min(410, safe.width * 0.5))
    }

    var showingFreePlay: Bool { isFreePlaySelected && progress.isFreePlayUnlocked(in: selectedWorld) }
    var playButtonTitle: String {
        if showingFreePlay { return selectedRoundDuration == 0 ? "START ENDLESS" : "START FREE PLAY" }
        if isTutorialReplayPending && selectedLevel == Level(world: .storm, number: 1) { return "PLAY TUTORIAL" }
        return selectedLevel.isBoss ? "PLAY BOSS LEVEL" : "PLAY LEVEL \(selectedLevel.number)"
    }
    var playButtonAction: String { showingFreePlay ? "action-free-play" : "action-play" }

    var setupCardHeight: CGFloat { showingFreePlay ? 330 : 250 }

    /// The menu card: world picker on top, then the world's levels.
    func drawSetupCard(center: CGPoint, width: CGFloat) {
        let height = setupCardHeight
        let theme = menuTheme
        let card = roundedRect(size: CGSize(width: width, height: height), radius: 22,
                               fill: theme.card, stroke: theme.stroke)
        card.position = center
        card.zPosition = 2
        addChild(card)
        let top = center.y + height / 2
        let left = center.x - width / 2 + 18
        let inner = width - 30

        addLabel("WORLD", font: "AvenirNext-Bold", size: 11, color: theme.subtext,
                 at: CGPoint(x: left, y: top - 24), alignment: .left, z: 4)
        addLabel(selectedWorld.title.uppercased(), font: "AvenirNext-Heavy", size: 11, color: theme.deepAccent,
                 at: CGPoint(x: center.x + width / 2 - 18, y: top - 24), alignment: .right, z: 4)
        drawWorldChoices(centerX: center.x, y: top - 72, width: inner)
        addMarker("menu-worlds", frame: CGRect(x: center.x - inner / 2, y: top - 104, width: inner, height: 64))

        drawLevelChoices(centerX: center.x, top: top - 112, left: left, width: inner)
    }

    func drawWorldChoices(centerX: CGFloat, y: CGFloat, width: CGFloat) {
        // Wide enough that neighboring tiles' progress rings don't run together.
        let gap: CGFloat = 12
        // Myth stays a secret until every main world is mastered.
        let worlds = World.main + (progress.isUnlocked(.myth) ? [.myth] : [])
        let count = CGFloat(worlds.count)
        let chipWidth = (width - gap * (count - 1)) / count
        let chipSize = CGSize(width: chipWidth, height: 58)
        markExistingUnlocksSeen()
        for world in worlds {
            let unlocked = progress.isUnlocked(world)
            let selected = world == selectedWorld
            let name = "action-world-\(world.rawValue)"
            let x = centerX - width / 2 + chipWidth / 2 + CGFloat(world.rawValue) * (chipWidth + gap)
            let chip = roundedRect(size: chipSize, radius: 12, fill: Palette.ink, stroke: .clear)
            chip.position = CGPoint(x: x, y: y)
            chip.zPosition = 5
            chip.name = name
            addChild(chip)

            // A live, tiny version of the world's backdrop fills the tile.
            let preview = worldPreview(world, size: chipSize)
            preview.removeFromParent()
            preview.alpha = unlocked ? 1 : 0.3
            preview.zPosition = 0.1
            chip.addChild(preview)
            let shade = roundedRect(size: chipSize, radius: 12, fill: SKColor(white: 0, alpha: unlocked ? 0.18 : 0.4), stroke: .clear)
            shade.zPosition = 0.5
            shade.name = name
            chip.addChild(shade)

            if let icon = makeSymbol(unlocked ? world.symbolName : "lock.fill", pointSize: 17,
                                     color: unlocked ? .white : SKColor(white: 1, alpha: 0.7)) {
                icon.position.y = 8
                icon.zPosition = 1
                icon.name = name
                chip.addChild(icon)
            }
            let title = makeLabel(world.title.uppercased(), font: "AvenirNext-Heavy", size: min(9, chipWidth / 6.2),
                                  color: unlocked ? .white : SKColor(white: 1, alpha: 0.6), name: name)
            title.position.y = -16
            title.zPosition = 1
            chip.addChild(title)

            drawProgressRing(on: chip, world: world, size: chipSize, selected: selected)
            if progress.isMastered(world) {
                let star = makeStar(radius: 9)
                star.position = CGPoint(x: chipWidth / 2 - 4, y: 25)
                star.zPosition = 3
                star.name = name
                chip.addChild(star)
            }
            if selected {
                chip.run(.sequence([.scale(to: 1.08, duration: 0.10), .scale(to: 1.03, duration: 0.10)]))
            }
            if unlocked && !hasSeenUnlock(world) { playUnlockBurst(on: chip, world: world) }
        }
    }

    /// One cropped, animated backdrop per world, built once and reused across redraws.
    func worldPreview(_ world: World, size: CGSize) -> SKCropNode {
        if let cached = worldPreviews[world], cached.userData?["size"] as? CGSize == size { return cached }
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: size, cornerRadius: 12)
        mask.fillColor = .white
        mask.strokeColor = .clear
        crop.maskNode = mask
        // Draw the world at twice the size, then shrink it, so details aren't cramped.
        let backdrop = world.makeBackground(size: CGSize(width: size.width * 2.2, height: size.height * 2.2))
        backdrop.setScale(1 / 2.2)
        backdrop.zPosition = 0
        crop.addChild(backdrop)
        crop.userData = ["size": size]
        worldPreviews[world] = crop
        return crop
    }

    /// A ring around the tile with one segment per level: dim until beaten, white once
    /// beaten, and gold when that level also has its star.
    func drawProgressRing(on chip: SKNode, world: World, size: CGSize, selected: Bool) {
        let ringSize = CGSize(width: size.width + 5, height: size.height + 5)
        let points = Self.roundedRectPerimeter(size: ringSize, radius: 14, samples: 180)
        let segments = Level.countPerWorld
        let beaten = progress.levelsBeaten(in: world)
        let theme = menuTheme
        let per = points.count / segments
        for index in 0..<segments {
            let level = Level(world: world, number: index + 1)
            let gapSamples = max(2, per / 10)
            let slice = Array(points[(index * per + gapSamples)...(index * per + per - gapSamples)])
            let path = CGMutablePath()
            path.addLines(between: slice)
            let segment = SKShapeNode(path: path)
            segment.lineWidth = selected ? 3.5 : 2.5
            segment.lineCap = .round
            segment.strokeColor = progress.hasStar(level) ? Palette.gold
                : (index < beaten ? (selected ? world.accentLight : theme.notchDone) : theme.notchOpen)
            segment.zPosition = 2
            chip.addChild(segment)
        }
    }

    /// Points around a rounded rectangle centered on the origin, clockwise from top center.
    static func roundedRectPerimeter(size: CGSize, radius: CGFloat, samples: Int) -> [CGPoint] {
        let path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
                          cornerWidth: radius, cornerHeight: radius, transform: nil)
        // Flatten the outline into short straight pieces.
        var raw: [CGPoint] = []
        path.applyWithBlock { element in
            let p = element.pointee
            switch p.type {
            case .moveToPoint, .addLineToPoint: raw.append(p.points[0])
            case .addQuadCurveToPoint:
                let start = raw.last ?? p.points[1]
                for step in 1...8 {
                    let t = CGFloat(step) / 8
                    let a = 1 - t
                    raw.append(CGPoint(x: a * a * start.x + 2 * a * t * p.points[0].x + t * t * p.points[1].x,
                                       y: a * a * start.y + 2 * a * t * p.points[0].y + t * t * p.points[1].y))
                }
            case .addCurveToPoint:
                let start = raw.last ?? p.points[2]
                for step in 1...8 {
                    let t = CGFloat(step) / 8
                    let a = 1 - t
                    let c = (a * a * a, 3 * a * a * t, 3 * a * t * t, t * t * t)
                    raw.append(CGPoint(x: c.0 * start.x + c.1 * p.points[0].x + c.2 * p.points[1].x + c.3 * p.points[2].x,
                                       y: c.0 * start.y + c.1 * p.points[0].y + c.2 * p.points[1].y + c.3 * p.points[2].y))
                }
            case .closeSubpath: if let first = raw.first { raw.append(first) }
            @unknown default: break
            }
        }
        // Resample evenly by distance, starting from the top center and going clockwise.
        var lengths: [CGFloat] = [0]
        for index in 1..<raw.count {
            lengths.append(lengths[index - 1] + hypot(raw[index].x - raw[index - 1].x, raw[index].y - raw[index - 1].y))
        }
        let total = lengths.last ?? 1
        var even: [CGPoint] = []
        var cursor = 0
        for sample in 0...samples {
            let target = total * CGFloat(sample) / CGFloat(samples)
            while cursor < lengths.count - 2 && lengths[cursor + 1] < target { cursor += 1 }
            let span = max(0.0001, lengths[cursor + 1] - lengths[cursor])
            let t = (target - lengths[cursor]) / span
            let a = raw[cursor], b = raw[cursor + 1]
            even.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
        }
        let topIndex = even.indices.max { even[$0].y - abs(even[$0].x) < even[$1].y - abs(even[$1].x) } ?? 0
        var ordered = Array(even[topIndex...] + even[..<topIndex])
        // Make it clockwise: after the top center, the next point should move right.
        if ordered.count > 1, ordered[1].x < ordered[0].x { ordered = [ordered[0]] + ordered.dropFirst().reversed() }
        return ordered
    }

    // MARK: Unlock bursts

    func hasSeenUnlock(_ world: World) -> Bool {
        world == .storm || UserDefaults.standard.bool(forKey: "seenUnlock.\(world.rawValue)")
    }

    /// Worlds already unlocked before this feature existed shouldn't all burst at once.
    func markExistingUnlocksSeen() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "seenUnlock.initialized") else { return }
        defaults.set(true, forKey: "seenUnlock.initialized")
        for world in World.main where progress.isUnlocked(world) {
            defaults.set(true, forKey: "seenUnlock.\(world.rawValue)")
        }
    }

    /// The first time a newly unlocked world appears: its lock pops off with a burst.
    func playUnlockBurst(on chip: SKNode, world: World) {
        UserDefaults.standard.set(true, forKey: "seenUnlock.\(world.rawValue)")
        let position = chip.position
        if let lock = makeSymbol("lock.open.fill", pointSize: 22, color: .white) {
            lock.position = CGPoint(x: position.x, y: position.y + 6)
            lock.zPosition = 120
            addChild(lock)
            lock.run(.sequence([
                .wait(forDuration: 0.35),
                .group([.moveBy(x: 0, y: 50, duration: 0.5), .rotate(byAngle: 0.8, duration: 0.5),
                        .scale(to: 1.6, duration: 0.5), .fadeOut(withDuration: 0.5)]),
                .removeFromParent()
            ]))
        }
        chip.setScale(0.6)
        chip.run(.sequence([.wait(forDuration: 0.4), .scale(to: 1.25, duration: 0.18), .scale(to: 1, duration: 0.14)]))
        run(.sequence([.wait(forDuration: 0.45), .run { [weak self] in
            self?.emitCelebration(from: position, count: 30)
            self?.sound.play(.levelPassed)
            self?.haptics.success()
        }]))
    }

    // MARK: Roaming mascot

    /// Every so often the home-screen ladybug flies over, perches on the title, then returns.
    func startRoaming() {
        guard let logo = childNode(withName: "home-logo"), let title = childNode(withName: "home-title") else { return }
        let home = logo.position
        let titleTop = title.position.y + title.frame.height / 2 + 26
        let halfWidth = title.frame.width / 2 * 0.75
        logo.run(.repeatForever(.sequence([
            .wait(forDuration: 10, withRange: 6),
            .run { [weak self, weak logo] in
                guard let self, let logo, logo.action(forKey: "fly-across") == nil,
                      logo.action(forKey: "roam") == nil else { return }
                // A bit more than half the time she lands at the end of the title, so her Y spells LETTERFLYY.
                if Double.random(in: 0..<1) < 0.6 {
                    self.spellName(logo, title: title, home: home)
                    return
                }
                let perch = CGPoint(x: home.x + CGFloat.random(in: -halfWidth...halfWidth), y: titleTop)
                self.flyMascot(logo, to: perch, then: [
                    .wait(forDuration: 2.5),
                    .run { [weak self, weak logo] in
                        guard let self, let logo else { return }
                        self.flyMascot(logo, to: home, then: [])
                    }
                ])
            }
        ])), withKey: "roam-timer")
    }

    /// Flies the mascot to the end of the title with her tile lined up as its last letter,
    /// sliding the title over so the whole name stays centered, then flies her home.
    func spellName(_ logo: SKNode, title: SKNode, home: CGPoint) {
        let size = Self.homeLogoSize
        let scale: CGFloat = 1.3
        let tileWidth = 0.30 * size * scale
        let shift = tileWidth / 2 + 3
        let tileCenter = CGPoint(x: title.position.x + title.frame.width / 2 - shift + 1 + tileWidth / 2,
                                 y: title.position.y + 3)
        // The tile hangs below and to the right of the bug's center (see `makeLogo`).
        let perch = CGPoint(x: tileCenter.x - 0.24 * size * scale, y: tileCenter.y + 0.31 * size * scale)
        let slide = SKAction.moveBy(x: -shift, y: 0, duration: 0.9)
        slide.timingMode = .easeInEaseOut
        title.run(.sequence([.wait(forDuration: 0.2), slide]))
        logo.run(.scale(to: scale, duration: 1.1))
        flyMascot(logo, to: perch, then: [
            .wait(forDuration: 3.5),
            .run { [weak self, weak logo, weak title] in
                guard let self, let logo else { return }
                title?.run(slide.reversed())
                logo.run(.scale(to: 1, duration: 1.1))
                self.flyMascot(logo, to: home, then: [])
            }
        ])
    }

    static let homeLogoSize: CGFloat = 120

    /// Flies the mascot along a gentle arc to `target`, facing its direction of travel.
    func flyMascot(_ logo: SKNode, to target: CGPoint, then after: [SKAction]) {
        let start = logo.position
        setFacing(logo, left: target.x < start.x - 4)
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: target, control: CGPoint(x: (start.x + target.x) / 2, y: max(start.y, target.y) + 70))
        let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.1)
        fly.timingMode = .easeInEaseOut
        logo.run(.sequence([
            fly,
            .run { [weak self] in self?.setFacing(logo, left: false) },
            .moveBy(x: 0, y: 8, duration: 0.1), .moveBy(x: 0, y: -8, duration: 0.12)
        ] + after), withKey: "roam")
    }

    /// When a world is picked, the mascot does a soft, springy hop: a quick squash, a
    /// smooth rise and an eased landing. No flip, so nothing looks jerky.
    func cheerOnWorldPick() {
        guard let logo = childNode(withName: "home-logo"), logo.action(forKey: "roam") == nil else { return }
        let base = logo.position
        let squash = SKAction.group([.scaleX(to: 1.06, duration: 0.08), .scaleY(to: 0.92, duration: 0.08)])
        let rise = SKAction.group([.moveTo(y: base.y + 16, duration: 0.22), .scaleX(to: 0.97, duration: 0.22),
                                   .scaleY(to: 1.05, duration: 0.22)])
        rise.timingMode = .easeOut
        let fall = SKAction.group([.moveTo(y: base.y, duration: 0.24), .scale(to: 1, duration: 0.24)])
        fall.timingMode = .easeIn
        let settle = SKAction.sequence([.group([.scaleX(to: 1.03, duration: 0.06), .scaleY(to: 0.97, duration: 0.06)]),
                                        .scale(to: 1, duration: 0.1)])
        logo.removeAction(forKey: "cheer")
        logo.run(.sequence([squash, rise, fall, settle]), withKey: "cheer")
    }

    func drawLevelChoices(centerX: CGFloat, top: CGFloat, left: CGFloat, width: CGFloat) {
        let level = selectedLevel
        let theme = menuTheme
        let beaten = progress.levelsBeaten(in: level.world)
        addLabel("LEVEL", font: "AvenirNext-Bold", size: 11, color: theme.subtext,
                 at: CGPoint(x: left, y: top - 12), alignment: .left, z: 4)
        let stars = progress.starCount(in: level.world)
        var header: [InlinePart] = beaten >= Level.countPerWorld
            ? [.symbol("checkmark.circle.fill"), .text("COMPLETE")]
            : [.text("\(beaten) OF \(Level.countPerWorld) DONE")]
        if stars == Level.countPerWorld {
            header += [.symbol("star.fill"), .text("MASTERED")]
        } else if stars > 0 {
            header += [.symbol("star.fill"), .text("\(stars)")]
        }
        let headerRow = makeInlineRow(header, font: "AvenirNext-Heavy", size: 11, color: theme.deepAccent,
                                      alignment: .right)
        headerRow.position = CGPoint(x: centerX + width / 2 + 3, y: top - 12)
        headerRow.zPosition = 4
        addChild(headerRow)

        // Five level dots plus the FREE item at the end of the row.
        let slots = CGFloat(Level.countPerWorld + 1)
        let spacing = min(56, width / slots)
        let rowY = top - 52
        addMarker("menu-levels", frame: CGRect(x: centerX - spacing * slots / 2, y: rowY - 22, width: spacing * slots, height: 44))
        let freeX = centerX + (slots - (slots + 1) / 2) * spacing
        let freeOpen = progress.isFreePlayUnlocked(in: level.world)
        let freeChip = roundedRect(size: CGSize(width: 44, height: 40), radius: 14,
                                   fill: showingFreePlay ? theme.deepAccent : theme.chip,
                                   stroke: showingFreePlay ? theme.deepAccent : theme.line.withAlphaComponent(freeOpen ? 0.25 : 0.1))
        freeChip.lineWidth = showingFreePlay ? 3 : 1.5
        freeChip.position = CGPoint(x: freeX, y: rowY)
        freeChip.zPosition = 5
        freeChip.name = "action-free-select"
        addChild(freeChip)
        if freeOpen {
            freeChip.addChild(makeLabel("FREE", font: "AvenirNext-Heavy", size: 11,
                                        color: showingFreePlay ? .white : theme.deepAccent, name: "action-free-select"))
        } else if let lock = makeSymbol("lock.fill", pointSize: 13, color: theme.subtext.withAlphaComponent(0.6)) {
            lock.name = "action-free-select"
            freeChip.addChild(lock)
        }
        for number in 1...Level.countPerWorld {
            let candidate = Level(world: level.world, number: number)
            let playable = progress.isPlayable(candidate)
            let isBeaten = number <= beaten
            let selected = number == level.number && !showingFreePlay
            let name = "action-level-\(number)"
            let x = centerX + (CGFloat(number) - (slots + 1) / 2) * spacing
            let dot = SKShapeNode(circleOfRadius: 20)
            dot.fillColor = isBeaten ? theme.accent : (selected ? theme.card : theme.chip)
            dot.strokeColor = selected ? theme.deepAccent : theme.line.withAlphaComponent(playable ? 0.25 : 0.1)
            dot.lineWidth = selected ? 3 : 1.5
            dot.position = CGPoint(x: x, y: rowY)
            dot.zPosition = 5
            dot.name = name
            addChild(dot)
            let textColor = isBeaten ? .white : theme.text.withAlphaComponent(playable ? 1 : 0.25)
            if candidate.isBoss {
                // The boss level wears a crown instead of a number.
                dot.fillColor = isBeaten ? Palette.coral : dot.fillColor
                if let crown = makeSymbol("crown.fill", pointSize: 15, color: isBeaten ? .white : Palette.coral.withAlphaComponent(playable ? 1 : 0.35)) {
                    crown.name = name
                    dot.addChild(crown)
                }
            } else {
                dot.addChild(makeCenteredLabel("\(number)", font: "AvenirNext-Heavy", size: 17, color: textColor, name: name))
            }
            if progress.hasStar(candidate) {
                let star = makeStar(radius: 9)
                star.position = CGPoint(x: 15, y: 15)
                star.zPosition = 1
                star.name = name
                dot.addChild(star)
            }
        }

        if showingFreePlay {
            let best = highScores.bestScore(for: selectedBoardSize, duration: selectedRoundDuration)
            let modeName = selectedRoundDuration == 0 ? "ENDLESS" : "FREE PLAY"
            addLabel(best > 0 ? "\(modeName)  •  BEST \(best)" : "\(modeName)  •  NO SCORE YET",
                     font: "AvenirNext-Heavy", size: 11, color: theme.deepAccent,
                     at: CGPoint(x: centerX, y: top - 90), alignment: .center, z: 4)
            drawBoardChoices(centerX: centerX, y: top - 128, width: width, height: 44)
            drawTimeChoices(centerX: centerX, y: top - 178, width: width, height: 44)
            return
        }
        let info = level.isBoss
            ? "BOSS: score \(level.targetScore)  •  \(level.world.bossTwist)"
            : "Score \(level.targetScore) in \(Int(level.duration)) sec  •  \(level.boardSize.title) pile"
        addLabel(info, font: "AvenirNext-DemiBold", size: fittedFontSize(for: info, max: 13, width: width + 10),
                 color: level.isBoss ? Palette.coral : theme.text,
                 at: CGPoint(x: centerX, y: top - 94), alignment: .center, z: 4)
        drawStarWordRow(for: level, centerX: centerX, y: top - 122)
    }

    /// The selected level's star words: one ball per word, filled for each found so far,
    /// laid out as one centered row ("STAR WORDS ●●○○ 2/4").
    func drawStarWordRow(for level: Level, centerX: CGFloat, y: CGFloat) {
        let theme = menuTheme
        let total = level.starWords.count
        let found = progress.hasStar(level) ? total : collectedThemeWords(in: level)
        let done = found == total
        let spacing: CGFloat = 20
        let radius: CGFloat = 7
        let gap: CGFloat = 12
        let label = makeLabel("STAR WORDS", font: "AvenirNext-Heavy", size: 10, color: theme.deepAccent, alignment: .left)
        let status = makeInlineRow(done ? [.symbol("star.fill"), .text("EARNED")] : [.text("\(found)/\(total)")],
                                   font: "AvenirNext-Heavy", size: 10, color: done ? Palette.gold : theme.deepAccent,
                                   symbolColor: Palette.gold, alignment: .left)
        let balls = makeStarBalls(total: total, filled: found, radius: radius, spacing: spacing,
                                  empty: theme.line.withAlphaComponent(0.25))
        let ballsWidth = CGFloat(total - 1) * spacing + radius * 2
        let statusWidth = status.calculateAccumulatedFrame().width
        let width = label.frame.width + gap + ballsWidth + gap + statusWidth
        var x = centerX - width / 2
        label.position = CGPoint(x: x, y: y)
        x += label.frame.width + gap
        balls.position = CGPoint(x: x + ballsWidth / 2, y: y)
        x += ballsWidth + gap
        status.position = CGPoint(x: x, y: y)
        for node in [label, balls, status] {
            node.zPosition = 4
            addChild(node)
        }
        addMarker("menu-stars", frame: CGRect(x: centerX - width / 2, y: y - 9, width: width, height: 18))
    }

    func drawBoardChoices(centerX: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let gap: CGFloat = 8
        let optionWidth = (width - gap * 2) / 3
        for (index, board) in LetterFlyGame.BoardSize.freePlayChoices.enumerated() {
            let x = centerX - width / 2 + optionWidth / 2 + CGFloat(index) * (optionWidth + gap)
            addChoiceButton(title: board.title, subtitle: "\(board.tileCount) letters", name: "action-board-\(board.rows)",
                            size: CGSize(width: optionWidth, height: height), selected: selectedBoardSize == board,
                            at: CGPoint(x: x, y: y))
        }
    }

    func drawTimeChoices(centerX: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        // Three timed lengths plus Endless (a length of 0).
        let options: [(TimeInterval, String, String)] = [(90, "90 sec", "quick"), (180, "180 sec", "relaxed"),
                                                         (270, "270 sec", "extended"), (0, "", "endless")]
        let gap: CGFloat = 6
        let optionWidth = (width - gap * 3) / 4
        for (index, (duration, title, subtitle)) in options.enumerated() {
            let x = centerX - width / 2 + optionWidth / 2 + CGFloat(index) * (optionWidth + gap)
            addChoiceButton(title: title, subtitle: subtitle,
                            name: "action-time-\(Int(duration))", size: CGSize(width: optionWidth, height: height),
                            selected: selectedRoundDuration == duration, at: CGPoint(x: x, y: y),
                            titleSymbol: duration == 0 ? "infinity" : nil)
        }
    }
}
