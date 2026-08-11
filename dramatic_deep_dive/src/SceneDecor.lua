local SceneDecor = {}
SceneDecor.__index = SceneDecor

local CELL = 16

local MATERIALS = {
  reefRock   = { 0.16, 0.31, 0.34, 1.00 },
  ruinStone  = { 0.29, 0.38, 0.39, 1.00 },
  darkStone  = { 0.10, 0.17, 0.23, 1.00 },
  coralPink  = { 0.95, 0.27, 0.55, 1.00 },
  coralOrange= { 1.00, 0.46, 0.20, 1.00 },
  coralPurple= { 0.57, 0.31, 0.88, 1.00 },
  kelp       = { 0.12, 0.57, 0.31, 1.00 },
  crystal    = { 0.19, 0.86, 0.96, 1.00 },
  sand       = { 0.54, 0.49, 0.35, 1.00 },
  fish       = { 0.47, 0.76, 0.92, 1.00 },
  bubble     = { 0.76, 0.94, 1.00, 0.42 },
  light      = { 0.62, 0.84, 1.00, 0.045 },
}

local CORAL_MATERIALS = { "coralPink", "coralOrange", "coralPurple" }

local function addVertex(out, x, y, z, u, v, shade)
  out[#out + 1] = { x, y, z, u or 0, v or 0, shade or 1 }
end

local function addTri(out, a, b, c, shade)
  addVertex(out, a[1], a[2], a[3], 0, 0, shade)
  addVertex(out, b[1], b[2], b[3], 1, 0, shade)
  addVertex(out, c[1], c[2], c[3], 0.5, 1, shade)
end

local function addQuad(out, a, b, c, d, shade)
  addTri(out, a, b, c, shade)
  addTri(out, a, c, d, shade)
end

local function addBox(out, x0, y0, z0, x1, y1, z1)
  if x1 <= x0 or y1 <= y0 or z1 <= z0 then return end
  addQuad(out, {x0,y1,z0}, {x1,y1,z0}, {x1,y1,z1}, {x0,y1,z1}, 1.00)
  addQuad(out, {x0,y0,z1}, {x1,y0,z1}, {x1,y0,z0}, {x0,y0,z0}, 0.58)
  addQuad(out, {x0,y0,z0}, {x0,y1,z0}, {x0,y1,z1}, {x0,y0,z1}, 0.72)
  addQuad(out, {x1,y0,z1}, {x1,y1,z1}, {x1,y1,z0}, {x1,y0,z0}, 0.84)
  addQuad(out, {x0,y0,z1}, {x0,y1,z1}, {x1,y1,z1}, {x1,y0,z1}, 0.90)
  addQuad(out, {x1,y0,z0}, {x1,y1,z0}, {x0,y1,z0}, {x0,y0,z0}, 0.66)
end

local function addPyramid(out, cx, y0, cz, radius, height)
  local a = { cx - radius, y0, cz - radius }
  local b = { cx + radius, y0, cz - radius }
  local c = { cx + radius, y0, cz + radius }
  local d = { cx - radius, y0, cz + radius }
  local p = { cx, y0 + height, cz }
  addQuad(out, a, d, c, b, 0.52)
  addTri(out, a, b, p, 0.88)
  addTri(out, b, c, p, 1.00)
  addTri(out, c, d, p, 0.76)
  addTri(out, d, a, p, 0.68)
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

local function modelTR(x, y, z, yaw)
  local c, s = math.cos(yaw or 0), math.sin(yaw or 0)
  return {
     c, 0, s, x,
     0, 1, 0, y,
    -s, 0, c, z,
     0, 0, 0, 1,
  }
end

local function release(value)
  if value and value.release then pcall(value.release, value) end
end

function SceneDecor.new(mod, registry, definitions)
  local byMap = {}
  for id, scene in pairs(definitions or {}) do
    scene.id = scene.id or id
    if scene.mapId then byMap[scene.mapId] = scene end
  end
  return setmetatable({
    mod = mod,
    registry = registry,
    definitions = definitions or {},
    byMap = byMap,
    voxel3d = nil,
    cache = {},
    textures = {},
    bubbleMesh = nil,
    fishMesh = nil,
  }, SceneDecor)
end

function SceneDecor:setVoxel3D(voxel3d)
  self.voxel3d = voxel3d
end

function SceneDecor:sceneForMap(mapId)
  return self.byMap[mapId]
end

function SceneDecor:makeTexture(material)
  local current = self.textures[material]
  if current then return current end
  local color = MATERIALS[material] or { 1, 1, 1, 1 }
  if not (love and love.image and love.image.newImageData
      and love.graphics and love.graphics.newImage) then return nil end
  local ok, image = pcall(function()
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, color[1], color[2], color[3], 1)
    local out = love.graphics.newImage(data)
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end)
  if ok then self.textures[material] = image return image end
  return nil
