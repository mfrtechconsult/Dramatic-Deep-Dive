# Changelog

## 0.1.0-alpha.1

First playable Route 19 prototype.

- Added Kanto Dive event integration.
- Added forced Voxel 3RD underwater mode with camera restoration on exit.
- Added continuous L2/R2 and Page Down/Page Up depth control.
- Added persistent underwater depth state.
- Added `SwimVolume`, `DepthZone` and `SurfaceZone` runtime registry.
- Added Route 19 west/east shelves and central deep channel.
- Added collision override inside authored swim volumes.
- Added seafloor depth clamp and smooth automatic rise over shallower terrain.
- Added procedural 3D seafloor shelves/cliffs aligned with `DepthZones`.
- Added a translucent overhead water-surface plane inside the Voxel scene.
- Added PokePC follower-based DIVE mount rendering.
- Added optional trainer rider and depth HUD.
- Added `SURFACE AVAILABLE` integration hint without taking ownership of Kanto Dive's SURFACE action.
