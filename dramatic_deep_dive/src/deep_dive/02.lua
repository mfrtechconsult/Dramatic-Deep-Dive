  local saved = self.mod.save:get(SAVE_KEY)
  if type(saved) ~= "table" or saved.active ~= true then return nil end
  if saved.mapId and saved.mapId ~= volume.mapId then return nil end
  return saved
end

function DeepDive:forceThirdPerson()
  if not Pipelines.get(VOXEL_PIPELINE) then return false end
  if self.state.previousVoxelLevel == nil then
    self.state.previousVoxelLevel = Pipelines.level(VOXEL_PIPELINE)
  end
  Pipelines.setLevel(VOXEL_PIPELINE, THIRD_PERSON_LEVEL)
  return Pipelines.level(VOXEL_PIPELINE) == THIRD_PERSON_LEVEL
end

function DeepDive:restoreVoxelMode()
  local previous = self.state.previousVoxelLevel
  self.state.previousVoxelLevel = nil
  if previous ~= nil and Pipelines.get(VOXEL_PIPELINE) then
    Pipelines.setLevel(VOXEL_PIPELINE, previous)
  end
end

function DeepDive:mountLift()
  local volume = self.state.volume
  if not volume then return 0 end
  return math.max(0, volume.surfaceHeight - (self.state.depth or volume.defaultDepth))
end

function DeepDive:removeRider()
  local ow = Game.overworld
  local entity = self.state.riderEntity
  if entity and ow then
    removeFromList(ow.entities, entity)
    removeFromList(ow.npcs, entity)
  end
  self.state.riderEntity = nil
end

function DeepDive:ensureRider()
  local state = self.state
  local ow = Game.overworld
  local player = ow and ow.player
  if not (state.active and player and state.originalPlayerSprite
      and optionValue(self.mod, "show_rider", true) == true) then
    self:removeRider()
    return
  end

  local entity = state.riderEntity
  if not entity then
    local controller = self
    entity = {
      id = "dramatic_deep_dive_rider",
      deepDiveRider = true,
      passable = true,
      sprite = state.originalPlayerSprite,
    }
    entity.pose = function(me)
      local active = controller.state.active
      local currentPlayer = Game.overworld and Game.overworld.player
      if not (active and currentPlayer and controller.state.originalPlayerSprite) then
        return me.sprite, me.px or 0, me.py or 0, me.facing or "down", 0, false, false
      end
      me.cellX, me.cellY = currentPlayer.cellX, currentPlayer.cellY
      me.px, me.py = currentPlayer.px, currentPlayer.py
      me.facing = currentPlayer.facing
      local flip = math.floor((currentPlayer.animClock or 0) / 16) % 2 == 1
      return controller.state.originalPlayerSprite,
        currentPlayer.px,
        currentPlayer.py - controller:mountLift() - RIDER_LIFT,
        currentPlayer.facing, 0, flip, false
    end
    entity.draw = function(me, camX, camY)
      local sprite, px, py, facing, phase, flip = me:pose()
      if sprite and sprite.draw then sprite:draw(px, py, camX, camY, facing, phase, flip) end
    end
    state.riderEntity = entity
  end

  entity.sprite = state.originalPlayerSprite
  entity:pose()
  ow.entities = ow.entities or {}
  if not contains(ow.entities, entity) then table.insert(ow.entities, entity) end
end

function DeepDive:activate(event)
  local volume = self:resolveVolume(event)
  if not volume then return false end
  if self.state.active and self.state.volume and self.state.volume.id == volume.id then
    self:forceThirdPerson()
    self:ensureRider()
    return true
  end

  local ow = Game.overworld
  local player = ow and ow.player
  if not player then return false end

  local state = self.state
  local saved = self:loadSavedState(volume)
  state.active = true
  state.volume = volume
  state.originalPlayerSprite = state.originalPlayerSprite or player.sprite
  state.mountSpecies = saved and saved.mountSpecies or state.mountSpecies
  state.previousVoxelLevel = saved and saved.previousVoxelLevel or state.previousVoxelLevel

  local mon = self:findDiveMount()
  local sprite, reason = self:buildMount(mon)
  state.mount = mon
  state.mountSpecies = mon and mon.species or nil
  state.mountSprite = sprite
  if not sprite then
    self.mod.log:warn("Underwater mount unavailable: %s; keeping the player sprite", tostring(reason))
  end

  local maxDepth = self.registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  local initial = saved and tonumber(saved.depth) or volume.defaultDepth
  state.depth = clamp(initial, volume.minDepth, maxDepth)
  state.targetDepth = clamp(saved and tonumber(saved.targetDepth) or state.depth,
    volume.minDepth, maxDepth)
  state.hudTimer = DEPTH_HUD_SECONDS
  state.saveTimer = 0

  if not self:forceThirdPerson() then
    self.mod.log:error("The voxel pipeline could not be forced to 3RD")
  end
  self:ensureRider()
  self:saveState()
  self:log("entered %s at depth %.1f", volume.id, state.depth)
  return true
