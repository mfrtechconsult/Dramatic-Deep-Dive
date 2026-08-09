local Game = require("src.core.Game")
local OverworldState = require("src.world.OverworldController")

local UpdateHookGuard = {}

local function active(controller)
  if not controller then return false end
  if type(controller.isActive) == "function" then
    local ok, value = pcall(controller.isActive, controller)
    if ok then return value == true end
  end
  return controller.state and controller.state.active == true or false
end

local function findUpdateUpvalue(fn)
  if type(fn) ~= "function" or not (debug and debug.getupvalue and debug.setupvalue) then
    return nil, nil
  end
  local index = 1
  while true do
    local name, value = debug.getupvalue(fn, index)
    if not name then return nil, nil end
    if name == "update" and type(value) == "function" then
      return index, value
    end
    index = index + 1
  end
end

function UpdateHookGuard.install(mod, controller)
  local coreUpdate = OverworldState.update
  local upvalueIndex, initialNext = findUpdateUpvalue(coreUpdate)
  if not (upvalueIndex and initialNext) then
    if mod.log then
      mod.log:warn("Deep Dive update-hook guard unavailable: wrapper upvalue not found")
    end
    return {
      ready = false,
      recoveries = function() return 0 end,
      heartbeat = function() return 0 end,
    }
  end

  local heartbeat = 0
  local recoveries = 0

  local function bindNext(nextUpdate)
    if type(nextUpdate) ~= "function" then return false end
    local function heartbeatNext(self, dt, ...)
      heartbeat = heartbeat + 1
      return nextUpdate(self, dt, ...)
    end
    debug.setupvalue(coreUpdate, upvalueIndex, heartbeatNext)
    return true
  end

  bindNext(initialNext)

  local function recover(reason)
    local current = OverworldState.update
    if current == coreUpdate then return true end
    if type(current) ~= "function" then return false end
    if not bindNext(current) then return false end
    OverworldState.update = coreUpdate
    recoveries = recoveries + 1
    if mod.log then
      mod.log:info(
        "Deep Dive update hook was displaced; reattached around current handler (%s)",
        tostring(reason or "heartbeat"))
    end
    return true
  end

  local gameUpdate = Game.update
  if type(gameUpdate) == "function" then
    Game.update = function(...)
      local before = heartbeat
      local a, b, c, d, e = gameUpdate(...)
      local ow = Game.overworld
      local stack = Game.stack
      local top = stack and stack.top and stack:top() or nil
      local overworldRunning = ow ~= nil and (not stack or top == ow)
      if active(controller) and overworldRunning and heartbeat == before then
        recover("active-dive heartbeat")
      end
      return a, b, c, d, e
    end
  end

  return {
    ready = true,
    ensure = recover,
    recoveries = function() return recoveries end,
    heartbeat = function() return heartbeat end,
  }
end

return UpdateHookGuard
