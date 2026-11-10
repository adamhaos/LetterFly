import Foundation

/// A themed environment. Each round's hidden words come from the world's lists,
/// and spelling one of them scores as a theme bonus.
enum World: Int, CaseIterable {
    case storm, circus, road, water, volcano, space
    /// The secret world, opened by starring every level of the six main worlds.
    case myth

    /// The six worlds of the regular playthrough, in order.
    static let main: [World] = [.storm, .circus, .road, .water, .volcano, .space]

    var title: String {
        switch self {
        case .storm: "Storm"
        case .circus: "Circus"
        case .road: "Road"
        case .water: "Water"
        case .volcano: "Volcano"
        case .space: "Space"
        case .myth: "Myth"
        }
    }

    /// The playthrough chain runs Storm to Space; Myth sits outside it.
    var previous: World? { self == .myth ? nil : World(rawValue: rawValue - 1) }
    var next: World? { self == .myth || self == .space ? nil : World(rawValue: rawValue + 1) }

    func words(ofLength length: Int) -> [String] {
        if self == .myth { return Self.mythWords }
        return length == 6 ? sixLetterWords : eightLetterWords
    }

    /// Myth boards are built from five-letter words: gods, monsters, heroes and their things.
    static let mythWords = [
        "HYDRA", "TITAN", "ATLAS", "HADES", "CHAOS", "MIDAS", "NYMPH", "SATYR", "SIREN", "MUSES",
        "FATES", "HARPY", "CIRCE", "MEDEA", "PARIS", "HELEN", "CUPID", "VENUS", "PLUTO", "FREYA",
        "TROLL", "GIANT", "DWARF", "ELVES", "RUNES", "MYTHS", "DEITY", "SPEAR", "SWORD", "TORCH",
        "FLAME", "WINGS", "STONE", "CROWN", "QUEST", "MAGIC", "SPELL", "CURSE", "OMENS", "FABLE",
        "SAGAS", "ALTAR", "OLIVE", "FEAST", "ARROW", "ARMOR", "BEAST", "OGRES", "PIXIE", "FAIRY",
        "GENIE", "GHOST", "GLORY", "HONOR", "VALOR", "LYRES", "SNAKE", "TALES",
    ]

    private var eightLetterWords: [String] {
        switch self {
        case .storm:
            ["RAINDROP", "SNOWFALL", "DOWNPOUR", "BLIZZARD", "TWISTERS", "RAINCOAT", "MONSOONS",
             "RAINBOWS", "SUNSHINE", "DRIZZLES", "CYCLONES", "OVERCAST", "FORECAST", "HUMIDITY"]
        case .circus:
            ["ACROBATS", "JUGGLERS", "TRAPEZES", "ELEPHANT", "BALLOONS", "RINGSIDE", "SIDESHOW",
             "UNICYCLE", "MAGICIAN", "CAROUSEL", "FIREWORK", "SPANGLED", "PERFORMS"]
        case .road:
            ["HIGHWAYS", "MOTORWAY", "DRIVEWAY", "MILEPOST", "CROSSING", "JUNCTION", "SIGNPOST",
             "ROADSIDE", "TAILGATE", "ODOMETER", "CARAVANS", "BACKSEAT", "GASOLINE"]
        case .water:
            ["SEASHELL", "SEAHORSE", "DOLPHINS", "STARFISH", "SEAWEEDS", "SNORKELS", "MERMAIDS",
             "SAILBOAT", "SWIMMERS", "SEAGULLS", "TREASURE", "ANCHORED"]
        case .volcano:
            ["ERUPTION", "MOUNTAIN", "BOULDERS", "SMOLDERS", "FIREBALL", "SCORCHED", "HOTSPOTS",
             "SULFURIC", "TREMBLES", "VOLCANIC", "FISSURES", "EXPLODED"]
        case .space:
            ["STARSHIP", "ASTEROID", "MOONWALK", "SPACEMAN", "LAUNCHED", "ORBITERS", "STARDUST",
             "MOONBEAM", "SUNSPOTS", "ECLIPSES", "UNIVERSE", "BLASTOFF"]
        case .myth: []
        }
    }

    private var sixLetterWords: [String] {
        switch self {
        case .storm:
            ["CLOUDS", "BREEZE", "SHOWER", "STORMY", "WINTRY", "DELUGE", "SQUALL", "FREEZE",
             "FLURRY", "PUDDLE", "THAWED"]
        case .circus:
            ["CLOWNS", "JUGGLE", "TICKET", "POODLE", "CIRCUS", "PARADE", "SEQUIN", "JESTER",
             "CANNON", "TUMBLE", "STILTS", "GIGGLE"]
        case .road:
            ["DETOUR", "ENGINE", "TRAVEL", "BRIDGE", "TUNNEL", "MOTELS", "DRIVER", "GARAGE",
             "CORNER", "MIRROR", "TRUCKS", "BUMPER"]
        case .water:
            ["OCEANS", "CORALS", "SHARKS", "WHALES", "OYSTER", "SPLASH", "RIPPLE", "BUBBLE",
             "DIVERS", "TURTLE", "ISLAND", "LAGOON"]
        case .volcano:
            ["MOLTEN", "CRATER", "CINDER", "BLAZES", "FLAMES", "STEAMY", "ERUPTS", "GEYSER",
             "TREMOR", "SCORCH", "EMBERS", "PUMICE"]
        case .space:
            ["PLANET", "ROCKET", "COMETS", "GALAXY", "ORBITS", "METEOR", "SATURN", "ALIENS",
             "COSMOS", "STARRY", "NEBULA"]
        case .myth: []
        }
    }
}
