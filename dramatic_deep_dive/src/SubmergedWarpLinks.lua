local SubmergedWarpLinks = {}
SubmergedWarpLinks.__index = SubmergedWarpLinks

local CELL = 16
local PORTAL_RADIUS = 3
local PORTAL_COOLDOWN = 1.0

local function key(mapId, x, y)
  return tostring(mapId) .. ":" .. tostring(x) .. ":" .. tostring(y)
end

local function dist2(x0, y0, x1, y1)
  local dx, dy = x1 - x0, y1 - y0
  return dx * dx + dy * dy
end

local function nearestWater(entry, x, y, radius)
  if not (entry and x and y) then return nil end
  local best, bestD2 = nil, math.huge
  local limit = (radius or PORTAL_RADIUS) ^ 2
  for cellKey in pairs(entry.water or {}) do
    local wx, wy = cellKey:match("^(%-?%d+):(%-?%d+)$")
    wx, wy = tonumber(wx), tonumber(wy)
    local d2 = dist2(x, y, wx, wy)
    if d2 <= limit and d2 < bestD2 then
      bestD2 = d2
      best = { x = wx, y = wy }
    end
  end
  return best
end

local function eligible(a, b)
  if not (a and b) then return false end
  if a.profileName == "cave" and b.profileName == "cave" then return true end
  if a.profileName == "harbor" and b.profileName == "harbor" then return true end
  return false
end

local function addPortalArch(scene, cell, material)
  if not (scene and cell) then return end
  scene.structures = scene.structures or {}
  scene.structures[#scene.structures + 1] = {
    kind = "rock_arch",
    x = cell.x * CELL + CELL / 2,
    z = cell.y * CELL + CELL / 2,
    width = 54,
    height = 40,
    thickness = 10,
    material = material or "darkStone",
  }
end

function SubmergedWarpLinks.new(mod, atlas, scenes)
  local self = setmetatable({
    mod = mod,
    atlas = atlas,
    scenes = scenes or {},
    portals = {},
    count = 0,
    installed = false,
    controller = nil,
    cooldown = 0,
    lastCellKey = nil,
    transitions = 0,
  }, SubmergedWarpLinks)
  self:build()
  return self
end

function SubmergedWarpLinks:addPortal(sourceEntry, sourceCell, destEntry, destCell, warpIndex)
  local sourceMap = sourceEntry.underwaterMapId
  local destMap = destEntry.underwaterMapId
  local portalKey = key(sourceMap, sourceCell.x, sourceCell.y)
  if self.portals[portalKey] then return false end

  self.portals[portalKey] = {
    sourceMap = sourceMap,
    sourceX = sourceCell.x,
    sourceY = sourceCell.y,
    destMap = destMap,
    destX = destCell.x,
    destY = destCell.y,
    surfaceSource = sourceEntry.id,
    surfaceDest = destEntry.id,
    warpIndex = warpIndex,
  }
  self.count = self.count + 1

  local sourceScene = self.scenes["atlas:" .. sourceEntry.id]
  addPortalArch(sourceScene, sourceCell,
    sourceEntry.profileName == "harbor" and "ruinStone" or "darkStone")
  return true
end

function SubmergedWarpLinks:build()
  self.portals = {}
  self.count = 0

  for _, surfaceId in ipairs(self.atlas:mapIds()) do
    local entry = self.atlas:surface(surfaceId)
    for warpIndex, warp in ipairs(entry.def.warps or {}) do
      local destEntry = warp.destMap and self.atlas:surface(warp.destMap) or nil
      if destEntry and eligible(entry, destEntry) then
        local destWarp = destEntry.def.warps and destEntry.def.warps[tonumber(warp.destWarp) or -1]
        if destWarp then
          local sourceCell = nearestWater(entry, tonumber(warp.x), tonumber(warp.y), PORTAL_RADIUS)
          local destCell = nearestWater(destEntry, tonumber(destWarp.x), tonumber(destWarp.y), PORTAL_RADIUS)
          if sourceCell and destCell then
            self:addPortal(entry, sourceCell, destEntry, destCell, warpIndex)
          end
        end
      end
    end
  end

  if self.mod.log then
    self.mod.log:info("Generated %d submerged cave/harbor warp portals", self.count)
  end
  return self.count
end

function SubmergedWarpLinks:portalAt(mapId, x, y)
  return self.portals[key(mapId, x, y)]
end

function SubmergedWarpLinks:tryPortal(game)
  if (self.cooldown or 0) > 0 then return false end
  local state = self.controller and self.controller.state
  local ow = game and game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (state and state.active and player and map) then return false end

  local currentKey = key(map.id, player.cellX, player.cellY)
  if self.lastCellKey == currentKey then return false end
  self.lastCellKey = currentKey

  local portal = self.portals[currentKey]
  if not portal then return false end
  if not (self.mod.world and self.mod.world.warpTo) then return false end

  self.cooldown = PORTAL_COOLDOWN
  local facing = player.facing or "down"
  local ok, err = self.mod.world:warpTo(portal.destMap, portal.destX, portal.destY, facing, {
    onDone = function()
      self.lastCellKey = key(portal.destMap, portal.destX, portal.destY)
      self.transitions = self.transitions + 1
      if self.mod.log then
        self.mod.log:info("submerged portal %s -> %s", portal.surfaceSource, portal.surfaceDest)
      end
    end,
  })
  if not ok then
    self.cooldown = 0
    if self.mod.log then self.mod.log:warn("submerged portal warp failed: %s", tostring(err)) end
    return false
  end
  return true
end

function SubmergedWarpLinks:install(controller)
  if self.installed then return true end
  self.controller = controller
  local service = self
  self.mod.hooks:wrap("input.step", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    service.cooldown = math.max(0, (service.cooldown or 0) - (tonumber(dt) or 1 / 60))
    local ow = game and game.overworld
    local stack = game and game.stack
    local top = stack and stack.top and stack:top() or nil
    if ow and (not stack or top == ow) then service:tryPortal(game) end
    return result
  end, 55)
  self.mod.events:on("mod.DRAMATIC_DEEP_DIVE.surfaced", function()
    service.cooldown = 0
    service.lastCellKey = nil
  end)
  self.installed = true
  return true
end

function SubmergedWarpLinks:stats()
  return { portals = self.count, transitions = self.transitions }
end

return SubmergedWarpLinks
