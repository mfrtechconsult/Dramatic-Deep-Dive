-- Data-driven seabed identity for generated Kanto water maps.
-- Map-specific overrides win; otherwise KantoWaterAtlas applies patterns.
return {
  default = "coastal",

  profiles = {
    coastal = {
      surfaceHeight = 680, minDepth = 22, defaultDepth = 76,
      nearFloor = 118, depthPerCell = 24, maxFloor = 500, seabedClearance = 9,
      floorColor = { 0.17, 0.30, 0.29 },
      scatter = { coral = 0.075, kelp = 0.055, rock = 0.040 },
      music = "Music_Dungeon2",
      ecology = "ocean",
    },
    ocean = {
      surfaceHeight = 760, minDepth = 26, defaultDepth = 96,
      nearFloor = 128, depthPerCell = 30, maxFloor = 650, seabedClearance = 11,
      floorColor = { 0.12, 0.25, 0.29 },
      scatter = { coral = 0.060, kelp = 0.045, rock = 0.052 },
      music = "Music_Dungeon2",
      ecology = "ocean",
    },
    harbor = {
      surfaceHeight = 610, minDepth = 20, defaultDepth = 66,
      nearFloor = 105, depthPerCell = 16, maxFloor = 330, seabedClearance = 8,
      floorColor = { 0.22, 0.27, 0.25 },
      scatter = { kelp = 0.030, rock = 0.050 },
      music = "Music_Dungeon2",
      ecology = "harbor",
    },
    volcanic = {
      surfaceHeight = 760, minDepth = 28, defaultDepth = 104,
      nearFloor = 135, depthPerCell = 34, maxFloor = 680, seabedClearance = 12,
      floorColor = { 0.10, 0.15, 0.17 },
      scatter = { rock = 0.090, crystal = 0.018 },
      vents = true,
      music = "Music_Dungeon2",
      ecology = "volcanic",
    },
    cave = {
      surfaceHeight = 580, minDepth = 30, defaultDepth = 92,
      nearFloor = 120, depthPerCell = 23, maxFloor = 500, seabedClearance = 9,
      floorColor = { 0.10, 0.17, 0.22 },
      scatter = { rock = 0.070, crystal = 0.055, kelp = 0.018 },
      cave = true,
      music = "Music_Dungeon3",
      ecology = "cave",
    },
    freshwater = {
      surfaceHeight = 520, minDepth = 16, defaultDepth = 52,
      nearFloor = 82, depthPerCell = 12, maxFloor = 245, seabedClearance = 7,
      floorColor = { 0.24, 0.28, 0.21 },
      scatter = { kelp = 0.075, rock = 0.032 },
      music = "Music_Dungeon2",
      ecology = "freshwater",
    },
    marsh = {
      surfaceHeight = 500, minDepth = 14, defaultDepth = 44,
      nearFloor = 70, depthPerCell = 9, maxFloor = 185, seabedClearance = 6,
      floorColor = { 0.25, 0.27, 0.18 },
      scatter = { kelp = 0.095, rock = 0.018 },
      music = "Music_Dungeon2",
      ecology = "marsh",
    },
  },

  overrides = {
    PALLET_TOWN = "coastal",
    VERMILION_CITY = "harbor",
    VERMILION_DOCK = "harbor",
    CINNABAR_ISLAND = "volcanic",
    FUCHSIA_CITY = "marsh",
    CERULEAN_CITY = "freshwater",
    CELADON_CITY = "freshwater",
    ROUTE_19 = "ocean",
    ROUTE_20 = "ocean",
    ROUTE_21 = "ocean",
    ROUTE_24 = "freshwater",
    ROUTE_25 = "freshwater",
    ROUTE_10 = "freshwater",
  },

  patterns = {
    { find = "SEAFOAM_ISLANDS", profile = "cave" },
    { find = "SAFARI_ZONE", profile = "marsh" },
    { find = "VERMILION", profile = "harbor" },
    { find = "CINNABAR", profile = "volcanic" },
  },

  ecology = {
    ocean = {
      shallow = { "TENTACOOL", "HORSEA", "KRABBY", "STARYU", "SHELLDER" },
      mid = { "TENTACOOL", "HORSEA", "SEADRA", "STARYU", "SHELLDER", "KINGLER" },
      deep = { "SEADRA", "TENTACRUEL", "CLOYSTER", "STARMIE", "GYARADOS", "DEWGONG" },
    },
    harbor = {
      shallow = { "KRABBY", "TENTACOOL", "MAGIKARP", "SHELLDER", "STARYU" },
      mid = { "KRABBY", "KINGLER", "TENTACOOL", "SHELLDER", "STARYU" },
      deep = { "KINGLER", "TENTACRUEL", "CLOYSTER", "GYARADOS" },
    },
    volcanic = {
      shallow = { "TENTACOOL", "HORSEA", "MAGIKARP", "KRABBY" },
      mid = { "TENTACOOL", "SEADRA", "TENTACRUEL", "STARYU" },
      deep = { "TENTACRUEL", "SEADRA", "CLOYSTER", "GYARADOS" },
    },
    cave = {
      shallow = { "SEEL", "SHELLDER", "SLOWPOKE", "HORSEA" },
      mid = { "SEEL", "SHELLDER", "SLOWPOKE", "DEWGONG", "CLOYSTER" },
      deep = { "DEWGONG", "CLOYSTER", "SLOWBRO", "SEADRA", "GYARADOS" },
    },
    freshwater = {
      shallow = { "POLIWAG", "PSYDUCK", "GOLDEEN", "MAGIKARP", "SLOWPOKE" },
      mid = { "POLIWAG", "POLIWHIRL", "PSYDUCK", "GOLDEEN", "SLOWPOKE" },
      deep = { "POLIWHIRL", "GOLDUCK", "SEAKING", "SLOWBRO", "GYARADOS" },
    },
    marsh = {
      shallow = { "POLIWAG", "PSYDUCK", "SLOWPOKE", "MAGIKARP", "GOLDEEN" },
      mid = { "POLIWAG", "PSYDUCK", "SLOWPOKE", "GOLDEEN", "SEAKING" },
      deep = { "POLIWHIRL", "GOLDUCK", "SLOWBRO", "SEAKING" },
    },
  },
}
