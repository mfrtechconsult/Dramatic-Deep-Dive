-- Dramatic Deep Dive authored 3D swim volumes.
-- Coordinates are movement cells; depth values are world pixels below water.
return {
  route19_reef_passage = {
    mapId = "DDD_ROUTE19_REEF_PASSAGE", zoneId = "route19_reef_passage",
    surfaceHeight = 480, minDepth = 24, defaultDepth = 90,
    defaultFloorDepth = 420, seabedClearance = 8,
    swimVolumes = { { id = "route19_open_reef", left = 2, top = 2, right = 93, bottom = 45 } },
    depthZones = {
      { id = "route19_west_reef", left = 2, top = 2, right = 31, bottom = 45, floorDepth = 210 },
      { id = "route19_mid_trench", left = 32, top = 2, right = 63, bottom = 45, floorDepth = 395 },
      { id = "route19_east_reef", left = 64, top = 2, right = 93, bottom = 45, floorDepth = 230 },
    },
    surfaceZones = {
      { id = "route19_west_surface", left = 34, top = 20, right = 37, bottom = 23 },
      { id = "route19_east_surface", left = 58, top = 20, right = 61, bottom = 23 },
    },
  },

  route20_seafloor = {
    mapId = "DDD_ROUTE20_SEAFLOOR", zoneId = "route20_seafoam",
    surfaceHeight = 640, minDepth = 28, defaultDepth = 110,
    defaultFloorDepth = 560, seabedClearance = 10,
    swimVolumes = { { id = "route20_open_sea", left = 2, top = 2, right = 157, bottom = 61 } },
    depthZones = {
      { id = "route20_west_garden", left = 2, top = 2, right = 55, bottom = 59, floorDepth = 240 },
      { id = "route20_west_drop", left = 56, top = 2, right = 75, bottom = 61, floorDepth = 370 },
      { id = "route20_seafoam_rift", left = 76, top = 2, right = 95, bottom = 61, floorDepth = 535 },
      { id = "route20_east_drop", left = 96, top = 2, right = 115, bottom = 61, floorDepth = 410 },
      { id = "route20_east_basin", left = 116, top = 2, right = 157, bottom = 59, floorDepth = 280 },
    },
    surfaceZones = {
      { id = "route20_west_surface", left = 18, top = 26, right = 51, bottom = 35 },
      { id = "route20_seafoam_surface", left = 74, top = 30, right = 85, bottom = 33 },
      { id = "route20_east_surface", left = 108, top = 26, right = 141, bottom = 35 },
    },
  },

  seafoam_sunken_cave = {
    mapId = "DDD_SEAFOAM_SUNKEN_CAVE", zoneId = "route20_seafoam",
    surfaceHeight = 560, minDepth = 40, defaultDepth = 120,
    defaultFloorDepth = 500, seabedClearance = 9,
    swimVolumes = { { id = "seafoam_cavern", left = 2, top = 2, right = 61, bottom = 45 } },
    depthZones = {
      { id = "seafoam_entry_ledge", left = 2, top = 2, right = 23, bottom = 19, floorDepth = 240 },
      { id = "seafoam_frozen_gallery", left = 24, top = 2, right = 61, bottom = 27, floorDepth = 350 },
      { id = "seafoam_blue_hole", left = 14, top = 28, right = 49, bottom = 45, floorDepth = 480 },
    },
    surfaceZones = {},
  },

  route21_abyss = {
    mapId = "DDD_ROUTE21_ABYSS", zoneId = "route21_abyss",
    surfaceHeight = 760, minDepth = 30, defaultDepth = 120,
    defaultFloorDepth = 680, seabedClearance = 12,
    swimVolumes = { { id = "route21_full_water_column", left = 0, top = 0, right = 79, bottom = 119 } },
    depthZones = {
      { id = "route21_north_shelf", left = 0, top = 0, right = 79, bottom = 23, floorDepth = 230 },
      { id = "route21_north_drop", left = 0, top = 24, right = 79, bottom = 39, floorDepth = 390 },
      { id = "route21_west_wall", left = 0, top = 40, right = 23, bottom = 79, floorDepth = 470 },
      { id = "route21_central_trench", left = 24, top = 40, right = 55, bottom = 79, floorDepth = 650 },
      { id = "route21_east_wall", left = 56, top = 40, right = 79, bottom = 79, floorDepth = 470 },
      { id = "route21_south_rise", left = 0, top = 80, right = 79, bottom = 95, floorDepth = 400 },
      { id = "route21_south_shelf", left = 0, top = 96, right = 79, bottom = 119, floorDepth = 250 },
    },
    surfaceZones = {
      { id = "route21_north_surface", left = 34, top = 14, right = 45, bottom = 31 },
      { id = "route21_central_surface", left = 33, top = 50, right = 46, bottom = 71 },
      { id = "route21_south_surface", left = 34, top = 94, right = 45, bottom = 111 },
    },
  },
}
