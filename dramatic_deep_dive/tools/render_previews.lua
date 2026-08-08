local ROOT = "dramatic_deep_dive/"
local OUT = arg[1] or "previews"
local BLOCK_PX = 8
local CELL_PX = BLOCK_PX / 2
local HEADER = 42
local MARGIN = 16
local MIN_WIDTH = 420

local function mkdir(path)
  os.execute(string.format('mkdir -p "%s"', path))
end

local function escape(text)
  return tostring(text or "")
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
end

local BLOCK_COLORS = {
  [0] = "#143f55", [1] = "#195069", [2] = "#152f40", [3] = "#1b5c70",
  [4] = "#246779", [5] = "#243d4a", [6] = "#182b35", [7] = "#315f6d",
  [8] = "#226076", [9] = "#2c6e78", [10] = "#334a55", [11] = "#1d5265",
  [12] = "#285a68", [13] = "#326f75", [14] = "#2c5962", [15] = "#101e28",
}

local DEPTH_COLORS = {
  "#8de7ec", "#64ced9", "#3caabc", "#2a819d", "#1d607f", "#173f65",
}

local function byMap(collection, mapId)
  for _, value in pairs(collection or {}) do
    if value.mapId == mapId then return value end
  end
end

local function mapFromSpec(spec) return dofile(ROOT .. spec.file) end

local function maxDepth(volume)
  local value = volume and volume.defaultFloorDepth or 1
  for _, zone in ipairs(volume and volume.depthZones or {}) do
    value = math.max(value, zone.floorDepth or 0)
  end
  return math.max(1, value)
end

