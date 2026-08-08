local VoxelRenderer = {}
VoxelRenderer.__index = VoxelRenderer

local CELL = 16
local WATER_ALPHA = 0.27

local function addVertex(out, x, y, z, u, v, shade)
  out[#out + 1] = { x, y, z, u or 0, v or 0, shade or 1 }
end

local function addTop(out, x0, z0, x1, z1, y, shade)
  addVertex(out, x0, y, z0, 0, 0, shade)
  addVertex(out, x1, y, z0, 1, 0, shade)
  addVertex(out, x1, y, z1, 1, 1, shade)
  addVertex(out, x0, y, z0, 0, 0, shade)
  addVertex(out, x1, y, z1, 1, 1, shade)
  addVertex(out, x0, y, z1, 0, 1, shade)
end

local function addWall(out, x0, z0, x1, z1, lowY, highY, shade)
  if highY <= lowY then return end
  addVertex(out, x0, lowY, z0, 0, 1, shade)
  addVertex(out, x1, lowY, z1, 1, 1, shade)
  addVertex(out, x1, highY, z1, 1, 0, shade)
  addVertex(out, x0, lowY, z0, 0, 1, shade)
  addVertex(out, x1, highY, z1, 1, 0, shade)
  addVertex(out, x0, highY, z0, 0, 0, shade)
end

local function bounds(rect)
  return rect.left * CELL,
         rect.top * CELL,
         (rect.right + 1) * CELL,
         (rect.bottom + 1) * CELL
end

local function addShelf(out, rect, lowY, highY)
  local x0, z0, x1, z1 = bounds(rect)
  addTop(out, x0, z0, x1, z1, highY, 0.94)
  addWall(out, x0, z0, x1, z0, lowY, highY, 0.72)
  addWall(out, x1, z0, x1, z1, lowY, highY, 0.82)
  addWall(out, x1, z1, x0, z1, lowY, highY, 0.86)
  addWall(out, x0, z1, x0, z0, lowY, highY, 0.68)
end

local function release(value)
  if value and value.release then pcall(value.release, value) end
end

function VoxelRenderer.new(mod, registry, sceneDecor)
  return setmetatable({
    mod = mod,
    registry = registry,
    sceneDecor = sceneDecor,
    controller = nil,
    voxel3d = nil,
    installed = false,
    cache = {},
    floorTexture = nil,
    waterTexture = nil,
    warned = false,
  }, VoxelRenderer)
end

function VoxelRenderer:setController(controller)
  self.controller = controller
end

function VoxelRenderer:providerModule(name)
  if not self.mod.find then return nil end
  local okFind, handle = pcall(self.mod.find, self.mod, "BATTLE_ART_VOXEL_FORK")
  local lib = okFind and handle and handle.exports and handle.exports.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, module = pcall(lib.require, name)
  return ok and module or nil
end

function VoxelRenderer:makeTexture(r, g, b)
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then return nil end
  local ok, image = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, r, g, b, 1)
    local out = love.graphics.newImage(data)
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end)
  return ok and image or nil
end

function VoxelRenderer:textures()
  if not self.floorTexture then
    self.floorTexture = self:makeTexture(0.16, 0.30, 0.30)
  end
  if not self.waterTexture then
    self.waterTexture = self:makeTexture(0.20, 0.58, 0.80)
  end
  return self.floorTexture, self.waterTexture
end

