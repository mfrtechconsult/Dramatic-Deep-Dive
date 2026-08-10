local Game = require("src.core.Game")

local SeamHandoff = {}

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

function SeamHandoff.install(mod, controller, registry)
  if controller.dramaticDeepDiveSeamHandoffInstalled then return true end
  local originalActivate = controller.activate

  function controller:activate(event)
    local volume = self:resolveVolume(event)
    local state = self.state
    local ow = Game.overworld
    local player = ow and ow.player

    if volume and player and state.active and state.volume
        and state.volume.id ~= volume.id then
      local previousId = state.volume.id
      state.volume = volume
      player.surfing = true
      if Game.save and Game.save.player then Game.save.player.surfing = true end

      local maxDepth = registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
        or (volume.defaultFloorDepth - volume.seabedClearance)
      state.depth = clamp(tonumber(state.depth) or volume.defaultDepth,
        volume.minDepth, maxDepth)
      state.targetDepth = clamp(tonumber(state.targetDepth) or state.depth,
        volume.minDepth, maxDepth)
      state.hudTimer = math.max(state.hudTimer or 0, 0.6)
      state.saveTimer = 0

      self:ensureFreeCamera(false)
      if self.followerBridge then self.followerBridge:purge(ow, state.suspendedFollowers) end
      self:ensureRider()
      self:saveState()
      if mod.log then
        mod.log:info("underwater seam %s -> %s at depth %.1f",
          tostring(previousId), tostring(volume.id), state.depth)
      end
      return true
    end

    return originalActivate(self, event)
  end

  controller.dramaticDeepDiveSeamHandoffInstalled = true
  return true
end

return SeamHandoff
