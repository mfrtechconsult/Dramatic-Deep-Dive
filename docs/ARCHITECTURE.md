# Architecture

Dramatic Deep Dive is a standalone gameplay system. Kanto Dive is now only a migration reference for early map layouts.

## Ownership

Dramatic Deep Dive owns:

- HM06 DIVE and Pokémon compatibility;
- DIVE/SURFACE party actions and travel sessions;
- underwater map registration;
- continuous free-swim depth;
- `SwimVolume`, `DepthZone` and `SurfaceZone` authoring;
- underwater follower suspension;
- mount/rider presentation;
- 1ST/3RD camera integration and swim boost;
- Voxel seafloor/surface companion geometry.

Battle Art Voxel Fork remains the renderer/provider dependency. PokePC Followers Voxel Merge remains the mount-art dependency.

## Travel layer

`src/DiveTravel.lua` maps authored surface rectangles to DDD-owned underwater maps. It handles the party-menu `DIVE` and `SURFACE` verbs, persists the travel session and keeps the engine's Surf state active underwater for compatibility.

The controller listens only to Deep Dive events:

- `mod.dramatic_deep_dive.entered`;
- `mod.dramatic_deep_dive.surfaced`.

No Kanto Dive event or export is required.

## Continuous-depth controller

`src/DeepDive.lua` treats depth as a continuous positive distance below the water surface. The visual world lift is `surfaceHeight - depth`. L2/R2 change the target depth continuously while local seafloor depth clamps the maximum.

Horizontal movement is delegated to Battle Art Voxel Fork's existing `FreeMove`. Deep Dive temporarily replaces only the collision verdict for cells inside its authored `SwimVolume`, so the free-camera movement remains the same mechanism used by Dramatic Sky Ride.

## Followers

`src/FollowerBridge.lua` uses the same entity-detection strategy as Dramatic Sky Ride. Native Pikachu, PokePC and Followers EX entities are removed from both `ow.entities` and `ow.npcs` while submerged. They are not rendered beside the underwater mount.

## Route 21 reference area

`DDD_ROUTE21_ABYSS` is the first standalone map. Its horizontal layout originates from the earlier Kanto Dive Route 21 trench prototype, but the map id, tileset asset, travel links and 3D depth model now belong to Deep Dive.

Its central canyon reaches a floor depth of 228 world pixels, with a maximum swimmer depth of 222 after clearance.
