-- Standalone DIVE/SURFACE travel owned entirely by Dramatic Deep Dive.
return {
  route19_reef_passage = {
    requiredBadge = "VOLCANOBADGE",
    underwaterMapId = "DDD_ROUTE19_REEF_PASSAGE",
    submergedMaps = { "DDD_ROUTE19_REEF_PASSAGE" },
    links = {
      {
        id = "route19_reef_east",
        surface = { mapId = "ROUTE_19", x = 12, y = 30 },
        underwater = { mapId = "DDD_ROUTE19_REEF_PASSAGE", x = 14, y = 2 },
        width = 4, height = 4,
      },
      {
        id = "route19_reef_west",
        surface = { mapId = "ROUTE_19", x = 4, y = 30 },
        underwater = { mapId = "DDD_ROUTE19_REEF_PASSAGE", x = 2, y = 2 },
        width = 4, height = 4,
      },
    },
  },

  route20_seafoam = {
    requiredBadge = "VOLCANOBADGE",
    underwaterMapId = "DDD_ROUTE20_SEAFLOOR",
    submergedMaps = {
      "DDD_ROUTE20_SEAFLOOR",
      "DDD_SEAFOAM_SUNKEN_CAVE",
    },
    links = {
      {
        id = "route20_west_basin",
        surface = { mapId = "ROUTE_20", x = 4, y = 4 },
        underwater = { mapId = "DDD_ROUTE20_SEAFLOOR", x = 4, y = 4 },
        width = 34, height = 10,
      },
      {
        id = "route20_seafoam_channel",
        surface = { mapId = "ROUTE_20", x = 44, y = 12 },
        underwater = { mapId = "DDD_ROUTE20_SEAFLOOR", x = 44, y = 12 },
        width = 12, height = 4,
      },
      {
        id = "route20_east_basin",
        surface = { mapId = "ROUTE_20", x = 62, y = 4 },
        underwater = { mapId = "DDD_ROUTE20_SEAFLOOR", x = 62, y = 4 },
        width = 34, height = 10,
      },
    },
  },

  route21_abyss = {
    requiredBadge = "VOLCANOBADGE",
    underwaterMapId = "DDD_ROUTE21_ABYSS",
    submergedMaps = { "DDD_ROUTE21_ABYSS" },
    links = {
      {
        id = "route21_north_shelf",
        surface = { mapId = "ROUTE_21", x = 4, y = 8 },
        underwater = { mapId = "DDD_ROUTE21_ABYSS", x = 4, y = 8 },
        width = 12, height = 18,
      },
      {
        id = "route21_central_abyss",
        surface = { mapId = "ROUTE_21", x = 3, y = 34 },
        underwater = { mapId = "DDD_ROUTE21_ABYSS", x = 3, y = 34 },
        width = 14, height = 22,
      },
      {
        id = "route21_south_shelf",
        surface = { mapId = "ROUTE_21", x = 4, y = 66 },
        underwater = { mapId = "DDD_ROUTE21_ABYSS", x = 4, y = 66 },
        width = 12, height = 18,
      },
    },
  },
}
