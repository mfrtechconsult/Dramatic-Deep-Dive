local Stadium2Pack = {}

local CACHE_ROOT = "crystal_251/stadium2"
local NORMAL_DIR = CACHE_ROOT .. "/normal"
local SHINY_DIR = CACHE_ROOT .. "/shiny"
local MARKER = CACHE_ROOT .. "/pack.info"
local MAGIC = "DSM4"
local NONE = 0xFFFF
local MOVE_SLOTS = 165
local CONTEXT_SLOTS = 20
local MAX_CACHE = 8

Stadium2Pack.NONE = NONE
Stadium2Pack.FPS = 30
Stadium2Pack.CACHE_ROOT = CACHE_ROOT

local cache, order, failed = {}, {}, {}

local function fsInfo(path)
  local fs = love and love.filesystem
  if not (fs and fs.getInfo) then return nil end
  local ok, info = pcall(fs.getInfo, path, "file")
  return ok and info or nil
end

local function read(path)
  local fs = love and love.filesystem
  if not (fs and fs.read) then return nil end
  local ok, bytes = pcall(fs.read, path)
  return ok and type(bytes) == "string" and bytes or nil
end

local function u8(s, p)
  local v = string.byte(s, p)
  if v == nil then error("unexpected end of DSM4 pack", 0) end
  return v, p + 1
end

local function u16(s, p)
  local a, b = string.byte(s, p, p + 1)
  if b == nil then error("unexpected end of DSM4 pack", 0) end
  return a + b * 256, p + 2
end

local function i16(s, p)
  local v
  v, p = u16(s, p)
  if v >= 32768 then v = v - 65536 end
  return v, p
end

local function u32(s, p)
  local a, b, c, d = string.byte(s, p, p + 3)
  if d == nil then error("unexpected end of DSM4 pack", 0) end
  return a + b * 256 + c * 65536 + d * 16777216, p + 4
end

local function i32(s, p)
  local v
  v, p = u32(s, p)
  if v >= 2147483648 then v = v - 4294967296 end
  return v, p
end

local function f32(s, p)
  local b1, b2, b3, b4 = string.byte(s, p, p + 3)
  if b4 == nil then error("unexpected end of DSM4 pack", 0) end
  local sign = 1
  if b4 >= 128 then sign, b4 = -1, b4 - 128 end
  local exponent = b4 * 2 + math.floor(b3 / 128)
  local mantissa = (b3 % 128) * 65536 + b2 * 256 + b1
  if exponent == 255 then
    return mantissa == 0 and sign * math.huge or 0 / 0, p + 4
  end
  if exponent == 0 then return sign * mantissa * 2 ^ -149, p + 4 end
  return sign * (1 + mantissa / 8388608) * 2 ^ (exponent - 127), p + 4
end

local function fixed(s, p)
  local v
  v, p = i32(s, p)
  return v / 65536, p
end

local COMPONENT_BYTES = { 2, 2, 2, 2, 2, 2, 4, 4, 4 }

local function skipTracks(bytes, p, bones, frames)
  for _ = 1, bones do
    local present
    present, p = u8(bytes, p)
    if present ~= 0 then
      for component = 1, 9 do
        local kind
        kind, p = u8(bytes, p)
        p = p + COMPONENT_BYTES[component] * (kind == 0 and 1 or frames)
        if p > #bytes + 1 then error("animation tracks exceed DSM4 pack", 0) end
      end
    end
  end
  return p
end

