local SetpieceDecor = {}
SetpieceDecor.__index = SetpieceDecor

local CELL = 16

local MATERIALS = {
  wreckWood = { 0.34, 0.23, 0.15 },
  wreckDark = { 0.20, 0.14, 0.11 },
  caveRock = { 0.09, 0.15, 0.20 },
  smokerRock = { 0.08, 0.11, 0.13 },
  smokerGlow = { 0.14, 0.78, 0.72 },
  bone = { 0.72, 0.72, 0.58 },
}

local function addVertex(out, x, y, z, u, v, shade)
  out[#out + 1] = { x, y, z, u or 0, v or 0, shade or 1 }
end

local function tri(out, a, b, c, shade)
  addVertex(out, a[1], a[2], a[3], 0, 0, shade)
  addVertex(out, b[1], b[2], b[3], 1, 0, shade)
  addVertex(out, c[1], c[2], c[3], 1, 1, shade)
end

local function quad(out, a, b, c, d, shade)
  tri(out, a, b, c, shade)
  tri(out, a, c, d, shade)
end

local function box(out, x0, y0, z0, x1, y1, z1)
  if x1 <= x0 or y1 <= y0 or z1 <= z0 then return end
  quad(out, {x0,y1,z0}, {x1,y1,z0}, {x1,y1,z1}, {x0,y1,z1}, 1.00)
  quad(out, {x0,y0,z1}, {x1,y0,z1}, {x1,y0,z0}, {x0,y0,z0}, 0.55)
  quad(out, {x0,y0,z0}, {x0,y1,z0}, {x0,y1,z1}, {x0,y0,z1}, 0.70)
  quad(out, {x1,y0,z1}, {x1,y1,z1}, {x1,y1,z0}, {x1,y0,z0}, 0.84)
  quad(out, {x0,y0,z1}, {x0,y1,z1}, {x1,y1,z1}, {x1,y0,z1}, 0.90)
  quad(out, {x1,y0,z0}, {x1,y1,z0}, {x0,y1,z0}, {x0,y0,z0}, 0.64)
end

local function bucket(buckets, name)
  buckets[name] = buckets[name] or {}
  return buckets[name]
end

local function addCollider(colliders, x0, z0, x1, z1, bottomY, topY)
  colliders[#colliders + 1] = {
    x0 = math.min(x0, x1), z0 = math.min(z0, z1),
    x1 = math.max(x0, x1), z1 = math.max(z0, z1),
    bottomY = math.min(bottomY, topY), topY = math.max(bottomY, topY),
  }
end

local function lcg(seed)
  local state = math.max(1, math.floor(tonumber(seed) or 1)) % 2147483647
  return function(a, b)
    state = (state * 48271) % 2147483647
    local r = state / 2147483647
    if a == nil then return r end
    return a + (b - a) * r
  end
end

local function release(value)
  if value and value.release then pcall(value.release, value) end
end

function SetpieceDecor.new(mod, registry, definitions)
  local byMap = {}
  for id, definition in pairs(definitions or {}) do
    definition.id = definition.id or id
    if definition.mapId then byMap[definition.mapId] = definition end
  end
  return setmetatable({
    mod = mod,
    registry = registry,
    definitions = definitions or {},
    byMap = byMap,
    voxel3d = nil,
    cache = {},
    textures = {},
  }, SetpieceDecor)
end

function SetpieceDecor:setVoxel3D(voxel3d) self.voxel3d = voxel3d end
function SetpieceDecor:forMap(mapId) return self.byMap[mapId] end

function SetpieceDecor:floorY(volume, x, z)
  local cellX = math.max(0, math.floor(x / CELL))
  local cellY = math.max(0, math.floor(z / CELL))
  local floorDepth = self.registry:floorDepthAt(volume.mapId, cellX, cellY)
    or volume.defaultFloorDepth
  return volume.surfaceHeight - floorDepth
end

function SetpieceDecor:makeTexture(name)
  if self.textures[name] then return self.textures[name] end
  local color = MATERIALS[name] or { 1, 1, 1 }
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    return nil
  end
  local ok, image = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, color[1], color[2], color[3], 1)
    local out = love.graphics.newImage(data)
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end)
  if ok then self.textures[name] = image return image end
  return nil
end

