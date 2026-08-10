local SeabedAudit = {}

local OPPOSITE = { north = "south", south = "north", west = "east", east = "west" }

local function cellKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function addError(report, message)
  report.errors[#report.errors + 1] = message
end

local function addWarning(report, message)
  report.warnings[#report.warnings + 1] = message
end

local function runCells(runs, fn)
  for y, row in pairs(runs or {}) do
    y = tonumber(y)
    for _, run in ipairs(row or {}) do
      for x = tonumber(run.x0) or 0, tonumber(run.x1) or -1 do fn(x, y, run) end
    end
  end
end

local function linkCells(zone, fn)
  for _, link in ipairs(zone and zone.links or {}) do
    local surface = link.surface or {}
    local underwater = link.underwater or {}
    local width, height = tonumber(link.width) or 0, tonumber(link.height) or 0
    for dy = 0, height - 1 do
      for dx = 0, width - 1 do
        fn(surface.x + dx, surface.y + dy,
          underwater.x + dx, underwater.y + dy, link)
      end
    end
  end
end

function SeabedAudit.validate(atlas, generated)
  local report = {
    ok = true,
    maps = 0,
    waterCells = 0,
    diveCells = 0,
    volumeCells = 0,
    seams = 0,
    errors = {},
    warnings = {},
  }

  if not (atlas and generated) then
    addError(report, "atlas or generated content is missing")
    report.ok = false
    return report
  end

  for _, surfaceId in ipairs(atlas:mapIds()) do
    local entry = atlas:surface(surfaceId)
    report.maps = report.maps + 1
    report.waterCells = report.waterCells + (entry.waterCount or 0)

    local zone = generated.dives and generated.dives["atlas:" .. surfaceId]
    local volume = generated.volumes and generated.volumes["atlas:" .. surfaceId]
    local mapDef = nil
    for _, candidate in ipairs(generated.maps or {}) do
      if candidate.id == entry.underwaterMapId then mapDef = candidate break end
    end

    if not zone then addError(report, surfaceId .. ": missing generated DIVE zone") end
    if not volume then addError(report, surfaceId .. ": missing generated volume") end
    if not mapDef then addError(report, surfaceId .. ": missing generated underwater map") end

    if mapDef then
      if mapDef.width ~= entry.def.width or mapDef.height ~= entry.def.height then
        addError(report, surfaceId .. ": generated map dimensions differ from surface map")
      end
      if #(mapDef.blocks or {}) ~= (mapDef.width or 0) * (mapDef.height or 0) then
        addError(report, surfaceId .. ": generated block count does not match map dimensions")
      end
    end

    local diveSeen = {}
    linkCells(zone, function(sx, sy, ux, uy, link)
      local key = cellKey(sx, sy)
      report.diveCells = report.diveCells + 1
      if diveSeen[key] then addError(report, surfaceId .. ": duplicate DIVE coverage at " .. key) end
      diveSeen[key] = true
      if not entry.water[key] then addError(report, surfaceId .. ": DIVE link covers non-water cell " .. key) end
      if sx ~= ux or sy ~= uy then
        addError(report, surfaceId .. ": generated DIVE link is not identity-mapped at " .. key)
      end
      if link.surface.mapId ~= surfaceId or link.underwater.mapId ~= entry.underwaterMapId then
        addError(report, surfaceId .. ": generated DIVE link points at the wrong map")
      end
    end)

    local volumeSeen = {}
    runCells(volume and volume.cellRuns, function(x, y)
      local key = cellKey(x, y)
      report.volumeCells = report.volumeCells + 1
      if volumeSeen[key] then addError(report, surfaceId .. ": duplicate volume coverage at " .. key) end
      volumeSeen[key] = true
      if not entry.water[key] then addError(report, surfaceId .. ": swim volume covers non-water cell " .. key) end
    end)

    for key in pairs(entry.water or {}) do
      if not diveSeen[key] then addError(report, surfaceId .. ": water cell has no DIVE link at " .. key) end
      if not volumeSeen[key] then addError(report, surfaceId .. ": water cell has no swim volume at " .. key) end
      local depth = entry.floorDepth and entry.floorDepth[key]
      if not tonumber(depth) or depth <= 0 then addError(report, surfaceId .. ": invalid seabed depth at " .. key) end
    end

    for direction, seam in pairs(entry.seams or {}) do
      report.seams = report.seams + 1
      local connection = mapDef and mapDef.connections and mapDef.connections[direction]
      if not connection or connection.map ~= seam.underwaterMap then
        addError(report, string.format("%s: missing underwater %s seam to %s",
          surfaceId, direction, tostring(seam.underwaterMap)))
      end
      local neighbor = atlas:surface(seam.map)
      local reverse = neighbor and neighbor.seams and neighbor.seams[OPPOSITE[direction]]
      if not reverse or reverse.map ~= surfaceId then
        addWarning(report, string.format("%s -> %s seam has no reciprocal %s source connection",
          surfaceId, tostring(seam.map), tostring(OPPOSITE[direction])))
      end
    end
  end

  if atlas.stats and atlas.stats.waterCells and report.waterCells ~= atlas.stats.waterCells then
    addError(report, string.format("atlas water total mismatch: report=%d atlas=%d",
      report.waterCells, atlas.stats.waterCells))
  end
  if report.diveCells ~= report.waterCells then
    addError(report, string.format("global DIVE coverage mismatch: dive=%d water=%d",
      report.diveCells, report.waterCells))
  end
  if report.volumeCells ~= report.waterCells then
    addError(report, string.format("global swim-volume coverage mismatch: volume=%d water=%d",
      report.volumeCells, report.waterCells))
  end

  report.ok = #report.errors == 0
  return report
end

function SeabedAudit.log(mod, report)
  if not (mod and mod.log and report) then return end
  if report.ok then
    mod.log:info("Kanto seabed audit OK: %d maps, %d water cells, %d DIVE cells, %d volume cells",
      report.maps, report.waterCells, report.diveCells, report.volumeCells)
  else
    mod.log:error("Kanto seabed audit failed with %d errors", #report.errors)
    for _, message in ipairs(report.errors) do mod.log:error("seabed audit: %s", message) end
  end
  for _, message in ipairs(report.warnings or {}) do mod.log:warn("seabed audit: %s", message) end
end

return SeabedAudit
