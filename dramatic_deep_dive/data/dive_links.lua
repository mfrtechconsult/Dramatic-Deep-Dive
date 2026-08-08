-- Standalone DIVE/SURFACE links owned by Dramatic Deep Dive.
-- The Route 21 coordinates are intentionally based on the proven Kanto Dive
-- layout while the underwater destination is now a DDD-owned map.
return {
  route21_abyss = {
    requiredBadge = "VOLCANOBADGE",
    underwaterMapId = "DDD_ROUTE21_ABYSS",
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
