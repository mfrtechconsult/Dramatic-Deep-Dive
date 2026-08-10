local Game = require("src.core.Game")
local Assets = require("src.render.Assets")
local SpriteRenderer = require("src.render.SpriteRenderer")

local UnderwaterWildlife = {}
UnderwaterWildlife.__index = UnderwaterWildlife

local CELL = 16
local SPAWN_MIN_CELLS = 5
local SPAWN_MAX_CELLS = 18
local DESPAWN_CELLS = 28
local PLAYER_FLEE_PIXELS = 56

local DENSITY = {
  low = { cap = 6, cooldown = 2.6 },
  normal = { cap = 12, cooldown = 1.45 },
  rich = { cap = 20, cooldown = 0.80 },
}

local function optionValue(mod, key, default)
  if not (mod.options and mod.options.get) then return default end
  local ok, value = pcall(mod.options.get, mod.options, key)
  if not ok or value == nil then return default end
  return value
end

local function rand01()
  if love and love.math and love.math.random then return love.math.random() end
  return math.random()
end

local function randRange(a, b)
  return a + (b - a) * rand01()
end

local function randInt(a, b)
  a, b = math.floor(a), math.floor(b)
  if b <= a then return a end
  if love and love.math and love.math.random then return love.math.random(a, b) end
  return math.random(a, b)
end

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function removeValue(list, value)
  for i = #(list or {}), 1, -1 do
    if list[i] == value then table.remove(list, i) end
  end
end

local function facingFor(vx, vy, previous)
  local ax, ay = math.abs(vx or 0), math.abs(vy or 0)
  if ax < 0.01 and ay < 0.01 then return previous or "right" end
  if ax >= ay then return vx < 0 and "left" or "right" end
  return vy < 0 and "up" or "down"
end

local function shortestTurn(current, wanted)
  return (wanted - current + math.pi) % (math.pi * 2) - math.pi
end

local function dexHeightFeet(species)
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[species]
  local dex = def and def.dexEntry or nil
  if not dex then return 2 end
  local feet = (tonumber(dex.heightFt) or 0) + (tonumber(dex.heightIn) or 0) / 12
  return feet > 0 and feet or 2
end

-- Pokédex height drives the actual visual size. The square-root curve keeps
-- tiny species readable while still making large sea Pokémon unmistakably
-- larger. Rough examples: ~1 ft -> 1.16x, ~3 ft -> 1.44x, ~8 ft -> 1.85x,
-- 20+ ft -> capped at 2.40x.
local function speciesVisualScale(species)
  local feet = math.max(0.5, dexHeightFeet(species))
  return clamp(0.78 + 0.38 * math.sqrt(feet), 0.85, 2.40)
end

local function speciesSpeedScale(species)
  local feet = dexHeightFeet(species)
  return clamp(0.92 + feet * 0.025, 0.92, 1.35)
end

local function cloneScaledSprite(source, species, scale)
  if not (source and source.def) then return source end
  local def = {}
  for key, value in pairs(source.def) do def[key] = value end
  def.id = tostring(def.id or "DEEP_DIVE") .. "_WILDLIFE_" .. tostring(species)
  def.deepDiveWorldScale = scale
  local sprite = SpriteRenderer.new(def, "deep_dive_wildlife_" .. tostring(species))
  if source.image then sprite.image = source.image end
  return sprite
end

function UnderwaterWildlife.new(mod, controller, registry, sprites, definitions)
  return setmetatable({
    mod = mod,
    controller = controller,
    registry = registry,
    sprites = sprites,
    definitions = definitions or {},
    swimmers = {},
    serial = 0,
    cooldown = 0,
    mapId = nil,
    spawned = 0,
    consumed = 0,
  }, UnderwaterWildlife)
end

function UnderwaterWildlife:density()
  return DENSITY[optionValue(self.mod, "ocean_density", "rich")] or DENSITY.rich
end

function UnderwaterWildlife:enabled()
  return optionValue(self.mod, "ocean_life", true) == true
end

