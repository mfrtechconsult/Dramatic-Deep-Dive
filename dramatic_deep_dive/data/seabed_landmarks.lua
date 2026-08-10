-- Data-driven landmark identity layered on top of generated Kanto seabeds.
-- These rules never define water coverage: KantoWaterAtlas remains the source
-- of truth. Landmarks only decorate valid generated water cells.
return {
  defaults = {
    coastal = { shoreStructures = 5, deepStructures = 2 },
    ocean = { shoreStructures = 3, deepStructures = 5 },
    harbor = { shoreStructures = 14, deepStructures = 4 },
    volcanic = { shoreStructures = 4, deepStructures = 8 },
    cave = { shoreStructures = 4, deepStructures = 7 },
    freshwater = { shoreStructures = 4, deepStructures = 2 },
    marsh = { shoreStructures = 5, deepStructures = 1 },
  },

  maps = {
    VERMILION_CITY = {
      name = "VERMILION HARBOR",
      type = "harbor",
      shoreStructures = 18,
      deepStructures = 5,
      anchors = 3,
    },
    VERMILION_DOCK = {
      name = "VERMILION DOCKS",
      type = "harbor",
      shoreStructures = 22,
      deepStructures = 4,
      anchors = 4,
    },
    CINNABAR_ISLAND = {
      name = "CINNABAR VOLCANIC SHELF",
      type = "volcanic",
      shoreStructures = 5,
      deepStructures = 11,
      vents = 6,
    },
    PALLET_TOWN = {
      name = "PALLET COAST",
      type = "coastal",
      shoreStructures = 4,
      deepStructures = 1,
    },
    ROUTE_19 = {
      name = "ROUTE 19 OPEN SEA",
      type = "ocean",
      deepStructures = 7,
    },
    ROUTE_20 = {
      name = "ROUTE 20 OPEN SEA",
      type = "ocean",
      deepStructures = 9,
    },
    ROUTE_21 = {
      name = "ROUTE 21 OPEN SEA",
      type = "ocean",
      deepStructures = 8,
    },
  },

  patterns = {
    {
      find = "SEAFOAM_ISLANDS",
      name = "SEAFOAM SUBMERGED CAVES",
      type = "cave",
      deepStructures = 9,
      iceColumns = 12,
    },
    {
      find = "SAFARI_ZONE",
      name = "SAFARI WETLANDS",
      type = "marsh",
      shoreStructures = 7,
    },
    {
      find = "VERMILION",
      name = "VERMILION WATERS",
      type = "harbor",
      anchors = 2,
    },
    {
      find = "CINNABAR",
      name = "CINNABAR WATERS",
      type = "volcanic",
      vents = 4,
    },
  },
}
