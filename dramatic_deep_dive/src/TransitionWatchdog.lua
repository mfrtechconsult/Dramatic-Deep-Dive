local Game = require("src.core.Game")

local TransitionWatchdog = {}

function TransitionWatchdog.install(mod, transition, updateHookGuard)
  if not (transition and type(transition.isActive) == "function"
      and updateHookGuard and type(updateHookGuard.ensure) == "function") then
    if mod.log then mod.log:warn("Deep Dive transition watchdog unavailable") end
    return false
  end

  Game.__dramaticDeepDiveTransitionWatchdog = {
    mod = mod,
    transition = transition,
    guard = updateHookGuard,
  }
  if Game.__dramaticDeepDiveTransitionWatchdogPatched then return true end

  local original = Game.step
  if type(original) ~= "function" then
    if mod.log then mod.log:warn("Deep Dive transition watchdog cannot wrap Game.step") end
    return false
  end

  Game.step = function(...)
    local active = Game.__dramaticDeepDiveTransitionWatchdog
    if active and active.transition:isActive() then
      local ok, recovered = pcall(active.guard.ensure, "active DIVE/SURFACE transition")
      if not ok and active.mod.log then
        active.mod.log:warn("Deep Dive transition update recovery failed: %s", tostring(recovered))
      end
    end
    return original(...)
  end
  Game.__dramaticDeepDiveTransitionWatchdogPatched = true
  if mod.log then mod.log:info("Deep Dive transition watchdog armed") end
  return true
end

return TransitionWatchdog
