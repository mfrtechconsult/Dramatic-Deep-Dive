-- Data-driven seabed identity for generated Kanto water maps.
-- Every detected water cell is covered; these rules only decide how that
-- underwater space should feel, not whether it exists.
return {
  default = "coastal",

  profiles = {
    coastal = {
      surfaceHeight = 680, minDepth = 18, defaultDepth = 70,
      nearFloor = 64, depthPerCell = 27, maxFloor = 520, seabedClearance = 9,
      floorColor = { 0.17, 0.30, 0.29 },
      scatter = { coral = 0.075, kelp = 0.055, rock = 0.040 },
      music = "Music_Dungeon2", ecology = "ocean",
    },
    ocean = {
      surfaceHeight = 760, minDepth = 22, defaultDepth = 90,
      nearFloor = 80, depthPerCell = 34, maxFloor = 700, seabedClearance = 11,
      floorColor = { 0.12, 0.25, 0.29 },
      scatter = { coral = 0.060, kelp = 0.045, rock = 0.052 },
      music = "Music_Dungeon2", ecology = "ocean",
    },
    harbor = {
      surfaceHeight = 610, minDepth = 16, defaultDepth = 58,
      nearFloor = 52, depthPerCell = 18, maxFloor = 360, seabedClearance = 8,
      floorColor = { 0.22, 0.27, 0.25 },
      scatter = { kelp = 0.030, rock = 0.050 },
      music = "Music_Dungeon2", ecology = "harbor",
    },
    volcanic = {
      surfaceHeight = 760, minDepth = 24, defaultDepth = 96,
      nearFloor = 88, depthPerCell = 38, maxFloor = 740, seabedClearance = 12,
      floorColor = { 0.10, 0.15, 0.17 },
      scatter = { rock = 0.090, crystal = 0.018 },
      vents = true, music = "Music_Dungeon2", ecology = "volcanic",
    },
    cave = {
      surfaceHeight = 580, minDepth = 22, defaultDepth = 78,
      nearFloor = 68, depthPerCell = 26, maxFloor = 540, seabedClearance = 9,
      floorColor = { 0.10, 0.17, 0.22 },
      scatter = { rock = 0.070, crystal = 0.055, kelp = 0.018 },
      cave = true, music = "Music_Dungeon3", ecology = "cave",
    },
    freshwater = {
      surfaceHeight = 520, minDepth = 12, defaultDepth = 42,
      nearFloor = 36, depthPerCell = 14, maxFloor = 270, seabedClearance = 7,
      floorColor = { 0.24, 0.28, 0.21 },
      scatter = { kelp = 0.075, rock = 0.032 },
      music = "Music_Dungeon2", ecology = "freshwater",
    },
    marsh = {
      surfaceHeight = 500, minDepth = 10, defaultDepth = 34,
      nearFloor = 28, depthPerCell = 11, maxFloor = 200, seabedClearance = 6,
      floorColor = { 0.25, 0.27, 0.18 },
      scatter = { kelp = 0.095, rock = 0.018 },
      music = "Music_Dungeon2", ecology = "marsh",
    },
  },

  -- Explicit Kanto geography. Maps without water are harmless here: they are
  -- never emitted by the atlas. The point is that any water which does exist
  -- inherits the correct regional identity instead of a generic ocean floor.
  overrides = {
    PALLET_TOWN = "coastal",
    VIRIDIAN_CITY = "freshwater",
    PEWTER_CITY = "freshwater",
    CERULEAN_CITY = "freshwater",
    CELADON_CITY = "freshwater",
    SAFFRON_CITY = "freshwater",
    LAVENDER_TOWN = "freshwater",
    FUCHSIA_CITY = "marsh",
    VERMILION_CITY = "harbor",
    VERMILION_DOCK = "harbor",
    CINNABAR_ISLAND = "volcanic",

    ROUTE_1 = "freshwater",
    ROUTE_2 = "freshwater",
    ROUTE_3 = "freshwater",
    ROUTE_4 = "freshwater",
    ROUTE_5 = "freshwater",
    ROUTE_6 = "freshwater",
    ROUTE_7 = "freshwater",
    ROUTE_8 = "freshwater",
    ROUTE_9 = "freshwater",
    ROUTE_10 = "freshwater",
    ROUTE_11 = "coastal",
    ROUTE_12 = "coastal",
    ROUTE_13 = "coastal",
    ROUTE_14 = "coastal",
    ROUTE_15 = "coastal",
    ROUTE_16 = "freshwater",
    ROUTE_17 = "freshwater",
    ROUTE_18 = "marsh",
    ROUTE_19 = "ocean",
    ROUTE_20 = "ocean",
    ROUTE_21 = "ocean",
    ROUTE_22 = "freshwater",
    ROUTE_23 = "freshwater",
    ROUTE_24 = "freshwater",
    ROUTE_25 = "freshwater",
  },

  patterns = {
    { find = "SEAFOAM_ISLANDS", profile = "cave" },
    { find = "CERULEAN_CAVE", profile = "cave" },
    { find = "ROCK_TUNNEL", profile = "cave" },
    { find = "VICTORY_ROAD", profile = "cave" },
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
