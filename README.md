# Dramatic Deep Dive

Dramatic Deep Dive is an **independent HM08 DIVE and free-depth underwater gameplay mod for Gen1Recomp**.

The `0.5.0-alpha.6` development line replaces the old handful of handcrafted underwater maps with a **generated full-Kanto seabed network** and deliberately gives the underwater world more horizontal room than the compressed Gen I surface maps.

The surface rule is simple:

> **If Gen1Recomp considers a Kanto movement cell to be water, that cell is a valid DIVE/SURFACE point.**

The underwater rule is broader:

> **Bridges, docks and pontoons may be solid/walkable on the surface while the water body and seabed continue underneath them.**

The old dark DIVE mask is removed. Real surface water itself is the DIVE area.

## Full-Kanto seabed atlas

At startup, Deep Dive builds a Kanto Water Atlas from the real game data and `Map.defIsWaterCell` rules.

For every water-bearing surface map it records:

- every real surface-water movement cell at the engine's native 16x16 movement-grid resolution;
- inferred water underneath over-water structures such as narrow bridges, docks and pontoons;
- connected underwater bodies, including bodies that cross normal map connections;
- shoreline distance across the connected underwater network;
- exact water-to-water cells at each map border;
- a generated seabed depth for every underwater hydrology cell;
- an underwater map id: `DDD_SEABED_<SURFACE_MAP>`.

Surface collision and underwater hydrology are intentionally separate. Normal land remains solid underwater, but a surface structure which is demonstrably built across water no longer creates an artificial seabed wall.

## Wide underwater world scale

Gen I Kanto is intentionally compact. Copying its 1:1 horizontal scale underwater made ocean routes feel like narrow corridors, so Deep Dive now preserves **topology** while expanding **underwater distance**.

Current profile scaling:

- **ocean** — `3x` width and `3x` height, approximately **9x the navigable swim area**;
- **volcanic / Cinnabar** — `3x`, allowing a broad offshore shelf and large deep-water basin;
- **coastal** — `2x`, approximately **4x the navigable area**;
- **harbor / Vermilion** — `2x`, giving docks and port structures breathing room;
- **cave / Seafoam** — `2x`, creating larger submerged chambers without making them feel like open sea;
- **freshwater** — `1x`, keeping rivers and small inland ponds believable;
- **marsh** — `1x`.

A surface water cell is therefore a **geographic source cell**, not necessarily a single underwater movement cell. For example, one Route 19 water cell represents a `3x3` patch of underwater navigation space.

This has several important properties:

- Kanto above the water is unchanged;
- coastlines and islands keep the same overall shape;
- connected route seams are expanded by the same factor and remain seamless;
- bathymetry is stretched horizontally, producing longer and more natural slopes;
- landmarks, salvage, fish schools, cave/harbor portals and other generated content are repositioned into the enlarged world;
- decoration count grows more slowly than navigable area, intentionally leaving broad areas of open water.

## Bridges, docks and pontoons

The atlas uses two masks:

1. **surface water** — the real Gen1Recomp water mask; this controls where DIVE and SURFACE are allowed;
2. **underwater hydrology** — surface water plus cells inferred to contain water beneath an over-water structure; this controls underwater collision, bathymetry and connectivity.

Generic Kanto bridge/pontoon strips are inferred when a short walkable surface gap is bounded by water on opposite sides. The inference is deliberately limited to small spans so broad land masses are not flooded accidentally.

`SHIP_PORT` also receives an explicit rule for the S.S. Anne boarding platform: Gen1Recomp intentionally classifies tile `$32` as land on that tileset, but Deep Dive preserves harbor water beneath the platform.

Consequences:

- the player cannot DIVE from a pontoon;
- the player cannot SURFACE through a pontoon;
- the player can swim underneath that pontoon;
- water on both sides belongs to the same underwater body when the structure is genuinely over water;
- real causeways and solid land remain underwater barriers.

## DIVE and SURFACE mapping

DIVE/SURFACE links are generated from the **surface-water** mask.

With a scaled underwater profile:

- a surface cell maps to the center of its corresponding enlarged underwater patch;
- any valid underwater cell inside that patch maps back to the same surface cell;
- inferred under-bridge / under-pier cells remain underwater-only and never become entry or exit points;
- all real surface-water cells remain covered;
- no visual DIVE mask is rendered.

DIVE still requires the normal Deep Dive progression contract: HM08 DIVE, a compatible party Pokémon and the configured field-move badge gate.

## Seamless underwater Kanto

Normal Kanto map connections are mirrored underwater whenever the two connected border cells belong to the same underwater hydrology network.

Connected seas and waterways can therefore continue beneath route boundaries without forcing the player to surface first. Connection offsets and seam openings scale with the underwater map, so the enlarged Route 19 / 20 / 21 ocean remains spatially consistent.

The seam system preserves:

- current depth;
- target depth;
- underwater mount state;
- free-camera state;
- the normal Deep Dive runtime.

Seam openings are tracked **cell by cell**. A route connection does not open an entire visual wall merely because one water cell connects.

## Submerged cave and harbor links

Map-border connections are not enough for multi-floor caves and port structures. Deep Dive also derives a second network from real surface warps.

A submerged portal can be generated when both ends are semantically compatible:

- cave -> cave;
- harbor -> harbor.

Portal positions are moved to the correct coordinates after underwater scaling, so Seafoam and harbor links remain aligned with their enlarged spaces.

