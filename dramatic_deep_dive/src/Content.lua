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

local function contains(list, value)
  for _, entry in ipairs(list or {}) do
    local id = type(entry) == "table" and entry.id or entry
    if id == value then return true end
  end
  return false
end

local function appendUnique(list, value)
  local out = {}
  for _, entry in ipairs(list or {}) do out[#out + 1] = entry end
  if not contains(out, value) then out[#out + 1] = value end
  return out
end

local function registerMapDefinition(mod, spec)
  local map, mapError = loadLua(mod, spec.file)
  if not map then
    mod.log:error("Could not load underwater map %s: %s", tostring(spec.file), tostring(mapError))
    return nil
  end
  if not mod.content.maps:get(map.id) then mod.content.maps:register(map.id, map) end
  if spec.song then mod.content.map_songs:register(map.id, spec.song) end
  if spec.encounters then mod.content.encounters:register(map.id, spec.encounters) end
  return map
end

-- Independent, idempotent public contract. Deep Dive provides DIVE/HM_DIVE
-- itself and only reuses an already-registered generic record when present.
function Content.ensureDiveContract(mod)
  local existingMove = mod.content.moves:get("DIVE")
  if not existingMove then
    local surf = mod.content.moves:get("SURF")
    local dive = {
      id = "DIVE", name = "DIVE", type = "WATER",
      power = 60, accuracy = 100, pp = 10,
      effect = "NO_ADDITIONAL_EFFECT", category = "special",
    }
    if surf and surf.anim ~= nil then dive.anim = surf.anim end
    mod.content.moves:register("DIVE", dive)
  end

  local existingItem = mod.content.items:get("HM_DIVE")
  if existingItem then
    local machine = existingItem.machine
    if not (machine and machine.kind == "HM" and machine.move == "DIVE") then
      mod.log:error("HM_DIVE exists but does not teach DIVE")
      return nil
    end
    -- The stable item/move ids are authoritative. Numerical HM slot is only
    -- presentation, and the canonical presentation is HM08.
    if existingItem.name ~= "HM08" or tonumber(machine.number) ~= 8 then
      mod.content.items:patch("HM_DIVE", { name = "HM08", machine = { number = 8 } })
    end
  else
    mod.content.items:register("HM_DIVE", {
      id = "HM_DIVE", name = "HM08", price = 0,
      machine = { kind = "HM", move = "DIVE", number = 8 },
      tossable = false, keyItem = true,
    })
  end

  local hmMoves = mod.content.constants:get("hmMoves") or {}
  mod.content.constants:override("hmMoves", appendUnique(hmMoves, "DIVE"))
  return true
end

function Content.register(mod)
  if not Content.ensureDiveContract(mod) then return nil end

  local compatibility, compatibilityError = loadLua(mod, "data/compatibility.lua")
  if not compatibility then
    mod.log:error("Could not load DIVE compatibility: %s", tostring(compatibilityError))
    return nil
  end
  for _, speciesId in ipairs(compatibility) do
    local species = mod.content.pokemon:get(speciesId)
    if species and not contains(species.tmhm, "DIVE") then
      -- Additive list merge: never replace another mod's complete TM/HM list.
      mod.content.pokemon:patch(speciesId, { tmhm = { __append = { "DIVE" } } })
    end
  end

  local blocks = {
    uniform(0), uniform(1), uniform(2),
    { 0,3,0,0, 0,0,0,3, 3,0,0,0, 0,0,3,0 },
    { 0,7,0,0, 0,0,7,0, 0,0,0,7, 0,0,0,0 },
    uniform(4), uniform(5),
    { 2,2,2,2, 6,6,2,2, 0,0,0,0, 0,0,0,0 },
    uniform(8), uniform(9), uniform(10), uniform(11),
    uniform(12), uniform(13), uniform(14), uniform(15),
  }

  if not mod.content.tilesets:get("DDD_UNDERWATER") then
    mod.content.tilesets:register("DDD_UNDERWATER", {
      id = "DDD_UNDERWATER",
      image = mod.assets:path("assets/tilesets/deep_dive_underwater.png"),
      imageWidth = 64, imageHeight = 32, tilesPerRow = 8,
      blocks = blocks, walkable = {}, warpTiles = { 6 },
      waterTiles = { 0, 1, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14 },
      shoreTiles = {}, grassTile = 8, trueColor = true,
    })
  end

  -- Deep Dive owns and registers its complete DDD_* underwater content.
  local maps, mapsError = loadLua(mod, "data/maps.lua")
  if not maps then
    mod.log:error("Could not load underwater map registry: %s", tostring(mapsError))
    return nil
  end
  for _, spec in ipairs(maps) do
    if not registerMapDefinition(mod, spec) then return nil end
  end
  return true
end

return Content
