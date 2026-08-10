# Full-Kanto Seabed Overhaul

## Goal

Replace the old small set of handcrafted Deep Dive maps with a deterministic underwater counterpart for every Kanto surface map that contains water.

The implementation rule is now:

> Every movement cell accepted by Gen1Recomp's `Map.defIsWaterCell` receives Deep Dive coverage.

The old surface dark-water DIVE mask is intentionally removed because there is no longer a special subset of water to indicate.

## Implemented architecture

### Kanto Water Atlas

- scans all candidate Kanto maps at runtime;
- uses the engine's real water-cell rules;
- records exact 16x16 movement-cell water topology;
- computes connected water bodies across map connections;
- computes a global shore-distance transform across connected maps;
- detects reciprocal water-to-water map seams;
- synthesizes one floor depth per water cell;
- reconciles floor depth exactly across connected map borders.

### Generated underwater maps

For each detected water-bearing surface map:

- generates `DDD_SEABED_<SURFACE_MAP>`;
- preserves the exact surface water mask through collision-mask blocks;
- generates identity-coordinate DIVE/SURFACE links for every water row run;
- generates swim/depth masks;
- mirrors normal surface connections when water crosses the border;
- tracks the exact connected cells at each border so the renderer opens only real water seams.

### Seamless network

Normal route/city connections remain underwater whenever water continues across them. Crossing a generated seam preserves current/target depth, mount state and free-camera state.

A second `SubmergedWarpLinks` pass creates explicit underwater portals for compatible authored surface warps:

- cave -> cave;
- harbor -> harbor.

Surface warp endpoints are snapped to nearby valid water cells and receive visible underwater arch/portal landmarks. Unrelated doors are not converted.

### Bathymetry

Depth is continuous and shore-derived rather than authored as large rectangular depth zones.

Profiles define different shallow-water floors, falloff rates and maximum depths for:

- coastal;
- ocean;
- harbor;
- volcanic;
- cave;
- freshwater;
- marsh.

The first water cells near land are intentionally shallow; open water falls away much faster and reaches the largest vertical range.

### Regional identity

All detected water is covered, while regional rule data differentiates the result:

- Pallet coast;
- Vermilion harbor/docks;
- Cinnabar volcanic shelf;
- Routes 19/20/21 open ocean;
- Cerulean waterways and northern freshwater routes;
- Fuchsia/Safari wetlands;
- Seafoam submerged caves;
- Cerulean Cave / Rock Tunnel / Victory Road cave water when present;
- regional coastal/freshwater/marsh identities for the remaining Kanto water maps.

### Surface-aware landmarks

Landmarks use both atlas geometry and real surface authored data.

Examples:

- actual Vermilion dock / S.S. Anne warps produce underwater harbor supports;
- Seafoam entrances/internal transitions produce cave-mouth structures;
- Seafoam boulder objects produce nearby geological cues;
- volcanic/cave/harbor/ocean/freshwater/marsh passes distribute deterministic structures only over valid water cells.

### Living ocean and exploration

The existing Deep Dive runtime remains integrated across the generated network:

- visible depth-aware Pokémon;
- Pokédex-height visual scaling;
- forgiving 3D interception;
- Wilds of Kanto overworld-only encounter mode;
- depth-based fallback random encounters without Wilds;
- biome-aware lighting;
- blue distant boundaries and blue overhead surface plane;
- sparse deterministic salvage across sufficiently large water bodies.

Generated salvage and other new fixed-step systems avoid rewriting `OverworldState.update`.

## Validation contracts

The dedicated `Kanto seabed contract` workflow verifies:

- connected water atlas topology;
- exact reciprocal map seams;
- exact connected seam-cell masks;
- seam depth reconciliation;
- generated block topology;
- one-to-one full-water DIVE coverage;
- one-to-one full-water swim-volume coverage;
- no generated leakage onto surface land;
- surface-aware landmarks;
- exact surface warp/object anchors;
- no legacy surface DIVE mask;
- compatible cave/harbor submerged portal generation.

The normal compatibility matrix and launcher packaging workflows remain required as well.

## Current development milestone

`0.5.0-alpha.2` is the first full-Kanto implementation milestone intended for broad gameplay validation. The stable `main` release remains `0.4.0` until this overhaul is explicitly promoted after testing.
