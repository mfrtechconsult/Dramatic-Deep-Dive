local SurfaceDiveMarkers = {}
SurfaceDiveMarkers.__index = SurfaceDiveMarkers

-- Full-Kanto seabed mode no longer needs a visual DIVE mask: every detected
-- surface-water cell is intended to be diveable.  This service now keeps only
-- the functional coverage index used by diagnostics/exports.
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
  if x < 0 or y < 0 or x >= def.width * 2 or y >= def.height * 2 then return false end
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
    lookup = {},
  }, SurfaceDiveMarkers)
end

function SurfaceDiveMarkers:addCell(cell)
  local seen = self.lookup[cell.mapId]
  if not seen then seen = {}; self.lookup[cell.mapId] = seen end
  local cellKey = key(cell.x, cell.y)
  if seen[cellKey] then return end
  seen[cellKey] = cell

  local list = self.byMap[cell.mapId]
  if not list then list = {}; self.byMap[cell.mapId] = list end
  list[#list + 1] = cell
end

function SurfaceDiveMarkers:build()
  self.byMap = {}
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

  for _, cells in pairs(self.byMap) do
    table.sort(cells, function(a, b)
      if a.y ~= b.y then return a.y < b.y end
      return a.x < b.x
    end)
  end
end

function SurfaceDiveMarkers:cellsFor(mapId)
  local out = {}
  for _, cell in ipairs(self.byMap[mapId] or {}) do out[#out + 1] = copyCell(cell) end
  return out
end

function SurfaceDiveMarkers:cellAt(mapId, x, y)
  local rows = self.lookup[mapId]
  local cell = rows and rows[key(x, y)]
  return cell and copyCell(cell) or nil
end

function SurfaceDiveMarkers:install()
  self:build()
  local total, maps = 0, 0
  for _, cells in pairs(self.byMap) do
    maps = maps + 1
    total = total + #cells
  end
  if self.mod.log then
    self.mod.log:info(
      "Indexed %d diveable water cells across %d surface maps; visual DIVE mask disabled in full-Kanto mode",
      total, maps)
  end
  return true
end

return SurfaceDiveMarkers
