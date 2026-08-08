# Architecture

Dramatic Deep Dive deliberately separates progression, 3D presentation and authored underwater geometry.

## Kanto Dive

Owns:

- HM06 DIVE;
- badge/progression checks;
- surface-to-underwater and underwater-to-surface links;
- underwater map registration;
- DIVE and SURFACE field-menu actions.

Deep Dive listens to `mod.kanto_dive.entered` and `mod.kanto_dive.surfaced` and also recovers from `map.entered` when a save is loaded underwater.

## Battle Art Voxel Fork

Owns the Voxel renderer and free-roam camera/movement implementation. Deep Dive forces pipeline level `7` (`3RD`) for the duration of an underwater session and restores the previous live level on exit.

## Deep Dive controller

Owns:

- continuous depth and target depth;
- L2/R2 + Page Down/Page Up vertical input;
- player world lift relative to the authored surface height;
- swim-volume collision policy;
- seafloor depth clamp;
- underwater mount/rider presentation;
- HUD and persistence.

## Volume registry

`data/volumes.lua` contains authored geometry independent of controller logic. External mods may call `DRAMATIC_DEEP_DIVE.exports.registerVolume(...)` to add maps without editing this repository.

## Voxel rendering bridge

Alpha.1 uses Gen1Recomp's existing `Player:pose()` lift contract, the same seam used successfully by Dramatic Sky Ride, and Battle Art Voxel Fork's exported `Voxel3D` module. Deep Dive wraps `Voxel3D.endScene()` and, while its underwater state is active, draws companion geometry before the provider closes the 3D pass.

The bridge currently injects:

- a deepest default seafloor plane per `SwimVolume`;
- raised shelf tops and vertical cliff faces for shallower `DepthZones`;
- a translucent surface plane at the authored `surfaceHeight`.

The geometry uses world-pixel coordinates directly and does not alter Battle Art Voxel Fork files or its terrain mesher. A later rendering pass can replace the lightweight surface plane with the fork's reflective water shader without changing the swimming controller or authoring format.