end

function SceneDecor:makeMesh(vertices)
  local Voxel3D = self.voxel3d
  if not (Voxel3D and Voxel3D.FORMAT and love and love.graphics
      and love.graphics.newMesh and #vertices >= 3) then return nil end
  local ok, mesh = pcall(love.graphics.newMesh,
    Voxel3D.FORMAT, vertices, "triangles", "static")
  return ok and mesh or nil
end

function SceneDecor:floorY(volume, x, z)
  local cx = math.max(0, math.floor(x / CELL))
  local cy = math.max(0, math.floor(z / CELL))
  local floorDepth = self.registry:floorDepthAt(volume.mapId, cx, cy)
    or volume.defaultFloorDepth
  return volume.surfaceHeight - floorDepth
end

local function bucket(buckets, material)
  buckets[material] = buckets[material] or {}
  return buckets[material]
end

local function addCollider(colliders, x0, z0, x1, z1, bottomY, topY)
  colliders[#colliders + 1] = {
    x0 = math.min(x0, x1), z0 = math.min(z0, z1),
    x1 = math.max(x0, x1), z1 = math.max(z0, z1),
    bottomY = bottomY, topY = topY,
  }
end

function SceneDecor:addCoral(buckets, volume, x, z, height, rng)
  local material = CORAL_MATERIALS[1 + math.floor(rng(0, #CORAL_MATERIALS - 0.001))]
  local out = bucket(buckets, material)
  local y = self:floorY(volume, x, z)
  local trunk = rng(2.5, 4.8)
  addBox(out, x - trunk/2, y, z - trunk/2, x + trunk/2, y + height, z + trunk/2)
  local branches = 2 + math.floor(rng(0, 3.99))
  for i = 1, branches do
    local by = y + height * rng(0.34, 0.88)
    local len = height * rng(0.22, 0.48)
    local thick = math.max(2, trunk * rng(0.55, 0.85))
    local axisX = rng() > 0.5
    local sign = rng() > 0.5 and 1 or -1
    if axisX then
      local x1 = x + sign * len
      addBox(out, math.min(x, x1), by, z - thick/2,
        math.max(x, x1), by + thick, z + thick/2)
      addBox(out, x1 - thick/2, by, z - thick/2,
        x1 + thick/2, by + len * 0.55, z + thick/2)
    else
      local z1 = z + sign * len
      addBox(out, x - thick/2, by, math.min(z, z1),
        x + thick/2, by + thick, math.max(z, z1))
      addBox(out, x - thick/2, by, z1 - thick/2,
        x + thick/2, by + len * 0.55, z1 + thick/2)
    end
  end
end

function SceneDecor:addKelp(buckets, volume, x, z, height, rng)
  local out = bucket(buckets, "kelp")
  local y = self:floorY(volume, x, z)
  local segments = math.max(3, math.floor(height / 8))
  local sx, sz = x, z
  for i = 1, segments do
    local h = height / segments
    local nx = sx + rng(-2.6, 2.6)
    local nz = sz + rng(-1.8, 1.8)
    addBox(out, nx - 1.25, y + (i-1)*h, nz - 1.25,
      nx + 1.25, y + i*h + 0.6, nz + 1.25)
    if i % 2 == 0 then
      local side = (i % 4 == 0) and -1 or 1
      addBox(out, nx, y + i*h - 3, nz - 0.8,
        nx + side * rng(5, 9), y + i*h - 1, nz + 0.8)
    end
    sx, sz = nx, nz
  end
end

function SceneDecor:addRock(buckets, volume, x, z, height, rng, material)
  local out = bucket(buckets, material or "reefRock")
  local y = self:floorY(volume, x, z)
  local w = rng(9, 20)
  local d = rng(8, 18)
  addBox(out, x-w/2, y, z-d/2, x+w/2, y + height*0.52, z+d/2)
  addBox(out, x-w*0.34, y + height*0.48, z-d*0.32,
    x+w*0.30, y + height*0.78, z+d*0.30)
  addBox(out, x-w*0.18, y + height*0.74, z-d*0.16,
    x+w*0.14, y + height, z+d*0.14)
end

function SceneDecor:addCrystal(buckets, volume, x, z, height, radius)
  local out = bucket(buckets, "crystal")
  local y = self:floorY(volume, x, z)
  addPyramid(out, x, y, z, radius or math.max(2.5, height * 0.18), height)
end

function SceneDecor:addGate(buckets, colliders, volume, s, abyss)
  local out = bucket(buckets, s.material or (abyss and "darkStone" or "ruinStone"))
  local y = self:floorY(volume, s.x, s.z)
  local w = s.width or 80
  local h = s.height or 60
  local t = s.thickness or 12
  local pillar = math.max(t, w * 0.14)
  local left0, left1 = s.x-w/2, s.x-w/2+pillar
  local right0, right1 = s.x+w/2-pillar, s.x+w/2
  local z0, z1 = s.z-t/2, s.z+t/2
  addBox(out, left0, y, z0, left1, y+h, z1)
  addBox(out, right0, y, z0, right1, y+h, z1)
  addBox(out, left0, y+h-t, z0, right1, y+h, z1)
  if abyss then
    addBox(out, left0-t*0.35, y, z0-t*0.35, left1+t*0.35, y+t*0.7, z1+t*0.35)
    addBox(out, right0-t*0.35, y, z0-t*0.35, right1+t*0.35, y+t*0.7, z1+t*0.35)
    addBox(out, s.x-t*0.38, y+h-t*1.8, z0-t*0.55,
      s.x+t*0.38, y+h+t*0.45, z1+t*0.55)
  end
  if s.solid then
    addCollider(colliders, left0, z0, left1, z1, y, y+h)
    addCollider(colliders, right0, z0, right1, z1, y, y+h)
  end
end

function SceneDecor:addRockArch(buckets, volume, s)
  local out = bucket(buckets, s.material or "reefRock")
  local y = self:floorY(volume, s.x, s.z)
  local w, h, t = s.width or 110, s.height or 55, s.thickness or 14
  local pillar = math.max(t*1.25, w*0.16)
  addBox(out, s.x-w/2, y, s.z-t/2, s.x-w/2+pillar, y+h*0.86, s.z+t/2)
  addBox(out, s.x+w/2-pillar, y, s.z-t/2, s.x+w/2, y+h*0.86, s.z+t/2)
  addBox(out, s.x-w/2+pillar*0.55, y+h*0.70, s.z-t*0.62,
    s.x+w/2-pillar*0.55, y+h*0.88, s.z+t*0.62)
  addBox(out, s.x-w*0.31, y+h*0.84, s.z-t*0.72,
    s.x+w*0.31, y+h, s.z+t*0.72)
end

function SceneDecor:addBrokenWall(buckets, colliders, volume, s)
  local out = bucket(buckets, s.material or "ruinStone")
  local y = self:floorY(volume, s.x, s.z)
  local w, h, t = s.width or 60, s.height or 34, s.thickness or 9
  local chunks = 6
  for i = 0, chunks-1 do
    local x0 = s.x-w/2 + (w/chunks)*i
    local x1 = x0 + w/chunks + 0.8
    local localH = h * (0.40 + 0.60 * (((i*7 + 3) % 11) / 10))
    addBox(out, x0, y, s.z-t/2, x1, y+localH, s.z+t/2)
  end
  if s.solid then addCollider(colliders, s.x-w/2, s.z-t/2, s.x+w/2, s.z+t/2, y, y+h) end
end

function SceneDecor:addColumnRing(buckets, colliders, volume, s)
  local out = bucket(buckets, s.material or "ruinStone")
  local count = s.count or 8
  for i = 1, count do
    local angle = (i-1) / count * math.pi * 2
    local x = s.x + math.cos(angle) * (s.radius or 60)
    local z = s.z + math.sin(angle) * (s.radius or 60)
    local y = self:floorY(volume, x, z)
    local h = (s.height or 50) * (0.72 + 0.28 * (((i*5)%7)/6))
    local r = 5.2
    addBox(out, x-r, y, z-r, x+r, y+h, z+r)
    addBox(out, x-r-2, y, z-r-2, x+r+2, y+5, z+r+2)
    addBox(out, x-r-1.5, y+h-5, z-r-1.5, x+r+1.5, y+h, z+r+1.5)
    if s.solid then addCollider(colliders, x-r, z-r, x+r, z+r, y, y+h) end
  end
end

function SceneDecor:addShrine(buckets, colliders, volume, s)
  local out = bucket(buckets, s.material or "ruinStone")
  local y = self:floorY(volume, s.x, s.z)
  local w, d, h = s.width or 72, s.depth or 52, s.height or 48
  addBox(out, s.x-w/2, y, s.z-d/2, s.x+w/2, y+5, s.z+d/2)
  addBox(out, s.x-w*0.36, y+5, s.z-d*0.34, s.x+w*0.36, y+10, s.z+d*0.34)
  local offsets = {
    {-w*0.34,-d*0.30}, {w*0.34,-d*0.30}, {-w*0.34,d*0.30}, {w*0.34,d*0.30},
  }
  for _, p in ipairs(offsets) do
    local x, z = s.x+p[1], s.z+p[2]
    addBox(out, x-4, y+10, z-4, x+4, y+h, z+4)
    if s.solid then addCollider(colliders, x-4, z-4, x+4, z+4, y, y+h) end
  end
  local crystal = bucket(buckets, "crystal")
  addPyramid(crystal, s.x, y+10, s.z, 7, 30)
end

function SceneDecor:addSpire(buckets, volume, s)
  local rng = lcg(math.floor(s.x*31 + s.z*17))
  self:addRock(buckets, volume, s.x, s.z, s.height or 80, rng, s.material or "reefRock")
end

function SceneDecor:buildScene(scene, volume)
  local buckets, colliders = {}, {}

  for _, s in ipairs(scene.structures or {}) do
    if s.kind == "ruin_gate" then self:addGate(buckets, colliders, volume, s, false)
    elseif s.kind == "abyss_gate" then self:addGate(buckets, colliders, volume, s, true)
    elseif s.kind == "rock_arch" then self:addRockArch(buckets, volume, s)
    elseif s.kind == "broken_wall" then self:addBrokenWall(buckets, colliders, volume, s)
    elseif s.kind == "column_ring" then self:addColumnRing(buckets, colliders, volume, s)
    elseif s.kind == "shrine" then self:addShrine(buckets, colliders, volume, s)
    elseif s.kind == "spire" then self:addSpire(buckets, volume, s) end
  end

  for _, spec in ipairs(scene.scatter or {}) do
    local rng = lcg(spec.seed)
    for _ = 1, spec.count or 0 do
      local x, z = rng(spec.x0, spec.x1), rng(spec.z0, spec.z1)
      local cellX, cellY = math.floor(x / CELL), math.floor(z / CELL)
      if self.registry:contains(volume.mapId, cellX, cellY) then
        local h = rng(spec.minHeight or 8, spec.maxHeight or 24)
        if spec.kind == "coral" then self:addCoral(buckets, volume, x, z, h, rng)
        elseif spec.kind == "kelp" then self:addKelp(buckets, volume, x, z, h, rng)
        elseif spec.kind == "crystal" then self:addCrystal(buckets, volume, x, z, h, rng(2.4, 5.2))
        elseif spec.kind == "rock" then self:addRock(buckets, volume, x, z, h, rng, "darkStone") end
      end
    end
  end

  for index, cluster in ipairs(scene.crystalClusters or {}) do
    local rng = lcg(8000 + index*97)
    for _ = 1, cluster.count or 5 do
      local angle = rng(0, math.pi*2)
      local radius = rng(2, cluster.radius or 18)
      self:addCrystal(buckets, volume,
        cluster.x + math.cos(angle)*radius,
        cluster.z + math.sin(angle)*radius,
        rng((cluster.height or 28)*0.45, cluster.height or 28), rng(2.5, 5.5))
    end
  end

  local light = bucket(buckets, "light")
  for _, shaft in ipairs(scene.lightShafts or {}) do
    local bottomY = volume.surfaceHeight - (shaft.bottomDepth or 120)
    addBox(light,
      shaft.x-(shaft.width or 24)/2, bottomY,
      shaft.z-(shaft.depth or 40)/2,
      shaft.x+(shaft.width or 24)/2, volume.surfaceHeight-2,
      shaft.z+(shaft.depth or 40)/2)
  end

  local meshes = {}
  for material, vertices in pairs(buckets) do
    meshes[material] = self:makeMesh(vertices)
  end

  return { meshes = meshes, colliders = colliders }
end

function SceneDecor:geometry(scene, volume)
  local hit = self.cache[scene.id]
  if hit then return hit end
  hit = self:buildScene(scene, volume)
  self.cache[scene.id] = hit
  return hit
end

function SceneDecor:ensureBubbleMesh()
  if self.bubbleMesh then return self.bubbleMesh end
  local v = {}
  addBox(v, -1.2, -1.2, -1.2, 1.2, 1.2, 1.2)
  self.bubbleMesh = self:makeMesh(v)
  return self.bubbleMesh
end

function SceneDecor:ensureFishMesh()
  if self.fishMesh then return self.fishMesh end
  local v = {}
  addBox(v, -3.6, -1.2, -1.5, 3.0, 1.2, 1.5)
  addTri(v, {-3.2,0,0}, {-6.4,2.5,0}, {-6.4,-2.5,0}, 0.78)
  addTri(v, {-3.2,0,0}, {-6.4,-2.5,0}, {-6.4,2.5,0}, 0.78)
  self.fishMesh = self:makeMesh(v)
  return self.fishMesh
end

function SceneDecor:drawOpaque(scene, volume, geo)
  local Voxel3D = self.voxel3d
  if not Voxel3D then return end
  pcall(love.graphics.setDepthMode, "lequal", true)
  for material, mesh in pairs(geo.meshes or {}) do
    if material ~= "light" and mesh then
      local color = MATERIALS[material] or {1,1,1,1}
      love.graphics.setColor(1, 1, 1, color[4] or 1)
      Voxel3D.draw(mesh, self:makeTexture(material))
    end
  end
end

function SceneDecor:drawFish(scene, volume, time)
  local Voxel3D = self.voxel3d
  local mesh = self:ensureFishMesh()
  local texture = self:makeTexture("fish")
  if not (Voxel3D and mesh and texture) then return end
  love.graphics.setColor(1,1,1,0.82)
  for _, school in ipairs(scene.fishSchools or {}) do
    local rng = lcg(school.seed)
    for i = 1, school.count or 0 do
      local base = rng(0, math.pi*2)
      local radius = rng((school.radius or 60)*0.35, school.radius or 60)
      local phase = rng(0, math.pi*2)
      local speed = (school.speed or 0.25) * rng(0.75, 1.25)
      local angle = base + time*speed
      local x = school.x + math.cos(angle)*radius
      local z = school.z + math.sin(angle)*radius*0.55
      local depth = (school.depth or 70) + math.sin(time*0.7 + phase)*10
      local y = volume.surfaceHeight - depth
      Voxel3D.draw(mesh, texture, modelTR(x, y, z, -angle + math.pi/2), -0.08)
    end
  end
end

function SceneDecor:drawTransparent(scene, volume, geo, time)
  local Voxel3D = self.voxel3d
  if not Voxel3D then return end
  pcall(love.graphics.setDepthMode, "lequal", false)

  local lightMesh = geo.meshes and geo.meshes.light
  if lightMesh then
    love.graphics.setColor(1,1,1,(MATERIALS.light[4] or 0.04))
    Voxel3D.draw(lightMesh, self:makeTexture("light"))
  end

  local bubbleMesh = self:ensureBubbleMesh()
  local bubbleTexture = self:makeTexture("bubble")
  if bubbleMesh and bubbleTexture then
    love.graphics.setColor(1,1,1,MATERIALS.bubble[4])
    for ventIndex, vent in ipairs(scene.bubbleVents or {}) do
      local floorY = self:floorY(volume, vent.x, vent.z) + 3
      local height = math.min(vent.height or 120, volume.surfaceHeight-floorY-3)
      for i = 1, vent.count or 5 do
        local phase = ((i * 0.173 + ventIndex * 0.271) % 1)
        local rise = ((time * (vent.speed or 12) / math.max(1,height)) + phase) % 1
        local wobble = math.sin(time*1.7 + i*2.1 + ventIndex) * 3.2
        local wobbleZ = math.cos(time*1.25 + i*1.4) * 2.1
        local y = floorY + rise * height
        Voxel3D.draw(bubbleMesh, bubbleTexture,
          modelTR(vent.x+wobble, y, vent.z+wobbleZ, 0), -0.12)
      end
    end
  end

  love.graphics.setColor(1,1,1,1)
  pcall(love.graphics.setDepthMode, "lequal", true)
end

function SceneDecor:draw(volume)
  local scene = volume and self:sceneForMap(volume.mapId)
  local Voxel3D = self.voxel3d
  if not (scene and Voxel3D and type(Voxel3D.draw) == "function") then return end
  local geo = self:geometry(scene, volume)
  local time = love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock()

  if type(Voxel3D.seams) == "function" then Voxel3D.seams(false) end
  if type(Voxel3D.glass) == "function" then Voxel3D.glass(false) end
  self:drawOpaque(scene, volume, geo)
  self:drawFish(scene, volume, time)
  self:drawTransparent(scene, volume, geo, time)
  if type(Voxel3D.glass) == "function" then Voxel3D.glass(true) end
  if type(Voxel3D.seams) == "function" then Voxel3D.seams(true) end
end

function SceneDecor:blocksCell(mapId, cellX, cellY, depth)
  local scene = self:sceneForMap(mapId)
  local volume = self.registry:forMap(mapId)
  if not (scene and volume) then return false end
  local geo = self:geometry(scene, volume)
  local x, z = cellX*CELL + CELL/2, cellY*CELL + CELL/2
  local worldY = volume.surfaceHeight - (tonumber(depth) or volume.defaultDepth)
  for _, c in ipairs(geo.colliders or {}) do
    if x >= c.x0 and x <= c.x1 and z >= c.z0 and z <= c.z1
        and worldY >= c.bottomY - 8 and worldY <= c.topY + 12 then
      return true
    end
  end
  return false
end

function SceneDecor:districtAt(mapId, worldZ)
  local scene = self:sceneForMap(mapId)
  if not scene then return nil end
  for _, district in ipairs(scene.districts or {}) do
    if worldZ >= district.z0 and worldZ < district.z1 then return district end
  end
  return nil
end

function SceneDecor:invalidate()
  for id, geo in pairs(self.cache) do
    for _, mesh in pairs(geo.meshes or {}) do release(mesh) end
    self.cache[id] = nil
  end
  for name, texture in pairs(self.textures) do
    release(texture)
    self.textures[name] = nil
  end
  release(self.bubbleMesh)
  release(self.fishMesh)
  self.bubbleMesh, self.fishMesh = nil, nil
end

return SceneDecor