function SetpieceDecor:makeMesh(vertices)
  local Voxel3D = self.voxel3d
  if not (Voxel3D and Voxel3D.FORMAT and love and love.graphics
      and love.graphics.newMesh and #vertices >= 3) then return nil end
  local ok, mesh = pcall(love.graphics.newMesh, Voxel3D.FORMAT, vertices, "triangles", "static")
  return ok and mesh or nil
end

function SetpieceDecor:addShipwreck(buckets, colliders, volume, piece)
  local wood = bucket(buckets, "wreckWood")
  local dark = bucket(buckets, "wreckDark")
  local y = self:floorY(volume, piece.x, piece.z)
  local length, width, height = piece.length or 150, piece.width or 58, piece.height or 46
  local x0, x1 = piece.x - length/2, piece.x + length/2
  local z0, z1 = piece.z - width/2, piece.z + width/2

  -- Stepped hull, open deck and ribs make it readable from above and side-on.
  box(dark, x0+12, y, z0+12, x1-10, y+8, z1-12)
  box(wood, x0+5, y+7, z0+7, x1-4, y+15, z1-7)
  box(wood, x0+20, y+14, z0+2, x1-22, y+20, z1-2)
  box(dark, x0, y+8, piece.z-3, x0+24, y+28, piece.z+3)
  for i = 0, 7 do
    local x = x0 + 18 + i * ((length-36)/7)
    box(wood, x-2, y+18, z0, x+2, y+35+(i%3)*3, z0+5)
    box(wood, x-2, y+18, z1-5, x+2, y+35+(i%2)*4, z1)
  end
  -- Main mast and a broken forward mast.
  box(wood, piece.x-18, y+18, piece.z-3, piece.x-12, y+height+38, piece.z+3)
  box(dark, piece.x-48, y+18, piece.z-2.5, piece.x-43, y+height+12, piece.z+2.5)
  box(wood, piece.x-54, y+height+3, piece.z-2, piece.x-8, y+height+7, piece.z+2)
  -- Cabin fragment.
  box(dark, piece.x+22, y+20, piece.z-15, piece.x+48, y+36, piece.z+15)
  box(wood, piece.x+18, y+36, piece.z-18, piece.x+51, y+40, piece.z+18)

  if piece.solid then addCollider(colliders, x0, z0, x1, z1, y, y+40) end
end

function SetpieceDecor:addBlackSmokers(buckets, colliders, volume, piece)
  local rock = bucket(buckets, "smokerRock")
  local glow = bucket(buckets, "smokerGlow")
  local rng = lcg(math.floor(piece.x*17 + piece.z*29 + (piece.count or 4)*71))
  for i = 1, piece.count or 4 do
    local angle = (i-1) / math.max(1, piece.count or 4) * math.pi * 2 + rng(-0.25, 0.25)
    local radius = rng((piece.radius or 40)*0.25, piece.radius or 40)
    local x = piece.x + math.cos(angle) * radius
    local z = piece.z + math.sin(angle) * radius
    local y = self:floorY(volume, x, z)
    local h = (piece.height or 70) * rng(0.55, 1.0)
    local r = rng(4.5, 7.5)
    box(rock, x-r, y, z-r, x+r, y+h, z+r)
    box(rock, x-r-2, y, z-r-2, x+r+2, y+6, z+r+2)
    box(glow, x-r*0.65, y+h-3, z-r*0.65, x+r*0.65, y+h+2, z+r*0.65)
    if piece.solid then addCollider(colliders, x-r, z-r, x+r, z+r, y, y+h) end
  end
end

function SetpieceDecor:addCaveCeiling(buckets, volume, piece)
  local rock = bucket(buckets, "caveRock")
  local ceilingY = volume.surfaceHeight - (piece.ceilingDepth or 18)
  local t = piece.thickness or 18
  box(rock,
    piece.x-(piece.width or 280)/2, ceilingY,
    piece.z-(piece.depth or 220)/2,
    piece.x+(piece.width or 280)/2, ceilingY+t,
    piece.z+(piece.depth or 220)/2)
end

function SetpieceDecor:addStalactites(buckets, colliders, volume, piece)
  local rock = bucket(buckets, "caveRock")
  local rng = lcg(piece.seed or 1)
  local topY = volume.surfaceHeight - (piece.ceilingDepth or 28)
  for _ = 1, piece.count or 20 do
    local x, z = rng(piece.x0, piece.x1), rng(piece.z0, piece.z1)
    local length = rng(piece.minLength or 16, piece.maxLength or 54)
    local r = rng(3.5, 8)
    local bottomY = topY - length
    box(rock, x-r, topY-length*0.42, z-r, x+r, topY, z+r)
    box(rock, x-r*0.65, topY-length*0.72, z-r*0.65, x+r*0.65, topY-length*0.40, z+r*0.65)
    box(rock, x-r*0.32, bottomY, z-r*0.32, x+r*0.32, topY-length*0.70, z+r*0.32)
    if piece.solid then addCollider(colliders, x-r, z-r, x+r, z+r, bottomY, topY) end
  end
end

function SetpieceDecor:addRibCage(buckets, volume, piece)
  local bone = bucket(buckets, "bone")
  local y = self:floorY(volume, piece.x, piece.z) + 3
  local length, width, height = piece.length or 110, piece.width or 80, piece.height or 44
  box(bone, piece.x-length/2, y, piece.z-2, piece.x+length/2, y+4, piece.z+2)
  local ribs = piece.ribs or 8
  for i = 1, ribs do
    local x = piece.x-length/2 + i * (length/(ribs+1))
    local rise = height * (0.72 + 0.28 * math.sin(i/ribs*math.pi))
    box(bone, x-1.8, y, piece.z-width/2, x+1.8, y+rise, piece.z-width/2+3.5)
    box(bone, x-1.8, y, piece.z+width/2-3.5, x+1.8, y+rise, piece.z+width/2)
    box(bone, x-1.8, y+rise-3.5, piece.z-width/2+2, x+1.8, y+rise, piece.z+width/2-2)
  end
  -- Skull-like block at one end, stylised rather than anatomical.
  box(bone, piece.x+length/2-5, y+3, piece.z-14, piece.x+length/2+19, y+22, piece.z+14)
  box(bucket(buckets, "caveRock"), piece.x+length/2+10, y+9, piece.z-9,
    piece.x+length/2+21, y+15, piece.z-3)
  box(bucket(buckets, "caveRock"), piece.x+length/2+10, y+9, piece.z+3,
    piece.x+length/2+21, y+15, piece.z+9)
end

function SetpieceDecor:build(definition, volume)
  local buckets, colliders = {}, {}
  for _, piece in ipairs(definition.pieces or {}) do
    if piece.kind == "shipwreck" then self:addShipwreck(buckets, colliders, volume, piece)
    elseif piece.kind == "black_smokers" then self:addBlackSmokers(buckets, colliders, volume, piece)
    elseif piece.kind == "cave_ceiling" then self:addCaveCeiling(buckets, volume, piece)
    elseif piece.kind == "stalactite_field" then self:addStalactites(buckets, colliders, volume, piece)
    elseif piece.kind == "rib_cage" then self:addRibCage(buckets, volume, piece) end
  end
  local meshes = {}
  for material, vertices in pairs(buckets) do meshes[material] = self:makeMesh(vertices) end
  return { meshes = meshes, colliders = colliders }
end

function SetpieceDecor:geometry(definition, volume)
  local cached = self.cache[definition.id]
  if cached then return cached end
  cached = self:build(definition, volume)
  self.cache[definition.id] = cached
  return cached
end

function SetpieceDecor:draw(volume)
  local definition = volume and self:forMap(volume.mapId)
  local Voxel3D = self.voxel3d
  if not (definition and Voxel3D and type(Voxel3D.draw) == "function") then return end
  local geo = self:geometry(definition, volume)
  pcall(love.graphics.setDepthMode, "lequal", true)
  if type(Voxel3D.seams) == "function" then Voxel3D.seams(false) end
  if type(Voxel3D.glass) == "function" then Voxel3D.glass(false) end
  for material, mesh in pairs(geo.meshes or {}) do
    if mesh then
      love.graphics.setColor(1,1,1,1)
      Voxel3D.draw(mesh, self:makeTexture(material))
    end
  end
  if type(Voxel3D.glass) == "function" then Voxel3D.glass(true) end
  if type(Voxel3D.seams) == "function" then Voxel3D.seams(true) end
end

function SetpieceDecor:blocksCell(mapId, cellX, cellY, depth)
  local definition = self:forMap(mapId)
  local volume = self.registry:forMap(mapId)
  if not (definition and volume) then return false end
  local geo = self:geometry(definition, volume)
  local x, z = cellX*CELL + CELL/2, cellY*CELL + CELL/2
  local worldY = volume.surfaceHeight - (tonumber(depth) or volume.defaultDepth)
  for _, c in ipairs(geo.colliders or {}) do
    if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1
        and worldY >= c.bottomY - 7 and worldY <= c.topY + 10 then
      return true
    end
  end
  return false
end

function SetpieceDecor:invalidate()
  for id, geo in pairs(self.cache) do
    for _, mesh in pairs(geo.meshes or {}) do release(mesh) end
    self.cache[id] = nil
  end
  for name, texture in pairs(self.textures) do
    release(texture)
    self.textures[name] = nil
  end
end

return SetpieceDecor
