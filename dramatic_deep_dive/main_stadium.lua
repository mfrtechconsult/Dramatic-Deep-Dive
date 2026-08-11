local function loadChunk(mod, relativePath)
  local source, err = mod:read(relativePath)
  if not source then
    mod.log:error("Could not read %s: %s", relativePath, tostring(err))
    return nil
  end
  source = source:gsub("mod%.dramatic_deep_dive%.", "mod.DRAMATIC_DEEP_DIVE.")
  local compiler = loadstring or load
  local chunk, loadErr = compiler(source, "@" .. mod.path .. "/" .. relativePath)
  if not chunk then
    mod.log:error("Could not compile %s: %s", relativePath, tostring(loadErr))
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
  -- Keep the stable Deep Dive bootstrap intact, then layer Stadium 2 wildlife
  -- on top through public exports/provider modules. This avoids coupling the
  -- experimental renderer to Deep Dive's controller internals.
  local original = loadChunk(mod, "main.lua")
  if type(original) ~= "function" then return end
  local ok, err = pcall(original, mod)
  if not ok then
    mod.log:error("Base Dramatic Deep Dive initialization failed: %s", tostring(err))
    return
  end

  local Stadium2Pack = loadChunk(mod, "src/Stadium2Pack.lua")
  local Stadium2Bootstrap = loadChunk(mod, "src/Stadium2Bootstrap.lua")
  local Stadium2ProviderCompat = loadChunk(mod, "src/Stadium2ProviderCompat.lua")
  local Stadium2Underwater = loadChunk(mod, "src/Stadium2Underwater.lua")
  if not (Stadium2Pack and Stadium2Bootstrap and Stadium2ProviderCompat
      and Stadium2Underwater) then return end

  -- A shiny pack is optional. If Crystal 251 only generated the normal model,
  -- a shiny entity must still get a valid 3D body rather than falling all the
  -- way back to a billboard merely because its colour variant is absent.
  local rawAvailable = Stadium2Pack.available
  Stadium2Pack.available = function(dex, shiny)
    if rawAvailable(dex, shiny) then return true end
    return shiny == true and rawAvailable(dex, false) or false
  end

  -- Cache generation is deliberately separate from rendering. Existing DSM4
  -- files are consumed immediately. If the cache is absent, Crystal 251 plus
  -- a full Dramaless/Dramatic Shape importer can attach the same Stadium 2
  -- bridge used by the Sky Ride experiment. Battle Art remains a renderer-only
  -- provider and simply waits for a prebuilt cache.
  local bootstrap = Stadium2Bootstrap.new(mod, Stadium2Pack)
  bootstrap:install()

  local service = Stadium2Underwater.new(mod, Stadium2Pack)

  -- Deep Dive normally prefers Battle Art as its active voxel renderer. Battle
  -- Art has the Voxel3D/shadow stack but intentionally does not ship StadiumRig.
  -- Borrow only the compatible CPU Stadium rig/parser from Dramaless/Dramatic
  -- Shape when needed, while all actual drawing remains on the active provider.
  Stadium2ProviderCompat.install(service, mod)

  -- Stadium2Underwater caches the sentinel sprite by species/image for normal
  -- reuse. That is correct for a one-model mount, but underwater schools can
  -- contain several Tentacool (etc.) simultaneously. Give each swimmer its
  -- own tiny cache bucket so its sprite def points to its own rig/sentinel and
  -- therefore to its own position/depth. The model data itself is still shared
  -- by Stadium2Pack's bounded LRU; only the per-instance rig is distinct.
  service.specialSpritesBySwimmer = setmetatable({}, { __mode = "k" })
  local rawSpriteFor = service.spriteFor
  function service:spriteFor(swimmer, baseSprite)
    local shared = self.specialSprites
    local bucket = self.specialSpritesBySwimmer[swimmer]
    if not bucket then
      bucket = {}
      self.specialSpritesBySwimmer[swimmer] = bucket
    end
    self.specialSprites = bucket
    local okSprite, sprite = pcall(rawSpriteFor, self, swimmer, baseSprite)
    self.specialSprites = shared
    if okSprite then return sprite end
    if self.mod and self.mod.log then
      self.mod.log:warn("Stadium 2 swimmer sprite fallback for %s: %s",
        tostring(swimmer and swimmer.species), tostring(sprite))
    end
    return baseSprite
  end

  local stadiumActive = service:install()

  mod.exports.stadium2Underwater = {
    api = 3,
    active = function() return stadiumActive == true end,
    available = function(dex) return Stadium2Pack.available(dex, false) end,
    stats = function()
      local out = service:stats()
      out.bootstrap = bootstrap:status()
      out.rigProvider = service.rigProviderId
      return out
    end,
    bootstrapStatus = function() return bootstrap:status() end,
    retryBootstrap = function() return bootstrap:try("manual_retry") end,
    worldHeight = Stadium2Underwater.worldHeight,
    clearCache = function()
      service:clear()
      Stadium2Pack.clear()
    end,
  }
end
