# Tiled authoring contract

Dramatic Deep Dive is designed so future underwater areas can be authored in Tiled without encoding movement rules directly in Lua.

The runtime representation used by `data/volumes.lua` mirrors the following object layers.

## `SwimVolume`

Rectangle objects defining where free underwater X/Y movement is allowed.

Properties:

- `id`: stable unique name;
- `mapId`: Gen1Recomp underwater map id when not inherited from the map definition.

A movement target outside every `SwimVolume` is blocked even if the underlying tile is normally passable.

## `DepthZones`

Rectangle objects defining how deep the local seafloor is below the water surface.

Properties:

- `id`;
- `floorDepth`: positive depth value.

If multiple zones overlap, the shallowest floor wins. Runtime maximum swimmer depth is `floorDepth - seabedClearance`.

The volume's `defaultFloorDepth` should be the deepest bottom in that volume. `DepthZones` then raise shelves above it; overlapping zones use the shallowest floor. This keeps runtime collision and procedural Voxel geometry identical while the player's vertical position remains continuous.

## `DiveLandings` / `SurfaceZones`

Rectangle objects marking authored places connected to Kanto Dive DIVE/SURFACE links.

Deep Dive never performs the surface warp itself. Kanto Dive remains authoritative for badge checks, link pairing and the SURFACE field move.

## `DiveZones`

These remain owned by Kanto Dive. Deep Dive consumes the underwater map/zone entered by Kanto Dive rather than creating a competing progression system.

## Route 19 alpha.1

The proof of concept maps the existing `KD_ROUTE19_REEF_PASSAGE` area as:

- one `SwimVolume`: cells `(2,2)` through `(17,5)`;
- water surface: world Y `96`;
- minimum swim depth: `28`;
- west shelf: floor depth `64`;
- central channel: floor depth `92`;
- east shelf: floor depth `64`;
- west/east `SurfaceZones` matching Kanto Dive's existing four-by-four link rectangles.

## Planned importer

A future milestone can export these layers from Tiled to Lua/JSON. The runtime registry is already separated from Route 19 data so adding the importer will not require rewriting the swimming controller.
