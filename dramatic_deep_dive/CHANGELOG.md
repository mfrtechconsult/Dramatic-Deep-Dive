# Changelog

## 0.6.0

- Added animated Pokemon Stadium 2 models for nearby visible underwater wildlife, with automatic 2D fallback when a model or backend is unavailable.
- Added Pokédex-derived compressed physical scaling, morphology corrections, movement-aware animation selection, smooth underwater orientation and bounded nearest-model LOD.
- Added support for multiple simultaneous swimmers of the same species with independent Stadium rig instances.
- Added shared Crystal 251 Stadium 2 DSM cache support and cache bootstrap when the required importer stack is available.
- Added official legacy `DRAMATIC_SHAPE` support alongside Battle Art Voxel Fork and Dramaless Shape.
- When `DRAMATIC_SHAPE` and `STADIUM_OVERWORLD_MODELS` are both enabled, Deep Dive delegates underwater Pokemon rendering to the existing Stadium renderer instead of competing for VoxelScene ownership.
- Hardened startup so HM08 progression is installed even when voxel provider discovery fails; renderer problems no longer silently remove the Cinnabar HM08 researcher.
- Retained the Full-Kanto free-depth underwater world, visible-only Wilds encounter policy, salvage, submerged links and HM06/HM07/HM08 integration from 0.5.0.
- GitHub release packaging now produces a launcher-ready ZIP with `manifest.json` and `main.lua` at archive root plus a SHA-256 checksum.

## 0.5.0

- Promoted the Full-Kanto generated seabed overhaul to the stable release line.
- Every real Kanto water area now participates in the generated DIVE/SURFACE atlas; the old surface DIVE mask is removed.
- Added broad underwater geography with profile-based scaling: open ocean and Cinnabar reach 3x linear scale, while coasts, harbors and major caves reach 2x.
- Added continuous underwater hydrology beneath bridges, docks and pontoons without allowing DIVE/SURFACE from those structures.
- Added seamless underwater route connections that preserve active depth, target depth, mount state and free-camera state.
- Added shore-derived bathymetry, biome-aware geology, generated landmarks, submerged cave/harbor portals and sparse salvage.
- With Wilds of Kanto active, invisible/random underwater encounters are disabled and battles come from visible Pokedex-scaled overworld Pokemon only.
- Retained Battle Art Voxel Fork, Dramaless Shape, Dramatic Sky Ride, Wild Skies, Crystal 251, HM06 WHIRLPOOL, HM07 WATERFALL and HM08 DIVE compatibility.
- HM08 DIVE is now given immediately by a fixed researcher outside, just left of the Cinnabar Lab, with no badge or story requirement.
- Added automated launcher-ready GitHub releases with `manifest.json` and `main.lua` at the ZIP root.

## 0.4.0

- Stable independent Deep Dive runtime with free vertical swimming, visible underwater wildlife, depth-aware encounters and compatibility with the Gen1Recomp Sky/Wilds ecosystem.
