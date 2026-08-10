-- Contract: bridges, docks and pontoons may be land/walkable on the surface
-- while the underwater hydrology remains continuous below them.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

package.preload["src.world.Map"] = function()
  return {
    defIsWaterCell = function(def, _tileset, x, y)
      return def._water and def._water[key(x, y)] == true or false
    end,
    defIsWalkableCell = function(def, _tileset, x, y)
      return def._walkable and def._walkable[key(x, y)] == true or false
    end,
    defCellTile = function(def, _tileset, x, y)
      return def._tiles and def._tiles[key(x, y)] or 0
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

local function makeStripMap(id, tileset, gapWalkable, shipPort)
  local def = {
    id = id, index = 1, tileset = tileset,
    width = 3, height = 2, connections = {},
    _water = {}, _walkable = {}, _tiles = {},
  }
  -- 6x4 movement cells. Two central columns are a surface structure; water
  -- exists to both sides. A bridge/pontoon should be open below, solid land
  -- should remain a real underwater divider.
  for y = 0, 3 do
    for x = 0, 5 do
      local k = key(x, y)
      if x == 2 or x == 3 then
        def._walkable[k] = gapWalkable == true
        def._tiles[k] = shipPort and 0x32 or 0x10
      else
        def._water[k] = true
        def._tiles[k] = 0x14
      end
    end
  end
  return def
end

local bridge = makeStripMap("BRIDGE_TEST", "OVERWORLD", true, false)
local solid = makeStripMap("SOLID_CAUSEWAY_TEST", "OVERWORLD", false, false)
local ship = makeStripMap("SHIP_PORT_TEST", "SHIP_PORT", false, true)

local maps = registry({
  BRIDGE_TEST = bridge,
  SOLID_CAUSEWAY_TEST = solid,
  SHIP_PORT_TEST = ship,
})
local tilesets = registry({
  OVERWORLD = { id = "OVERWORLD", waterTiles = { 0x14 } },
  SHIP_PORT = { id = "SHIP_PORT", waterTiles = { 0x14 } },
})
local songs = { register = function() return true end }
local encounters = registry({})
local field = { get = function(_, id)
  if id == "waterTilesets" then return { "OVERWORLD", "SHIP_PORT" } end
end }
local mod = {
  content = {
    maps = maps, tilesets = tilesets, map_songs = songs,
    encounters = encounters, field = field,
  },
}

local profiles = dofile(root .. "/data/seabed_profiles.lua")
local Atlas = dofile(root .. "/src/KantoWaterAtlas.lua")
local Generator = dofile(root .. "/src/SeabedGenerator.lua")
local VolumeRegistry = dofile(root .. "/src/VolumeRegistry.lua")
local Audit = dofile(root .. "/src/SeabedAudit.lua")

local atlas = Atlas.new(mod, profiles):build()
local bridgeEntry = assert(atlas:surface("BRIDGE_TEST"))
local solidEntry = assert(atlas:surface("SOLID_CAUSEWAY_TEST"))
local shipEntry = assert(atlas:surface("SHIP_PORT_TEST"))

assert(bridgeEntry.surfaceWaterCount == 16, "bridge test has sixteen real surface-water cells")
assert(bridgeEntry.underStructureCount == 8, "walkable two-cell bridge strip must infer water below")
assert(bridgeEntry.waterCount == 24, "bridge seabed must become one continuous 6x4 water body")
assert(not bridgeEntry.surfaceWater[key(2, 1)], "bridge surface itself must not become surfable water")
assert(bridgeEntry.water[key(2, 1)], "bridge cell must exist in underwater hydrology")
assert(bridgeEntry.underStructure[key(2, 1)], "bridge cell must be classified as under-structure water")

assert(solidEntry.underStructureCount == 0, "non-walkable land strip must not be inferred as a bridge")
assert(not solidEntry.water[key(2, 1)], "solid causeway must remain an underwater divider")

assert(shipEntry.underStructureCount == 8,
  "SHIP_PORT $32 boarding-platform cells must retain harbor water underneath")
assert(shipEntry.water[key(2, 1)], "S.S. Anne style dock platform must be swimmable underneath")
assert(not shipEntry.surfaceWater[key(2, 1)], "dock platform must stay non-water on the surface")

assert(atlas.stats.surfaceWaterCells == 48, "three maps expose forty-eight real surface-water cells")
assert(atlas.stats.underStructureCells == 16, "bridge + ship dock infer sixteen under-structure cells")
assert(atlas.stats.seabedCells == 64, "seabed total includes inferred under-structure water")

local generated = Generator.new(mod, atlas, profiles):build()
local bridgeZone = assert(generated.dives["atlas:BRIDGE_TEST"])
local diveCount = 0
for _, link in ipairs(bridgeZone.links) do diveCount = diveCount + link.width * link.height end
assert(diveCount == 16, "DIVE entry coverage must use real surface water only")
for _, link in ipairs(bridgeZone.links) do
  for dx = 0, link.width - 1 do
    local k = key(link.surface.x + dx, link.surface.y)
    assert(not bridgeEntry.underStructure[k], "DIVE must never be offered from a bridge/pontoon cell")
  end
end

local volumes = VolumeRegistry.new({})
for id, definition in pairs(generated.volumes) do
  local volume, err = volumes:register(id, definition, "test")
  assert(volume, err)
end
local bridgeMap = bridgeEntry.underwaterMapId
assert(volumes:contains(bridgeMap, 2, 1), "player must be able to swim under bridge cell")
local surfaceAllowed = volumes:isSurfaceZone(bridgeMap, 2, 1)
assert(surfaceAllowed == false, "player must not SURFACE through a bridge/pontoon")
assert(volumes:isSurfaceZone(bridgeMap, 1, 1) == true,
  "normal water beside the bridge must remain a valid SURFACE point")

local report = Audit.validate(atlas, generated)
if not report.ok then
  error("over-water hydrology audit failed: " .. table.concat(report.errors, " | "))
end
assert(report.diveCells == report.surfaceWaterCells,
  "audit must compare DIVE cells against real surface water")
assert(report.volumeCells == report.seabedCells,
  "audit must compare swim volume against the broader seabed hydrology")

print(string.format(
  "Over-water hydrology OK: %d surface cells + %d cells below structures = %d seabed cells",
  atlas.stats.surfaceWaterCells, atlas.stats.underStructureCells, atlas.stats.seabedCells))
