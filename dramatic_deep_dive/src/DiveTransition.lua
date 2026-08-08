local Game = require("src.core.Game")
local OverworldState = require("src.world.OverworldController")

local DiveTransition = {}
DiveTransition.__index = DiveTransition

local DIVE_OUT = 0.30
local DIVE_IN = 0.82
local SURFACE_OUT = 0.30
local SURFACE_IN = 0.48
local SURFACE_ASCEND_SPEED = 138
local WAIT_TIMEOUT = 3.0

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function approach(value, target, amount)
  if value < target then return math.min(target, value + amount) end
  return math.max(target, value - amount)
end

function DiveTransition.new(mod, controller, registry)
  return setmetatable({
    mod = mod,
    controller = controller,
    registry = registry,
    mode = nil,
    timer = 0,
    duration = 0,
    callback = nil,
    waitTimer = 0,
  }, DiveTransition)
end

function DiveTransition:isActive()
  return self.mode ~= nil
end

function DiveTransition:isBlockingInput()
  return self.mode ~= nil
end

function DiveTransition:clear()
  self.mode = nil
  self.timer = 0
  self.duration = 0
  self.callback = nil
  self.waitTimer = 0
end

function DiveTransition:start(mode, duration, callback)
  self.mode = mode
  self.timer = 0
  self.duration = math.max(0.01, tonumber(duration) or 0.01)
  self.callback = callback
  self.waitTimer = 0
end

function DiveTransition:beginDive(callback)
  if self:isActive() then return false end
  self:start("dive_out", DIVE_OUT, callback)
  return true
end

function DiveTransition:beginSurface(callback)
  if self:isActive() then return false end
  local state = self.controller and self.controller.state
  local volume = state and state.active and state.volume or nil
  if not volume then return false end
  state.targetDepth = volume.minDepth
  self:start("surface_ascent", 999, callback)
  return true
end

function DiveTransition:runCallback(waitMode)
  local callback = self.callback
  self.callback = nil
  self.mode = waitMode
  self.timer = 0
  self.waitTimer = 0
  if not callback then
    self:clear()
    return
  end
  local ok, result = pcall(callback)
  if not ok then
    if self.mod.log then self.mod.log:error("DIVE transition callback failed: %s", tostring(result)) end
    self:clear()
    return
  end
  if result == false then self:clear() end
end

function DiveTransition:onEntered(event)
  if self.mode ~= "wait_dive_map" then return end
  local state = self.controller and self.controller.state
  local volume = state and state.active and state.volume or nil
  local ow = Game.overworld
  local player = ow and ow.player
  if not (volume and player and event and event.mapId == volume.mapId) then return end

  local maxDepth = self.registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  state.depth = volume.minDepth
  state.targetDepth = clamp(volume.defaultDepth, volume.minDepth, maxDepth)
  state.hudTimer = math.max(state.hudTimer or 0, DIVE_IN)
  self.mode = "dive_in"
  self.timer = 0
  self.duration = DIVE_IN
  self.waitTimer = 0
  self.controller:saveState()
end

function DiveTransition:onSurfaced()
  if self.mode ~= "wait_surface_map" then return end
  self.mode = "surface_in"
  self.timer = 0
  self.duration = SURFACE_IN
  self.waitTimer = 0
end

function DiveTransition:update(dt)
  if not self.mode then return end
  dt = math.min(0.1, math.max(0, tonumber(dt) or 0))

  if self.mode == "surface_ascent" then
    local state = self.controller and self.controller.state
    local volume = state and state.active and state.volume or nil
    if not volume then
      self:runCallback("wait_surface_map")
      return
    end
    state.targetDepth = volume.minDepth
    state.depth = approach(state.depth or volume.defaultDepth,
      volume.minDepth, SURFACE_ASCEND_SPEED * dt)
    state.hudTimer = math.max(state.hudTimer or 0, 0.25)
    if state.depth <= volume.minDepth + 0.6 then
      state.depth = volume.minDepth
      state.targetDepth = volume.minDepth
      self.mode = "surface_out"
      self.timer = 0
      self.duration = SURFACE_OUT
      self.controller:saveState()
    end
    return
  end

  if self.mode == "wait_dive_map" or self.mode == "wait_surface_map" then
    self.waitTimer = self.waitTimer + dt
    if self.waitTimer >= WAIT_TIMEOUT then
      if self.mod.log then self.mod.log:warn("underwater transition timed out in %s", tostring(self.mode)) end
      self:clear()
    end
    return
  end

  self.timer = self.timer + dt
  if self.timer < self.duration then return end

  if self.mode == "dive_out" then
    self:runCallback("wait_dive_map")
  elseif self.mode == "surface_out" then
    self:runCallback("wait_surface_map")
  elseif self.mode == "dive_in" or self.mode == "surface_in" then
    self:clear()
  end
end

function DiveTransition:overlayAlpha()
  if not self.mode then return 0 end
  local p = clamp(self.timer / math.max(0.01, self.duration), 0, 1)
  if self.mode == "dive_out" then return p * 0.82 end
  if self.mode == "wait_dive_map" then return 0.82 end
  if self.mode == "dive_in" then return (1-p) * 0.72 end
  if self.mode == "surface_ascent" then return 0.04 end
  if self.mode == "surface_out" then return p * 0.78 end
  if self.mode == "wait_surface_map" then return 0.78 end
  if self.mode == "surface_in" then return (1-p) * 0.78 end
  return 0
end

function DiveTransition:drawOverlay()
  if not (self.mode and love and love.graphics) then return end
  local alpha = self:overlayAlpha()
  if alpha <= 0 then return end

  love.graphics.push("all")
  love.graphics.setColor(0.02, 0.16, 0.27, alpha)
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  -- Small procedural bubbles sell the water crossing without requiring any
  -- external art. They deliberately live in screen space only during the
  -- transition; the normal underwater vents are real world-space meshes.
  local phase = (love.timer and love.timer.getTime and love.timer.getTime() or os.clock()) * 32
  love.graphics.setColor(0.75, 0.94, 1.0, math.min(0.55, alpha + 0.12))
  for i = 1, 9 do
    local x = (i * 29 + math.floor(phase * 0.35)) % 164 - 2
    local y = 146 - ((phase + i * 19) % 158)
    local r = 1 + (i % 3) * 0.7
    love.graphics.circle("line", x, y, r)
  end
  love.graphics.pop()
end

function DiveTransition:install()
  local transition = self

  -- Run after the normal DeepDive activation and transition guard so the
  -- destination volume already exists before the entry descent is staged.
  self.mod.events:on("mod.dramatic_deep_dive.entered", function(event)
    transition:onEntered(event)
  end, -200)
  self.mod.events:on("mod.dramatic_deep_dive.surfaced", function()
    transition:onSurfaced()
  end, -200)

  local handleInput = OverworldState.handleInput
  function OverworldState:handleInput(...)
    if Game.overworld == self and transition:isBlockingInput() then return end
    return handleInput(self, ...)
  end

  local update = OverworldState.update
  function OverworldState:update(dt, ...)
    local result = update(self, dt, ...)
    if Game.overworld == self then transition:update(dt) end
    return result
  end

  local drawUI = OverworldState.drawUI
  function OverworldState:drawUI(...)
    local result = drawUI(self, ...)
    if Game.overworld == self then transition:drawOverlay() end
    return result
  end
end

return DiveTransition
