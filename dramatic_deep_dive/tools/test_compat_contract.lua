local ROOT = arg[1] or "dramatic_deep_dive/"
local total, failed = 0, 0
local function check(v,label)
  total=total+1
  if v then print("[PASS] "..label) else failed=failed+1; io.stderr:write("[FAIL] "..label.."\n") end
end

local function registry(seed)
  local r={data=seed or {},patches={}}
  function r:get(id) return self.data[id] end
  function r:register(id,v) self.data[id]=v return v end
  function r:patch(id,p)
    self.patches[#self.patches+1]={id=id,patch=p}
    local cur=self.data[id] or {}; self.data[id]=cur
    for k,v in pairs(p) do
      if type(v)=="table" and type(cur[k])=="table" and v.number then
        for kk,vv in pairs(v) do cur[k][kk]=vv end
      else cur[k]=v end
    end
    return cur
  end
  function r:override(id,v) self.data[id]=v return v end
  return r
end

local Content=dofile(ROOT.."src/Content.lua")
local Crystal=dofile(ROOT.."src/Crystal251Compat.lua")
local MountPolicy=dofile(ROOT.."src/MountPolicy.lua")

local function baseMod(opts)
  opts=opts or {}
  local pokemon={}
  for _,id in ipairs(Crystal.species) do pokemon[id]={id=id,dex=opts.dex and opts.dex[id] or 200,tmhm={"SURF"}} end
  local m={
    content={
      moves=registry({SURF={id="SURF",anim=7}}),
      items=registry(), constants=registry({hmMoves={"CUT","FLY","SURF","STRENGTH","FLASH"}}),
      pokemon=registry(pokemon), maps=registry(), map_songs=registry(), encounters=registry(), tilesets=registry(),
    },
    find=function(_,id) if id=="CRYSTAL_251" and opts.crystal then return {id=id,exports={}} end end,
    log={info=function() end,warn=function() end,error=function() end},
  }
  return m
end

do
  local mod=baseMod()
  check(Content.ensureDiveContract(mod)==true,"standalone DIVE contract installs")
  local hm=mod.content.items:get("HM_DIVE")
  check(hm and hm.name=="HM08","standalone item is HM08")
  check(hm.machine.kind=="HM" and hm.machine.move=="DIVE" and hm.machine.number==8,"HM08 teaches DIVE")
  check(mod.content.moves:get("DIVE")~=nil,"standalone DIVE move exists")
end

do
  local mod=baseMod()
  local existing={id="HM_DIVE",name="HM08",machine={kind="HM",move="DIVE",number=8}}
  mod.content.items.data.HM_DIVE=existing
  Content.ensureDiveContract(mod)
  check(mod.content.items:get("HM_DIVE")==existing,"existing generic HM_DIVE record is reused")
  check(#mod.content.items.patches==0,"canonical existing HM08 needs no rewrite")
end

do
  local mod=baseMod()
  mod.content.items.data.HM_DIVE={id="HM_DIVE",name="OLD",machine={kind="HM",move="DIVE",number=1}}
  Content.ensureDiveContract(mod)
  local hm=mod.content.items:get("HM_DIVE")
  check(hm.id=="HM_DIVE" and hm.machine.move=="DIVE","stable HM_DIVE/DIVE ids survive normalization")
  check(hm.name=="HM08" and hm.machine.number==8,"presentation normalizes to HM08")
end

do
  local mod=baseMod({crystal=false})
  local r=Crystal.install(mod)
  check(r.installed==false and #r.patched==0,"Crystal compatibility is inert when Crystal is absent")
end

do
  local mod=baseMod({crystal=true})
  local r=Crystal.install(mod)
  check(r.installed==true,"Crystal compatibility activates when installed")
  local wanted={TOTODILE=true,KINGDRA=true,LUGIA=true}
  local seen={}
  for _,p in ipairs(mod.content.pokemon.patches) do
    if wanted[p.id] then
      local a=p.patch.tmhm and p.patch.tmhm.__append
      if a and a[1]=="DIVE" then seen[p.id]=true end
    end
  end
  check(seen.TOTODILE,"Totodile receives additive DIVE compatibility")
  check(seen.KINGDRA,"Kingdra receives additive DIVE compatibility")
  check(seen.LUGIA,"Lugia receives additive DIVE compatibility")
end

do
  check(MountPolicy.isExplicitGen2Mount("FERALIGATR"),"Feraligatr is a suitable mount")
  check(MountPolicy.isExplicitGen2Mount("KINGDRA"),"Kingdra is a suitable mount")
  check(MountPolicy.isExplicitGen2Mount("LUGIA"),"Lugia is a suitable mount")
  check(not MountPolicy.isExplicitGen2Mount("TOTODILE"),"Totodile can learn DIVE without becoming a mount")
  check(not MountPolicy.isExplicitGen2Mount("REMORAID"),"Remoraid can learn DIVE without becoming a mount")
end

do
  local f=assert(io.open(ROOT.."main.lua","rb")); local s=f:read("*a"); f:close()
  check(s:find("DiveTravel.new",1,true)~=nil,"bootstrap installs native DiveTravel")
  check(s:find("Progression.install",1,true)~=nil,"bootstrap installs native progression")
  check(s:find("DepthEncounters.new",1,true)~=nil,"bootstrap installs native depth ecology")
end

if failed>0 then io.stderr:write(string.format("compat contract: %d/%d failed\n",failed,total)); os.exit(1) end
print(string.format("compat contract: %d checks passed",total))
