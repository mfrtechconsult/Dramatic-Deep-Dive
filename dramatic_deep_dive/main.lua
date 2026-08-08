local function loadModule(mod, relativePath)
  local source, readError = mod:read(relativePath)
  if not source then
    mod.log:error("Could not read %s: %s", relativePath, tostring(readError))
    return nil
  end
  local compiler = loadstring or load
  local chunk, loadError = compiler(source, "@" .. mod.path .. "/" .. relativePath)
  if not chunk then
    mod.log:error("Could not compile %s: %s", relativePath, tostring(loadError))
    return nil
  end
  local ok, value = pcall(chunk)
  if not ok then
    mod.log:error("Could not initialize %s: %s", relativePath, tostring(value))
    return nil
  end
  return value
end

return function(mod)
  local Content = loadModule(mod, "src/Content.lua")
  local VolumeRegistry = loadModule(mod, "src/VolumeRegistry.lua")
  local FollowerSprites = loadModule(mod, "src/FollowerSprites.lua")
  local FollowerBridge = loadModule(mod, "src/FollowerBridge.lua")
  local DiveTravel = loadModule(mod, "src/DiveTravel.lua")
  local Progression = loadModule(mod, "src/Progression.lua")
  local DeepDive = loadModule(mod, "src/DeepDive.lua")
  local SceneDecor = loadModule(mod, "src/SceneDecor.lua")
  local SetpieceDecor = loadModule(mod, "src/SetpieceDecor.lua")
  local SceneGameplay = loadModule(mod, "src/SceneGameplay.lua")
  local UnderwaterLighting = loadModule(mod, "src/UnderwaterLighting.lua")
  local VoxelRenderer = loadModule(mod, "src/VoxelRenderer.lua")
  local volumeDefinitions = loadModule(mod, "data/volumes.lua")
  local diveDefinitions = loadModule(mod, "data/dive_links.lua")
  local sceneDefinitions = loadModule(mod, "data/scenes.lua")
  local setpieceDefinitions = loadModule(mod, "data/setpieces.lua")
  if not (Content and VolumeRegistry and FollowerSprites and FollowerBridge and DiveTravel
      and Progression and DeepDive and SceneDecor and SetpieceDecor and SceneGameplay
      and UnderwaterLighting and VoxelRenderer and volumeDefinitions and diveDefinitions
      and sceneDefinitions and setpieceDefinitions) then
    return
  end
  if not Content.register(mod) then return end

  local registry = VolumeRegistry.new(mod)
  for id, definition in pairs(volumeDefinitions) do
    local volume, err = registry:register(id, definition, mod.id)
    if not volume then
      mod.log:error("Could not register deep-dive volume %s: %s", tostring(id), tostring(err))
      return
    end
  end

  local sprites = FollowerSprites.new(mod)
  local followerBridge = FollowerBridge.new(mod)
  local travel = DiveTravel.new(mod, diveDefinitions)
  local sceneDecor = SceneDecor.new(mod, registry, sceneDefinitions)
  local setpieceDecor = SetpieceDecor.new(mod, registry, setpieceDefinitions)
  local voxelRenderer = VoxelRenderer.new(mod, registry, sceneDecor, setpieceDecor)
  local controller = DeepDive.new(mod, registry, sprites, voxelRenderer, followerBridge, travel)
  local sceneGameplay = SceneGameplay.new(mod, controller, voxelRenderer)
  local underwaterLighting = UnderwaterLighting.new(mod, controller)
  voxelRenderer:setController(controller)

  travel:install()
  Progression.install(mod)
  controller:install()
  voxelRenderer:install()
  underwaterLighting:install()
  sceneGameplay:install()

  mod.exports.isActive = function() return controller:isActive() end
  mod.exports.isUnderwater = function() return controller:isActive() end
  mod.exports.currentDepth = function() return controller:currentDepth() end
  mod.exports.targetDepth = function() return controller:targetDepth() end
  mod.exports.currentVolume = function() return controller:currentVolume() end
  mod.exports.floorDepthAt = function(mapId, x, y) return registry:floorDepthAt(mapId, x, y) end
  mod.exports.canSwimAt = function(mapId, x, y) return registry:contains(mapId, x, y) end
  mod.exports.canDiveHere = function(game) return travel:canDiveHere(game) end
  mod.exports.canSurfaceHere = function(game) return travel:canSurfaceHere(game) end
  mod.exports.currentDistrict = function()
    return sceneGameplay.districtId, sceneGameplay.districtName
  end
  mod.exports.registerVolume = function(id, definition, owner)
    return registry:register(id, definition, owner or "external")
  end
  mod.exports.requestDepth = function(depth) return controller:requestDepth(depth) end
end
