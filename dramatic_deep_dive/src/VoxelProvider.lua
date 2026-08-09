local Pipelines = require("src.render.Pipelines")

local VoxelProvider = {}
VoxelProvider.__index = VoxelProvider

local CANDIDATES = {
  {
    id = "BATTLE_ART_VOXEL_FORK",
    label = "Battle Art Voxel Fork",
    pipelines = { "voxel", "st_voxel" },
    primary = true,
  },
  {
    id = "DRAMALESS_SHAPE",
    label = "Dramaless Shape",
    pipelines = { "st_voxel", "voxel" },
  },
}

local function find(mod, id)
  if not (mod and mod.find) then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function publicLib(handle)
  local exports = handle and handle.exports
  local lib = exports and exports.lib
  if type(lib) == "table" and type(lib.require) == "function" then return lib end
  return nil
end

local function pipelineExists(id)
  local ok, value = pcall(Pipelines.get, id)
  return ok and value ~= nil
end

function VoxelProvider.new(mod)
  return setmetatable({
    mod = mod,
    handle = nil,
    providerId = nil,
    providerLabel = nil,
    lib = nil,
    pipelineHint = nil,
    pipelineCandidates = nil,
    installed = {},
    conflict = false,
  }, VoxelProvider)
end

function VoxelProvider:discover()
  local installed = {}
  for _, candidate in ipairs(CANDIDATES) do
    local handle = find(self.mod, candidate.id)
    local lib = publicLib(handle)
    if handle and lib then
      installed[#installed + 1] = { candidate = candidate, handle = handle, lib = lib }
    end
  end

  self.installed = installed
  self.conflict = #installed > 1
  local selected = installed[1]
  if not selected then
    if self.mod and self.mod.log then
      self.mod.log:error("Dramatic Deep Dive needs Battle Art Voxel Fork or Dramaless Shape; neither public Voxel API was found")
    end
    return false
  end

  self.handle = selected.handle
  self.providerId = selected.candidate.id
  self.providerLabel = selected.candidate.label
  self.lib = selected.lib
  self.pipelineCandidates = selected.candidate.pipelines

  local exports = selected.handle.exports or {}
  local published = exports.pipelines
  if type(published) == "table" and type(published.voxel) == "string" then
    self.pipelineHint = published.voxel
  end

  if self.conflict and self.mod and self.mod.log then
    self.mod.log:warn("multiple voxel providers detected; using %s and ignoring the others for Deep Dive", tostring(self.providerLabel))
  elseif self.mod and self.mod.log then
    self.mod.log:info("Deep Dive voxel provider: %s", tostring(self.providerLabel))
  end

  if self.mod then
    self.mod.exports = self.mod.exports or {}
    self.mod.exports._dramaticProviderState = {
      handle = self.handle,
      id = self.providerId,
      version = self.handle and (self.handle.version or (self.handle.exports and self.handle.exports.version)) or nil,
      voxelPipeline = self:pipelineId(),
      conflict = self.conflict,
      battleArt = self.providerId == "BATTLE_ART_VOXEL_FORK" and self.handle or nil,
      dramaless = self.providerId == "DRAMALESS_SHAPE" and self.handle or nil,
    }
  end
  return true
end

function VoxelProvider:installCompatibilityShim()
  if not (self.mod and self.mod.find and self.handle) then return false end
  if self.mod._dramaticDeepDiveOriginalFind then return true end
  local originalFind = self.mod.find
  self.mod._dramaticDeepDiveOriginalFind = originalFind
  local selected = self.handle
  local providerId = self.providerId
  self.mod.find = function(modSelf, id)
    if id == "BATTLE_ART_VOXEL_FORK" and providerId == "DRAMALESS_SHAPE" then
      return selected
    end
    return originalFind(modSelf, id)
  end
  return true
end

function VoxelProvider:id()
  return self.providerId
end

function VoxelProvider:label()
  return self.providerLabel
end

function VoxelProvider:pipelineId()
  if self.pipelineHint and pipelineExists(self.pipelineHint) then return self.pipelineHint end
  for _, id in ipairs(self.pipelineCandidates or {}) do
    if pipelineExists(id) then return id end
  end
  return self.pipelineHint or (self.pipelineCandidates and self.pipelineCandidates[1]) or "voxel"
end

function VoxelProvider:module(name)
  if not (self.lib and type(self.lib.require) == "function") then return nil end
  local ok, value = pcall(self.lib.require, name)
  return ok and value or nil
end

function VoxelProvider:supportsFreeMove()
  return self:module("Voxel3D") ~= nil
    and self:module("FreeMove") ~= nil
    and self:module("FirstPerson") ~= nil
end

return VoxelProvider
