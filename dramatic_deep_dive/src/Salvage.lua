local Game = require("src.core.Game")
local OverworldState = require("src.world.OverworldController")
local Bag = require("src.inventory.Bag")
local Font = require("src.render.Font")

local Salvage = {}
Salvage.__index = Salvage

local SAVE_KEY = "salvageTaken"
local SIGNAL_RADIUS = 24
local COLLECT_RADIUS = 13
local DEPTH_TOLERANCE = 11

local function distance(ax, az, bx, bz)
  local dx, dz = ax - bx, az - bz
  return math.sqrt(dx * dx + dz * dz)
end

function Salvage.new(mod, controller, definitions)
  return setmetatable({
    mod = mod,
    controller = controller,
    definitions = definitions or {},
    currentSignal = nil,
  }, Salvage)
end

function Salvage:takenTable()
  local taken = self.mod.save:get(SAVE_KEY)
  if type(taken) ~= "table" then taken = {} end
  return taken
end

function Salvage:isTaken(id)
  return self:takenTable()[id] == true
end

function Salvage:markTaken(id)
  local taken = self:takenTable()
  taken[id] = true
  self.mod.save:set(SAVE_KEY, taken)
end

function Salvage:playerPosition()
  local ow = Game.overworld
  local player = ow and ow.player
  local map = ow and ow.map
  local state = self.controller and self.controller.state
  if not (player and map and state and state.active) then return nil end
  return map.id, (player.px or player.cellX * 16) + 8,
    (player.py or player.cellY * 16) + 8, state.depth or 0
end

function Salvage:nearestSignal()
  local mapId, x, z, depth = self:playerPosition()
  if not mapId then return nil end
  local best, bestDistance
  for _, node in ipairs(self.definitions[mapId] or {}) do
    if not self:isTaken(node.id) then
      local d = distance(x, z, node.x, node.z)
      if d <= SIGNAL_RADIUS and (not bestDistance or d < bestDistance) then
        best, bestDistance = node, d
      end
    end
  end
  if not best then return nil end
  return best, bestDistance, (best.depth or depth) - depth
end

function Salvage:showText(text)
  if not (Game.stack and self.mod.ui and self.mod.ui.TextBox) then return end
  Game.stack:push(self.mod.ui.TextBox.new(Game, text))
end

function Salvage:itemName(itemId)
  local item = Game.data and Game.data.items and Game.data.items[itemId]
  return item and item.name or itemId
end

function Salvage:collect(node)
  if not (node and Game.save and Game.data) then return false end
  if not (Game.data.items and Game.data.items[node.item]) then
    if self.mod.log then
      self.mod.log:error("salvage %s references unknown item %s",
        tostring(node.id), tostring(node.item))
    end
    return false
  end

  local qty = tonumber(node.qty) or 1
  if not Bag.add(Game.save, node.item, qty, Game.data) then
    self:showText("No more room for\nthis salvage.")
    return false
  end

  self:markTaken(node.id)
  local name = self:itemName(node.item)
  local prefix = qty > 1 and (tostring(qty) .. " ") or ""
  self:showText("Recovered " .. prefix .. name .. "!")
  self.mod.events:emit("mod.dramatic_deep_dive.salvage", {
    id = node.id,
    item = node.item,
    qty = qty,
    mapId = Game.overworld and Game.overworld.map and Game.overworld.map.id,
    depth = self.controller and self.controller:currentDepth(),
  })
  return true
end

function Salvage:tryInteract()
  local node, horizontal, vertical = self:nearestSignal()
  if not node then return false end
  if horizontal > COLLECT_RADIUS or math.abs(vertical) > DEPTH_TOLERANCE then return false end
  self:collect(node)
  return true
end

function Salvage:update()
  local node, horizontal, vertical = self:nearestSignal()
  self.currentSignal = node and {
    node = node,
    horizontal = horizontal,
    vertical = vertical,
  } or nil
end

function Salvage:drawHint()
  local signal = self.currentSignal
  if not signal or not (love and love.graphics) then return end
  local node, horizontal, vertical = signal.node, signal.horizontal, signal.vertical

  local message
  if horizontal <= COLLECT_RADIUS and math.abs(vertical) <= DEPTH_TOLERANCE then
    message = "A  SALVAGE"
  elseif vertical > DEPTH_TOLERANCE then
    message = "SIGNAL BELOW"
  elseif vertical < -DEPTH_TOLERANCE then
    message = "SIGNAL ABOVE"
  else
    message = node.label or "SALVAGE SIGNAL"
  end

  love.graphics.push("all")
  love.graphics.setColor(0, 0, 0, 1)
  -- Dedicated middle strip: depth HUD occupies the top, district discovery
  -- sits lower, and SURFACE hints live at the bottom of the 144px viewport.
  Font.drawBox(1, 6, 18, 4)
  Font.draw(message, math.floor((160 - Font.width(message)) / 2), 56)
  love.graphics.pop()
end

function Salvage:install()
  local salvage = self

  local handleInput = OverworldState.handleInput
  function OverworldState:handleInput(...)
    if Game.overworld == self and salvage.controller and salvage.controller:isActive()
        and Game.input and Game.input.wasPressed and Game.input:wasPressed("a") then
      if salvage:tryInteract() then return end
    end
    return handleInput(self, ...)
  end

  local update = OverworldState.update
  function OverworldState:update(dt, ...)
    local result = update(self, dt, ...)
    if Game.overworld == self then salvage:update() end
    return result
  end

  local drawUI = OverworldState.drawUI
  function OverworldState:drawUI(...)
    local result = drawUI(self, ...)
    if Game.overworld == self then salvage:drawHint() end
    return result
  end

  self.mod.events:on("save.created", function()
    salvage.mod.save:set(SAVE_KEY, {})
  end)
end

function Salvage:remaining(mapId)
  local count = 0
  for _, node in ipairs(self.definitions[mapId] or {}) do
    if not self:isTaken(node.id) then count = count + 1 end
  end
  return count
end

return Salvage
