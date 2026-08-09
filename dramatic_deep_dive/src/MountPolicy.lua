local MountPolicy = {}

local GEN2 = {
  TOTODILE = false,
  CROCONAW = true,
  FERALIGATR = true,
  CHINCHOU = false,
  LANTURN = true,
  MARILL = false,
  AZUMARILL = true,
  POLITOED = true,
  WOOPER = false,
  QUAGSIRE = true,
  SLOWKING = true,
  QWILFISH = false,
  REMORAID = false,
  OCTILLERY = false,
  MANTINE = true,
  KINGDRA = true,
  SUICUNE = true,
  LUGIA = true,
}

function MountPolicy.isSuitable(speciesId, speciesDef)
  if GEN2[speciesId] ~= nil then return GEN2[speciesId] end
  local dex = speciesDef and tonumber(speciesDef.dex)
  if dex and dex <= 151 then return true end
  return false
end

function MountPolicy.isExplicitGen2Mount(speciesId)
  return GEN2[speciesId] == true
end

MountPolicy.gen2 = GEN2
return MountPolicy
