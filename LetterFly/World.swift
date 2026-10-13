import Foundation

/// A themed environment. Each round's hidden words come from the world's lists,
/// and spelling one of them scores as a theme bonus.
enum World: Int, CaseIterable {
    case storm, circus, road, water, volcano, space

    var title: String {
        switch self {
        case .storm: "Storm"
        case .circus: "Circus"
        case .road: "Road"
        case .water: "Water"
        case .volcano: "Volcano"
        case .space: "Space"
        }
    }

    var previous: World? { World(rawValue: rawValue - 1) }
    var next: World? { World(rawValue: rawValue + 1) }

    func words(ofLength length: Int) -> [String] {
        length == 6 ? sixLetterWords : eightLetterWords
    }

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
        }
    }
}
