local SurfaceDiveMarkers = {}
SurfaceDiveMarkers.__index = SurfaceDiveMarkers

-- Match Kanto Dive's surface language exactly: a neutral black tint keeps the
-- animated water readable while clearly marking the whole DIVE area.
local SHADE_ALPHA = 0.34
local CELL_SIZE = 16

local function key(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function copyCell(cell)
  return {
    mapId = cell.mapId,
    x = cell.x,
    y = cell.y,
    zoneId = cell.zoneId,
    linkId = cell.linkId,
  }
end

local function mapCellIsWater(mod, Map, mapId, x, y)
  local def = mod.content.maps:get(mapId)
  if not def then return false end
  if x < 0 or y < 0 or x >= def.width * 2 or y >= def.height * 2 then
    return false
  end
  local tileset = mod.content.tilesets:get(def.tileset)
  if not tileset then return false end
  if Map and type(Map.defIsWaterCell) == "function" then
    return Map.defIsWaterCell(def, tileset, x, y) == true
  end
  return true
end

local function graphicsAvailable()
  return love and love.graphics
    and type(love.graphics.rectangle) == "function"
    and type(love.graphics.setColor) == "function"
end

function SurfaceDiveMarkers.new(mod, definitions)
  return setmetatable({
    mod = mod,
    definitions = definitions or {},
    byMap = {},
    runsByMap = {},
    lookup = {},
  }, SurfaceDiveMarkers)
end

function SurfaceDiveMarkers:addCell(cell)
  local seen = self.lookup[cell.mapId]
  if not seen then
    seen = {}
    self.lookup[cell.mapId] = seen
  end
  local cellKey = key(cell.x, cell.y)
  if seen[cellKey] then return end
  seen[cellKey] = cell

  local list = self.byMap[cell.mapId]
  if not list then
    list = {}
    self.byMap[cell.mapId] = list
  end
  list[#list + 1] = cell
end

function SurfaceDiveMarkers:build()
  self.byMap = {}
  self.runsByMap = {}
  self.lookup = {}

  local mapLoaded, Map = pcall(require, "src.world.Map")
  if not mapLoaded then Map = nil end

  for zoneId, zone in pairs(self.definitions) do
    for _, link in ipairs(zone.links or {}) do
      local surface = link.surface
      if surface and surface.mapId then
        local width = math.max(1, tonumber(link.width) or 1)
        local height = math.max(1, tonumber(link.height) or 1)
        for y = surface.y, surface.y + height - 1 do
          for x = surface.x, surface.x + width - 1 do
            if mapCellIsWater(self.mod, Map, surface.mapId, x, y) then
              self:addCell({
                mapId = surface.mapId,
                x = x,
                y = y,
                zoneId = zoneId,
                linkId = link.id,
              })
            end
          end
        end
      end
    end
  end

  for mapId, cells in pairs(self.byMap) do
    table.sort(cells, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
    local runs = {}
    for _, cell in ipairs(cells) do
      local run = runs[#runs]
      if run and run.y == cell.y and run.x + run.width == cell.x then
        run.width = run.width + 1
      else
        runs[#runs + 1] = { x = cell.x, y = cell.y, width = 1 }
      end
    end
    self.runsByMap[mapId] = runs
  end
end

function SurfaceDiveMarkers:cellsFor(mapId)
  local out = {}
  for _, cell in ipairs(self.byMap[mapId] or {}) do
    out[#out + 1] = copyCell(cell)
  end
  return out
end

function SurfaceDiveMarkers:cellAt(mapId, x, y)
  local rows = self.lookup[mapId]
  local cell = rows and rows[key(x, y)]
  return cell and copyCell(cell) or nil
end

function SurfaceDiveMarkers:drawFlat(mapId, camX, camY, viewWidth, viewHeight)
  local runs = self.runsByMap[mapId]
  if not (runs and graphicsAvailable()) then return end

  local floorX = math.floor(camX or 0)
  local floorY = math.floor(camY or 0)
  local vw = viewWidth or math.huge
  local vh = viewHeight or math.huge

  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, SHADE_ALPHA)
  for _, run in ipairs(runs) do
    local x = run.x * CELL_SIZE - floorX
    local y = run.y * CELL_SIZE - floorY
    local width = run.width * CELL_SIZE
    if x + width > 0 and y + CELL_SIZE > 0 and x < vw and y < vh then
      love.graphics.rectangle("fill", x, y, width, CELL_SIZE)
    end
  end
  love.graphics.pop()
end

local function projectPoint(project, x, y)
  local px, py = project(x, y)
  if type(px) ~= "number" or type(py) ~= "number" then return nil end
  return px, py
end

function SurfaceDiveMarkers:drawProjected(ctx, project)
  if not (ctx and ctx.state and ctx.state.map and type(project) == "function") then
    return
  end
  local runs = self.runsByMap[ctx.state.map.id]
  if not (runs and graphicsAvailable() and type(love.graphics.polygon) == "function") then
    return
  end

  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, SHADE_ALPHA)
  for _, run in ipairs(runs) do
    local x0, y0 = run.x * CELL_SIZE, run.y * CELL_SIZE
    local x1, y1 = x0 + run.width * CELL_SIZE, y0 + CELL_SIZE
    local ax, ay = projectPoint(project, x0, y0)
    local bx, by = projectPoint(project, x1, y0)
    local cx, cy = projectPoint(project, x1, y1)
    local dx, dy = projectPoint(project, x0, y1)
    if ax and bx and cx and dx then
      love.graphics.polygon("fill", ax, ay, bx, by, cx, cy, dx, dy)
    end
  end
  love.graphics.pop()
end

function SurfaceDiveMarkers:playerTouchesDark(mapId, player)
  if not (mapId and player) then return false end
  local rows = self.lookup[mapId]
  if not rows then return false end
  if rows[key(player.cellX, player.cellY)] then return true end
  if player.targetX ~= nil and player.targetY ~= nil
      and rows[key(player.targetX, player.targetY)] then return true end
  return false
end

local function dramaticSkyRideOwnsPlayer(service)
  local mod = service and service.mod
  if not (mod and type(mod.find) == "function") then return false end

  local okFind, handle = pcall(mod.find, mod, "DRAMATIC_SKY_RIDE")
  local exports = okFind and handle and handle.exports or nil
  if type(exports) ~= "table" then return false end

  for _, name in ipairs({ "isFlying", "isGroundRiding", "isWaterRiding" }) do
    local fn = exports[name]
    if type(fn) == "function" then
      local ok, active = pcall(fn)
      if ok and active == true then return true end
    end
  end
  return false
end

function SurfaceDiveMarkers:redrawPlayerProjected(ctx, project, scale)
  if not (ctx and ctx.state and ctx.state.map and type(project) == "function") then
    return
  end
  if dramaticSkyRideOwnsPlayer(self) then return end

  local state = ctx.state
  local player = state.player
  local mapId = state.map.id
  if not self:playerTouchesDark(mapId, player) then return end
  if not (player and type(player.draw) == "function") then return end

  local wx, wy = player.px + 8, player.py + 16
  local sx, sy = projectPoint(project, wx, wy)
  if not sx then return end
  scale = tonumber(scale) or tonumber(ctx.scale) or 1
  if scale == 0 then scale = 1 end
  local cam = ctx.cam or state.camera or { x = 0, y = 0 }
  local flatFootX, flatFootY = wx - (cam.x or 0), wy - (cam.y or 0)

  love.graphics.push("all")
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.scale(scale, scale)
  love.graphics.translate(sx / scale - flatFootX, sy / scale - flatFootY)
  player:draw(cam.x or 0, cam.y or 0)
  love.graphics.pop()
end

local function installTileRenderer(service)
  local loaded, TileRenderer = pcall(require, "src.render.TileRenderer")
  if not (loaded and TileRenderer) then
    return nil, "src.render.TileRenderer is unavailable"
  end

  TileRenderer.__dramaticDeepDiveSurfaceDarkService = service
  if TileRenderer.__dramaticDeepDiveSurfaceDarkPatched then return true end

  local originalDrawWindow = TileRenderer.drawWindow
  if type(originalDrawWindow) ~= "function" then
    return nil, "TileRenderer.drawWindow is unavailable"
  end

  TileRenderer.drawWindow = function(renderer, camX, camY, viewWidth, viewHeight)
    originalDrawWindow(renderer, camX, camY, viewWidth, viewHeight)
    local active = TileRenderer.__dramaticDeepDiveSurfaceDarkService
    local mapId = renderer and renderer.map and renderer.map.id
    if active and mapId then
      active:drawFlat(mapId, camX, camY, viewWidth, viewHeight)
    end
  end
  TileRenderer.__dramaticDeepDiveSurfaceDarkPatched = true
  return true
end

local function installPipelineProjection(service)
  local loaded, Pipelines = pcall(require, "src.render.Pipelines")
  if not (loaded and Pipelines) then
    return nil, "src.render.Pipelines is unavailable"
  end

  Pipelines.__dramaticDeepDiveSurfaceDarkService = service
  if Pipelines.__dramaticDeepDiveSurfaceDarkPatched then return true end

  local originalDrawWorld = Pipelines.drawWorld
  if type(originalDrawWorld) ~= "function" then
    return nil, "Pipelines.drawWorld is unavailable"
  end

  Pipelines.drawWorld = function(id, ctx)
    local active = Pipelines.__dramaticDeepDiveSurfaceDarkService
    if active and ctx and type(ctx.drawFx) == "function"
        and ctx.state and ctx.state.map
        and active.byMap[ctx.state.map.id] then
      local baseDrawFx = ctx.drawFx
      ctx.drawFx = function(project, scale)
        active:drawProjected(ctx, project)
        active:redrawPlayerProjected(ctx, project, scale)
        return baseDrawFx(project, scale)
      end
    end
    return originalDrawWorld(id, ctx)
  end
  Pipelines.__dramaticDeepDiveSurfaceDarkPatched = true
  return true
end

function SurfaceDiveMarkers:install()
  self:build()

  local ok, err = installTileRenderer(self)
  if not ok then
    self.mod.log:error("Could not install Deep Dive surface tint in 2D: %s", tostring(err))
    return nil
  end

  ok, err = installPipelineProjection(self)
  if not ok then
    self.mod.log:error("Could not install Deep Dive surface tint in world pipelines: %s", tostring(err))
    return nil
  end

  local total = 0
  for _, cells in pairs(self.byMap) do total = total + #cells end
  self.mod.log:info("Installed Kanto-style dark-water tint on %d Deep Dive cells", total)
  return true
end

return SurfaceDiveMarkers