function UnderwaterWildlife:bandFor(mapId, depth)
  local bands = self.definitions[mapId]
  if not bands then return nil end
  depth = tonumber(depth) or 0
  for _, band in ipairs(bands) do
    if depth >= (band.minDepth or 0) and depth < (band.maxDepth or math.huge) then
      return band
    end
  end
  return bands[#bands]
end

function UnderwaterWildlife:remove(swimmer, overworld)
  if not swimmer then return end
  swimmer.dead = true
  overworld = overworld or Game.overworld
  if overworld and overworld.entities then removeValue(overworld.entities, swimmer) end
  removeValue(self.swimmers, swimmer)
end

function UnderwaterWildlife:clear()
  local ow = Game.overworld
  for i = #self.swimmers, 1, -1 do
    local swimmer = self.swimmers[i]
    swimmer.dead = true
    if ow and ow.entities then removeValue(ow.entities, swimmer) end
    table.remove(self.swimmers, i)
  end
  self.mapId = nil
  self.cooldown = 0
end

function UnderwaterWildlife:pickSlot(band)
  local slots = band and band.slots or nil
  if not slots or #slots == 0 then return nil end

  -- Favour an existing same-species swimmer often enough to form readable
  -- little schools, while still using the encounter table as the ecology.
  if #self.swimmers > 0 and rand01() < 0.42 then
    local leader = self.swimmers[randInt(1, #self.swimmers)]
    if leader and not leader.dead then
      for _, slot in ipairs(slots) do
        if slot.species == leader.species then
          return { species = slot.species, level = slot.level }, leader
        end
      end
    end
  end

  local slot = slots[randInt(1, #slots)]
  if not slot then return nil end
  return { species = slot.species, level = slot.level }, nil
end

function UnderwaterWildlife:depthBounds(volume, band, cellX, cellY)
  local maxDepth = self.registry:maxDepthAt(volume.mapId, cellX, cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  local lo = math.max(volume.minDepth or 0, band and band.minDepth or 0)
  local hiBand = band and band.maxDepth or math.huge
  if hiBand < math.huge then hiBand = hiBand - 1 end
  local hi = math.min(maxDepth, hiBand)
  if hi <= lo + 6 then return nil end
  return lo, hi
end

function UnderwaterWildlife:spawnPosition(volume, band, player, leader)
  for _ = 1, 36 do
    local cellX, cellY
    if leader and not leader.dead and rand01() < 0.7 then
      cellX = leader.cellX + randInt(-3, 3)
      cellY = leader.cellY + randInt(-3, 3)
    else
      local angle = randRange(0, math.pi * 2)
      local radius = randRange(SPAWN_MIN_CELLS, SPAWN_MAX_CELLS)
      cellX = math.floor(player.cellX + math.cos(angle) * radius + 0.5)
      cellY = math.floor(player.cellY + math.sin(angle) * radius + 0.5)
    end

    if self.registry:contains(volume.mapId, cellX, cellY) then
      local lo, hi = self:depthBounds(volume, band, cellX, cellY)
      if lo then
        local depth
        if leader and not leader.dead then
          depth = clamp(leader.depth + randRange(-22, 22), lo, hi)
        else
          local playerDepth = self.controller.state.depth or volume.defaultDepth
          depth = clamp(playerDepth + randRange(-72, 72), lo, hi)
          if rand01() < 0.25 then depth = randRange(lo, hi) end
        end
        return cellX * CELL + randRange(1, CELL - 1),
               cellY * CELL + randRange(1, CELL - 1),
               depth, lo, hi
      end
    end
  end
  return nil
end

function UnderwaterWildlife:makeEntity(pick, sprite, volume, band, px, py, depth, lo, hi)
  self.serial = self.serial + 1
  local service = self
  local visualScale = speciesVisualScale(pick.species)
  sprite = cloneScaledSprite(sprite, pick.species, visualScale)
  local swimmer = {
    id = "dramatic_deep_dive_wildlife_" .. tostring(self.serial),
    deepDiveWildlife = true,
    passable = true,
    species = pick.species,
    level = pick.level,
    sprite = sprite,
    px = px,
    py = py,
    cellX = math.floor(px / CELL),
    cellY = math.floor(py / CELL),
    depth = depth,
    targetDepth = depth,
    bandMin = lo,
    bandMax = hi,
    heading = randRange(0, math.pi * 2),
    visualScale = visualScale,
    speed = randRange(17, 29) * speciesSpeedScale(pick.species),
    t = randRange(0, 8),
    turnTimer = randRange(0.6, 2.4),
    depthTimer = randRange(1.5, 4.0),
    facing = "right",
    dead = false,
  }

  function swimmer:lift()
    local activeVolume = service.controller.state.volume
    if not activeVolume then return 0 end
    return math.max(0, (activeVolume.surfaceHeight or 0) - (self.depth or 0))
  end

  function swimmer:phase()
    return math.floor((self.t or 0) * 4.5) % 2
  end

  function swimmer:pose()
    return self.sprite, self.px, self.py - self:lift(), self.facing,
      self:phase(), false, false
  end

  function swimmer:draw(camX, camY)
    if not (self.sprite and self.sprite.draw) then return end
    local scale = tonumber(self.visualScale) or 1
    local visualY = self.py - self:lift()
    if love and love.graphics and scale ~= 1 then
      -- Scale around the sprite's feet/centre so large Pokémon grow upward
      -- and outward instead of sliding around the world as their size changes.
      local anchorX = self.px + 8 - (camX or 0)
      local anchorY = visualY + 16 - (camY or 0)
      love.graphics.push()
      love.graphics.translate(anchorX, anchorY)
      love.graphics.scale(scale, scale)
      love.graphics.translate(-anchorX, -anchorY)
      self.sprite:draw(self.px, visualY, camX, camY,
        self.facing, self:phase(), false)
      love.graphics.pop()
      return
    end
    self.sprite:draw(self.px, visualY, camX, camY,
      self.facing, self:phase(), false)
  end

  return swimmer
end

function UnderwaterWildlife:spawn()
  local state = self.controller and self.controller.state
  local volume = state and state.active and state.volume or nil
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (volume and player and map and map.id == volume.mapId) then return false end

  local band = self:bandFor(map.id, state.depth)
  local pick, leader = self:pickSlot(band)
  if not pick then return false end

  local def = Game.data and Game.data.pokemon and Game.data.pokemon[pick.species]
  local dex = def and tonumber(def.dex)
  if not dex then return false end
  local sprite = self.sprites and self.sprites:build(pick.species, dex) or nil
  if not sprite then return false end

  local px, py, depth, lo, hi = self:spawnPosition(volume, band, player, leader)
  if not px then return false end
  local swimmer = self:makeEntity(pick, sprite, volume, band, px, py, depth, lo, hi)
  self.swimmers[#self.swimmers + 1] = swimmer
  ow.entities = ow.entities or {}
  ow.entities[#ow.entities + 1] = swimmer
  self.spawned = self.spawned + 1
  return true
end

function UnderwaterWildlife:steer(swimmer, wanted, maxTurn)
  local diff = shortestTurn(swimmer.heading, wanted)
  diff = clamp(diff, -maxTurn, maxTurn)
  swimmer.heading = swimmer.heading + diff
end

function UnderwaterWildlife:tickSwimmer(swimmer, dt, volume, player)
  swimmer.t = swimmer.t + dt
  swimmer.turnTimer = swimmer.turnTimer - dt
  swimmer.depthTimer = swimmer.depthTimer - dt

  local dxPlayer = swimmer.px - (player.px or player.cellX * CELL)
  local dyPlayer = swimmer.py - (player.py or player.cellY * CELL)
  local playerDistance = math.sqrt(dxPlayer * dxPlayer + dyPlayer * dyPlayer)
  local speedBoost = 1
  if playerDistance < PLAYER_FLEE_PIXELS and playerDistance > 0.1 then
    self:steer(swimmer, math.atan2(dyPlayer, dxPlayer), math.rad(145) * dt)
    speedBoost = 1.35
  elseif swimmer.turnTimer <= 0 then
    swimmer.turnTimer = randRange(0.7, 2.3)
    swimmer.heading = swimmer.heading + randRange(-0.75, 0.75)
  end

  -- Mild same-species schooling: nearby companions pull headings together,
  -- but never strongly enough to turn the ocean into synchronized trains.
  local avgSin, avgCos, peers = 0, 0, 0
  for _, other in ipairs(self.swimmers) do
    if other ~= swimmer and not other.dead and other.species == swimmer.species then
      local dx, dy = other.px - swimmer.px, other.py - swimmer.py
      if math.abs(dx) + math.abs(dy) < 120 then
        avgSin = avgSin + math.sin(other.heading)
        avgCos = avgCos + math.cos(other.heading)
        peers = peers + 1
      end
    end
  end
  if peers > 0 then
    self:steer(swimmer, math.atan2(avgSin, avgCos), math.rad(25) * dt)
  end

  local step = swimmer.speed * speedBoost * dt
  local nx = swimmer.px + math.cos(swimmer.heading) * step
  local ny = swimmer.py + math.sin(swimmer.heading) * step
  local cellX = math.floor((nx + CELL / 2) / CELL)
  local cellY = math.floor((ny + CELL / 2) / CELL)
  local allowed = self.registry:contains(volume.mapId, cellX, cellY)
  if allowed and self.controller.voxelRenderer
      and self.controller.voxelRenderer.blocksCell then
    local ok, blocked = pcall(self.controller.voxelRenderer.blocksCell,
      self.controller.voxelRenderer, volume.mapId, cellX, cellY, swimmer.depth)
    if ok and blocked then allowed = false end
  end

  if allowed then
    local lo, hi = self:depthBounds(volume,
      self:bandFor(volume.mapId, swimmer.depth), cellX, cellY)
    if lo then
      swimmer.px, swimmer.py = nx, ny
      swimmer.cellX, swimmer.cellY = cellX, cellY
      swimmer.bandMin, swimmer.bandMax = lo, hi
      swimmer.targetDepth = clamp(swimmer.targetDepth, lo, hi)
    else
      allowed = false
    end
  end
  if not allowed then
    swimmer.heading = swimmer.heading + math.pi + randRange(-0.45, 0.45)
    swimmer.turnTimer = randRange(0.5, 1.2)
  end

  if swimmer.depthTimer <= 0 then
    swimmer.depthTimer = randRange(1.8, 4.8)
    local lo, hi = swimmer.bandMin, swimmer.bandMax
    if hi and lo and hi > lo then
      swimmer.targetDepth = clamp(swimmer.depth + randRange(-55, 55), lo, hi)
      if rand01() < 0.18 then swimmer.targetDepth = randRange(lo, hi) end
    end
  end
  local depthDelta = swimmer.targetDepth - swimmer.depth
  local depthStep = 28 * dt
  if math.abs(depthDelta) <= depthStep then swimmer.depth = swimmer.targetDepth
  else swimmer.depth = swimmer.depth + (depthDelta < 0 and -depthStep or depthStep) end

  local vx = math.cos(swimmer.heading) * swimmer.speed
  local vy = math.sin(swimmer.heading) * swimmer.speed
  swimmer.facing = facingFor(vx, vy, swimmer.facing)
end

function UnderwaterWildlife:update(dt)
  if not self:enabled() then
    if #self.swimmers > 0 then self:clear() end
    return
  end

  local state = self.controller and self.controller.state
  local volume = state and state.active and state.volume or nil
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (volume and ow and player and map and map.id == volume.mapId) then
    if #self.swimmers > 0 then self:clear() end
    return
  end

  if self.mapId ~= map.id then
    self:clear()
    self.mapId = map.id
    self.cooldown = 0
  end

  for i = #self.swimmers, 1, -1 do
    local swimmer = self.swimmers[i]
    self:tickSwimmer(swimmer, dt, volume, player)
    local dx = swimmer.cellX - player.cellX
    local dy = swimmer.cellY - player.cellY
    local tooFar = math.abs(dx) + math.abs(dy) > DESPAWN_CELLS
    local wrongDepth = math.abs((swimmer.depth or 0) - (state.depth or 0)) > 260
    if swimmer.dead or tooFar or wrongDepth then
      if ow.entities then removeValue(ow.entities, swimmer) end
      table.remove(self.swimmers, i)
    end
  end

  local density = self:density()
  self.cooldown = math.max(0, (self.cooldown or 0) - dt)
  if #self.swimmers < density.cap and self.cooldown <= 0 then
    self:spawn()
    -- Seed the first handful quickly so entering a huge ocean never looks
    -- empty, then settle into a low background replenishment rate.
    if #self.swimmers < math.min(7, density.cap) then
      self.cooldown = 0.12
    else
      self.cooldown = density.cooldown
    end
  end
end

function UnderwaterWildlife:consumeNearby(species)
  if not species then return false end
  local ow = Game.overworld
  local player = ow and ow.player
  if not player then return false end
  local best, bestDistance
  for _, swimmer in ipairs(self.swimmers) do
    if not swimmer.dead and swimmer.species == species then
      local d = math.abs(swimmer.cellX - player.cellX) + math.abs(swimmer.cellY - player.cellY)
      if d <= 6 and (not bestDistance or d < bestDistance) then
        best, bestDistance = swimmer, d
      end
    end
  end
  if not best then return false end
  self:remove(best, ow)
  self.consumed = self.consumed + 1
  return true
end

function UnderwaterWildlife:installVoxelScaleBridge()
  local voxelRenderer = self.controller and self.controller.voxelRenderer
  if not (voxelRenderer and voxelRenderer.providerModule) then return false end
  local SpriteBillboards = voxelRenderer:providerModule("SpriteBillboards")
  local Voxel3D = voxelRenderer:providerModule("Voxel3D")
  if not (SpriteBillboards and Voxel3D and Voxel3D.pushQuad and Voxel3D.newMesh) then
    return false
  end
  if SpriteBillboards.dramaticDeepDiveScaleHook then return true end

  local innerMesh = SpriteBillboards.mesh
  local innerShadow = SpriteBillboards.shadowQuad or innerMesh
  local innerInvalidate = SpriteBillboards.invalidate
  local scaledMeshes = {}

  local function buildScaled(def, frame, scale)
    local key = tostring(def.image) .. "#" .. tostring(frame) .. "#ddd#"
      .. string.format("%.3f", scale)
    if scaledMeshes[key] ~= nil then return scaledMeshes[key] or nil end

    local ok, mesh = pcall(function()
      local img = Assets.image(def.image)
      local iw, ih = img:getDimensions()
      local fy = (tonumber(frame) or 0) * 16
      if fy + 16 > ih then fy = 0 end
      local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
      local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
      local half = 8 * scale
      local height = 16 * scale
      -- Keep x=8 as the foot centre used by VoxelScene.billboardMatrix.
      local verts = {
        { 8-half, 0,      0, u0, v1, 1 },
        { 8+half, 0,      0, u1, v1, 1 },
        { 8+half, height, 0, u1, v0, 1 },
        { 8-half, height, 0, u0, v0, 1 },
      }
      local indices = {}
      Voxel3D.pushQuad(indices, 0)
      return Voxel3D.newMesh(verts, indices)
    end)
    scaledMeshes[key] = ok and mesh or false
    return scaledMeshes[key] or nil
  end

  local function scaledOr(inner, def, frame)
    local scale = def and tonumber(def.deepDiveWorldScale) or nil
    if scale and math.abs(scale - 1) > 0.01 then
      return buildScaled(def, frame, scale) or inner(def, frame)
    end
    return inner(def, frame)
  end

  SpriteBillboards.mesh = function(def, frame)
    return scaledOr(innerMesh, def, frame)
  end
  SpriteBillboards.shadowQuad = function(def, frame)
    return scaledOr(innerShadow, def, frame)
  end
  SpriteBillboards.invalidate = function(...)
    for key, mesh in pairs(scaledMeshes) do
      if mesh and mesh.release then pcall(mesh.release, mesh) end
      scaledMeshes[key] = nil
    end
    if innerInvalidate then return innerInvalidate(...) end
  end
  SpriteBillboards.dramaticDeepDiveScaleHook = true
  return true
end

function UnderwaterWildlife:install()
  local service = self
  self:installVoxelScaleBridge()
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then
      service:update(tonumber(dt) or (1 / 60))
    elseif #service.swimmers > 0 and not (service.controller.state and service.controller.state.active) then
      service:clear()
    end
    return result
  end, 70)

  self.mod.events:on("mod.DRAMATIC_DEEP_DIVE.surfaced", function()
    service:clear()
  end)
  self.mod.events:on("map.exited", function()
    service:clear()
  end)
  return true
end

function UnderwaterWildlife:stats()
  return {
    active = #self.swimmers,
    spawned = self.spawned,
    consumed = self.consumed,
    density = optionValue(self.mod, "ocean_density", "rich"),
  }
end

return UnderwaterWildlife
