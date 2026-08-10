local Game = require("src.core.Game")

local DepthEncounters = {}
DepthEncounters.__index = DepthEncounters

-- Run before normal encounter wrappers such as Wilds of Kanto's default
-- priority-0 hook. A second encounter.species guard is installed as a final
-- safety net in case another higher-priority encounter.roll wrapper forces a
-- result without calling next().
local HARD_SUPPRESS_PRIORITY = 1000000

function DepthEncounters.new(mod, controller, definitions)
  return setmetatable({
    mod = mod,
    controller = controller,
    definitions = definitions or {},
    wildlife = nil,
    installed = false,
    suppressed = 0,
  }, DepthEncounters)
end

function DepthEncounters:setWildlife(wildlife)
  self.wildlife = wildlife
end

function DepthEncounters:band(mapId, depth)
  local bands = self.definitions[mapId]
  if not bands then return nil end
  depth = tonumber(depth) or 0
  for _, band in ipairs(bands) do
    if depth >= (band.minDepth or 0) and depth < (band.maxDepth or math.huge) then
      return band
    end
  end
  return nil
end

function DepthEncounters:currentMapId()
  local ow = Game and Game.overworld
  local map = ow and ow.map
  return map and map.id or nil
end

function DepthEncounters:isManagedUnderwaterMap(mapId)
  mapId = mapId or self:currentMapId()
  return type(mapId) == "string" and self.definitions[mapId] ~= nil
end

function DepthEncounters:currentBand(mapId)
  local state = self.controller and self.controller.state
  mapId = mapId or self:currentMapId()
  if not (state and state.active and mapId) then return nil end
  return self:band(mapId, state.depth), mapId
end

function DepthEncounters:encounterDefinition(band)
  if not band then return nil end
  return {
    grass = {
      rate = band.rate or 0,
      slots = band.slots,
      buckets = band.buckets,
    },
  }
end

function DepthEncounters:wildsInstalled()
  if self.mod and self.mod.find then
    local ok, handle = pcall(self.mod.find, self.mod, "overworld_wild_spawns")
    if ok and handle then return true end
  end
  local exports = Game and Game.mods and Game.mods.exports
  return exports and exports.overworld_wild_spawns ~= nil or false
end

function DepthEncounters:shouldHardSuppress(mapId)
  return self:wildsInstalled() and self:isManagedUnderwaterMap(mapId)
end

function DepthEncounters:install()
  if self.installed then return true end
  if not (self.mod and self.mod.hooks and self.mod.hooks.wrap) then
    return false
  end

  local service = self

  -- Primary gate. This is the official Gen1Recomp encounter pipeline used by
  -- OverworldState:rollEncounter. Returning nil without next() prevents every
  -- downstream classic/random encounter provider from producing a battle.
  self.mod.hooks:wrap("encounter.roll", function(nextFn, encounterDef, ctx)
    local mapId = ctx and ctx.mapId or service:currentMapId()
    if service:shouldHardSuppress(mapId) then
      service.suppressed = service.suppressed + 1
      return nil
    end

    -- Standalone Deep Dive keeps depth-aware random encounters, but generated
    -- engine-facing encounter records themselves stay rate 0. Inject the live
    -- depth band only here when Wilds is absent.
    if service:isManagedUnderwaterMap(mapId) then
      local band = service:currentBand(mapId)
      if not band then return nil end
      local encounter = nextFn(service:encounterDefinition(band), ctx)
      if encounter and service.wildlife and service.wildlife.consumeNearby then
        pcall(service.wildlife.consumeNearby, service.wildlife, encounter.species)
      end
      return encounter
    end

    return nextFn(encounterDef, ctx)
  end, HARD_SUPPRESS_PRIORITY)

  -- Final safety gate. Gen1Recomp calls encounter.species after encounter.roll
  -- for every non-nil roll. Therefore even a hypothetical wrapper with an even
  -- higher roll priority that forces a Pokemon without calling next() is still
  -- cancelled here while Wilds + Deep Dive are active.
  self.mod.hooks:wrap("encounter.species", function(nextFn, encounter, ctx)
    local mapId = ctx and ctx.mapId or service:currentMapId()
    if service:shouldHardSuppress(mapId) then
      service.suppressed = service.suppressed + 1
      return nil
    end
    return nextFn(encounter, ctx)
  end, HARD_SUPPRESS_PRIORITY)

  self.installed = true
  return true
end

function DepthEncounters:stats()
  return {
    wilds = self:wildsInstalled(),
    suppressed = self.suppressed,
    managedMap = self:isManagedUnderwaterMap(),
  }
end

return DepthEncounters
