package.path = "dramatic_deep_dive/?.lua;dramatic_deep_dive/?/init.lua;" .. package.path

local Game = {
  data = {
    pokemon = {
      MAGIKARP = { dex = 129, dexEntry = { heightFt = 2, heightIn = 11 } },
      HORSEA = { dex = 116, dexEntry = { heightFt = 1, heightIn = 4 } },
      TENTACOOL = { dex = 72, dexEntry = { heightFt = 2, heightIn = 11 } },
      TENTACRUEL = { dex = 73, dexEntry = { heightFt = 5, heightIn = 3 } },
      LAPRAS = { dex = 131, dexEntry = { heightFt = 8, heightIn = 2 } },
      GYARADOS = { dex = 130, dexEntry = { heightFt = 21, heightIn = 4 } },
      TINY = { dex = 1, dexEntry = { heightFt = 0, heightIn = 1 } },
      HUGE = { dex = 2, dexEntry = { heightFt = 99, heightIn = 0 } },
    },
  },
}

package.preload["src.core.Game"] = function() return Game end
package.preload["src.render.SpriteRenderer"] = function()
  return { new = function(def) return { def = def } end }
end

local Stadium = dofile("dramatic_deep_dive/src/Stadium2Underwater.lua")
local height = Stadium.worldHeight

assert(height("HORSEA") >= 8.5, "small Pokemon must stay readable")
assert(height("TENTACRUEL") > height("TENTACOOL"), "species size ladder collapsed")
assert(height("LAPRAS") > height("MAGIKARP"), "large aquatic Pokemon should be visibly larger")
assert(height("GYARADOS") > height("LAPRAS"), "Gyarados should remain imposing")
assert(height("TINY") == 8.5, "lower hard cap changed")
assert(height("HUGE") == 46, "upper hard cap changed")

local mod = { exports = {}, log = {} }
local service = Stadium.new(mod, {})
local player = { px = 0, py = 0, cellX = 0, cellY = 0 }
local entities = { player }
for i = 1, 14 do
  entities[#entities + 1] = {
    deepDiveWildlife = true,
    species = "MAGIKARP",
    px = i * 16,
    py = 0,
    dead = false,
  }
end
entities[#entities + 1] = {
  deepDiveWildlife = true,
  species = "GYARADOS",
  px = 25 * 16,
  py = 0,
  dead = false,
}
Game.overworld = { player = player, entities = entities }
service:selectNearest()

local selected, farSelected, maxDistance = 0, false, 0
for swimmer in pairs(service.selected) do
  selected = selected + 1
  local d = math.abs((swimmer.px or 0) / 16)
  maxDistance = math.max(maxDistance, d)
  if d > 24 then farSelected = true end
end
assert(selected == 10, "LOD must select exactly the nearest 10 eligible swimmers")
assert(not farSelected, "LOD selected a swimmer outside the 24-cell range")
assert(maxDistance == 10, "LOD did not choose the nearest swimmers first")

print("Stadium 2 underwater scale/LOD policy OK")
