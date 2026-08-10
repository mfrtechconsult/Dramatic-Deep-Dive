-- Headless contract test for surface warp/object -> seabed landmark anchors.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

local function fullWaterEntry(id, profileName, width, height)
  local water, shoreDistance, floorDepth = {}, {}, {}
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      local k = key(x, y)
      local d = math.min(x, y, width - 1 - x, height - 1 - y)
      water[k] = true
      shoreDistance[k] = d
      floorDepth[k] = 100 + d * 20
    end
  end
  return {
    id = id,
    profileName = profileName,
    width = width,
    height = height,
    water = water,
    shoreDistance = shoreDistance,
    floorDepth = floorDepth,
    def = { warps = {}, objects = {} },
  }
end

local vermilion = fullWaterEntry("VERMILION_CITY", "harbor", 40, 36)
vermilion.def.warps = {
  { x = 18, y = 31, destMap = "VERMILION_DOCK" },
  { x = 12, y = 19, destMap = "VERMILION_GYM" },
}

local seafoam = fullWaterEntry("SEAFOAM_ISLANDS_1F", "cave", 32, 20)
seafoam.def.warps = {
  { x = 4, y = 17, destMap = "LAST_MAP" },
  { x = 7, y = 5, destMap = "SEAFOAM_ISLANDS_B1F" },
}
seafoam.def.objects = {
  { x = 18, y = 10, sprite = "SPRITE_BOULDER" },
}

local entries = { VERMILION_CITY = vermilion, SEAFOAM_ISLANDS_1F = seafoam }
local atlas = {
  mapIds = function() return { "SEAFOAM_ISLANDS_1F", "VERMILION_CITY" } end,
  surface = function(_, id) return entries[id] end,
}

local scenes = {
  ["atlas:VERMILION_CITY"] = {
    structures = {}, crystalClusters = {}, bubbleVents = {},
  },
  ["atlas:SEAFOAM_ISLANDS_1F"] = {
    structures = {}, crystalClusters = {}, bubbleVents = {},
  },
}

local Anchors = dofile(root .. "/src/SurfaceLandmarkAnchors.lua")
local mod = { log = { info = function() end } }
local pass = Anchors.new(mod, atlas)
local maps, count = pass:apply(scenes)
assert(maps == 2, "both synthetic maps should receive surface-linked anchors")
assert(count >= 6, "surface anchor pass should create multiple linked structures")

local harborColumns = 0
for _, s in ipairs(scenes["atlas:VERMILION_CITY"].structures) do
  if s.kind == "column_ring" then harborColumns = harborColumns + 1 end
end
assert(harborColumns >= 2, "Vermilion dock warp should create paired support columns")

local caveArches = 0
for _, s in ipairs(scenes["atlas:SEAFOAM_ISLANDS_1F"].structures) do
  if s.kind == "rock_arch" then caveArches = caveArches + 1 end
end
assert(caveArches >= 2, "Seafoam external/internal warps should create cave-mouth anchors")
assert(#scenes["atlas:SEAFOAM_ISLANDS_1F"].bubbleVents >= 1,
  "Seafoam boulder should create a subtle submerged shaft/bubble cue")

for id, entry in pairs(entries) do
  for _, s in ipairs(scenes["atlas:" .. id].structures) do
    local x, y = math.floor((s.x or 0) / 16), math.floor((s.z or 0) / 16)
    -- Support pairs may offset by less than one cell around their snapped water anchor.
    assert(x >= 0 and y >= 0 and x < entry.width and y < entry.height,
      string.format("%s anchor escaped map bounds", id))
  end
end

print(string.format("Surface landmark anchors OK: %d maps, %d generated anchors", maps, count))
