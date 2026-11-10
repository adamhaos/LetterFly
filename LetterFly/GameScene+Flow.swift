import SpriteKit
import UIKit

// Menu choices and round flow: starting, finishing and leaving rounds.
extension GameScene {
    // MARK: - Menu choices

    func selectFreePlay() {
        guard progress.isFreePlayUnlocked(in: selectedWorld) else {
            flashMenuNote("Beat all \(Level.regularCount) \(selectedWorld.title) levels to unlock Free Play")
            return
        }
        isFreePlaySelected = true
        isTutorialReplayPending = false
        haptics.select()
        render()
    }

    func startFreePlay() {
        guard progress.isFreePlayUnlocked(in: selectedWorld) else {
            flashMenuNote("Beat all \(Level.regularCount) \(selectedWorld.title) levels to unlock Free Play")
            return
        }
        mode = .freePlay
        startRound()
    }

    func chooseWorld(_ world: World) {
        guard progress.isUnlocked(world) else {
            let previous = world.previous?.title ?? ""
            flashMenuNote("Beat \(Level.countToUnlockNext) \(previous) levels to unlock \(world.title)")
            return
        }
        isTutorialReplayPending = false
        // Going into or out of Myth swaps the whole layout, so a rainbow sweeps across to carry it.
        if (world == .myth) != (selectedWorld == .myth) {
            switchThroughRainbow(to: world)
            return
        }
        selectedWorld = world
        selectedLevel = progress.nextLevel(in: world)
        if !progress.isFreePlayUnlocked(in: world) { isFreePlaySelected = false }
        haptics.select()
        render()
        cheerOnWorldPick()
    }

    func chooseLevel(_ number: Int) {
        let level = Level(world: selectedWorld, number: number)
        guard progress.isPlayable(level) else {
            flashMenuNote("Beat level \(number - 1) first")
            return
        }
        selectedLevel = level
        isFreePlaySelected = false
        isTutorialReplayPending = false
        haptics.select()
        render()
    }

    /// Replaying the tutorial heads straight to Storm level 1, whose button then reads
    /// PLAY TUTORIAL until the player picks something else.
    func goToTutorialLevel() {
        isTutorialReplayPending = true
        isFreePlaySelected = false
        if selectedWorld == .myth {
            switchThroughRainbow(to: .storm)
        } else {
            selectedWorld = .storm
            selectedLevel = Level(world: .storm, number: 1)
            render()
        }
        flashMenuNote("The tutorial is ready on Storm level 1")
    }

    func chooseBoard(_ boardSize: LetterFlyGame.BoardSize) {
        selectedBoardSize = boardSize
        haptics.select()
        render()
    }

    func chooseDuration(_ duration: TimeInterval) {
        selectedRoundDuration = duration
        haptics.select()
        render()
    }


    func toggleSound() {
        sound.isEnabled.toggle()
        haptics.select()
        render()
    }