local function parse(bytes)
  if type(bytes) ~= "string" or bytes:sub(1, 4) ~= MAGIC then
    error("unsupported Stadium 2 pack (expected DSM4)", 0)
  end
  local p, model = 5, { bytes = bytes }
  model.species, p = u16(bytes, p)
  model.boneCount, p = u16(bytes, p)
  model.primCount, p = u16(bytes, p)
  model.texCount, p = u16(bytes, p)
  model.animCount, p = u16(bytes, p)
  model.auxCount, p = u16(bytes, p)
  model.attachmentCount, p = u16(bytes, p)
  model.rootScale, p = f32(bytes, p)
  local static
  static, p = u8(bytes, p)
  model.staticPose = static ~= 0
  model.height, p = f32(bytes, p)
  model.floor, p = f32(bytes, p)
  model.radius, p = f32(bytes, p)

  model.moveAnim, model.moveAux = {}, {}
  for i = 1, MOVE_SLOTS do model.moveAnim[i], p = u16(bytes, p) end
  for i = 1, MOVE_SLOTS do model.moveAux[i], p = i16(bytes, p) end
  model.ctx = {}
  for i = 1, CONTEXT_SLOTS do model.ctx[i], p = u16(bytes, p) end

  model.parent, model.restT, model.restR, model.restS = {}, {}, {}, {}
  for bone = 1, model.boneCount do
    local parent
    parent, p = i16(bytes, p)
    model.parent[bone] = parent + 1
    local o = (bone - 1) * 3
    model.restT[o + 1], p = i16(bytes, p)
    model.restT[o + 2], p = i16(bytes, p)
    model.restT[o + 3], p = i16(bytes, p)
    model.restR[o + 1], p = i16(bytes, p)
    model.restR[o + 2], p = i16(bytes, p)
    model.restR[o + 3], p = i16(bytes, p)
    model.restS[o + 1], p = fixed(bytes, p)
    model.restS[o + 2], p = fixed(bytes, p)
    model.restS[o + 3], p = fixed(bytes, p)
  end

  model.attachments = {}
  for i = 1, model.attachmentCount do
    local bone, tag
    bone, p = i16(bytes, p)
    tag, p = i16(bytes, p)
    model.attachments[i] = { bone = bone + 1, tag = tag }
  end

  model.prims = {}
  for i = 1, model.primCount do
    local prim = {}
    prim.tex, p = u16(bytes, p); prim.tex = prim.tex + 1
    local cull, additive
    cull, p = u8(bytes, p); additive, p = u8(bytes, p)
    prim.cull, prim.additive = cull ~= 0, additive ~= 0
    prim.texAnim, p = i16(bytes, p)

    local mapCount
    mapCount, p = u8(bytes, p)
    if mapCount > 0 then
      prim.texMap = {}
      for _ = 1, mapCount do
        local key, texture
        key, p = u8(bytes, p); texture, p = u16(bytes, p)
        prim.texMap[key] = texture + 1
      end
    end

    local fxCount
    fxCount, p = u16(bytes, p)
    if fxCount > 0 then
      prim.fxFrames = {}
      for f = 1, fxCount do
        prim.fxFrames[f], p = u16(bytes, p)
        prim.fxFrames[f] = prim.fxFrames[f] + 1
      end
    end

    prim.vertCount, p = u16(bytes, p)
    prim.indexCount, p = u16(bytes, p)
    prim.px, prim.py, prim.pz = {}, {}, {}
    prim.uv = {}
    prim.nx, prim.ny, prim.nz = {}, {}, {}
    prim.bone = {}
    for vertex = 1, prim.vertCount do
      prim.px[vertex], p = i16(bytes, p)
      prim.py[vertex], p = i16(bytes, p)
      prim.pz[vertex], p = i16(bytes, p)
      local uu, vv
      uu, p = i16(bytes, p); vv, p = i16(bytes, p)
      prim.uv[vertex * 2 - 1], prim.uv[vertex * 2] = uu / 512, vv / 512
      local nx, ny, nz
      nx, p = u8(bytes, p); ny, p = u8(bytes, p); nz, p = u8(bytes, p)
      if nx >= 128 then nx = nx - 256 end
      if ny >= 128 then ny = ny - 256 end
      if nz >= 128 then nz = nz - 256 end
      prim.nx[vertex], prim.ny[vertex], prim.nz[vertex] = nx / 127, ny / 127, nz / 127
      local bone
      bone, p = u8(bytes, p)
      prim.bone[vertex] = bone + 1
    end
    prim.index = {}
    for index = 1, prim.indexCount do
      prim.index[index], p = u16(bytes, p)
      prim.index[index] = prim.index[index] + 1
    end
    model.prims[i] = prim
  end

  model.textures = {}
  for i = 1, model.texCount do
    local w, h, length
    w, p = u16(bytes, p); h, p = u16(bytes, p); length, p = u32(bytes, p)
    if p + length - 1 > #bytes then error("invalid DSM4 texture payload", 0) end
    model.textures[i] = { w = w, h = h, rgba = bytes:sub(p, p + length - 1) }
    p = p + length
  end

  model.anims = {}
  for i = 1, model.animCount do
    local nameLen
    nameLen, p = u8(bytes, p)
    local name = bytes:sub(p, p + nameLen - 1)
    p = p + nameLen
    local frames, loopStart, aux
    frames, p = u16(bytes, p); loopStart, p = u16(bytes, p); aux, p = i16(bytes, p)
    local record = {
      name = name,
      frames = math.max(1, frames),
      loopStart = loopStart,
      aux = aux >= 0 and (aux + 1) or nil,
      offset = p,
    }
    model.anims[i] = record
    p = skipTracks(bytes, p, model.boneCount, record.frames)
  end

  model.auxAnims = {}
  for i = 1, model.auxCount do
    local frames, loopStart, channelCount
    frames, p = u16(bytes, p); loopStart, p = u16(bytes, p); channelCount, p = u16(bytes, p)
    local aux = { frames = frames, loopStart = loopStart, channels = {} }
    for channel = 1, channelCount do
      local count
      count, p = u16(bytes, p)
      local stream = {}
      for index = 1, count do stream[index], p = u16(bytes, p) end
      aux.channels[channel] = stream
    end
    model.auxAnims[i] = aux
  end
  return model
end

local function key(dex, shiny)
  return tostring(dex) .. (shiny and ":s" or ":n")
end

local function path(dex, shiny)
  local root = shiny and SHINY_DIR or NORMAL_DIR
  return string.format("%s/%03d.dsm", root, dex)
end

local function touch(k)
  for i = #order, 1, -1 do if order[i] == k then table.remove(order, i) end end
  order[#order + 1] = k
  while #order > MAX_CACHE do
    local old = table.remove(order, 1)
    cache[old] = nil
  end
end

function Stadium2Pack.available(dex, shiny)
  dex = math.floor(tonumber(dex) or 0)
  return dex >= 1 and dex <= 251 and fsInfo(path(dex, shiny == true)) ~= nil
end

function Stadium2Pack.load(dex, shiny)
  dex = math.floor(tonumber(dex) or 0)
  if dex < 1 or dex > 251 then return nil end
  local k = key(dex, shiny == true)
  if cache[k] then touch(k); return cache[k] end
  if failed[k] then return nil end
  local bytes = read(path(dex, shiny == true))
  if not bytes and shiny then bytes = read(path(dex, false)) end
  if not bytes then failed[k] = true; return nil end
  local ok, model = pcall(parse, bytes)
  if not ok or not model then failed[k] = true; return nil end
  cache[k] = model
  touch(k)
  return model
end

function Stadium2Pack.marker()
  local text = read(MARKER)
  if not text then return nil end
  local format, count, variants, hash = text:match("^(%S+)%s+(%d+)%s+(%d+)%s*(%S*)")
  if not format then return nil end
  return { format = format, count = tonumber(count), variants = tonumber(variants), md5 = hash ~= "" and hash or nil }
end

function Stadium2Pack.clear()
  cache, order, failed = {}, {}, {}
end

return Stadium2Pack
