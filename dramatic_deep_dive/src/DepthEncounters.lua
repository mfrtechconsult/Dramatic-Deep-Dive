local Game = require("src.core.Game")
local Encounter = require("src.world.Encounter")

local DepthEncounters = {}
DepthEncounters.__index = DepthEncounters

function DepthEncounters.new(mod, controller, definitions)
  return setmetatable({
    mod = mod,
    controller = controller,
    definitions = definitions or {},
    wildlife = nil,
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

function DepthEncounters:currentBand()
  local state = self.controller and self.controller.state
  local mapId = self:currentMapId()
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

function DepthEncounters:install()
  -- OverworldController retains the Encounter module table, not a local copy
  -- of roll(), so replacing this one function safely affects normal encounter
  -- checks while leaving battle creation and the vanilla RNG implementation
  -- untouched. The wrapper becomes a no-op everywhere outside Deep Dive.
  Encounter.dramaticDeepDiveDepthEncounters = self
  if Encounter.dramaticDeepDiveDepthHook then return true end

  local innerRoll = Encounter.roll
  function Encounter.roll(encounterDef, rng)
    local service = Encounter.dramaticDeepDiveDepthEncounters
    if service then
      local mapId = service:currentMapId()

      -- Hard Wilds gate: as soon as the current map belongs to Deep Dive's
      -- generated underwater encounter definitions, random encounters are
      -- impossible. This check deliberately does not depend on controller
      -- active state or the current depth band, so transition frames and band
      -- edges cannot leak an invisible vanilla encounter through.
      -- Visible wildlife interception starts battles directly and therefore
      -- does not pass through Encounter.roll.
      if service:wildsInstalled() and service:isManagedUnderwaterMap(mapId) then
        return nil
      end

      local band = service:currentBand()
      if band then
        local encounter = innerRoll(service:encounterDefinition(band), rng)
        if encounter and service.wildlife and service.wildlife.consumeNearby then
          pcall(service.wildlife.consumeNearby, service.wildlife, encounter.species)
        end
        return encounter
      end
    end
    return innerRoll(encounterDef, rng)
  end
  Encounter.dramaticDeepDiveDepthHook = true
  return true
end

return DepthEncounters
