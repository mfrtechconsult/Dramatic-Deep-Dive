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

local function discoverBoundary(root)
  local chain = {}
  local seen = {}
  local current = root
  while type(current) == "function" and not seen[current] do
    seen[current] = true
    chain[#chain + 1] = current
    local index, child = findUpdateUpvalue(current)
    if not index then break end
    local childIndex = select(1, findUpdateUpvalue(child))
    if not childIndex then
      return current, index, child, chain
    end
    current = child
  end
  return nil, nil, nil, chain
end

function UpdateHookGuard.install(mod, controller)
  -- Install this after every Deep Dive subsystem so `rootUpdate` is the full
  -- DDD update chain (transition -> salvage -> scene gameplay -> depth core).
  local rootUpdate = OverworldState.update
  local boundaryParent, boundaryIndex, initialExternal, chain =
    discoverBoundary(rootUpdate)
  if not (boundaryParent and boundaryIndex and initialExternal) then
    if mod.log then
      mod.log:warn("Deep Dive update-hook guard unavailable: wrapper boundary not found")
    end
    return {
      ready = false,
      recoveries = function() return 0 end,
      heartbeat = function() return 0 end,
      protectedWrappers = function() return #(chain or {}) end,
      rootUpdate = function() return rootUpdate end,
      ownsUpdate = function() return false end,
    }
  end

  local heartbeat = 0
  local recoveries = 0
  local chainSet = {}
  for _, fn in ipairs(chain or {}) do chainSet[fn] = true end

  local function bindExternal(nextUpdate)
    if type(nextUpdate) ~= "function" then return false end
    local function heartbeatExternal(self, dt, ...)
      heartbeat = heartbeat + 1
      return nextUpdate(self, dt, ...)
    end
    debug.setupvalue(boundaryParent, boundaryIndex, heartbeatExternal)
    return true
  end

  bindExternal(initialExternal)

  -- If Sky Ride is installed, its guard owns the DSR -> external boundary.
  -- Ask it to compose around the CURRENT displaced handler first, then put
  -- the complete DDD chain above the returned DSR root. This preserves the
  -- full stack as DDD -> DSR -> Wilds/other instead of making either sibling
  -- guard overwrite the other's chain.
  local function composeExternal(current, reason)
    if not (mod and mod.find) then return current end
    local okFind, handle = pcall(mod.find, mod, "DRAMATIC_SKY_RIDE")
    local compat = okFind and handle and handle.exports
      and handle.exports.wildsCompatibility or nil
    local compose = compat and compat.composeAround
    if type(compose) ~= "function" then return current end

    local okCompose, combined = pcall(compose, current,
      reason or "Deep Dive cooperative recovery")
    if okCompose and type(combined) == "function" then return combined end
    if not okCompose and mod.log then
      mod.log:warn("Sky Ride cooperative update composition failed: %s",
        tostring(combined))
    end
    return current
  end

  local function recover(reason)
    local current = OverworldState.update
    if current == rootUpdate then return true end
    if type(current) ~= "function" then return false end

    -- Restoring an intermediate DDD wrapper only needs the complete root put
    -- back on top. For a genuinely external handler (Wilds or another mod),
    -- preserve Sky Ride when available, then retarget DDD's deepest external
    -- edge around that combined chain.
    local nextUpdate = current
    if not chainSet[current] then
      nextUpdate = composeExternal(current, reason)
      if not bindExternal(nextUpdate) then return false end
    end
    OverworldState.update = rootUpdate
    recoveries = recoveries + 1
    if mod.log then
      mod.log:info(
        "Deep Dive update hook was displaced; full DDD chain reattached (%s)",
        tostring(reason or "heartbeat"))
    end
    return true
  end

  -- Guard at the fixed logic boundary. Game.update can render without running
  -- a logic tick on high-refresh displays, so using it would create false
  -- missing-heartbeat detections.
  local gameStep = Game.step
  if type(gameStep) == "function" then
    Game.step = function(...)
      local owBefore = Game.overworld
      local stackBefore = Game.stack
      local topBefore = stackBefore and stackBefore.top and stackBefore:top() or nil
      local expectedOverworldTick = owBefore ~= nil
        and (not stackBefore or topBefore == owBefore)
      local before = heartbeat

      local a, b, c, d, e = gameStep(...)

      local owAfter = Game.overworld
      local stackAfter = Game.stack
      local topAfter = stackAfter and stackAfter.top and stackAfter:top() or nil
      local stillInOverworld = owAfter ~= nil
        and (not stackAfter or topAfter == owAfter)
      if active(controller) and expectedOverworldTick and stillInOverworld
          and heartbeat == before then
        recover("active-dive logic heartbeat")
      end
      return a, b, c, d, e
    end
  end

  if mod.log then
    mod.log:info("Deep Dive update-chain guard armed (%d wrappers)", #(chain or {}))
  end

  return {
    ready = true,
    ensure = recover,
    recoveries = function() return recoveries end,
    heartbeat = function() return heartbeat end,
    protectedWrappers = function() return #(chain or {}) end,
    rootUpdate = function() return rootUpdate end,
    ownsUpdate = function(fn) return chainSet[fn] == true end,
  }
end

return UpdateHookGuard
