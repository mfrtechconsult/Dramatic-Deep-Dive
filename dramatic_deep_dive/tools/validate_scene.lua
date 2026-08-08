local function fail(message)
  io.stderr:write("[scene validation] " .. tostring(message) .. "\n")
  os.exit(1)
end

local function check(condition, message)
  if not condition then fail(message) end
end

local ROOT = "dramatic_deep_dive/"
local mapSpecs = dofile(ROOT .. "data/maps.lua")
local volumes = dofile(ROOT .. "data/volumes.lua")
local scenes = dofile(ROOT .. "data/scenes.lua")

local minimumUsableDepth = {
  DDD_ROUTE19_REEF_PASSAGE = 130,
  DDD_ROUTE20_SEAFLOOR = 230,
  DDD_SEAFOAM_SUNKEN_CAVE = 170,
  DDD_ROUTE21_ABYSS = 210,
}

local function volumeForMap(mapId)
  for _, volume in pairs(volumes) do
    if volume.mapId == mapId then return volume end
  end
end

local function sceneForMap(mapId)
  for _, scene in pairs(scenes) do
    if scene.mapId == mapId then return scene end
  end
end

local totalStructures, totalScatter, totalVents, totalSchools = 0, 0, 0, 0

for _, spec in ipairs(mapSpecs) do
  local map = dofile(ROOT .. spec.file)
  local volume = volumeForMap(map.id)
  local scene = sceneForMap(map.id)
  check(volume ~= nil, map.id .. " volume missing")
  check(scene ~= nil, map.id .. " scene missing")
  check(scene.mapId == map.id, map.id .. " scene map id mismatch")
  check(volume.mapId == map.id, map.id .. " volume map id mismatch")

  local worldWidth = map.width * 2 * 16
  local worldDepth = map.height * 2 * 16
  local usableDepth = volume.defaultFloorDepth - volume.seabedClearance
  check(usableDepth >= (minimumUsableDepth[map.id] or 60), map.id .. " is not deep enough")

  for _, swim in ipairs(volume.swimVolumes or {}) do
    check(swim.left >= 0 and swim.top >= 0, map.id .. " SwimVolume starts outside map")
    check(swim.right < map.width * 2 and swim.bottom < map.height * 2,
      map.id .. " SwimVolume ends outside map")
  end

  local function pointInWorld(label, x, z)
    check(type(x) == "number" and type(z) == "number", label .. " invalid position")
    check(x >= 0 and x <= worldWidth, label .. " x outside map")
    check(z >= 0 and z <= worldDepth, label .. " z outside map")
  end

  for index, structure in ipairs(scene.structures or {}) do
    pointInWorld(map.id .. " structure " .. index, structure.x, structure.z)
  end
  for index, scatter in ipairs(scene.scatter or {}) do
    pointInWorld(map.id .. " scatter " .. index .. " min", scatter.x0, scatter.z0)
    pointInWorld(map.id .. " scatter " .. index .. " max", scatter.x1, scatter.z1)
    check((scatter.count or 0) > 0, map.id .. " scatter has no instances")
  end
  for index, cluster in ipairs(scene.crystalClusters or {}) do
    pointInWorld(map.id .. " crystal cluster " .. index, cluster.x, cluster.z)
  end
  for index, vent in ipairs(scene.bubbleVents or {}) do
    pointInWorld(map.id .. " bubble vent " .. index, vent.x, vent.z)
    check((vent.height or 0) > 0 and (vent.speed or 0) > 0, map.id .. " invalid bubble vent")
  end
  for index, shaft in ipairs(scene.lightShafts or {}) do
    pointInWorld(map.id .. " light shaft " .. index, shaft.x, shaft.z)
    check((shaft.bottomDepth or 0) > volume.minDepth, map.id .. " light shaft too shallow")
  end
  for index, school in ipairs(scene.fishSchools or {}) do
    pointInWorld(map.id .. " fish school " .. index, school.x, school.z)
    check((school.count or 0) > 0 and (school.radius or 0) > 0, map.id .. " invalid fish school")
    check((school.depth or 0) >= volume.minDepth, map.id .. " fish school above swim column")
    check((school.depth or 0) <= volume.defaultFloorDepth, map.id .. " fish school below floor")
  end

  -- District coverage must span the principal travel axis without gaps.
  local districts = scene.districts or {}
  check(#districts > 0, map.id .. " has no districts")
  local axis = districts[1].axis or "z"
  local expectedEnd = axis == "x" and worldWidth or worldDepth
  local cursor = 0
  for index, district in ipairs(districts) do
    check((district.axis or "z") == axis, map.id .. " mixes district axes")
    local from = axis == "x" and district.x0 or district.z0
    local to = axis == "x" and district.x1 or district.z1
    check(from == cursor, string.format("%s district %d leaves a gap", map.id, index))
    check(to > from, map.id .. " district has invalid range")
    cursor = to
  end
  check(cursor == expectedEnd, map.id .. " districts do not cover full map axis")

  totalStructures = totalStructures + #(scene.structures or {})
  totalScatter = totalScatter + #(scene.scatter or {})
  totalVents = totalVents + #(scene.bubbleVents or {})
  totalSchools = totalSchools + #(scene.fishSchools or {})
end

print(string.format(
  "Deep Dive scenes OK: %d maps, %d structures, %d scatter groups, %d vents, %d fish schools",
  #mapSpecs, totalStructures, totalScatter, totalVents, totalSchools))
