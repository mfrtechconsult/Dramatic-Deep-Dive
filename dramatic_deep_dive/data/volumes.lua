-- Dramatic Deep Dive authored 3D swim volumes.
-- Coordinates are Gen1Recomp movement cells; depths are world pixels below water.
return {
  route19_reef_passage = {
    mapId = "DDD_ROUTE19_REEF_PASSAGE",
    zoneId = "route19_reef_passage",
    surfaceHeight = 200,
    minDepth = 20,
    defaultDepth = 48,
    defaultFloorDepth = 155,
    seabedClearance = 5,
    swimVolumes = {
      { id = "route19_reef_corridor", left = 2, top = 2, right = 17, bottom = 5 },
    },
    depthZones = {
      { id = "route19_west_reef", left = 2, top = 2, right = 5, bottom = 5, floorDepth = 82 },
      { id = "route19_mid_channel", left = 6, top = 2, right = 13, bottom = 5, floorDepth = 145 },
      { id = "route19_east_reef", left = 14, top = 2, right = 17, bottom = 5, floorDepth = 86 },
    },
    surfaceZones = {
      { id = "route19_west_surface", left = 2, top = 2, right = 5, bottom = 5 },
      { id = "route19_east_surface", left = 14, top = 2, right = 17, bottom = 5 },
    },
  },

  route20_seafloor = {
    mapId = "DDD_ROUTE20_SEAFLOOR",
    zoneId = "route20_seafoam",
    surfaceHeight = 300,
    minDepth = 24,
    defaultDepth = 62,
    defaultFloorDepth = 260,
    seabedClearance = 7,
    swimVolumes = {
      { id = "route20_open_sea", left = 2, top = 2, right = 97, bottom = 15 },
    },
    depthZones = {
      { id = "route20_west_garden", left = 2, top = 2, right = 37, bottom = 13, floorDepth = 118 },
      { id = "route20_west_drop", left = 38, top = 2, right = 45, bottom = 15, floorDepth = 176 },
      { id = "route20_seafoam_rift", left = 46, top = 2, right = 58, bottom = 15, floorDepth = 252 },
      { id = "route20_east_drop", left = 59, top = 2, right = 65, bottom = 15, floorDepth = 198 },
      { id = "route20_east_basin", left = 66, top = 2, right = 97, bottom = 13, floorDepth = 146 },
    },
    surfaceZones = {
      { id = "route20_west_surface", left = 4, top = 4, right = 37, bottom = 13 },
      { id = "route20_seafoam_surface", left = 44, top = 12, right = 55, bottom = 15 },
      { id = "route20_east_surface", left = 62, top = 4, right = 95, bottom = 13 },
    },
  },

  seafoam_sunken_cave = {
    mapId = "DDD_SEAFOAM_SUNKEN_CAVE",
    zoneId = "route20_seafoam",
    surfaceHeight = 220,
    minDepth = 36,
    defaultDepth = 72,
    defaultFloorDepth = 194,
    seabedClearance = 6,
    swimVolumes = {
      { id = "seafoam_cavern", left = 2, top = 2, right = 17, bottom = 13 },
    },
    depthZones = {
      { id = "seafoam_entry_ledge", left = 2, top = 2, right = 7, bottom = 6, floorDepth = 118 },
      { id = "seafoam_frozen_gallery", left = 8, top = 2, right = 17, bottom = 7, floorDepth = 152 },
      { id = "seafoam_blue_hole", left = 5, top = 8, right = 14, bottom = 13, floorDepth = 190 },
    },
    surfaceZones = {},
  },

  route21_abyss = {
    mapId = "DDD_ROUTE21_ABYSS",
    zoneId = "route21_abyss",
    surfaceHeight = 256,
    minDepth = 24,
    defaultDepth = 64,
    defaultFloorDepth = 228,
    seabedClearance = 6,
    swimVolumes = {
      { id = "route21_full_water_column", left = 0, top = 0, right = 19, bottom = 89 },
    },
    depthZones = {
      { id = "route21_north_shelf", left = 0, top = 0, right = 19, bottom = 17, floorDepth = 96 },
      { id = "route21_north_drop", left = 0, top = 18, right = 19, bottom = 29, floorDepth = 140 },
      { id = "route21_west_wall", left = 0, top = 30, right = 4, bottom = 59, floorDepth = 168 },
      { id = "route21_east_wall", left = 15, top = 30, right = 19, bottom = 59, floorDepth = 168 },
      { id = "route21_south_rise", left = 0, top = 60, right = 19, bottom = 71, floorDepth = 160 },
      { id = "route21_south_shelf", left = 0, top = 72, right = 19, bottom = 89, floorDepth = 108 },
    },
    surfaceZones = {
      { id = "route21_north_surface", left = 4, top = 8, right = 15, bottom = 25 },
      { id = "route21_central_surface", left = 3, top = 34, right = 16, bottom = 55 },
      { id = "route21_south_surface", left = 4, top = 66, right = 15, bottom = 83 },
    },
  },
}
