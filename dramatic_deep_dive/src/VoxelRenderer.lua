local VoxelRenderer = {}
VoxelRenderer.__index = VoxelRenderer

local CELL = 16
local WATER_ALPHA = 0.27
local ABYSS_ALPHA = 0.88
local CEILING_ALPHA = 0.34
local BOUNDS_PAD = 8 * CELL
local CEILING_LIFT = 6
local WALL_DROP = 320

local FLOOR_COLORS = {
  coastal = { 0.17, 0.30, 0.29 },
  ocean = { 0.12, 0.25, 0.29 },
  harbor = { 0.22, 0.27, 0.25 },
  volcanic = { 0.10, 0.15, 0.17 },
  cave = { 0.10, 0.17, 0.22 },
  freshwater = { 0.24, 0.28, 0.21 },
  marsh = { 0.25, 0.27, 0.18 },
}

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

local function volumeBounds(volume)
  local minX, minZ = math.huge, math.huge
  local maxX, maxZ = -math.huge, -math.huge
  if volume.cellRuns then
    for y, row in pairs(volume.cellRuns) do
      for _, run in ipairs(row) do
        minX = math.min(minX, run.x0 * CELL)
        minZ = math.min(minZ, y * CELL)
        maxX = math.max(maxX, (run.x1 + 1) * CELL)
        maxZ = math.max(maxZ, (y + 1) * CELL)
      end
    end
  end
  for _, rect in ipairs(volume.swimVolumes or {}) do
    local x0, z0, x1, z1 = bounds(rect)
    if x0 < minX then minX = x0 end
    if z0 < minZ then minZ = z0 end
    if x1 > maxX then maxX = x1 end
    if z1 > maxZ then maxZ = z1 end
  end
  if minX == math.huge then return 0, 0, CELL, CELL end
  return minX, minZ, maxX, maxZ
end

local function release(value)
  if value and value.release then pcall(value.release, value) end
end

function VoxelRenderer.new(mod, registry, sceneDecor, setpieceDecor)
  return setmetatable({
    mod = mod,
    registry = registry,
    sceneDecor = sceneDecor,
    setpieceDecor = setpieceDecor,
    controller = nil,
    voxel3d = nil,
    installed = false,
    activeSlot = nil,
    cache = {},
    floorTexture = nil,
    floorTextures = {},
    waterTexture = nil,
    abyssTexture = nil,
    ceilingTexture = nil,
    warned = false,
  }, VoxelRenderer)
end

function VoxelRenderer:setController(controller) self.controller = controller end

function VoxelRenderer:providerModule(name)
  if not self.mod.find then return nil end
  local okFind, handle = pcall(self.mod.find, self.mod, "BATTLE_ART_VOXEL_FORK")
  local lib = okFind and handle and handle.exports and handle.exports.lib or nil
  if not (lib and type(lib.require) == "function") then return nil end
  local ok, module = pcall(lib.require, name)
  return ok and module or nil
end

function VoxelRenderer:makeTexture(r, g, b)
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil
  end
  local ok, image = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, r, g, b, 1)
    local out = love.graphics.newImage(data)
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end)
  return ok and image or nil
end

function VoxelRenderer:floorTextureFor(volume)
  local key = volume and volume.biome or "default"
  if self.floorTextures[key] then return self.floorTextures[key] end
  local color = volume and volume.floorColor or FLOOR_COLORS[key] or { 0.16, 0.30, 0.30 }
  local texture = self:makeTexture(color[1] or 0.16, color[2] or 0.30, color[3] or 0.30)
  self.floorTextures[key] = texture
  return texture
end

function VoxelRenderer:textures(volume)
  local floorTexture = self:floorTextureFor(volume)
  if not self.waterTexture then self.waterTexture = self:makeTexture(0.20, 0.58, 0.80) end
  if not self.abyssTexture then self.abyssTexture = self:makeTexture(0.05, 0.16, 0.30) end
  if not self.ceilingTexture then self.ceilingTexture = self:makeTexture(0.15, 0.42, 0.66) end
  return floorTexture, self.waterTexture, self.abyssTexture, self.ceilingTexture
end

function VoxelRenderer:makeMesh(vertices)
  local Voxel3D = self.voxel3d
  if not (Voxel3D and Voxel3D.FORMAT and love and love.graphics
      and love.graphics.newMesh and #vertices >= 3) then return nil end
  local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, vertices, "triangles", "static")
  return ok and mesh or nil
