  state.targetDepth = clamp(tonumber(depth) or state.targetDepth,
    state.volume.minDepth, maxDepth)
  state.hudTimer = DEPTH_HUD_SECONDS
  self:saveState()
  return true
end

function DeepDive:runInsideSwimVolume(overworld, fn)
  local state = self.state
  local map = overworld and overworld.map
  if not (state.active and state.volume and map) then return fn() end

  local rawWalk = rawget(map, "isWalkableCell")
  local hadRawWalk = rawWalk ~= nil
  local oldOccupied = Collision.occupied
  local oldDefPassable = Map.defPassable
  local field = Game.data and Game.data.field
  local oldPairs = field and field.tilePairs
  local registry = self.registry
  local mapId = map.id

  map.isWalkableCell = function(_, x, y)
    return registry:contains(mapId, x, y)
  end
  Collision.occupied = function() return nil end
  Map.defPassable = function(def, tileset, x, y, surfing)
    if def and def.id == mapId then return registry:contains(mapId, x, y) end
    return oldDefPassable(def, tileset, x, y, surfing)
  end
  if field then field.tilePairs = { land = {}, water = {} } end

  local ok, result = pcall(fn)

  if hadRawWalk then map.isWalkableCell = rawWalk
  else rawset(map, "isWalkableCell", nil) end
  Collision.occupied = oldOccupied
  Map.defPassable = oldDefPassable
  if field then field.tilePairs = oldPairs end

  if not ok then error(result, 0) end
  return result
end

function DeepDive:installHooks()
  local controller = self

  local playerPose = Player.pose
  function Player:pose()
    local sprite, px, py, facing, phase, flip, hopping = playerPose(self)
    local state = controller.state
    local ow = Game.overworld
    if state.active and ow and ow.player == self then
      local visual = state.mountSprite or sprite
      local swimPhase = math.floor((self.animClock or 0) / 12) % 2
      return visual, self.px, self.py - controller:mountLift(),
        facing, swimPhase, flip, false
    end
    return sprite, px, py, facing, phase, flip, hopping
  end

  self.mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    local state = controller.state
    local ow = Game.overworld
    if not (state.active and ow and ctx and ctx.mover == ow.player) then return result end
    local mapId = ow.map and ow.map.id
    if mapId and controller.registry:contains(mapId, ctx.toX, ctx.toY) then
      ctx.reason = nil
      return true
    end
    ctx.reason = "deep_dive_volume"
    return false
  end, 95)

  local handleInput = OverworldState.handleInput
  function OverworldState:handleInput(...)
    if not (controller.state.active and Game.overworld == self) then
      return handleInput(self, ...)
    end
    local args = { ... }
    return controller:runInsideSwimVolume(self, function()
      return handleInput(self, unpackArgs(args))
    end)
  end

  local update = OverworldState.update
  function OverworldState:update(dt, ...)
    local result = update(self, dt, ...)
    if controller.state.active and Game.overworld == self then
      controller:updateDepth(tonumber(dt) or (1 / 60))
    end
    return result
  end

  local drawUI = OverworldState.drawUI
  function OverworldState:drawUI(...)
    local result = drawUI(self, ...)
    local state = controller.state
    if not (state.active and Game.overworld == self and love and love.graphics) then
      return result
    end

    local mode = optionValue(controller.mod, "depth_display", "temporary")
    local visible = mode == "always" or (mode == "temporary" and (state.hudTimer or 0) > 0)
    local showSurface = optionValue(controller.mod, "surface_hint", true) == true
      and state.surfaceAvailable
    if not visible and not showSurface then return result end

    love.graphics.push("all")
    love.graphics.setColor(0, 0, 0, 1)
    if visible then
      Font.drawBox(9, 0, 11, 4)
      Font.draw("DEPTH", 80, 8)
      local depthText = string.format("%02d", math.floor((state.depth or 0) + 0.5))
      Font.draw(depthText, 126, 8)
      local volume = state.volume
      local maxDepth = volume and controller.registry:maxDepthAt(
        volume.mapId,
        Game.overworld.player.cellX,
        Game.overworld.player.cellY) or 1
      local ratio = clamp(((state.depth or 0) - (volume and volume.minDepth or 0)) /
        math.max(1, maxDepth - (volume and volume.minDepth or 0)), 0, 1)
      for i = 1, 5 do
        local x, y = 80 + (i - 1) * 13, 21
        love.graphics.rectangle("line", x + 0.5, y + 0.5, 9, 5)
        if ratio >= (i - 1) / 5 then love.graphics.rectangle("fill", x + 2, y + 2, 6, 2) end
      end
    end
    if showSurface then
      Font.drawBox(1, 14, 18, 4)
      local text = "SURFACE AVAILABLE"
      Font.draw(text, math.floor((160 - Font.width(text)) / 2), 120)
    end
    love.graphics.pop()
    return result
  end

  local gamepadpressed = Game.gamepadpressed
  function Game:gamepadpressed(joystick, button, ...)
    if controller.state.active and (button == "lefttrigger" or button == "righttrigger"
      or button == "triggerleft" or button == "triggerright") then
      return
    end
    return gamepadpressed(self, joystick, button, ...)
  end
end

function DeepDive:installEvents()
  local controller = self

  self.mod.events:on("mod.kanto_dive.entered", function(event)
    controller:activate(event)
  end)

  self.mod.events:on("mod.kanto_dive.surfaced", function()
    controller:deactivate("surfaced")
  end)

  self.mod.events:on("map.entered", function(event)
    local mapId = event and event.mapId
    if not mapId then return end
    local volume = controller.registry:forMap(mapId)
    if volume then
      if not controller.state.active then controller:activate(event) end
      return
    end
    if controller.state.active then controller:deactivate("left authored underwater map") end
  end)

  self.mod.events:on("save.writing", function()
    if controller.state.active then controller:saveState() end
  end)

  self.mod.events:on("save.created", function()
    controller.mod.save:set(SAVE_KEY, nil)
  end)

  self.mod.events:on("map.reloaded", function(event)
    if controller.voxelRenderer and event and event.reason ~= "colors" then
      controller.voxelRenderer:invalidate()
    end
  end)
end

function DeepDive:install()
  if self.mod.options and self.mod.options.define then
    self.mod.options:define(OPTION_SCHEMA)
  end
  self:installHooks()
  self:installEvents()
  self:log("0.1.0-alpha.1 loaded")
end

function DeepDive:isActive()
  return self.state.active == true
end

function DeepDive:currentDepth()
  return self.state.active and self.state.depth or nil
end

function DeepDive:targetDepth()
  return self.state.active and self.state.targetDepth or nil
end

function DeepDive:currentVolume()
  return self.state.volume and self.state.volume.id or nil
end

return DeepDive
