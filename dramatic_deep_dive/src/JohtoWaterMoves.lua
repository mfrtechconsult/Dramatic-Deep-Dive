local JohtoWaterMoves = {}
local Service = {}
Service.__index = Service

local CELL = 16

local WHIRLPOOL_GEN1 = {
  "SQUIRTLE", "WARTORTLE", "BLASTOISE", "PSYDUCK", "GOLDUCK",
  "POLIWAG", "POLIWHIRL", "POLIWRATH", "TENTACOOL", "TENTACRUEL",
  "SEEL", "DEWGONG", "SHELLDER", "CLOYSTER", "KRABBY", "KINGLER",
  "HORSEA", "SEADRA", "STARYU", "STARMIE", "GYARADOS", "LAPRAS",
  "VAPOREON", "OMANYTE", "OMASTAR", "KABUTOPS", "DRAGONITE", "MEW",
}
local WATERFALL_GEN1 = {
  "SQUIRTLE", "WARTORTLE", "BLASTOISE", "PSYDUCK", "GOLDUCK",
  "POLIWAG", "POLIWHIRL", "POLIWRATH", "SEEL", "DEWGONG",
  "GOLDEEN", "SEAKING", "HORSEA", "SEADRA", "STARYU", "STARMIE",
  "GYARADOS", "VAPOREON", "DRATINI", "DRAGONAIR", "DRAGONITE", "MEW",
}

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
local function findOptionalMod(mod, id)
  if not (mod and type(mod.find) == "function") then return nil end
  local ok, handle = pcall(function() return mod.find(id) end)
  if ok and handle then return handle end
  ok, handle = pcall(function() return mod:find(id) end)
  if ok then return handle end
  return nil
end
local function crystalInstalled(mod) return findOptionalMod(mod, "CRYSTAL_251") ~= nil end
local function ensureMove(mod, id, def)
  local existing = mod.content.moves:get(id)
  if existing then return existing end
  local surf = mod.content.moves:get("SURF")
  if surf and surf.anim ~= nil then def.anim = surf.anim end
  mod.content.moves:register(id, def)
  return mod.content.moves:get(id)
end
local function ensureMachine(mod, id, number, move)
  local existing = mod.content.items:get(id)
  if existing then
    local machine = existing.machine
    if not (machine and machine.kind == "HM" and machine.move == move) then
      mod.log:error("%s already exists but does not teach %s", id, move)
      return nil
    end
    return existing
  end
  mod.content.items:register(id, {
    id=id, name=("HM%02d"):format(number), price=0, tossable=false,
    needsTarget=true, machine={ kind="HM", move=move, number=number },
  })
  return mod.content.items:get(id)
end
local function patchCompatibility(mod, moveId, speciesIds)
  local patched = 0
  for _, speciesId in ipairs(speciesIds) do
    local species = mod.content.pokemon:get(speciesId)
    if species and not contains(species.tmhm, moveId) then
      mod.content.pokemon:patch(speciesId, { tmhm={ __append={ moveId } } })
      patched = patched + 1
    end
  end
  return patched
end
local function mapHasObject(map, name)
  for _, object in ipairs(map and map.objects or {}) do
    if object.name == name then return true end
  end
  return false
end
local function nextObjectIndex(map)
  local highest = 0
  for _, object in ipairs(map and map.objects or {}) do
    highest = math.max(highest, tonumber(object.index) or 0)
  end
  return highest + 1
end
local function installStandaloneAcquisition(mod)
  if crystalInstalled(mod) then return false end
  local specs = {
    { mapId="ROCKET_HIDEOUT_B4F", x=27, y=7, item="HM_06",
      name="JOHTO_WATER_HM06", text="TEXT_JOHTO_WATER_HM06" },
    { mapId="SEAFOAM_ISLANDS_B4F", x=9, y=2, item="HM_07",
      name="JOHTO_WATER_HM07", text="TEXT_JOHTO_WATER_HM07" },
  }
  for _, spec in ipairs(specs) do
    local map = mod.content.maps:get(spec.mapId)
    if map and not mapHasObject(map, spec.name) then
      mod.content.maps:patch(spec.mapId, { objects={ __append={ {
        index=nextObjectIndex(map), x=spec.x, y=spec.y,
        sprite="SPRITE_POKE_BALL", movement="STAY", range="NONE",
        item=spec.item, text=spec.text, name=spec.name,
      } } } })
    end
  end
  return true
