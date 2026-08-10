local SeabedLandmarks = {}
SeabedLandmarks.__index = SeabedLandmarks

local CELL = 16

local function stableHash(mapId, x, y, salt)
  local value = tonumber(salt) or 0
  local text = tostring(mapId or "")
  for i = 1, #text do value = (value * 33 + text:byte(i)) % 2147483647 end
  value = (value + (x + 17) * 73856093 + (y + 29) * 19349663) % 2147483647
  return value
end

local function copy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function merge(base, override)
  local out = copy(base)
  for key, value in pairs(override or {}) do out[key] = value end
  return out
end

local function worldPoint(x, y)
  return x * CELL + CELL / 2, y * CELL + CELL / 2
end

local function distanceSquared(a, b)
  local dx, dy = a.x - b.x, a.y - b.y
  return dx * dx + dy * dy
end

local function sameCell(a, b)
  return a.x == b.x and a.y == b.y
end

local function spacedPick(candidates, count, spacing, mapId, salt)
  if count <= 0 or #candidates == 0 then return {} end
  table.sort(candidates, function(a, b)
    local ha = stableHash(mapId, a.x, a.y, salt)
    local hb = stableHash(mapId, b.x, b.y, salt)
    if ha ~= hb then return ha < hb end
    if a.y ~= b.y then return a.y < b.y end
    return a.x < b.x
  end)
  local out, minD2 = {}, spacing * spacing
  for _, candidate in ipairs(candidates) do
    local clear = true
    for _, chosen in ipairs(out) do
      if distanceSquared(candidate, chosen) < minD2 then clear = false break end
    end
    if clear then
      out[#out + 1] = candidate
      if #out >= count then break end
    end
  end

  -- Small ponds/caves may not have enough room to satisfy both the requested
  -- count and the preferred spacing. In that case density wins: fill the
  -- remaining slots with the next deterministic candidates instead of
  -- silently deleting landmark identity from compact maps.
  if #out < count then
    for _, candidate in ipairs(candidates) do
      local already = false
      for _, chosen in ipairs(out) do
        if sameCell(candidate, chosen) then already = true break end
      end
      if not already then
        out[#out + 1] = candidate
        if #out >= count then break end
      end
    end
  end
  return out
end

function SeabedLandmarks.new(mod, atlas, rules)
  return setmetatable({ mod = mod, atlas = atlas, rules = rules or {} }, SeabedLandmarks)
end

function SeabedLandmarks:ruleFor(entry)
  local defaults = self.rules.defaults and self.rules.defaults[entry.profileName] or {}
  local selected = self.rules.maps and self.rules.maps[entry.id] or nil
  if not selected then
    for _, rule in ipairs(self.rules.patterns or {}) do
      if tostring(entry.id):find(rule.find, 1, true) then selected = rule break end
    end
  end
  return merge(defaults, selected or { type = entry.profileName })
end

function SeabedLandmarks:candidates(entry, mode)
  local out = {}
  for key in pairs(entry.water or {}) do
    local x, y = key:match("^(%-?%d+):(%-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    local shore = entry.shoreDistance[key] or 0
    local floor = entry.floorDepth[key] or 0
    local keep = false
    if mode == "shore" then keep = shore <= 1
    elseif mode == "mid" then keep = shore >= 2 and shore <= 5
    elseif mode == "deep" then keep = shore >= 4
    elseif mode == "all" then keep = true end
    if keep then out[#out + 1] = { x = x, y = y, shore = shore, floor = floor } end
  end
  if mode == "deep" then
    table.sort(out, function(a, b)
      if a.floor ~= b.floor then return a.floor > b.floor end
      return stableHash(entry.id, a.x, a.y, 991) < stableHash(entry.id, b.x, b.y, 991)
    end)
  end
  return out
end

local function addDistrict(scene, name, entry)
  if not name then return end
  scene.districts = scene.districts or {}
  scene.districts[#scene.districts + 1] = {
    id = "generated_identity",
    name = name,
    x0 = 0, x1 = entry.width * CELL,
    z0 = 0, z1 = entry.height * CELL,
  }
end

-- SceneDecor already knows how to render column rings, rock spires, arches and
-- broken walls. The landmark pass intentionally reuses those stable primitives
-- instead of adding renderer-specific geometry to the atlas layer.
local function addColumn(scene, x, z, height, material, width)
  scene.structures[#scene.structures + 1] = {
    kind = "column_ring", x = x, z = z,
    radius = 0, count = 1, height = height,
    material = material or "ruinStone",
    solid = false,
    generatedWidth = width,
  }
end

function SeabedLandmarks:addHarbor(entry, scene, rule)
  local shore = spacedPick(self:candidates(entry, "shore"), rule.shoreStructures or 12, 2.2, entry.id, 101)
  local mid = spacedPick(self:candidates(entry, "mid"), rule.anchors or 2, 5.0, entry.id, 117)
  local deep = spacedPick(self:candidates(entry, "deep"), rule.deepStructures or 3, 5.5, entry.id, 139)

  for index, cell in ipairs(shore) do
    local x, z = worldPoint(cell.x, cell.y)
    addColumn(scene, x, z, 58 + (index % 4) * 14,
      index % 4 == 0 and "darkStone" or "ruinStone")
  end
  for index, cell in ipairs(mid) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "broken_wall", x = x, z = z,
      width = 24 + index * 4, height = 18 + index * 2,
      thickness = 7, material = "darkStone",
    }
  end
  for index, cell in ipairs(deep) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = index % 2 == 0 and "broken_wall" or "column_ring",
      x = x, z = z,
      width = 48, height = 34 + index * 3,
      thickness = 9, radius = 0, count = 1,
      material = "darkStone",
    }
  end
end

function SeabedLandmarks:addVolcanic(entry, scene, rule)
  local deep = spacedPick(self:candidates(entry, "deep"), rule.deepStructures or 8, 4.5, entry.id, 211)
  local vents = spacedPick(self:candidates(entry, "deep"), rule.vents or 4, 6.0, entry.id, 227)
  local shore = spacedPick(self:candidates(entry, "shore"), rule.shoreStructures or 4, 4.0, entry.id, 241)

  for index, cell in ipairs(deep) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "spire", x = x, z = z,
      height = 70 + (index % 5) * 24,
      radius = 12 + (index % 3) * 4,
      material = "darkStone",
    }
  end
  for _, cell in ipairs(vents) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "spire", x = x, z = z,
      height = 44 + (cell.floor % 48), radius = 10,
      material = "darkStone",
    }
    scene.bubbleVents[#scene.bubbleVents + 1] = {
      x = x, z = z, count = 9,
      height = math.min(420, math.max(160, cell.floor - 30)), speed = 17,
    }
  end
  for _, cell in ipairs(shore) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "rock_arch", x = x, z = z,
      width = 70, height = 44, thickness = 12, material = "darkStone",
    }
  end
