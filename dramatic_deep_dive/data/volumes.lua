-- Authored underwater volumes. Coordinates use Gen1Recomp cell coordinates.
-- The first playable proof of concept follows Kanto Dive's two Route 19 links.
return {
  route19_reef_passage = {
    mapId = "KD_ROUTE19_REEF_PASSAGE",
    zoneId = "route19_reef_passage",

    -- World-space distance between the seafloor plane and the water surface.
    surfaceHeight = 96,
    minDepth = 28,
    defaultDepth = 40,
    defaultFloorDepth = 92,
    seabedClearance = 3,

    swimVolumes = {
      { id = "route19_main", left = 2, top = 2, right = 17, bottom = 5 },
    },

    -- Shallower shelves around each DIVE landing make the seafloor collision
    -- rise naturally before the central reef channel drops away.
    depthZones = {
      { id = "route19_west_shelf", left = 2, top = 2, right = 5, bottom = 5, floorDepth = 64 },
      { id = "route19_channel", left = 6, top = 2, right = 13, bottom = 5, floorDepth = 92 },
      { id = "route19_east_shelf", left = 14, top = 2, right = 17, bottom = 5, floorDepth = 64 },
    },

    -- These mirror Kanto Dive's route19_reef_west/east authored links.
    -- Reaching shallow water here does not auto-warp: Kanto Dive remains the
    -- authority for the SURFACE field move and progression checks.
    surfaceZones = {
      { id = "route19_west_surface", left = 2, top = 2, right = 5, bottom = 5 },
      { id = "route19_east_surface", left = 14, top = 2, right = 17, bottom = 5 },
    },
  },
}
