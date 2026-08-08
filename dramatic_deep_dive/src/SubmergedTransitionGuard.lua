local Game = require("src.core.Game")

local Guard = {}
Guard.__index = Guard

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

function Guard.new(mod, controller, registry)
  return setmetatable({
    mod = mod,
    controller = controller,
    registry = registry,
    pending = nil,
  }, Guard)
end

function Guard:capture(event)
  local state = self.controller and self.controller.state
  local current = state and state.volume
  if not (state and state.active and current and event and event.mapId) then return end
  if current.mapId == event.mapId then return end
  if not self.registry:forMap(event.mapId) then return end

  self.pending = {
    fromMapId = current.mapId,
    toMapId = event.mapId,
    previousVoxelLevel = state.previousVoxelLevel,
    depth = state.depth,
    targetDepth = state.targetDepth,
  }
end

function Guard:restore(event)
  local pending = self.pending
  if not (pending and event and event.mapId == pending.toMapId) then return end
  self.pending = nil

  local state = self.controller and self.controller.state
  local volume = state and state.volume
  local ow = Game.overworld
  local player = ow and ow.player
  if not (state and state.active and volume and volume.mapId == event.mapId and player) then return end

  local maxDepth = self.registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  state.depth = clamp(tonumber(pending.depth) or volume.defaultDepth, volume.minDepth, maxDepth)
  state.targetDepth = clamp(tonumber(pending.targetDepth) or state.depth, volume.minDepth, maxDepth)

  -- Never let an internal underwater warp replace the surface camera mode
  -- with 1ST/3RD as the mode to restore after SURFACE.
  if pending.previousVoxelLevel ~= nil then
    state.previousVoxelLevel = pending.previousVoxelLevel
  end

  self.controller:saveState()
  if self.mod.log then
    self.mod.log:info("preserved depth %.1f across %s -> %s",
      state.depth, tostring(pending.fromMapId), tostring(pending.toMapId))
  end
end

function Guard:install()
  local guard = self
  -- Events are dispatched by priority, so this listener snapshots the active
  -- water column before DeepDive's priority-0 entered handler changes it.
  self.mod.events:on("mod.dramatic_deep_dive.entered", function(event)
    guard:capture(event)
  end, 100)

  -- Restore after the controller has activated the destination map.
  self.mod.events:on("mod.dramatic_deep_dive.entered", function(event)
    guard:restore(event)
  end, -100)
end

return Guard
