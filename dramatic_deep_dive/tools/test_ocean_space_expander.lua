-- Contract: surface Kanto stays unchanged while underwater ocean topology can
-- expand horizontally. Open ocean uses x3 scale (9x navigation area), DIVE
-- lands near the center of the corresponding underwater patch, and SURFACE
-- maps any point in that patch back to the original surface cell.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

local mapRegistry = {}
function mapRegistry:get(id) return self[id] end

local mod = { content = { maps = mapRegistry }, log = nil }
local atlasEntry = {
  id = "ROUTE_19",
  underwaterMapId = "DDD_SEABED_ROUTE_19",
  def = { width = 2, height = 2 },
  width = 4,
  height = 4,
  water = {},
  surfaceWater = {},
  floorDepth = {},
  waterCount = 16,
  profile = { spaceScale = 3 },
  profileName = "ocean",
}
for y = 0, 3 do
  for x = 0, 3 do
    atlasEntry.water[key(x, y)] = true
    atlasEntry.surfaceWater[key(x, y)] = true
    atlasEntry.floorDepth[key(x, y)] = 240
  end
end

local atlas = {
  stats = {},
  mapIds = function() return { "ROUTE_19" } end,
  surface = function(_, id) if id == "ROUTE_19" then return atlasEntry end end,
}

local map = {
  id = atlasEntry.underwaterMapId,
  width = 2, height = 2,
  blocks = { 31, 31, 31, 31 },
  connections = {},
}
mapRegistry[map.id] = map

local generated = {
  maps = { map },
  volumes = {
    ["atlas:ROUTE_19"] = {
      cellRuns = {}, depthRuns = {}, surfaceRuns = {},
      widthCells = 4, heightCells = 4,
      connectedEdgeCells = {},
    },
  },
  dives = {
    ["atlas:ROUTE_19"] = {
      links = {
        {
          id = "row1",
          surface = { mapId = "ROUTE_19", x = 0, y = 1 },
          underwater = { mapId = atlasEntry.underwaterMapId, x = 0, y = 1 },
          width = 4, height = 1,
        },
      },
    },
  },
  scenes = {
    ["atlas:ROUTE_19"] = {
      districts = { { x0 = 0, x1 = 64, z0 = 0, z1 = 64 } },
      structures = { { x = 24, z = 24 } },
      scatter = { { x0 = 8, x1 = 56, z0 = 8, z1 = 56, count = 10 } },
      crystalClusters = {}, bubbleVents = {}, lightShafts = {}, fishSchools = {},
    },
  },
  salvage = {
    [atlasEntry.underwaterMapId] = { { id = "test", x = 24, z = 24 } },
  },
}

local Expander = dofile(root .. "/src/OceanSpaceExpander.lua")
local expander = Expander.new(mod, atlas)
expander:expandTopology(generated)

assert(atlasEntry.underwaterScale == 3, "ocean profile must use x3 scale")
assert(map.width == 6 and map.height == 6,
  "2x2-block surface map must become 6x6 blocks underwater")
assert(#map.blocks == 36, "expanded map block count must match expanded dimensions")

local volume = generated.volumes["atlas:ROUTE_19"]
assert(volume.widthCells == 12 and volume.heightCells == 12,
  "4x4 surface movement cells must become 12x12 underwater cells")
local swimCells = 0
for _, row in pairs(volume.cellRuns) do
  for _, run in ipairs(row) do swimCells = swimCells + run.x1 - run.x0 + 1 end
end
assert(swimCells == 144, "x3 horizontal scaling must create 9x navigation area")

local zone = generated.dives["atlas:ROUTE_19"]
assert(zone.links[1].scale == 3, "generated DIVE link must retain x3 mapping metadata")
assert(zone.links[1].underwater.y == 3, "underwater row origin must be scaled")
assert(zone.links[1].underwaterWidth == 12 and zone.links[1].underwaterHeight == 3,
  "surface row must own the complete scaled underwater strip")

local travel = { zones = { test = zone } }
expander:patchTravel(travel)
local diveTarget = assert(travel:diveTarget({ mapId = "ROUTE_19", x = 2, y = 1, facing = "down" }))
assert(diveTarget.x == 7 and diveTarget.y == 4,
  "DIVE should land in the center of the source cell's 3x3 underwater patch")
local surfaceTarget = assert(travel:surfaceTarget({
  mapId = atlasEntry.underwaterMapId, x = 8, y = 5, facing = "up",
}))
assert(surfaceTarget.x == 2 and surfaceTarget.y == 1,
  "any point inside a 3x3 patch must map back to its original surface cell")

local portals = {
  portals = {
    [atlasEntry.underwaterMapId .. ":2:1"] = {
      sourceMap = atlasEntry.underwaterMapId, sourceX = 2, sourceY = 1,
      destMap = atlasEntry.underwaterMapId, destX = 1, destY = 2,
    },
  },
}
expander:expandPresentation(generated, portals)
local scene = generated.scenes["atlas:ROUTE_19"]
assert(scene.structures[1].x == 72 and scene.structures[1].z == 72,
  "surface-aware landmarks must move outward with the enlarged ocean")
assert(scene.scatter[1].count == 30,
  "decor population should grow linearly while area grows quadratically")
assert(generated.salvage[atlasEntry.underwaterMapId][1].x == 72,
  "salvage coordinates must stay aligned with the expanded world")
assert(portals.portals[atlasEntry.underwaterMapId .. ":7:4"],
  "submerged portal trigger must move to the scaled cell center")

local stats = expander:stats()
assert(stats.originalSeabedCells == 16 and stats.expandedSeabedCells == 144,
  "space stats must report 9x open-ocean swim area")

print("Ocean space expander OK: x3 open sea = 9x swim area with reversible DIVE mapping")
