local function fail(message)
  io.stderr:write("[scene validation] " .. tostring(message) .. "\n")
  os.exit(1)
end

local function check(condition, message)
  if not condition then fail(message) end
end

local volumes = dofile("dramatic_deep_dive/data/volumes.lua")
local scenes = dofile("dramatic_deep_dive/data/scenes.lua")
local map = dofile("dramatic_deep_dive/maps/DDD_ROUTE21_ABYSS.lua")

local volume = volumes.route21_abyss
local scene = scenes.route21_abyss
check(volume ~= nil, "route21_abyss volume missing")
check(scene ~= nil, "route21_abyss scene missing")
check(scene.mapId == map.id, "scene map id does not match map")
check(volume.mapId == map.id, "volume map id does not match map")

local worldWidth = map.width * 2 * 16
local worldDepth = map.height * 2 * 16
check(worldWidth == 320, "Route 21 world width should remain 320 pixels")
check(worldDepth == 1440, "Route 21 world depth should remain 1440 pixels")
check(volume.defaultFloorDepth >= 220, "central abyss is not deep enough")
check(volume.defaultFloorDepth - volume.seabedClearance >= 210,
  "usable abyss depth fell below 210")

local previousEnd = 0
for index, district in ipairs(scene.districts or {}) do
  check(district.z0 == previousEnd,
    string.format("district %d does not start where previous one ended", index))
  check(district.z1 > district.z0, "district has invalid range")
  previousEnd = district.z1
end
check(previousEnd == worldDepth, "districts do not cover the complete Route 21 map")

local function pointInWorld(label, x, z)
  check(type(x) == "number" and type(z) == "number", label .. " has invalid position")
  check(x >= 0 and x <= worldWidth, label .. " x outside map")
  check(z >= 0 and z <= worldDepth, label .. " z outside map")
end

for index, structure in ipairs(scene.structures or {}) do
  pointInWorld("structure " .. index, structure.x, structure.z)
end

for index, spec in ipairs(scene.scatter or {}) do
  pointInWorld("scatter " .. index .. " minimum", spec.x0, spec.z0)
  pointInWorld("scatter " .. index .. " maximum", spec.x1, spec.z1)
  check((spec.count or 0) > 0, "scatter has no instances")
end

for index, cluster in ipairs(scene.crystalClusters or {}) do
  pointInWorld("crystal cluster " .. index, cluster.x, cluster.z)
end
for index, vent in ipairs(scene.bubbleVents or {}) do
  pointInWorld("bubble vent " .. index, vent.x, vent.z)
  check((vent.height or 0) > 0 and (vent.speed or 0) > 0, "invalid bubble vent")
end
for index, shaft in ipairs(scene.lightShafts or {}) do
  pointInWorld("light shaft " .. index, shaft.x, shaft.z)
  check((shaft.bottomDepth or 0) > volume.minDepth, "light shaft is too shallow")
end
for index, school in ipairs(scene.fishSchools or {}) do
  pointInWorld("fish school " .. index, school.x, school.z)
  check((school.count or 0) > 0 and (school.radius or 0) > 0, "invalid fish school")
  check((school.depth or 0) >= volume.minDepth, "fish school above swim column")
  check((school.depth or 0) <= volume.defaultFloorDepth, "fish school below abyss floor")
end

print(string.format(
  "Route 21 scene OK: %d structures, %d scatter groups, %d bubble vents, %d fish schools",
  #(scene.structures or {}), #(scene.scatter or {}),
  #(scene.bubbleVents or {}), #(scene.fishSchools or {})))
