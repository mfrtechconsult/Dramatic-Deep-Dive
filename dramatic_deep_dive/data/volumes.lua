-- Dramatic Deep Dive authored 3D swim volumes.
-- Coordinates are Gen1Recomp movement cells; depth values are world pixels
-- measured downward from the water surface.
return {
  route21_abyss = {
    mapId = "DDD_ROUTE21_ABYSS",
    zoneId = "route21_abyss",

    -- This is intentionally much deeper than the Route 19 prototype. The
    -- central trench gives more than 200 world pixels of usable vertical room.
    surfaceHeight = 256,
    minDepth = 24,
    defaultDepth = 64,
    defaultFloorDepth = 228,
    seabedClearance = 6,

    swimVolumes = {
      { id = "route21_full_water_column", left = 0, top = 0, right = 19, bottom = 89 },
    },

    -- defaultFloorDepth is the deepest abyss. These non-overlapping zones
    -- raise shelves and shoulders above it, producing a canyon instead of a
    -- single flat underwater plane.
    depthZones = {
      { id = "route21_north_shelf", left = 0, top = 0, right = 19, bottom = 17, floorDepth = 96 },
      { id = "route21_north_drop", left = 0, top = 18, right = 19, bottom = 29, floorDepth = 140 },
      { id = "route21_west_wall", left = 0, top = 30, right = 4, bottom = 59, floorDepth = 168 },
      { id = "route21_east_wall", left = 15, top = 30, right = 19, bottom = 59, floorDepth = 168 },
      { id = "route21_south_rise", left = 0, top = 60, right = 19, bottom = 71, floorDepth = 160 },
      { id = "route21_south_shelf", left = 0, top = 72, right = 19, bottom = 89, floorDepth = 108 },
    },

    -- Three broad SURFACE windows mirror the proven Route 21 link layout.
    surfaceZones = {
      { id = "route21_north_surface", left = 4, top = 8, right = 15, bottom = 25 },
      { id = "route21_central_surface", left = 3, top = 34, right = 16, bottom = 55 },
      { id = "route21_south_surface", left = 4, top = 66, right = 15, bottom = 83 },
    },
  },
}