end

function DeepDive:deactivate(reason)
  if not self.state.active then return end
  self:removeRider()
  self:restoreVoxelMode()
  self.state.active = false
  self.state.depth = 0
  self.state.targetDepth = 0
  self.state.volume = nil
  self.state.mount = nil
  self.state.mountSpecies = nil
  self.state.mountSprite = nil
  self.state.originalPlayerSprite = nil
  self.state.surfaceAvailable = false
  self.state.saveTimer = 0
  self.mod.save:set(SAVE_KEY, nil)
  self:log("left underwater free-swim mode%s", reason and (": " .. tostring(reason)) or "")
end

function DeepDive:verticalRate()
  local key = optionValue(self.mod, "vertical_speed", "normal")
  return VERTICAL_RATES[key] or VERTICAL_RATES.normal
end

function DeepDive:depthInput()
  local ascend = keyDown("pageup") or triggerDown("triggerright")
  local descend = keyDown("pagedown") or triggerDown("triggerleft")
  if ascend == descend then return 0 end
  -- Positive depth points downward: L2/Page Down dives, R2/Page Up ascends.
  return descend and 1 or -1
end

function DeepDive:updateDepth(dt)
  local state = self.state
  local volume = state.volume
  local ow = Game.overworld
  local player = ow and ow.player
  if not (state.active and volume and player) then return end

  self:forceThirdPerson()

  local maxDepth = self.registry:maxDepthAt(volume.mapId, player.cellX, player.cellY)
    or (volume.defaultFloorDepth - volume.seabedClearance)
  local dir = self:depthInput()
  if dir ~= 0 then
    state.targetDepth = clamp(state.targetDepth + dir * self:verticalRate() * dt,
      volume.minDepth, maxDepth)
    state.hudTimer = DEPTH_HUD_SECONDS
  else
    state.targetDepth = math.min(state.targetDepth, maxDepth)
  end

  -- Entering a shallower DepthZone raises the swimmer smoothly instead of
  -- allowing the visual card to clip through the authored seafloor ceiling.
  state.targetDepth = clamp(state.targetDepth, volume.minDepth, maxDepth)
  local followRate = math.max(self:verticalRate(), 36)
  local delta = state.targetDepth - state.depth
  local step = followRate * dt
  if math.abs(delta) <= step then
    state.depth = state.targetDepth
  else
    state.depth = state.depth + (delta < 0 and -step or step)
  end
  state.depth = clamp(state.depth, volume.minDepth, maxDepth)
  state.hudTimer = math.max(0, (state.hudTimer or 0) - dt)

  local kd = self:kantoDive()
  local canSurface = false
  if kd and kd.exports and type(kd.exports.canSurfaceHere) == "function" then
    local ok, value = pcall(kd.exports.canSurfaceHere, Game)
    canSurface = ok and value == true
  end
  state.surfaceAvailable = canSurface
  self:ensureRider()
  state.saveTimer = (state.saveTimer or 0) + dt
  if state.saveTimer >= 0.25 then
    state.saveTimer = 0
    self:saveState()
  end
end

function DeepDive:requestDepth(depth)
  local state = self.state
  if not (state.active and state.volume) then return false end
  local mapId, x, y = self:currentPosition()
  local maxDepth = self.registry:maxDepthAt(mapId, x, y)
    or (state.volume.defaultFloorDepth - state.volume.seabedClearance)
