import Foundation

/// The rules of a Myth trial. Each of the six Myth levels plays one trial, drawn from a
/// legend; every word is still played normally, and the trial decides what it counts for.
struct MythTrial {
    enum Kind: Int, CaseIterable {
        case icarus, ouroboros, sphinx, midas, fates, hydra

        var title: String {
            switch self {
            case .icarus: "Icarus's Flight"
            case .ouroboros: "The Ouroboros"
            case .sphinx: "Riddle of the Sphinx"
            case .midas: "The Midas Touch"
            case .fates: "Threads of Fate"
            case .hydra: "The Hydra"
            }
        }

        var shortTitle: String {
            switch self {
            case .icarus: "Icarus"
            case .ouroboros: "Ouroboros"
            case .sphinx: "Sphinx"
            case .midas: "Midas"
            case .fates: "Fates"
            case .hydra: "Hydra"
            }
        }

        var symbol: String {
            switch self {
            case .icarus: "sun.max.fill"
            case .ouroboros: "arrow.triangle.2.circlepath"
            case .sphinx: "eye.fill"
            case .midas: "hand.point.up.fill"
            case .fates: "scissors"
            case .hydra: "flame.fill"
            }
        }

        /// The legend, told when the trial begins.
        var legend: String {
            switch self {
            case .icarus:
                "Daedalus made his son wings of feathers and wax, and warned him: fly too low and the sea spray soaks them, fly too high and the sun melts them."
            case .ouroboros:
                "The Ouroboros is the serpent that eats its own tail, a circle with no end."
            case .sphinx:
                "The Sphinx guards the road to Thebes, and lets no one pass who cannot answer her riddles."
            case .midas:
                "King Midas wished that everything he touched would turn to gold. The gods granted it."
            case .fates:
                "Three sisters weave every life: Clotho spins the thread, Lachesis measures it, and Atropos cuts it."
            case .hydra:
                "The Hydra has many heads: cut one off and two grow back. Heracles won by sealing each wound with fire, and buried the last, immortal head under a rock."
            }
        }

        /// How to win, in one or two lines.
        var rule: String {
            switch self {
            case .icarus:
                "Climb with words of exactly 3, then 4, 5 and 6 letters. Any other length and you fall back to 3. Finish \(goal) climbs."
            case .ouroboros:
                "Each word must start with the last letter of the word before. Break the chain and it starts over. Link \(goal) words."
            case .sphinx:
                "Spell the answer to each riddle; it's hidden in the pile. A wrong myth word costs 10 seconds. Solve \(goal) riddles."
            case .midas:
                "Every letter your words uncover turns gold, worth triple. Use \(goal) gold letters in your words."
            case .fates:
                "Letters come in three threads. Serve each sister in turn with \(goal / 3) words holding 2+ letters of her color."
            case .hydra:
                "Words of 5+ letters burn a head away; shorter ones grow a head back. The last head needs a myth word. Don't let it reach \(MythTrial.hydraMaxHeads) heads."
            }
        }

        var goal: Int {
            switch self {
            case .icarus: 3
            case .ouroboros: 6
            case .sphinx: 5
            case .midas: 40
            case .fates: 9
            case .hydra: MythTrial.hydraStartHeads
            }
        }

        var duration: TimeInterval {
            switch self {
            case .icarus: 300
            case .ouroboros: 300
            case .sphinx: 240
            case .midas: 160
            case .fates: 150
            case .hydra: 180
            }
        }
    }

    /// What a submitted word did, for the status line and the scene's effects.
    struct Outcome {
        var message: String
        var good: Bool
        /// Hydra: letters to grow onto the pile.
        var growLetters = 0
        /// Sphinx: seconds taken off the clock.
        var timePenalty: TimeInterval = 0
        /// Midas: gild the letters this word uncovered.
        var gildUncovered = false
    }

