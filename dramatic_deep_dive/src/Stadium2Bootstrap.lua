local Stadium2Bootstrap = {}
Stadium2Bootstrap.__index = Stadium2Bootstrap

local IMPORT_MODULES = {
  "StadiumRig", "StadiumBuild", "StadiumFragment",
  "StadiumInstall", "StadiumRom", "StadiumFx",
}

local function safeFind(mod, id)
  if not (mod and mod.find) then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function publicLib(handle)
  local exports = handle and handle.exports
  local lib = exports and exports.lib
  return type(lib) == "table" and type(lib.require) == "function" and lib or nil
end

local function hasImporter(handle)
  local lib = publicLib(handle)
  if not lib then return false end
  for _, name in ipairs(IMPORT_MODULES) do
    local ok, value = pcall(lib.require, name)
    if not (ok and type(value) == "table") then return false end
  end
  return true
end

function Stadium2Bootstrap.new(mod, Pack)
  return setmetatable({
    mod = mod,
    Pack = Pack,
    attempts = 0,
    installed = false,
    reason = nil,
    provider = nil,
    crystal = false,
    bridgeSource = nil,
  }, Stadium2Bootstrap)
end

function Stadium2Bootstrap:crystalHandle()
  return safeFind(self.mod, "CRYSTAL_251") or safeFind(self.mod, "crystal_251")
end

function Stadium2Bootstrap:importProvider()
  local handle = safeFind(self.mod, "DRAMALESS_SHAPE")
    or safeFind(self.mod, "dramaticless_shape")
  if handle and hasImporter(handle) then return handle, "DRAMALESS_SHAPE" end
  handle = safeFind(self.mod, "DRAMATIC_SHAPE") or safeFind(self.mod, "dramatic_shape")
  if handle and hasImporter(handle) then return handle, "DRAMATIC_SHAPE" end
  return nil
end

function Stadium2Bootstrap:bridge(crystal)
  local exported = crystal and crystal.exports and crystal.exports.crystalStadium2
  if type(exported) == "table" and type(exported.install) == "function" then
    self.bridgeSource = "export"
    return exported
  end
  local ok, bridge = pcall(require, "mods.CRYSTAL_251.lib.stadium2_bridge")
  if ok and type(bridge) == "table" and type(bridge.install) == "function" then
    self.bridgeSource = "module"
    return bridge
  end
  self.bridgeSource = nil
  return nil
end

function Stadium2Bootstrap:cacheReady()
  local marker = self.Pack and self.Pack.marker and self.Pack.marker() or nil
  return marker ~= nil and marker.format == "C2DSM10"
end

function Stadium2Bootstrap:try(reason)
  self.attempts = self.attempts + 1
  if self:cacheReady() then
    self.reason = "cache_ready"
    return true
  end

  local crystal = self:crystalHandle()
  self.crystal = crystal ~= nil
  if not crystal then
    self.reason = "crystal_251_missing"
    return false
  end

  local bridge = self:bridge(crystal)
  if not bridge then
    self.reason = "crystal_251_bridge_unavailable"
    return false
  end

  local provider, providerId = self:importProvider()
  self.provider = providerId
  if not provider then
    self.reason = safeFind(self.mod, "BATTLE_ART_VOXEL_FORK")
      and "battle_art_requires_prebuilt_cache" or "stadium_import_provider_missing"
    return false
  end

  local options = {
    count = 251,
    ownerId = tostring(crystal.id or "CRYSTAL_251"),
    ownerName = "Crystal 251",
  }
  local ok, active = pcall(bridge.install, crystal, nil, provider, options)
  if not ok or not active then
    self.reason = "bridge_install_failed"
    if self.mod.log then
      self.mod.log:warn("Could not attach Crystal 251 Stadium 2 cache importer to %s: %s",
        tostring(providerId), tostring(ok and active or active))
    end
    return false
  end

  self.installed = true
  self.reason = reason or "installed"
  if self.mod.log then
    self.mod.log:info("Crystal 251 Stadium 2 cache bootstrap attached to %s (bridge=%s)",
      tostring(providerId), tostring(self.bridgeSource))
  end
  return true
end

function Stadium2Bootstrap:install()
  self:try("load")
  local service = self
  if self.mod.events and self.mod.events.on then
    self.mod.events:on("game.ready", function()
      if not service.installed and not service:cacheReady() then service:try("game.ready") end
    end)
  end
  if self.reason == "battle_art_requires_prebuilt_cache" and self.mod.log then
    self.mod.log:warn("Stadium 2 underwater cache is not ready. Battle Art can render DSM4 models but cannot import Stadium 2; generate the cache once with Crystal 251 + Dramaless Shape, or keep the billboard fallback.")
  end
  return true
end

function Stadium2Bootstrap:status()
  return {
    attempts = self.attempts,
    installed = self.installed,
    cacheReady = self:cacheReady(),
    crystal = self.crystal,
    provider = self.provider,
    reason = self.reason,
    bridgeSource = self.bridgeSource,
  }
end

return Stadium2Bootstrap
