import SpriteKit
import UIKit

// The Myth world's home screen: a rainbow road winding up behind the bug with a stop for
// each trial, the finale that straightens it into a beam, and the portal the bug flies
// into when a level starts.
extension GameScene {
    static let rainbowColors: [SKColor] = [
        SKColor(red: 0.96, green: 0.30, blue: 0.30, alpha: 1),
        SKColor(red: 1.00, green: 0.58, blue: 0.22, alpha: 1),
        SKColor(red: 1.00, green: 0.85, blue: 0.28, alpha: 1),
        SKColor(red: 0.36, green: 0.82, blue: 0.42, alpha: 1),
        SKColor(red: 0.30, green: 0.66, blue: 1.00, alpha: 1),
        SKColor(red: 0.44, green: 0.42, blue: 0.92, alpha: 1),
        SKColor(red: 0.74, green: 0.42, blue: 0.94, alpha: 1),
    ]
    static let roadSamples = 160
    static let bandWidth: CGFloat = 9

    /// Where along the road (0 at the bottom, 1 at the top) each trial's stop sits.
    static func stopFraction(_ index: Int) -> CGFloat { 0.07 + CGFloat(index) * 0.172 }

    /// The road's center line through `rect`: a winding S, or a straight beam once the
    /// rainbow has been won.
    func roadPoints(in rect: CGRect, straight: Bool) -> [CGPoint] {
        let amplitude = min(rect.width * 0.32, 120)
        return (0...Self.roadSamples).map { index in
            let t = CGFloat(index) / CGFloat(Self.roadSamples)
            let x = straight ? rect.midX : rect.midX + amplitude * sin(t * .pi * 2.6 + .pi * 0.15)
            return CGPoint(x: x, y: rect.minY + rect.height * t)
        }
    }

    func roadPoint(_ points: [CGPoint], at fraction: CGFloat) -> CGPoint {
        points[min(points.count - 1, max(0, Int((fraction * CGFloat(Self.roadSamples)).rounded())))]
    }

    /// Seven paths side by side, red to violet, following `points`.
    static func bandPaths(along points: [CGPoint]) -> [CGPath] {
        let normals = points.indices.map { index -> CGVector in
            let a = points[max(0, index - 1)], b = points[min(points.count - 1, index + 1)]
            let length = max(0.001, hypot(b.x - a.x, b.y - a.y))
            return CGVector(dx: -(b.y - a.y) / length, dy: (b.x - a.x) / length)
        }
        return (0..<rainbowColors.count).map { band in
            let offset = (CGFloat(band) - 3) * bandWidth
            let path = CGMutablePath()
            for (index, point) in points.enumerated() {
                let shifted = CGPoint(x: point.x + normals[index].dx * offset, y: point.y + normals[index].dy * offset)
                index == 0 ? path.move(to: shifted) : path.addLine(to: shifted)
            }
            return path
        }
    }

