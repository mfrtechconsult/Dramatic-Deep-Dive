# Dramatic Deep Dive

**Dramatic Deep Dive** is a standalone Gen1Recomp underwater traversal mod. It owns HM06 DIVE, DIVE/SURFACE travel, underwater maps, continuous-depth swimming, Pokemon mounts and the 3D underwater environment itself.

Kanto Dive is now only source material for the historical map layouts. It is **not required at runtime** and conflicts with Dramatic Deep Dive to avoid duplicate HM/map systems.

## Current version

`0.4.0-alpha.1` — complete four-map standalone migration and setpiece pass.

## Standalone underwater Kanto

The complete underwater map set inherited from the old Kanto Dive prototype is now owned by Dramatic Deep Dive:

- `DDD_ROUTE19_REEF_PASSAGE` — compact coral gate with a deep middle channel;
- `DDD_ROUTE20_SEAFLOOR` — 100 x 18-cell open-sea map with shelves, a Seafoam rift, ruins, an explorable 3D shipwreck and hydrothermal vents;
- `DDD_SEAFOAM_SUNKEN_CAVE` — enclosed crystal cavern with a rendered cave ceiling, physical stalactites and a deep blue-hole chamber;
- `DDD_ROUTE21_ABYSS` — 20 x 90-cell vertical exploration map south of Pallet Town with reefs, kelp, ruins and the central abyss.

Route 20 and Seafoam form one continuous submerged zone. Entering Seafoam no longer resets the Deep Dive session: depth and the player's original pre-dive camera mode survive the internal map warp.

## Route 21 districts

- **PALLET REEF** — bright branching coral and a natural rock arch;
- **KELP CATHEDRAL** — tall kelp fields and rock spires;
- **SUNKEN COURT** — gates, broken walls, columns, shrine and crystal growths;
- **ABYSSAL GATE** — the darkest/deepest canyon, giant ruined gateway, fossil ribs and hydrothermal vents;
- **SOUTHERN GARDENS** — coral/kelp ecosystem and southern ruins.

## Route 20 districts

- **WEST CORAL SHELF** — wide reef shelf, kelp and ruined columns;
- **SEAFOAM RIFT** — a deep 250+ depth trench with an abyss gate, crystal growths and smoker field;
- **CURRENT GARDENS** — eastern coral/kelp shelf containing a large wrecked ship and additional ruins.

## Seafoam

Seafoam is no longer a flat 2D cave copied into Voxel mode. Its Deep Dive version has:

- a dark overhead cave ceiling;
- 28 deterministic stalactites extending into the swimming column;
- physical depth-aware stalactite collision;
- crystal clusters and rock formations;
- a submerged ruin ring and shrine;
- a deeper **BLUE HOLE** chamber reaching roughly 188 usable depth.

## Living 3D environment

The environment is generated as real depth-tested Voxel geometry rather than screen-space decoration:

- branching coral gardens;
- segmented kelp forests;
- stepped rock spires and arches;
- ancient gates, walls, columns and shrines;
- crystal fields;
- animated bubble vents;
- animated fish schools in world space;
- light shafts from the surface;
- depth-aware blue/teal lighting;
- a full block-built shipwreck;
- hydrothermal chimney fields;
- cave ceiling and stalactites;
- fossil rib-cage setpiece.

Large structures have vertical collision. A ruin can block you at its own height while remaining passable if you swim over it.

## Depth ranges

| Map | Approx. usable range | Identity |
| --- | ---: | --- |
| Route 19 Reef Passage | 20-150 | compact reef channel |
| Route 20 Seafloor | 24-253 | wide shelves + deep Seafoam rift |
| Seafoam Sunken Cave | 36-188 | enclosed cavern + blue hole |
| Route 21 Abyss | 24-222 | long canyon + deep central abyss |

## Controls

- normal Battle Art Voxel Fork free movement in 1ST/3RD;
- `R2` / `Page Up`: ascend;
- `L2` / `Page Down`: dive deeper;
- hold `B`: smooth swim boost;
- `SURFACE`: party submenu action inside an authored surface window.

## Mount and followers

The first party Pokemon that knows DIVE is used as the underwater mount through PokePC follower art. The trainer is rendered separately in third person and hidden automatically in first person.

Normal followers are explicitly removed from overworld entity/NPC lists for the whole submerged session, so the active follower does not appear beside the DIVE mount.

## Map previews

Every release now generates **real-data map previews** from the actual Lua map, depth-volume, scene and setpiece definitions. These are not concept art.

The release assets include:

- `DDD_ROUTE19_REEF_PASSAGE.png`
- `DDD_ROUTE20_SEAFLOOR.png`
- `DDD_SEAFOAM_SUNKEN_CAVE.png`
- `DDD_ROUTE21_ABYSS.png`

The previews display the actual base-map blocks, depth zones, SURFACE regions, 3D landmarks, named districts and major setpieces.

## Dependencies

- Gen1Recomp with Mod API 2;
- Battle Art Voxel Fork `>=1.7.6 <2.0.0`;
- PokePC Followers Voxel Merge.

Dramatic Sky Ride remains optional. Kanto Dive must not be installed simultaneously because Dramatic Deep Dive replaces its HM06/travel responsibilities.

## Installation

Install the complete `dramatic_deep_dive` folder into Gen1Recomp's `mods` directory:

`mods/dramatic_deep_dive/manifest.json`

GitHub releases include a ready-to-install ZIP whose root is `dramatic_deep_dive/`.

## Progression

HM06 is owned by this mod. The Cinnabar Lab scientist progression is retained for now: after the Volcano Badge, he gives HM06 DIVE without replacing the vanilla TM35 interaction.

## Validation

The release workflow rejects a build if:

- `manifest.json` is invalid;
- any Lua source fails syntax validation;
- one of the four maps is missing its depth volume or scene;
- a SwimVolume exceeds map boundaries;
- a map loses its intended minimum depth;
- districts leave gaps in their main exploration axis;
- landmarks, scatter regions, vents, fish schools, light shafts or setpieces exceed map boundaries;
- the Seafoam ceiling enters the legal swimming ceiling.

The same workflow generates the four map previews and attaches their PNGs to the GitHub release.

## Project direction

The old flat DIVE implementation is no longer the target. Dramatic Deep Dive is being developed as the underwater counterpart to Dramatic Sky Ride: continuous free movement, meaningful vertical traversal, mount/rider presentation and authored 3D spaces.

The next stages focus on transitions, depth-dependent encounters/interactions, map-specific secrets and performance/LOD before final gameplay tuning on real hardware.
