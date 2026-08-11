local UnderwaterLighting = {}
UnderwaterLighting.__index = UnderwaterLighting
local unpackArgs = table.unpack or unpack

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function copyColor(color)
  return {
    tonumber(color and color[1]) or 1,
    tonumber(color and color[2]) or 1,
    tonumber(color and color[3]) or 1,
  }
end

-- Shallow/deep transmission multipliers by generated Kanto seabed identity.
-- These are deliberately subtle: geometry/floor colour still carries most of
-- the biome identity while depth remains the dominant visual signal.
local BIOME_LIGHT = {
  coastal = {
    shallow = { 0.80, 0.95, 1.00 }, deep = { 0.30, 0.58, 0.78 },
  },
  ocean = {
    shallow = { 0.76, 0.93, 1.00 }, deep = { 0.24, 0.50, 0.74 },
  },
  harbor = {
    shallow = { 0.78, 0.90, 0.90 }, deep = { 0.30, 0.50, 0.52 },
  },
  volcanic = {
    shallow = { 0.74, 0.88, 0.91 }, deep = { 0.27, 0.43, 0.48 },
  },
  cave = {
    shallow = { 0.70, 0.88, 0.98 }, deep = { 0.20, 0.38, 0.62 },
  },
  freshwater = {
    shallow = { 0.82, 0.94, 0.86 }, deep = { 0.34, 0.55, 0.44 },
  },
  marsh = {
    shallow = { 0.78, 0.86, 0.66 }, deep = { 0.34, 0.43, 0.27 },
  },
}

function UnderwaterLighting.new(mod, controller)
  return setmetatable({ mod = mod, controller = controller, voxel3d = nil }, UnderwaterLighting)
end

function UnderwaterLighting:providerModule(name)
  if not self.mod.find then return nil end
  local okFind, handle = pcall(self.mod.find, self.mod, "BATTLE_ART_VOXEL_FORK")
  local lib = okFind and handle and handle.exports and handle.exports.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, module = pcall(lib.require, name)
  return ok and module or nil
end

function UnderwaterLighting:tint(base)
  local state = self.controller and self.controller.state
  local volume = state and state.volume
  if not (state and state.active and volume) then return copyColor(base) end

  local maxDepth = math.max(volume.minDepth + 1,
    (volume.defaultFloorDepth or 220) - (volume.seabedClearance or 0))
  local ratio = clamp(((state.depth or volume.minDepth) - volume.minDepth)
    / (maxDepth - volume.minDepth), 0, 1)

  local profile = BIOME_LIGHT[volume.biome] or BIOME_LIGHT.coastal
  local water = {
    lerp(profile.shallow[1], profile.deep[1], ratio),
    lerp(profile.shallow[2], profile.deep[2], ratio),
    lerp(profile.shallow[3], profile.deep[3], ratio),
  }
  local source = copyColor(base)
  return {
    source[1] * water[1],
    source[2] * water[2],
    source[3] * water[3],
  }
end

function UnderwaterLighting:install()
  local Voxel3D = self:providerModule("Voxel3D")
  if not (Voxel3D and type(Voxel3D.beginScene) == "function") then return false end
  self.voxel3d = Voxel3D

  Voxel3D.dramaticDeepDiveLighting = self
  if Voxel3D.dramaticDeepDiveLightingHook then return true end

  local innerBeginScene = Voxel3D.beginScene
  function Voxel3D.beginScene(...)
    local lighting = Voxel3D.dramaticDeepDiveLighting
    local previous = Voxel3D.tint
    if lighting and lighting.controller and lighting.controller:isActive() then
      Voxel3D.tint = lighting:tint(previous)
    end
    local results = { pcall(innerBeginScene, ...) }
    Voxel3D.tint = previous
    if not results[1] then error(results[2], 0) end
    return unpackArgs(results, 2)
  end
  Voxel3D.dramaticDeepDiveLightingHook = true
  return true
end

return UnderwaterLighting