    static func linePath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        return path
    }

    /// Draws the road: a faint full-length rainbow, the lit part up to the next trial
    /// glowing on top, and a spark that runs along the lit part.
    typealias RoadNodes = (glow: SKShapeNode, dim: [SKShapeNode], lit: [SKShapeNode], litCount: Int, spark: SKNode?)

    @discardableResult
    func drawRainbowRoad(_ points: [CGPoint], litTo fraction: CGFloat) -> RoadNodes {
        let glow = SKShapeNode(path: Self.linePath(points))
        glow.strokeColor = SKColor(white: 1, alpha: 0.10)
        glow.lineWidth = Self.bandWidth * 7 + 18
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.zPosition = 2
        glow.name = "road-glow"
        addChild(glow)
        var dimNodes: [SKShapeNode] = []
        for (band, path) in Self.bandPaths(along: points).enumerated() {
            let dim = SKShapeNode(path: path)
            dim.strokeColor = Self.rainbowColors[band].withAlphaComponent(0.22)
            dim.lineWidth = Self.bandWidth + 0.6
            dim.lineCap = .round
            dim.zPosition = 2.1
            dim.name = "road-dim"
            addChild(dim)
            dimNodes.append(dim)
        }
        let litCount = Int(fraction * CGFloat(Self.roadSamples)) + 1
        var bands: [SKShapeNode] = []
        guard litCount > 1 else { return (glow, dimNodes, bands, litCount, nil) }
        let lit = Array(points.prefix(litCount))
        for (band, path) in Self.bandPaths(along: lit).enumerated() {
            let node = SKShapeNode(path: path)
            node.strokeColor = Self.rainbowColors[band]
            node.lineWidth = Self.bandWidth + 0.6
            node.lineCap = .round
            node.zPosition = 2.2
            node.name = "road-lit"
            addChild(node)
            bands.append(node)
        }
        let spark = SKShapeNode(circleOfRadius: 5)
        spark.fillColor = .white
        spark.strokeColor = .clear
        spark.glowWidth = 6
        spark.zPosition = 2.3
        spark.name = "road-spark"
        addChild(spark)
        let run = SKAction.follow(Self.linePath(lit), asOffset: false, orientToPath: false,
                                  duration: max(1.2, Double(litCount) / 40))
        spark.run(.repeatForever(.sequence([.fadeIn(withDuration: 0.1), run, .fadeOut(withDuration: 0.2), .wait(forDuration: 0.8)])))
        return (glow, dimNodes, bands, litCount, spark)
    }

    // MARK: Switching into Myth

    /// A rainbow ribbon sweeps across the screen while the old layout fades out under it and
    /// the new one fades in. Going into Myth, the road then draws itself in.
    func switchThroughRainbow(to world: World) {
        isAnimatingFeedback = true
        haptics.select()
        sound.play(.shuffle)
        let entering = world == .myth
        let diagonal = hypot(size.width, size.height)
        let ribbon = SKNode()
        ribbon.zRotation = entering ? 0.5 : -0.5
        transitionLayer.addChild(ribbon)
        let bandHeight: CGFloat = 26
        for (index, color) in Self.rainbowColors.enumerated() {
            let band = SKSpriteNode(color: color, size: CGSize(width: diagonal * 1.4, height: bandHeight))
            band.position = CGPoint(x: 0, y: (CGFloat(index) - 3) * bandHeight)
            band.alpha = 0.92
            ribbon.addChild(band)
        }
        // A soft glow on each side of the ribbon.
        let glow = SKSpriteNode(color: .white, size: CGSize(width: diagonal * 1.4, height: bandHeight * 11))
        glow.alpha = 0.12
        glow.zPosition = -1
        ribbon.addChild(glow)
        // The ribbon travels across the screen, perpendicular to its length.
        let travel = diagonal * 0.75
        let direction = CGVector(dx: -sin(ribbon.zRotation), dy: cos(ribbon.zRotation))
        let flip: CGFloat = entering ? 1 : -1
        ribbon.position = CGPoint(x: -direction.dx * travel * flip, y: -direction.dy * travel * flip)
        let sweep = SKAction.move(to: CGPoint(x: direction.dx * travel * flip, y: direction.dy * travel * flip), duration: 0.9)
        sweep.timingMode = .easeInEaseOut
        ribbon.run(.sequence([sweep, .removeFromParent()]))

        // Fade the old layout out as the ribbon passes, then bring the new one in behind it.
        for child in children where child !== backdrop && child !== overlay && child !== transitionLayer {
            child.run(.fadeOut(withDuration: 0.25))
        }
        run(.sequence([.wait(forDuration: 0.32), .run { [weak self] in
            guard let self else { return }
            self.selectedWorld = world
            self.selectedLevel = self.isTutorialReplayPending && world == .storm
                ? Level(world: .storm, number: 1) : self.progress.nextLevel(in: world)
            if !self.progress.isFreePlayUnlocked(in: world) { self.isFreePlaySelected = false }
            self.mythIntroPending = entering
            self.mythBugStop = nil
            self.render()
            // Nodes that start hidden (the road's stops and the bug) animate themselves in.
            for child in self.children where child !== self.backdrop && child !== self.overlay
                && child !== self.transitionLayer && child.alpha > 0 {
                let target = child.alpha
                child.alpha = 0
                child.run(.fadeAlpha(to: target, duration: 0.35))
            }
        }, .wait(forDuration: 0.6), .run { [weak self] in self?.isAnimatingFeedback = false }]), withKey: "world-switch")
    }

    // MARK: Myth home screen

    func drawMythMenu(in safe: CGRect) {
        let theme = menuTheme
        let landscape = safe.width > safe.height
        // A star finished mid-round (then abandoned) can complete the set too.
        progress.awardRainbowIfEarned()
        let won = progress.hasRainbow
        let allBeaten = progress.levelsBeaten(in: .myth) >= Level.countPerWorld
        let straight = won && progress.hasSeenRainbowFinale

        // Card and PLAY at the bottom (or on the right in landscape); the road fills the rest.
        let cardWidth = landscape ? min(400, safe.width * 0.46) : min(safe.width - 32, 420)
        let cardHeight: CGFloat = 214
        let playSize = CGSize(width: min(cardWidth, 300), height: 56)
        let cardCenter: CGPoint
        let playCenter: CGPoint
        let roadRect: CGRect
        let titleY: CGFloat
        if landscape {
            let rightX = safe.minX + safe.width * 0.72
            cardCenter = CGPoint(x: rightX, y: safe.midY + 30)
            playCenter = CGPoint(x: rightX, y: cardCenter.y - cardHeight / 2 - 44)
            titleY = cardCenter.y + cardHeight / 2 + 34
            roadRect = CGRect(x: safe.minX + 20, y: safe.minY + 30, width: safe.width * 0.42, height: safe.height - 90)
        } else {
            playCenter = CGPoint(x: safe.midX, y: safe.minY + 42)
            cardCenter = CGPoint(x: safe.midX, y: playCenter.y + playSize.height / 2 + 14 + cardHeight / 2)
            titleY = safe.maxY - 76
            // Room above the top stop for the bug to perch without covering the title.
            let roadTop = titleY - 84
            let roadBottom = cardCenter.y + cardHeight / 2 + 34
            roadRect = CGRect(x: safe.minX + 24, y: roadBottom, width: safe.width - 48, height: max(80, roadTop - roadBottom))
        }

        addLabel("THE MYTH TRIALS", font: "AvenirNext-Heavy", size: 26, color: Palette.cream,
                 at: CGPoint(x: landscape ? cardCenter.x : safe.midX, y: titleY), alignment: .center, name: "myth-title")
        let subtitle = won ? "Every legend conquered"
            : (allBeaten ? "Find every star word to earn the rainbow" : "Six legends stand between you and the rainbow")
        addLabel(subtitle,
                 font: "AvenirNext-DemiBold", size: 12, color: World.myth.accentLight,
                 at: CGPoint(x: landscape ? cardCenter.x : safe.midX, y: titleY - 24), alignment: .center)

        let beaten = progress.levelsBeaten(in: .myth)
        let points = roadPoints(in: roadRect, straight: straight)
        let litTo = Self.stopFraction(min(beaten, Level.countPerWorld - 1))
        let drawIn = mythIntroPending
        mythIntroPending = false
        let road = drawRainbowRoad(points, litTo: beaten >= Level.countPerWorld ? 1 : litTo)
        drawTrialStops(points, beaten: beaten, center: roadRect.midX)
        if drawIn { drawRoadIn(points, road: road) }

        // The bug perches beside the selected stop, on the side away from its name (so she
        // never sits on the next stop up), flying along the road when the selection changes.
        let selected = selectedLevel.world == .myth ? selectedLevel.number - 1 : min(beaten, Level.countPerWorld - 1)
        let perchOnRight = { (index: Int) -> Bool in
            let point = self.roadPoint(points, at: Self.stopFraction(index))
            // Her side is opposite the stop's name.
            return Self.stopLabelOnLeft(point, center: roadRect.midX, index: index)
        }
        let perch = { (index: Int) -> CGPoint in
            let point = self.roadPoint(points, at: Self.stopFraction(index))
            let x = point.x + (perchOnRight(index) ? 60 : -60)
            return CGPoint(x: min(max(x, safe.minX + 36), safe.maxX - 36), y: point.y + 10)
        }
        let logo = makeLogo(size: 64)
        logo.name = "home-logo"
        logo.zPosition = 20
        // No tap target here: a tap near her should reach the stop she's beside.
        addChild(logo)
        if let from = mythBugStop, from != selected {
            logo.position = perch(from)
            let step = from < selected ? 1 : -1
            let path = CGMutablePath()
            path.move(to: perch(from))
            var index = Int(Self.stopFraction(from) * CGFloat(Self.roadSamples))
            let end = Int(Self.stopFraction(selected) * CGFloat(Self.roadSamples))
            // Ride just above the road, then settle beside the new stop.
            while index != end {
                index += step
                if index % 4 == 0 { path.addLine(to: CGPoint(x: points[index].x, y: points[index].y + 28)) }
            }
            path.addLine(to: perch(selected))
            setFacing(logo, left: perch(selected).x < perch(from).x, duration: 0)
            let fly = SKAction.follow(path, asOffset: false, orientToPath: false,
                                      duration: min(1.4, 0.35 + Double(abs(selected - from)) * 0.25))
            fly.timingMode = .easeInEaseOut
            let faceStop = perchOnRight(selected)
            logo.run(.sequence([fly, .run { [weak self] in self?.setFacing(logo, left: faceStop) }]), withKey: "roam")
        } else if drawIn {
            // She flies up the freshly drawn road to her trial.
            let start = CGPoint(x: points[0].x, y: points[0].y - 20)
            logo.position = start
            logo.alpha = 0
            let path = CGMutablePath()
            path.move(to: start)
            let end = Int(Self.stopFraction(selected) * CGFloat(Self.roadSamples))
            for index in stride(from: 0, through: end, by: 4) {
                path.addLine(to: CGPoint(x: points[index].x, y: points[index].y + 28))
            }
            path.addLine(to: perch(selected))
            let fly = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.5 + Double(selected) * 0.12)
            fly.timingMode = .easeInEaseOut
            let faceStop = perchOnRight(selected)
            logo.run(.sequence([.wait(forDuration: 0.5), .fadeIn(withDuration: 0.15), fly,
                                .run { [weak self] in self?.setFacing(logo, left: faceStop) }]), withKey: "roam")
        } else {
            logo.position = perch(selected)
            setFacing(logo, left: perchOnRight(selected), duration: 0)
        }
        mythBugStop = selected

        // The card: world picker, then the selected trial.
        let card = roundedRect(size: CGSize(width: cardWidth, height: cardHeight), radius: 22, fill: theme.card, stroke: theme.stroke)
        card.position = cardCenter
        card.zPosition = 2
        addChild(card)
        let top = cardCenter.y + cardHeight / 2
        let left = cardCenter.x - cardWidth / 2 + 18
        let inner = cardWidth - 30
        addLabel("WORLD", font: "AvenirNext-Bold", size: 11, color: theme.subtext,
                 at: CGPoint(x: left, y: top - 24), alignment: .left, z: 4)
        addLabel("MYTH", font: "AvenirNext-Heavy", size: 11, color: theme.deepAccent,
                 at: CGPoint(x: cardCenter.x + cardWidth / 2 - 18, y: top - 24), alignment: .right, z: 4)
        drawWorldChoices(centerX: cardCenter.x, y: top - 72, width: inner)
        let level = Level(world: .myth, number: selected + 1)
        if let kind = level.trial {
            let heading = "TRIAL \(selected + 1)  •  \(kind.title.uppercased())"
            addLabel(heading, font: "AvenirNext-Heavy", size: fittedFontSize(for: heading, max: 14, width: inner),
                     color: theme.deepAccent, at: CGPoint(x: cardCenter.x, y: top - 122), alignment: .center, z: 4)
            let rule = SKLabelNode(fontNamed: "AvenirNext-Medium")
            rule.text = kind.rule
            rule.fontSize = 12
            rule.fontColor = theme.text.withAlphaComponent(0.8)
            rule.numberOfLines = 3
            rule.preferredMaxLayoutWidth = inner
            rule.lineBreakMode = .byWordWrapping
            rule.horizontalAlignmentMode = .center
            rule.verticalAlignmentMode = .top
            rule.position = CGPoint(x: cardCenter.x, y: top - 134)
            rule.zPosition = 4
            addChild(rule)
        }
        drawStarWordRow(for: level, centerX: cardCenter.x, y: top - cardHeight + 20)
        let play = addButton(title: beaten > selected ? "REPLAY TRIAL" : "BEGIN TRIAL", name: "action-play", size: playSize,
                             color: theme.accent, at: playCenter, symbol: level.trial?.symbol)
        pulse(play, size: playSize, color: theme.accent)

        if won && !progress.hasSeenRainbowFinale {
            run(.sequence([.wait(forDuration: 0.7), .run { [weak self] in self?.playRainbowFinale(roadRect: roadRect) }]),
                withKey: "finale")
        }
    }

    /// The road paints itself in from the bottom up, and each stop pops in as it's reached.
    func drawRoadIn(_ points: [CGPoint], road: RoadNodes) {
        let duration = 0.9
        let fullLit = Array(points.prefix(road.litCount))
        road.spark?.isHidden = true
        road.lit.forEach { $0.isHidden = true }
        run(.customAction(withDuration: duration) { _, elapsed in
            let t = min(1, elapsed / CGFloat(duration))
            let eased = 1 - pow(1 - t, 2)
            let count = max(2, Int(eased * CGFloat(points.count)))
            let shown = Array(points.prefix(count))
            for (node, path) in zip(road.dim, Self.bandPaths(along: shown)) { node.path = path }
            road.glow.path = Self.linePath(shown)
            let lit = Array(fullLit.prefix(count))
            guard lit.count > 1 else { return }
            for (node, path) in zip(road.lit, Self.bandPaths(along: lit)) {
                node.path = path
                node.isHidden = false
            }
        }, withKey: "road-in")
        if let spark = road.spark {
            run(.sequence([.wait(forDuration: duration), .run { spark.isHidden = false }]))
        }
        // Stops (and their names and rings) pop in as the road reaches them.
        let stopParts = children.filter {
            $0.name?.hasPrefix("action-level-") == true || $0.name == "myth-stop-label" || $0.name == "myth-stop-ring"
        }
        for node in stopParts {
            let fraction = (node.position.y - points[0].y) / max(1, points[points.count - 1].y - points[0].y)
            let delay = Double(max(0, min(1, fraction))) * duration
            let finalAlpha = node.alpha
            node.alpha = 0
            node.setScale(0.3)
            node.run(.sequence([.wait(forDuration: delay),
                                .group([.fadeAlpha(to: finalAlpha, duration: 0.15),
                                        .sequence([.scale(to: 1.2, duration: 0.12), .scale(to: 1, duration: 0.1)])])]))
        }
    }

    /// A medallion for each trial along the road, in the trial's own color: filled once
    /// beaten, outlined when it's next, locked beyond that.
    func drawTrialStops(_ points: [CGPoint], beaten: Int, center: CGFloat) {
        let selected = selectedLevel.world == .myth ? selectedLevel.number - 1 : -1
        for kind in MythTrial.Kind.allCases {
            let index = kind.rawValue
            let point = roadPoint(points, at: Self.stopFraction(index))
            let done = index < beaten
            let open = index <= beaten
            let name = "action-level-\(index + 1)"
            let medallion = SKShapeNode(circleOfRadius: 24)
            medallion.fillColor = done ? kind.color : Palette.mix(World.myth.glass, Palette.ink, 0.2).withAlphaComponent(0.95)
            medallion.strokeColor = done ? Palette.mix(kind.color, .white, 0.45) : (open ? kind.color : SKColor(white: 1, alpha: 0.25))
            medallion.lineWidth = index == selected ? 3.5 : 2.5
            medallion.position = point
            medallion.zPosition = 6
            medallion.name = name
            addChild(medallion)
            let symbol = open ? kind.symbol : "lock.fill"
            if let icon = makeSymbol(symbol, pointSize: 17, color: done ? .white : (open ? kind.color : SKColor(white: 1, alpha: 0.4))) {
                icon.name = name
                icon.zPosition = 1
                medallion.addChild(icon)
            }
            if progress.hasStar(Level(world: .myth, number: index + 1)) {
                let star = makeStar(radius: 8)
                star.position = CGPoint(x: 19, y: 19)
                star.zPosition = 2
                star.name = name
                medallion.addChild(star)
            }
            if index == selected {
                let ring = SKShapeNode(circleOfRadius: 29)
                ring.strokeColor = kind.color
                ring.lineWidth = 2
                ring.fillColor = .clear
                ring.position = point
                ring.zPosition = 5.9
                ring.name = "myth-stop-ring"
                addChild(ring)
                ring.run(.repeatForever(.sequence([
                    .group([.scale(to: 1, duration: 0), .fadeAlpha(to: 0.8, duration: 0)]),
                    .group([.scale(to: 1.35, duration: 1.1), .fadeOut(withDuration: 1.1)])
                ])))
            }
            // The name sits toward the middle of the screen; the bug perches on the other side.
            let onLeft = Self.stopLabelOnLeft(point, center: center, index: index)
            let label = makeInlineRow((done ? [InlinePart.symbol("checkmark.circle.fill")] : []) + [.text(kind.shortTitle.uppercased())],
                                      font: "AvenirNext-Heavy", size: 11,
                                      color: open ? Palette.cream : SKColor(white: 1, alpha: 0.45),
                                      alignment: onLeft ? .right : .left)
            // Clear of the road's edge.
            label.position = CGPoint(x: point.x + (onLeft ? -44 : 44), y: point.y)
            label.zPosition = 6
            label.name = "myth-stop-label"
            label.userData = ["index": index]
            addChild(label)
        }
    }

    /// Whether a stop's name goes on its left: toward the middle of the screen, alternating
    /// when the stop sits right on the middle (as on the straightened beam).
    static func stopLabelOnLeft(_ point: CGPoint, center: CGFloat, index: Int) -> Bool {
        point.x > center + 4 || (abs(point.x - center) <= 4 && index % 2 == 0)
    }

    // MARK: Finale

    /// After the last trial: the winding road smooths into a straight beam down the middle,
    /// the bug rides it up and back, and comes out wearing the rainbow.
    func playRainbowFinale(roadRect: CGRect) {
        guard screen == .menu, selectedWorld == .myth, menuOverlay == nil else { return }
        progress.hasSeenRainbowFinale = true
        isAnimatingFeedback = true
        let winding = roadPoints(in: roadRect, straight: false)
        let straight = roadPoints(in: roadRect, straight: true)
        let roadParts: Set<String> = ["road-glow", "road-dim", "road-lit", "road-spark"]
        children.filter { roadParts.contains($0.name ?? "") }.forEach { $0.removeFromParent() }
        // Fade out the stops and their labels so the road has the stage.
        let stopParts: Set<String> = ["myth-stop-label", "myth-stop-ring"]
        for node in children where node.name?.hasPrefix("action-level-") == true || stopParts.contains(node.name ?? "") {
            node.run(.fadeOut(withDuration: 0.4))
        }
        let glow = SKShapeNode(path: Self.linePath(winding))
        glow.strokeColor = SKColor(white: 1, alpha: 0.12)
        glow.lineWidth = Self.bandWidth * 7 + 18
        glow.lineCap = .round
        glow.zPosition = 2
        addChild(glow)
        let bands = Self.bandPaths(along: winding).enumerated().map { band, path -> SKShapeNode in
            let node = SKShapeNode(path: path)
            node.strokeColor = Self.rainbowColors[band]
            node.lineWidth = Self.bandWidth + 0.6
            node.lineCap = .round
            node.zPosition = 2.2
            addChild(node)
            return node
        }
        let morph = SKAction.customAction(withDuration: 2.4) { _, elapsed in
            let t = min(1, elapsed / 2.4)
            let eased = t * t * (3 - 2 * t)
            let points = zip(winding, straight).map { a, b in
                CGPoint(x: a.x + (b.x - a.x) * eased, y: a.y + (b.y - a.y) * eased)
            }
            for (node, path) in zip(bands, Self.bandPaths(along: points)) { node.path = path }
            glow.path = Self.linePath(points)
        }
        sound.play(.shuffle)
        let beamTop = CGPoint(x: roadRect.midX, y: roadRect.maxY)
        let beamBottom = CGPoint(x: roadRect.midX, y: roadRect.minY)
        let middle = CGPoint(x: roadRect.midX, y: roadRect.midY)
        run(.sequence([
            .wait(forDuration: 0.4),
            morph,
            .run { [weak self] in
                // The beam flares.
                glow.run(.sequence([.group([.customAction(withDuration: 0.5) { node, elapsed in
                    (node as? SKShapeNode)?.glowWidth = 14 * elapsed / 0.5
                }, .fadeAlpha(to: 1, duration: 0.5)])]))
                glow.strokeColor = SKColor(white: 1, alpha: 0.35)
                self?.haptics.success()
                self?.sound.play(.levelPassed)
            },
            .wait(forDuration: 0.4),
            .run { [weak self] in self?.rideTheBeam(from: beamBottom, to: beamTop, landing: middle) }
        ]), withKey: "finale")
    }

    private func rideTheBeam(from bottom: CGPoint, to top: CGPoint, landing: CGPoint) {
        // The reveal is timed on the scene, so it still happens (and taps come back) even if
        // a redraw replaces the bug mid-ride.
        run(.sequence([.wait(forDuration: 2.2), .run { [weak self] in
            guard let self else { return }
            self.revealRainbowSkin(at: landing, replacing: self.childNode(withName: "home-logo"))
        }]), withKey: "finale-reveal")
        guard let logo = childNode(withName: "home-logo") else { return }
        logo.removeAllActions()
        let toBottom = SKAction.move(to: bottom, duration: 0.6)
        toBottom.timingMode = .easeInEaseOut
        let up = SKAction.move(to: top, duration: 0.9)
        up.timingMode = .easeIn
        let down = SKAction.move(to: landing, duration: 0.7)
        down.timingMode = .easeOut
        // Sparkles trail her up the beam.
        let trail = SKAction.repeat(.sequence([.run { [weak self, weak logo] in
            guard let self, let logo else { return }
            let spark = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            spark.fillColor = Self.rainbowColors.randomElement()!
            spark.strokeColor = .clear
            spark.position = CGPoint(x: logo.position.x + CGFloat.random(in: -14...14), y: logo.position.y - 10)
            spark.zPosition = 19
            self.addChild(spark)
            spark.run(.sequence([.group([.moveBy(x: 0, y: -40, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        }, .wait(forDuration: 0.04)]), count: 40)
        logo.run(.sequence([toBottom, .group([up, trail, .rotate(byAngle: .pi * 2, duration: 0.9)]), down]))
    }

    private func revealRainbowSkin(at point: CGPoint, replacing logo: SKNode?) {
        // Rings of every color burst out, and she comes out wearing the rainbow.
        for (index, color) in Self.rainbowColors.enumerated() {
            let ring = SKShapeNode(circleOfRadius: 30)
            ring.strokeColor = color
            ring.lineWidth = 5
            ring.fillColor = .clear
            ring.position = point
            ring.zPosition = 18
            ring.setScale(0.2)
            addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(index) * 0.06),
                .group([.scale(to: 6, duration: 1.1), .fadeOut(withDuration: 1.1)]),
                .removeFromParent()
            ]))
        }
        emitCelebration(from: point, count: 70)
        flashAndShake(strength: 1.2)
        Outfit.selected = .rainbow
        let rainbowBug = makeLogo(size: 70, outfit: .rainbow)
        rainbowBug.position = point
        rainbowBug.zPosition = 20
        rainbowBug.setScale(0.2)
        addChild(rainbowBug)
        logo?.removeFromParent()
        rainbowBug.run(.sequence([.scale(to: 1.5, duration: 0.3), .scale(to: 1.2, duration: 0.2)]))

        let banner = addLabel("RAINBOW SKIN UNLOCKED!", font: "AvenirNext-Heavy", size: 22, color: Palette.cream,
                              at: CGPoint(x: point.x, y: point.y - 80), alignment: .center, z: 30)
        let note = addLabel("It's yours to keep, even after a reset", font: "AvenirNext-DemiBold", size: 12,
                            color: World.myth.accentLight, at: CGPoint(x: point.x, y: point.y - 104), alignment: .center, z: 30)
        for label in [banner, note] {
            label.alpha = 0
            label.run(.sequence([.wait(forDuration: 0.4), .fadeIn(withDuration: 0.4)]))
        }
        run(.sequence([.wait(forDuration: 4), .run { [weak self] in
            self?.isAnimatingFeedback = false
            self?.render()
        }]))
    }

    // MARK: Portal

    /// Starting a level from home: the bug dives into the selected world's tile, which
    /// opens as a portal themed to that world. A window onto the world grows inside it
    /// until it fills the screen, and the round begins there.
    func launchThroughPortal(then begin: @escaping () -> Void) {
        let world = selectedWorld
        guard let logo = childNode(withName: "home-logo"),
              let tile = children.first(where: { $0.name == "action-world-\(world.rawValue)" }) else {
            begin()
            return
        }
        isAnimatingFeedback = true
        logo.removeAllActions()
        let center = tile.position

        let portal = SKNode()
        portal.position = center
        portal.zPosition = 30
        addChild(portal)

        // The tile itself becomes the portal: a window onto the world, in the tile's shape.
        let tileSize = (tile as? SKShapeNode)?.frame.size ?? CGSize(width: 50, height: 58)
        let shape = CGPath(roundedRect: CGRect(x: -tileSize.width / 2, y: -tileSize.height / 2,
                                               width: tileSize.width, height: tileSize.height),
                           cornerWidth: 12, cornerHeight: 12, transform: nil)
        let window = SKCropNode()
        let hole = SKShapeNode(path: shape)
        hole.fillColor = .white
        hole.strokeColor = .clear
        window.maskNode = hole
        let scenery = world.makeBackground(size: size)
        scenery.position = CGPoint(x: -center.x, y: -center.y)
        scenery.zPosition = 0
        window.addChild(scenery)
        window.zPosition = 1
        window.alpha = 0
        portal.addChild(window)
        window.run(.fadeIn(withDuration: 0.2))
        // A glowing rim hugs the opening.
        let rim = SKShapeNode(path: shape)
        rim.strokeColor = world.accentLight
        rim.lineWidth = 3
        rim.glowWidth = 6
        rim.fillColor = .clear
        rim.zPosition = 2
        portal.addChild(rim)
        rim.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)])))

        // Outlines in the world's colors ripple out from the tile.
        let ringColors = world == .myth ? Self.rainbowColors : [world.accentLight, world.accent, Palette.gold, .white]
        portal.run(.repeat(.sequence([.run { [weak portal] in
            guard let portal else { return }
            let ripple = SKShapeNode(path: shape)
            ripple.strokeColor = (ringColors.randomElement() ?? .white).withAlphaComponent(0.9)
            ripple.lineWidth = 2.5
            ripple.fillColor = .clear
            ripple.zPosition = 3
            ripple.name = "portal-ripple"
            portal.addChild(ripple)
            ripple.run(.sequence([.group([.scale(to: 1.9, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        }, .wait(forDuration: 0.12)]), count: 10))

        // Bits of the world swirl into the portal.
        portal.run(.repeat(.sequence([.run { [weak self, weak portal] in
            guard let self, let portal else { return }
            let bit = self.portalBit(for: world)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let start = CGPoint(x: cos(angle) * 80, y: sin(angle) * 80)
            bit.position = start
            bit.zRotation = angle + .pi / 2
            bit.zPosition = 4
            portal.addChild(bit)
            // Spiral in: a curve that bends around the center.
            let spiral = CGMutablePath()
            spiral.move(to: start)
            spiral.addQuadCurve(to: .zero, control: CGPoint(x: cos(angle + 1.2) * 60, y: sin(angle + 1.2) * 60))
            bit.run(.sequence([
                .group([.follow(spiral, asOffset: false, orientToPath: world == .storm || world == .road, duration: 0.5),
                        .scale(to: 0.3, duration: 0.5), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.2)])]),
                .removeFromParent()
            ]))
        }, .wait(forDuration: 0.025)]), count: 44))

        // The bug swoops over and spirals in.
        let from = logo.position
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: center, control: CGPoint(x: (from.x + center.x) / 2 + (center.x < from.x ? -70 : 70),
                                                       y: max(from.y, center.y) + 90))
        setFacing(logo, left: center.x < from.x)
        logo.zPosition = 40
        let swoop = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.6)
        swoop.timingMode = .easeIn
        let spiralIn = SKAction.group([.rotate(byAngle: .pi * 3, duration: 0.45), .scale(to: 0, duration: 0.45),
                                       .fadeOut(withDuration: 0.45)])
        spiralIn.timingMode = .easeIn
        sound.play(.shuffle)
        haptics.tap(.medium)
        logo.run(.sequence([
            .wait(forDuration: 0.15),
            .group([swoop, .scale(to: 0.6, duration: 0.6)]),
            spiralIn
        ]))
        // The timing runs on the scene itself, so the round still starts (and taps come back)
        // even if a redraw removes the portal or the bug partway through.
        run(.sequence([
            .wait(forDuration: 1.2),
            .run { [weak self, weak portal, weak hole, weak rim] in
                guard let self else { return }
                self.sound.play(.themeWord)
                self.haptics.success()
                // The opening grows until the world fills the screen.
                let reach = 2 * max(self.size.width / tileSize.width, self.size.height / tileSize.height) + 1
                let flood = SKAction.scale(to: reach, duration: 0.45)
                flood.timingMode = .easeIn
                hole?.run(flood)
                rim?.run(.group([flood, .fadeOut(withDuration: 0.45)]))
                portal?.children.filter { $0.name == "portal-ripple" }.forEach { $0.removeFromParent() }
            },
            .wait(forDuration: 0.45),
            .run { [weak self] in
                self?.isAnimatingFeedback = false
                begin()
            }
        ]), withKey: "portal")
    }

    /// One piece of a world, pulled into its portal.
    private func portalBit(for world: World) -> SKNode {
        switch world {
        case .storm:
            let drop = SKShapeNode(rectOf: CGSize(width: 2, height: 12), cornerRadius: 1)
            drop.fillColor = SKColor(red: 0.75, green: 0.85, blue: 1, alpha: 0.9)
            drop.strokeColor = .clear
            return drop
        case .circus:
            let confetti = SKShapeNode(rectOf: CGSize(width: 6, height: 6), cornerRadius: 1)
            confetti.fillColor = [Palette.coral, Palette.gold, Palette.teal, .white].randomElement()!
            confetti.strokeColor = .clear
            return confetti
        case .road:
            let dash = SKShapeNode(rectOf: CGSize(width: 3, height: 12), cornerRadius: 1.5)
            dash.fillColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
            dash.strokeColor = .clear
            return dash
        case .water:
            let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 3...6))
            bubble.fillColor = SKColor(white: 1, alpha: 0.15)
            bubble.strokeColor = SKColor(red: 0.7, green: 0.95, blue: 1, alpha: 0.9)
            bubble.lineWidth = 1.2
            return bubble
        case .volcano:
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...3.5))
            ember.fillColor = [SKColor(red: 1, green: 0.55, blue: 0.15, alpha: 1), SKColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)].randomElement()!
            ember.strokeColor = .clear
            ember.glowWidth = 2
            return ember
        case .space:
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...2.2))
            star.fillColor = .white
            star.strokeColor = .clear
            star.glowWidth = 2
            return star
        case .myth:
            let spark = SKShapeNode(circleOfRadius: 2.5)
            spark.fillColor = Self.rainbowColors.randomElement()!
            spark.strokeColor = .clear
            spark.glowWidth = 2
            return spark
        }
    }
}
