# Kanto Seabed Overhaul Plan

## Goal

Replace the small set of handcrafted Deep Dive maps with a complete underwater layer for Kanto.

Every meaningful water body in Kanto must have a coherent seabed representation. The underwater world must visually and structurally match the surface route, town, cave or landmark above it instead of feeling like an unrelated generic dungeon.

The released `0.4.0` main branch remains the stable reference. All work happens on `dev/kanto-seabed-overhaul` until the new coverage is complete and validated.

## Current implementation status

### Implemented

- Previous four handcrafted underwater maps removed from the development branch.
- Runtime `KantoWaterAtlas` scans actual map definitions with `Map.defIsWaterCell`.
- Connected water bodies can span normal surface-map connections.
- Underwater seams are generated only where both connected border cells are water.
- Shore distance is computed globally across connected maps.
- Seabed depth is synthesized from shore distance and reconciled at map seams.
- One generated `DDD_SEABED_<SURFACE_MAP>` map is created for each detected water-bearing Kanto map.
- Generated DIVE/SURFACE row-runs cover the source water mask at identity coordinates.
- Underwater map transitions preserve active depth, target depth, mount and camera state.
- Biome profiles exist for coastal, ocean, harbor, volcanic, cave, freshwater and marsh environments.
- Visible ecology and encounter bands are generated from biome/depth data.
- A surface-aware landmark pass now derives structures from valid atlas water cells.
- Vermilion receives harbor support/debris identity.
- Cinnabar receives volcanic spires and thermal bubble vents.
- Seafoam maps receive dark cave formations plus ice/crystal vertical landmarks.
- Pallet, Route 19/20/21, Safari, freshwater and generic coastal/ocean maps receive profile-specific baseline identity.
- Headless contract tests cover atlas topology/seams and generated landmark placement.

### Next

- Validate the generated atlas against the real imported Kanto dataset through PR CI/runtime.
- Add stronger surface landmark correspondence using surface blocks/objects where reliable (dock footprints, bridge supports, cliff continuation and cave-mouth anchors).
- Add authored exceptions for special map topology that should not use default identity mapping.
- Add full coverage reporting and a strict CI allowlist for decorative/non-navigable water.
- Add salvage and unique points of interest only after topology and landmark correspondence are stable.

## Core design rule

The new system must not rely on a manually maintained list of a few DIVE rectangles.

A Kanto water atlas scans the actual loaded map definitions with the engine water-cell rules and produces an exhaustive inventory of water cells and connected water bodies. Authoring data then adds biome, depth and landmark identity on top of that generated topology.

This gives two guarantees:

1. coverage is exhaustive and auditable;
2. areas still receive bespoke visual identity instead of becoming generic procedural oceans.

## Phase 1 — Build the Kanto water atlas

Create tooling that inspects every Kanto map and records:

- map id and dimensions;
- every cell considered water by the engine;
- connected water components inside each map;
- whether each component is reachable by normal Surf gameplay or only decorative;
- coastline cells and distance from shore;
- map-to-map connections touching water;
- cave/interior/outdoor context;
- tileset and map metadata useful for biome classification.

Generated output must be deterministic and checked into the repository so it can be audited.

### Required audit

CI must fail if a Kanto water cell is not assigned to a seabed component unless it is explicitly allowlisted as decorative/non-navigable water.

## Phase 2 — Replace manual DIVE links with identity coordinate mapping

For normal water bodies, underwater coordinates should preserve the surface coordinates whenever possible.

The default rule becomes:

- surface map + water cell `(x, y)` -> matching underwater map + `(x, y)`;
- SURFACE from an underwater cell -> matching surface cell only when that surface cell is still valid water;
- broad manual rectangles are no longer the primary authoring mechanism.

Exception mappings remain possible for special spaces such as caves, shafts or authored portals.

This removes most hand-maintained DIVE links and makes full-Kanto coverage practical.

## Phase 3 — Generate one coherent seabed topology per water-bearing surface map

Generate underwater map definitions from the surface water mask.

Rules:

- water footprint drives the navigable underwater footprint;
- land/coast above becomes solid underwater boundary or rising seabed;
- narrow channels stay narrow unless an authored profile intentionally opens them below the surface;
- bridges and docks remain passable underwater but may receive supports/pylons;
- connected surface maps receive corresponding underwater connections;
- crossing a map boundary underwater must preserve position and depth smoothly.

The generator must avoid loading all of Kanto as one giant mesh. Content remains map/chunk scoped for performance.

## Phase 4 — Derive believable depth automatically

Base depth comes from topology rather than arbitrary rectangles.

Default depth synthesis:

- shallow shelves close to coastline;
- progressively deeper water as distance from shore increases;
- smoothed depth transitions instead of hard rectangular steps;
- narrow rivers/canals stay relatively shallow;
- large ocean bodies receive deeper central basins;
- map-boundary depths are reconciled so neighboring underwater maps join cleanly.

