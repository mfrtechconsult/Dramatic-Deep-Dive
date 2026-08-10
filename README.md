# Dramatic Deep Dive

Dramatic Deep Dive is an **independent HM08 DIVE and free-depth underwater gameplay mod for Gen1Recomp**.

The `0.5.0-alpha.3` development line replaces the old handful of handcrafted underwater maps with a **generated full-Kanto seabed network**.

The surface rule is simple:

> **If Gen1Recomp considers a Kanto movement cell to be water, that cell is a valid DIVE/SURFACE point.**

The underwater rule is slightly broader:

> **Bridges, docks and pontoons may be solid/walkable on the surface while the water body and seabed continue underneath them.**

The surface DIVE dark-water mask has therefore been removed. There is no longer a special painted subset of water to look for: real surface water itself is the DIVE area.

## Full-Kanto seabed atlas

At startup, Deep Dive builds a Kanto Water Atlas from the real game data and `Map.defIsWaterCell` rules.

For every water-bearing surface map it records:

- every real surface-water movement cell at the engine's native 16x16 movement-grid resolution;
- inferred water underneath over-water structures such as narrow bridges, docks and pontoons;
- connected bodies of underwater water, including bodies that cross normal map connections;
- shoreline distance across the whole connected underwater network;
- exact water-to-water cells at each map border;
- a generated seabed depth for every underwater hydrology cell;
- an underwater map id: `DDD_SEABED_<SURFACE_MAP>`.

Surface collision and underwater hydrology are intentionally separate. Normal land remains solid underwater, but a surface structure which is demonstrably built across water no longer creates an artificial seabed wall.

### Bridges, docks and pontoons

The atlas uses two masks:

1. **surface water** — the real Gen1Recomp water mask; this controls where DIVE and SURFACE are allowed;
2. **underwater hydrology** — surface water plus cells inferred to contain water beneath an over-water structure; this controls underwater collision, bathymetry and connectivity.

Generic Kanto bridge/pontoon strips are inferred when a short walkable surface gap is bounded by water on opposite sides. The inference is deliberately limited to small spans so broad land masses are not flooded accidentally.

`SHIP_PORT` also receives an explicit rule for the S.S. Anne boarding platform: Gen1Recomp intentionally classifies tile `$32` as land on that tileset, but Deep Dive preserves harbor water beneath the platform.

Consequences:

- the player cannot DIVE from a pontoon;
- the player cannot SURFACE through a pontoon;
- the player can swim underneath that pontoon;
- water on the two sides belongs to the same underwater body when the structure is genuinely over water;
- real causeways/solid land remain underwater barriers.

## Every real water cell is diveable

DIVE/SURFACE links are generated directly from the **surface-water** mask as identity-coordinate row runs.

In normal use:

- surface `(map, x, y)` -> DIVE -> `DDD_SEABED_<map>` at `(x, y)`;
- underwater `(x, y)` -> SURFACE -> the same surface `(x, y)` when that surface cell is real water;
- all detected surface-water cells are covered;
- inferred under-bridge/under-pier cells are underwater-only and are not surface entry/exit points;
- no visual DIVE mask is rendered;
- the functional water-cell index remains available to compatibility/debug exports.

DIVE still requires the normal Deep Dive progression contract: HM08 DIVE, a compatible party Pokémon and the configured field-move badge gate.

## Seamless underwater Kanto

Normal Kanto map connections are mirrored underwater whenever the two connected border cells belong to the same underwater hydrology network.

This means connected seas and waterways can continue beneath route boundaries without forcing the player to surface first.

The seam system preserves:

- current depth;
- target depth;
- underwater mount state;
- free-camera state;
- the normal Deep Dive runtime.

Seam openings are tracked **cell by cell**. A route connection does not open an entire visual wall merely because one water cell connects: only the exact connected border cells are left open.

## Submerged cave and harbor links

Map-border connections are not enough for multi-floor caves and port structures. Deep Dive also derives a second network from real surface warps.

A submerged portal can be generated when both ends are semantically compatible:

- cave -> cave;
- harbor -> harbor.

The surface warp and its destination are snapped to nearby valid underwater cells, then represented underwater by a visible arch/portal landmark. This is primarily intended for places such as Seafoam's multi-floor cave network and coherent harbor spaces.

Unrelated doors are not converted into underwater portals. For example, a freshwater exterior door leading into a cave does not automatically become a submerged connection.

