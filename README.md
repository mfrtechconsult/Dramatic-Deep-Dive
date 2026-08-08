# Dramatic Deep Dive

**Dramatic Deep Dive** is now a standalone Gen1Recomp underwater traversal mod. It is no longer an addon for Kanto Dive: it owns HM06 DIVE, DIVE/SURFACE travel, underwater maps and the free-swimming runtime itself.

Kanto Dive is still being used as a development reference for the first underwater map layouts, but it is **not required at runtime** and is marked as conflicting to avoid duplicate HM/map systems.

## Current version

`0.2.0-alpha.1` — standalone Route 21 abyss prototype.

## What changed from alpha.1

- removed the hard dependency on Kanto Dive;
- added Deep Dive-owned HM06 DIVE and compatibility data;
- added Deep Dive-owned DIVE/SURFACE travel service;
- imported the Route 21 trench layout into the standalone map `DDD_ROUTE21_ABYSS`;
- vendored the underwater tileset under a Deep Dive-owned asset path;
- expanded the Route 21 underwater column to more than 200 world pixels of usable depth;
- added a central abyss with shallow shelves, drops and side walls;
- added three independent DIVE/SURFACE windows under Route 21 south of Pallet Town;
- followers are fully suspended while underwater rather than remaining visible beside the mount;
- rider is hidden automatically in 1ST camera mode;
- 1ST and 3RD free cameras are both supported underwater;
- added smooth B-button swim boost through Battle Art Voxel Fork's existing FreeMove path;
- increased vertical-control speed for the much larger depth range.

## Controls

- movement: normal free-move controls in 1ST/3RD;
- `R2` / `Page Up`: ascend;
- `L2` / `Page Down`: dive deeper;
- hold `B`: smooth swim boost;
- `SURFACE`: available from the party submenu when inside an authored surface window.

## Route 21 abyss

The first full-size Deep Dive area sits below Route 21, immediately south of Pallet Town. It uses the same 20 × 90 movement-cell footprint as Route 21.

The water column is no longer a shallow fake altitude layer:

- water surface Y: `256`;
- minimum depth: `24`;
- deepest seafloor: `228`;
- usable deepest swimming depth: `222` after seabed clearance;
- north shelf: floor depth `96`;
- north drop: `140`;
- central side walls: `168`;
- central trench: `228`;
- south rise: `160`;
- south shelf: `108`.

This produces a real canyon profile: the player can descend from shelf water into a substantially deeper central abyss and climb back out without changing maps.

## Dependencies

- Gen1Recomp with Mod API 2;
- Battle Art Voxel Fork `>=1.7.6 <2.0.0`;
- PokePC Followers Voxel Merge.

Dramatic Sky Ride remains optional. Kanto Dive must not be installed at the same time because Deep Dive now replaces its HM06/travel responsibilities.

## Installation

Install the complete `dramatic_deep_dive` folder into Gen1Recomp's `mods` directory:

`mods/dramatic_deep_dive/manifest.json`

GitHub releases include a ready-to-install ZIP whose root is `dramatic_deep_dive/`.

## Progression

HM06 is owned by this mod. The Cinnabar Lab scientist progression used by the earlier Kanto Dive prototype is retained for now: after the Volcano Badge, he gives HM06 DIVE without replacing the vanilla TM35 interaction.

## Project direction

Dramatic Deep Dive is intended to become the normal DIVE implementation for this mod ecosystem. Future underwater maps will be authored directly for its continuous-depth model rather than treating 3D swimming as a presentation layer over a separate 2D DIVE mod.

Kanto Dive remains useful as source material while its existing Route 19/20/21 and Seafoam maps are migrated, but those maps will progressively receive `DDD_*` ids and native `SwimVolume`/`DepthZone` data.