end

local function rectContains(f, x, y)
  return x >= f.x and x < f.x + f.width and y >= f.y and y < f.y + f.height
end
local DELTA = { up={0,-1}, down={0,1}, left={-1,0}, right={1,0} }
local function monKnows(mon, moveId)
  for _, move in ipairs(mon and mon.moves or {}) do
    local id = type(move) == "table" and move.id or move
    if id == moveId then return true end
  end
  return false
end
local function alreadyHas(items, label)
  for _, item in ipairs(items or {}) do if item.label == label then return true end end
  return false
end
local function insertBeforeStats(items, item)
  local index = #items + 1
  for i, existing in ipairs(items) do if existing.label == "STATS" then index=i break end end
  table.insert(items, index, item)
end
local function normalizeFeature(kind, def)
  assert(type(def)=="table" and type(def.mapId)=="string", kind .. " feature requires mapId")
  assert(type(def.x)=="number" and type(def.y)=="number", kind .. " feature requires x/y")
  return {
    id=def.id or (kind:lower().."_"..def.mapId.."_"..def.x.."_"..def.y),
    kind=kind, mapId=def.mapId, x=def.x, y=def.y,
    width=math.max(1, tonumber(def.width) or 1),
    height=math.max(1, tonumber(def.height) or 1),
  }
end

function Service.new(mod, config)
  config=config or {}
  local self=setmetatable({ mod=mod, config=config,
    features={WHIRLPOOL={}, WATERFALL={}}, cleared={} }, Service)
  for _,d in ipairs(config.whirlpools or {}) do self:registerWhirlpool(d) end
  for _,d in ipairs(config.waterfalls or {}) do self:registerWaterfall(d) end
  return self
