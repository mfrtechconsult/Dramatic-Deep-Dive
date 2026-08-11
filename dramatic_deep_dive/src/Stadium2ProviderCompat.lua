local Stadium2ProviderCompat = {}

local function publicLib(handle)
  local exports = handle and handle.exports
  local lib = exports and exports.lib
  return type(lib) == "table" and type(lib.require) == "function" and lib or nil
end

local function safeFind(mod, id)
  if not (mod and mod.find) then return nil end
  local ok, handle = pcall(mod.find, mod, id)
  return ok and handle or nil
end

local function req(lib, name)
  if not lib then return nil end
  local ok, value = pcall(lib.require, name)
  return ok and value or nil
end

local function sameFormat(a, b)
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
  for i = 1, #a do
    local x, y = a[i], b[i]
    if type(x) ~= "table" or type(y) ~= "table" then return false end
    if x[1] ~= y[1] or x[2] ~= y[2] or x[3] ~= y[3] then return false end
  end
  return true
end

function Stadium2ProviderCompat.install(service, mod)
  if not service then return false end

  service.discover = function(self)
    local state = mod.exports and mod.exports._dramaticProviderState
    local activeHandle = state and state.handle
    local activeLib = publicLib(activeHandle)
    if not activeLib then return false end

    -- Rendering must always use the provider Deep Dive already selected, so
    -- its VoxelScene, depth buffer, shadow map and billboard hooks remain one
    -- coherent pipeline.
    local activeVoxel = req(activeLib, "Voxel3D")
    local activeMat4 = req(activeLib, "Mat4")
    local activeBillboards = req(activeLib, "SpriteBillboards")
    local activeShadow = req(activeLib, "ShadowMap")
    if not (activeVoxel and activeMat4 and activeBillboards and activeShadow) then
      return false
    end

    -- Prefer the active provider's Stadium stack. Battle Art intentionally
    -- does not expose StadiumRig; in that configuration borrow only the CPU
    -- Stadium rig/parser from Dramaless (or Dramatic Shape) while still
    -- drawing through Battle Art's active Voxel3D/ShadowMap pipeline.
    local rigLib, rigProvider = activeLib, state and state.id or "active"
    local rig = req(rigLib, "StadiumRig")
    local pack = req(rigLib, "StadiumPack")

    if not (type(rig) == "table" and type(rig.new) == "function"
        and type(pack) == "table" and type(pack.tracks) == "function") then
      local candidates = {
        { "DRAMALESS_SHAPE", "DRAMALESS_SHAPE" },
        { "dramaticless_shape", "DRAMALESS_SHAPE" },
        { "DRAMATIC_SHAPE", "DRAMATIC_SHAPE" },
        { "dramatic_shape", "DRAMATIC_SHAPE" },
      }
      rigLib, rig, pack, rigProvider = nil, nil, nil, nil
      for _, candidate in ipairs(candidates) do
        local lib = publicLib(safeFind(mod, candidate[1]))
        local candidateRig = req(lib, "StadiumRig")
        local candidatePack = req(lib, "StadiumPack")
        local candidateVoxel = req(lib, "Voxel3D")
        if type(candidateRig) == "table" and type(candidateRig.new) == "function"
            and type(candidatePack) == "table" and type(candidatePack.tracks) == "function"
            and candidateVoxel and sameFormat(activeVoxel.FORMAT, candidateVoxel.FORMAT) then
          rigLib, rig, pack, rigProvider = lib, candidateRig, candidatePack, candidate[2]
          break
        end
      end
    end

    if not (rig and pack) then
      if mod.log then
        mod.log:warn("Stadium 2 underwater models need a StadiumRig backend. Install/enable Dramaless Shape when Battle Art is the active voxel provider.")
      end
      return false
    end

    self.lib = rigLib
    self.Rig = rig
    self.ProviderPack = pack
    self.Mat4 = activeMat4
    self.Voxel3D = activeVoxel
    self.SpriteBillboards = activeBillboards
    self.ShadowMap = activeShadow
    self.rigProviderId = rigProvider

    if mod.log then
      mod.log:info("Stadium 2 underwater provider bridge: render=%s rig=%s",
        tostring(state and state.id or "active"), tostring(rigProvider))
    end
    return true
  end

  return true
end

return Stadium2ProviderCompat