end

local function addGeneratedGeometry(renderer, volume, floorVertices, waterVertices, abyssVertices)
  local surfaceY = volume.surfaceHeight
  for y, row in pairs(volume.cellRuns or {}) do
    for _, run in ipairs(row) do
      addTop(waterVertices, run.x0 * CELL, y * CELL,
        (run.x1 + 1) * CELL, (y + 1) * CELL, surfaceY, 1.00)
    end
  end
  for y, row in pairs(volume.depthRuns or {}) do
    for _, run in ipairs(row) do
      local floorY = surfaceY - run.floorDepth
      addTop(floorVertices, run.x0 * CELL, y * CELL,
        (run.x1 + 1) * CELL, (y + 1) * CELL, floorY, 0.92)
    end
  end

  local dirs = {
    { name = "north", dx = 0, dy = -1 },
    { name = "south", dx = 0, dy = 1 },
    { name = "west", dx = -1, dy = 0 },
    { name = "east", dx = 1, dy = 0 },
  }
  local width, height = volume.widthCells or 0, volume.heightCells or 0
  for y, row in pairs(volume.cellRuns or {}) do
    for _, run in ipairs(row) do
      for x = run.x0, run.x1 do
        local floorDepth = renderer.registry:floorDepthAt(volume.mapId, x, y)
          or volume.defaultFloorDepth
        local floorY = surfaceY - floorDepth
        for _, dir in ipairs(dirs) do
          local nx, ny = x + dir.dx, y + dir.dy
          local outside = nx < 0 or ny < 0 or nx >= width or ny >= height
          local neighborDepth = not outside and renderer.registry:floorDepthAt(volume.mapId, nx, ny) or nil

          local x0, z0, x1, z1
          if dir.name == "north" then x0,z0,x1,z1 = x*CELL,y*CELL,(x+1)*CELL,y*CELL
          elseif dir.name == "south" then x0,z0,x1,z1 = (x+1)*CELL,(y+1)*CELL,x*CELL,(y+1)*CELL
          elseif dir.name == "west" then x0,z0,x1,z1 = x*CELL,(y+1)*CELL,x*CELL,y*CELL
          else x0,z0,x1,z1 = (x+1)*CELL,y*CELL,(x+1)*CELL,(y+1)*CELL end

          if neighborDepth then
            local neighborY = surfaceY - neighborDepth
            if neighborY < floorY - 0.01 then
              addWall(floorVertices, x0, z0, x1, z1, neighborY, floorY, 0.72)
            end
          elseif outside and volume.connectedEdges and volume.connectedEdges[dir.name] then
            -- Connected generated map continues the ocean here: leave it open.
          elseif outside then
            addWall(abyssVertices, x0, z0, x1, z1,
              floorY - WALL_DROP, surfaceY + CEILING_LIFT, 0.60)
          else
            addWall(floorVertices, x0, z0, x1, z1, floorY, surfaceY, 0.68)
          end
        end
      end
    end
  end
end

