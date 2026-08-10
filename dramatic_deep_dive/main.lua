local function loadModule(mod, relativePath)
  local source, readError = mod:read(relativePath)
  if not source then
    mod.log:error("Could not read %s: %s", relativePath, tostring(readError))
    return nil
  end
  -- Gen1Recomp 0.1.75 enforces mod.<MANIFEST_ID>.* event namespaces.
  source = source:gsub("mod%.dramatic_deep_dive%.", "mod.DRAMATIC_DEEP_DIVE.")
  local compiler = loadstring or load
  local chunk, loadError = compiler(source, "@" .. mod.path .. "/" .. relativePath)
  if not chunk then
    mod.log:error("Could not compile %s: %s", relativePath, tostring(loadError))
    return nil
  end
  local ok, value = pcall(chunk)
  if not ok then
    mod.log:error("Could not initialize %s: %s", relativePath, tostring(value))
    return nil
  end
  return value
end

return function(mod)
  local Content = loadModule(mod, "src/Content.lua")
  local VoxelProvider = loadModule(mod, "src/VoxelProvider.lua")
  local Crystal251Compat = loadModule(mod, "src/Crystal251Compat.lua")
  local JohtoWaterMoves = loadModule(mod, "src/JohtoWaterMoves.lua")
  local HMForgetGuard = loadModule(mod, "src/HMForgetGuard.lua")
  local HMShowcase = loadModule(mod, "src/HMShowcase.lua")
  local MountPolicy = loadModule(mod, "src/MountPolicy.lua")
  local VolumeRegistry = loadModule(mod, "src/VolumeRegistry.lua")
  local KantoWaterAtlas = loadModule(mod, "src/KantoWaterAtlas.lua")
  local SeabedGenerator = loadModule(mod, "src/SeabedGenerator.lua")
  local SeabedLandmarks = loadModule(mod, "src/SeabedLandmarks.lua")
  local SurfaceLandmarkAnchors = loadModule(mod, "src/SurfaceLandmarkAnchors.lua")
  local SubmergedWarpLinks = loadModule(mod, "src/SubmergedWarpLinks.lua")
  local SeamHandoff = loadModule(mod, "src/SeamHandoff.lua")
  local FollowerSprites = loadModule(mod, "src/FollowerSprites.lua")
  local FollowerBridge = loadModule(mod, "src/FollowerBridge.lua")
  local DiveTravel = loadModule(mod, "src/DiveTravel.lua")
  local StableDepthTick = loadModule(mod, "src/StableDepthTick.lua")
  local SurfaceDiveMarkers = loadModule(mod, "src/SurfaceDiveMarkers.lua")
  local Progression = loadModule(mod, "src/Progression.lua")
  local DeepDive = loadModule(mod, "src/DeepDive.lua")
  local SceneDecor = loadModule(mod, "src/SceneDecor.lua")
  local SetpieceDecor = loadModule(mod, "src/SetpieceDecor.lua")
  local SceneGameplay = loadModule(mod, "src/SceneGameplay.lua")
  local UnderwaterLighting = loadModule(mod, "src/UnderwaterLighting.lua")
  local SubmergedTransitionGuard = loadModule(mod, "src/SubmergedTransitionGuard.lua")
  local DiveTransition = loadModule(mod, "src/DiveTransition.lua")
  local DepthEncounters = loadModule(mod, "src/DepthEncounters.lua")
  local UnderwaterWildlife = loadModule(mod, "src/UnderwaterWildlife.lua")
  local UnderwaterIntercept = loadModule(mod, "src/UnderwaterIntercept.lua")
  local Salvage = loadModule(mod, "src/Salvage.lua")
  local AmbientLOD = loadModule(mod, "src/AmbientLOD.lua")
  local VoxelRenderer = loadModule(mod, "src/VoxelRenderer.lua")

  local volumeDefinitions = loadModule(mod, "data/volumes.lua")
  local diveDefinitions = loadModule(mod, "data/dive_links.lua")
  local sceneDefinitions = loadModule(mod, "data/scenes.lua")
  local setpieceDefinitions = loadModule(mod, "data/setpieces.lua")
  local depthEncounterDefinitions = loadModule(mod, "data/depth_encounters.lua")
  local salvageDefinitions = loadModule(mod, "data/salvage.lua")
  local seabedProfiles = loadModule(mod, "data/seabed_profiles.lua")
  local seabedLandmarkRules = loadModule(mod, "data/seabed_landmarks.lua")

  if not (Content and VoxelProvider and Crystal251Compat and JohtoWaterMoves
      and HMForgetGuard and HMShowcase and MountPolicy and VolumeRegistry
      and KantoWaterAtlas and SeabedGenerator and SeabedLandmarks
      and SurfaceLandmarkAnchors and SubmergedWarpLinks and SeamHandoff
      and FollowerSprites and FollowerBridge and DiveTravel and StableDepthTick
      and SurfaceDiveMarkers and Progression and DeepDive and SceneDecor
      and SetpieceDecor and SceneGameplay and UnderwaterLighting
      and SubmergedTransitionGuard and DiveTransition and DepthEncounters
      and UnderwaterWildlife and UnderwaterIntercept and Salvage and AmbientLOD
      and VoxelRenderer and volumeDefinitions and diveDefinitions
      and sceneDefinitions and setpieceDefinitions and depthEncounterDefinitions
      and salvageDefinitions and seabedProfiles and seabedLandmarkRules) then
    return
  end

  if not Content.register(mod) then return end

  -- Full-Kanto generation pipeline. The surface game's real water cells are the
  -- only source of navigable coverage; all later passes decorate that topology.
  local atlas = KantoWaterAtlas.new(mod, seabedProfiles):build()
  local generated = SeabedGenerator.new(mod, atlas, seabedProfiles):build()
  local landmarkPass = SeabedLandmarks.new(mod, atlas, seabedLandmarkRules)
  local landmarkMapCount = landmarkPass:apply(generated.scenes)
  local surfaceAnchorPass = SurfaceLandmarkAnchors.new(mod, atlas)
  local surfaceAnchorMaps, surfaceAnchorCount = surfaceAnchorPass:apply(generated.scenes)
  local submergedWarpLinks = SubmergedWarpLinks.new(mod, atlas, generated.scenes)
  local submergedPortalCount = submergedWarpLinks.count or 0

  local function mergeGenerated(target, source)
    for id, definition in pairs(source or {}) do target[id] = definition end
  end
  mergeGenerated(volumeDefinitions, generated.volumes)
  mergeGenerated(diveDefinitions, generated.dives)
  mergeGenerated(sceneDefinitions, generated.scenes)
  mergeGenerated(setpieceDefinitions, generated.setpieces)
  mergeGenerated(depthEncounterDefinitions, generated.encounters)
  mergeGenerated(salvageDefinitions, generated.salvage)

  if mod.log then
    mod.log:info(
      "Kanto water atlas: %d maps, %d water cells, %d connected bodies, %d edge seams, %d submerged portals, %d landmark maps, %d surface anchors",
      atlas.stats.maps or 0, atlas.stats.waterCells or 0,
      atlas.stats.components or 0, atlas.stats.seams or 0,
      submergedPortalCount, landmarkMapCount or 0, surfaceAnchorCount or 0)
  end

  Crystal251Compat.install(mod)

  local johtoWater = JohtoWaterMoves.install(mod, {
    whirlpoolBadge = "VOLCANOBADGE",
    waterfallBadge = "EARTHBADGE",
    whirlpools = {
      { id = "route20_seafoam_whirlpool", mapId = "ROUTE_20", x = 49, y = 12, width = 2, height = 4 },
    },
    waterfalls = {
      { id = "route21_central_waterfall", mapId = "ROUTE_21", x = 3, y = 50, width = 14, height = 2 },
    },
  })
  if not johtoWater or not HMForgetGuard.install(mod) then return end

  HMShowcase.install(mod, {
    ROUTE_20 = {
      id = "hm06_whirlpool_route20", move = "WHIRLPOOL",
      text = "HM06 WHIRLPOOL TEST\nA whirlpool blocks the\nSeafoam channel.\fFace it while SURFing\nand use WHIRLPOOL.",
    },
    ROUTE_21 = {
      id = "hm07_waterfall_route21", move = "WATERFALL",
      text = "HM07 WATERFALL TEST\nA waterfall blocks the\ncentral current.\fDescend freely, then\nuse WATERFALL to climb.",
    },
  })

  -- Kept as a functional index only. Full-Kanto mode deliberately renders no
  -- dark surface mask: all detected water is intended to be diveable.
  local surfaceDiveMarkers = SurfaceDiveMarkers.new(mod, diveDefinitions)
  if not surfaceDiveMarkers:install() then return end

  local voxelProvider = VoxelProvider.new(mod)
  if not voxelProvider:discover() then return end
  voxelProvider:installCompatibilityShim()

  local registry = VolumeRegistry.new(mod)
  for id, definition in pairs(volumeDefinitions) do
    local volume, err = registry:register(id, definition, mod.id)
    if not volume then
      mod.log:error("Could not register deep-dive volume %s: %s", tostring(id), tostring(err))
      return
    end
  end

  local sprites = FollowerSprites.new(mod)
  local followerBridge = FollowerBridge.new(mod)
  local travel = DiveTravel.new(mod, diveDefinitions)
  local sceneDecor = SceneDecor.new(mod, registry, sceneDefinitions)
  local setpieceDecor = SetpieceDecor.new(mod, registry, setpieceDefinitions)
  local voxelRenderer = VoxelRenderer.new(mod, registry, sceneDecor, setpieceDecor, voxelProvider)
  local controller = DeepDive.new(mod, registry, sprites, voxelRenderer,
    followerBridge, travel, MountPolicy, voxelProvider)
  SeamHandoff.install(mod, controller, registry)

  local Game = require("src.core.Game")
  local function knowsDive(mon)
    for _, move in ipairs(mon and mon.moves or {}) do
      local id = type(move) == "table" and move.id or move
      if id == "DIVE" then return true end
    end
    return false
  end
  function controller:isSuitableMount(mon)
    if not (mon and knowsDive(mon)) then return false end
    local def = Game.data and Game.data.pokemon and Game.data.pokemon[mon.species]
    return MountPolicy.isSuitable(mon.species, def) == true
  end
  function controller:findDiveMount()
    local party = Game.save and Game.save.party or {}
    local remembered = self.state.mountSpecies
    if remembered then
      for _, mon in ipairs(party) do
        if mon.species == remembered and self:isSuitableMount(mon) then return mon end
      end
    end
    for _, mon in ipairs(party) do
      if self:isSuitableMount(mon) then return mon end
    end
    return nil
  end
  local originalEnsureRider = controller.ensureRider
  function controller:ensureRider()
    if self.state.active and not self.state.mountSprite then
      self:removeRider()
      return
    end
    return originalEnsureRider(self)
  end

  local sceneGameplay = SceneGameplay.new(mod, controller, voxelRenderer)
  local underwaterLighting = UnderwaterLighting.new(mod, controller, voxelProvider)
  local transitionGuard = SubmergedTransitionGuard.new(mod, controller, registry)
  local diveTransition = DiveTransition.new(mod, controller, registry)
  local depthEncounters = DepthEncounters.new(mod, controller, depthEncounterDefinitions)
  local underwaterWildlife = UnderwaterWildlife.new(
    mod, controller, registry, sprites, depthEncounterDefinitions)
  local underwaterIntercept = UnderwaterIntercept.new(mod, controller, underwaterWildlife)
  depthEncounters:setWildlife(underwaterWildlife)
  local salvage = Salvage.new(mod, controller, salvageDefinitions)
  local ambientLOD = AmbientLOD.new(mod, sceneDecor)

  controller.travel = travel
  travel:setTransition(diveTransition)
  voxelRenderer:setController(controller)

  travel:install()
  transitionGuard:install()
  Progression.install(mod)
  controller:install()
  StableDepthTick.install(mod, controller)
  submergedWarpLinks:install(controller)
  voxelRenderer:install()
  underwaterLighting:install()
  sceneGameplay:install()
  depthEncounters:install()
  underwaterWildlife:install()
  underwaterIntercept:install()
  ambientLOD:install()
  salvage:install()
  diveTransition:install()

  mod.exports.voxelProvider = function() return voxelProvider:id(), voxelProvider:pipelineId() end
  mod.exports.isActive = function() return controller:isActive() end
  mod.exports.isUnderwater = function() return controller:isActive() end
  mod.exports.currentDepth = function() return controller:currentDepth() end
  mod.exports.targetDepth = function() return controller:targetDepth() end
  mod.exports.currentVolume = function() return controller:currentVolume() end
  mod.exports.floorDepthAt = function(mapId, x, y) return registry:floorDepthAt(mapId, x, y) end
  mod.exports.canSwimAt = function(mapId, x, y) return registry:contains(mapId, x, y) end
  mod.exports.allWaterDiveable = function() return true end
  mod.exports.surfaceDiveMaskEnabled = function() return false end
  mod.exports.waterAtlasStats = function()
    local portalStats = submergedWarpLinks:stats()
    return {
      maps = atlas.stats.maps,
      waterCells = atlas.stats.waterCells,
      components = atlas.stats.components,
      seams = atlas.stats.seams,
      submergedPortals = portalStats.portals,
      submergedPortalTransitions = portalStats.transitions,
      landmarkMaps = landmarkMapCount,
      surfaceAnchorMaps = surfaceAnchorMaps,
      surfaceAnchors = surfaceAnchorCount,
    }
  end
  mod.exports.underwaterMapFor = function(surfaceMapId) return atlas:underwaterMapId(surfaceMapId) end
  mod.exports.surfaceMapFor = function(underwaterMapId) return atlas:surfaceMapId(underwaterMapId) end
  mod.exports.canDiveHere = function(game) return travel:canDiveHere(game) end
  mod.exports.canSurfaceHere = function(game) return travel:canSurfaceHere(game) end
  mod.exports.getDiveMarkers = function(mapId) return surfaceDiveMarkers:cellsFor(mapId) end
  mod.exports.getVisualDiveMarkers = function() return {} end
  mod.exports.submergedWarpStats = function() return submergedWarpLinks:stats() end
  mod.exports.currentDistrict = function()
    return sceneGameplay.districtId, sceneGameplay.districtName
  end
  mod.exports.currentEncounterBand = function()
    local band, mapId = depthEncounters:currentBand()
    return band and band.id or nil, mapId
  end
  mod.exports.oceanLifeStats = function() return underwaterWildlife:stats() end
  mod.exports.oceanInterceptStats = function() return underwaterIntercept:stats() end
  mod.exports.ambientLODStats = function() return ambientLOD:stats() end
  mod.exports.isTransitioning = function() return diveTransition:isActive() end
  mod.exports.salvageRemaining = function(mapId) return salvage:remaining(mapId) end
  mod.exports.registerVolume = function(id, definition, owner)
    return registry:register(id, definition, owner or "external")
  end
  mod.exports.requestDepth = function(depth) return controller:requestDepth(depth) end

  mod.exports.canWhirlpoolHere = function(game) return johtoWater:canWhirlpool(game) end
  mod.exports.canWaterfallHere = function(game) return johtoWater:canWaterfall(game) end
  mod.exports.registerWhirlpool = function(definition) return johtoWater:registerWhirlpool(definition) end
  mod.exports.registerWaterfall = function(definition) return johtoWater:registerWaterfall(definition) end

  mod.exports.wildsCompatibility = {
    wildsId = "overworld_wild_spawns",
    detected = function() return travel:wildsInstalled() end,
    hookGuardReady = false,
    ensureUpdateHook = nil,
    hookRecoveries = function() return 0 end,
    updateHeartbeat = function() return 0 end,
    protectedWrappers = function() return 0 end,
    rootUpdate = function() return nil end,
    ownsUpdate = function() return false end,
  }
end
