local Game = require("src.core.Game")
local Pipelines = require("src.render.Pipelines")
local Player = require("src.world.Player")
local OverworldState = require("src.world.OverworldController")
local Map = require("src.world.Map")
local Collision = require("src.world.Collision")
local Font = require("src.render.Font")
local Assets = require("src.render.Assets")
local SpriteRenderer = require("src.render.SpriteRenderer")

local DeepDive = {}
DeepDive.__index = DeepDive

local SAVE_KEY = "deepDiveSession"
local VOXEL_PIPELINE = "voxel"
local FIRST_PERSON_LEVEL = 6
local THIRD_PERSON_LEVEL = 7
local TRIGGER_THRESHOLD = 0.35
local DEPTH_HUD_SECONDS = 2.0
local RIDER_LIFT = 7
local RIDER_CROP_HEIGHT = 13
local RIDER_CROP_Y = 1
local RIDER_RUNTIME_DIR = "dramatic_deep_dive_runtime"
local BOOST_MAX_MULTIPLIER = 2.25
local BOOST_RAMP_UP = 3.2
local BOOST_RAMP_DOWN = 5.0
local unpackArgs = table.unpack or unpack

local VERTICAL_RATES = {
  slow = 24,
  normal = 48,
  fast = 76,
}

local OPTION_SCHEMA = {
  {
    key = "show_rider", type = "toggle", label = "SHOW RIDER", default = true,
    help = "Show the trainer riding the underwater Pokemon in third person.",
  },
  {
    key = "start_camera", type = "choice", label = "DIVE CAMERA", default = "third_person",
    choices = {
      { "Third Person", "third_person" },
      { "First Person", "first_person" },
      { "Keep 1ST/3RD", "keep" },
    },
    help = "Starting free camera. You may still switch between 1ST and 3RD underwater.",
  },
  {
    key = "depth_display", type = "choice", label = "DEPTH DISPLAY", default = "temporary",
    choices = {
      { "Temporary", "temporary" }, { "Always", "always" }, { "Off", "off" },
    },
    help = "When the continuous depth indicator is visible.",
  },
  {
    key = "vertical_speed", type = "choice", label = "VERTICAL SPEED", default = "normal",
    choices = {
      { "Slow", "slow" }, { "Normal", "normal" }, { "Fast", "fast" },
    },
    help = "L2/Page Down dives; R2/Page Up ascends.",
  },
  {
    key = "swim_boost", type = "toggle", label = "SWIM BOOST", default = true,
    help = "Hold B while moving for a smooth underwater speed boost.",
  },
  {
    key = "surface_hint", type = "toggle", label = "SURFACE HINT", default = true,
    help = "Show when SURFACE is available at the current location.",
  },
}

local function optionValue(mod, key, default)
  if not (mod.options and mod.options.get) then return default end
  local ok, value = pcall(mod.options.get, mod.options, key)
  if not ok or value == nil then return default end
  return value
end

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function contains(list, value)
  for _, item in ipairs(list or {}) do if item == value then return true end end
  return false
end

local function removeFromList(list, value)
  for index = #(list or {}), 1, -1 do
    if list[index] == value then table.remove(list, index) end
  end
end

