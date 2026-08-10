-- Contract: with Wilds of Kanto installed, Deep Dive underwater battles may
-- only come from visible overworld wildlife interception. Vanilla/random rolls
-- must be suppressed even during controller transition/band edge frames.
local root = arg and arg[0] and arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path

-- The generated engine-facing encounter table itself must be inert. Deep Dive
-- supplies standalone depth-band rates dynamically only when Wilds is absent.
local generatorFile = assert(io.open(root .. "/src/SeabedGenerator.lua", "r"))
local generatorSource = generatorFile:read("*a")
generatorFile:close()
assert(generatorSource:find("grass = { rate = 0, slots = first.slots }", 1, true),
  "generated underwater vanilla encounter record must have permanent rate 0")

local game = {
  overworld = { map = { id = "DDD_SEABED_ROUTE_TEST" } },
  mods = { exports = { overworld_wild_spawns = {} } },
}

local innerCalls = 0
local Encounter = {
  roll = function(def, _rng)
    innerCalls = innerCalls + 1
    local grass = def and def.grass
    if grass and (grass.rate or 0) > 0 then
      return { species = "MAGIKARP", level = 5 }
    end
    return nil
  end,
}

package.preload["src.core.Game"] = function() return game end
package.preload["src.world.Encounter"] = function() return Encounter end

local DepthEncounters = dofile(root .. "/src/DepthEncounters.lua")
local controller = { state = { active = false, depth = 120 } }
local definitions = {
  DDD_SEABED_ROUTE_TEST = {
    { minDepth = 0, maxDepth = 9999, rate = 6,
      slots = { { species = "MAGIKARP", level = 5 } } },
  },
}
local mod = {
  find = function(_, id)
    if id == "overworld_wild_spawns" then return { exports = {} } end
  end,
}

local service = DepthEncounters.new(mod, controller, definitions)
service:install()

-- The hard gate must work even while the controller says inactive. This is the
-- transition-frame hole that the old band-dependent gate could leave open.
local random = Encounter.roll({ grass = { rate = 255, slots = {} } }, {})
assert(random == nil, "Wilds must suppress random Deep Dive encounters")
assert(innerCalls == 0, "Wilds hard gate must stop the vanilla roll entirely")

-- Outside a managed Deep Dive underwater map the wrapper must stay transparent.
game.overworld.map.id = "ROUTE_TEST"
local outside = Encounter.roll({ grass = { rate = 255, slots = {} } }, {})
assert(outside and outside.species == "MAGIKARP", "normal maps must retain normal encounter behavior")
assert(innerCalls == 1, "outside Deep Dive, inner Encounter.roll must run")

-- Without Wilds, Deep Dive should still inject its own depth-band encounter
-- table even though generated engine-facing encounter records are rate zero.
mod.find = function() return nil end
game.mods.exports.overworld_wild_spawns = nil
game.overworld.map.id = "DDD_SEABED_ROUTE_TEST"
controller.state.active = true
local standalone = Encounter.roll({ grass = { rate = 0, slots = {} } }, {})
assert(standalone and standalone.species == "MAGIKARP",
  "standalone Deep Dive must still use depth-band encounters")
assert(innerCalls == 2, "standalone depth-band encounter must call inner roll once")

print("Wilds overworld-only encounter gate OK")
