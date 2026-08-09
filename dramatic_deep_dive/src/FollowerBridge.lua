local PikachuFollower = require("src.world.PikachuFollower")

local FollowerBridge = {}
FollowerBridge.__index = FollowerBridge

local WILDS_MOD_ID = "overworld_wild_spawns"
local FOLLOWER_MOD_IDS = {
  "FOLLOWERS_EX",
  "followers_ex",
  "PokePCFollowers_VoxelMerge",
  "pokepcfollowers",
}

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then return true end
  end
  return false
end

local function isFollowerEntity(entity, player)
  if not entity or entity == player then return false end
  local spriteDef = entity.sprite and entity.sprite.def
  local defId = spriteDef and spriteDef.id
  local id = tostring(entity.id or ""):lower()
  local spriteId = tostring(entity.spriteId or defId or ""):upper()
  return entity.pikachuFollower == true
    or entity.pokepcTrailer == true
    or entity.wildsFollower == true
    or entity.pokepcMon ~= nil
    or entity._pokepcFollowerSpecies ~= nil
    or id == "pikachu"
    or id:find("pokepc", 1, true) ~= nil
    or spriteId == "SPRITE_PIKACHU"
    or spriteId:find("POKEPC", 1, true) ~= nil
end

local function removeFollowers(list, player, captured)
  for i = #(list or {}), 1, -1 do
    local entity = list[i]
    if isFollowerEntity(entity, player) then
      if captured and not contains(captured, entity) then captured[#captured + 1] = entity end
      table.remove(list, i)
    end
  end
end

function FollowerBridge.new(mod)
  return setmetatable({ mod = mod }, FollowerBridge)
end

function FollowerBridge:purge(overworld, captured)
  if not overworld then return captured end
  captured = captured or { mapId = overworld.map and overworld.map.id, entities = {}, npcs = {} }
  captured.entities = captured.entities or {}
  captured.npcs = captured.npcs or {}
  removeFollowers(overworld.entities, overworld.player, captured.entities)
  removeFollowers(overworld.npcs, overworld.player, captured.npcs)
  return captured
end

function FollowerBridge:suspend(overworld)
  return self:purge(overworld, {
    mapId = overworld and overworld.map and overworld.map.id,
    entities = {}, npcs = {},
  })
end

function FollowerBridge:hasFollower(overworld)
  if not overworld then return false end
  for _, list in ipairs({ overworld.entities or {}, overworld.npcs or {} }) do
    for _, entity in ipairs(list) do
      if isFollowerEntity(entity, overworld.player) then return true end
    end
  end
  return false
end

function FollowerBridge:_exports(id)
  if not self.mod.find then return nil end
  local okFind, handle = pcall(self.mod.find, self.mod, id)
  return okFind and handle and handle.exports or nil
end

function FollowerBridge:syncMods(game, overworld)
  if not (game and overworld) then return false end

  -- Wilds is a complete follower runtime. When present, it is authoritative:
  -- do not also call PokéPC / Followers EX lifecycle functions, which would
  -- create competing owners. A successful sync is authoritative even when
  -- the configured follower count is zero or the player is surfing.
  local wilds = self:_exports(WILDS_MOD_ID)
  if wilds and type(wilds.syncAll) == "function" then
    local ok, err = pcall(wilds.syncAll, game, overworld)
    if not ok and self.mod.log then
      self.mod.log:warn("Wilds follower sync failed: %s", tostring(err))
    end
    return ok == true
  end

  if PikachuFollower and type(PikachuFollower.onMapEntered) == "function" then
    pcall(PikachuFollower.onMapEntered, game, overworld, {})
  end
  for _, id in ipairs(FOLLOWER_MOD_IDS) do
    local exports = self:_exports(id)
    if exports then
      if type(exports.syncAll) == "function" then pcall(exports.syncAll, game, overworld)
      elseif type(exports.sync) == "function" then pcall(exports.sync, game, overworld) end
    end
  end
  return self:hasFollower(overworld)
end

function FollowerBridge:restore(game, overworld, captured)
  if not (game and overworld and overworld.map) then return false end
  self:purge(overworld)

  -- Followers are not supposed to appear while Surfing. SURFACE returns to
  -- ordinary Surf, so leave them suspended until their own mod respawns them
  -- after the player dismounts.
  if overworld.player and overworld.player.surfing then return true end
  if self:syncMods(game, overworld) then return true end

  if captured and captured.mapId == overworld.map.id then
    for _, entity in ipairs(captured.npcs or {}) do
      if not contains(overworld.npcs, entity) then table.insert(overworld.npcs, entity) end
    end
    for _, entity in ipairs(captured.entities or {}) do
      if not contains(overworld.entities, entity) then table.insert(overworld.entities, entity) end
    end
  end
  return true
end

return FollowerBridge