local function monKnows(mon, moveId)
  for _, move in ipairs(mon and mon.moves or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end

local function keyDown(key)
  local keyboard = love and love.keyboard
  if not (keyboard and keyboard.isDown) then return false end
  local ok, down = pcall(keyboard.isDown, key)
  return ok and down == true
end

local function triggerDown(axis)
  local joystickApi = love and love.joystick
  if not (joystickApi and joystickApi.getJoysticks) then return false end
  local okList, joysticks = pcall(joystickApi.getJoysticks)
  if not okList or type(joysticks) ~= "table" then return false end
  for _, joystick in ipairs(joysticks) do
    local okPad, isPad = pcall(function()
      return joystick.isGamepad and joystick:isGamepad()
    end)
    if okPad and isPad then
      local okAxis, value = pcall(joystick.getGamepadAxis, joystick, axis)
      if okAxis and (tonumber(value) or 0) > TRIGGER_THRESHOLD then return true end
    end
  end
  return false
end

local function shallowCopy(source)
  local out = {}
  for key, value in pairs(source or {}) do out[key] = value end
  return out
end

local function safeAssetName(value)
  return tostring(value or "player"):gsub("[^%w_%-]", "_")
end

local function fileExists(path)
  return love and love.filesystem and love.filesystem.getInfo
    and love.filesystem.getInfo(path) ~= nil
end

function DeepDive.new(mod, registry, sprites, voxelRenderer, followerBridge, travel)
  return setmetatable({
    mod = mod,
    registry = registry,
    sprites = sprites,
    voxelRenderer = voxelRenderer,
    followerBridge = followerBridge,
    travel = travel,
    state = {
      active = false,
      depth = 0,
      targetDepth = 0,
      volume = nil,
      mount = nil,
      mountSpecies = nil,
      mountSprite = nil,
      riderSprite = nil,
      originalPlayerSprite = nil,
      riderEntity = nil,
      suspendedFollowers = nil,
      previousVoxelLevel = nil,
      hudTimer = 0,
      surfaceAvailable = false,
      saveTimer = 0,
      boost = 0,
    },
  }, DeepDive)
end

function DeepDive:log(fmt, ...)
  if self.mod.log then self.mod.log:info(fmt, ...) end
end

function DeepDive:providerModule(name)
  if not self.mod.find then return nil end
  local okFind, handle = pcall(self.mod.find, self.mod, "BATTLE_ART_VOXEL_FORK")
  local lib = okFind and handle and handle.exports and handle.exports.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, module = pcall(lib.require, name)
  return ok and module or nil
end

function DeepDive:voxelLevel()
  local ok, level = pcall(Pipelines.level, VOXEL_PIPELINE)
  return ok and tonumber(level) or 0
end

function DeepDive:isFirstPerson()
  return self:voxelLevel() == FIRST_PERSON_LEVEL
end

function DeepDive:isFreeCamera()
  local level = self:voxelLevel()
  return level == FIRST_PERSON_LEVEL or level == THIRD_PERSON_LEVEL
end

function DeepDive:ensureFreeCamera(firstEntry)
  if not Pipelines.get(VOXEL_PIPELINE) then return false end
  local state = self.state
  local current = self:voxelLevel()
  if state.previousVoxelLevel == nil then state.previousVoxelLevel = current end
  if current == FIRST_PERSON_LEVEL or current == THIRD_PERSON_LEVEL then return true end

  local mode = optionValue(self.mod, "start_camera", "third_person")
  local target = mode == "first_person" and FIRST_PERSON_LEVEL or THIRD_PERSON_LEVEL
  if mode == "keep" and firstEntry == false then target = THIRD_PERSON_LEVEL end
  Pipelines.setLevel(VOXEL_PIPELINE, target)
  return self:isFreeCamera()
end

function DeepDive:restoreVoxelMode()
  local previous = self.state.previousVoxelLevel
  self.state.previousVoxelLevel = nil
  if previous ~= nil and Pipelines.get(VOXEL_PIPELINE) then
    Pipelines.setLevel(VOXEL_PIPELINE, previous)
  end
end

function DeepDive:currentPosition()
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (player and map) then return nil end
  return map.id, player.cellX, player.cellY
end

function DeepDive:resolveVolume(event)
  local mapId, x, y = self:currentPosition()
  if not mapId and event then mapId, x, y = event.mapId, event.x, event.y end
  if not mapId then return nil end
  return self.registry:forMap(mapId, x, y) or self.registry:forMap(mapId)
end

function DeepDive:findDiveMount()
  local party = Game.save and Game.save.party or {}
  local remembered = self.state.mountSpecies
  if remembered then
    for _, mon in ipairs(party) do
      if mon.species == remembered and monKnows(mon, "DIVE") then return mon end
    end
  end
  for _, mon in ipairs(party) do if monKnows(mon, "DIVE") then return mon end end
  return nil
end

function DeepDive:buildMount(mon)
  if not mon then return nil, "no Pokemon knows DIVE" end
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[mon.species]
  local dex = def and tonumber(def.dex)
  if not dex then return nil, "Pokemon has no Pokedex number" end
  return self.sprites:build(mon.species, dex)
end

function DeepDive:buildRiderSprite(player)
  local source = player and player.sprite
  local sourceDef = source and source.def
  local sourcePath = sourceDef and sourceDef.image
  if not sourcePath then return source end
  if not (love and love.image and love.image.newImageData and love.filesystem
      and love.filesystem.createDirectory and Assets.imageData) then return source end

  local path = string.format("%s/rider_%s_c%d_y%d.png",
    RIDER_RUNTIME_DIR, safeAssetName(sourceDef.id or sourcePath),
    RIDER_CROP_HEIGHT, RIDER_CROP_Y)
  local ok = pcall(function()
    if not fileExists(path) then
      love.filesystem.createDirectory(RIDER_RUNTIME_DIR)
      local src = Assets.imageData(sourcePath)
      local sw, sh = src:getDimensions()
      if sw < 16 or sh < 16 then error("unexpected player sheet") end
      local frames = math.max(1, math.floor(sh / 16))
      if tonumber(sourceDef.frames) then frames = math.min(frames, tonumber(sourceDef.frames)) end
      local out = love.image.newImageData(16, 96)
      for frame = 0, 5 do
        local sourceFrame = math.min(frame, frames - 1)
        for y = 0, RIDER_CROP_HEIGHT - 1 do
          for x = 0, 15 do
            out:setPixel(x, frame * 16 + RIDER_CROP_Y + y,
              src:getPixel(x, sourceFrame * 16 + y))
          end
        end
      end
      local encoded = out:encode("png")
      local bytes = encoded and encoded.getString and encoded:getString() or encoded
      if type(bytes) ~= "string" or not love.filesystem.write(path, bytes) then
        error("rider write failed")
      end
    end
  end)
  if not ok then return source end
  local def = shallowCopy(sourceDef)
  def.id = "DEEP_DIVE_RIDER_" .. safeAssetName(sourceDef.id)
  def.image = path
  def.frames = 6
  def.walker = true
  return SpriteRenderer.new(def, "deep_dive_rider")
end

function DeepDive:saveState()
  local state = self.state
  if not state.active then self.mod.save:set(SAVE_KEY, nil) return end
  self.mod.save:set(SAVE_KEY, {
    active = true,
    mapId = state.volume and state.volume.mapId or nil,
    volumeId = state.volume and state.volume.id or nil,
    depth = state.depth,
    targetDepth = state.targetDepth,
    mountSpecies = state.mountSpecies,
    previousVoxelLevel = state.previousVoxelLevel,
  })
end

function DeepDive:loadSavedState(volume)
  local saved = self.mod.save:get(SAVE_KEY)
  if type(saved) ~= "table" or saved.active ~= true then return nil end
  if saved.mapId and saved.mapId ~= volume.mapId then return nil end
  return saved
end

function DeepDive:mountLift()
  local volume = self.state.volume
  if not volume then return 0 end
  return math.max(0, volume.surfaceHeight - (self.state.depth or volume.defaultDepth))
end

function DeepDive:swimBob()
  local player = Game.overworld and Game.overworld.player
  return player and math.sin((player.animClock or 0) * 0.16) * 0.65 or 0
end

function DeepDive:removeRider()
  local ow = Game.overworld
  local entity = self.state.riderEntity
  if ow and entity then
    removeFromList(ow.entities, entity)
    removeFromList(ow.npcs, entity)
  end
  self.state.riderEntity = nil
end

function DeepDive:riderOffset(player)
  if not player or self:isFirstPerson() then return 0, 0 end
  local delta = {
    up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
  }
  local d = delta[player.facing] or delta.down
  return -d[1] * 0.35, -d[2] * 0.35
end

function DeepDive:ensureRider()
  local state = self.state
  local ow = Game.overworld
  local player = ow and ow.player
  if not (state.active and player and state.riderSprite
      and optionValue(self.mod, "show_rider", true) == true
      and not self:isFirstPerson()) then
    self:removeRider()
    return
  end

  local controller = self
  local entity = state.riderEntity
  if not entity then
    entity = {
      id = "dramatic_deep_dive_rider",
      deepDiveRider = true,
      passable = true,
      sprite = state.riderSprite,
    }
    entity.pose = function(me)
      local p = Game.overworld and Game.overworld.player
      if not (controller.state.active and p and controller.state.riderSprite) then
        return me.sprite, me.px or 0, me.py or 0, me.facing or "down", 0, false, false
      end
      local dx, dy = controller:riderOffset(p)
      me.cellX, me.cellY = p.cellX, p.cellY
      me.px, me.py, me.facing = p.px + dx, p.py + dy, p.facing
      local flip = math.floor((p.animClock or 0) / 16) % 2 == 1
      return controller.state.riderSprite, me.px,
        me.py - controller:mountLift() - RIDER_LIFT - controller:swimBob(),
        p.facing, 0, flip, false
    end
    entity.draw = function(me, camX, camY)
      local sprite, px, py, facing, phase, flip = me:pose()
      if sprite and sprite.draw then sprite:draw(px, py, camX, camY, facing, phase, flip) end
    end
    state.riderEntity = entity
  end
  entity.sprite = state.riderSprite
  entity:pose()
  ow.entities = ow.entities or {}
  if not contains(ow.entities, entity) then table.insert(ow.entities, entity) end
end

function DeepDive:activate(event)
  local volume = self:resolveVolume(event)
  if not volume then return false end
  local ow = Game.overworld
  local player = ow and ow.player
  if not player then return false end

  if self.state.active and self.state.volume and self.state.volume.id == volume.id then
    self:ensureFreeCamera(false)
    if self.followerBridge then self.followerBridge:purge(ow, self.state.suspendedFollowers) end
    self:ensureRider()
    return true
  end

  local state = self.state
  local saved = self:loadSavedState(volume)
  state.active = true
  state.volume = volume
  state.originalPlayerSprite = player.sprite
  state.riderSprite = self:buildRiderSprite(player)
  state.mountSpecies = saved and saved.mountSpecies or nil
  state.previousVoxelLevel = saved and saved.previousVoxelLevel or nil
  state.suspendedFollowers = self.followerBridge and self.followerBridge:suspend(ow) or nil

  -- Surf remains logically active underwater. That keeps compatibility with
  -- the engine and independently guarantees follower mods suppress trailers.
  player.surfing = true
  if Game.save and Game.save.player then Game.save.player.surfing = true end

  local mon = self:findDiveMount()
  local sprite, reason = self:buildMount(mon)
  state.mount, state.mountSpecies, state.mountSprite = mon, mon and mon.species or nil, sprite
  if not sprite and self.mod.log then
    self.mod.log:warn("Underwater mount unavailable: %s", tostring(reason))
  end

  local maxDepth = self.registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  local initial = saved and tonumber(saved.depth) or volume.defaultDepth
  state.depth = clamp(initial, volume.minDepth, maxDepth)
  state.targetDepth = clamp(saved and tonumber(saved.targetDepth) or state.depth,
    volume.minDepth, maxDepth)
  state.hudTimer, state.saveTimer, state.boost = DEPTH_HUD_SECONDS, 0, 0

  self:ensureFreeCamera(true)
  self:ensureRider()
  self:saveState()
  self:log("entered %s at depth %.1f", volume.id, state.depth)
  return true
end

function DeepDive:deactivate(reason)
  local state = self.state
  if not state.active then return end
  local captured = state.suspendedFollowers
  self:removeRider()
  self:restoreVoxelMode()
  state.active = false
  state.depth, state.targetDepth = 0, 0
  state.volume, state.mount, state.mountSpecies, state.mountSprite = nil, nil, nil, nil
  state.riderSprite, state.originalPlayerSprite = nil, nil
  state.surfaceAvailable, state.saveTimer, state.boost = false, 0, 0
  state.suspendedFollowers = nil
  self.mod.save:set(SAVE_KEY, nil)
  if self.followerBridge then self.followerBridge:restore(Game, Game.overworld, captured) end
  self:log("left underwater free-swim mode%s", reason and (": " .. tostring(reason)) or "")
end

function DeepDive:verticalRate()
  return VERTICAL_RATES[optionValue(self.mod, "vertical_speed", "normal")]
    or VERTICAL_RATES.normal
end

function DeepDive:depthInput()
  local ascend = keyDown("pageup") or triggerDown("triggerright")
  local descend = keyDown("pagedown") or triggerDown("triggerleft")
  if ascend == descend then return 0 end
  return descend and 1 or -1
end

function DeepDive:updateBoost(dt)
  local enabled = optionValue(self.mod, "swim_boost", true) == true
  local held = enabled and Game.input and Game.input.isDown and Game.input:isDown("b")
  local target = held and 1 or 0
  local rate = target > self.state.boost and BOOST_RAMP_UP or BOOST_RAMP_DOWN
  local delta = target - self.state.boost
  local step = rate * dt
  if math.abs(delta) <= step then self.state.boost = target
  else self.state.boost = self.state.boost + (delta < 0 and -step or step) end
end

function DeepDive:updateDepth(dt)
  local state = self.state
  local volume = state.volume
  local ow = Game.overworld
  local player = ow and ow.player
  if not (state.active and volume and player) then return end

  self:ensureFreeCamera(false)
  self:updateBoost(dt)
  if self.followerBridge then self.followerBridge:purge(ow, state.suspendedFollowers) end

  local maxDepth = self.registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  local dir = self:depthInput()
  if dir ~= 0 then
    state.targetDepth = clamp(state.targetDepth + dir * self:verticalRate() * dt,
      volume.minDepth, maxDepth)
    state.hudTimer = DEPTH_HUD_SECONDS
  else
    state.targetDepth = math.min(state.targetDepth, maxDepth)
  end

  state.targetDepth = clamp(state.targetDepth, volume.minDepth, maxDepth)
  local followRate = math.max(self:verticalRate(), 52)
  local delta = state.targetDepth - state.depth
  local step = followRate * dt
  if math.abs(delta) <= step then state.depth = state.targetDepth
  else state.depth = state.depth + (delta < 0 and -step or step) end
  state.depth = clamp(state.depth, volume.minDepth, maxDepth)
  state.hudTimer = math.max(0, (state.hudTimer or 0) - dt)
  state.surfaceAvailable = self.travel and self.travel:canSurfaceHere(Game) or false
  self:ensureRider()

  state.saveTimer = (state.saveTimer or 0) + dt
  if state.saveTimer >= 0.25 then state.saveTimer = 0 self:saveState() end
end

function DeepDive:requestDepth(depth)
  local state = self.state
  if not (state.active and state.volume) then return false end
  local mapId, x, y = self:currentPosition()
  local maxDepth = self.registry:maxDepthAt(mapId, x, y)
    or (state.volume.defaultFloorDepth - state.volume.seabedClearance)
  state.targetDepth = clamp(tonumber(depth) or state.targetDepth,
    state.volume.minDepth, maxDepth)
  state.hudTimer = DEPTH_HUD_SECONDS
  self:saveState()
  return true
end

function DeepDive:runInsideSwimVolume(overworld, fn)
  local state = self.state
  local map = overworld and overworld.map
  if not (state.active and state.volume and map) then return fn() end

  local rawWalk = rawget(map, "isWalkableCell")
  local hadRawWalk = rawWalk ~= nil
  local oldOccupied = Collision.occupied
  local oldDefPassable = Map.defPassable
  local field = Game.data and Game.data.field
  local oldPairs = field and field.tilePairs
  local registry = self.registry
  local mapId = map.id

  map.isWalkableCell = function(_, x, y) return registry:contains(mapId, x, y) end
  Collision.occupied = function() return nil end
  Map.defPassable = function(def, tileset, x, y, surfing)
    if def and def.id == mapId then return registry:contains(mapId, x, y) end
    return oldDefPassable(def, tileset, x, y, surfing)
  end
  if field then field.tilePairs = { land = {}, water = {} } end

  local ok, result = pcall(fn)
  if hadRawWalk then map.isWalkableCell = rawWalk else rawset(map, "isWalkableCell", nil) end
  Collision.occupied = oldOccupied
  Map.defPassable = oldDefPassable
  if field then field.tilePairs = oldPairs end
  if not ok then error(result, 0) end
  return result
end

function DeepDive:installDramaticHooks()
  local FreeMove = self:providerModule("FreeMove")
  if not FreeMove then return end
  FreeMove.dramaticDeepDiveController = self
  if FreeMove.dramaticDeepDiveSpeedHook then return end

  local innerTick = FreeMove.tick
  function FreeMove.tick(overworld)
    local controller = FreeMove.dramaticDeepDiveController
    local oldWalk, oldBike = FreeMove.WALK, FreeMove.BIKE
    if controller and controller.state.active and controller:isFreeCamera() then
      local multiplier = 1 + (BOOST_MAX_MULTIPLIER - 1) * (controller.state.boost or 0)
      FreeMove.WALK = (tonumber(oldWalk) or 1) * multiplier
      FreeMove.BIKE = (tonumber(oldBike) or 2) * multiplier
    end
    local ok, result = pcall(innerTick, overworld)
    FreeMove.WALK, FreeMove.BIKE = oldWalk, oldBike
    if not ok then error(result, 0) end
    return result
  end
  FreeMove.dramaticDeepDiveSpeedHook = true
end

function DeepDive:installHooks()
  local controller = self
  local playerPose = Player.pose
  function Player:pose()
    local sprite, px, py, facing, phase, flip, hopping = playerPose(self)
    local state = controller.state
    local ow = Game.overworld
    if state.active and ow and ow.player == self then
      local visual = state.mountSprite or sprite
      local swimPhase = math.floor((self.animClock or 0) / 10) % 2
      return visual, self.px, self.py - controller:mountLift() - controller:swimBob(),
        facing, swimPhase, flip, false
    end
    return sprite, px, py, facing, phase, flip, hopping
  end

  self.mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    local state = controller.state
    local ow = Game.overworld
    if not (state.active and ow and ctx and ctx.mover == ow.player) then return result end
    local mapId = ow.map and ow.map.id
    if mapId and controller.registry:contains(mapId, ctx.toX, ctx.toY) then
      ctx.reason = nil
      return true
    end
    ctx.reason = "deep_dive_volume"
    return false
  end, 95)

  local handleInput = OverworldState.handleInput
  function OverworldState:handleInput(...)
    if not (controller.state.active and Game.overworld == self) then
      return handleInput(self, ...)
    end
    local args = { ... }
    return controller:runInsideSwimVolume(self, function()
      return handleInput(self, unpackArgs(args))
    end)
  end

  local update = OverworldState.update
  function OverworldState:update(dt, ...)
    local result = update(self, dt, ...)
    if controller.state.active and Game.overworld == self then
      controller:updateDepth(tonumber(dt) or (1 / 60))
    end
    return result
  end

  local drawUI = OverworldState.drawUI
  function OverworldState:drawUI(...)
    local result = drawUI(self, ...)
    local state = controller.state
    if not (state.active and Game.overworld == self and love and love.graphics) then return result end
    local mode = optionValue(controller.mod, "depth_display", "temporary")
    local visible = mode == "always" or (mode == "temporary" and (state.hudTimer or 0) > 0)
    local showSurface = optionValue(controller.mod, "surface_hint", true) == true
      and state.surfaceAvailable
    if not visible and not showSurface then return result end

    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 1)
    if visible then
      Font.drawBox(8, 0, 12, 4)
      Font.draw("DEPTH", 72, 8)
      Font.draw(string.format("%03d", math.floor((state.depth or 0) + 0.5)), 120, 8)
      local volume = state.volume
      local maxDepth = volume and controller.registry:maxDepthAt(
        volume.mapId, Game.overworld.player.cellX, Game.overworld.player.cellY) or 1
      local ratio = clamp(((state.depth or 0) - (volume and volume.minDepth or 0)) /
        math.max(1, maxDepth - (volume and volume.minDepth or 0)), 0, 1)
      for i = 1, 6 do
        local x, y = 73 + (i - 1) * 12, 21
        love.graphics.rectangle("line", x + 0.5, y + 0.5, 8, 5)
        if ratio >= (i - 1) / 6 then love.graphics.rectangle("fill", x + 2, y + 2, 5, 2) end
      end
    end
    if showSurface then
      Font.drawBox(1, 14, 18, 4)
      local text = "SURFACE AVAILABLE"
      Font.draw(text, math.floor((160 - Font.width(text)) / 2), 120)
    end
    love.graphics.pop()
    return result
  end
