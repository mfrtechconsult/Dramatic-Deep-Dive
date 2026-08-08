local Game = require("src.core.Game")
local Pipelines = require("src.render.Pipelines")
local Player = require("src.world.Player")
local OverworldState = require("src.world.OverworldController")
local Map = require("src.world.Map")
local Collision = require("src.world.Collision")
local Font = require("src.render.Font")

local DeepDive = {}
DeepDive.__index = DeepDive

local SAVE_KEY = "deepDiveSession"
local VOXEL_PIPELINE = "voxel"
local THIRD_PERSON_LEVEL = 7
local TRIGGER_THRESHOLD = 0.35
local DEPTH_HUD_SECONDS = 2.0
local RIDER_LIFT = 7
local unpackArgs = table.unpack or unpack

local VERTICAL_RATES = {
  slow = 16,
  normal = 28,
  fast = 44,
}

local OPTION_SCHEMA = {
  {
    key = "show_rider",
    type = "toggle",
    label = "SHOW RIDER",
    default = true,
    help = "Show the trainer above the underwater Pokemon mount.",
  },
  {
    key = "depth_display",
    type = "choice",
    label = "DEPTH DISPLAY",
    default = "temporary",
    choices = {
      { "Temporary", "temporary" },
      { "Always", "always" },
      { "Off", "off" },
    },
    help = "When the continuous depth indicator is visible.",
  },
  {
    key = "vertical_speed",
    type = "choice",
    label = "VERTICAL SPEED",
    default = "normal",
    choices = {
      { "Slow", "slow" },
      { "Normal", "normal" },
      { "Fast", "fast" },
    },
    help = "How quickly L2/R2 and Page Down/Page Up change depth.",
  },
  {
    key = "surface_hint",
    type = "toggle",
    label = "SURFACE HINT",
    default = true,
    help = "Show when Kanto Dive permits SURFACE at the current cell.",
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

local function monKnows(mon, moveId)
  for _, move in ipairs(mon and mon.moves or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then return true end
  end
  return false
end

local function removeFromList(list, value)
  for index = #(list or {}), 1, -1 do
    if list[index] == value then table.remove(list, index) end
  end
end

function DeepDive.new(mod, registry, sprites, voxelRenderer)
  return setmetatable({
    mod = mod,
    registry = registry,
    sprites = sprites,
    voxelRenderer = voxelRenderer,
    state = {
      active = false,
      depth = 0,
      targetDepth = 0,
      volume = nil,
      mount = nil,
      mountSpecies = nil,
      mountSprite = nil,
      originalPlayerSprite = nil,
      riderEntity = nil,
      previousVoxelLevel = nil,
      hudTimer = 0,
      surfaceAvailable = false,
      saveTimer = 0,
    },
  }, DeepDive)
end

function DeepDive:log(fmt, ...)
  if self.mod.log then self.mod.log:info(fmt, ...) end
end

function DeepDive:kantoDive()
  if not self.mod.find then return nil end
  local ok, handle = pcall(self.mod.find, self.mod, "kanto_dive")
  return ok and handle or nil
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
  if not mapId and event then
    mapId, x, y = event.mapId, event.x, event.y
  end
  if not mapId then return nil end
  return self.registry:forMap(mapId, x, y)
end

function DeepDive:findDiveMount()
  local party = Game.save and Game.save.party or {}
  local remembered = self.state.mountSpecies

  local function valid(mon)
    return mon and monKnows(mon, "DIVE")
  end

  if remembered then
    for _, mon in ipairs(party) do
      if mon.species == remembered and valid(mon) then return mon end
    end
  end

  for _, mon in ipairs(party) do
    if valid(mon) then return mon end
  end
  return nil
end

function DeepDive:buildMount(mon)
  if not mon then return nil, "no Pokemon knows DIVE" end
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[mon.species]
  local dex = def and tonumber(def.dex)
  if not dex then return nil, "Pokemon has no Pokedex number" end
  return self.sprites:build(mon.species, dex)
end

function DeepDive:saveState()
  local state = self.state
  if not state.active then
    self.mod.save:set(SAVE_KEY, nil)
    return
  end
  self.mod.save:set(SAVE_KEY, {
    active = true,
    mapId = state.volume and state.volume.mapId or nil,
    volumeId = state.volume and state.volume.id or nil,
    zoneId = state.volume and state.volume.zoneId or nil,
    depth = state.depth,
    targetDepth = state.targetDepth,
    mountSpecies = state.mountSpecies,
    previousVoxelLevel = state.previousVoxelLevel,
  })
end

function DeepDive:loadSavedState(volume)
