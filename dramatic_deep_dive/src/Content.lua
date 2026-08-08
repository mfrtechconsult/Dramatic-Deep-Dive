local Content = {}

local function uniform(tile)
  local row = {}
  for i = 1, 16 do row[i] = tile end
  return row
end

local function loadLua(mod, relativePath)
  local source, readError = mod:read(relativePath)
  if not source then return nil, readError end
  local compiler = loadstring or load
  local chunk, compileError = compiler(source, "@" .. mod.path .. "/" .. relativePath)
  if not chunk then return nil, compileError end
  local ok, value = pcall(chunk)
  if not ok then return nil, value end
  return value
end

local function appendUnique(list, value)
  local out, found = {}, false
  for _, entry in ipairs(list or {}) do
    out[#out + 1] = entry
    if entry == value then found = true end
  end
  if not found then out[#out + 1] = value end
  return out
end

function Content.register(mod)
  local surf = mod.content.moves:get("SURF")
  local dive = {
    id = "DIVE",
    name = "DIVE",
    type = "WATER",
    power = 60,
    accuracy = 100,
    pp = 10,
    effect = "NO_ADDITIONAL_EFFECT",
    category = "special",
  }
  if surf and surf.anim ~= nil then dive.anim = surf.anim end
  if mod.content.moves:get("DIVE") then
    mod.content.moves:patch("DIVE", dive)
  else
    mod.content.moves:register("DIVE", dive)
  end

  local hm = {
    id = "HM_DIVE",
    name = "HM06",
    price = 0,
    machine = { kind = "HM", move = "DIVE", number = 6 },
    tossable = false,
    keyItem = true,
  }
  if mod.content.items:get("HM_DIVE") then
    mod.content.items:patch("HM_DIVE", hm)
  else
    mod.content.items:register("HM_DIVE", hm)
  end

  local hmMoves = mod.content.constants:get("hmMoves") or {}
  mod.content.constants:override("hmMoves", appendUnique(hmMoves, "DIVE"))

  local compatibility, compatibilityError = loadLua(mod, "data/compatibility.lua")
  if not compatibility then
    mod.log:error("Could not load DIVE compatibility: %s", tostring(compatibilityError))
    return nil
  end
  for _, speciesId in ipairs(compatibility) do
    local species = mod.content.pokemon:get(speciesId)
    if species then
      mod.content.pokemon:patch(speciesId, {
        tmhm = appendUnique(species.tmhm or {}, "DIVE"),
      })
    end
  end

  -- The first standalone tileset is copied from the proven Kanto Dive art,
  -- but receives a DDD-owned id so Kanto Dive is no longer needed at runtime.
  local blocks = {
    uniform(0),
    uniform(1),
    uniform(2),
    { 0,3,0,0, 0,0,0,3, 3,0,0,0, 0,0,3,0 },
    { 0,7,0,0, 0,0,7,0, 0,0,0,7, 0,0,0,0 },
    uniform(4),
    uniform(5),
    { 2,2,2,2, 6,6,2,2, 0,0,0,0, 0,0,0,0 },
    uniform(8),
    uniform(9),
    uniform(10),
    uniform(11),
    uniform(12),
    uniform(13),
    uniform(14),
    uniform(15),
  }

  if not mod.content.tilesets:get("DDD_UNDERWATER") then
    mod.content.tilesets:register("DDD_UNDERWATER", {
      id = "DDD_UNDERWATER",
      image = mod.assets:path("assets/tilesets/deep_dive_underwater.png"),
      imageWidth = 64,
      imageHeight = 32,
      tilesPerRow = 8,
      blocks = blocks,
      walkable = {},
      warpTiles = { 6 },
      waterTiles = { 0, 1, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14 },
      shoreTiles = {},
      grassTile = 8,
      trueColor = true,
    })
  end

  local map, mapError = loadLua(mod, "maps/DDD_ROUTE21_ABYSS.lua")
  if not map then
    mod.log:error("Could not load Route 21 abyss map: %s", tostring(mapError))
    return nil
  end
  if not mod.content.maps:get(map.id) then mod.content.maps:register(map.id, map) end
  mod.content.map_songs:register(map.id, "Music_Dungeon2")
  mod.content.encounters:register(map.id, {
    grass = { rate = 24, slots = {
      { level = 27, species = "TENTACOOL" },
      { level = 27, species = "HORSEA" },
      { level = 28, species = "STARYU" },
      { level = 29, species = "SHELLDER" },
      { level = 29, species = "TENTACOOL" },
      { level = 30, species = "HORSEA" },
      { level = 30, species = "STARYU" },
      { level = 31, species = "SEADRA" },
      { level = 31, species = "TENTACRUEL" },
      { level = 33, species = "GYARADOS" },
    } },
  })

  return true
end

return Content
