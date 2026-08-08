local Game = require("src.core.Game")
local Encounter = require("src.world.Encounter")

local DepthEncounters = {}
DepthEncounters.__index = DepthEncounters

function DepthEncounters.new(mod, controller, definitions)
  return setmetatable({
    mod = mod,
    controller = controller,
    definitions = definitions or {},
  }, DepthEncounters)
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

function DepthEncounters:currentBand()
  local state = self.controller and self.controller.state
  local ow = Game.overworld
  local map = ow and ow.map
  if not (state and state.active and map) then return nil end
  return self:band(map.id, state.depth), map.id
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
      local band = service:currentBand()
      if band then
        return innerRoll(service:encounterDefinition(band), rng)
      end
    end
    return innerRoll(encounterDef, rng)
  end
  Encounter.dramaticDeepDiveDepthHook = true
  return true
end

return DepthEncounters
