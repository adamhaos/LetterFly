# LetterFly — Project Summary

Use this file to pick the project up in a new session. It covers what the game is, how the code is laid out, how the rules work, where the release stands, and what's left to do.

_Last updated: November 9, 2026 (build 8, submitted for App Store review)._

---

## 1. What it is

**LetterFly** is an iOS word game for iPhone and iPad (App Store display name **"LetterFlyy"**, because "LetterFly" was taken). The letters of hidden themed words are dealt into stacks. You tap uncovered letters to spell any valid English word, which removes those letters and uncovers the ones beneath. A cartoon ladybug mascot (the app icon) guides, hints and celebrates.

- **Tagline / subtitle:** "Words Take Flight"
- **Category:** Games / Word. Free, United States only, rated 4+, no sign-in, no data collected.
- **Tech:** Swift 5, UIKit app shell with a single **SpriteKit** `GameScene`. Every visual is drawn from SpriteKit shapes, and every sound is synthesized at launch, so the app ships no image or audio assets apart from the app icon.
- **Persistence:** `UserDefaults` only (privacy manifest declares reason CA92.1).
- **Min iOS:** 17.0 in the archive. Targets iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`).
- **Bundle ID:** `atm.LetterFly`. **ASC app ID:** 6816781742. **Team:** ZCW4C29TGM.
- **Version:** 1.0 (build 8).
- **Repo:** `github.com/adamhaos/LetterFly`. Working branch is `letterfly-gameplay`; `main` is the default branch.
- **Support / privacy site:** https://sites.google.com/view/letterfly-app
- **CI:** an Xcode Cloud workflow manifest lives at `LetterFly.xcodeproj/xcshareddata/xcodecloud/manifest.json`.

---

## 2. Core rules

### Board
- Board sizes (`LetterFlyGame.BoardSize`):

  | Size | Grid | Layers | Words per layer | Word length | Clock |
  |---|---|---|---|---|---|
  | classic | 4×2 | 4 | 1 | 8 | 90 s |
  | big | 4×3 | 5 | 2 | 6 | 180 s |
  | huge | 4×4 | 6 | 2 | 8 | 270 s |
  | grand (Myth only) | 5×4 | 4 | 4 | 5 | per trial |

- Each layer is built by shuffling the letters of that layer's theme word(s) across every stack, so every layer fills each stack exactly once. The top layer is fully uncovered at the start.
- Stacks are scattered loosely on screen (best-candidate sampling), not laid out in a grid. Covered letters show faintly above each exposed letter.

### Scoring (`commitSelection`)
- Letter values follow Scrabble (Q and Z are worth 10, J and X 8, and so on).
- **Red bonus letters** (about 1 in 7 tiles; none in Myth) are worth 2×.
- **Gold letters** (Midas trial) are worth 3×.
- **Wild "?"** (one per big or huge board; none in Myth) is free to use and scores 0. The game resolves it to a letter that makes a valid, unused word, preferring theme words.
- Word total = letter sum × max(1, length − 2). Spelling a **theme word** doubles it.
- **Valid words:** the round's theme words, a built-in list of common 3-letter words, Myth names (in Myth), or any word `UITextChecker` accepts (`en_US`). Anything longer than 15 letters is rejected.
- **Anti-stall:** `prepareNextMove()` swaps covered letters into exposed slots when no known word can be spelled. The overall letter bag stays the same.

### Controls
Submit, undo the last letter, clear, **Mix** (shuffles exposed letters; the wild stays put), and **Hint** (the bug shows the first and last letters of a findable word, e.g. `Try R • • • • N`). Pause offers resume, restart, sound and exit.

---

## 3. Progression

### Worlds (`World.swift`)
Six main worlds in order: **Storm → Circus → Road → Water → Volcano → Space**, plus a secret seventh, **Myth**. Each world has its own word lists (8-letter and 6-letter; Myth uses 5-letter), colors, an animated backdrop, a menu symbol, and a letter-tap sound.

### Levels (`Playthrough.swift`)
- **6 levels per world:** 5 regular levels and a **boss level** (level 6).
- Board size by level: levels 1–2 classic, 3–4 big, 5–6 huge.
- **Target scores:** base `[70, 85, 165, 190, 320, 350]`, raised 4% per world after Storm and rounded to the nearest 5. The targets were tuned against a simulated casual player. Once you reach the target, the goal bar becomes a pill that lets you finish the level early.
- **Unlocks:** beating 3 levels in a world opens the next world. Beating all 5 regular levels opens **Free Play** for that world. Beating every level of all six main worlds opens **Myth**.
- **Theme words are fixed per level** (seeded with `SeededGenerator`, a SplitMix64 generator). The letters are dealt fresh on every play.

### Star words
- Each level has **4 star words** (the first 4 of its theme words). Found star words are saved across plays. Finding all 4 earns the level's **star**.
- Missing star words are stacked on the top layer, so every replay offers a new one.
- Finding a star word plays a splash (dim screen, spinning gold star, "2 OF 4 FOUND"). The clock pauses while the splash is up.
- Starring every level in a world **masters** it and unlocks that world's ladybug **outfit**: rain hat, party hat, racing cap, snorkel, fire helmet, space helmet.

### Boss twists (`GameScene+Twists.swift`)
| World | Twist |
|---|---|
| Storm | Wind gusts scatter the stacks to new spots |
| Circus | Two stacks swap places |
| Road | All stacks shift one place along, like traffic |
| Water | The current sways the letters |
| Volcano | A letter left uncovered too long glows, then burns away unscored |
| Space | Letters drift and turn in low gravity |

### Myth world (`MythTrial.swift`, `GameScene+Myth.swift`, `+Road.swift`, `+Clash.swift`)
- It uses the **grand** 5×4 board and 58 five-letter myth words. Its home screen is a winding **rainbow road** with six trial stops.
- Each level is a **trial** won by its own goal, not by score. Piles refill as they're used, so the clock is the only way to lose (except the Hydra).

| Trial | Goal | Clock | Rule |
|---|---|---|---|
| Icarus's Flight | 3 climbs | 300 s | Spell words of exactly 3, 4, 5, then 6 letters. A wrong length resets the climb to 3. |
| The Ouroboros | 6 links | 300 s | Each word starts with the last letter of the previous word. Breaking the chain resets it. |
| Riddle of the Sphinx | 5 riddles | 240 s | Spell the answer to a riddle (every myth word has one). A wrong myth word costs 10 s. |
| The Midas Touch | 40 gold | 160 s | Letters your words uncover turn gold (3×). Use 40 gold letters. |
| Threads of Fate | 9 words | 150 s | Letters come in 3 thread colors. Give each sister in turn 3 words with 2+ letters of her color. |
| The Hydra | 8 heads | 180 s | 5+ letter words burn off a head; shorter words grow two letters back. The last head needs a myth word. You lose at 10 heads. |

- Starting a trial plays a character "clash" animation and a legend card.
- Beating all 6 trials **and** starring all of Myth earns the **rainbow skin**. A finale then plays: the road straightens into a beam and the bug rides it. The rainbow is saved under its own key, so resetting progress doesn't remove it.

### Other modes and screens
- **Free Play:** pick a board size and a 90, 180 or 270 s clock. High scores are kept per board and clock (`HighScoreStore`).
- **Endless:** the pile starts half full and new letters drop in faster and faster. It topples at stackCount × (layers + 1) letters.
- **Stats** (`StatsStore`): lifetime stats, best score per world, most-used letter.
- **Settings:** sound, haptics, outfit picker, replay tutorial, reset progress (with a confirmation step).
- **Rules card**, plus world unlock bursts on the menu.

### Daily puzzle (`DailyPuzzle.swift`, `GameScene+Daily.swift`)
- One puzzle a day, dealt the same on every device: a 4×3 pile on a 180 s clock, with the worlds taking turns. The words, deal, red letters and wild come from seeds based on the day (`LetterFlyGame.startNewRound(dealSeed:)`); Mix and the anti-stall remix stay random.
- A new puzzle opens at **08:00 UTC** (`DailyPuzzle.resetHourUTC`), which is overnight across the US. The Game Center daily leaderboard must restart at the same hour.
- **One try a day:** starting the puzzle uses the try, restart is greyed out, and leaving early saves the score so far. A progress reset doesn't clear daily data.
- The calendar button on the home screen (with a dot while today's puzzle is unplayed) opens the daily card: the day's world and date, streak, best streak, best score, today's result, a countdown to the next puzzle, and a leaderboard button.

### Game Center (`GameCenter.swift`, `GameCenterGoals.swift`)
- Optional sign-in at launch (`GameViewController.viewDidAppear`). When signed out, nothing changes.
- Leaderboards: `letterfly.daily` (recurring, daily), `letterfly.endless`, `letterfly.stars`, `letterfly.daily_streak`.
- 14 achievements (IDs in `Achievement`), worked out from saved progress after every round and on sign-in, so progress earned while signed out is sent later.
- The trophy button on the home screen opens the Game Center dashboard. Setup steps and every ID are in `Release/Game-Center-Setup.md`.

### Onboarding
- **Tutorial** (`GameScene+Tutorial.swift`): runs across Storm level 1. The ladybug coaches with a spotlight and pointer through these steps: welcome, goal, layers, star dots, spelling a star word, next layer, goal bar, scoring, red letters, hint, mix, fixing mistakes, time bonus. While the player spells the tutorial word, only the controls needed for it respond.
- **Home tour** (`GameScene+HomeTour.swift`): the bug flies between stops on the home screen: welcome, worlds, levels, star words, stats, rules, settings, play.

### Feel
- **Portal transition:** the bug dives into the world tile, which opens as a portal into that world.
- **Rainbow wipe** when switching into Myth.
- **Celebrations:** confetti, screen shake, and a lap of honor for 8-letter words. The final 10 seconds pulse.
- **Haptics** (`Haptics.swift`): named patterns, plus a heartbeat in the final seconds.
- **Sound** (`SoundPlayer.swift`): synthesized tones using the ambient session, so it respects the silent switch and mixes with the player's music.
- Supports dark mode on the menu and landscape layouts.

---

## 4. Code map (~8,150 lines of Swift in `LetterFly/`)

| File | Responsibility |
|---|---|
| `LetterFlyGame.swift` | Pure game model: board, tiles, selection, scoring, Endless drops, the anti-stall remix, Myth helpers (gild, threads, surface, plant), `SeededGenerator` |
| `World.swift` | World enum, order, word lists |
| `Playthrough.swift` | `Level` (board, clock, target, seed, star words) and `ProgressStore` (unlocks, stars, found words, rainbow) |
| `MythTrial.swift` | The six trial rule engines, plus riddles |
| `Stats.swift` | `StatsStore` and the `Outfit` enum |
| `HighScoreStore.swift` | Free Play high scores |
| `DailyPuzzle.swift` | `DailyPuzzle` (the day's world, words and deal seed) and `DailyStore` (one try a day, streaks, bests) |
| `GameCenterGoals.swift` | Leaderboard and achievement IDs, and achievement progress from saved data |
| `GameCenter.swift` | GameKit sign-in, score and achievement reporting, opening Game Center |
| `GameScene+Daily.swift` | Daily card, daily round start and save, Game Center buttons |
| `SoundPlayer.swift`, `Haptics.swift` | Audio synthesis, vibration patterns |
| `WorldBackground.swift` | Per-world colors and animated shape backdrops |
| `GameScene.swift` | Scene state, palette, menu theme, update loop |
| `GameScene+Menu.swift` | Home screen, world and level pickers, progress rings, roaming mascot |
| `GameScene+Board.swift` | In-game HUD, pile layout, controls, rules and pause cards |
| `GameScene+Play.swift` | Tapping, submitting, validation, wild resolution, hints |
| `GameScene+Flow.swift` | Menu choices, starting, finishing and replaying rounds |
| `GameScene+Results.swift` | Results screen |
| `GameScene+Effects.swift` | Word animations, star-word splash, celebrations |
| `GameScene+Nodes.swift` | Node builders, including the animated ladybug and outfits |
| `GameScene+Twists.swift` | Boss twists and Endless drops |
| `GameScene+Myth.swift` | Trial turns, hints, banners |
| `GameScene+Road.swift` | Rainbow road, Myth menu, finale, world portal |
| `GameScene+Clash.swift` | Myth characters and the trial-launch clash |
| `GameScene+Tutorial.swift`, `+HomeTour.swift` | Onboarding |
| `GameScene+Screens.swift` | Settings, stats and reset overlays |
| `AppDelegate`, `SceneDelegate`, `GameViewController` | UIKit shell |

### Persistence keys (UserDefaults)
- `progress.<world>`: levels beaten
- `stars.<world>`: starred level numbers
- `found.<world>.<level>`: star words found
- `rainbow.earned`, `myth.finaleSeen`
- `daily.day`, `daily.score`, `daily.streak`, `daily.bestStreak`, `daily.bestScore`, `daily.played` (only the latest day is kept)
- Plus keys for stats, high scores, settings and seen unlocks

---

## 5. Commit history
1. Initial commit
2. Add LetterFly gameplay, high scores, and app icon
3. Add themed worlds, playthrough levels, and sound
4. Retune level targets so every level is passable
5. Add Xcode Cloud workflow manifest
6. Update project settings for App Store builds
7. Add boss levels, Endless, tutorial, stats, outfits and UI polish
8. Fix bugs found in stress testing and rebalance boss levels
9. Add the Myth world, star words, portals and app icon variants
10. Expand the tutorial across Storm level 1 and add a home-screen tour
11. Prepare build 8 for App Store submission
12. Add build 8 App Store screenshots

---

## 6. Release status (as of Nov 9, 2026)
- **Build 8** was uploaded, processed, and swapped in for build 5 on version 1.0.
- The description, promotional text and review notes now mention the Myth world and star words.
- Screenshots were replaced with build 8 captures (`Release/Screenshots/build-8/`): iPhone 1206×2622 and iPad 13" 2064×2752, each showing the menu, the Myth road, the Sphinx in play, and Water in play.
- **Resubmitted ~9:24 PM Nov 9. Status: Waiting for Review.** The release setting is automatic on approval.
- A launch-screen fix shipped in build 8: the new `LaunchBackground` color (#1A212E ink navy) replaced a missing "Black" asset that caused a white flash at launch.
- The Release build has no warnings, debug prints, TODOs or cheat flags.
- Full details are in `Release/Release-Preparation.md`.

### Known gaps / open items
- The Myth world, portals and the new tutorial **have not been played through by hand on a real device**. They were only smoke-tested on the simulator.
- No device accessibility audit has been done.
- No optional App Store preview video or promo artwork.
- Availability is US only.
- Waiting on App Review; respond to any rejection.

---

## 7. Ideas for what's next (not started)
- Hand playtest Myth and the tutorial on a device, and fix anything found.
- Accessibility pass: VoiceOver labels on SpriteKit nodes, Dynamic Type, reduced motion.
- Localization and wider availability.
- App Store preview video.
- More worlds or trials, and more outfits.

---

## 8. Working conventions
- Each game-rule change lives in the pure model (`LetterFlyGame`, `MythTrial`, `Playthrough`). `GameScene` extensions handle drawing and flow only.
- Bump `CURRENT_PROJECT_VERSION` for every upload. Builds 6–8 have been used; the project is now set to build 9 (daily puzzle and Game Center).
- Release notes and screenshots go under `Release/`.
