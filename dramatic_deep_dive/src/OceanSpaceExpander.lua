local OceanSpaceExpander = {}
OceanSpaceExpander.__index = OceanSpaceExpander

local CELL = 16

local function cellKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function parseCell(key)
  local x, y = tostring(key):match("^(%-?%d+):(%-?%d+)$")
  return tonumber(x), tonumber(y)
end

local function clampScale(value)
  value = math.floor((tonumber(value) or 1) + 0.5)
  if value < 1 then return 1 end
  if value > 4 then return 4 end
  return value
end

local function scaleFor(entry)
  return clampScale(entry and entry.profile and entry.profile.spaceScale or 1)
end

local function sourceCell(entry, ux, uy)
  local scale = entry.underwaterScale or scaleFor(entry)
  return math.floor(ux / scale), math.floor(uy / scale)
end

local function sourceContains(entry, cells, ux, uy)
  local sx, sy = sourceCell(entry, ux, uy)
  return cells and cells[cellKey(sx, sy)] == true
end

local function scaledRuns(entry, cells, values)
  local scale = entry.underwaterScale or scaleFor(entry)
  local width, height = entry.width * scale, entry.height * scale
  local rows = {}
  for y = 0, height - 1 do
    local row, x = {}, 0
    while x < width do
      local sx, sy = sourceCell(entry, x, y)
      local sourceKey = cellKey(sx, sy)
      if cells and cells[sourceKey] then
        local x0 = x
        local value = values and values[sourceKey] or nil
        x = x + 1
        while x < width do
          local nsx, nsy = sourceCell(entry, x, y)
          local nk = cellKey(nsx, nsy)
          if not (cells and cells[nk]) then break end
          if values and values[nk] ~= value then break end
          x = x + 1
        end
        local run = { x0 = x0, x1 = x - 1 }
        if values then run.floorDepth = value end
        row[#row + 1] = run
      else
        x = x + 1
      end
    end
    if #row > 0 then rows[y] = row end
  end
  return rows
end

local function scaledMaskBlock(entry, bx, by)
  local mask = 0
  local cells = {
    { bx * 2,     by * 2,     1 },
    { bx * 2 + 1, by * 2,     2 },
    { bx * 2,     by * 2 + 1, 4 },
    { bx * 2 + 1, by * 2 + 1, 8 },
  }
  for _, cell in ipairs(cells) do
    if sourceContains(entry, entry.water, cell[1], cell[2]) then mask = mask + cell[3] end
  end
  return 16 + mask
end

local function centerOffset(scale)
  return math.floor(scale / 2)
end

local function scaledCenter(entry, x, y)
  local scale = entry.underwaterScale or scaleFor(entry)
  local offset = centerOffset(scale)
  return x * scale + offset, y * scale + offset
end

local function scaleScenePoint(value, scale)
  return type(value) == "number" and value * scale or value
end

function OceanSpaceExpander.new(mod, atlas)
  return setmetatable({
    mod = mod,
    atlas = atlas,
    expandedMaps = 0,
    originalSeabedCells = 0,
    expandedSeabedCells = 0,
    maxScale = 1,
    scalesByUnderwaterMap = {},
  }, OceanSpaceExpander)
end

function OceanSpaceExpander:expandMap(entry, map)
  local scale = entry.underwaterScale
  if not (map and scale and scale > 1) then return end

  local widthBlocks = entry.def.width * scale
  local heightBlocks = entry.def.height * scale
  local blocks = {}
  for by = 0, heightBlocks - 1 do
    for bx = 0, widthBlocks - 1 do
      blocks[#blocks + 1] = scaledMaskBlock(entry, bx, by)
    end
  end

  map.width = widthBlocks
  map.height = heightBlocks
  map.blocks = blocks
  map.dramaticDeepDiveScale = scale
  for _, connection in pairs(map.connections or {}) do
    connection.offset = (tonumber(connection.offset) or 0) * scale
  end

  -- Content registries normally retain the registered table by reference, but
  -- mirror the fields into a separately returned record as a defensive guard.
  local registered = self.mod.content.maps:get(map.id)
  if registered and registered ~= map then
    registered.width = map.width
    registered.height = map.height
    registered.blocks = map.blocks
    registered.connections = map.connections
    registered.dramaticDeepDiveScale = scale
  end
end

function OceanSpaceExpander:expandEdgeCells(entry, edgeMasks)
  local scale = entry.underwaterScale
  local width, height = entry.width * scale, entry.height * scale
  local out = {}

  for direction, source in pairs(edgeMasks or {}) do
    local dest = {}
    for key, enabled in pairs(source or {}) do
      if enabled then
        local x, y = parseCell(key)
        if x and y then
          if direction == "north" then
            for i = 0, scale - 1 do dest[cellKey(x * scale + i, 0)] = true end
          elseif direction == "south" then
            for i = 0, scale - 1 do dest[cellKey(x * scale + i, height - 1)] = true end
          elseif direction == "west" then
            for i = 0, scale - 1 do dest[cellKey(0, y * scale + i)] = true end
          elseif direction == "east" then
            for i = 0, scale - 1 do dest[cellKey(width - 1, y * scale + i)] = true end
          end
        end
      end
    end
    out[direction] = dest
  end
  return out
end

function OceanSpaceExpander:expandVolume(entry, volume)
  if not volume then return end
  local scale = entry.underwaterScale
  volume.cellRuns = scaledRuns(entry, entry.water)
  volume.depthRuns = scaledRuns(entry, entry.water, entry.floorDepth)
  volume.surfaceRuns = scaledRuns(entry, entry.surfaceWater or entry.water)
  volume.widthCells = entry.width * scale
  volume.heightCells = entry.height * scale
  volume.connectedEdgeCells = self:expandEdgeCells(entry, volume.connectedEdgeCells)
  volume.underwaterScale = scale
  volume.sourceWidthCells = entry.width
  volume.sourceHeightCells = entry.height
end

function OceanSpaceExpander:expandDiveZone(entry, zone)
  if not zone then return end
  local scale = entry.underwaterScale
  for _, link in ipairs(zone.links or {}) do
    if not link._oceanSpaceExpanded then
      link.scale = scale
      link.underwater.x = link.underwater.x * scale
      link.underwater.y = link.underwater.y * scale
      link.underwaterWidth = (tonumber(link.width) or 1) * scale
      link.underwaterHeight = (tonumber(link.height) or 1) * scale
      link.centerOffset = centerOffset(scale)
      link._oceanSpaceExpanded = true
    end
  end
  zone.underwaterScale = scale
end

function OceanSpaceExpander:expandTopology(generated)
  local mapsById = {}
  for _, map in ipairs(generated and generated.maps or {}) do mapsById[map.id] = map end

  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    local scale = scaleFor(entry)
    entry.underwaterScale = scale
    self.scalesByUnderwaterMap[entry.underwaterMapId] = scale
    self.maxScale = math.max(self.maxScale, scale)
    self.originalSeabedCells = self.originalSeabedCells + (entry.waterCount or 0)
    self.expandedSeabedCells = self.expandedSeabedCells + (entry.waterCount or 0) * scale * scale

    self:expandMap(entry, mapsById[entry.underwaterMapId])
    self:expandVolume(entry, generated.volumes and generated.volumes["atlas:" .. surfaceId])
    self:expandDiveZone(entry, generated.dives and generated.dives["atlas:" .. surfaceId])
    if scale > 1 then self.expandedMaps = self.expandedMaps + 1 end
  end

  self.atlas.stats.expandedSeabedCells = self.expandedSeabedCells
  self.atlas.stats.maxUnderwaterScale = self.maxScale
  if self.mod.log then
    self.mod.log:info(
      "Expanded underwater Kanto: %d maps enlarged, %d -> %d swim cells, max horizontal scale x%d",
      self.expandedMaps, self.originalSeabedCells, self.expandedSeabedCells, self.maxScale)
  end
  return generated
end

local function scaleScene(scene, scale)
  if not (scene and scale and scale > 1) then return end
  if scene._oceanSpacePresentationExpanded then return end

  for _, district in ipairs(scene.districts or {}) do
    district.x0 = scaleScenePoint(district.x0, scale)
    district.x1 = scaleScenePoint(district.x1, scale)
    district.z0 = scaleScenePoint(district.z0, scale)
    district.z1 = scaleScenePoint(district.z1, scale)
  end
  for _, structure in ipairs(scene.structures or {}) do
    structure.x = scaleScenePoint(structure.x, scale)
    structure.z = scaleScenePoint(structure.z, scale)
  end
  for _, scatter in ipairs(scene.scatter or {}) do
    scatter.x0 = scaleScenePoint(scatter.x0, scale)
    scatter.x1 = scaleScenePoint(scatter.x1, scale)
    scatter.z0 = scaleScenePoint(scatter.z0, scale)
    scatter.z1 = scaleScenePoint(scatter.z1, scale)
    -- Grow decorative population only linearly while navigable area grows by
    -- scale^2. Large oceans therefore feel open instead of turning into clutter.
    scatter.count = math.max(1, math.floor((tonumber(scatter.count) or 1) * scale + 0.5))
  end
  for _, cluster in ipairs(scene.crystalClusters or {}) do
    cluster.x = scaleScenePoint(cluster.x, scale)
    cluster.z = scaleScenePoint(cluster.z, scale)
    cluster.radius = type(cluster.radius) == "number" and cluster.radius * math.sqrt(scale) or cluster.radius
  end
  for _, vent in ipairs(scene.bubbleVents or {}) do
    vent.x = scaleScenePoint(vent.x, scale)
    vent.z = scaleScenePoint(vent.z, scale)
  end
  for _, shaft in ipairs(scene.lightShafts or {}) do
    shaft.x = scaleScenePoint(shaft.x, scale)
    shaft.z = scaleScenePoint(shaft.z, scale)
    shaft.width = type(shaft.width) == "number" and shaft.width * math.sqrt(scale) or shaft.width
  end
  for _, school in ipairs(scene.fishSchools or {}) do
    school.x = scaleScenePoint(school.x, scale)
    school.z = scaleScenePoint(school.z, scale)
    school.radius = type(school.radius) == "number" and school.radius * math.sqrt(scale) or school.radius
  end

  scene.underwaterScale = scale
  scene._oceanSpacePresentationExpanded = true
end

function OceanSpaceExpander:expandPortals(portalService)
  if not (portalService and portalService.portals) then return end
  local rebuilt = {}
  for _, portal in pairs(portalService.portals) do
    local sourceScale = self.scalesByUnderwaterMap[portal.sourceMap] or 1
    local destScale = self.scalesByUnderwaterMap[portal.destMap] or 1
    portal.sourceX = portal.sourceX * sourceScale + centerOffset(sourceScale)
    portal.sourceY = portal.sourceY * sourceScale + centerOffset(sourceScale)
    portal.destX = portal.destX * destScale + centerOffset(destScale)
    portal.destY = portal.destY * destScale + centerOffset(destScale)
    rebuilt[tostring(portal.sourceMap) .. ":" .. tostring(portal.sourceX) .. ":" .. tostring(portal.sourceY)] = portal
  end
  portalService.portals = rebuilt
  portalService.lastCellKey = nil
end

function OceanSpaceExpander:expandPresentation(generated, portalService)
  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    local scale = entry.underwaterScale or 1
    scaleScene(generated.scenes and generated.scenes["atlas:" .. surfaceId], scale)
    for _, node in ipairs(generated.salvage and generated.salvage[entry.underwaterMapId] or {}) do
      if not node._oceanSpaceExpanded then
        node.x = scaleScenePoint(node.x, scale)
        node.z = scaleScenePoint(node.z, scale)
        node._oceanSpaceExpanded = true
      end
    end
  end
  self:expandPortals(portalService)
  return generated
end

function OceanSpaceExpander:patchTravel(travel)
  if not travel or travel._oceanSpacePatched then return travel end

  local function contains(point, rect)
    return point.x >= rect.x and point.x < rect.x + rect.width
      and point.y >= rect.y and point.y < rect.y + rect.height
  end

  function travel:diveTarget(position)
    if not position then return nil end
    for zoneId, zone in pairs(self.zones) do
      for _, link in ipairs(zone.links or {}) do
        if position.mapId == link.surface.mapId and contains(position, {
          x = link.surface.x, y = link.surface.y,
          width = link.width, height = link.height,
        }) then
          local scale = clampScale(link.scale or 1)
          local offset = tonumber(link.centerOffset) or centerOffset(scale)
          return {
            mapId = link.underwater.mapId,
            x = link.underwater.x + (position.x - link.surface.x) * scale + offset,
            y = link.underwater.y + (position.y - link.surface.y) * scale + offset,
            facing = position.facing,
            linkId = link.id,
            zoneId = zoneId,
          }, zone, zoneId
        end
      end
    end
    return nil
  end

  function travel:surfaceTarget(position)
    if not position then return nil end
    for zoneId, zone in pairs(self.zones) do
      for _, link in ipairs(zone.links or {}) do
        local scale = clampScale(link.scale or 1)
        local width = tonumber(link.underwaterWidth) or (tonumber(link.width) or 1) * scale
        local height = tonumber(link.underwaterHeight) or (tonumber(link.height) or 1) * scale
        if position.mapId == link.underwater.mapId and contains(position, {
          x = link.underwater.x, y = link.underwater.y,
          width = width, height = height,
        }) then
          return {
            mapId = link.surface.mapId,
            x = link.surface.x + math.floor((position.x - link.underwater.x) / scale),
            y = link.surface.y + math.floor((position.y - link.underwater.y) / scale),
            facing = position.facing,
            linkId = link.id,
            zoneId = zoneId,
          }, zone, zoneId
        end
      end
    end
    return nil
  end

  travel._oceanSpacePatched = true
  return travel
end

function OceanSpaceExpander:stats()
  return {
    expandedMaps = self.expandedMaps,
    originalSeabedCells = self.originalSeabedCells,
    expandedSeabedCells = self.expandedSeabedCells,
    maxScale = self.maxScale,
  }
end

return OceanSpaceExpander
