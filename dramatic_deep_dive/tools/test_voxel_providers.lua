local ROOT = arg[1] or "dramatic_deep_dive/"
local total, failed = 0, 0
local function check(value, label)
  total = total + 1
  if value then print("[PASS] " .. label) else failed = failed + 1; io.stderr:write("[FAIL] " .. label .. "\n") end
end

local defs = {}
package.loaded["src.render.Pipelines"] = nil
package.preload["src.render.Pipelines"] = function()
  return {
    get = function(id) return defs[id] end,
    level = function() return 0 end,
    setLevel = function(_, level) return level end,
  }
end

local VoxelProvider = dofile(ROOT .. "src/VoxelProvider.lua")
local function handle(id, publishedPipeline)
  local modules = {
    Voxel3D = { FORMAT = {}, beginScene = function() end, endScene = function() end },
    FreeMove = { tick = function() end },
    FirstPerson = { update = function() end },
    ThirdPerson = { reach = function() end },
  }
  return {
    id = id,
    version = "test",
    exports = {
      pipelines = publishedPipeline and { voxel = publishedPipeline } or nil,
      lib = { require = function(name) return modules[name] end },
    },
  }
end

local function makeMod(installed)
  return {
    exports = {},
    log = { info=function() end, warn=function() end, error=function() end },
    find = function(_, id) return installed[id] end,
  }
end

do
  defs = { voxel = {} }
  local mod = makeMod({ BATTLE_ART_VOXEL_FORK = handle("BATTLE_ART_VOXEL_FORK") })
  local p = VoxelProvider.new(mod)
  check(p:discover(), "Battle Art provider is discovered")
  check(p:id() == "BATTLE_ART_VOXEL_FORK", "Battle Art provider id selected")
  check(p:pipelineId() == "voxel", "Battle Art voxel pipeline selected")
  check(p:module("Voxel3D") ~= nil and p:supportsFreeMove(), "Battle Art public modules accepted")
end

do
  defs = { voxel = {} }
  local mod = makeMod({ DRAMALESS_SHAPE = handle("DRAMALESS_SHAPE") })
  local p = VoxelProvider.new(mod)
  check(p:discover(), "Dramaless provider is discovered")
  check(p:id() == "DRAMALESS_SHAPE", "Dramaless provider id selected")
  check(p:pipelineId() == "voxel", "current Dramaless voxel pipeline selected")
  check(p:module("Voxel3D") ~= nil and p:supportsFreeMove(), "Dramaless public modules accepted")
  p:installCompatibilityShim()
  check(mod:find("BATTLE_ART_VOXEL_FORK") == p.handle,
    "Dramaless is exposed only through Deep Dive's legacy internal lookup")
end

do
  defs = { st_voxel = {} }
  local mod = makeMod({ DRAMALESS_SHAPE = handle("DRAMALESS_SHAPE") })
  local p = VoxelProvider.new(mod)
  check(p:discover() and p:pipelineId() == "st_voxel", "legacy Dramaless st_voxel pipeline is probed")
end

do
  defs = { custom_voxel = {} }
  local mod = makeMod({ DRAMALESS_SHAPE = handle("DRAMALESS_SHAPE", "custom_voxel") })
  local p = VoxelProvider.new(mod)
  check(p:discover() and p:pipelineId() == "custom_voxel", "provider-published voxel pipeline is honored")
end

do
  defs = { voxel = {}, st_voxel = {} }
  local mod = makeMod({
    BATTLE_ART_VOXEL_FORK = handle("BATTLE_ART_VOXEL_FORK"),
    DRAMALESS_SHAPE = handle("DRAMALESS_SHAPE"),
  })
  local p = VoxelProvider.new(mod)
  check(p:discover() and p:id() == "BATTLE_ART_VOXEL_FORK", "Battle Art wins deterministic multi-provider precedence")
  check(p.conflict == true and mod.exports._dramaticProviderState.conflict == true,
    "multi-provider installation is surfaced as a conflict warning state")
end

do
  defs = {}
  local mod = makeMod({})
  local p = VoxelProvider.new(mod)
  check(p:discover() == false, "missing voxel provider is rejected cleanly")
end

do
  local rows = {
    { name = "Deep Dive + Battle Art", provider = "BATTLE_ART_VOXEL_FORK" },
    { name = "Deep Dive + Dramaless", provider = "DRAMALESS_SHAPE" },
    { name = "Crystal + Deep Dive + Battle Art", provider = "BATTLE_ART_VOXEL_FORK", crystal = true },
    { name = "Crystal + Deep Dive + Dramaless", provider = "DRAMALESS_SHAPE", crystal = true },
    { name = "Deep Dive + Sky Ride + Battle Art", provider = "BATTLE_ART_VOXEL_FORK", sky = true },
    { name = "Deep Dive + Sky Ride + Dramaless", provider = "DRAMALESS_SHAPE", sky = true },
    { name = "Crystal + Deep Dive + Sky Ride + Battle Art", provider = "BATTLE_ART_VOXEL_FORK", crystal = true, sky = true },
    { name = "Crystal + Deep Dive + Sky Ride + Dramaless", provider = "DRAMALESS_SHAPE", crystal = true, sky = true },
  }
  for _, row in ipairs(rows) do
    defs = { voxel = {} }
    local installed = {}
    installed[row.provider] = handle(row.provider)
    if row.crystal then installed.CRYSTAL_251 = { id = "CRYSTAL_251", exports = {} } end
    if row.sky then installed.DRAMATIC_SKY_RIDE = { id = "DRAMATIC_SKY_RIDE", exports = {} } end
    local provider = VoxelProvider.new(makeMod(installed))
    check(provider:discover() and provider:id() == row.provider and provider:supportsFreeMove(),
      row.name .. ": renderer remains available")
  end
end

do
  local file = assert(io.open(ROOT .. "main.lua", "rb"))
  local source = file:read("*a")
  file:close()
  check(source:find("voxelProvider:installCompatibilityShim()", 1, true) ~= nil,
    "bootstrap installs isolated renderer compatibility shim")
  check(source:find("function controller:findDiveMount()", 1, true) ~= nil,
    "bootstrap applies independent mount suitability policy")
  check(source:find("MountPolicy.isSuitable", 1, true) ~= nil,
    "bootstrap separates DIVE compatibility from mount suitability")
end
if failed > 0 then
  io.stderr:write(string.format("voxel provider contract: %d/%d failed\n", failed, total))
  os.exit(1)
end
print(string.format("voxel provider contract: %d checks passed", total))