function VoxelRenderer:geometry(volume)
  local hit = self.cache[volume.id]
  if hit then return hit end
  local floorVertices, waterVertices, abyssVertices, ceilingVertices = {}, {}, {}, {}
  local baseY = volume.surfaceHeight - volume.defaultFloorDepth
  local minX, minZ, maxX, maxZ = volumeBounds(volume)
  minX, minZ = minX - BOUNDS_PAD, minZ - BOUNDS_PAD
  maxX, maxZ = maxX + BOUNDS_PAD, maxZ + BOUNDS_PAD
  local wallBottom = baseY - WALL_DROP
  local wallTop = volume.surfaceHeight + CEILING_LIFT

  if volume.cellRuns then
    addGeneratedGeometry(self, volume, floorVertices, waterVertices, abyssVertices)
  else
    for _, rect in ipairs(volume.swimVolumes) do
      local x0, z0, x1, z1 = bounds(rect)
      addTop(floorVertices, x0, z0, x1, z1, baseY, 0.90)
      addTop(waterVertices, x0, z0, x1, z1, volume.surfaceHeight, 1.00)
    end
    for _, zone in ipairs(volume.depthZones) do
      local shelfY = volume.surfaceHeight - zone.floorDepth
      if shelfY > baseY + 0.01 then addShelf(floorVertices, zone, baseY, shelfY) end
    end
    addWall(abyssVertices, minX, minZ, maxX, minZ, wallBottom, wallTop, 0.52)
    addWall(abyssVertices, maxX, minZ, maxX, maxZ, wallBottom, wallTop, 0.62)
    addWall(abyssVertices, maxX, maxZ, minX, maxZ, wallBottom, wallTop, 0.66)
    addWall(abyssVertices, minX, maxZ, minX, minZ, wallBottom, wallTop, 0.56)
  end
  addTop(ceilingVertices, minX, minZ, maxX, maxZ, volume.surfaceHeight + CEILING_LIFT, 1.00)

  hit = {
    floor = self:makeMesh(floorVertices),
    surface = self:makeMesh(waterVertices),
    abyss = self:makeMesh(abyssVertices),
    ceiling = self:makeMesh(ceilingVertices),
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
  local floorTexture, waterTexture, abyssTexture, ceilingTexture = self:textures(volume)
  if not (geo and floorTexture and waterTexture and abyssTexture and ceilingTexture) then return end

  if type(Voxel3D.seams) == "function" then Voxel3D.seams(false) end
  if type(Voxel3D.glass) == "function" then Voxel3D.glass(false) end

  if geo.abyss then
    love.graphics.setColor(1, 1, 1, ABYSS_ALPHA)
    pcall(love.graphics.setDepthMode, "lequal", true)
    Voxel3D.draw(geo.abyss, abyssTexture)
  end

  if geo.floor then
    love.graphics.setColor(1, 1, 1, 1)
    pcall(love.graphics.setDepthMode, "lequal", true)
    Voxel3D.draw(geo.floor, floorTexture)
  end

  if self.sceneDecor then self.sceneDecor:draw(volume) end
  if self.setpieceDecor then self.setpieceDecor:draw(volume) end

  pcall(love.graphics.setDepthMode, "lequal", false)
  if geo.ceiling then
    love.graphics.setColor(1, 1, 1, CEILING_ALPHA)
    Voxel3D.draw(geo.ceiling, ceilingTexture)
  end
  if geo.surface then
    love.graphics.setColor(1, 1, 1, WATER_ALPHA)
    Voxel3D.draw(geo.surface, waterTexture)
  end
  love.graphics.setColor(1, 1, 1, 1)
  pcall(love.graphics.setDepthMode, "lequal", true)

  if type(Voxel3D.glass) == "function" then Voxel3D.glass(true) end
  if type(Voxel3D.seams) == "function" then Voxel3D.seams(true) end
end

function VoxelRenderer:blocksCell(mapId, cellX, cellY, depth)
  if self.sceneDecor and self.sceneDecor:blocksCell(mapId, cellX, cellY, depth) then return true end
  if self.setpieceDecor and self.setpieceDecor:blocksCell(mapId, cellX, cellY, depth) then return true end
  return false
end

function VoxelRenderer:districtAt(mapId, worldZ)
  return self.sceneDecor and self.sceneDecor:districtAt(mapId, worldZ) or nil
end

function VoxelRenderer:install()
  if self.installed then return true end
  local Voxel3D = self:providerModule("Voxel3D")
  if not (Voxel3D and type(Voxel3D.beginScene) == "function" and type(Voxel3D.endScene) == "function") then
    if not self.warned and self.mod.log then
      self.mod.log:warn("Battle Art Voxel Fork did not expose Voxel3D; custom underwater geometry is disabled")
      self.warned = true
    end
    return false
  end

  self.voxel3d = Voxel3D
  if self.sceneDecor then self.sceneDecor:setVoxel3D(Voxel3D) end
  if self.setpieceDecor then self.setpieceDecor:setVoxel3D(Voxel3D) end
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
    release(geo.abyss)
    release(geo.ceiling)
    self.cache[id] = nil
  end
  release(self.floorTexture)
  for key, texture in pairs(self.floorTextures or {}) do
    release(texture)
    self.floorTextures[key] = nil
  end
  release(self.waterTexture)
  release(self.abyssTexture)
  release(self.ceilingTexture)
  self.floorTexture, self.waterTexture = nil, nil
  self.abyssTexture, self.ceilingTexture = nil, nil
  if self.sceneDecor then self.sceneDecor:invalidate() end
  if self.setpieceDecor then self.setpieceDecor:invalidate() end
end

return VoxelRenderer
