# Changelog

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
