local SeabedGenerator = {}
SeabedGenerator.__index = SeabedGenerator

local CELL = 16

local function cellKey(x, y) return tostring(x) .. ":" .. tostring(y) end

local function stableHash(mapId, x, y, salt)
  local value = tonumber(salt) or 0
  local text = tostring(mapId or "")
  for i = 1, #text do value = (value * 33 + text:byte(i)) % 2147483647 end
  value = (value + (x + 17) * 73856093 + (y + 29) * 19349663) % 2147483647
  return value
end

local function maskBlock(entry, bx, by)
  local mask = 0
  local cells = {
    { bx * 2,     by * 2,     1 },
    { bx * 2 + 1, by * 2,     2 },
    { bx * 2,     by * 2 + 1, 4 },
    { bx * 2 + 1, by * 2 + 1, 8 },
  }
  for _, c in ipairs(cells) do
    if entry.water[cellKey(c[1], c[2])] then mask = mask + c[3] end
  end
  return 16 + mask
end

local function safeLabel(id)
  return ("DramaticDeepDiveSeabed_" .. tostring(id)):gsub("[^%w_]", "_")
end

local function encounterSlots(species, level)
  local slots = {}
  if not species or #species == 0 then return slots end
  for i = 1, 10 do
    slots[i] = { level = level + math.floor((i - 1) / 3), species = species[((i - 1) % #species) + 1] }
  end
  return slots
end

function SeabedGenerator.new(mod, atlas, profileData)
  return setmetatable({ mod = mod, atlas = atlas, profileData = profileData or {} }, SeabedGenerator)
end

function SeabedGenerator:mapDefinition(entry, index)
  local blocks = {}
  for by = 0, entry.def.height - 1 do
    for bx = 0, entry.def.width - 1 do blocks[#blocks + 1] = maskBlock(entry, bx, by) end
  end

  local connections = {}
  for direction, seam in pairs(entry.seams or {}) do
    connections[direction] = { map = seam.underwaterMap, offset = seam.offset }
  end

  return {
    id = entry.underwaterMapId,
    label = safeLabel(entry.id),
    index = 2000 + index,
    tileset = "DDD_UNDERWATER",
    width = entry.def.width,
    height = entry.def.height,
    borderBlock = 16,
    outdoor = false,
    region = "DRAMATIC_DEEP_DIVE",
    blocks = blocks,
    connections = connections,
    warps = {}, objects = {}, signs = {},
    dramaticDeepDiveSurfaceMap = entry.id,
    dramaticDeepDiveBiome = entry.profileName,
  }
end

function SeabedGenerator:volumeDefinition(entry)
  local p = entry.profile
  local maxFloor = 0
  for _, depth in pairs(entry.floorDepth) do if depth > maxFloor then maxFloor = depth end end
  local connectedEdges = {}
  for direction in pairs(entry.seams or {}) do connectedEdges[direction] = true end
  return {
    mapId = entry.underwaterMapId,
    zoneId = "atlas:" .. entry.id,
    surfaceMapId = entry.id,
    biome = entry.profileName,
    floorColor = p.floorColor,
    surfaceHeight = p.surfaceHeight or 680,
    minDepth = p.minDepth or 20,
    defaultDepth = p.defaultDepth or 72,
    defaultFloorDepth = math.max(maxFloor, p.nearFloor or 110),
    seabedClearance = p.seabedClearance or 8,
    cellRuns = entry.cellRuns,
    depthRuns = entry.depthRuns,
    surfaceRuns = entry.cellRuns,
    widthCells = entry.width,
    heightCells = entry.height,
    connectedEdges = connectedEdges,
  }
end

function SeabedGenerator:diveZone(entry)
  local links = {}
  for y, runs in pairs(entry.cellRuns or {}) do
    for runIndex, run in ipairs(runs) do
      links[#links + 1] = {
        id = string.format("atlas_%s_%d_%d", entry.id:lower(), y, runIndex),
        surface = { mapId = entry.id, x = run.x0, y = y },
        underwater = { mapId = entry.underwaterMapId, x = run.x0, y = y },
        width = run.x1 - run.x0 + 1,
        height = 1,
      }
    end
  end
  table.sort(links, function(a, b)
    if a.surface.y ~= b.surface.y then return a.surface.y < b.surface.y end
    return a.surface.x < b.surface.x
  end)
  return {
    requiredBadge = "VOLCANOBADGE",
    underwaterMapId = entry.underwaterMapId,
    submergedMaps = { entry.underwaterMapId },
    links = links,
    generated = true,
    surfaceMapId = entry.id,
  }
end

function SeabedGenerator:encounters(entry)
  local ecology = self.profileData.ecology and self.profileData.ecology[entry.profile.ecology or entry.profileName]
  if not ecology then ecology = self.profileData.ecology and self.profileData.ecology.ocean end
  if not ecology then return {} end
  local maxDepth = entry.profile.maxFloor or 500
  local shallowEnd = math.max(80, math.floor(maxDepth * 0.30))
  local midEnd = math.max(shallowEnd + 70, math.floor(maxDepth * 0.62))
  local base = entry.profileName == "marsh" and 16
    or entry.profileName == "freshwater" and 18
    or entry.profileName == "harbor" and 20
    or entry.profileName == "cave" and 27
    or entry.profileName == "volcanic" and 29
    or entry.profileName == "ocean" and 25
    or 21
  return {
    { id = entry.profileName .. "_shallows", minDepth = 0, maxDepth = shallowEnd, rate = 6,
      slots = encounterSlots(ecology.shallow, base) },
    { id = entry.profileName .. "_midwater", minDepth = shallowEnd, maxDepth = midEnd, rate = 5,
      slots = encounterSlots(ecology.mid, base + 3) },
    { id = entry.profileName .. "_deep", minDepth = midEnd, maxDepth = 9999, rate = 4,
      slots = encounterSlots(ecology.deep, base + 6) },
  }
end

function SeabedGenerator:scene(entry)
  local p = entry.profile
  local count = math.max(1, entry.waterCount)
  local scene = {
    id = "atlas_scene:" .. entry.id,
    mapId = entry.underwaterMapId,
    districts = {}, structures = {}, scatter = {}, crystalClusters = {},
    bubbleVents = {}, lightShafts = {}, fishSchools = {},
  }
  local widthPx, heightPx = entry.width * CELL, entry.height * CELL
  local seed = 10000 + (entry.def.index or 0) * 37
  for kind, density in pairs(p.scatter or {}) do
    scene.scatter[#scene.scatter + 1] = {
      kind = kind,
      seed = seed + #scene.scatter * 101,
      count = math.max(2, math.floor(count * density)),
      x0 = 8, x1 = math.max(9, widthPx - 8),
      z0 = 8, z1 = math.max(9, heightPx - 8),
      minHeight = kind == "kelp" and 18 or 8,
      maxHeight = kind == "kelp" and 66 or kind == "rock" and 50 or 34,
    }
  end

  local bestKey, bestDistance = nil, -1
  for k, distance in pairs(entry.shoreDistance) do
    if distance > bestDistance then bestKey, bestDistance = k, distance end
  end
  if bestKey then
    local x, y = bestKey:match("^(%-?%d+):(%-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    local wx, wz = x * CELL + 8, y * CELL + 8
    scene.lightShafts[#scene.lightShafts + 1] = {
      x = wx, z = wz, width = 48, depth = 64,
      bottomDepth = math.min(entry.profile.maxFloor or 500, 260),
    }
    scene.fishSchools[#scene.fishSchools + 1] = {
      seed = seed + 900, x = wx, z = wz,
      depth = math.min(140, entry.profile.maxFloor or 180),
      count = math.min(12, math.max(5, math.floor(count / 28))),
      radius = math.min(130, math.max(48, math.sqrt(count) * 10)), speed = 0.24,
    }
    if p.vents then
      scene.bubbleVents[#scene.bubbleVents + 1] = {
        x = wx, z = wz, count = 8,
        height = math.min(360, entry.profile.maxFloor or 360), speed = 16,
      }
    end
  end
  return scene
end

local SALVAGE_ITEMS = {
  ocean = { "NUGGET", "RARE_CANDY", "MAX_REVIVE" },
  coastal = { "NUGGET", "MAX_POTION" },
  harbor = { "NUGGET", "PP_UP", "MAX_POTION" },
  volcanic = { "FULL_RESTORE", "RARE_CANDY", "NUGGET" },
  cave = { "RARE_CANDY", "MAX_REVIVE", "PP_UP" },
  freshwater = { "MAX_POTION", "FULL_HEAL" },
  marsh = { "FULL_HEAL", "MAX_POTION" },
}

function SeabedGenerator:salvage(entry)
  -- Tiny decorative pools still receive a seabed, but not treasure spam.
  if entry.waterCount < 36 then return {} end
  local desired = math.min(4, math.max(1, math.floor(entry.waterCount / 220) + 1))
  if entry.profileName == "freshwater" or entry.profileName == "marsh" then desired = math.min(desired, 2) end

  local candidates = {}
  for k in pairs(entry.water) do
    local x, y = k:match("^(%-?%d+):(%-?%d+)$")
    x, y = tonumber(x), tonumber(y)
    candidates[#candidates + 1] = {
      x = x, y = y,
      shore = entry.shoreDistance[k] or 0,
      floor = entry.floorDepth[k] or entry.profile.nearFloor or 80,
      hash = stableHash(entry.id, x, y, 1701),
    }
  end
  table.sort(candidates, function(a, b)
    if a.shore ~= b.shore then return a.shore > b.shore end
    if a.floor ~= b.floor then return a.floor > b.floor end
    return a.hash < b.hash
  end)

  local chosen = {}
  local spacing2 = 25
  for _, c in ipairs(candidates) do
    local clear = c.shore >= 1
    if clear then
      for _, other in ipairs(chosen) do
        local dx, dy = c.x - other.x, c.y - other.y
        if dx * dx + dy * dy < spacing2 then clear = false break end
      end
    end
    if clear then
      chosen[#chosen + 1] = c
      if #chosen >= desired then break end
    end
  end
  if #chosen == 0 and candidates[1] then chosen[1] = candidates[1] end

  local items = SALVAGE_ITEMS[entry.profileName] or SALVAGE_ITEMS.coastal
  local nodes = {}
  for i, c in ipairs(chosen) do
    local item = items[((stableHash(entry.id, c.x, c.y, 1901) + i) % #items) + 1]
    nodes[#nodes + 1] = {
      id = string.format("atlas_salvage_%s_%d", entry.id:lower(), i),
      x = c.x * CELL + CELL / 2,
      z = c.y * CELL + CELL / 2,
      depth = math.max(entry.profile.minDepth or 10,
        c.floor - (entry.profile.seabedClearance or 8) - 5),
      item = item,
      qty = 1,
      label = entry.profileName == "harbor" and "DEBRIS SIGNAL"
        or entry.profileName == "cave" and "CAVE SIGNAL"
        or entry.profileName == "volcanic" and "THERMAL SIGNAL"
        or "SEABED SIGNAL",
    }
  end
  return nodes
end

function SeabedGenerator:build()
  local out = {
    volumes = {}, dives = {}, encounters = {}, scenes = {}, setpieces = {}, salvage = {}, maps = {},
  }
  local ids = self.atlas:mapIds()
  for index, surfaceId in ipairs(ids) do
    local entry = self.atlas:surface(surfaceId)
    local map = self:mapDefinition(entry, index)
    if not self.mod.content.maps:get(map.id) then self.mod.content.maps:register(map.id, map) end
    local song = entry.profile.music
    if song then self.mod.content.map_songs:register(map.id, song) end
    out.maps[#out.maps + 1] = map
    out.volumes["atlas:" .. surfaceId] = self:volumeDefinition(entry)
    out.dives["atlas:" .. surfaceId] = self:diveZone(entry)
    local bands = self:encounters(entry)
    out.encounters[map.id] = bands
    -- The depth hook replaces this table while Deep Dive is active, but a
    -- real encounter record keeps vanilla's step/grass encounter cadence
    -- alive as the standalone fallback when Wilds of Kanto is absent.
    local first = bands[1]
    if first and not self.mod.content.encounters:get(map.id) then
      self.mod.content.encounters:register(map.id, {
        grass = { rate = first.rate or 5, slots = first.slots },
      })
    end
    out.scenes["atlas:" .. surfaceId] = self:scene(entry)
    out.salvage[map.id] = self:salvage(entry)
  end
  return out
end

return SeabedGenerator
