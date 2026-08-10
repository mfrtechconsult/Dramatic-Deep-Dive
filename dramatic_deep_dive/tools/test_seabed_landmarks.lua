-- Headless contract test for surface-aware generated landmark identity.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

local function makeEntry(id, profileName)
  local width, height = 16, 12
  local water, shoreDistance, floorDepth = {}, {}, {}
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      local k = key(x, y)
      local d = math.min(x, y, width - 1 - x, height - 1 - y)
      water[k] = true
      shoreDistance[k] = d
      floorDepth[k] = 100 + d * 36
    end
  end
  return {
    id = id,
    width = width,
    height = height,
    water = water,
    waterCount = width * height,
    shoreDistance = shoreDistance,
    floorDepth = floorDepth,
    profileName = profileName,
    profile = { maxFloor = 600 },
  }
end

local entries = {
  VERMILION_CITY = makeEntry("VERMILION_CITY", "harbor"),
  CINNABAR_ISLAND = makeEntry("CINNABAR_ISLAND", "volcanic"),
  SEAFOAM_ISLANDS_1F = makeEntry("SEAFOAM_ISLANDS_1F", "cave"),
}

local atlas = {
  mapIds = function() return { "CINNABAR_ISLAND", "SEAFOAM_ISLANDS_1F", "VERMILION_CITY" } end,
  surface = function(_, id) return entries[id] end,
}

local scenes = {}
for id in pairs(entries) do
  scenes["atlas:" .. id] = {
    id = "atlas_scene:" .. id,
    mapId = "DDD_SEABED_" .. id,
    districts = {}, structures = {}, scatter = {}, crystalClusters = {},
    bubbleVents = {}, lightShafts = {}, fishSchools = {},
  }
end

local rules = dofile(root .. "/data/seabed_landmarks.lua")
local Landmarks = dofile(root .. "/src/SeabedLandmarks.lua")
local mod = { log = { info = function() end } }
local pass = Landmarks.new(mod, atlas, rules)
assert(pass:apply(scenes) == 3, "all synthetic landmark maps should be processed")

local vermilion = scenes["atlas:VERMILION_CITY"]
local cinnabar = scenes["atlas:CINNABAR_ISLAND"]
local seafoam = scenes["atlas:SEAFOAM_ISLANDS_1F"]

assert(#vermilion.structures >= 10, "Vermilion should receive a substantial harbor structure set")
assert(#cinnabar.bubbleVents >= 3, "Cinnabar should receive multiple thermal vents")
assert(#seafoam.crystalClusters >= 1, "Seafoam should receive ice/crystal clusters")

local foundHarborColumn, foundVolcanicSpire, foundIce = false, false, false
for _, s in ipairs(vermilion.structures) do
  if s.kind == "column_ring" then foundHarborColumn = true end
end
for _, s in ipairs(cinnabar.structures) do
  if s.kind == "spire" and s.material == "darkStone" then foundVolcanicSpire = true end
end
for _, s in ipairs(seafoam.structures) do
  if s.kind == "spire" and s.material == "crystal" then foundIce = true end
end
assert(foundHarborColumn, "Vermilion needs generated dock-support columns")
assert(foundVolcanicSpire, "Cinnabar needs dark volcanic spires")
assert(foundIce, "Seafoam needs crystal/ice vertical formations")

-- Every structure anchor must still be located on an atlas water cell.
for id, entry in pairs(entries) do
  local scene = scenes["atlas:" .. id]
  for _, s in ipairs(scene.structures) do
    local x = math.floor((s.x or 0) / 16)
    local y = math.floor((s.z or 0) / 16)
    assert(entry.water[key(x, y)] == true,
      string.format("%s structure escaped the source water mask at %d,%d", id, x, y))
  end
end

print(string.format(
  "Seabed landmarks OK: Vermilion=%d structures, Cinnabar=%d structures/%d vents, Seafoam=%d structures/%d crystal clusters",
  #vermilion.structures,
  #cinnabar.structures, #cinnabar.bubbleVents,
  #seafoam.structures, #seafoam.crystalClusters))
