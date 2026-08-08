return {
  route20_wreck = {
    mapId = "DDD_ROUTE20_SEAFLOOR",
    pieces = {
      {
        kind = "shipwreck",
        x = 1260, z = 166,
        length = 154, width = 58, height = 46,
        yaw = -0.10,
        solid = true,
      },
      {
        kind = "black_smokers",
        x = 820, z = 210,
        count = 5, radius = 46, height = 72,
        solid = true,
      },
    },
  },

  seafoam_ceiling = {
    mapId = "DDD_SEAFOAM_SUNKEN_CAVE",
    pieces = {
      {
        kind = "cave_ceiling",
        x = 160, z = 128,
        width = 288, depth = 220,
        ceilingDepth = 18,
        thickness = 18,
      },
      {
        kind = "stalactite_field",
        seed = 5101,
        x0 = 42, x1 = 278, z0 = 38, z1 = 220,
        count = 28,
        ceilingDepth = 34,
        minLength = 18, maxLength = 62,
        solid = true,
      },
    },
  },

  route21_abyss_setpieces = {
    mapId = "DDD_ROUTE21_ABYSS",
    pieces = {
      {
        kind = "rib_cage",
        x = 154, z = 1004,
        length = 116, width = 88, height = 46,
        ribs = 8,
      },
      {
        kind = "black_smokers",
        x = 83, z = 974,
        count = 4, radius = 34, height = 82,
        solid = true,
      },
    },
  },
}
