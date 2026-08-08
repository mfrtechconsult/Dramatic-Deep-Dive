# Dramatic Deep Dive

**Dramatic Deep Dive** is a Gen1Recomp gameplay mod that turns **Kanto Dive** underwater maps into a Voxel free-swimming space with continuous depth.

It is a separate mod inspired by Dramatic Sky Ride. It does **not** modify or bundle Dramatic Sky Ride or Kanto Dive.

## Current version

`0.1.0-alpha.1` — Route 19 proof of concept.

### Implemented

- automatically enters Deep Dive mode after Kanto Dive's DIVE warp;
- forces Battle Art Voxel Fork to **3RD** while submerged;
- restores the player's previous Voxel level after surfacing;
- free X/Y movement inside authored `SwimVolume` bounds;
- continuous depth rather than discrete underwater floors;
- `R2` / `Page Up` ascends;
- `L2` / `Page Down` dives deeper;
- authored `DepthZones` provide a variable seafloor ceiling and prevent clipping into the bottom;
- matching 3D seafloor shelves/cliffs are injected into the active Voxel scene;
- a translucent world-space water surface is rendered above the swimmer;
- depth and target depth persist in mod save data;
- the first party Pokémon that knows **DIVE** is used as the visible underwater mount when its PokePC follower sprite is available;
- optional visible trainer rider;
- HUD depth gauge and a `SURFACE AVAILABLE` hint;
- Kanto Dive remains authoritative for HM06, badges, DIVE/SURFACE mappings and actual surface warps;
- Route 19 supports both existing Kanto Dive entrances.

## Dependencies

- Gen1Recomp with Mod API 2;
- Kanto Dive `>=1.5.3 <2.0.0`;
- Battle Art Voxel Fork `>=1.7.6 <2.0.0`;
- PokePC Followers Voxel Merge;
- Dramatic Sky Ride `>=0.1.1 <2.0.0` is optional and is not modified by this mod.

## Installation

Copy the `dramatic_deep_dive` directory into the Gen1Recomp `mods` directory so this file exists:

`mods/dramatic_deep_dive/manifest.json`

Then restart Gen1Recomp.

## Route 19 prototype

Kanto Dive already exposes two Route 19 links into `KD_ROUTE19_REEF_PASSAGE`. Deep Dive overlays that map with one `SwimVolume`, two shallow shelves and a deeper central channel.

The current proof of concept intentionally leaves the actual `SURFACE` action to Kanto Dive. Moving into one of the two authored surface zones displays a hint when Kanto Dive reports that `SURFACE` is available; use Kanto Dive's normal `SURFACE` field move to return above water.

## Authoring model

Deep Dive uses four concepts designed to map cleanly to Tiled object layers:

- `DiveZones`: ownership/progression remains in Kanto Dive;
- `DiveLandings` / `SurfaceZones`: places where surfacing is authored;
- `SwimVolume`: the X/Y region the player may freely swim through;
- `DepthZones`: rectangles that define the local seafloor depth.

See [`docs/TILED_AUTHORING.md`](docs/TILED_AUTHORING.md).

## Alpha limitations

- Route 19 is the only authored Deep Dive volume in alpha.1.
- The water surface is currently a lightweight translucent plane; it does not yet use Battle Art Voxel Fork's full reflective water shader.
- Route 19 seafloor shelves use simple procedural companion geometry in alpha.1; authored textured reef meshes are a later art pass.
- Mount selection is automatic; a dedicated underwater mount selector is not implemented yet.
- Underwater wild battles use Kanto Dive's existing encounter setup; battle-specific mount presentation polishing is still pending.

## Repository policy

This repository contains only Dramatic Deep Dive. Kanto Dive and Dramatic Sky Ride remain separate projects and are not vendored or patched here.
