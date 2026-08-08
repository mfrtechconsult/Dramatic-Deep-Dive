local function fail(message)
  io.stderr:write("[travel validation] " .. tostring(message) .. "\n")
  os.exit(1)
end

local function check(condition, message)
  if not condition then fail(message) end
end

local ROOT = "dramatic_deep_dive/"
local mapSpecs = dofile(ROOT .. "data/maps.lua")
local links = dofile(ROOT .. "data/dive_links.lua")
local volumes = dofile(ROOT .. "data/volumes.lua")

local maps = {}
local indices = {}
for _, spec in ipairs(mapSpecs) do
  local map = dofile(ROOT .. spec.file)
  check(type(map.id) == "string" and map.id:match("^DDD_"), "underwater map must use a DDD_ id")
  check(not maps[map.id], "duplicate underwater map id " .. map.id)
  check(not indices[map.index], "duplicate underwater map index " .. tostring(map.index))
  check(type(map.blocks) == "table" and #map.blocks == map.width * map.height,
    map.id .. " block count does not match dimensions")
  maps[map.id] = map
  indices[map.index] = map.id
end

local function volumeForMap(mapId)
  for _, volume in pairs(volumes) do
    if volume.mapId == mapId then return volume end
  end
end

local function rectContains(outer, inner)
  return inner.left >= outer.left and inner.top >= outer.top
    and inner.right <= outer.right and inner.bottom <= outer.bottom
end

local assigned = {}
for zoneId, zone in pairs(links) do
  check(maps[zone.underwaterMapId] ~= nil,
    zoneId .. " primary underwater map is not registered")
  local submerged = zone.submergedMaps or { zone.underwaterMapId }
  check(#submerged > 0, zoneId .. " has no submerged maps")
  for _, mapId in ipairs(submerged) do
    check(maps[mapId] ~= nil, zoneId .. " references missing submerged map " .. tostring(mapId))
    check(not assigned[mapId] or assigned[mapId] == zoneId,
      mapId .. " belongs to multiple dive zones")
    assigned[mapId] = zoneId
  end

  for _, link in ipairs(zone.links or {}) do
    local map = maps[link.underwater.mapId]
    check(map ~= nil, link.id .. " references unregistered underwater map")
    check((link.width or 0) > 0 and (link.height or 0) > 0, link.id .. " has invalid size")
    local x0, y0 = link.underwater.x, link.underwater.y
    local x1, y1 = x0 + link.width - 1, y0 + link.height - 1
    check(x0 >= 0 and y0 >= 0 and x1 < map.width * 2 and y1 < map.height * 2,
      link.id .. " underwater arrival rectangle is outside " .. map.id)

    local volume = volumeForMap(map.id)
    check(volume ~= nil, link.id .. " has no matching depth volume")
    local linkRect = { left = x0, top = y0, right = x1, bottom = y1 }
    local insideSurface = false
    for _, surface in ipairs(volume.surfaceZones or {}) do
      if rectContains(surface, linkRect) then insideSurface = true break end
    end
    check(insideSurface,
      link.id .. " arrival rectangle is not contained in an authored SurfaceZone")
  end
end

for mapId in pairs(maps) do
  check(assigned[mapId] ~= nil or mapId == "DDD_SEAFOAM_SUNKEN_CAVE",
    mapId .. " is unreachable from every DIVE zone")
  check(volumeForMap(mapId) ~= nil, mapId .. " has no depth volume")
end

-- Internal underwater warps must stay inside the registered DDD map graph.
for mapId, map in pairs(maps) do
  for index, warp in ipairs(map.warps or {}) do
    check(maps[warp.destMap] ~= nil,
      string.format("%s warp %d leaves the standalone underwater map graph", mapId, index))
    check(type(warp.destWarp) == "number" and warp.destWarp >= 1,
      string.format("%s warp %d has invalid destination warp", mapId, index))
  end
end

check(assigned.DDD_ROUTE20_SEAFLOOR == "route20_seafoam",
  "Route 20 must belong to route20_seafoam")
check(assigned.DDD_SEAFOAM_SUNKEN_CAVE == "route20_seafoam",
  "Seafoam must share Route 20's submerged travel session")

print(string.format("Deep Dive travel OK: %d maps across %d DIVE zones",
  #mapSpecs, (function() local n=0 for _ in pairs(links) do n=n+1 end return n end)()))
