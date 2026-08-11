-- Contract: with Wilds of Kanto installed, Deep Dive underwater battles may
-- only come from visible overworld wildlife interception. Classic/random rolls
-- must be suppressed at Gen1Recomp's public encounter hooks.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

local generatorFile = assert(io.open(root .. "/src/SeabedGenerator.lua", "r"))
local generatorSource = generatorFile:read("*a")
generatorFile:close()
assert(generatorSource:find("grass = { rate = 0, slots = first.slots }", 1, true),
  "generated underwater vanilla encounter record must have permanent rate 0")

local game = {
  overworld = { map = { id = "DDD_SEABED_ROUTE_TEST" } },
  mods = { exports = { overworld_wild_spawns = {} } },
}
package.preload["src.core.Game"] = function() return game end

-- Minimal faithful hook chain: higher priority runs first, and a wrapper may
-- force/suppress a result without calling next().
local Hooks = {}
Hooks.__index = Hooks
function Hooks.new() return setmetatable({ chains = {} }, Hooks) end
function Hooks:wrap(name, callback, priority)
  local chain = self.chains[name] or {}
  self.chains[name] = chain
  chain[#chain + 1] = { callback = callback, priority = priority or 0 }
  table.sort(chain, function(a, b) return a.priority > b.priority end)
end
function Hooks:call(name, vanilla, ...)
  local chain = self.chains[name] or {}
  local args = { ... }
  local function run(i, current)
    if i > #chain then return vanilla(table.unpack(current)) end
    local entry = chain[i]
    return entry.callback(function(...)
      local nextArgs = select("#", ...) > 0 and { ... } or current
      return run(i + 1, nextArgs)
    end, table.unpack(current))
  end
  return run(1, args)
end

local hooks = Hooks.new()
local controller = { state = { active = false, depth = 120 } }
local definitions = {
  DDD_SEABED_ROUTE_TEST = {
    { minDepth = 0, maxDepth = 9999, rate = 6,
      slots = { { species = "MAGIKARP", level = 5 } } },
  },
}
local mod = {
  hooks = hooks,
  find = function(_, id)
    if id == "overworld_wild_spawns" then return { exports = {} } end
  end,
}

local DepthEncounters = dofile(root .. "/src/DepthEncounters.lua")
local service = DepthEncounters.new(mod, controller, definitions)
assert(service:install() == true)

local vanillaCalls = 0
local function vanillaRoll(def)
  vanillaCalls = vanillaCalls + 1
  local grass = def and def.grass
  if grass and (grass.rate or 0) > 0 then
    return { species = "MAGIKARP", level = 5 }
  end
  return nil
end
local function vanillaSpecies(enc) return enc end

local underwaterCtx = { mapId = "DDD_SEABED_ROUTE_TEST", rng = function() return 0 end }
local outsideCtx = { mapId = "ROUTE_TEST", rng = function() return 0 end }

-- Simulate Wilds/default companion behavior downstream at priority 0 that can
-- force a random result. Deep Dive's public roll hook must swallow it before it
-- is reached, even while the controller is inactive during a transition frame.
hooks:wrap("encounter.roll", function(_next, _def, _ctx)
  return { species = "RATTATA", level = 4 }
end, 0)
local random = hooks:call("encounter.roll", vanillaRoll,
  { grass = { rate = 255, slots = {} } }, underwaterCtx)
assert(random == nil, "Wilds + Deep Dive must suppress the entire encounter.roll chain")
assert(vanillaCalls == 0, "suppression must happen before vanilla roll")

-- Even a hypothetical wrapper with a still-higher roll priority can force a
-- result without calling Deep Dive's roll hook. Gen1Recomp then invokes the
-- species hook for every non-nil roll; the second Deep Dive gate must kill it.
hooks:wrap("encounter.roll", function(_next, _def, _ctx)
  return { species = "ZUBAT", level = 9 }
end, 2000000)
local forced = hooks:call("encounter.roll", vanillaRoll,
  { grass = { rate = 255, slots = {} } }, underwaterCtx)
assert(forced and forced.species == "ZUBAT", "test precondition: higher-priority hook forces roll")
local final = hooks:call("encounter.species", vanillaSpecies, forced, underwaterCtx)
assert(final == nil, "encounter.species safety gate must cancel a forced underwater roll")

-- Normal Kanto maps remain untouched.
local outside = hooks:call("encounter.roll", vanillaRoll,
  { grass = { rate = 255, slots = {} } }, outsideCtx)
assert(outside ~= nil, "outside Deep Dive the encounter chain must remain available")

-- Without Wilds, Deep Dive injects the live depth-band table into the public
-- hook chain even though the registered map encounter rate itself is zero.
mod.find = function() return nil end
game.mods.exports.overworld_wild_spawns = nil
controller.state.active = true
-- Use a clean hook chain for standalone behavior so the synthetic force hooks
-- above do not interfere with this assertion.
local hooks2 = Hooks.new()
mod.hooks = hooks2
local standaloneService = DepthEncounters.new(mod, controller, definitions)
assert(standaloneService:install() == true)
local standalone = hooks2:call("encounter.roll", vanillaRoll,
  { grass = { rate = 0, slots = {} } }, underwaterCtx)
assert(standalone and standalone.species == "MAGIKARP",
  "standalone Deep Dive must still use depth-band encounters")

print("Wilds visible-only public encounter hook gate OK")