end

function DeepDive:installEvents()
  local controller = self
  self.mod.events:on("mod.dramatic_deep_dive.entered", function(event)
    controller:activate(event)
  end)
  self.mod.events:on("mod.dramatic_deep_dive.surfaced", function()
    controller:deactivate("surfaced")
  end)
  self.mod.events:on("map.entered", function(event)
    local mapId = event and event.mapId
    if not mapId then return end
    local volume = controller.registry:forMap(mapId)
    if volume then
      if not controller.state.active then controller:activate(event) end
    elseif controller.state.active then
      controller:deactivate("left authored underwater map")
    end
  end)
  self.mod.events:on("save.writing", function()
    if controller.state.active then controller:saveState() end
  end)
  self.mod.events:on("save.created", function()
    controller.mod.save:set(SAVE_KEY, nil)
  end)
  self.mod.events:on("map.reloaded", function(event)
    if controller.voxelRenderer and event and event.reason ~= "colors" then
      controller.voxelRenderer:invalidate()
    end
  end)
end

function DeepDive:install()
  if self.mod.options and self.mod.options.define then self.mod.options:define(OPTION_SCHEMA) end
  self:installHooks()
  self:installEvents()
  self:installDramaticHooks()
  self:log("0.2.0-alpha.1 standalone controller loaded")
end

function DeepDive:isActive() return self.state.active == true end
function DeepDive:currentDepth() return self.state.active and self.state.depth or nil end
function DeepDive:targetDepth() return self.state.active and self.state.targetDepth or nil end
function DeepDive:currentVolume() return self.state.volume and self.state.volume.id or nil end

return DeepDive
