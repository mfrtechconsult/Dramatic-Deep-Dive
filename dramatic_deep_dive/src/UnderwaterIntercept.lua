local Game = require("src.core.Game")

local UnderwaterIntercept = {}
UnderwaterIntercept.__index = UnderwaterIntercept

local CELL = 16

-- Dramatic Sky Ride uses a forgiving two-cell Wild Skies envelope because a
-- moving sprite is annoying to hit exactly. Deep Dive keeps that philosophy
-- but gives the 3D underwater case a little more horizontal room as the player
-- must also match depth.
local INTERCEPT_RADIUS_CELLS = 3
local INTERCEPT_DEPTH_PIXELS = 80
local SIZE_RADIUS_BONUS = 7
local SIZE_DEPTH_BONUS = 20
local PENDING_BATTLE_SECONDS = 4
local POST_BATTLE_REST = 4.5

function UnderwaterIntercept.new(mod, controller, wildlife)
  return setmetatable({
    mod = mod,
    controller = controller,
    wildlife = wildlife,
    wildsPresent = nil,
    cooldown = 0,
    expectedBattle = 0,
    intercepted = 0,
  }, UnderwaterIntercept)
end

function UnderwaterIntercept:wildsInstalled()
  if self.wildsPresent ~= nil then return self.wildsPresent == true end
  local present = false
  if self.mod and self.mod.find then
    local ok, handle = pcall(self.mod.find, self.mod, "overworld_wild_spawns")
    present = ok and handle ~= nil
  end
  if not present then
    local exports = Game and Game.mods and Game.mods.exports
    present = exports and exports.overworld_wild_spawns ~= nil or false
  end
  self.wildsPresent = present == true
  return self.wildsPresent
end

function UnderwaterIntercept:envelope(swimmer)
  local scale = tonumber(swimmer and swimmer.visualScale) or 1
  local extra = math.max(0, scale - 1)
  return INTERCEPT_RADIUS_CELLS * CELL + extra * SIZE_RADIUS_BONUS,
         INTERCEPT_DEPTH_PIXELS + extra * SIZE_DEPTH_BONUS
end

function UnderwaterIntercept:nearest(player)
  local state = self.controller and self.controller.state
  if not (state and state.active and player) then return nil end

  local playerX = (player.px or player.cellX * CELL) + CELL / 2
  local playerY = (player.py or player.cellY * CELL) + CELL / 2
  local playerDepth = tonumber(state.depth) or 0
  local best, bestScore

  for _, swimmer in ipairs(self.wildlife and self.wildlife.swimmers or {}) do
    if swimmer and not swimmer.dead and swimmer.species then
      local radius, depthTolerance = self:envelope(swimmer)
      local dx = (tonumber(swimmer.px) or 0) + CELL / 2 - playerX
      local dy = (tonumber(swimmer.py) or 0) + CELL / 2 - playerY
      local horizontal = math.sqrt(dx * dx + dy * dy)
      local depthDelta = math.abs((tonumber(swimmer.depth) or 0) - playerDepth)

      if horizontal <= radius and depthDelta <= depthTolerance then
        -- Rank by normalised 3D proximity so a fish directly beside the rider
        -- beats one that merely shares the same map cells at another depth.
        local h = horizontal / math.max(1, radius)
        local d = depthDelta / math.max(1, depthTolerance)
        local score = h * h + d * d
        if not bestScore or score < bestScore then
          best, bestScore = swimmer, score
        end
      end
    end
  end
  return best
end

function UnderwaterIntercept:tryIntercept(overworld)
  if not self:wildsInstalled() then return false end
  if (self.cooldown or 0) > 0 or (self.expectedBattle or 0) > 0 then return false end
  local state = self.controller and self.controller.state
  local player = overworld and overworld.player
  if not (state and state.active and player) then return false end

  local stack = Game.stack
  if stack and stack.top and stack:top() ~= overworld then return false end

  local swimmer = self:nearest(player)
  if not swimmer then return false end
  if not (self.mod.world and self.mod.world.queueScript) then return false end

  local species = swimmer.species
  local level = tonumber(swimmer.level) or 5
  local pokemonDepth = tonumber(swimmer.depth)
  local ok, queued = pcall(self.mod.world.queueScript, self.mod.world, {
    { "start_battle", "wild", species, level },
  })
  if not ok or queued == false then
    if self.mod.log then
      self.mod.log:warn("underwater interception failed: %s", tostring(queued))
    end
    return false
  end

  if self.wildlife and self.wildlife.remove then
    self.wildlife:remove(swimmer, overworld)
    self.wildlife.consumed = (self.wildlife.consumed or 0) + 1
  end
  self.intercepted = self.intercepted + 1
  self.cooldown = 1.25
  self.expectedBattle = PENDING_BATTLE_SECONDS

  pcall(function() require("src.core.Sound").playCry(Game.data, species) end)
  pcall(function()
    self.mod.events:emit("mod.DRAMATIC_DEEP_DIVE.wildlife_intercepted", {
      species = species,
      level = level,
      depth = state.depth,
      pokemonDepth = pokemonDepth,
    })
  end)
  if self.mod.log then
    self.mod.log:info("intercepted underwater %s Lv.%s", tostring(species), tostring(level))
  end
  return true
end

function UnderwaterIntercept:install()
  local service = self

  -- Wildlife itself runs at input.step priority 70 and updates after next().
  -- Priority 60 therefore checks interception before the priority-70 service
  -- gets its post-next movement tick, so crossing the envelope counts before
  -- the swimmer gets another chance to flee away from the player.
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    local frameDt = tonumber(dt) or (1 / 60)
    service.cooldown = math.max(0, (service.cooldown or 0) - frameDt)
    service.expectedBattle = math.max(0, (service.expectedBattle or 0) - frameDt)

    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then service:tryIntercept(ow) end
    return result
  end, 60)

  self.mod.events:on("game.ready", function()
    service.wildsPresent = nil
  end)
  self.mod.events:on("battle.started", function()
    service.expectedBattle = 0
  end)
  self.mod.events:on("battle.ended", function()
    local state = service.controller and service.controller.state
    if state and state.active then service.cooldown = POST_BATTLE_REST end
  end)
  self.mod.events:on("mod.DRAMATIC_DEEP_DIVE.surfaced", function()
    service.cooldown = 0
    service.expectedBattle = 0
  end)
  return true
end

function UnderwaterIntercept:stats()
  return {
    enabled = self:wildsInstalled(),
    intercepted = self.intercepted,
    cooldown = self.cooldown,
    radiusCells = INTERCEPT_RADIUS_CELLS,
    depthTolerance = INTERCEPT_DEPTH_PIXELS,
  }
end

return UnderwaterIntercept
