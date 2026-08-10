local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."

local Markers = dofile(root .. "/src/SurfaceDiveMarkers.lua")
assert(Markers.drawFlat == nil, "full-Kanto mode must not expose the old flat dark-water renderer")
assert(Markers.drawProjected == nil, "full-Kanto mode must not expose the old projected dark-water renderer")
assert(Markers.redrawPlayerProjected == nil, "full-Kanto mode must not patch projected player redraw for a DIVE mask")

local SubmergedWarpLinks = dofile(root .. "/src/SubmergedWarpLinks.lua")

local function waterRect(x0, y0, x1, y1)
  local out = {}
  for y = y0, y1 do
    for x = x0, x1 do out[tostring(x) .. ":" .. tostring(y)] = true end
  end
  return out
end

local maps = {
  CAVE_A = {
    id = "CAVE_A", profileName = "cave", underwaterMapId = "DDD_SEABED_CAVE_A",
    water = waterRect(0, 0, 3, 3),
    def = { warps = { { x = 2, y = 2, destMap = "CAVE_B", destWarp = 1 } } },
  },
  CAVE_B = {
    id = "CAVE_B", profileName = "cave", underwaterMapId = "DDD_SEABED_CAVE_B",
    water = waterRect(0, 0, 3, 3),
    def = { warps = { { x = 1, y = 1, destMap = "CAVE_A", destWarp = 1 } } },
  },
  CITY_A = {
    id = "CITY_A", profileName = "freshwater", underwaterMapId = "DDD_SEABED_CITY_A",
    water = waterRect(0, 0, 3, 3),
    def = { warps = { { x = 1, y = 1, destMap = "CAVE_A", destWarp = 1 } } },
  },
}
local atlas = {
  mapIds = function() return { "CAVE_A", "CAVE_B", "CITY_A" } end,
  surface = function(_, id) return maps[id] end,
}
local scenes = {
  ["atlas:CAVE_A"] = { structures = {} },
  ["atlas:CAVE_B"] = { structures = {} },
  ["atlas:CITY_A"] = { structures = {} },
}
local logs = {}
local mod = { log = { info = function(_, fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end } }
local links = SubmergedWarpLinks.new(mod, atlas, scenes)
assert(links.count == 2, "reciprocal cave warps should create two directional underwater portals")
assert(links:portalAt("DDD_SEABED_CAVE_A", 2, 2), "source cave portal missing")
assert(links:portalAt("DDD_SEABED_CAVE_B", 1, 1), "destination cave portal missing")
assert(not links:portalAt("DDD_SEABED_CITY_A", 1, 1), "freshwater-to-cave surface door must not become an underwater portal")
assert(#scenes["atlas:CAVE_A"].structures >= 1, "underwater cave portal should receive a visible arch")

print("Full-Kanto mode OK: no surface mask, cave/harbor portal contract valid")
