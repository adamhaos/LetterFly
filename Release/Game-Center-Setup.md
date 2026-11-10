# Game Center setup (daily puzzle, leaderboards, achievements)

The code is in build 9. Before testing or submitting it, set up the following. The IDs must match exactly, since the app sends them as written.

## 1. Turn on the Game Center capability

The project already includes `LetterFly/LetterFly.entitlements` (with `com.apple.developer.game-center`) and points `CODE_SIGN_ENTITLEMENTS` at it. In Xcode, open the LetterFly target, go to **Signing & Capabilities**, and check that **Game Center** is listed. If it isn't, click **+ Capability**, add Game Center, and let Xcode use the existing entitlements file. Automatic signing updates the App ID.

## 2. Turn on Game Center in App Store Connect

Go to App Store Connect, then LetterFlyy, then **Distribution**. On the version page that will ship this (1.1 if 1.0 goes out first), check the **Game Center** box, then add the leaderboards and achievements below to that version. Create each one under **Services → Game Center**.

## 3. Leaderboards

| Leaderboard ID | Reference name | Type | Score format | Sort | Notes |
|---|---|---|---|---|---|
| `letterfly.daily` | Daily Puzzle | **Recurring** | Integer | High to low | Start at 08:00 UTC on any day, duration **1 day**, restarts every **1 day**. The 08:00 UTC hour matches `DailyPuzzle.resetHourUTC`. |
| `letterfly.endless` | Endless Best | Classic | Integer | High to low | Best Endless score on any pile |
| `letterfly.stars` | Stars Earned | Classic | Integer | High to low | Range 0–42 |
| `letterfly.daily_streak` | Daily Streak | Classic | Integer | High to low | Suffix "days" |

Each leaderboard needs an English (U.S.) localization with a display name, such as "Daily Puzzle", "Endless Best", "Stars" or "Daily Streak".

## 4. Achievements

Each achievement needs a title, a description for before it's earned, a description for after, a point value, and a 512×512 or 1024×1024 image. The points below add up to 590 of the 1,000 allowed.

| Achievement ID | Title | How to earn | Points | Hidden |
|---|---|---|---|---|
| `letterfly.first_flight` | First Flight | Beat Storm level 1 | 10 | No |
| `letterfly.storm_cleared` | Storm Chaser | Beat all 6 Storm levels | 25 | No |
| `letterfly.circus_cleared` | Ringmaster | Beat all 6 Circus levels | 30 | No |
| `letterfly.road_cleared` | Road Warrior | Beat all 6 Road levels | 35 | No |
| `letterfly.water_cleared` | Deep Diver | Beat all 6 Water levels | 40 | No |
| `letterfly.volcano_cleared` | Lava Walker | Beat all 6 Volcano levels | 45 | No |
| `letterfly.space_cleared` | Star Voyager | Beat all 6 Space levels | 50 | No |
| `letterfly.myth_opened` | Into the Myth | Open the secret Myth world | 75 | Yes |
| `letterfly.first_mastery` | Star Collector | Star every level in one world | 50 | No |
| `letterfly.rainbow` | Over the Rainbow | Earn the rainbow skin | 100 | Yes |
| `letterfly.long_word` | Big Words | Spell an 8-letter word | 20 | No |
| `letterfly.words_500` | Wordsmith | Spell 500 words | 50 | No |
| `letterfly.daily_first` | Daily Flier | Play a daily puzzle | 10 | No |
| `letterfly.daily_streak_7` | Week on the Wing | Play the daily puzzle 7 days in a row | 50 | No |

Achievements that track a count (the world clears, Star Collector, Wordsmith and Week on the Wing) report partial progress, so Game Center shows how close the player is.

## 5. Test

1. Create the leaderboards and achievements first, because Game Center ignores IDs it doesn't know.
2. On a device or simulator, sign in to Game Center (Settings → Game Center). Debug builds use the Game Center sandbox automatically.
3. Launch the app. The Game Center welcome banner should slide in.
4. Play today's daily puzzle. The score should show on the Daily Puzzle leaderboard, and Daily Flier should unlock.
5. Tap the trophy on the home screen to open the Game Center dashboard.

## 6. Privacy

The app sends only scores and achievement progress, and only to Apple's Game Center. Before submitting, check that the App Privacy answers ("Data Not Collected") still fit your reading of Apple's current rules for Game Center.