    /// Shows a short note on the menu, e.g. when a locked world is tapped.
    func flashMenuNote(_ text: String) {
        haptics.warning()
        nodeNamed("menu-note")?.removeFromParent()
        let note = addLabel(text, font: "AvenirNext-DemiBold", size: 12, color: Palette.coral,
                            at: CGPoint(x: safeFrame.midX, y: safeFrame.minY + 14), alignment: .center,
                            name: "menu-note", z: 150)
        note.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: - Round flow

    func startRound() {
        let board: LetterFlyGame.BoardSize
        let world: World
        switch mode {
        case .playthrough:
            activeLevel = selectedLevel
            board = selectedLevel.boardSize
            world = selectedLevel.world
            roundDuration = selectedLevel.duration
        case .freePlay:
            activeLevel = nil
            board = selectedBoardSize
            world = selectedWorld
            roundDuration = selectedRoundDuration
        case .daily:
            let puzzle = dailyPuzzle ?? .today()
            dailyPuzzle = puzzle
            activeLevel = nil
            board = puzzle.boardSize
            world = puzzle.world
            roundDuration = puzzle.duration
            // Starting uses up the day's one try.
            daily.recordStart(of: puzzle)
        }
        let puzzle = mode == .daily ? dailyPuzzle : nil
        // A round length of 0 means Endless.
        // Levels (Myth trials too) put their unfound star words on top; the daily puzzle
        // deals the same words and letters on every device.
        let levelWords = activeLevel.map { $0.wordOrder(found: progress.foundWords(in: $0)) } ?? puzzle?.themeWords
        game.startNewRound(boardSize: board, world: world, endless: mode == .freePlay && roundDuration == 0,
                           wordSeed: activeLevel?.wordSeed, words: levelWords, dealSeed: puzzle?.dealSeed)
        trial = activeLevel?.trial.map { MythTrial(kind: $0) }
        isShowingTrialIntro = trial != nil
        pendingOutcome = nil
        earnedRainbow = false
        mythWasLocked = !progress.isUnlocked(.myth)
        if trial?.kind == .fates { game.assignThreads() }
        prepareTrialTurn()
        roundElapsed = 0
        nextEventAt = game.isEndless ? 4 : 7
        exposedSince = [:]
        screen = .playing
        timeRemaining = roundDuration
        lastUpdateTime = 0
        lastTickSecond = 0
        displayedScore = 0
        isClockUrgent = false
        backgroundLayer?.speed = 1
        if let trial {
            statusMessage = trial.kind.title
        } else if let level = activeLevel, level.isBoss {
            statusMessage = "BOSS: \(level.world.bossTwist)"
            statusExpiresAt = 0
        } else if game.isEndless {
            statusMessage = "Don't let the pile topple!"
        } else if mode == .daily {
            statusMessage = "Daily puzzle: one try, make it count!"
        } else {
            statusMessage = activeLevel.map { "Score \($0.targetScore) to pass" } ?? "Make words with the uncovered letters"
        }
        statusColor = Palette.muted
        statusExpiresAt = 0
        isAnimatingFeedback = false
        isConfirmingExit = false
        isShowingStarSplash = false
        hasAnnouncedGoal = false
        layoutSeed = Int.random(in: 0..<1_000_000)
        hiddenInWord = []
        hiddenInPile = []
        earnedNewHighScore = false
        passedLevel = false
        unlockedWorld = nil
        earnedStar = false
        isNewStar = false
        masteredWorld = false
        unlockedFreePlay = false
        isTutorialReplayPending = false
        prepareTutorial()
        render()
    }

    /// How many of `level`'s star words have been found over all plays.
    func collectedThemeWords(in level: Level) -> Int {
        let found = progress.foundWords(in: level)
        return level.starWords.filter { found.contains($0.lowercased()) }.count
    }

    /// The words the theme dots track: a level's star words, or every theme word in Free Play.
    var starWords: [String] { activeLevel.map(\.starWords) ?? game.roundWords }

    /// Star words spelled this round.
    var starWordsFoundThisRound: Int { starWords.filter { game.usedWords.contains($0.lowercased()) }.count }

    /// The level after `activeLevel`: the next in its world, or the next world's first unbeaten level.
    var levelAfterActive: Level? {
        guard let level = activeLevel else { return nil }
        if level.number < Level.countPerWorld { return Level(world: level.world, number: level.number + 1) }
        guard let next = level.world.next, progress.isUnlocked(next) else { return nil }
        return progress.nextLevel(in: next)
    }

    /// Plays the finished round's setup again. Passing a level already advanced the
    /// menu selection, so point it back at the level just played.
    func replayRound() {
        // The daily puzzle gets one try.
        guard mode != .daily else { showMenu(); return }
        if let level = activeLevel {
            selectedWorld = level.world
            selectedLevel = level
        }
        startRound()
    }

    func startNextLevel() {
        guard let next = levelAfterActive else { return }
        selectedWorld = next.world
        selectedLevel = next
        startRound()
    }

    func showMenu() {
        // Leaving the daily puzzle early still counts: the score so far is saved and sent.
        if screen == .playing, mode == .daily, let puzzle = dailyPuzzle {
            saveDailyScore(for: puzzle)
            gameCenter.sync()
        }
        screen = .menu
        // Leaving mid-tutorial drops any tip; the tutorial replays unless its tour was finished.
        endCoaching()
        lastUpdateTime = 0
        isConfirmingExit = false
        if !progress.isPlayable(selectedLevel) { selectedLevel = progress.nextLevel(in: selectedWorld) }
        render()
    }

    /// Ends a level once its goal is met, without waiting for the clock.
    func finishEarly() {
        guard screen == .playing, trial == nil, let level = activeLevel, game.score >= level.targetScore else { return }
        finishRound(message: "Finished early")
    }

    func presentExitConfirmation() {
        guard screen == .playing else { return }
        isConfirmingExit = true
        lastUpdateTime = 0
        haptics.tap(.light)
        render()
    }

    func dismissExitConfirmation() {
        isConfirmingExit = false
        lastUpdateTime = 0
        render()
    }

    func finishRound(message: String) {
        screen = .finished
        endCoaching()
        isShowingStarSplash = false
        removeAction(forKey: "star-splash")
        statusMessage = message
        lastUpdateTime = 0
        // Calm the backdrop back down if the clock was running low.
        isClockUrgent = false
        backgroundLayer?.removeAllActions()
        backgroundLayer?.speed = 1
        stats.recordRound(score: game.score, world: game.world)
        if let level = activeLevel, let trial {
            passedLevel = trial.isComplete
            // Trials have star words too, collected across plays like any level.
            earnedStar = starWordsFoundThisRound == level.starWords.count
            if collectedThemeWords(in: level) == level.starWords.count {
                isNewStar = progress.recordStar(for: level) || isNewStar
            }
            masteredWorld = isNewStar && progress.isMastered(.myth)
            if passedLevel {
                progress.recordPass(of: level)
                selectedLevel = levelAfterActive ?? level
                selectedWorld = .myth
            }
            earnedRainbow = progress.awardRainbowIfEarned()
            sound.play(passedLevel ? .levelPassed : .levelFailed)
            passedLevel ? haptics.success() : haptics.warning()
        } else if let level = activeLevel {
            passedLevel = game.score >= level.targetScore
            // Theme words carry over between plays: the star comes once all have been found.
            earnedStar = starWordsFoundThisRound == level.starWords.count
            if collectedThemeWords(in: level) == level.starWords.count {
                isNewStar = progress.recordStar(for: level) || isNewStar
            }
            masteredWorld = isNewStar && progress.isMastered(level.world)
            if passedLevel {
                let freePlayWasLocked = !progress.isFreePlayUnlocked(in: level.world)
                unlockedWorld = progress.recordPass(of: level)
                if mythWasLocked && progress.isUnlocked(.myth) { unlockedWorld = .myth }
                unlockedFreePlay = freePlayWasLocked && progress.isFreePlayUnlocked(in: level.world)
                selectedLevel = levelAfterActive ?? level
                selectedWorld = selectedLevel.world
            }
            sound.play(passedLevel ? .levelPassed : .levelFailed)
            passedLevel ? haptics.success() : haptics.warning()
        } else if mode == .daily, let puzzle = dailyPuzzle {
            earnedNewHighScore = saveDailyScore(for: puzzle)
            sound.play(.levelPassed)
            haptics.success()
        } else {
            // Endless scores are kept under a round length of 0.
            earnedNewHighScore = highScores.record(game.score, board: game.boardSize, duration: game.isEndless ? 0 : roundDuration)
            sound.play(.levelPassed)
            haptics.success()
        }
        // Send new stars, streaks, Endless bests and achievements to Game Center.
        gameCenter.sync()
        render()
    }
}
