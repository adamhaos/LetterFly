# LetterFly 1.0 release preparation

Prepared October 13, 2026. App Store Connect app: 6816781742; bundle ID: atm.LetterFly.

## Build

- Release build and signed archive succeeded; build 5 uploaded successfully.
- Minimum iOS version in the archive: 17.0.
- Added PrivacyInfo.xcprivacy for local UserDefaults access (CA92.1); no tracking or collected data.
- Removed the unused local variable and fixed the actor-isolation compiler warning.
- Signed archive: /private/tmp/LetterFly-1.0-5.xcarchive.

## Validation

- iPhone: word selection, submission, scoring, timed results, replay, boss round, and hints checked.
- iPad: first-run tutorial, word submission, scoring, and menu/gameplay layouts checked.
- Core model checks passed for 900 randomized boards across all worlds and board sizes, selection/removal, Endless drops, progress persistence, and score ordering.
- This is a release smoke test, not a complete manual playthrough of every level or a device accessibility audit.

## Store preparation

- Build 5 attached to version 1.0.
- Free pricing; United States only.
- Games / Word category; subtitle: Words Take Flight.
- Age rating: 4+.
- Description, promotional text, keywords, copyright, review contact and notes saved.
- No sign-in required.
- Privacy label: Data Not Collected.
- Support and privacy website: https://sites.google.com/view/letterfly-app
- Two screenshots in the required medium iPhone slot and two in the 13-inch iPad slot.

The app remains in Prepare for Submission. Add for Review was not clicked. Optional preview videos and promotional header artwork were not added.

## Update — November 9, 2026: build 8 (uploaded)

Build 5 (attached to 1.0 in App Store Connect) predates the Myth world, star words, portals, icon variants and the expanded tutorial/home tour. Build 8 includes all of them.

- Build number bumped to 8; builds 6 and 7 had already been uploaded earlier, so App Store Connect rejected 7.
- Launch screen fix: Info.plist referenced a color asset named "Black" that did not exist, causing a white flash at launch in light mode. Added `LaunchBackground` (the game's ink navy, #1A212E) and pointed the launch screen at it.
- Display name intentionally stays "LetterFlyy" (the other spelling is taken on the App Store).
- Clean Release build: no compiler warnings. No debug prints, TODOs or cheat flags in the source.
- Signed archive: ~/Library/Developer/Xcode/Archives/2026-11-09/LetterFly 1.0 (8).xcarchive (min iOS 17.0, ITSAppUsesNonExemptEncryption = NO, team ZCW4C29TGM).
- Release build launches on the iPhone simulator to the menu.

### Remaining before Add for Review
1. Build 8 uploaded Nov 9 and is processing. Once it shows in App Store Connect, swap it in for build 5 on version 1.0.
2. Screenshots predate star words / Myth; optional refresh.
3. Mention the Myth world and star words in the description/promotional text if they aren't there.
4. Myth world, portals and the new tutorial have not been played through by hand on device.

### Submitted — November 9, 2026
- Build 8 processed; swapped in for build 5 on version 1.0.
- Description, promotional text and review notes updated for the Myth world and star words.
- Submitted for review at ~8:53 PM; status Waiting for Review. Release setting: automatic on approval.