## Shore-derived bathymetry

The seabed is not a flat rectangle and depth is not assigned as a few abrupt authored boxes.

Depth is derived from distance to the nearest true underwater boundary across connected maps:

- immediate shoreline cells are relatively shallow;
- the floor falls away as the player moves farther from land;
- bridges and pontoons no longer reset the shoreline calculation simply because their surface collision is land;
- open sea becomes dramatically deeper than ponds or rivers;
- neighboring map-border depths are reconciled so an underwater route transition does not create an artificial step;
- biome-specific maximum depths keep freshwater, marsh, cave and ocean spaces distinct.

Current development profiles include:

- **coastal** — shallow shelves, reefs and a strong transition toward deeper water;
- **ocean** — the largest vertical range and deepest open-water basins;
- **harbor** — shallower, murkier engineered waterfronts;
- **volcanic** — steep dark shelves, basalt-like structures and thermal vents;
- **cave** — enclosed deep pools, arches, vertical rock and crystal formations;
- **freshwater** — rivers, ponds and city waterways with restrained depth;
- **marsh** — shallow muddy wetlands with dense vegetation.

## Kanto regional identity

The generator covers every detected water map, but it does not make every seabed look identical.

Regional profiles and landmark rules provide a coherent identity for the surface location above it. Examples include:

- **Pallet Town** — shallow coastal shelf;
- **Vermilion City / Vermilion Dock** — harbor supports, submerged debris, dock-linked structures and continuous water beneath dock platforms;
- **Cinnabar Island** — volcanic shelf, dark spires and thermal bubble vents;
- **Routes 19 / 20 / 21** — large open-ocean spaces with the greatest depth range;
- **Route 20 / Seafoam channel** — ocean geology tied into the Seafoam approaches;
- **Seafoam Islands** — submerged cave arches, dark formations, vertical crystal/ice landmarks and boulder-linked geological cues;
- **Cerulean waterways / Routes 24-25** — freshwater beds;
- **Fuchsia / Safari areas** — marsh and wetland seabeds;
- **Cerulean Cave, Rock Tunnel and Victory Road water** — cave-style underwater environments when water exists there.

Map-specific rules never invent arbitrary ocean areas. The only non-surface-water cells admitted into the underwater mask are cells proven/inferred to belong below an over-water structure.

## Surface-aware landmarks

Deep Dive uses more than map names. A second landmark pass can read the real surface map's authored warps and objects.

Current examples include:

- Vermilion's actual dock / S.S. Anne access points producing explicit underwater harbor supports;
- Seafoam entrances and internal transitions producing cave-mouth structures near the corresponding water;
- Seafoam boulder objects producing nearby submerged geological cues.

This lets recognizable surface features leave a trace on the seabed without hardcoding a separate replacement map by hand.

## Living underwater Pokémon

The full-Kanto overhaul retains the living-ocean system.

Visible underwater Pokémon:

- are chosen from the current biome/depth ecology;
- move horizontally and vertically through the water column;
- can loosely school with the same species;
- react to the player and avoid major scenery/bounds;
- use installed compatible overworld/follower sprite providers when available;
- are dynamically scaled from Pokédex height;
- can be intercepted with a forgiving 3D proximity envelope.

### Pokédex-sized wildlife

Pokédex height affects the actual displayed size in both fallback 2D and voxel billboard rendering.

The visual scale uses a compressed curve so:

- tiny Pokémon remain readable;
- medium species visibly differ in size;
- large species such as Lapras or Gyarados feel substantially larger;
- extreme heights are capped so one sprite cannot dominate the whole camera.

### Forgiving interception

Exact pixel/depth overlap is not required to catch a moving underwater Pokémon.

Deep Dive uses approximately:

- **3 cells horizontal tolerance**;
- **80 px depth tolerance**;
- slightly larger envelopes for physically larger Pokémon.

When several Pokémon are in range, the nearest valid target in normalized 3D space wins. The battle uses the exact visible species and level.

## Wilds of Kanto

When `overworld_wild_spawns` is installed:

- classic invisible random underwater encounters are disabled;
- visible Deep Dive wildlife remains active;
- visible Pokémon become the normal underwater encounter layer;
- compatible Wilds/follower sprites are preferred where available;
- the safe DIVE/SURFACE travel path is used where required by the Sky/Wilds compatibility stack.

Without Wilds of Kanto, Deep Dive keeps low-frequency depth-based random encounter bands as a standalone fallback.

