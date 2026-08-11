local Game = require("src.core.Game")
local SpriteRenderer = require("src.render.SpriteRenderer")

local Stadium2Underwater = {}
Stadium2Underwater.__index = Stadium2Underwater

local MAX_ACTIVE_MODELS = 10
local MODEL_RANGE_CELLS = 24
local TRAVEL_LIMIT = 0.75
local NONE = 0xFFFF

local MORPH_SCALE = {
  GYARADOS = 1.18, DRATINI = 1.06, DRAGONAIR = 1.14,
  LAPRAS = 1.12, TENTACRUEL = 1.08, TENTACOOL = 0.96,
  ONIX = 1.14, STEELIX = 1.16, MANTINE = 1.12,
  KINGDRA = 1.06, CLOYSTER = 1.04, SEADRA = 1.02,
  DEWGONG = 1.05, VAPOREON = 1.03, QWILFISH = 0.92,
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function dexHeightFeet(species)
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[species]
  local dex = def and def.dexEntry
  if not dex then return 3 end
  local feet = (tonumber(dex.heightFt) or 0) + (tonumber(dex.heightIn) or 0) / 12
  return feet > 0 and feet or 3
end

-- Stadium's raw model range is much wider than one shared overworld camera can
-- frame. Keep Pokédex ordering, compress the extremes, then apply a handful of
-- morphology corrections for long-bodied sea Pokémon.
local function worldHeight(species)
  local feet = math.max(0.5, dexHeightFeet(species))
  local h = 16 * (feet / 3) ^ 0.58
  h = h * (MORPH_SCALE[species] or 1)
  return clamp(h, 8.5, 46)
end

local function dynamicAnimation(model, PackModule)
  local requested = model and model.ctx and model.ctx[1]
  if requested and requested ~= NONE and model.anims and model.anims[requested + 1] then
    requested = requested + 1
  else
    requested = nil
  end

  local function moves(index)
    if not (PackModule and PackModule.tracks and index) then return false end
    local ok, tracks = pcall(PackModule.tracks, model, index)
    if not ok or type(tracks) ~= "table" then return false end
    for _, comps in pairs(tracks) do
      for _, values in ipairs(comps or {}) do
        if type(values) == "table" and #values > 1 then
          local first = values[1] or 0
          for i = 2, #values do
            if math.abs((values[i] or 0) - first) > 1e-6 then return true end
          end
        end
      end
    end
    return false
  end

  if requested and moves(requested) then return requested, "stadium_idle" end
  local firstMoving, firstLooping
  for i, anim in ipairs(model and model.anims or {}) do
    if moves(i) then
      if not firstMoving then firstMoving = i end
      local loop = tonumber(anim.loopStart) or 0
      if not firstLooping and loop > 0 and loop < (tonumber(anim.frames) or 1) then
        firstLooping = i
      end
    end
  end
  return firstLooping or firstMoving or requested or 1,
    (firstLooping and "moving_loop_recovery")
      or (firstMoving and "moving_clip_recovery") or "static_fallback"
end

local function textureImage(slot)
  if not slot then return nil end
  if slot.image ~= nil then return slot.image or nil end
  if not (love and love.image and love.image.newImageData and love.graphics and love.graphics.newImage) then
    slot.image = false
    return nil
  end
  local ok, image = pcall(function()
    local data = love.image.newImageData(slot.w, slot.h, "rgba8", slot.rgba)
    local out = love.graphics.newImage(data)
    if out.setFilter then out:setFilter("nearest", "nearest") end
    return out
  end)
  slot.image = ok and image or false
  return slot.image or nil
end

local function activeVoxelLib(mod)
  local state = mod.exports and mod.exports._dramaticProviderState
  local handle = state and state.handle
  local lib = handle and handle.exports and handle.exports.lib
  if type(lib) == "table" and type(lib.require) == "function" then return lib end
  return nil
end

function Stadium2Underwater.new(mod, Pack)
  return setmetatable({
    mod = mod,
    Pack = Pack,
    lib = nil,
    Rig = nil,
    ProviderPack = nil,
    Mat4 = nil,
    Voxel3D = nil,
    SpriteBillboards = nil,
    ShadowMap = nil,
    runtimeBySwimmer = setmetatable({}, { __mode = "k" }),
    runtimeByDef = setmetatable({}, { __mode = "k" }),
    ownerByMesh = setmetatable({}, { __mode = "k" }),
    selected = setmetatable({}, { __mode = "k" }),
    specialSprites = {},
    attached = setmetatable({}, { __mode = "k" }),
    installed = false,
    loaded = 0,
    failed = 0,
    recoveredAnimations = 0,
  }, Stadium2Underwater)
end

function Stadium2Underwater:module(name)
  if not self.lib then return nil end
  local ok, value = pcall(self.lib.require, name)
  return ok and value or nil
end

function Stadium2Underwater:discover()
  self.lib = activeVoxelLib(self.mod)
  self.Rig = self:module("StadiumRig")
  self.ProviderPack = self:module("StadiumPack")
  self.Mat4 = self:module("Mat4")
  self.Voxel3D = self:module("Voxel3D")
  self.SpriteBillboards = self:module("SpriteBillboards")
  self.ShadowMap = self:module("ShadowMap")
  return type(self.Rig) == "table" and type(self.Rig.new) == "function"
    and self.ProviderPack and type(self.ProviderPack.tracks) == "function"
    and self.Mat4 and self.Voxel3D and self.SpriteBillboards and self.ShadowMap
end

function Stadium2Underwater:isDeepDiveActive()
  local fn = self.mod.exports and self.mod.exports.isActive
  if type(fn) ~= "function" then return false end
  local ok, active = pcall(fn)
  return ok and active == true
end

function Stadium2Underwater:currentVolume()
  local fn = self.mod.exports and self.mod.exports.currentVolume
  if type(fn) ~= "function" then return nil end
  local ok, volume = pcall(fn)
  return ok and volume or nil
end

function Stadium2Underwater:releaseRuntime(runtime)
  if runtime and runtime.rig and runtime.rig.release then pcall(runtime.rig.release, runtime.rig) end
end

function Stadium2Underwater:clear()
  for swimmer, runtime in pairs(self.runtimeBySwimmer) do
    self:releaseRuntime(runtime)
    self.runtimeBySwimmer[swimmer] = nil
  end
  self.runtimeByDef = setmetatable({}, { __mode = "k" })
  self.ownerByMesh = setmetatable({}, { __mode = "k" })
  self.selected = setmetatable({}, { __mode = "k" })
end

function Stadium2Underwater:attachEntity(swimmer)
  if not (swimmer and swimmer.deepDiveWildlife and type(swimmer.pose) == "function") then return end
  if self.attached[swimmer] then return end
  self.attached[swimmer] = true
  local service, innerPose = self, swimmer.pose
  swimmer.pose = function(entity, ...)
    local sprite, px, py, facing, phase, flip, hopping = innerPose(entity, ...)
    sprite = service:spriteFor(entity, sprite)
    return sprite, px, py, facing, phase, flip, hopping
  end
end

function Stadium2Underwater:scanWildlife()
  local ow = Game.overworld
  for _, entity in ipairs(ow and ow.entities or {}) do
    if entity and entity.deepDiveWildlife then self:attachEntity(entity) end
  end
end

function Stadium2Underwater:ensureRuntime(swimmer)
  if not swimmer or swimmer.dead then return nil end
  local hit = self.runtimeBySwimmer[swimmer]
  if hit then return hit end
  local def = Game.data and Game.data.pokemon and Game.data.pokemon[swimmer.species]
  local dex = def and tonumber(def.dex)
  if not dex or not self.Pack.available(dex, swimmer.shiny == true) then return nil end
  local model = self.Pack.load(dex, swimmer.shiny == true)
  if not model or model.staticPose then return nil end
  local ok, rig = pcall(self.Rig.new, model)
  if not ok or not rig or not rig.parts or not rig.parts[1] or not rig.parts[1].mesh then
    self.failed = self.failed + 1
    return nil
  end
  local anim, source = dynamicAnimation(model, self.ProviderPack)
  if source ~= "stadium_idle" and source ~= "static_fallback" then
    self.recoveredAnimations = self.recoveredAnimations + 1
  end
  local runtime = {
    swimmer = swimmer, model = model, rig = rig, dex = dex,
    species = swimmer.species, anim = anim, animSource = source,
    time = math.random() * 4, yaw = swimmer.heading or 0, pitch = 0,
    desiredHeight = worldHeight(swimmer.species), sentinel = rig.parts[1].mesh,
  }
  self.runtimeBySwimmer[swimmer] = runtime
  self.ownerByMesh[runtime.sentinel] = runtime
  self.loaded = self.loaded + 1
  return runtime
end

function Stadium2Underwater:applyEffectTextures(runtime)
  local tick = math.floor((runtime.time or 0) * 30)
  for _, part in ipairs(runtime.rig and runtime.rig.parts or {}) do
    local frames = part.prim and part.prim.fxFrames
    if type(frames) == "table" and #frames > 0 then
      local idx = frames[(tick % #frames) + 1]
      part.texture = textureImage(runtime.model.textures and runtime.model.textures[idx])
    end
  end
end

function Stadium2Underwater:poseRuntime(runtime, dt)
  local swimmer, rig, model = runtime.swimmer, runtime.rig, runtime.model
  if not (swimmer and rig and model) then return false end
  runtime.time = (runtime.time or 0) + math.max(0, tonumber(dt) or 0)
  local wantedYaw = tonumber(swimmer.heading) or runtime.yaw or 0
  local delta = (wantedYaw - (runtime.yaw or 0) + math.pi) % (2 * math.pi) - math.pi
  runtime.yaw = (runtime.yaw or 0) + clamp(delta, -2.4 * dt, 2.4 * dt)
  local depthDelta = (tonumber(swimmer.targetDepth) or tonumber(swimmer.depth) or 0)
    - (tonumber(swimmer.depth) or 0)
  local targetPitch = clamp(-depthDelta / 90, -0.24, 0.24)
  runtime.pitch = runtime.pitch + (targetPitch - runtime.pitch) * clamp(dt * 3.5, 0, 1)

  local record = model.anims and model.anims[runtime.anim]
  local ok = pcall(function()
    rig:pose(runtime.anim, runtime.time * 30, true)
    if rig.anchor then rig:anchor(TRAVEL_LIMIT, dt) end
    -- StadiumRig uses yaw while skinning to keep directional lighting correct;
    -- the world matrix below carries the same yaw for actual placement.
    if rig.skin then rig:skin(runtime.yaw) end
    if rig.textures then rig:textures(record and record.aux or nil) end
    self:applyEffectTextures(runtime)
  end)
  return ok
end

function Stadium2Underwater:modelMatrix(runtime)
  local swimmer = runtime and runtime.swimmer
  local volume = self:currentVolume()
  if not (swimmer and volume and self.Mat4) then return nil end
  local model = runtime.model
  local root = tonumber(model.rootScale) or 1
  if root <= 0 then root = 1 end
  local rawHeight = math.max(tonumber(model.height) or 1, 1e-6)
  local scale = root * runtime.desiredHeight / rawHeight
  local rawFloor = (tonumber(model.floor) or 0) / root
  local bob = math.sin((runtime.time or 0) * 1.7 + runtime.dex * 0.31)
    * math.min(1.1, runtime.desiredHeight * 0.035)
  local y = (tonumber(volume.surfaceHeight) or 0) - (tonumber(swimmer.depth) or 0) + bob
  local M = self.Mat4
  local matrix = M.mul(M.translate((swimmer.px or 0) + 8, y, (swimmer.py or 0) + 8), M.rotateY(runtime.yaw or 0))
  if M.rotateX then matrix = M.mul(matrix, M.rotateX(runtime.pitch or 0)) end
  matrix = M.mul(matrix, M.scale(scale, scale, scale))
  return M.mul(matrix, M.translate(0, -rawFloor, 0))
end

function Stadium2Underwater:spriteFor(swimmer, baseSprite)
  if not (self.selected[swimmer] and baseSprite and baseSprite.def) then return baseSprite end
  local runtime = self:ensureRuntime(swimmer)
  if not runtime then return baseSprite end
  local key = tostring(runtime.dex) .. ":" .. tostring(baseSprite.def.image)
  local sprite = self.specialSprites[key]
  if not sprite then
    local def = {}
    for k, v in pairs(baseSprite.def) do def[k] = v end
    def.id = "DDD_STADIUM2_" .. tostring(runtime.dex)
    def.frames, def.walker, def.trueColor = 6, true, true
    def.deepDiveStadium2 = true
    sprite = SpriteRenderer.new(def, "ddd_stadium2:" .. tostring(runtime.dex))
    sprite.image = baseSprite.image
    self.specialSprites[key] = sprite
  end
  self.runtimeByDef[sprite.def] = runtime
  return sprite
end

function Stadium2Underwater:selectNearest()
  self.selected = setmetatable({}, { __mode = "k" })
  local ow, player = Game.overworld, Game.overworld and Game.overworld.player
  if not player then return end
  local px, py = player.px or player.cellX * 16, player.py or player.cellY * 16
  local candidates = {}
  for _, swimmer in ipairs(ow.entities or {}) do
    if swimmer and swimmer.deepDiveWildlife and not swimmer.dead then
      local dx, dy = (swimmer.px or 0) - px, (swimmer.py or 0) - py
      local cells = math.sqrt(dx * dx + dy * dy) / 16
      if cells <= MODEL_RANGE_CELLS then candidates[#candidates + 1] = { swimmer = swimmer, d = cells } end
    end
  end
  table.sort(candidates, function(a, b) return a.d < b.d end)
  for i = 1, math.min(MAX_ACTIVE_MODELS, #candidates) do self.selected[candidates[i].swimmer] = true end
end

function Stadium2Underwater:tick(dt)
  if not self:isDeepDiveActive() then
    if next(self.runtimeBySwimmer) then self:clear() end
    return
  end
  self:scanWildlife()
  self:selectNearest()
  for swimmer, runtime in pairs(self.runtimeBySwimmer) do
    if swimmer.dead or not self.selected[swimmer] then
      self:releaseRuntime(runtime)
      self.runtimeBySwimmer[swimmer] = nil
    end
  end
  for swimmer in pairs(self.selected) do
    local runtime = self:ensureRuntime(swimmer)
    if runtime then self:poseRuntime(runtime, dt) end
  end
end

function Stadium2Underwater:installProviderHooks()
  local B, V, S, service = self.SpriteBillboards, self.Voxel3D, self.ShadowMap, self
  if not B.dramaticDeepDiveStadium2Hook then
    local innerMesh, innerShadow = B.mesh, B.shadowQuad
    B.mesh = function(def, frame)
      if def and def.deepDiveStadium2 then
        local runtime = service.runtimeByDef[def]
        if runtime and runtime.sentinel then return runtime.sentinel end
      end
      return innerMesh(def, frame)
    end
    B.shadowQuad = function(def, frame)
      if def and def.deepDiveStadium2 then
        local runtime = service.runtimeByDef[def]
        if runtime and runtime.sentinel then return runtime.sentinel end
      end
      return innerShadow(def, frame)
    end
    B.dramaticDeepDiveStadium2Hook = true
  end

  if not V.dramaticDeepDiveStadium2Hook and type(V.draw) == "function" then
    local rawDraw = V.draw
    V.draw = function(mesh, texture, matrix, pull, sunModel)
      local runtime = service.ownerByMesh[mesh]
      if not runtime then return rawDraw(mesh, texture, matrix, pull, sunModel) end
      local custom = service:modelMatrix(runtime)
      if not custom then return rawDraw(mesh, texture, matrix, pull, sunModel) end
      if V.seams then V.seams(false) end
      if V.glass then V.glass(false) end
      local additive = {}
      for _, part in ipairs(runtime.rig.parts or {}) do
        if part.prim and part.prim.additive then additive[#additive + 1] = part
        elseif part.texture then rawDraw(part.mesh, part.texture, custom, 0, custom) end
      end
      if #additive > 0 and V.blend then V.blend("add") end
      for _, part in ipairs(additive) do
        if part.texture then rawDraw(part.mesh, part.texture, custom, 0, custom) end
      end
      if #additive > 0 and V.blend then V.blend(nil) end
      if V.glass then V.glass(true) end
      if V.seams then V.seams(true) end
      return true
    end
    V.dramaticDeepDiveStadium2Hook = true
  end

  if not S.dramaticDeepDiveStadium2Hook and type(S.draw) == "function" then
    local rawShadow = S.draw
    S.draw = function(mesh, texture, matrix)
      local runtime = service.ownerByMesh[mesh]
      if not runtime then return rawShadow(mesh, texture, matrix) end
      local custom = service:modelMatrix(runtime)
      if not custom then return rawShadow(mesh, texture, matrix) end
      for _, part in ipairs(runtime.rig.parts or {}) do
        if part.texture and not (part.prim and part.prim.additive) then rawShadow(part.mesh, part.texture, custom) end
      end
      return true
    end
    S.dramaticDeepDiveStadium2Hook = true
  end
  return true
end

function Stadium2Underwater:install()
  if self.installed then return true end
  if not self:discover() then
    if self.mod.log then self.mod.log:warn("Stadium 2 underwater models unavailable: active voxel provider exposes no StadiumRig stack") end
    return false
  end
  self:installProviderHooks()
  local service = self
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then service:tick(tonumber(dt) or 1 / 60) end
    return result
  end, 68)
  self.mod.events:on("mod.DRAMATIC_DEEP_DIVE.surfaced", function() service:clear() end)
  self.mod.events:on("map.exited", function() service:clear() end)
  self.installed = true
  if self.mod.log then
    local marker = self.Pack.marker()
    self.mod.log:info("Stadium 2 underwater renderer ready (cache=%s, maxActive=%d)",
      marker and tostring(marker.format) or "not built yet", MAX_ACTIVE_MODELS)
  end
  return true
end

function Stadium2Underwater:stats()
  local active = 0
  for _ in pairs(self.runtimeBySwimmer) do active = active + 1 end
  local marker = self.Pack.marker()
  return {
    installed = self.installed,
    cacheReady = marker ~= nil,
    cacheFormat = marker and marker.format or nil,
    activeModels = active,
    maxActiveModels = MAX_ACTIVE_MODELS,
    modelRangeCells = MODEL_RANGE_CELLS,
    loaded = self.loaded,
    failed = self.failed,
    recoveredAnimations = self.recoveredAnimations,
  }
end

Stadium2Underwater.worldHeight = worldHeight

return Stadium2Underwater
