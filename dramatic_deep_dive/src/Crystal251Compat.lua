local Crystal251Compat = {}

local SPECIES = {
  "TOTODILE", "CROCONAW", "FERALIGATR",
  "CHINCHOU", "LANTURN",
  "MARILL", "AZUMARILL",
  "POLITOED", "WOOPER", "QUAGSIRE", "SLOWKING", "QWILFISH",
  "REMORAID", "OCTILLERY", "MANTINE", "KINGDRA", "SUICUNE", "LUGIA",
}

local function contains(list, value)
  for _, entry in ipairs(list or {}) do
    local id = type(entry) == "table" and entry.id or entry
    if id == value then return true end
  end
  return false
end

local function crystalInstalled(mod)
  if not mod.find then return false end
  local ok, handle = pcall(mod.find, mod, "CRYSTAL_251")
  return ok and handle ~= nil
end

function Crystal251Compat.install(mod)
  if not crystalInstalled(mod) then return { installed = false, patched = {} } end

  local patched = {}
  for _, speciesId in ipairs(SPECIES) do
    local species = mod.content.pokemon:get(speciesId)
    if species and not contains(species.tmhm, "DIVE") then
      mod.content.pokemon:patch(speciesId, {
        tmhm = { __append = { "DIVE" } },
      })
      patched[#patched + 1] = speciesId
    end
  end

  if #patched > 0 and mod.log then
    mod.log:info("Added Crystal 251 DIVE compatibility for %d imported species", #patched)
  end
  return { installed = true, patched = patched }
end

Crystal251Compat.species = SPECIES
return Crystal251Compat
