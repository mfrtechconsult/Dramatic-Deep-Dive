local Json = require("src.link.Json")
local Assets = require("src.render.Assets")
local SpriteRenderer = require("src.render.SpriteRenderer")

local FollowerSprites = {}
FollowerSprites.__index = FollowerSprites

local PROVIDER_IDS = {
  PokePCFollowers_VoxelMerge = true,
  pokepcfollowers = true,
  FOLLOWERS_EX = true,
  followers_ex = true,
}

local function fileExists(path)
  return love and love.filesystem and love.filesystem.getInfo
    and love.filesystem.getInfo(path) ~= nil
end

local function setNearest(image)
  if image and image.setFilter then image:setFilter("nearest", "nearest") end
end

function FollowerSprites.new(mod)
  return setmetatable({ mod = mod, cache = {} }, FollowerSprites)
end

function FollowerSprites:pathForDex(dex)
  dex = tonumber(dex)
  if not dex then return nil end
  local filename = string.format("follower_%03d.png", dex)

  if love and love.filesystem and love.filesystem.getDirectoryItems then
    local ok, names = pcall(love.filesystem.getDirectoryItems, "mods")
    if ok and type(names) == "table" then
      local fallback = nil
      for _, name in ipairs(names) do
        local root = "mods/" .. name
        local asset = root .. "/assets/sprites/" .. filename
        if fileExists(asset) then
          local raw = love.filesystem.read(root .. "/manifest.json")
          local decoded = raw and Json.decode(raw) or nil
          if decoded and PROVIDER_IDS[decoded.id] then return asset end
          fallback = fallback or asset
        end
      end
      if fallback then return fallback end
    end
  end

  local roots = {
    "mods/PokePCFollowers_VoxelMerge/assets/sprites/",
    "mods/pokepcfollowers/assets/sprites/",
    "mods/PokePCFollowers/assets/sprites/",
  }
  for _, root in ipairs(roots) do
    local candidate = root .. filename
    if fileExists(candidate) then return candidate end
  end
  return nil
end

function FollowerSprites:build(species, dex)
  local key = tostring(species) .. ":" .. tostring(dex)
  if self.cache[key] then return self.cache[key] end

  local path = self:pathForDex(dex)
  if not path then return nil, "missing follower asset" end
  local ok, image = pcall(Assets.image, path)
  if not ok or not image then return nil, "failed to load follower asset" end
  setNearest(image)

  local width, height = image:getDimensions()
  if width < 16 or height < 96 then return nil, "unexpected follower sheet size" end

  local def = {
    id = "DEEP_DIVE_" .. tostring(species),
    image = path,
    frames = 6,
    walker = true,
    trueColor = true,
  }
  local sprite = SpriteRenderer.new(def, "deep_dive_" .. tostring(species))
  sprite.image = image
  self.cache[key] = sprite
  return sprite
end

return FollowerSprites
