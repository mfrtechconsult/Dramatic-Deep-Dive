local VolumeRegistry = {}
VolumeRegistry.__index = VolumeRegistry

local function number(value, fallback)
  value = tonumber(value)
  if value == nil then return fallback end
  return value
end

local function normalizeRect(rect)
  if type(rect) ~= "table" then return nil end
  local left = number(rect.left or rect.x, nil)
  local top = number(rect.top or rect.y, nil)
  local right = number(rect.right, nil)
  local bottom = number(rect.bottom, nil)

  if right == nil and left ~= nil and rect.width ~= nil then
    right = left + number(rect.width, 0) - 1
  end
  if bottom == nil and top ~= nil and rect.height ~= nil then
    bottom = top + number(rect.height, 0) - 1
  end
  if left == nil or top == nil or right == nil or bottom == nil then return nil end
  if right < left or bottom < top then return nil end

  return { left = left, top = top, right = right, bottom = bottom }
end

local function contains(rect, x, y)
  return rect and x >= rect.left and x <= rect.right
    and y >= rect.top and y <= rect.bottom
end

local function normalizeRows(rows, withDepth)
  if type(rows) ~= "table" then return nil end
  local out = {}
  for rawY, rawRuns in pairs(rows) do
    local y = number(rawY, nil)
    if y ~= nil and type(rawRuns) == "table" then
      local row = {}
      for index, raw in ipairs(rawRuns) do
        local x0 = number(raw.x0 or raw.left or raw.x, nil)
        local x1 = number(raw.x1 or raw.right, nil)
        if x1 == nil and x0 ~= nil and raw.width ~= nil then
          x1 = x0 + number(raw.width, 0) - 1
        end
        if x0 == nil or x1 == nil or x1 < x0 then
          return nil, ("invalid row run y=%s #%d"):format(tostring(rawY), index)
        end
        local run = { x0 = x0, x1 = x1 }
        if withDepth then
          run.floorDepth = number(raw.floorDepth or raw.maxDepth, nil)
          if not run.floorDepth then
            return nil, ("depth row run y=%s #%d has no floorDepth"):format(tostring(rawY), index)
          end
        end
        row[#row + 1] = run
      end
      if #row > 0 then
        table.sort(row, function(a, b) return a.x0 < b.x0 end)
        out[y] = row
      end
    end
  end
  return out
end

local function rowContains(rows, x, y)
  local row = rows and rows[y]
  if not row then return false end
  for _, run in ipairs(row) do
    if x >= run.x0 and x <= run.x1 then return true, run end
  end
  return false
end

function VolumeRegistry.new(mod)
  return setmetatable({ mod = mod, byId = {}, byMap = {} }, VolumeRegistry)
end

function VolumeRegistry:register(id, definition, owner)
  if type(id) ~= "string" or id == "" then return nil, "missing id" end
  if type(definition) ~= "table" then return nil, "definition is not a table" end
  if self.byId[id] then return nil, "duplicate id" end

  local mapId = definition.mapId
  if type(mapId) ~= "string" or mapId == "" then return nil, "missing mapId" end

  local swimVolumes = {}
  for index, raw in ipairs(definition.swimVolumes or {}) do
    local rect = normalizeRect(raw)
    if not rect then return nil, ("invalid SwimVolume %d"):format(index) end
    rect.id = raw.id or (id .. ":swim:" .. index)
    swimVolumes[#swimVolumes + 1] = rect
  end

  local cellRuns, cellError = normalizeRows(definition.cellRuns, false)
  if cellError then return nil, cellError end
  if #swimVolumes == 0 and not cellRuns then
    return nil, "at least one SwimVolume or cellRuns mask is required"
  end

  local depthZones = {}
  for index, raw in ipairs(definition.depthZones or {}) do
    local rect = normalizeRect(raw)
    if not rect then return nil, ("invalid DepthZone %d"):format(index) end
    rect.id = raw.id or (id .. ":depth:" .. index)
    rect.floorDepth = number(raw.floorDepth or raw.maxDepth, nil)
    if not rect.floorDepth then return nil, ("DepthZone %d has no floorDepth"):format(index) end
    depthZones[#depthZones + 1] = rect
  end

  local depthRuns, depthError = normalizeRows(definition.depthRuns, true)
  if depthError then return nil, depthError end
  local surfaceRuns, surfaceError = normalizeRows(definition.surfaceRuns, false)
  if surfaceError then return nil, surfaceError end

  local surfaceZones = {}
  for index, raw in ipairs(definition.surfaceZones or {}) do
    local rect = normalizeRect(raw)
    if not rect then return nil, ("invalid SurfaceZone %d"):format(index) end
    rect.id = raw.id or (id .. ":surface:" .. index)
    surfaceZones[#surfaceZones + 1] = rect
  end

  local entry = {
    id = id,
    owner = owner,
    mapId = mapId,
    zoneId = definition.zoneId,
    surfaceMapId = definition.surfaceMapId,
    biome = definition.biome,
    floorColor = definition.floorColor,
    surfaceHeight = number(definition.surfaceHeight, 48),
    minDepth = number(definition.minDepth, 4),
    defaultDepth = number(definition.defaultDepth, 16),
    defaultFloorDepth = number(definition.defaultFloorDepth, 42),
    seabedClearance = number(definition.seabedClearance, 3),
    widthCells = number(definition.widthCells, nil),
    heightCells = number(definition.heightCells, nil),
    connectedEdges = definition.connectedEdges or {},
    swimVolumes = swimVolumes,
    cellRuns = cellRuns,
    depthZones = depthZones,
    depthRuns = depthRuns,
    surfaceZones = surfaceZones,
    surfaceRuns = surfaceRuns,
  }

  entry.defaultDepth = math.max(entry.minDepth,
    math.min(entry.defaultFloorDepth - entry.seabedClearance, entry.defaultDepth))

  self.byId[id] = entry
  self.byMap[mapId] = self.byMap[mapId] or {}
  self.byMap[mapId][#self.byMap[mapId] + 1] = entry
  return entry
end

function VolumeRegistry:get(id)
  return self.byId[id]
end

function VolumeRegistry:forMap(mapId, x, y)
  local candidates = self.byMap[mapId] or {}
  if x == nil or y == nil then return candidates[1] end
  for _, volume in ipairs(candidates) do
    if volume.cellRuns and rowContains(volume.cellRuns, x, y) then return volume end
    for _, rect in ipairs(volume.swimVolumes) do
      if contains(rect, x, y) then return volume end
    end
  end
  return nil
end

function VolumeRegistry:contains(mapId, x, y)
  return self:forMap(mapId, x, y) ~= nil
end

function VolumeRegistry:floorDepthAt(mapId, x, y)
  local volume = self:forMap(mapId, x, y)
  if not volume then return nil end
  local floorDepth = volume.defaultFloorDepth
  if volume.depthRuns then
    local hit, run = rowContains(volume.depthRuns, x, y)
    if hit and run and run.floorDepth then floorDepth = run.floorDepth end
  end
  for _, zone in ipairs(volume.depthZones) do
    if contains(zone, x, y) then
      floorDepth = math.min(floorDepth, zone.floorDepth)
    end
  end
  return floorDepth, volume
end

function VolumeRegistry:maxDepthAt(mapId, x, y)
  local floorDepth, volume = self:floorDepthAt(mapId, x, y)
  if not floorDepth then return nil, volume end
  return math.max(volume.minDepth, floorDepth - volume.seabedClearance), volume
end

function VolumeRegistry:isSurfaceZone(mapId, x, y)
  local volume = self:forMap(mapId, x, y)
  if not volume then return false end
  if volume.surfaceRuns and rowContains(volume.surfaceRuns, x, y) then
    return true, { id = volume.id .. ":generated_surface" }, volume
  end
  for _, zone in ipairs(volume.surfaceZones) do
    if contains(zone, x, y) then return true, zone, volume end
  end
  return false, nil, volume
end

function VolumeRegistry:rowsForMap(mapId)
  local volume = self:forMap(mapId)
  return volume and volume.cellRuns or nil, volume
end

return VolumeRegistry
