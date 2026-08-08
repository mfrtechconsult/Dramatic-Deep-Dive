local Game = require("src.core.Game")
local OverworldState = require("src.world.OverworldController")
local Font = require("src.render.Font")

local SceneGameplay = {}
SceneGameplay.__index = SceneGameplay

local DISTRICT_BANNER_SECONDS = 2.6

function SceneGameplay.new(mod, controller, renderer)
  return setmetatable({
    mod = mod,
    controller = controller,
    renderer = renderer,
    districtId = nil,
    districtName = nil,
    bannerTimer = 0,
  }, SceneGameplay)
end

function SceneGameplay:districtAt(mapId, worldX, worldZ)
  local decor = self.renderer and self.renderer.sceneDecor
  local scene = decor and decor:sceneForMap(mapId)
  if not scene then return nil end
  for _, district in ipairs(scene.districts or {}) do
    local axis = district.axis or "z"
    if axis == "x" then
      if worldX >= (district.x0 or 0) and worldX < (district.x1 or math.huge) then
        return district
      end
    elseif worldZ >= (district.z0 or 0) and worldZ < (district.z1 or math.huge) then
      return district
    end
  end
  return nil
end

function SceneGameplay:updateDistrict(dt)
  local controller = self.controller
  local state = controller and controller.state
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  if not (state and state.active and player and map) then
    self.districtId, self.districtName, self.bannerTimer = nil, nil, 0
    return
  end

  local worldX = player.px or player.cellX * 16
  local worldZ = player.py or player.cellY * 16
  local district = self:districtAt(map.id, worldX, worldZ)
  if district and district.id ~= self.districtId then
    self.districtId = district.id
    self.districtName = district.name or district.id
    self.bannerTimer = DISTRICT_BANNER_SECONDS
    self.mod.events:emit("mod.dramatic_deep_dive.district", {
      id = district.id,
      name = self.districtName,
      mapId = map.id,
    })
    if self.mod.log then self.mod.log:info("discovered underwater district %s", self.districtName) end
  end
  self.bannerTimer = math.max(0, self.bannerTimer - (tonumber(dt) or 0))
end

function SceneGameplay:drawDistrictBanner()
  if self.bannerTimer <= 0 or not self.districtName then return end
  if not (love and love.graphics) then return end
  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 1)
  Font.drawBox(2, 11, 16, 4)
  local title = "AREA DISCOVERED"
  local name = tostring(self.districtName)
  Font.draw(title, math.floor((160 - Font.width(title)) / 2), 96)
  Font.draw(name, math.floor((160 - Font.width(name)) / 2), 112)
  love.graphics.pop()
end

function SceneGameplay:install()
  local gameplay = self

  self.mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    local controller = gameplay.controller
    local state = controller and controller.state
    local ow = Game.overworld
    if not (state and state.active and ow and ow.player and ctx
        and ctx.mover == ow.player and ow.map) then return result end

    if gameplay.renderer:blocksCell(ow.map.id, ctx.toX, ctx.toY, state.depth) then
      ctx.reason = "deep_dive_landmark"
      return false
    end
    return result
  end, 110)

  local update = OverworldState.update
  function OverworldState:update(dt, ...)
    local result = update(self, dt, ...)
    if Game.overworld == self then gameplay:updateDistrict(dt) end
    return result
  end

  local drawUI = OverworldState.drawUI
  function OverworldState:drawUI(...)
    local result = drawUI(self, ...)
    if Game.overworld == self then gameplay:drawDistrictBanner() end
    return result
  end
end

return SceneGameplay