local function depthColor(depth, deepest)
  local ratio = math.max(0, math.min(0.999, (depth or 0) / deepest))
  local index = 1 + math.floor(ratio * #DEPTH_COLORS)
  return DEPTH_COLORS[index]
end

local function rect(out, x, y, w, h, fill, opacity, stroke, strokeWidth)
  out[#out + 1] = string.format(
    '<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s" fill-opacity="%.3f" stroke="%s" stroke-width="%.2f"/>',
    x, y, w, h, fill or "none", opacity or 1, stroke or "none", strokeWidth or 0)
end

local function text(out, x, y, value, size, anchor, fill, weight)
  out[#out + 1] = string.format(
    '<text x="%.2f" y="%.2f" font-family="monospace" font-size="%d" text-anchor="%s" fill="%s" font-weight="%s">%s</text>',
    x, y, size or 10, anchor or "start", fill or "#ffffff", weight or "normal", escape(value))
end

local function line(out, x1, y1, x2, y2, stroke, width, dash)
  out[#out + 1] = string.format(
    '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="%.2f"%s/>',
    x1, y1, x2, y2, stroke or "#ffffff", width or 1,
    dash and (' stroke-dasharray="' .. dash .. '"') or "")
end

local function circle(out, x, y, r, fill, opacity, stroke)
  out[#out + 1] = string.format(
    '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s" fill-opacity="%.3f" stroke="%s" stroke-width="1"/>',
    x, y, r, fill or "#ffffff", opacity or 1, stroke or "none")
end

local function glyph(kind)
  local labels = {
    rock_arch = "ARCH", ruin_gate = "GATE", abyss_gate = "ABYSS",
    broken_wall = "WALL", column_ring = "RING", shrine = "SHRINE",
    spire = "SPIRE", shipwreck = "WRECK", black_smokers = "VENTS",
    cave_ceiling = "CEILING", stalactite_field = "STALACTITES", rib_cage = "FOSSIL",
  }
  return labels[kind] or tostring(kind or "3D"):upper()
end

local function render(map, volume, scene, setpiece)
  local mapW = map.width * BLOCK_PX
  local mapH = map.height * BLOCK_PX
  local width = math.max(MIN_WIDTH, mapW + MARGIN * 2)
  local height = mapH + HEADER + MARGIN * 2 + 34
  local ox = math.floor((width - mapW) / 2)
  local oy = HEADER + MARGIN
  local out = {}
  out[#out + 1] = string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
    width, height, width, height)
  rect(out, 0, 0, width, height, "#07131d", 1)

  text(out, MARGIN, 20, map.id, 14, "start", "#e9fbff", "bold")
  local dimensions = string.format("%d x %d cells", map.width * 2, map.height * 2)
  if volume then
    dimensions = dimensions .. string.format("  |  depth %d-%d", volume.minDepth or 0,
      (volume.defaultFloorDepth or 0) - (volume.seabedClearance or 0))
  end
  text(out, MARGIN, 35, dimensions, 9, "start", "#88b9c9")

  for by = 0, map.height - 1 do
    for bx = 0, map.width - 1 do
      local block = map.blocks[by * map.width + bx + 1] or map.borderBlock or 15
      rect(out, ox + bx * BLOCK_PX, oy + by * BLOCK_PX,
        BLOCK_PX, BLOCK_PX, BLOCK_COLORS[block] or "#244759", 1, "#0d2632", 0.25)
    end
  end

  if scene then
    for index, district in ipairs(scene.districts or {}) do
      if (district.axis or "z") == "x" then
        local x0 = ox + (district.x0 or 0) / 32 * BLOCK_PX
        local x1 = ox + (district.x1 or map.width * 32) / 32 * BLOCK_PX
        rect(out, x0, oy, x1-x0, mapH, "#ffffff", index % 2 == 0 and 0.025 or 0.045)
        text(out, (x0+x1)/2, oy+10, district.name or district.id, 7, "middle", "#d8f8ff", "bold")
      else
        local z0 = oy + (district.z0 or 0) / 32 * BLOCK_PX
        local z1 = oy + (district.z1 or map.height * 32) / 32 * BLOCK_PX
        rect(out, ox, z0, mapW, z1-z0, "#ffffff", index % 2 == 0 and 0.025 or 0.045)
        text(out, ox + mapW/2, z0+10, district.name or district.id, 7, "middle", "#d8f8ff", "bold")
      end
    end
  end

  if volume then
    local deepest = maxDepth(volume)
    for _, zone in ipairs(volume.depthZones or {}) do
      local x = ox + zone.left * CELL_PX
      local y = oy + zone.top * CELL_PX
      local w = (zone.right - zone.left + 1) * CELL_PX
      local h = (zone.bottom - zone.top + 1) * CELL_PX
      local color = depthColor(zone.floorDepth, deepest)
      rect(out, x, y, w, h, color, 0.24, color, 0.7)
      if w >= 30 and h >= 12 then
        text(out, x+w/2, y+h/2+3, tostring(zone.floorDepth), 7, "middle", "#eaffff", "bold")
      end
    end
    for _, zone in ipairs(volume.surfaceZones or {}) do
      local x = ox + zone.left * CELL_PX
      local y = oy + zone.top * CELL_PX
      local w = (zone.right - zone.left + 1) * CELL_PX
      local h = (zone.bottom - zone.top + 1) * CELL_PX
      rect(out, x, y, w, h, "none", 0, "#71fff2", 1.4)
    end
  end

  if scene then
    for _, structure in ipairs(scene.structures or {}) do
      local x = ox + structure.x / 32 * BLOCK_PX
      local y = oy + structure.z / 32 * BLOCK_PX
      circle(out, x, y, 3.2, structure.material == "darkStone" and "#a16bff" or "#ffcf74", 0.9, "#081219")
      text(out, x+5, y+2, glyph(structure.kind), 6, "start", "#f6f4dd", "bold")
    end
    for _, vent in ipairs(scene.bubbleVents or {}) do
      circle(out, ox + vent.x / 32 * BLOCK_PX, oy + vent.z / 32 * BLOCK_PX,
        1.5, "#b5f5ff", 0.9, "none")
    end
  end

  if setpiece then
    for _, piece in ipairs(setpiece.pieces or {}) do
      if piece.x and piece.z then
        local x = ox + piece.x / 32 * BLOCK_PX
        local y = oy + piece.z / 32 * BLOCK_PX
        rect(out, x-3.5, y-3.5, 7, 7, "#ff5fd2", 0.95, "#fff0fb", 0.7)
        text(out, x+5, y+2, glyph(piece.kind), 6, "start", "#ffd9f4", "bold")
      elseif piece.x0 then
        local x = ox + piece.x0 / 32 * BLOCK_PX
        local y = oy + piece.z0 / 32 * BLOCK_PX
        local w = (piece.x1-piece.x0) / 32 * BLOCK_PX
        local h = (piece.z1-piece.z0) / 32 * BLOCK_PX
        rect(out, x, y, w, h, "#ff5fd2", 0.08, "#ff7adb", 0.8)
        text(out, x+w/2, y+h/2+2, glyph(piece.kind), 6, "middle", "#ffd9f4", "bold")
      end
    end
  end

  rect(out, ox, oy, mapW, mapH, "none", 0, "#bfeefa", 1)
  local ly = oy + mapH + 18
  line(out, MARGIN, ly-5, MARGIN+18, ly-5, "#71fff2", 2)
  text(out, MARGIN+23, ly-2, "SURFACE", 7, "start", "#a8e9e6")
  circle(out, MARGIN+91, ly-5, 3, "#ffcf74", 1, "none")
  text(out, MARGIN+98, ly-2, "LANDMARK", 7, "start", "#e8d9ad")
  rect(out, MARGIN+158, ly-8, 6, 6, "#ff5fd2", 1, "none", 0)
  text(out, MARGIN+169, ly-2, "SETPIECE", 7, "start", "#ffd9f4")
  text(out, width-MARGIN, ly-2, "numbers = floor depth", 7, "end", "#7ca5b5")

  out[#out + 1] = "</svg>"
  return table.concat(out, "\n")
end

mkdir(OUT)
local specs = dofile(ROOT .. "data/maps.lua")
local volumes = dofile(ROOT .. "data/volumes.lua")
local scenes = dofile(ROOT .. "data/scenes.lua")
local setpieces = dofile(ROOT .. "data/setpieces.lua")

local count = 0
for _, spec in ipairs(specs) do
  local map = mapFromSpec(spec)
  local svg = render(map, byMap(volumes, map.id), byMap(scenes, map.id), byMap(setpieces, map.id))
  local path = OUT .. "/" .. map.id .. ".svg"
  local file = assert(io.open(path, "wb"))
  file:write(svg)
  file:close()
  print("preview: " .. path)
  count = count + 1
end

print(string.format("generated %d Deep Dive map previews", count))
