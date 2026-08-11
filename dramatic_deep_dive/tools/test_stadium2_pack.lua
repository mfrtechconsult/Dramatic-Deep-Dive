package.path = "dramatic_deep_dive/?.lua;dramatic_deep_dive/?/init.lua;" .. package.path

local function u16(v) return string.pack("<I2", v) end
local function i16(v) return string.pack("<i2", v) end
local function i32(v) return string.pack("<i4", v) end
local function f32(v) return string.pack("<f", v) end
local function u8(v) return string.char(v) end

local out = { "DSM4" }
out[#out + 1] = u16(6)      -- Charizard dex, arbitrary test species
out[#out + 1] = u16(1)      -- bones
out[#out + 1] = u16(0)      -- prims
out[#out + 1] = u16(0)      -- textures
out[#out + 1] = u16(1)      -- animations
out[#out + 1] = u16(0)      -- aux animations
out[#out + 1] = u16(0)      -- attachments
out[#out + 1] = f32(1.0)    -- root scale
out[#out + 1] = u8(0)       -- staticPose=false
out[#out + 1] = f32(42.0)   -- height
out[#out + 1] = f32(0.0)    -- floor
out[#out + 1] = f32(12.0)   -- radius
for _ = 1, 165 do out[#out + 1] = u16(0xFFFF) end
for _ = 1, 165 do out[#out + 1] = i16(-1) end
out[#out + 1] = u16(0)      -- idle context -> animation #1 (zero based)
for _ = 2, 20 do out[#out + 1] = u16(0xFFFF) end
out[#out + 1] = i16(-1)     -- root bone
for _ = 1, 6 do out[#out + 1] = i16(0) end
for _ = 1, 3 do out[#out + 1] = i32(65536) end
out[#out + 1] = u8(4) .. "idle" .. u16(2) .. u16(0) .. i16(-1)
out[#out + 1] = u8(1)       -- bone track present
out[#out + 1] = u8(1) .. i16(0) .. i16(3) -- dynamic TX
for _ = 2, 6 do out[#out + 1] = u8(0) .. i16(0) end
for _ = 7, 9 do out[#out + 1] = u8(0) .. i32(65536) end
local bytes = table.concat(out)

love = {
  filesystem = {
    getInfo = function(path, kind)
      if path == "crystal_251/stadium2/normal/006.dsm" then return { type = "file" } end
      if path == "crystal_251/stadium2/pack.info" then return { type = "file" } end
      return nil
    end,
    read = function(path)
      if path == "crystal_251/stadium2/normal/006.dsm" then return bytes end
      if path == "crystal_251/stadium2/pack.info" then return "C2DSM10 251 2 deadbeef" end
      error("unexpected read: " .. tostring(path))
    end,
  },
}

local Pack = dofile("dramatic_deep_dive/src/Stadium2Pack.lua")
assert(Pack.available(6, false), "normal DSM4 pack must be discoverable")
assert(not Pack.available(0, false), "invalid dex must be rejected")
local model = assert(Pack.load(6, false), "synthetic DSM4 pack must parse")
assert(model.species == 6 and model.boneCount == 1, "header parse failed")
assert(model.animCount == 1 and model.anims[1].frames == 2, "animation scan failed")
assert(model.ctx[1] == 0, "idle context was not preserved")
assert(model.rootScale > 0.99 and model.rootScale < 1.01, "float parse failed")
local marker = assert(Pack.marker(), "pack marker must parse")
assert(marker.format == "C2DSM10" and marker.count == 251 and marker.variants == 2,
  "marker contract failed")
print("Stadium 2 DSM4 underwater pack contract OK")