    static let hydraStartHeads = 8
    static let hydraMaxHeads = 10
    static let fateNames = ["Clotho", "Lachesis", "Atropos"]
    static let fateColorNames = ["blue", "gold", "rose"]

    let kind: Kind
    /// Progress toward `kind.goal`: climbs, chain links, riddles, gold letters, offerings, heads cut.
    private(set) var progress = 0
    private(set) var isFailed = false

    // Icarus: how many steps of the current climb are done (0–3); the next word needs 3 + step letters.
    private(set) var climbStep = 0
    // Ouroboros: the letter the next word must start with.
    private(set) var chainLetter: Character?
    // Sphinx: the riddle's answer and the answers already given.
    private(set) var riddleAnswer: String?
    private(set) var solved: Set<String> = []
    // Fates: offerings made to the current sister (0–2 index).
    private(set) var fate = 0
    private(set) var fateOfferings = 0
    // Hydra: heads still attached, and whether the last head still demands a myth word
    // (it settles for any 5+ letter word once no myth word can be spelled).
    private(set) var heads = MythTrial.hydraStartHeads
    private(set) var immortalNeedsMyth = true

    mutating func allowAnyBurial() { immortalNeedsMyth = false }

    init(kind: Kind) { self.kind = kind }

    var isComplete: Bool { progress >= kind.goal }

    /// The length Icarus's next word must be.
    var requiredLength: Int { 3 + climbStep }

    var offeringsPerFate: Int { kind.goal / 3 }

    var fraction: Double { min(1, Double(progress) / Double(kind.goal)) }

    /// A short line telling the player what to do next.
    var objective: String {
        switch kind {
        case .icarus:
            "Climb \(min(progress + 1, kind.goal)) of \(kind.goal)  •  next word: exactly \(requiredLength) letters"
        case .ouroboros:
            chainLetter.map { "Chain \(progress)/\(kind.goal)  •  next word starts with \($0)" }
                ?? "Chain 0/\(kind.goal)  •  start with any word"
        case .sphinx:
            riddleAnswer.flatMap { MythTrial.riddles[$0] } ?? "The Sphinx is thinking of a riddle…"
        case .midas:
            "Gold used \(progress)/\(kind.goal)  •  gold letters score triple"
        case .fates:
            "\(Self.fateNames[fate]) wants words with 2+ \(Self.fateColorNames[fate]) letters  •  \(fateOfferings)/\(offeringsPerFate)"
        case .hydra:
            heads == 1 ? (immortalNeedsMyth ? "One immortal head left  •  bury it with a myth word"
                                            : "One immortal head left  •  bury it with 5+ letters")
                : "\(heads) heads  •  5+ letters burn one away"
        }
    }

