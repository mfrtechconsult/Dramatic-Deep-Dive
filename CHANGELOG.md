# Changelog

## 0.4.0-alpha.2

Depth ecology and release-hardening pass.

- Added depth-dependent wild encounter ecology for every Deep Dive map while preserving Gen1Recomp's vanilla encounter RNG and battle flow.
- Route 19 now changes from sunlit reef species to stronger channel encounters as the player descends.
- Route 20 now has coral-shelf, open-blue and deep Seafoam-rift encounter layers.
- Seafoam now changes between Ice Gallery and Blue Hole ecology.
- Route 21 now has sunlit, twilight and abyssal encounter layers, with stronger species and levels in the deepest water.
- Added validation that every legal swimming depth is covered by exactly ordered encounter bands with ten vanilla-compatible encounter slots.
- Added a standalone travel-graph validator for DDD map ids, unique indices, map block counts, underwater arrival rectangles, SurfaceZone containment and internal Route 20/Seafoam warps.
- Improved generated map previews with a phone-readable minimum canvas width and centered narrow maps.
- Kept the complete 0.4.0-alpha.1 four-map migration, setpieces, multi-map depth continuity and release preview generation.

## 0.4.0-alpha.1

Standalone Kanto underwater expansion milestone.

- Completed the migration of all four Kanto Dive underwater maps into Dramatic Deep Dive-owned `DDD_*` maps.
- Added `DDD_ROUTE19_REEF_PASSAGE`, `DDD_ROUTE20_SEAFLOOR` and `DDD_SEAFOAM_SUNKEN_CAVE` alongside `DDD_ROUTE21_ABYSS`.
- Added a generic underwater map registry so content registration is no longer hard-coded to Route 21.
- Added standalone DIVE/SURFACE links for Route 19 and Route 20, including the Seafoam channel.
- Added multi-map submerged-zone handling so Route 20 -> Seafoam -> Route 20 remains one continuous Deep Dive session.
- Added a transition guard that preserves depth, target depth and the original pre-dive Voxel camera mode across internal underwater map warps.
- Added authored continuous-depth volumes for every underwater map.
- Route 20 now reaches 253 usable depth and contains west/east shelves plus a deep Seafoam rift.
- Seafoam now has a 188-depth blue-hole chamber instead of behaving like a flat cave floor.
- Added full procedural 3D environment compositions to Route 19, Route 20 and Seafoam: coral, kelp, ruins, spires, crystals, fish schools, bubbles and light shafts.
- Added horizontal district discovery for Route 20 in addition to north/south district discovery.
- Added a dedicated 3D setpiece renderer with depth-aware collisions.
- Added a large shipwreck and hydrothermal smoker field to Route 20.
- Added a cave ceiling and physical stalactite field to Seafoam.
- Added a fossil rib cage and additional smoker field to Route 21's abyss.
- Added real-data map preview generation from the actual Lua maps, volumes, scenes and setpieces.
- GitHub releases now generate and attach PNG previews for all four underwater maps.
- Expanded release validation to cover every map, volume, district, scene object and setpiece.

## 0.3.0-alpha.1

Underwater environment and exploration pass.

- Added a dedicated procedural 3D scene layer rendered inside Battle Art Voxel Fork's real depth-tested world pass.
- Split Route 21 into five named underwater districts: Pallet Reef, Kelp Cathedral, Sunken Court, Abyssal Gate and Southern Gardens.
- Added large voxel landmarks: natural rock arches, stepped rock spires, ancient gates, broken walls, a ring of columns, a submerged shrine and a giant abyss gateway.
- Added deterministic procedural coral gardens and dense voxel kelp forests.
- Added crystal fields, bubble vents, 3D fish schools and light shafts.
- Added depth-aware underwater lighting.
- Added physical height-aware landmark collision.
- Added district discovery banners.
- Scoped Deep Dive geometry to the Voxel world pass.
- Added scene sanity validation to GitHub Actions.

## 0.2.0-alpha.1

Standalone architecture milestone.

- Removed the Kanto Dive runtime dependency and marked it as a conflict.
- Deep Dive now owns HM06 DIVE, DIVE compatibility, progression and DIVE/SURFACE travel.
- Migrated the Route 21 trench base into `DDD_ROUTE21_ABYSS`.
- Vendored the underwater tileset into the Deep Dive package.
- Expanded Route 21 to a 24-222 usable depth range.
- Added follower suspension/purge, first-person rider hiding, B-button swim boost and 1ST/3RD free-camera swimming.

## 0.1.0-alpha.1

First Route 19 proof of concept.

- Added continuous depth controls and persistent underwater state.
- Added `SwimVolume`, `DepthZone` and `SurfaceZone` runtime registry.
- Added procedural seafloor and translucent water-surface geometry.
- Added PokePC follower-based DIVE mount rendering and optional trainer rider.
