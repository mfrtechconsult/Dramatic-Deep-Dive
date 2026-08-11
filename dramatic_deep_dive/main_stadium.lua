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
  local Stadium2Underwater = loadChunk(mod, "src/Stadium2Underwater.lua")
  if not (Stadium2Pack and Stadium2Underwater) then return end

  local service = Stadium2Underwater.new(mod, Stadium2Pack)
  service:install()

  mod.exports.stadium2Underwater = {
    api = 1,
    available = function(dex) return Stadium2Pack.available(dex, false) end,
    stats = function() return service:stats() end,
    worldHeight = Stadium2Underwater.worldHeight,
    clearCache = function()
      service:clear()
      Stadium2Pack.clear()
    end,
  }
end
