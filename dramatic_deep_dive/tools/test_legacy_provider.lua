package.path = "dramatic_deep_dive/?.lua;dramatic_deep_dive/?/init.lua;" .. package.path

package.preload["src.render.Pipelines"] = function()
  return {
    get = function(id)
      if id == "voxel" or id == "st_voxel" then return { id = id } end
      return nil
    end,
  }
end

local modules = {
  Voxel3D = { beginScene = function() end, endScene = function() end },
  FreeMove = { tick = function() end },
  FirstPerson = {},
  StadiumRig = { new = function() return {} end },
  StadiumPack = { tracks = function() return {} end },
}
local legacyHandle = {
  version = "0.7.96",
  exports = {
    lib = {
      require = function(name) return modules[name] end,
    },
  },
}
local externalTagged = {}
local stadiumOverworldHandle = {
  exports = {
    tag = function(entity, species)
      externalTagged[entity] = species
      return true
    end,
    untag = function(entity)
      externalTagged[entity] = nil
      return true
    end,
  },
}

local handles = {
  DRAMATIC_SHAPE = legacyHandle,
  STADIUM_OVERWORLD_MODELS = stadiumOverworldHandle,
}
local mod = {
  exports = {},
  log = { info = function() end, warn = function() end, error = function() end },
}
function mod:find(id) return handles[id] end

local VoxelProvider = dofile("dramatic_deep_dive/src/VoxelProvider.lua")
local provider = VoxelProvider.new(mod)
assert(provider:discover(), "legacy Dramatic Shape should be discoverable")
assert(provider:id() == "DRAMATIC_SHAPE", "wrong legacy provider selected")
assert(provider:isLegacy(), "legacy provider flag missing")
assert(provider:pipelineId() == "voxel", "legacy voxel pipeline should resolve")
assert(provider:supportsFreeMove(), "legacy provider should expose free-move stack")
assert(mod.exports._dramaticProviderState.legacy == true, "legacy export state missing")
assert(mod.exports._dramaticProviderState.dramaticShape == legacyHandle,
  "legacy provider handle not exported")

assert(provider:installCompatibilityShim(), "private Battle Art alias shim failed")
assert(mod:find("BATTLE_ART_VOXEL_FORK") == legacyHandle,
  "old Deep Dive Battle Art lookups must resolve to selected legacy provider")
assert(mod:find("STADIUM_OVERWORLD_MODELS") == stadiumOverworldHandle,
  "provider shim must not hide unrelated mods")

local Game = { overworld = nil }
package.loaded["src.core.Game"] = nil
package.preload["src.core.Game"] = function() return Game end

local hooks = {}
local events = {}
mod.hooks = {
  wrap = function(_, name, fn, priority)
    hooks[name] = { fn = fn, priority = priority }
  end,
}
mod.events = {
  on = function(_, name, fn) events[name] = fn end,
}
mod.exports.isActive = function() return true end

local LegacyBridge = dofile("dramatic_deep_dive/src/Stadium2LegacyBridge.lua")
local bridge = LegacyBridge.new(mod)
assert(bridge:externalInstalled(), "legacy Stadium Overworld install was not detected")
assert(bridge:install(), "legacy Stadium bridge failed to install")

local fish = {
  deepDiveWildlife = true,
  species = "MAGIKARP",
  px = 64,
  py = 80,
  depth = 40,
  dead = false,
}
Game.overworld = { entities = { fish } }
assert(bridge:scan(), "legacy bridge scan failed")
assert(externalTagged[fish] == "MAGIKARP", "underwater Pokemon was not delegated")
assert(fish.dramaticDeepDiveLegacyStadium == true, "legacy entity diagnostic tag missing")

local stats = bridge:stats()
assert(stats.mode == "legacy_delegate", "wrong legacy bridge mode")
assert(stats.provider == "DRAMATIC_SHAPE", "wrong provider in legacy stats")
assert(stats.externalInstalled == true and stats.externalReady == true,
  "legacy external renderer readiness not reported")
assert(stats.tagged == 1, "legacy tag count incorrect")

bridge:clear()
assert(externalTagged[fish] == nil, "legacy untag did not clean up")

print("Legacy Dramatic Shape provider/Stadium delegation OK")
