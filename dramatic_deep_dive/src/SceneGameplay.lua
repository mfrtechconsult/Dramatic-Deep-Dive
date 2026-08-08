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

  local district = self.renderer:districtAt(map.id, player.py or player.cellY * 16)
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

  -- DeepDive's own movement wrapper opens the authored SwimVolume. This
  -- higher-priority wrapper runs around it and puts physical mass back into
  -- large 3D landmarks. A player may still swim over a short ruin because the
  -- collider also checks current world height/depth.
  self.mod.hooks:wrap("movement.collision", function(next, allowed, ctx)
    local result = next(allowed, ctx)
    local controller = gameplay.controller
    local state = controller and controller.state
    local ow = Game.overworld
    if not (state and state.active and ow and ow.player and ctx
        and ctx.mover == ow.player and ow.map) then return result end

    if gameplay.renderer:blocksCell(
        ow.map.id, ctx.toX, ctx.toY, state.depth) then
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
