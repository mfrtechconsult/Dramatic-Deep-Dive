local UnderwaterLighting = {}
UnderwaterLighting.__index = UnderwaterLighting

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

  -- Sunlit cyan near the surface, increasingly blue/teal and dim in the
  -- abyss. This multiplies the provider's own day/night tint instead of
  -- replacing it, preserving its lighting model.
  local water = {
    lerp(0.78, 0.30, ratio),
    lerp(0.94, 0.58, ratio),
    lerp(1.00, 0.78, ratio),
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

  -- A previous hot reload may already own the wrapper; update the controller
  -- reference instead of stacking another beginScene layer.
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
    return table.unpack(results, 2)
  end
  Voxel3D.dramaticDeepDiveLightingHook = true
  return true
end

return UnderwaterLighting
