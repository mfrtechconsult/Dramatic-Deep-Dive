-- Headless synthetic contract test for the generated Kanto seabed architecture.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

package.preload["src.world.Map"] = function()
  return {
    defIsWaterCell = function(def, _tileset, x, y)
      return def._water and def._water[key(x, y)] == true or false
    end,
  }
end

local function registry(base)
  local added = {}
  return {
    get = function(_, id) return added[id] or base[id] end,
    register = function(_, id, value) assert(not added[id]); added[id] = value; return value end,
    each = function()
      local ids = {}
      for id in pairs(base) do ids[#ids + 1] = id end
      table.sort(ids)
      local i = 0
      return function()
        i = i + 1
        local id = ids[i]
        if not id then return nil end
        return id, base[id]
      end
    end,
    _added = added,
  }
end

local function waterRect(width, height)
  local out = {}
  for y = 0, height - 1 do
    for x = 0, width - 1 do out[key(x, y)] = true end
  end
  return out
end

local mapsBase = {
  ROUTE_TEST_A = {
    id = "ROUTE_TEST_A", index = 1, tileset = "OVERWORLD", width = 2, height = 2,
    connections = { east = { map = "ROUTE_TEST_B", offset = 0 } },
    _water = waterRect(4, 4),
  },
  ROUTE_TEST_B = {
    id = "ROUTE_TEST_B", index = 2, tileset = "OVERWORLD", width = 2, height = 2,
    connections = { west = { map = "ROUTE_TEST_A", offset = 0 } },
    _water = waterRect(4, 4),
  },
}
-- Keep some non-water coast inside each map and deliberately break one cell
-- of the east/west border pair. A map connection must not visually open the
-- whole edge when only some of its water cells actually connect.
mapsBase.ROUTE_TEST_A._water[key(0, 0)] = nil
mapsBase.ROUTE_TEST_A._water[key(0, 1)] = nil
mapsBase.ROUTE_TEST_B._water[key(3, 2)] = nil
mapsBase.ROUTE_TEST_B._water[key(3, 3)] = nil
mapsBase.ROUTE_TEST_B._water[key(0, 0)] = nil

local maps = registry(mapsBase)
local tilesets = registry({ OVERWORLD = { id = "OVERWORLD", waterTiles = { 0x14 } } })
local songs = { register = function() return true end }
local encounters = registry({})
local field = { get = function(_, id) if id == "waterTilesets" then return { "OVERWORLD" } end end }
local mod = { content = { maps = maps, tilesets = tilesets, map_songs = songs, encounters = encounters, field = field } }

local profiles = dofile(root .. "/data/seabed_profiles.lua")
local Atlas = dofile(root .. "/src/KantoWaterAtlas.lua")
local Generator = dofile(root .. "/src/SeabedGenerator.lua")
local VolumeRegistry = dofile(root .. "/src/VolumeRegistry.lua")

local atlas = Atlas.new(mod, profiles):build()
assert(atlas.stats.maps == 2, "two water maps should be scanned")
assert(atlas.stats.waterCells == 27, "all synthetic water cells should be counted")
assert(atlas.stats.components == 1, "the east/west seam should make one connected water body")
assert(atlas.stats.seams == 1, "reciprocal map edges should count as one underwater seam")
assert(atlas:surface("ROUTE_TEST_A").seams.east.waterCells == 3, "only three east edge cells connect")
assert(atlas:surface("ROUTE_TEST_B").seams.west.waterCells == 3, "reciprocal partial seam should match")
local seamA = atlas:surface("ROUTE_TEST_A").floorDepth[key(3, 2)]
local seamB = atlas:surface("ROUTE_TEST_B").floorDepth[key(0, 2)]
assert(seamA == seamB, "connected maps must reconcile seabed depth at the seam")

local generated = Generator.new(mod, atlas, profiles):build()
local mapA = maps._added.DDD_SEABED_ROUTE_TEST_A
local mapB = maps._added.DDD_SEABED_ROUTE_TEST_B
assert(mapA and mapB, "generator must register one underwater map per water map")
assert(mapA.connections.east.map == mapB.id, "underwater east seam must target generated neighbor")
assert(mapB.connections.west.map == mapA.id, "underwater west seam must be reciprocal")
assert(#mapA.blocks == mapA.width * mapA.height, "generated block count must match dimensions")
for _, block in ipairs(mapA.blocks) do assert(block >= 16 and block <= 31, "mask blocks must stay in 16..31") end

local volumeA = generated.volumes["atlas:ROUTE_TEST_A"]
assert(volumeA.connectedEdgeCells.east[key(3, 1)] == true,
  "an actual water-to-water border cell must stay open")
assert(volumeA.connectedEdgeCells.east[key(3, 0)] ~= true,
  "an unmatched water border cell must remain visually closed")

local volumes = VolumeRegistry.new({})
for id, definition in pairs(generated.volumes) do
  local volume, err = volumes:register(id, definition, "test")
  assert(volume, err)
end
local registeredA = volumes:get("atlas:ROUTE_TEST_A")
assert(registeredA.connectedEdgeCells.east[key(3, 1)] == true,
  "registered volume must preserve an exact connected edge cell")
assert(registeredA.connectedEdgeCells.east[key(3, 0)] ~= true,
  "registered volume must preserve a closed unmatched edge cell")
assert(volumes:contains(mapA.id, 1, 1), "water cell must be swimmable")
assert(not volumes:contains(mapA.id, 0, 0), "surface land cell must stay solid underwater")
local near = volumes:floorDepthAt(mapA.id, 1, 0)
local center = volumes:floorDepthAt(mapA.id, 2, 2)
assert(near and center, "generated cells need floor depths")
assert(center >= near, "depth must not get shallower toward interior water")

local zone = generated.dives["atlas:ROUTE_TEST_A"]
local covered = 0
for _, link in ipairs(zone.links) do covered = covered + link.width * link.height end
assert(covered == 14, "DIVE row-runs must cover every surface water cell exactly once")

print(string.format(
  "Kanto water atlas OK: %d maps, %d water cells, %d component, %d seam",
  atlas.stats.maps, atlas.stats.waterCells, atlas.stats.components, atlas.stats.seams))