end
function Service:registerWhirlpool(def)
  local f=normalizeFeature("WHIRLPOOL",def); self.features.WHIRLPOOL[#self.features.WHIRLPOOL+1]=f; return f
end
function Service:registerWaterfall(def)
  local f=normalizeFeature("WATERFALL",def); self.features.WATERFALL[#self.features.WATERFALL+1]=f; return f
end
function Service:current(game)
  local ow=game and game.overworld; local p=ow and ow.player; local map=ow and ow.map
  if not (p and map) then return nil end
  return { mapId=map.id, x=p.cellX, y=p.cellY, facing=p.facing or "down", surfing=p.surfing==true }
end
function Service:hasBadge(game,badge)
  if not badge then return true end
  local inv=game and game.save and game.save.inventory
  return inv and inv[badge] ~= nil and inv[badge] ~= false
end
function Service:isCleared(f)
  local map=self.cleared[f.mapId]; return map and map[f.id]==true or false
end
function Service:setCleared(f,value)
  local map=self.cleared[f.mapId] or {}; self.cleared[f.mapId]=map; map[f.id]=value and true or nil
end
function Service:featureAt(kind,mapId,x,y)
  for _,f in ipairs(self.features[kind] or {}) do
    if f.mapId==mapId and rectContains(f,x,y) and (kind~="WHIRLPOOL" or not self:isCleared(f)) then return f end
  end
  return nil
end
function Service:facingFeature(game,kind)
  local p=self:current(game); if not (p and p.surfing) then return nil end
  local d=DELTA[p.facing]; if not d then return nil end
  local f=self:featureAt(kind,p.mapId,p.x+d[1],p.y+d[2]); if not f then return nil end
  if kind=="WATERFALL" and (p.facing~="up" or p.y~=f.y+f.height) then return nil end
  return f
end
function Service:blocksMove(player,dir,map)
  if not (player and player.surfing and map and map.id) then return nil end
  if player.moving or player.inputLocked or player.facing~=dir or (player.turnTimer and player.turnTimer>0) then return nil end
  local d=DELTA[dir]; if not d then return nil end
  local x,y=player.cellX+d[1],player.cellY+d[2]
  if self:featureAt("WHIRLPOOL",map.id,x,y) then return "whirlpool" end
  if self:featureAt("WATERFALL",map.id,x,y) and dir~="down" then return "waterfall" end
  return nil
end
function Service:closePartyMenu(game)
  local stack=game and game.stack; local top=stack and stack.top and stack:top()
  if top and type(top.close)=="function" then top:close() elseif top and stack and stack.pop then stack:pop() end
end
function Service:displayName(game,mon)
  if mon and mon.nickname and mon.nickname~="" then return mon.nickname end
  local species=mon and game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
  return species and species.name or "POKEMON"
end
function Service:showText(game,text,onDone)
  if not (game and game.stack and self.mod.ui and self.mod.ui.TextBox) then if onDone then onDone() end return end
  game.stack:push(self.mod.ui.TextBox.new(game,text,onDone))
end
function Service:beginWhirlpool(mon,game,f)
  self:closePartyMenu(game)
  self:showText(game,self:displayName(game,mon).." used WHIRLPOOL!",function()
    self:setCleared(f,true)
    self.mod.events:emit("mod.johto_water.whirlpool_cleared",{owner=self.mod.id,mapId=f.mapId,id=f.id})
  end)
end
function Service:beginWaterfall(mon,game,f)
  local p=self:current(game); if not p then return end
  self:closePartyMenu(game)
  self:showText(game,self:displayName(game,mon).." used WATERFALL!",function()
    local ok,err=self.mod.world:warpTo(p.mapId,p.x,f.y-1,"up",{onDone=function()
      local ow=game and game.overworld
      if game and game.save then game.save.onBike=false; if game.save.player then game.save.player.surfing=true end end
      if ow and ow.player then ow.player.surfing=true end
      if ow and type(ow.syncSurfingPikachu)=="function" then pcall(ow.syncSurfingPikachu,ow) end
      self.mod.events:emit("mod.johto_water.waterfall_climbed",{owner=self.mod.id,mapId=f.mapId,id=f.id})
    end})
    if not ok then self.mod.log:error("WATERFALL traversal failed: %s",tostring(err)) end
  end)
end
function Service:canWhirlpool(game)
  return self:hasBadge(game,self.config.whirlpoolBadge) and self:facingFeature(game,"WHIRLPOOL")~=nil
end
function Service:canWaterfall(game)
  return self:hasBadge(game,self.config.waterfallBadge) and self:facingFeature(game,"WATERFALL")~=nil
end

local function graphicsAvailable()
  return love and love.graphics and type(love.graphics.rectangle)=="function" and type(love.graphics.setColor)=="function"
end
function Service:drawFlat(mapId,camX,camY)
  if not graphicsAvailable() then return end
  local ox,oy=math.floor(camX or 0),math.floor(camY or 0); love.graphics.push("all")
  for _,f in ipairs(self.features.WHIRLPOOL) do
    if f.mapId==mapId and not self:isCleared(f) then
      local x,y,w,h=f.x*CELL-ox,f.y*CELL-oy,f.width*CELL,f.height*CELL
      love.graphics.setColor(0.15,0.35,0.65,0.30); love.graphics.rectangle("fill",x,y,w,h)
      if type(love.graphics.ellipse)=="function" then
        love.graphics.setColor(0.85,0.95,1.0,0.70); local cx,cy=x+w/2,y+h/2
        love.graphics.ellipse("line",cx,cy,math.max(4,w*0.35),math.max(3,h*0.25))
        love.graphics.ellipse("line",cx,cy,math.max(2,w*0.18),math.max(2,h*0.12))
      end
    end
  end
  for _,f in ipairs(self.features.WATERFALL) do
    if f.mapId==mapId then
      local x,y,w,h=f.x*CELL-ox,f.y*CELL-oy,f.width*CELL,f.height*CELL
      love.graphics.setColor(0.65,0.85,1.0,0.34); love.graphics.rectangle("fill",x,y,w,h)
      love.graphics.setColor(0.95,1.0,1.0,0.70)
      if type(love.graphics.line)=="function" then for yy=y+4,y+h-2,6 do love.graphics.line(x,yy,x+w,yy) end end
    end
  end
  love.graphics.pop()
end
local function projectedQuad(project,f)
  local x0,y0=f.x*CELL,f.y*CELL; local x1,y1=x0+f.width*CELL,y0+f.height*CELL
  local ax,ay=project(x0,y0); local bx,by=project(x1,y0); local cx,cy=project(x1,y1); local dx,dy=project(x0,y1)
  if type(ax)~="number" or type(ay)~="number" or type(bx)~="number" or type(by)~="number" or type(cx)~="number" or type(cy)~="number" or type(dx)~="number" or type(dy)~="number" then return nil end
  return {ax,ay,bx,by,cx,cy,dx,dy}
end
function Service:drawProjected(ctx,project)
  if not (ctx and ctx.state and ctx.state.map and graphicsAvailable() and type(project)=="function" and type(love.graphics.polygon)=="function") then return end
  local mapId=ctx.state.map.id; love.graphics.push("all")
  for _,f in ipairs(self.features.WHIRLPOOL) do
    if f.mapId==mapId and not self:isCleared(f) then local q=projectedQuad(project,f); if q then love.graphics.setColor(0.15,0.35,0.65,0.30); love.graphics.polygon("fill",q) end end
  end
  for _,f in ipairs(self.features.WATERFALL) do
    if f.mapId==mapId then local q=projectedQuad(project,f); if q then love.graphics.setColor(0.65,0.85,1.0,0.34); love.graphics.polygon("fill",q) end end
  end
  love.graphics.pop()
end
local function installPlayerPatch(service)
  local ok,Player=pcall(require,"src.world.Player")
  if not (ok and Player and type(Player.tryMove)=="function") then service.mod.log:error("Could not install Johto water collision hook"); return nil end
  Player.__johtoWaterMoveServices=Player.__johtoWaterMoveServices or {}; table.insert(Player.__johtoWaterMoveServices,service)
  if Player.__johtoWaterMovePatched then return true end
  local original=Player.tryMove
  Player.tryMove=function(player,dir,map,entities)
    for _,active in ipairs(Player.__johtoWaterMoveServices or {}) do
      local why=active:blocksMove(player,dir,map); if why then player.bumpFrames=player.stepFrames or 16; return "blocked",why end
    end
    return original(player,dir,map,entities)
  end
  Player.__johtoWaterMovePatched=true; return true
end
local function installRenderPatch(service)
  local okTiles,TileRenderer=pcall(require,"src.render.TileRenderer")
  if okTiles and TileRenderer and type(TileRenderer.drawWindow)=="function" then
    TileRenderer.__johtoWaterMoveServices=TileRenderer.__johtoWaterMoveServices or {}; table.insert(TileRenderer.__johtoWaterMoveServices,service)
    if not TileRenderer.__johtoWaterMovePatched then
      local original=TileRenderer.drawWindow
      TileRenderer.drawWindow=function(renderer,camX,camY,viewWidth,viewHeight)
        local result=original(renderer,camX,camY,viewWidth,viewHeight); local mapId=renderer and renderer.map and renderer.map.id
        if mapId then for _,active in ipairs(TileRenderer.__johtoWaterMoveServices or {}) do active:drawFlat(mapId,camX,camY) end end
        return result
      end
      TileRenderer.__johtoWaterMovePatched=true
    end
  end
  local okPipes,Pipelines=pcall(require,"src.render.Pipelines")
  if okPipes and Pipelines and type(Pipelines.drawWorld)=="function" then
    Pipelines.__johtoWaterMoveServices=Pipelines.__johtoWaterMoveServices or {}; table.insert(Pipelines.__johtoWaterMoveServices,service)
    if not Pipelines.__johtoWaterMovePatched then
      local original=Pipelines.drawWorld
      Pipelines.drawWorld=function(id,ctx)
        if ctx and type(ctx.drawFx)=="function" then local base=ctx.drawFx; ctx.drawFx=function(project,scale) for _,active in ipairs(Pipelines.__johtoWaterMoveServices or {}) do active:drawProjected(ctx,project) end; return base(project,scale) end end
        return original(id,ctx)
      end
      Pipelines.__johtoWaterMovePatched=true
    end
  end
  return true
end
function Service:install()
  if not installPlayerPatch(self) then return nil end; installRenderPatch(self)
  self.mod.hooks:wrap("ui.party.submenu",function(next,game,items,mon,ctx)
    local out=next(game,items,mon,ctx); if type(out)~="table" or (ctx and ctx.battle) then return out end
    local p=self:current(game); if not (p and p.surfing and mon) then return out end
    if monKnows(mon,"WHIRLPOOL") and self:hasBadge(game,self.config.whirlpoolBadge) then
      local f=self:facingFeature(game,"WHIRLPOOL"); if f and not alreadyHas(out,"WHIRLPOOL") then insertBeforeStats(out,{label="WHIRLPOOL",onSelect=function(selected,activeGame) self:beginWhirlpool(selected,activeGame,f) end}) end
    end
    if monKnows(mon,"WATERFALL") and self:hasBadge(game,self.config.waterfallBadge) then
      local f=self:facingFeature(game,"WATERFALL"); if f and not alreadyHas(out,"WATERFALL") then insertBeforeStats(out,{label="WATERFALL",onSelect=function(selected,activeGame) self:beginWaterfall(selected,activeGame,f) end}) end
    end
    return out
  end)
  self.mod.events:on("map.entered",function(event) if event and event.mapId then self.cleared[event.mapId]=nil end end)
  return true
end

function JohtoWaterMoves.install(mod,config)
  ensureMove(mod,"WHIRLPOOL",{id="WHIRLPOOL",name="WHIRLPOOL",type="WATER",power=15,accuracy=70,pp=15,effect="TRAPPING_EFFECT",category="special"})
  ensureMove(mod,"WATERFALL",{id="WATERFALL",name="WATERFALL",type="WATER",power=80,accuracy=100,pp=15,effect="NO_ADDITIONAL_EFFECT",category="special"})
  if not ensureMachine(mod,"HM_06",6,"WHIRLPOOL") then return nil end
  if not ensureMachine(mod,"HM_07",7,"WATERFALL") then return nil end
  local hm=mod.content.constants:get("hmMoves") or {}; hm=appendUnique(hm,"WHIRLPOOL"); hm=appendUnique(hm,"WATERFALL"); mod.content.constants:override("hmMoves",hm)
  local wp=patchCompatibility(mod,"WHIRLPOOL",WHIRLPOOL_GEN1); local wf=patchCompatibility(mod,"WATERFALL",WATERFALL_GEN1); local standalone=installStandaloneAcquisition(mod)
  local service=Service.new(mod,config); if not service:install() then return nil end
  mod.log:info("Johto water HMs ready: HM06 WHIRLPOOL (%d Gen I patches), HM07 WATERFALL (%d); Crystal 251=%s, standalone acquisition=%s",wp,wf,tostring(crystalInstalled(mod)),tostring(standalone))
  return service
end
JohtoWaterMoves.WHIRLPOOL_GEN1=WHIRLPOOL_GEN1
JohtoWaterMoves.WATERFALL_GEN1=WATERFALL_GEN1
return JohtoWaterMoves