function VoxelRenderer:makeMesh(vertices)
  local Voxel3D = self.voxel3d
  if not (Voxel3D and Voxel3D.FORMAT and love and love.graphics
      and love.graphics.newMesh and #vertices >= 3) then return nil end
  local ok, mesh = pcall(love.graphics.newMesh,
    Voxel3D.FORMAT, vertices, "triangles", "static")
  return ok and mesh or nil
end

function VoxelRenderer:geometry(volume)
  local hit = self.cache[volume.id]
  if hit then return hit end

  local floorVertices = {}
  local waterVertices = {}
  local baseY = volume.surfaceHeight - volume.defaultFloorDepth

  for _, rect in ipairs(volume.swimVolumes) do
    local x0, z0, x1, z1 = bounds(rect)
    addTop(floorVertices, x0, z0, x1, z1, baseY, 0.90)
    addTop(waterVertices, x0, z0, x1, z1, volume.surfaceHeight, 1.00)
  end

  for _, zone in ipairs(volume.depthZones) do
    local shelfY = volume.surfaceHeight - zone.floorDepth
    if shelfY > baseY + 0.01 then
      addShelf(floorVertices, zone, baseY, shelfY)
    end
  end

  hit = {
    floor = self:makeMesh(floorVertices),
    surface = self:makeMesh(waterVertices),
  }
  self.cache[volume.id] = hit
  return hit
end

function VoxelRenderer:drawCurrentVolume()
  local controller = self.controller
  local state = controller and controller.state
  local volume = state and state.active and state.volume or nil
  local Voxel3D = self.voxel3d
  if not (volume and Voxel3D and type(Voxel3D.draw) == "function") then return end

  local geo = self:geometry(volume)
  local floorTexture, waterTexture = self:textures()
  if not (geo and floorTexture and waterTexture) then return end

  if type(Voxel3D.seams) == "function" then Voxel3D.seams(false) end
  if type(Voxel3D.glass) == "function" then Voxel3D.glass(false) end

  if geo.floor then
    love.graphics.setColor(1, 1, 1, 1)
    pcall(love.graphics.setDepthMode, "lequal", true)
    Voxel3D.draw(geo.floor, floorTexture)
  end

  if self.sceneDecor then self.sceneDecor:draw(volume) end

  if geo.surface then
    pcall(love.graphics.setDepthMode, "lequal", false)
    love.graphics.setColor(1, 1, 1, WATER_ALPHA)
    Voxel3D.draw(geo.surface, waterTexture)
    love.graphics.setColor(1, 1, 1, 1)
    pcall(love.graphics.setDepthMode, "lequal", true)
  end

  if type(Voxel3D.glass) == "function" then Voxel3D.glass(true) end
  if type(Voxel3D.seams) == "function" then Voxel3D.seams(true) end
end

function VoxelRenderer:blocksCell(mapId, cellX, cellY, depth)
  return self.sceneDecor
    and self.sceneDecor:blocksCell(mapId, cellX, cellY, depth) == true
    or false
end

function VoxelRenderer:districtAt(mapId, worldZ)
  return self.sceneDecor and self.sceneDecor:districtAt(mapId, worldZ) or nil
end

function VoxelRenderer:install()
  if self.installed then return true end
  local Voxel3D = self:providerModule("Voxel3D")
  if not (Voxel3D and type(Voxel3D.beginScene) == "function"
      and type(Voxel3D.endScene) == "function") then
    if not self.warned and self.mod.log then
      self.mod.log:warn("Battle Art Voxel Fork did not expose Voxel3D; custom underwater geometry is disabled")
      self.warned = true
    end
    return false
  end

  self.voxel3d = Voxel3D
  if self.sceneDecor then self.sceneDecor:setVoxel3D(Voxel3D) end

  -- Store the current renderer on the provider so hot reload replaces the
  -- target instead of stacking another pair of global Voxel3D wrappers.
  Voxel3D.dramaticDeepDiveRenderer = self

  if not Voxel3D.dramaticDeepDiveBeginSceneHook then
    local innerBeginScene = Voxel3D.beginScene
    function Voxel3D.beginScene(w, h, cx, cy, vw, vh, sky, slot)
      local renderer = Voxel3D.dramaticDeepDiveRenderer
      if renderer then renderer.activeSlot = slot or "world" end
      return innerBeginScene(w, h, cx, cy, vw, vh, sky, slot)
    end
    Voxel3D.dramaticDeepDiveBeginSceneHook = true
  end

  if not Voxel3D.dramaticDeepDiveEndSceneHook then
    local innerEndScene = Voxel3D.endScene
    function Voxel3D.endScene(...)
      local renderer = Voxel3D.dramaticDeepDiveRenderer
      if renderer and renderer.activeSlot == "world"
          and renderer.controller and renderer.controller:isActive() then
        local ok, err = pcall(renderer.drawCurrentVolume, renderer)
        if not ok and renderer.mod.log then
          renderer.mod.log:error("underwater voxel geometry failed: %s", tostring(err))
        end
      end
      local result = innerEndScene(...)
      if renderer then renderer.activeSlot = nil end
      return result
    end
    Voxel3D.dramaticDeepDiveEndSceneHook = true
  end

  self.installed = true
  return true
end

function VoxelRenderer:invalidate()
  for id, geo in pairs(self.cache) do
    release(geo.floor)
    release(geo.surface)
    self.cache[id] = nil
  end
  release(self.floorTexture)
  release(self.waterTexture)
  self.floorTexture = nil
  self.waterTexture = nil
  if self.sceneDecor then self.sceneDecor:invalidate() end
end

return VoxelRenderer
