local Game = require("src.core.Game")

local Stadium2LegacyBridge = {}
Stadium2LegacyBridge.__index = Stadium2LegacyBridge

local EXTERNAL_IDS = {
  "STADIUM_OVERWORLD_MODELS",
  "stadium_overworld_models",
}

local function safeFind(mod, id)
  if not (mod and mod.find) then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function providerState(mod)
  return mod and mod.exports and mod.exports._dramaticProviderState or nil
end

function Stadium2LegacyBridge.new(mod)
  return setmetatable({
    mod = mod,
    installed = false,
    external = nil,
    tagged = setmetatable({}, { __mode = "k" }),
    scans = 0,
    taggedCount = 0,
    tagFailures = 0,
  }, Stadium2LegacyBridge)
end

function Stadium2LegacyBridge:isLegacyProvider()
  local state = providerState(self.mod)
  return state and state.id == "DRAMATIC_SHAPE"
end

function Stadium2LegacyBridge:externalHandle()
  if self.external then return self.external end
  for _, id in ipairs(EXTERNAL_IDS) do
    local handle = safeFind(self.mod, id)
    if handle then
      self.external = handle
      return handle
    end
  end
  return nil
end

function Stadium2LegacyBridge:externalInstalled()
  return self:isLegacyProvider() and self:externalHandle() ~= nil
end

function Stadium2LegacyBridge:exports()
  local handle = self:externalHandle()
  return handle and handle.exports or nil
end

function Stadium2LegacyBridge:tagEntity(entity)
  if not (entity and entity.deepDiveWildlife and entity.species) then return false end
  if self.tagged[entity] then return true end

  -- The legacy Stadium Overworld renderer already consumes pose lift, so the
  -- existing Deep Dive wildlife pose naturally places the model at its actual
  -- underwater depth.  We only provide an explicit Pokemon identity here;
  -- movement, encounter state and lifetime remain owned by Deep Dive.
  local ex = self:exports()
  local tagged = false
  if ex and type(ex.tag) == "function" then
    local ok, value = pcall(ex.tag, entity, entity.species)
    tagged = ok and value ~= false
  elseif ex and ex.overworld and type(ex.overworld.tag) == "function" then
    local ok, value = pcall(ex.overworld.tag, entity, entity.species)
    tagged = ok and value ~= false
  else
    -- Current Stadium Overworld builds also infer the generic `species` field.
    -- Keep the bridge live until its public tag export becomes available; the
    -- entity can already be recognized meanwhile without mutating its sprite.
    return false
  end

  if tagged then
    entity.dramaticDeepDiveLegacyStadium = true
    self.tagged[entity] = true
    self.taggedCount = self.taggedCount + 1
    return true
  end
  self.tagFailures = self.tagFailures + 1
  return false
end

function Stadium2LegacyBridge:scan()
  if not self:isLegacyProvider() then return false end
  self.scans = self.scans + 1
  local ow = Game.overworld
  if not ow then return false end
  for _, entity in ipairs(ow.entities or {}) do
    if entity and entity.deepDiveWildlife and not entity.dead then
      self:tagEntity(entity)
    end
  end
  return true
end

function Stadium2LegacyBridge:clear()
  local ex = self:exports()
  for entity in pairs(self.tagged) do
    if ex and type(ex.untag) == "function" then pcall(ex.untag, entity)
    elseif ex and ex.overworld and type(ex.overworld.untag) == "function" then
      pcall(ex.overworld.untag, entity)
    end
    if entity then entity.dramaticDeepDiveLegacyStadium = nil end
    self.tagged[entity] = nil
  end
end

function Stadium2LegacyBridge:install()
  if self.installed then return true end
  if not self:externalInstalled() then return false end

  local bridge = self
  if self.mod.hooks and self.mod.hooks.wrap then
    self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      local active = bridge.mod.exports and bridge.mod.exports.isActive
      local okActive, isActive = type(active) == "function" and pcall(active) or false, false
      if okActive then
        local ok, value = pcall(active)
        isActive = ok and value == true
      end
      if isActive then bridge:scan() end
      return result
    end, 67)
  end

  if self.mod.events and self.mod.events.on then
    self.mod.events:on("game.ready", function() bridge:scan() end)
    self.mod.events:on("map.entered", function() bridge:scan() end)
    self.mod.events:on("mod.DRAMATIC_DEEP_DIVE.entered", function() bridge:scan() end)
    self.mod.events:on("mod.DRAMATIC_DEEP_DIVE.surfaced", function() bridge:clear() end)
  end

  self.installed = true
  if self.mod.log then
    self.mod.log:info("Legacy Stadium bridge enabled: Dramatic Shape + Stadium Overworld Models")
  end
  return true
end

function Stadium2LegacyBridge:stats()
  local state = providerState(self.mod)
  local ex = self:exports()
  return {
    mode = "legacy_delegate",
    provider = state and state.id or nil,
    externalInstalled = self:externalHandle() ~= nil,
    externalReady = ex ~= nil and (type(ex.tag) == "function"
      or (ex.overworld and type(ex.overworld.tag) == "function")),
    scans = self.scans,
    tagged = self.taggedCount,
    tagFailures = self.tagFailures,
  }
end

return Stadium2LegacyBridge