## Salvage across Kanto

The generated seabed network supports sparse procedural salvage rather than limiting exploration rewards to the old prototype maps.

Larger water bodies receive a small number of deterministic salvage signals, biased toward deeper/interior water. Tiny decorative pools receive no treasure spam.

Item pools and signal labels vary by environment, for example:

- harbor debris;
- cave signals;
- thermal/volcanic signals;
- general seabed salvage.

The salvage tick uses the public fixed-step input hook rather than rewriting `OverworldState.update`, preserving compatibility with Wilds, Wild Skies and Dramatic Sky Ride.

## Underwater rendering

The voxel renderer builds geometry directly from the generated hydrology/depth masks.

It includes:

- one floor height per generated depth run;
- vertical transitions between neighboring depth levels;
- shoreline walls only where underwater water really ends;
- no artificial shoreline wall beneath inferred bridges, docks or pontoons;
- exact open map seams only where connected border hydrology really continues;
- dark-blue distant non-playable boundaries instead of a black void;
- a blue overhead surface plane;
- biome-specific seabed colors;
- biome-specific depth lighting.

Lighting varies subtly by environment: ocean blue, colder caves, murkier harbor water, greenish freshwater and marshes, and darker mineral Cinnabar water.

## Depth controls

Deep Dive uses fixed-step input hooks so vertical swimming remains responsive even when other mods compose their own overworld wrappers.

- `R2` / `Page Up` — ascend;
- `L2` / `Page Down` — descend;
- hold `B` — swim boost;
- normal 1ST/3RD renderer movement — horizontal swimming;
- `SURFACE` — return to the corresponding real surface-water cell.

## Dramatic Sky Ride / Wild Skies compatibility

Deep Dive does not self-heal or rewrite the Sky-family `OverworldState.update` wrapper chain.

The compatibility lessons from the `0.4.0` cycle remain enforced:

- no `UpdateHookGuard`;
- no `TransitionWatchdog`;
- depth and generated-world systems prefer public/fixed-step hooks;
- DIVE/SURFACE cinematic staging is bypassed when a known conflicting Sky/Wilds composition is active;
- the complete underwater runtime still activates after the safe warp.

## HM06 WHIRLPOOL / HM07 WATERFALL / HM08 DIVE

Deep Dive owns its complete HM08 DIVE contract and also provides standalone Gen II-style water field mechanics:

- **HM06 WHIRLPOOL** — Generation II move data and authored whirlpool barriers;
- **HM07 WATERFALL** — Generation II move data, free descent and gated ascent;
- **HM08 DIVE** — independent underwater travel and free-depth gameplay.

Crystal 251 remains optional. When present, compatible existing records and Generation II Pokémon data are reused additively instead of duplicated.

## Renderer requirements

Supported voxel providers:

- **Battle Art Voxel Fork** `>=1.7.6 <2.0.0` — recommended;
- **Dramaless Shape** — supported alternative.

Dramatic Sky Ride is optional. Wild Skies and Wilds of Kanto are optional compatibility integrations, not hard dependencies.

## Validation

The development branch has a dedicated **Kanto seabed contract** in addition to the normal compatibility and packaging workflows.

Automated contracts verify:

- atlas scanning and connected water bodies;
- separate surface-water and underwater-hydrology masks;
- bridge/pontoon inference for short walkable spans;
- explicit `SHIP_PORT` boarding-platform hydrology;
- solid/non-walkable causeways remain underwater barriers;
- DIVE/SURFACE is not generated on inferred structure cells;
- swimming remains valid below inferred structure cells;
- reciprocal underwater route seams;
- exact seam-cell masks, including preservation through volume registration;
- seam depth reconciliation;
- generated map block topology;
- exact full-water coverage;
- no generated DIVE leakage onto surface land;
- surface-aware landmark placement;
- surface warp/object anchors;
- no legacy surface DIVE mask;
- cave/harbor submerged portal rules;
- HM06/HM07/HM08 and standalone contracts;
- Crystal 251 compatibility;
- Battle Art Voxel Fork / Dramaless Shape compatibility;
- Dramatic Sky Ride / Wilds compatibility;
- launcher-ready packaging.

## Development status

Current development preview: **0.5.0-alpha.3**.

This branch is intended for full-Kanto gameplay testing. The published `main` release remains the stable `0.4.0` line until the overhaul is explicitly promoted after testing.
