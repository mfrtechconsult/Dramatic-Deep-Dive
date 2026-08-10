local SurfaceDiveMarkers = {}
SurfaceDiveMarkers.__index = SurfaceDiveMarkers

local CELL = 16
local SHADE_ALPHA = 0.40

local function key(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function graphicsAvailable()
  return love and love.graphics
    and type(love.graphics.rectangle) == "function"
    and type(love.graphics.setColor) == "function"
end

local function isWaterCell(mod, Map, mapId, x, y)
  local def = mod.content.maps:get(mapId)
  if not def then return false end
  local tileset = mod.content.tilesets:get(def.tileset)
  if not tileset then return false end
  if Map and type(Map.defIsWaterCell) == "function" then
    return Map.defIsWaterCell(def, tileset, x, y) == true
  end
  return true
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
  if not seen then seen = {}; self.lookup[cell.mapId] = seen end
  local k = key(cell.x, cell.y)
  if seen[k] then return end
  seen[k] = cell
  local list = self.byMap[cell.mapId]
  if not list then list = {}; self.byMap[cell.mapId] = list end
  list[#list + 1] = cell
end

function SurfaceDiveMarkers:build()
  self.byMap, self.runsByMap, self.lookup = {}, {}, {}
  local okMap, Map = pcall(require, "src.world.Map")
  if not okMap then Map = nil end

  for zoneId, zone in pairs(self.definitions) do
    for _, link in ipairs(zone.links or {}) do
      local surface = link.surface
      if surface and surface.mapId then
        for y = surface.y, surface.y + (link.height or 1) - 1 do
          for x = surface.x, surface.x + (link.width or 1) - 1 do
            if isWaterCell(self.mod, Map, surface.mapId, x, y) then
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
    out[#out + 1] = {
      mapId = cell.mapId,
      x = cell.x,
      y = cell.y,
      zoneId = cell.zoneId,
      linkId = cell.linkId,
    }
  end
  return out
end

function SurfaceDiveMarkers:drawFlat(mapId, camX, camY, viewWidth, viewHeight)
  local runs = self.runsByMap[mapId]
  if not (runs and graphicsAvailable()) then return end
  local ox, oy = math.floor(camX or 0), math.floor(camY or 0)
  local vw, vh = viewWidth or math.huge, viewHeight or math.huge
  love.graphics.push("all")
  for _, run in ipairs(runs) do
    local x = run.x * CELL - ox
    local y = run.y * CELL - oy
    local w = run.width * CELL
    if x + w > 0 and y + CELL > 0 and x < vw and y < vh then
      love.graphics.setColor(0, 0.04, 0.11, SHADE_ALPHA)
      love.graphics.rectangle("fill", x, y, w, CELL)
      love.graphics.setColor(0.62, 0.88, 1.0, 0.58)
      love.graphics.rectangle("line", x + 0.5, y + 0.5, math.max(1, w - 1), CELL - 1)
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
  if not (ctx and ctx.state and ctx.state.map and type(project) == "function"
      and graphicsAvailable() and type(love.graphics.polygon) == "function") then
    return
  end
  local runs = self.runsByMap[ctx.state.map.id]
  if not runs then return end

  love.graphics.push("all")
  for _, run in ipairs(runs) do
    local x0, y0 = run.x * CELL, run.y * CELL
    local x1, y1 = x0 + run.width * CELL, y0 + CELL
    local ax, ay = projectPoint(project, x0, y0)
    local bx, by = projectPoint(project, x1, y0)
    local cx, cy = projectPoint(project, x1, y1)
    local dx, dy = projectPoint(project, x0, y1)
    if ax and bx and cx and dx then
      local q = { ax, ay, bx, by, cx, cy, dx, dy }
      love.graphics.setColor(0, 0.04, 0.11, 0.30)
      love.graphics.polygon("fill", q)
      love.graphics.setColor(0.62, 0.88, 1.0, 0.68)
      love.graphics.polygon("line", q)
    end
  end
  love.graphics.pop()
end

local function installTileRenderer(service)
  local ok, TileRenderer = pcall(require, "src.render.TileRenderer")
  if not (ok and TileRenderer and type(TileRenderer.drawWindow) == "function") then
    return nil, "TileRenderer.drawWindow is unavailable"
  end
  TileRenderer.__dramaticDeepDiveSurfaceMarkersService = service
  if TileRenderer.__dramaticDeepDiveSurfaceMarkersPatched then return true end
  local original = TileRenderer.drawWindow
  TileRenderer.drawWindow = function(renderer, camX, camY, viewWidth, viewHeight)
    local result = original(renderer, camX, camY, viewWidth, viewHeight)
    local active = TileRenderer.__dramaticDeepDiveSurfaceMarkersService
    local mapId = renderer and renderer.map and renderer.map.id
    if active and mapId then active:drawFlat(mapId, camX, camY, viewWidth, viewHeight) end
    return result
  end
  TileRenderer.__dramaticDeepDiveSurfaceMarkersPatched = true
  return true
end

local function installPipelines(service)
  local ok, Pipelines = pcall(require, "src.render.Pipelines")
  if not (ok and Pipelines and type(Pipelines.drawWorld) == "function") then
    return nil, "Pipelines.drawWorld is unavailable"
  end
  Pipelines.__dramaticDeepDiveSurfaceMarkersService = service
  if Pipelines.__dramaticDeepDiveSurfaceMarkersPatched then return true end
  local original = Pipelines.drawWorld
  Pipelines.drawWorld = function(id, ctx)
    local active = Pipelines.__dramaticDeepDiveSurfaceMarkersService
    if active and ctx and type(ctx.drawFx) == "function" and ctx.state and ctx.state.map
        and active.runsByMap[ctx.state.map.id] then
      local baseDrawFx = ctx.drawFx
      ctx.drawFx = function(project, scale)
        active:drawProjected(ctx, project)
        return baseDrawFx(project, scale)
      end
    end
    return original(id, ctx)
  end
  Pipelines.__dramaticDeepDiveSurfaceMarkersPatched = true
  return true
end

function SurfaceDiveMarkers:install()
  self:build()
  local ok, err = installTileRenderer(self)
  if not ok then
    self.mod.log:error("Could not install Deep Dive surface markers in 2D: %s", tostring(err))
    return nil
  end
  ok, err = installPipelines(self)
  if not ok then
    self.mod.log:error("Could not install Deep Dive surface markers in world pipelines: %s", tostring(err))
    return nil
  end
  local total = 0
  for _, cells in pairs(self.byMap) do total = total + #cells end
  self.mod.log:info("Installed visible surface markers on %d Deep Dive cells", total)
  return true
end

return SurfaceDiveMarkers
