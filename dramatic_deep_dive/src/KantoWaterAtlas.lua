local Map = require("src.world.Map")

local KantoWaterAtlas = {}
KantoWaterAtlas.__index = KantoWaterAtlas

local DIRS = {
  { name = "north", dx = 0, dy = -1 },
  { name = "south", dx = 0, dy = 1 },
  { name = "west", dx = -1, dy = 0 },
  { name = "east", dx = 1, dy = 0 },
}

-- Surface collision and underwater hydrology are deliberately different.
-- A bridge/pier/pontoon is solid or walkable on the surface, but water still
-- exists underneath it.  Small walkable gaps between water cells are treated
-- as over-water structures for the seabed mask while remaining non-DIVE cells
-- on the surface.  Four movement cells is wide enough for Kanto's authored
-- bridge/dock strips without broadly swallowing normal land masses.
local MAX_OVERWATER_GAP = 4

local function listSet(list)
  local out = {}
  for _, value in ipairs(list or {}) do out[value] = true end
  return out
end

local function copySet(source)
  local out = {}
  for key, value in pairs(source or {}) do if value then out[key] = true end end
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
    stats = {
      maps = 0,
      waterCells = 0,            -- legacy: real surface water cells
      surfaceWaterCells = 0,
      underStructureCells = 0,
      seabedCells = 0,           -- surface water + inferred water below structures
      components = 0,
      seams = 0,
    },
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

local function walkable(entry, x, y)
  if not (Map and type(Map.defIsWalkableCell) == "function") then return false end
  local ok, value = pcall(Map.defIsWalkableCell, entry.def, entry.tileset, x, y)
  return ok and value == true
end

function KantoWaterAtlas:markUnderStructure(entry, x, y, reason)
  if x < 0 or y < 0 or x >= entry.width or y >= entry.height then return false end
  local key = cellKey(x, y)
  if entry.surfaceWater[key] or entry.underStructure[key] then return false end
  entry.underStructure[key] = reason or true
  entry.water[key] = true
  entry.underStructureCount = entry.underStructureCount + 1
  entry.waterCount = entry.waterCount + 1
  return true
end

function KantoWaterAtlas:inferShipPortPlatforms(entry)
  if entry.def.tileset ~= "SHIP_PORT" or not (Map and type(Map.defCellTile) == "function") then
    return 0
  end
  local added = 0
  for y = 0, entry.height - 1 do
    for x = 0, entry.width - 1 do
      local key = cellKey(x, y)
      if not entry.surfaceWater[key] then
        local ok, tile = pcall(Map.defCellTile, entry.def, entry.tileset, x, y)
        -- Gen1Recomp intentionally excludes $32 from SHIP_PORT's water/shore
        -- set because it is the S.S. Anne boarding platform. Hydrologically it
        -- is still a dock built over the harbor, so the seabed continues below.
        if ok and tile == 0x32 and self:markUnderStructure(entry, x, y, "ship_port_32") then
          added = added + 1
        end
      end
    end
  end
  return added
end

local function gapIsWalkable(entry, horizontal, fixed, first, last)
  for value = first, last do
    local x, y = horizontal and value or fixed, horizontal and fixed or value
    if not walkable(entry, x, y) then return false end
  end
  return true
end

function KantoWaterAtlas:inferWalkableWaterGaps(entry)
  local added = 0

  local function scanLine(horizontal, fixed, length)
    local pos = 0
    while pos < length do
      local x, y = horizontal and pos or fixed, horizontal and fixed or pos
      if entry.water[cellKey(x, y)] then
        pos = pos + 1
      else
        local first = pos
        while pos < length do
          x, y = horizontal and pos or fixed, horizontal and fixed or pos
          if entry.water[cellKey(x, y)] then break end
          pos = pos + 1
        end
        local last = pos - 1
        local gap = last - first + 1
        if first > 0 and pos < length and gap <= MAX_OVERWATER_GAP
            and gapIsWalkable(entry, horizontal, fixed, first, last) then
          local beforeX, beforeY = horizontal and (first - 1) or fixed,
            horizontal and fixed or (first - 1)
          local afterX, afterY = horizontal and pos or fixed,
            horizontal and fixed or pos
          if entry.water[cellKey(beforeX, beforeY)] and entry.water[cellKey(afterX, afterY)] then
            for value = first, last do
              x, y = horizontal and value or fixed, horizontal and fixed or value
              if self:markUnderStructure(entry, x, y, horizontal and "bridge_h" or "bridge_v") then
                added = added + 1
              end
            end
          end
        end
      end
    end
  end

  -- Two passes allow an L/T-shaped authored platform to be completed after
  -- one axis has established hydrological continuity, while the strict small
  -- gap + walkable requirement still prevents broad land from being flooded.
  for _ = 1, 2 do
    local before = added
    for y = 0, entry.height - 1 do scanLine(true, y, entry.width) end
    for x = 0, entry.width - 1 do scanLine(false, x, entry.height) end
    if added == before then break end
  end
  return added
end

function KantoWaterAtlas:inferUnderStructureWater(entry)
  self:inferShipPortPlatforms(entry)
  self:inferWalkableWaterGaps(entry)
end

function KantoWaterAtlas:scanMap(mapId, def)
  local tileset = self.mod.content.tilesets:get(def.tileset)
  if not tileset then return nil end
  local width, height = def.width * 2, def.height * 2
  local surfaceWater, count = {}, 0
  for y = 0, height - 1 do
    for x = 0, width - 1 do
      if Map.defIsWaterCell(def, tileset, x, y) == true then
        surfaceWater[cellKey(x, y)] = true
        count = count + 1
      end
    end
  end
  if count == 0 then return nil end
  local profile, profileName = self:profile(mapId)
  local entry = {
    id = mapId,
    def = def,
    tileset = tileset,
    width = width,
    height = height,
    surfaceWater = surfaceWater,
    surfaceWaterCount = count,
    underStructure = {},
    underStructureCount = 0,
    water = copySet(surfaceWater),
    waterCount = count,
    underwaterMapId = underwaterId(mapId),
    profile = profile,
    profileName = profileName,
    shoreDistance = {},
    floorDepth = {},
    componentAt = {},
    seams = {},
  }
  self:inferUnderStructureWater(entry)
  return entry
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

function KantoWaterAtlas:isSurfaceWater(mapId, x, y)
  local entry = self.maps[mapId]
  return entry and entry.surfaceWater[cellKey(x, y)] == true or false
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
    entry.surfaceCellRuns = rowRuns(entry.surfaceWater, entry.width, entry.height)
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
      self.stats.surfaceWaterCells = self.stats.surfaceWaterCells + entry.surfaceWaterCount
      self.stats.waterCells = self.stats.surfaceWaterCells
      self.stats.underStructureCells = self.stats.underStructureCells + entry.underStructureCount
      self.stats.seabedCells = self.stats.seabedCells + entry.waterCount
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