    /// Counts a word that has just been played. `tiles` are its letters as they were in the pile.
    mutating func record(word: String, tiles: [LetterFlyGame.Tile], isThemeWord: Bool) -> Outcome {
        // A finished trial (won or lost) doesn't change any more.
        guard !isComplete, !isFailed else { return Outcome(message: "", good: true) }
        let length = word.count
        switch kind {
        case .icarus:
            guard length == requiredLength else {
                let tooHigh = length > requiredLength
                climbStep = 0
                return Outcome(message: tooHigh ? "Too close to the sun! Your wings melt" : "Too low! Sea spray soaks your wings",
                               good: false)
            }
            climbStep += 1
            if climbStep == 4 {
                climbStep = 0
                progress += 1
                return Outcome(message: isComplete ? "You soared safely home!" : "Climb \(progress) complete!", good: true)
            }
            return Outcome(message: "Higher! Next: \(requiredLength) letters", good: true)

        case .ouroboros:
            let first = Character(word.prefix(1).uppercased())
            defer { chainLetter = Character(word.suffix(1).uppercased()) }
            if let chainLetter, first != chainLetter {
                progress = 1
                return Outcome(message: "The chain breaks! A new one starts", good: false)
            }
            progress += 1
            return Outcome(message: isComplete ? "The serpent bites its tail!" : "Linked! \(progress)/\(kind.goal)", good: true)

        case .sphinx:
            let upper = word.uppercased()
            if upper == riddleAnswer {
                solved.insert(upper)
                riddleAnswer = nil
                progress += 1
                return Outcome(message: isComplete ? "The Sphinx steps aside!" : "Correct! Another riddle…", good: true)
            }
            if isThemeWord {
                return Outcome(message: "Wrong answer! The Sphinx takes 10 seconds", good: false, timePenalty: 10)
            }
            return Outcome(message: "+ \(upper)", good: true)

        case .midas:
            let gold = tiles.filter(\.isGold).count
            progress += gold
            let message = gold > 0 ? "\(gold) gold \(gold == 1 ? "letter" : "letters")! \(min(progress, kind.goal))/\(kind.goal)"
                : "Your touch turns the letters below to gold"
            return Outcome(message: message, good: true, gildUncovered: true)

        case .fates:
            let matching = tiles.filter { $0.thread == fate }.count
            guard matching >= 2 else {
                return Outcome(message: "\(Self.fateNames[fate]) wants 2+ \(Self.fateColorNames[fate]) letters", good: false)
            }
            progress += 1
            fateOfferings += 1
            let name = Self.fateNames[fate]
            if fateOfferings == offeringsPerFate, fate < 2 {
                fate += 1
                fateOfferings = 0
                return Outcome(message: "\(name) is pleased. Now \(Self.fateNames[fate])", good: true)
            }
            return Outcome(message: isComplete ? "Atropos cuts the thread!" : "\(name) accepts \(fateOfferings)/\(offeringsPerFate)",
                           good: true)

        case .hydra:
            if heads == 1 {
                if isThemeWord || (!immortalNeedsMyth && length >= 5) {
                    heads = 0
                    progress = kind.goal
                    return Outcome(message: "You buried the immortal head!", good: true)
                }
                if length >= 5 {
                    return Outcome(message: immortalNeedsMyth ? "Only a myth word can bury the immortal head"
                                                              : "Only 5+ letters can bury the immortal head", good: false)
                }
                // Short words still grow heads back, even at the end.
            }
            if length >= 5, heads > 1 {
                heads -= 1
                progress = Self.hydraStartHeads - heads
                return Outcome(message: heads == 1 ? "One head left: the immortal one!" : "Burned away! \(heads) heads left",
                               good: true)
            }
            heads += 1
            progress = max(0, Self.hydraStartHeads - heads)
            if heads >= Self.hydraMaxHeads { isFailed = true }
            return Outcome(message: "Two heads grow back! \(heads) heads", good: false, growLetters: 2)
        }
    }

    /// Sphinx: picks the next riddle, favoring answers that can be spelled right now.
    mutating func chooseRiddle(in game: LetterFlyGame) {
        guard kind == .sphinx else { return }
        let solved = solved
        let unasked = { (words: [String]) in words.filter { !solved.contains($0) && !game.usedWords.contains($0.lowercased()) } }
        // Once the pile's own myth words are spent, any other myth word can be the answer.
        var open = unasked(game.roundWords)
        if open.isEmpty { open = unasked(World.mythWords) }
        if let current = riddleAnswer, open.contains(current), game.canSpell(current, from: game.remainingLetters) { return }
        let available = game.availableLetters
        riddleAnswer = open.first { game.canSpell($0, from: available) }
            ?? open.first { game.canSpell($0, from: game.remainingLetters) }
            ?? open.first
    }

    /// Hydra: whether the next word must be a myth word.
    var needsMythWord: Bool { kind == .hydra && heads == 1 && immortalNeedsMyth }

    // MARK: - Riddles

