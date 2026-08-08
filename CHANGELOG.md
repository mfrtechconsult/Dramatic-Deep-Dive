# Changelog

## 0.3.0-alpha.1

Underwater environment and exploration pass.

- Added a dedicated procedural 3D scene layer rendered inside Battle Art Voxel Fork's real depth-tested world pass.
- Split Route 21 into five named underwater districts: Pallet Reef, Kelp Cathedral, Sunken Court, Abyssal Gate and Southern Gardens.
- Added large voxel landmarks: natural rock arches, stepped rock spires, ancient gates, broken walls, a ring of columns, a submerged shrine and a giant abyss gateway.
- Added 44+ northern reef corals and a larger southern coral garden with deterministic procedural branching.
- Added dense voxel kelp forests with tall segmented stalks and side leaves.
- Added crystal fields and hand-placed crystal clusters around the ruins and central abyss.
- Added animated bubble vents rising through the water column.
- Added four animated fish schools moving through 3D world space.
- Added translucent volumetric-style light shafts descending from the water surface.
- Added depth-aware underwater lighting: shallow water stays bright cyan while the central abyss becomes progressively darker and bluer.
- Added physical 3D landmark collision. Tall ruins block swimming at their height but can be crossed by swimming above them.
- Added district discovery banners when entering a new Route 21 underwater biome.
- Scoped Deep Dive world geometry to the Voxel world pass so it cannot leak into Voxel battle scenes.
- Added scene sanity validation to GitHub Actions in addition to Lua/JSON syntax checks.

## 0.2.0-alpha.1

Standalone architecture milestone.

- Removed the Kanto Dive runtime dependency and marked it as a conflict.
- Deep Dive now owns HM06 DIVE, DIVE compatibility, progression and DIVE/SURFACE travel.
- Migrated the Route 21 trench base into `DDD_ROUTE21_ABYSS`.
- Vendored the underwater tileset into the Deep Dive package.
- Expanded Route 21 to a 24–222 usable depth range.
- Added a 228-depth central abyss plus north/south shelves, drops and side walls.
- Added the three Route 21 DIVE/SURFACE regions below Pallet Town.
- Added follower suspension/purge based on the Dramatic Sky Ride follower bridge.
- Added first-person rider hiding.
- Added smooth B-button swim boost through Battle Art Voxel Fork FreeMove.
- Added support for both 1ST and 3RD free-camera swimming.
- Kept continuous seafloor collision and procedural Voxel shelf/cliff geometry.

## 0.1.0-alpha.1

First Route 19 proof of concept.

- Added Kanto Dive event integration.
- Added forced Voxel 3RD underwater mode.
- Added continuous depth controls and persistent underwater state.
- Added `SwimVolume`, `DepthZone` and `SurfaceZone` runtime registry.
- Added procedural seafloor and translucent water-surface geometry.
- Added PokePC follower-based DIVE mount rendering and optional trainer rider.
