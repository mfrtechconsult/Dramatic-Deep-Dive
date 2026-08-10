local SurfaceLandmarkAnchors = {}
SurfaceLandmarkAnchors.__index = SurfaceLandmarkAnchors

local CELL = 16

local function cellKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function worldPoint(x, y)
  return x * CELL + CELL / 2, y * CELL + CELL / 2
end

local function squaredDistance(x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  return dx * dx + dy * dy
end

local function contains(text, fragment)
  return tostring(text or ""):find(fragment, 1, true) ~= nil
end

function SurfaceLandmarkAnchors.new(mod, atlas)
  return setmetatable({ mod = mod, atlas = atlas }, SurfaceLandmarkAnchors)
end

function SurfaceLandmarkAnchors:nearestWater(entry, x, y, maxRadius)
  if not entry then return nil end
  x, y = tonumber(x), tonumber(y)
  if not (x and y) then return nil end
  local best, bestD2 = nil, math.huge
  local limit = (tonumber(maxRadius) or 4) ^ 2
  for key in pairs(entry.water or {}) do
    local wx, wy = key:match("^(%-?%d+):(%-?%d+)$")
    wx, wy = tonumber(wx), tonumber(wy)
    local d2 = squaredDistance(x, y, wx, wy)
    if d2 <= limit and d2 < bestD2 then
      bestD2 = d2
      best = {
        x = wx,
        y = wy,
        shore = entry.shoreDistance[key] or 0,
        floor = entry.floorDepth[key] or 0,
      }
    end
  end
  return best
end

local function addColumn(scene, x, z, height, material)
  scene.structures[#scene.structures + 1] = {
    kind = "column_ring",
    x = x,
    z = z,
    radius = 0,
    count = 1,
    height = height,
    material = material or "ruinStone",
    solid = false,
  }
end

function SurfaceLandmarkAnchors:addHarborWarp(entry, scene, warp, index)
  local dest = warp.destMap
  if not (contains(dest, "DOCK") or contains(dest, "SS_ANNE")) then return 0 end
  local cell = self:nearestWater(entry, warp.x, warp.y, 7)
  if not cell then return 0 end
  local x, z = worldPoint(cell.x, cell.y)
  addColumn(scene, x - 7, z, 74 + (index % 3) * 10, "ruinStone")
  addColumn(scene, x + 7, z, 68 + (index % 4) * 9, "darkStone")
  scene.structures[#scene.structures + 1] = {
    kind = "broken_wall",
    x = x,
    z = z + 16,
    width = 42,
    height = 18,
    thickness = 7,
    material = "darkStone",
  }
  return 3
end

function SurfaceLandmarkAnchors:addCaveWarp(entry, scene, warp, index)
  local external = warp.destMap == "LAST_MAP"
  local seafoam = contains(entry.id, "SEAFOAM_ISLANDS")
  if not seafoam then return 0 end
  local radius = external and 7 or 3
  local cell = self:nearestWater(entry, warp.x, warp.y, radius)
  if not cell then return 0 end
  local x, z = worldPoint(cell.x, cell.y)
  scene.structures[#scene.structures + 1] = {
    kind = "rock_arch",
    x = x,
    z = z,
    width = external and 84 or 58,
    height = external and 58 or 42,
    thickness = external and 15 or 11,
    material = "darkStone",
  }
  if external then
    scene.crystalClusters[#scene.crystalClusters + 1] = {
      x = x + ((index % 2 == 0) and 18 or -18),
      z = z + 8,
      count = 6,
      radius = 20,
      height = 42,
    }
  end
  return external and 2 or 1
end

function SurfaceLandmarkAnchors:addSeafoamObject(entry, scene, object, index)
  if not contains(entry.id, "SEAFOAM_ISLANDS") then return 0 end
  if not contains(object.sprite, "BOULDER") then return 0 end
  local cell = self:nearestWater(entry, object.x, object.y, 4)
  if not cell then return 0 end
  local x, z = worldPoint(cell.x, cell.y)
  scene.structures[#scene.structures + 1] = {
    kind = "spire",
    x = x,
    z = z,
    height = 54 + (index % 3) * 18,
    radius = 13,
    material = "darkStone",
  }
  scene.bubbleVents[#scene.bubbleVents + 1] = {
    x = x,
    z = z,
    count = 4,
    height = math.min(220, math.max(90, cell.floor - 20)),
    speed = 10,
  }
  return 2
end

function SurfaceLandmarkAnchors:applyOne(entry, scene)
  if not (entry and scene and entry.def) then return 0 end
  scene.structures = scene.structures or {}
  scene.crystalClusters = scene.crystalClusters or {}
  scene.bubbleVents = scene.bubbleVents or {}
  local count = 0
  local kind = entry.profileName
  for index, warp in ipairs(entry.def.warps or {}) do
    if kind == "harbor" then
      count = count + self:addHarborWarp(entry, scene, warp, index)
    elseif kind == "cave" then
      count = count + self:addCaveWarp(entry, scene, warp, index)
    end
  end
  if kind == "cave" then
    for index, object in ipairs(entry.def.objects or {}) do
      count = count + self:addSeafoamObject(entry, scene, object, index)
    end
  end
  return count
end

function SurfaceLandmarkAnchors:apply(scenes)
  local maps, anchors = 0, 0
  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    local scene = scenes and scenes["atlas:" .. surfaceId]
    if scene then
      local count = self:applyOne(entry, scene)
      if count > 0 then maps = maps + 1; anchors = anchors + count end
    end
  end
  if self.mod.log then
    self.mod.log:info("Applied %d surface-linked seabed anchors across %d maps", anchors, maps)
  end
  return maps, anchors
end

return SurfaceLandmarkAnchors