end

function SeabedLandmarks:addCave(entry, scene, rule)
  local deep = spacedPick(self:candidates(entry, "deep"), rule.deepStructures or 7, 4.2, entry.id, 307)
  local ice = spacedPick(self:candidates(entry, "all"), rule.iceColumns or 9, 3.4, entry.id, 331)
  local shore = spacedPick(self:candidates(entry, "shore"), rule.shoreStructures or 4, 5.0, entry.id, 349)

  for index, cell in ipairs(deep) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = index % 3 == 0 and "rock_arch" or "spire",
      x = x, z = z,
      width = 74, height = 62 + (index % 4) * 18,
      thickness = 14, radius = 13, material = "darkStone",
    }
  end
  for index, cell in ipairs(ice) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "spire", x = x, z = z,
      height = 38 + (index % 5) * 18,
      radius = 7 + (index % 3) * 2,
      material = "crystal",
    }
  end
  for _, cell in ipairs(shore) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.crystalClusters[#scene.crystalClusters + 1] = {
      x = x, z = z, count = 5, radius = 18, height = 36,
    }
  end
end

function SeabedLandmarks:addOcean(entry, scene, rule)
  local deep = spacedPick(self:candidates(entry, "deep"), rule.deepStructures or 5, 6.0, entry.id, 401)
  local shore = spacedPick(self:candidates(entry, "shore"), rule.shoreStructures or 3, 5.0, entry.id, 419)
  for index, cell in ipairs(deep) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = index % 3 == 0 and "rock_arch" or "spire",
      x = x, z = z,
      width = 88, height = 72 + (index % 4) * 22,
      thickness = 14, radius = 15, material = "reefRock",
    }
  end
  for _, cell in ipairs(shore) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "rock_arch", x = x, z = z,
      width = 58, height = 38, thickness = 10, material = "reefRock",
    }
  end
end

function SeabedLandmarks:addFreshwater(entry, scene, rule)
  local shore = spacedPick(self:candidates(entry, "shore"), rule.shoreStructures or 4, 4.0, entry.id, 503)
  local deep = spacedPick(self:candidates(entry, "deep"), rule.deepStructures or 2, 6.0, entry.id, 521)
  for index, cell in ipairs(shore) do
    local x, z = worldPoint(cell.x, cell.y)
    addColumn(scene, x, z, 26 + (index % 4) * 8, "darkStone")
  end
  for _, cell in ipairs(deep) do
    local x, z = worldPoint(cell.x, cell.y)
    scene.structures[#scene.structures + 1] = {
      kind = "spire", x = x, z = z,
      height = 42, radius = 10, material = "reefRock",
    }
  end
end

function SeabedLandmarks:addMarsh(entry, scene, rule)
  local shore = spacedPick(self:candidates(entry, "shore"), rule.shoreStructures or 5, 3.0, entry.id, 601)
  for index, cell in ipairs(shore) do
    local x, z = worldPoint(cell.x, cell.y)
    addColumn(scene, x, z, 24 + (index % 4) * 7, "darkStone")
  end
end

function SeabedLandmarks:applyOne(entry, scene)
  if not (entry and scene) then return end
  scene.structures = scene.structures or {}
  scene.bubbleVents = scene.bubbleVents or {}
  scene.crystalClusters = scene.crystalClusters or {}
  local rule = self:ruleFor(entry)
  addDistrict(scene, rule.name, entry)
  local kind = rule.type or entry.profileName
  if kind == "harbor" then self:addHarbor(entry, scene, rule)
  elseif kind == "volcanic" then self:addVolcanic(entry, scene, rule)
  elseif kind == "cave" then self:addCave(entry, scene, rule)
  elseif kind == "freshwater" then self:addFreshwater(entry, scene, rule)
  elseif kind == "marsh" then self:addMarsh(entry, scene, rule)
  else self:addOcean(entry, scene, rule) end
end

function SeabedLandmarks:apply(scenes)
  local count = 0
  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    local scene = scenes and scenes["atlas:" .. surfaceId]
    if scene then self:applyOne(entry, scene); count = count + 1 end
  end
  if self.mod.log then self.mod.log:info("Applied seabed landmark identity to %d generated maps", count) end
  return count
end

return SeabedLandmarks