    /// One riddle for every Myth word, so any word on a Sphinx board can be asked.
    static let riddles: [String: String] = [
        "HYDRA": "Cut off one of my heads and two grow back.",
        "TITAN": "My giant kind ruled before the gods of Olympus.",
        "ATLAS": "I hold the sky on my shoulders. Now I'm a book of maps.",
        "HADES": "I rule the underworld, with a three-headed dog at my door.",
        "CHAOS": "Before anything existed, there was only me: the great void.",
        "MIDAS": "Everything I touched turned to gold, even my dinner.",
        "NYMPH": "A spirit of the rivers, trees and springs.",
        "SATYR": "Half goat, half man, I love music and dancing.",
        "SIREN": "Sailors heard my song and steered onto the rocks.",
        "MUSES": "Nine sisters who inspire poets, painters and singers.",
        "FATES": "Three sisters who spin, measure and cut the thread of life.",
        "HARPY": "Half bird, half woman, I snatch things away.",
        "CIRCE": "A witch who turned Odysseus's sailors into pigs.",
        "MEDEA": "A sorceress who helped Jason steal the Golden Fleece.",
        "PARIS": "A Trojan prince who carried off a queen. Also the capital of France.",
        "HELEN": "Mine was the face that launched a thousand ships.",
        "CUPID": "My arrows make people fall in love.",
        "VENUS": "The Roman goddess of love, and the brightest planet at night.",
        "PLUTO": "The Roman king of the underworld, and a dwarf planet.",
        "FREYA": "A Norse goddess whose chariot is pulled by cats.",
        "TROLL": "I lurk under bridges and turn to stone in sunlight.",
        "GIANT": "Jack climbed a beanstalk to reach my castle.",
        "DWARF": "I forge treasures deep in the mountains. Snow White knew seven of us.",
        "ELVES": "Pointy-eared folk of the forest, famous archers.",
        "RUNES": "Ancient Norse letters carved into stone.",
        "MYTHS": "Old stories of gods and heroes, like this whole world.",
        "DEITY": "Another word for a god or goddess.",
        "SPEAR": "A long pole with a sharp point, carried by Athena.",
        "SWORD": "Arthur pulled me from the stone.",
        "TORCH": "Carry me to light your way through the labyrinth.",
        "FLAME": "Prometheus stole me from the gods and gave me to people.",
        "WINGS": "Icarus made me out of feathers and wax.",
        "STONE": "Look into Medusa's eyes and you'll turn into me.",
        "CROWN": "A king wears me on his head.",
        "QUEST": "A hero's long journey to find something precious.",
        "MAGIC": "Wizards and witches use me to cast spells.",
        "SPELL": "Witches cast me, and you do it to words.",
        "CURSE": "A wicked spell, like the one on Sleeping Beauty.",
        "OMENS": "Signs of what's to come, like a crow at your window.",
        "FABLE": "A short story with a lesson, like the tortoise and the hare.",
        "SAGAS": "Long Norse tales of heroes and their families.",
        "ALTAR": "A stone table where offerings are left for the gods.",
        "OLIVE": "Athena's gift to Athens: a tree with small green fruit.",
        "FEAST": "A great banquet in the halls of the gods.",
        "ARROW": "Feathered at one end, sharp at the other, fired from a bow.",
        "ARMOR": "Achilles wore me into battle, but his heel was left bare.",
        "BEAST": "Beauty fell in love with me.",
        "OGRES": "Big, smelly monsters who eat travelers. Shrek is one.",
        "PIXIE": "A tiny, mischievous sprite with pointed ears.",
        "FAIRY": "Tinker Bell is one of me.",
        "GENIE": "Rub my lamp and I'll grant you three wishes.",
        "GHOST": "A spirit of the dead that haunts the living.",
        "GLORY": "What heroes seek: fame that lasts forever.",
        "HONOR": "A hero's good name and sense of what's right.",
        "VALOR": "Great courage in the face of danger.",
        "LYRES": "Small harps, played by Apollo and Orpheus.",
        "SNAKE": "Medusa had a head full of me.",
        "TALES": "Stories, especially ones told around a fire.",
    ]
}
