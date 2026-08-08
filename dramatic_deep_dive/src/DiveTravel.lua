local DiveTravel = {}
DiveTravel.__index = DiveTravel

local SESSION_KEY = "travelSession"

local function containsRect(point, rect)
  return point.x >= rect.x and point.x < rect.x + rect.width
    and point.y >= rect.y and point.y < rect.y + rect.height
end

local function listContains(list, value)
  for _, item in ipairs(list or {}) do if item == value then return true end end
  return false
end

local function monKnows(mon, moveId)
  for _, move in ipairs(mon and mon.moves or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end

local function removeLabel(items, label)
  for index = #items, 1, -1 do
    if items[index] and items[index].label == label then table.remove(items, index) end
  end
end

local function alreadyHas(items, label)
  for _, item in ipairs(items or {}) do if item.label == label then return true end end
  return false
end

local function insertBeforeStats(items, item)
  local index = #items + 1
  for i, existing in ipairs(items) do if existing.label == "STATS" then index = i break end end
  table.insert(items, index, item)
end

function DiveTravel.new(mod, definitions)
  return setmetatable({ mod = mod, zones = definitions or {}, transition = nil }, DiveTravel)
end

function DiveTravel:setTransition(transition)
  self.transition = transition
end

function DiveTravel:getSession() return self.mod.save:get(SESSION_KEY) end
function DiveTravel:setSession(value) self.mod.save:set(SESSION_KEY, value) end

function DiveTravel:current(game)
  local ow = game and game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (player and map) then return nil end
  return {
    mapId = map.id,
    x = player.cellX,
    y = player.cellY,
    facing = player.facing or "down",
    surfing = player.surfing == true,
  }
end

function DiveTravel:hasBadge(game, badge)
  local inventory = game and game.save and game.save.inventory
  return inventory and inventory[badge] ~= nil and inventory[badge] ~= false
end

function DiveTravel:zoneForUnderwaterMap(mapId)
  for id, zone in pairs(self.zones) do
    if zone.underwaterMapId == mapId or listContains(zone.submergedMaps, mapId) then
      return zone, id
    end
  end
  return nil
end

function DiveTravel:diveTarget(position)
  if not position then return nil end
  for zoneId, zone in pairs(self.zones) do
    for _, link in ipairs(zone.links or {}) do
      if position.mapId == link.surface.mapId and containsRect(position, {
        x = link.surface.x, y = link.surface.y, width = link.width, height = link.height,
      }) then
        return {
          mapId = link.underwater.mapId,
          x = link.underwater.x + (position.x - link.surface.x),
          y = link.underwater.y + (position.y - link.surface.y),
          facing = position.facing,
          linkId = link.id,
          zoneId = zoneId,
        }, zone, zoneId
      end
    end
  end
  return nil
end

function DiveTravel:surfaceTarget(position)
  if not position then return nil end
  for zoneId, zone in pairs(self.zones) do
    for _, link in ipairs(zone.links or {}) do
      if position.mapId == link.underwater.mapId and containsRect(position, {
        x = link.underwater.x, y = link.underwater.y, width = link.width, height = link.height,
      }) then
        return {
          mapId = link.surface.mapId,
          x = link.surface.x + (position.x - link.underwater.x),
          y = link.surface.y + (position.y - link.underwater.y),
          facing = position.facing,
          linkId = link.id,
          zoneId = zoneId,
        }, zone, zoneId
      end
    end
  end
  return nil
end

function DiveTravel:surfaceTargetIsWater(game, target)
  if not (game and game.data and target) then return false end
  local okMap, Map = pcall(require, "src.world.Map")
  if not (okMap and Map and type(Map.defIsWaterCell) == "function") then return true end
  local def = game.data.maps and game.data.maps[target.mapId]
  local tileset = def and game.data.tilesets and game.data.tilesets[def.tileset]
  return def ~= nil and tileset ~= nil and Map.defIsWaterCell(def, tileset, target.x, target.y) == true
end

function DiveTravel:setSurfing(game, enabled, surfMusic)
  local save = game and game.save
  local ow = game and game.overworld
  if save then
    save.onBike = false
    save.forcedBike = nil
    if save.player then save.player.surfing = enabled and true or false end
  end
  if ow and ow.player then ow.player.surfing = enabled and true or false end
  if ow and type(ow.syncSurfingPikachu) == "function" then pcall(ow.syncSurfingPikachu, ow) end
  local okMusic, Music = pcall(require, "src.core.Music")
  if okMusic and Music and game and game.data and ow and ow.map then
    pcall(Music.playMap, game.data, ow.map.id, false, surfMusic and true or false)
  end
end

function DiveTravel:displayName(game, mon)
  if mon and mon.nickname and mon.nickname ~= "" then return mon.nickname end
  local species = mon and game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
  return species and species.name or "POKEMON"
end

function DiveTravel:closePartyMenu(game)
  local stack = game and game.stack
  local top = stack and stack.top and stack:top()
  if top and type(top.close) == "function" then top:close()
  elseif top and stack and stack.pop then stack:pop() end
end

function DiveTravel:showText(game, text, onDone)
  if not (game and game.stack and self.mod.ui and self.mod.ui.TextBox) then
    if onDone then onDone() end
    return
  end
  game.stack:push(self.mod.ui.TextBox.new(game, text, onDone))
end

function DiveTravel:beginDive(mon, game, zone, zoneId, position, target)
  self:closePartyMenu(game)
  self:showText(game, self:displayName(game, mon) .. " used DIVE!", function()
    self:setSession({ active = true, zoneId = zoneId, linkId = target.linkId })
    self:setSurfing(game, true, false)

    local function doWarp()
      local ok, err = self.mod.world:warpTo(target.mapId, target.x, target.y,
        target.facing or position.facing, { onDone = function()
          self:setSurfing(game, true, false)
          self.mod.events:emit("mod.dramatic_deep_dive.entered", {
            zoneId = zoneId, linkId = target.linkId,
            mapId = target.mapId, x = target.x, y = target.y,
          })
        end })
      if not ok then
        self:setSession(nil)
        self.mod.log:error("DIVE warp failed: %s", tostring(err))
        return false
      end
      return true
    end

    if not (self.transition and self.transition:beginDive(doWarp)) then doWarp() end
  end)
end

function DiveTravel:beginSurface(mon, game, zone, zoneId, position, target)
  self:closePartyMenu(game)
  self:showText(game, self:displayName(game, mon) .. " used SURFACE!", function()
    self:setSurfing(game, true, false)

    local function doWarp()
      local ok, err = self.mod.world:warpTo(target.mapId, target.x, target.y,
        target.facing or position.facing, { onDone = function()
          self:setSession(nil)
          self:setSurfing(game, true, true)
          self.mod.events:emit("mod.dramatic_deep_dive.surfaced", {
            zoneId = zoneId, linkId = target.linkId,
            mapId = target.mapId, x = target.x, y = target.y,
          })
        end })
      if not ok then
        self.mod.log:error("SURFACE warp failed: %s", tostring(err))
        return false
      end
      return true
    end

    if not (self.transition and self.transition:beginSurface(doWarp)) then doWarp() end
  end)
end

function DiveTravel:install()
  local service = self
  self.mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
    local out = next(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end

    local position = service:current(game)
    local underwater = position and service:zoneForUnderwaterMap(position.mapId)
    if underwater then removeLabel(out, "SURF") end
    if not (position and mon and monKnows(mon, "DIVE")) then return out end

    if underwater then
      local target, zone, zoneId = service:surfaceTarget(position)
      if target and service:surfaceTargetIsWater(game, target) and not alreadyHas(out, "SURFACE") then
        insertBeforeStats(out, {
          label = "SURFACE",
          onSelect = function(selected, activeGame)
            service:beginSurface(selected, activeGame, zone, zoneId, position, target)
          end,
        })
      end
      return out
    end

    local target, zone, zoneId = service:diveTarget(position)
    if target and zone and position.surfing and service:hasBadge(game, zone.requiredBadge)
        and not alreadyHas(out, "DIVE") then
      insertBeforeStats(out, {
        label = "DIVE",
        onSelect = function(selected, activeGame)
          service:beginDive(selected, activeGame, zone, zoneId, position, target)
        end,
      })
    end
    return out
  end)

  self.mod.hooks:wrap("fieldmove.eligibility", function(next, moveId, ctx)
    local position = service:current(require("src.core.Game"))
    if moveId == "SURF" and position and service:zoneForUnderwaterMap(position.mapId) then return nil end
    return next(moveId, ctx)
  end)

  self.mod.events:on("map.entered", function(event)
    if not (event and event.mapId) then return end
    local zone, zoneId = service:zoneForUnderwaterMap(event.mapId)
    if zone then
      local Game = require("src.core.Game")
      service:setSurfing(Game, true, false)
      local state = service:getSession()
      if not (state and state.active) then
        service:setSession({ active = true, zoneId = zoneId, orphaned = true })
      else
        state.zoneId = zoneId
        state.mapId = event.mapId
        service:setSession(state)
      end
      service.mod.events:emit("mod.dramatic_deep_dive.entered", { zoneId = zoneId, mapId = event.mapId })
      return
    end
    local state = service:getSession()
    if state and state.active then service:setSession(nil) end
  end)
end

function DiveTravel:canDiveHere(game)
  local position = self:current(game)
  if not (position and position.surfing) then return false end
  local target, zone = self:diveTarget(position)
  return target ~= nil and zone ~= nil and self:hasBadge(game, zone.requiredBadge)
end

function DiveTravel:canSurfaceHere(game)
  local position = self:current(game)
  if not position then return false end
  local target = self:surfaceTarget(position)
  return target ~= nil and self:surfaceTargetIsWater(game, target)
end

return DiveTravel
