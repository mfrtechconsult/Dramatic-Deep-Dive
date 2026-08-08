local function compileSource(mod, name, source)
  local compiler = loadstring or load
  local chunk, loadError = compiler(source, "@" .. mod.path .. "/" .. name)
  if not chunk then
    mod.log:error("Could not compile %s: %s", name, tostring(loadError))
    return nil
  end
  local ok, value = pcall(chunk)
  if not ok then
    mod.log:error("Could not initialize %s: %s", name, tostring(value))
    return nil
  end
  return value
end

local function loadModule(mod, relativePath)
  local source, readError = mod:read(relativePath)
  if not source then
    mod.log:error("Could not read %s: %s", relativePath, tostring(readError))
    return nil
  end
  return compileSource(mod, relativePath, source)
end

local function loadCombinedModule(mod, name, paths)
  local chunks = {}
  for _, relativePath in ipairs(paths) do
    local source, readError = mod:read(relativePath)
    if not source then
      mod.log:error("Could not read %s: %s", relativePath, tostring(readError))
      return nil
    end
    chunks[#chunks + 1] = source
  end
  return compileSource(mod, name, table.concat(chunks, "\n"))
end

return function(mod)
  local VolumeRegistry = loadModule(mod, "src/VolumeRegistry.lua")
  local FollowerSprites = loadModule(mod, "src/FollowerSprites.lua")
  local DeepDive = loadCombinedModule(mod, "src/DeepDive.lua", {
    "src/deep_dive/01.lua",
    "src/deep_dive/02.lua",
    "src/deep_dive/03.lua",
  })
  local VoxelRenderer = loadModule(mod, "src/VoxelRenderer.lua")
  local volumeDefinitions = loadModule(mod, "data/volumes.lua")
  if not (VolumeRegistry and FollowerSprites and DeepDive and VoxelRenderer and volumeDefinitions) then return end

  local registry = VolumeRegistry.new(mod)
  for id, definition in pairs(volumeDefinitions) do
    local ok, err = registry:register(id, definition, mod.id)
    if not ok then
      mod.log:error("Could not register deep-dive volume %s: %s", tostring(id), tostring(err))
      return
    end
  end

  local sprites = FollowerSprites.new(mod)
  local voxelRenderer = VoxelRenderer.new(mod, registry)
  local controller = DeepDive.new(mod, registry, sprites, voxelRenderer)
  voxelRenderer:setController(controller)
  controller:install()
  voxelRenderer:install()

  mod.exports.isActive = function() return controller:isActive() end
  mod.exports.currentDepth = function() return controller:currentDepth() end
  mod.exports.targetDepth = function() return controller:targetDepth() end
  mod.exports.currentVolume = function() return controller:currentVolume() end
  mod.exports.floorDepthAt = function(mapId, x, y) return registry:floorDepthAt(mapId, x, y) end
  mod.exports.canSwimAt = function(mapId, x, y) return registry:contains(mapId, x, y) end
  mod.exports.registerVolume = function(id, definition, owner)
    return registry:register(id, definition, owner or "external")
  end
  mod.exports.requestDepth = function(depth) return controller:requestDepth(depth) end
end
