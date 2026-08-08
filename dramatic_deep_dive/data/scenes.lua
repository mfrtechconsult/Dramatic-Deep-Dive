-- Hand-authored scene composition for the standalone Route 21 abyss.
-- Geometry is generated procedurally at runtime by SceneDecor; this file is
-- intentionally data-only so the same concepts can later come from Tiled.
return {
  route21_abyss = {
    mapId = "DDD_ROUTE21_ABYSS",

    districts = {
      { id = "pallet_reef", name = "PALLET REEF", z0 = 0, z1 = 330 },
      { id = "kelp_cathedral", name = "KELP CATHEDRAL", z0 = 330, z1 = 570 },
      { id = "sunken_court", name = "SUNKEN COURT", z0 = 570, z1 = 825 },
      { id = "abyssal_gate", name = "ABYSSAL GATE", z0 = 825, z1 = 1030 },
      { id = "southern_gardens", name = "SOUTHERN GARDENS", z0 = 1030, z1 = 1440 },
    },

    -- Large landmarks deliberately frame the long north/south Route 21 map.
    structures = {
      { kind = "rock_arch", x = 160, z = 280, width = 122, height = 54, thickness = 13, material = "reefRock" },
      { kind = "spire", x = 45, z = 405, height = 72, radius = 15, material = "reefRock" },
      { kind = "spire", x = 276, z = 438, height = 86, radius = 18, material = "reefRock" },

      { kind = "ruin_gate", x = 160, z = 620, width = 96, height = 62, thickness = 12, material = "ruinStone", solid = true },
      { kind = "broken_wall", x = 55, z = 690, width = 66, height = 34, thickness = 9, material = "ruinStone", solid = true },
      { kind = "broken_wall", x = 262, z = 710, width = 72, height = 42, thickness = 9, material = "ruinStone", solid = true },
      { kind = "column_ring", x = 160, z = 760, radius = 66, count = 8, height = 50, material = "ruinStone", solid = true },
      { kind = "shrine", x = 160, z = 810, width = 72, depth = 52, height = 48, material = "ruinStone", solid = true },

      -- The central chasm gets a giant gateway visible from far away.
      { kind = "abyss_gate", x = 160, z = 900, width = 138, height = 96, thickness = 16, material = "darkStone", solid = true },
      { kind = "spire", x = 42, z = 940, height = 112, radius = 19, material = "darkStone" },
      { kind = "spire", x = 280, z = 952, height = 124, radius = 20, material = "darkStone" },

      { kind = "rock_arch", x = 160, z = 1135, width = 132, height = 58, thickness = 14, material = "reefRock" },
      { kind = "ruin_gate", x = 82, z = 1260, width = 72, height = 48, thickness = 10, material = "ruinStone", solid = true },
      { kind = "ruin_gate", x = 240, z = 1320, width = 72, height = 48, thickness = 10, material = "ruinStone", solid = true },
    },

    scatter = {
      { kind = "coral", seed = 2101, count = 44, x0 = 18, x1 = 302, z0 = 35, z1 = 320, minHeight = 10, maxHeight = 30 },
      { kind = "kelp", seed = 2102, count = 52, x0 = 18, x1 = 302, z0 = 330, z1 = 575, minHeight = 24, maxHeight = 72 },
      { kind = "coral", seed = 2103, count = 28, x0 = 12, x1 = 308, z0 = 580, z1 = 825, minHeight = 8, maxHeight = 22 },
      { kind = "crystal", seed = 2104, count = 30, x0 = 18, x1 = 302, z0 = 720, z1 = 1030, minHeight = 8, maxHeight = 30 },
      { kind = "rock", seed = 2105, count = 24, x0 = 8, x1 = 312, z0 = 830, z1 = 1040, minHeight = 12, maxHeight = 44 },
      { kind = "coral", seed = 2106, count = 58, x0 = 16, x1 = 304, z0 = 1040, z1 = 1420, minHeight = 8, maxHeight = 34 },
      { kind = "kelp", seed = 2107, count = 34, x0 = 20, x1 = 300, z0 = 1060, z1 = 1390, minHeight = 22, maxHeight = 58 },
    },

    crystalClusters = {
      { x = 92, z = 735, count = 6, radius = 18, height = 30 },
      { x = 225, z = 790, count = 7, radius = 22, height = 38 },
      { x = 82, z = 920, count = 8, radius = 24, height = 42 },
      { x = 245, z = 955, count = 9, radius = 24, height = 46 },
      { x = 160, z = 1015, count = 5, radius = 15, height = 34 },
    },

    bubbleVents = {
      { x = 56, z = 180, count = 5, height = 118, speed = 12 },
      { x = 265, z = 410, count = 6, height = 150, speed = 15 },
      { x = 91, z = 705, count = 5, height = 130, speed = 11 },
      { x = 232, z = 790, count = 7, height = 178, speed = 17 },
      { x = 160, z = 930, count = 9, height = 205, speed = 20 },
      { x = 69, z = 1180, count = 6, height = 145, speed = 14 },
      { x = 258, z = 1340, count = 5, height = 120, speed = 12 },
    },

    lightShafts = {
      { x = 78, z = 125, width = 28, depth = 38, bottomDepth = 105, alpha = 0.055 },
      { x = 216, z = 255, width = 38, depth = 54, bottomDepth = 130, alpha = 0.045 },
      { x = 148, z = 470, width = 32, depth = 70, bottomDepth = 155, alpha = 0.035 },
      { x = 160, z = 875, width = 48, depth = 96, bottomDepth = 220, alpha = 0.025 },
      { x = 245, z = 1160, width = 30, depth = 64, bottomDepth = 155, alpha = 0.04 },
    },

    fishSchools = {
      { seed = 3101, x = 150, z = 195, depth = 62, count = 9, radius = 72, speed = 0.34 },
      { seed = 3102, x = 170, z = 505, depth = 88, count = 12, radius = 82, speed = 0.28 },
      { seed = 3103, x = 160, z = 870, depth = 142, count = 11, radius = 92, speed = 0.22 },
      { seed = 3104, x = 155, z = 1185, depth = 78, count = 10, radius = 76, speed = 0.31 },
    },
  },
}
