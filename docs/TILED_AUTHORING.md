# Tiled authoring contract

Dramatic Deep Dive authors underwater space directly. Kanto Dive maps can be migrated into this format, but no Kanto Dive runtime objects are required.

## `SwimVolume`

Rectangle objects defining the horizontal X/Y area in which free 1ST/3RD swimming is allowed.

Properties:

- `id`;
- `mapId` when not inherited from the map;
- optional authoring metadata.

Targets outside every `SwimVolume` are blocked even though Deep Dive bypasses the normal grid collision inside the volume.

## `DepthZones`

Rectangle objects defining local seafloor depth below the water surface.

Properties:

- `id`;
- `floorDepth` in world pixels.

The map-level `defaultFloorDepth` is the deepest bottom. `DepthZones` raise shelves and canyon shoulders above it. When zones overlap, runtime collision uses the shallowest floor.

Maximum swimming depth is:

`floorDepth - seabedClearance`

## `SurfaceZones`

Rectangle objects marking locations where the standalone `SURFACE` field action may be offered. Travel coordinates are paired separately in `data/dive_links.lua` so progression/travel can evolve independently from 3D terrain.

## Route 21 standalone prototype

`DDD_ROUTE21_ABYSS` uses one full-map swim volume covering cells `(0,0)` through `(19,89)`.

Vertical profile:

- `surfaceHeight = 256`;
- `minDepth = 24`;
- `defaultFloorDepth = 228`;
- `seabedClearance = 6`;
- north shelf `0..17`: floor `96`;
- north drop `18..29`: floor `140`;
- central side walls `30..59`: floor `168`;
- central channel `30..59`, x `5..14`: default floor `228`;
- south rise `60..71`: floor `160`;
- south shelf `72..89`: floor `108`.

Three surface windows mirror the historical Route 21 Kanto Dive link rectangles, but point at the new DDD-owned map.

## Migration plan

The remaining Kanto Dive Route 19, Route 20 and Seafoam layouts will be converted to DDD-owned map ids and then expanded vertically rather than copied as shallow floors. Future Tiled exports should generate both map geometry and the Deep Dive volume data from one source of truth.
