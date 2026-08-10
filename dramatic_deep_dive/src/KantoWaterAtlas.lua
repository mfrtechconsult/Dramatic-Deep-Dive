local Map = require("src.world.Map")

local KantoWaterAtlas = {}
KantoWaterAtlas.__index = KantoWaterAtlas

local DIRS = {
  { name = "north", dx = 0, dy = -1 },
  { name = "south", dx = 0, dy = 1 },
  { name = "west", dx = -1, dy = 0 },
  { name = "east", dx = 1, dy = 0 },
}

local function listSet(list)
  local out = {}
  for _, value in ipairs(list or {}) do out[value] = true end
  return out
end

local function sortedKeys(map)
  local out = {}
  for key in pairs(map or {}) do out[#out + 1] = key end
  table.sort(out)
  return out
end

local function cellKey(x, y) return tostring(x) .. ":" .. tostring(y) end

local function rowRuns(cells, width, height, valueAt)
  local rows = {}
  for y = 0, height - 1 do
    local row, x = {}, 0
    while x < width do
      if cells[cellKey(x, y)] then
        local x0 = x
        local value = valueAt and valueAt(x, y) or nil
        x = x + 1
        while x < width and cells[cellKey(x, y)]
            and (not valueAt or valueAt(x, y) == value) do
          x = x + 1
        end
        local run = { x0 = x0, x1 = x - 1 }
        if valueAt then run.floorDepth = value end
        row[#row + 1] = run
      else
        x = x + 1
      end
    end
    if #row > 0 then rows[y] = row end
  end
  return rows
end

local function underwaterId(surfaceId)
  return "DDD_SEABED_" .. tostring(surfaceId)
end

function KantoWaterAtlas.new(mod, profileData)
  return setmetatable({
    mod = mod,
    profileData = profileData or {},
    maps = {},
    byUnderwater = {},
    components = {},
    stats = { maps = 0, waterCells = 0, components = 0, seams = 0 },
  }, KantoWaterAtlas)
end

function KantoWaterAtlas:profileName(mapId)
  local data = self.profileData
  local explicit = data.overrides and data.overrides[mapId]
  if explicit then return explicit end
  for _, rule in ipairs(data.patterns or {}) do
    if tostring(mapId):find(rule.find, 1, true) then return rule.profile end
  end
  if tostring(mapId):match("^ROUTE_") then return "coastal" end
  return data.default or "coastal"
end

function KantoWaterAtlas:profile(mapId)
  local name = self:profileName(mapId)
  return (self.profileData.profiles and self.profileData.profiles[name]) or {}, name
end

function KantoWaterAtlas:isCandidateMap(mapId, def, waterTilesets)
  if type(mapId) ~= "string" or type(def) ~= "table" then return false end
  if mapId:match("^DDD_") then return false end
  if not (tonumber(def.width) and tonumber(def.height) and def.tileset) then return false end
  if waterTilesets[def.tileset] then return true end
  local tileset = self.mod.content.tilesets:get(def.tileset)
  return tileset and type(tileset.waterTiles) == "table" and #tileset.waterTiles > 0
end

function KantoWaterAtlas:scanMap(mapId, def)
  local tileset = self.mod.content.tilesets:get(def.tileset)
  if not tileset then return nil end
  local width, height = def.width * 2, def.height * 2
  local cells, count = {}, 0
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      if Map.defIsWaterCell(def, tileset, x, y) == true then
        cells[cellKey(x, y)] = true
        count = count + 1
      end
    end
  end
  if count == 0 then return nil end
  local profile, profileName = self:profile(mapId)
  return {
    id = mapId,
    def = def,
    tileset = tileset,
    width = width,
    height = height,
    water = cells,
    waterCount = count,
    underwaterMapId = underwaterId(mapId),
    profile = profile,
    profileName = profileName,
    shoreDistance = {},
    floorDepth = {},
    componentAt = {},
    seams = {},
  }
end

function KantoWaterAtlas:step(mapId, x, y, direction)
  local entry = self.maps[mapId]
  if not entry then return nil end
  local nx, ny = x + direction.dx, y + direction.dy
  if nx >= 0 and ny >= 0 and nx < entry.width and ny < entry.height then
    return mapId, nx, ny
  end
  local connection = entry.def.connections and entry.def.connections[direction.name]
  if not connection or not connection.map then return nil end
  local dest = self.maps[connection.map]
  if not dest then return nil end
  local offset = (tonumber(connection.offset) or 0) * 2
  if direction.name == "north" then
    nx, ny = x - offset, dest.height - 1
  elseif direction.name == "south" then
    nx, ny = x - offset, 0
  elseif direction.name == "west" then
    nx, ny = dest.width - 1, y - offset
  else
    nx, ny = 0, y - offset
  end
  if nx < 0 or ny < 0 or nx >= dest.width or ny >= dest.height then return nil end
  return dest.id, nx, ny
end

function KantoWaterAtlas:isWater(mapId, x, y)
  local entry = self.maps[mapId]
  return entry and entry.water[cellKey(x, y)] == true or false
end

function KantoWaterAtlas:waterNeighbors(mapId, x, y)
  local out = {}
  for _, direction in ipairs(DIRS) do
    local destId, nx, ny = self:step(mapId, x, y, direction)
    if destId and self:isWater(destId, nx, ny) then
      out[#out + 1] = { mapId = destId, x = nx, y = ny, direction = direction.name }
    end
  end
  return out
end

function KantoWaterAtlas:buildComponentsAndDistance()
  local queue, head = {}, 1

  -- A water cell is shoreline if at least one cardinal neighbor is not a
  -- connected water cell. Map connections are followed, so an ocean seam is
  -- not mistaken for a coast merely because it crosses a map boundary.
  for mapId, entry in pairs(self.maps) do
    for key in pairs(entry.water) do
      local x, y = key:match("^(%-?%d+):(%-?%d+)$")
      x, y = tonumber(x), tonumber(y)
      if #self:waterNeighbors(mapId, x, y) < 4 then
        entry.shoreDistance[key] = 0
        queue[#queue + 1] = { mapId = mapId, x = x, y = y }
      end
    end
  end

  -- Global multi-map distance transform. Crossing a connected route seam costs
  -- one cell just like moving inside one map, which keeps depth continuous.
  while head <= #queue do
    local node = queue[head]; head = head + 1
    local entry = self.maps[node.mapId]
    local d = entry.shoreDistance[cellKey(node.x, node.y)] or 0
    for _, neighbor in ipairs(self:waterNeighbors(node.mapId, node.x, node.y)) do
      local dest = self.maps[neighbor.mapId]
      local key = cellKey(neighbor.x, neighbor.y)
      if dest.shoreDistance[key] == nil then
        dest.shoreDistance[key] = d + 1
        queue[#queue + 1] = neighbor
      end
    end
  end

  -- Connected components also span map boundaries. This is useful for audits
  -- and later biome/landmark authoring over one coherent ocean body.
  local componentId = 0
  for mapId, entry in pairs(self.maps) do
    for key in pairs(entry.water) do
      if not entry.componentAt[key] then
        componentId = componentId + 1
        local component = { id = componentId, cells = 0, maps = {} }
        self.components[componentId] = component
        local x, y = key:match("^(%-?%d+):(%-?%d+)$")
        local pending, qi = { { mapId = mapId, x = tonumber(x), y = tonumber(y) } }, 1
        entry.componentAt[key] = componentId
        while qi <= #pending do
          local node = pending[qi]; qi = qi + 1
          local current = self.maps[node.mapId]
          component.cells = component.cells + 1
          component.maps[node.mapId] = true
          for _, neighbor in ipairs(self:waterNeighbors(node.mapId, node.x, node.y)) do
            local dest = self.maps[neighbor.mapId]
            local nk = cellKey(neighbor.x, neighbor.y)
            if not dest.componentAt[nk] then
              dest.componentAt[nk] = componentId
              pending[#pending + 1] = neighbor
            end
          end
        end
      end
    end
  end
  self.stats.components = componentId
end

function KantoWaterAtlas:buildSeams()
  local counted = {}
  for mapId, entry in pairs(self.maps) do
    for _, direction in ipairs(DIRS) do
      local connection = entry.def.connections and entry.def.connections[direction.name]
      if connection and self.maps[connection.map] then
        local count = 0
        if direction.name == "north" or direction.name == "south" then
          local y = direction.name == "north" and 0 or entry.height - 1
          for x = 0, entry.width - 1 do
            local destId, nx, ny = self:step(mapId, x, y, direction)
            if destId and self:isWater(mapId, x, y) and self:isWater(destId, nx, ny) then
              count = count + 1
            end
          end
        else
          local x = direction.name == "west" and 0 or entry.width - 1
          for y = 0, entry.height - 1 do
            local destId, nx, ny = self:step(mapId, x, y, direction)
            if destId and self:isWater(mapId, x, y) and self:isWater(destId, nx, ny) then
              count = count + 1
            end
          end
        end
        if count > 0 then
          entry.seams[direction.name] = {
            map = connection.map,
            underwaterMap = self.maps[connection.map].underwaterMapId,
            offset = tonumber(connection.offset) or 0,
            waterCells = count,
          }
          local pair = mapId < connection.map
            and (mapId .. ":" .. connection.map)
            or (connection.map .. ":" .. mapId)
          if not counted[pair] then counted[pair] = true self.stats.seams = self.stats.seams + 1 end
        end
      end
    end
  end
end

local function quantize(value, quantum)
  quantum = quantum or 8
  return math.floor((value + quantum / 2) / quantum) * quantum
end

function KantoWaterAtlas:buildDepths()
  for _, entry in pairs(self.maps) do
    local p = entry.profile
    for key in pairs(entry.water) do
      local distance = entry.shoreDistance[key] or 0
      local floor = (p.nearFloor or 110) + distance * (p.depthPerCell or 22)
      floor = math.min(p.maxFloor or 520, floor)
      entry.floorDepth[key] = quantize(floor, 8)
    end
  end

  -- Exact seam reconciliation: connected border cells receive the same floor
  -- depth even when their two maps use different biome profiles.
  for _ = 1, 2 do
    for mapId, entry in pairs(self.maps) do
      for _, direction in ipairs(DIRS) do
        if entry.seams[direction.name] then
          if direction.name == "north" or direction.name == "south" then
            local y = direction.name == "north" and 0 or entry.height - 1
            for x = 0, entry.width - 1 do
              local destId, nx, ny = self:step(mapId, x, y, direction)
              if destId and self:isWater(mapId, x, y) and self:isWater(destId, nx, ny) then
                local a, b = cellKey(x, y), cellKey(nx, ny)
                local dest = self.maps[destId]
                local shared = quantize(((entry.floorDepth[a] or 0) + (dest.floorDepth[b] or 0)) / 2, 8)
                entry.floorDepth[a], dest.floorDepth[b] = shared, shared
              end
            end
          else
            local x = direction.name == "west" and 0 or entry.width - 1
            for y = 0, entry.height - 1 do
              local destId, nx, ny = self:step(mapId, x, y, direction)
              if destId and self:isWater(mapId, x, y) and self:isWater(destId, nx, ny) then
                local a, b = cellKey(x, y), cellKey(nx, ny)
                local dest = self.maps[destId]
                local shared = quantize(((entry.floorDepth[a] or 0) + (dest.floorDepth[b] or 0)) / 2, 8)
                entry.floorDepth[a], dest.floorDepth[b] = shared, shared
              end
            end
          end
        end
      end
    end
  end
end

function KantoWaterAtlas:finishRows()
  for _, entry in pairs(self.maps) do
    entry.cellRuns = rowRuns(entry.water, entry.width, entry.height)
    entry.depthRuns = rowRuns(entry.water, entry.width, entry.height, function(x, y)
      return entry.floorDepth[cellKey(x, y)]
    end)
  end
end

function KantoWaterAtlas:build()
  local waterTilesets = {}
  local field = self.mod.content.field
  if field and field.get then waterTilesets = listSet(field:get("waterTilesets") or {}) end

  local candidates = {}
  for mapId, def in self.mod.content.maps:each() do
    if self:isCandidateMap(mapId, def, waterTilesets) then
      candidates[#candidates + 1] = { id = mapId, def = def }
    end
  end
  table.sort(candidates, function(a, b) return a.id < b.id end)

  for _, candidate in ipairs(candidates) do
    local entry = self:scanMap(candidate.id, candidate.def)
    if entry then
      self.maps[entry.id] = entry
      self.byUnderwater[entry.underwaterMapId] = entry
      self.stats.maps = self.stats.maps + 1
      self.stats.waterCells = self.stats.waterCells + entry.waterCount
    end
  end

  self:buildComponentsAndDistance()
  self:buildSeams()
  self:buildDepths()
  self:finishRows()
  return self
end

function KantoWaterAtlas:surface(mapId) return self.maps[mapId] end
function KantoWaterAtlas:underwater(mapId) return self.byUnderwater[mapId] end
function KantoWaterAtlas:underwaterMapId(mapId)
  local entry = self.maps[mapId]
  return entry and entry.underwaterMapId or nil
end
function KantoWaterAtlas:surfaceMapId(underwaterMapId)
  local entry = self.byUnderwater[underwaterMapId]
  return entry and entry.id or nil
end
function KantoWaterAtlas:mapIds() return sortedKeys(self.maps) end

return KantoWaterAtlas
