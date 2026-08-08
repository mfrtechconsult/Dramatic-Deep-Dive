# Changelog

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
