local AmbientLOD = {}
AmbientLOD.__index = AmbientLOD

local FISH_RADIUS = 430
local BUBBLE_RADIUS = 360

local function squaredDistance(ax, az, bx, bz)
  local dx, dz = ax - bx, az - bz
  return dx * dx + dz * dz
end

local function focus(sceneDecor)
  local Voxel3D = sceneDecor and sceneDecor.voxel3d
  local f = Voxel3D and Voxel3D.focus
  if type(f) == "table" then
    return tonumber(f[1]), tonumber(f[3])
  end
  return nil
end

local function filtered(items, fx, fz, radius, itemRadius)
  if not (fx and fz) then return items end
  local out = {}
  for _, item in ipairs(items or {}) do
    local extra = itemRadius and (tonumber(item[itemRadius]) or 0) or 0
    local limit = radius + extra
    if squaredDistance(tonumber(item.x) or 0, tonumber(item.z) or 0, fx, fz)
        <= limit * limit then
      out[#out + 1] = item
    end
  end
  return out
end

function AmbientLOD.new(mod, sceneDecor)
  return setmetatable({
    mod = mod,
    sceneDecor = sceneDecor,
    visibleFishSchools = 0,
    visibleBubbleVents = 0,
  }, AmbientLOD)
end

function AmbientLOD:install()
  local decor = self.sceneDecor
  if not decor or decor.dramaticDeepDiveLodInstalled then return false end
  local lod = self

  local innerFish = decor.drawFish
  if type(innerFish) == "function" then
    decor.drawFish = function(self, scene, volume, time)
      local fx, fz = focus(self)
      local original = scene.fishSchools
      local visible = filtered(original, fx, fz, FISH_RADIUS, "radius")
      scene.fishSchools = visible
      lod.visibleFishSchools = #visible
      local ok, result = pcall(innerFish, self, scene, volume, time)
      scene.fishSchools = original
      if not ok then error(result, 0) end
      return result
    end
  end

  local innerTransparent = decor.drawTransparent
  if type(innerTransparent) == "function" then
    decor.drawTransparent = function(self, scene, volume, geo, time)
      local fx, fz = focus(self)
      local original = scene.bubbleVents
      local visible = filtered(original, fx, fz, BUBBLE_RADIUS)
      scene.bubbleVents = visible
      lod.visibleBubbleVents = #visible
      local ok, result = pcall(innerTransparent, self, scene, volume, geo, time)
      scene.bubbleVents = original
      if not ok then error(result, 0) end
      return result
    end
  end

  decor.dramaticDeepDiveLodInstalled = true
  return true
end

function AmbientLOD:stats()
  return {
    fishSchools = self.visibleFishSchools,
    bubbleVents = self.visibleBubbleVents,
    fishRadius = FISH_RADIUS,
    bubbleRadius = BUBBLE_RADIUS,
  }
end

return AmbientLOD
