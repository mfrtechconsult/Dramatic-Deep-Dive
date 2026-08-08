# Dramatic Deep Dive

**Dramatic Deep Dive** is a standalone Gen1Recomp underwater traversal mod. It owns HM06 DIVE, DIVE/SURFACE travel, underwater maps, continuous-depth swimming and the 3D underwater environment itself.

Kanto Dive is still used as a development reference for the earliest map layouts, but it is **not required at runtime** and conflicts with Dramatic Deep Dive to avoid duplicate HM/map systems.

## Current version

`0.3.0-alpha.1` — living Route 21 environment pass.

## Route 21 is now a real 3D underwater space

`DDD_ROUTE21_ABYSS` remains the 20 × 90 movement-cell map below Route 21 south of Pallet Town, but it is no longer just a deep floor with a few shelves.

The map now contains five visually distinct exploration districts:

- **PALLET REEF** — bright shallow reef, dense branching coral and a large natural rock arch;
- **KELP CATHEDRAL** — tall voxel kelp fields and rock spires that create narrow swimming corridors;
- **SUNKEN COURT** — broken walls, ancient gates, a column ring, submerged shrine and crystal growths;
- **ABYSSAL GATE** — the darkest and deepest part of the map, framed by a giant ruined gateway and tall rock spires;
- **SOUTHERN GARDENS** — a second coral/kelp ecosystem with ruins near the southern exits.

The environment is generated as real depth-tested Voxel geometry, not screen-space decoration. Buildings and terrain occlude correctly, fish move through world space, bubbles rise through the water column, and large ruins have height-aware collision: you can swim over a low structure instead of hitting an invisible 2D wall forever.

## Living underwater effects

- deterministic procedural coral gardens with several coral materials;
- tall segmented kelp forests;
- stepped rock spires and natural arches;
- ancient stone gates, broken walls, columns and shrine structures;
- crystal fields and hand-authored crystal clusters;
- animated bubble vents;
- animated 3D fish schools;
- translucent shafts of light from the surface;
- depth-aware underwater lighting that becomes darker and bluer as the player descends;
- area-discovery banners when crossing between the five underwater districts.

## Depth model

Route 21 still uses the large vertical range introduced by the standalone rewrite:

- water surface Y: `256`;
- minimum depth: `24`;
- deepest seafloor: `228`;
- deepest normal swimming depth: `222` after seabed clearance;
- north shelf: floor depth `96`;
- north drop: `140`;
- central side walls: `168`;
- central abyss: `228`;
- south rise: `160`;
- south shelf: `108`.

The same map therefore supports shallow reef exploration, mid-water ruins and a genuinely deep central canyon without changing maps.

## Controls

- movement: Battle Art Voxel Fork free movement in 1ST/3RD;
- `R2` / `Page Up`: ascend;
- `L2` / `Page Down`: dive deeper;
- hold `B`: smooth swim boost;
- `SURFACE`: available from the party submenu when inside an authored surface window.

## Mount and followers

The first party Pokémon that knows DIVE is used as the underwater mount through PokePC follower art. The trainer is rendered separately in third person and hidden automatically in first person.

Normal followers are explicitly removed from the overworld entity/NPC lists for the whole submerged session, so the active follower does not appear swimming beside the DIVE mount.

## Dependencies

- Gen1Recomp with Mod API 2;
- Battle Art Voxel Fork `>=1.7.6 <2.0.0`;
- PokePC Followers Voxel Merge.

Dramatic Sky Ride remains optional. Kanto Dive must not be installed at the same time because Dramatic Deep Dive now replaces its HM06/travel responsibilities.

## Installation

Install the complete `dramatic_deep_dive` folder into Gen1Recomp's `mods` directory:

`mods/dramatic_deep_dive/manifest.json`

GitHub releases include a ready-to-install ZIP whose root is `dramatic_deep_dive/`.

## Progression

HM06 is owned by this mod. The Cinnabar Lab scientist progression is retained for now: after the Volcano Badge, he gives HM06 DIVE without replacing the vanilla TM35 interaction.

## Validation

The release workflow now rejects a build if:

- `manifest.json` is invalid;
- any Lua source fails `luac` syntax validation;
- Route 21's 3D districts fail to cover the whole map;
- scene landmarks, scatter regions, bubble vents, light shafts or fish schools lie outside the map;
- the central abyss accidentally loses its intended deep-water range.

## Project direction

Dramatic Deep Dive is intended to become the normal DIVE implementation for this mod ecosystem. Future underwater maps will be authored directly for its continuous-depth and 3D-scene model.

Kanto Dive remains useful as source material while Route 19, Route 20 and Seafoam are migrated, but those maps will progressively receive `DDD_*` ids, native `SwimVolume`/`DepthZone` data and their own 3D environments rather than being copied as flat underwater floors.
