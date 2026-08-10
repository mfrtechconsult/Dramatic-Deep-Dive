local StableDepthTick = {}

function StableDepthTick.install(mod, controller)
  if not (mod and mod.hooks and controller and type(controller.updateDepth) == "function") then
    return nil
  end
  if controller.__dramaticDeepDiveStableDepthTickInstalled then return true end

  local originalUpdateDepth = controller.updateDepth
  local serial = 0
  local lastSerial = -1

  -- The original DeepDive controller historically serviced depth from a
  -- direct OverworldState.update wrapper. Sky-family mods can replace that
  -- slot, so keep it as a harmless fallback but guarantee at-most-once depth
  -- work per engine fixed step when this public hook is available.
  function controller:updateDepth(dt)
    local current = self.__dramaticDeepDiveDepthSerial
    if current ~= nil and current == lastSerial then return end
    if current ~= nil then lastSerial = current end
    return originalUpdateDepth(self, dt)
  end

  mod.hooks:wrap("input.step", function(nextFn, game, dt)
    serial = serial + 1
    controller.__dramaticDeepDiveDepthSerial = serial
    local result = nextFn(game, dt)

    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if controller.state and controller.state.active and ow
        and (not stack or top == ow) then
      controller:updateDepth(tonumber(dt) or (1 / 60))
    end
    return result
  end, 90)

  controller.__dramaticDeepDiveStableDepthTickInstalled = true
  if mod.log then
    mod.log:info("Deep Dive depth control bound to public input.step fixed tick")
  end
  return true
end

return StableDepthTick