Authoring profiles can override the generated depth for named landmarks and special geology.

## Phase 5 — Kanto biome profiles

Every water-bearing map receives a biome profile derived from its location and context.

Example families:

### Open ocean / coastal routes

- reef shelves;
- sand and rock fields;
- kelp and coral where appropriate;
- trenches farther offshore;
- stronger blue falloff at depth.

### Cinnabar / volcanic coast

- darker volcanic rock;
- basalt formations;
- thermal vents and bubble columns;
- deeper offshore drop-offs.

### Vermilion / harbor water

- dock supports;
- anchors, chains and shipping debris;
- flatter dredged seabed near the port;
- occasional wreckage farther out.

### Pallet / quiet coast

- shallow sand;
- grass/kelp patches;
- gentle rock shelves;
- low-complexity beginner-friendly depth.

### Seafoam / cave water

- rock ceilings and enclosed blue light;
- ice/crystal formations where appropriate;
- shafts, submerged chambers and deep holes;
- cave-specific navigation silhouettes.

### Freshwater / inland water

- mud, gravel and vegetation instead of ocean coral;
- shallower depth profiles;
- freshwater encounter ecology.

### Safari / marsh-like water

- silt, roots, reeds and murkier visibility;
- shallow irregular basins.

Biome selection must be data-driven so individual maps can override materials, density, visibility and depth limits without changing engine code.

## Phase 6 — Surface landmark correspondence

Underwater scenery should explain what exists above it.

Examples:

- bridge cells can generate pillars/supports below;
- docks can generate pylons and harbor debris;
- coastal cliffs continue below the waterline;
- cave mouths become underwater rock entrances or walls;
- major islands create submerged slopes rather than abrupt flat borders;
- authored landmarks can place wrecks, ruins, vents, arches or caves only where they fit the surface context.

A landmark-anchor data layer references surface coordinates/topology so the underwater version stays spatially coherent. The first pass already places all generated landmarks on actual atlas water cells and chooses shore/deep candidates from the real water topology. Later passes will add stronger direct correspondence to surface blocks/objects.

## Phase 7 — Seamless underwater Kanto network

Underwater routes should connect wherever their surface water bodies connect.

Requirements:

- preserve depth when crossing between neighboring underwater maps;
- reconcile floor depth across seams;
- no forced SURFACE between adjacent connected ocean routes;
- maintain valid fallback positions for save/load and recovery;
- support future external map mods through the existing public volume/registration APIs.

## Phase 8 — Living ecology

Reuse the proven Deep Dive living-ocean systems on the new atlas:

- visible Pokémon spawned by biome and depth;
- Pokédex-height dynamic visual scaling;
- schooling and free 3D swimming;
- forgiving 3D interception;
- exact visible species/level passed into battle;
- Wilds of Kanto sprite-provider integration;
- random encounter rolls disabled while Wilds mode is active;
- classic random encounters remain as fallback without Wilds.

Ecology tables become biome-based first, with optional map-specific overrides.

## Phase 9 — Visual boundaries and atmosphere

Keep the current successful presentation principles:

- dark-blue distant boundaries rather than black void;
- blue overhead surface cue;
- depth-dependent lighting and visibility;
- stronger darkness and reduced visibility in abyssal zones;
- shallower, brighter treatment near towns and coastlines;
- cave-specific ceiling treatment.

## Phase 10 — Salvage and authored points of interest

Only after topology is stable:

- place salvage nodes;
- add wrecks, ruins and special caves;
- create named underwater districts only where useful;
- distribute optional exploration rewards;
- ensure POIs do not block required travel corridors.

## Phase 11 — Coverage and regression CI

Add automated checks for:

- 100% Kanto water coverage or explicit allowlist;
- every DIVE destination exists;
- every SURFACE target is valid water;
- underwater coordinate bounds;
- matching underwater connections across adjacent maps;
- no missing volume for generated underwater maps;
- no impossible floor/ceiling ranges;
- spawn positions inside valid swim volumes;
- generated landmark anchors remain inside atlas water masks;
- no invalid event namespaces;
- compatibility with Wilds of Kanto, Wild Skies, Dramatic Sky Ride, Battle Art Voxel Fork, Dramaless Shape and Crystal 251;
- launcher-ready packaging.

## Delivery order

1. Water atlas and seam topology.
2. Generated underwater maps and identity DIVE/SURFACE mapping.
3. Seam-safe depth synthesis and travel handoff.
4. Biome and ecology baseline.
5. Surface-aware landmark identity.
6. Real-Kanto runtime/CI validation and special-map exception list.
7. Stronger dock/bridge/cliff/cave-mouth correspondence.
8. Salvage, unique POIs and exploration rewards.
9. Full regression/coverage audit.
10. Testable launcher-ready development release.