## Shore-derived bathymetry

The seabed is not a flat rectangle and depth is not assigned as a few abrupt authored boxes.

Depth is derived from distance to the nearest true underwater boundary across connected maps:

- immediate shoreline cells are relatively shallow;
- the floor falls away as the player moves farther from land;
- bridges and pontoons do not reset the shoreline calculation;
- open sea becomes dramatically deeper than ponds or rivers;
- neighboring map-border depths are reconciled;
- horizontal world scaling stretches those depth steps over more physical distance, making ocean slopes less cramped;
- biome-specific maximum depths keep freshwater, marsh, cave and ocean spaces distinct.

Current profiles include `coastal`, `ocean`, `harbor`, `volcanic`, `cave`, `freshwater` and `marsh`.

## Kanto regional identity

The generator covers every detected water map but does not make every seabed identical.

Examples include:

- **Pallet Town** — shallow coastal shelf;
- **Vermilion City / Vermilion Dock** — enlarged harbor, supports, submerged debris and continuous water beneath dock platforms;
- **Cinnabar Island** — large volcanic shelf, dark spires and thermal vents;
- **Routes 19 / 20 / 21** — the largest open-ocean spaces and deepest basins;
- **Seafoam Islands** — enlarged submerged chambers, arches, dark formations, crystals/ice and boulder-linked geology;
- **Cerulean waterways / Routes 24-25** — restrained freshwater beds;
- **Fuchsia / Safari areas** — marsh and wetland seabeds.

Underwater scaling does not invent unrelated new coastlines. It magnifies the proven hydrology topology into a larger navigable world.

## Living underwater Pokémon

Visible underwater Pokémon:

- are chosen from the current biome/depth ecology;
- move horizontally and vertically through the water column;
- can loosely school with the same species;
- react to the player and avoid major scenery/bounds;
- use compatible overworld/follower sprite providers when available;
- are dynamically scaled from Pokédex height;
- can be intercepted with a forgiving 3D proximity envelope.

The larger ocean does not require exact sprite collision. Interception keeps approximately **3 cells horizontal tolerance** plus **80 px depth tolerance**, with additional allowance for large Pokémon.

## Wilds of Kanto

When `overworld_wild_spawns` is installed:

- classic invisible/random Deep Dive encounters are hard-disabled;
- suppression is enforced through Gen1Recomp's public `encounter.roll` and `encounter.species` hooks;
- generated underwater engine-facing encounter tables remain at rate `0`;
- visible Deep Dive wildlife remains active;
- the visible Pokémon being intercepted is the Pokémon used for the battle.

Without Wilds of Kanto, Deep Dive keeps its low-frequency depth-based standalone encounter bands.

## Salvage across Kanto

The generated seabed supports sparse procedural salvage. Larger water bodies receive a small number of deterministic signals biased toward deeper/interior water.

After horizontal world scaling, salvage coordinates are expanded with the seabed so they remain correctly positioned. Signal hints are:

- `SIGNAL BELOW` — the nearby salvage point is deeper than the player;
- `SIGNAL ABOVE` — it is shallower;
- `A SALVAGE` — the player is close enough horizontally and vertically to collect it.

## Underwater rendering

The voxel renderer builds geometry directly from the generated hydrology/depth masks.

It includes:

- floor height per generated depth run;
- vertical transitions between neighboring depth levels;
- shoreline walls only where underwater water really ends;
- no artificial wall beneath inferred bridges, docks or pontoons;
- exact open map seams;
- dark-blue distant boundaries instead of a black void;
- a blue overhead surface plane;
- biome-specific seabed colors and depth lighting.

## Depth controls

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

Deep Dive provides:

- **HM06 WHIRLPOOL** — Generation II move data and authored whirlpool barriers;
- **HM07 WATERFALL** — Generation II move data, free descent and gated ascent;
- **HM08 DIVE** — independent underwater travel and free-depth gameplay.

Crystal 251 remains optional and is integrated additively when installed.

## Renderer requirements

Supported voxel providers:

- **Battle Art Voxel Fork** `>=1.7.6 <2.0.0` — recommended;
- **Dramaless Shape** — supported alternative.

Dramatic Sky Ride, Wild Skies and Wilds of Kanto are optional compatibility integrations, not hard dependencies.

## Validation

The development branch has a dedicated **Kanto seabed contract** in addition to compatibility and launcher-packaging workflows.

Automated contracts verify:

- atlas scanning and connected water bodies;
- separate surface-water and underwater-hydrology masks;
- bridges, docks and pontoons over continuous underwater water;
- solid causeways remain barriers;
- exact reciprocal underwater seams;
- DIVE/SURFACE coverage;
- no legacy surface mask;
- submerged cave/harbor portals;
- **open-ocean 3x scale = 9x navigation area**;
- reversible scaled DIVE/SURFACE coordinate mapping;
- scaled landmarks, salvage and portal positions;
- Wilds visible-only battle suppression;
- HM06/HM07/HM08 contracts;
- Crystal 251 compatibility;
- Battle Art / Dramaless compatibility;
- Dramatic Sky Ride / Wild Skies compatibility;
- launcher-ready packaging.

## Development status

Current development preview: **0.5.0-alpha.6**.

This branch is intended for full-Kanto gameplay testing. The published `main` release remains the stable `0.4.0` line until the overhaul is explicitly promoted after testing.
