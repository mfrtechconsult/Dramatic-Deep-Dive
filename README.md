# Dramatic Deep Dive

Dramatic Deep Dive is an **independent HM08 DIVE / free-depth underwater mod** for Gen1Recomp.

It owns its own gameplay stack:

- `DIVE` and the stable item id `HM_DIVE`, presented as **HM08**;
- its own progression and save state;
- its own `DDD_*` underwater maps and DIVE/SURFACE links;
- continuous depth, 1ST/3RD free swimming and seabed collision;
- its own depth-based encounter ecology;
- salvage, 3D reefs, ruins, caves, shipwrecks, abyss scenery and ambient life;
- its own underwater mount selection and rider presentation.

There is no cross-mod map handoff, event bridge, zone aliasing or ecology sharing with any other DIVE implementation.

## HM08 DIVE

Deep Dive can provide the complete DIVE contract by itself. If the generic `DIVE` move or `HM_DIVE` record already exists in the game data, Deep Dive reuses the same stable ids rather than creating a duplicate record, but it performs no mod discovery to determine who registered them.

The visible machine number is always **HM08**.

A historical Deep Dive receipt key from earlier alpha saves is retained internally so existing Deep Dive saves keep their progression. It is not used for presentation.

## Underwater content

Deep Dive keeps its complete native underwater content:

- `DDD_ROUTE19_REEF_PASSAGE`;
- `DDD_ROUTE20_SEAFLOOR`;
- `DDD_SEAFOAM_SUNKEN_CAVE`;
- `DDD_ROUTE21_ABYSS`.

All travel, depth volumes, scenery, setpieces, encounters and salvage for those maps are owned by this project.

## Crystal 251

Crystal 251 is optional. When installed, Deep Dive additively enables DIVE for the canonical Generation II R/S/E-compatible species without replacing Crystal's complete TM/HM lists.

Supported field-move compatibility:

`TOTODILE`, `CROCONAW`, `FERALIGATR`, `CHINCHOU`, `LANTURN`, `MARILL`, `AZUMARILL`, `POLITOED`, `WOOPER`, `QUAGSIRE`, `SLOWKING`, `QWILFISH`, `REMORAID`, `OCTILLERY`, `MANTINE`, `KINGDRA`, `SUICUNE`, `LUGIA`.

Mount suitability is intentionally separate. Small or visually unsuitable DIVE users are not automatically used as rideable underwater mounts.

## Renderer compatibility

Deep Dive supports either:

- Battle Art Voxel Fork; or
- Dramaless Shape.

`VoxelProvider.lua` discovers the installed renderer through its public library API and supplies the same provider to free movement, underwater lighting and custom 3D geometry.

Dramatic Sky Ride remains optional. Deep Dive does not depend on it for mounts. Deep Dive does not add a `Player:draw()` path; its pose wrapper delegates exactly once to the existing pose chain so Sky Ride can coexist safely.

## Mounts

The active party is searched for a Pokémon that:

1. knows `DIVE`;
2. is considered visually suitable by Deep Dive's mount policy;
3. has an available PokePC follower sprite.

PokePC Followers Voxel Merge supplies the mount sprite assets. The normal following Pokémon is suspended while submerged so the mount is not duplicated by a follower at the player's side.

## Controls

- free movement: renderer 1ST/3RD controls;
- `R2` / `Page Up`: ascend;
- `L2` / `Page Down`: descend;
- hold `B`: swim boost;
- `SURFACE`: return through Deep Dive's own authored surface links.

## Validation

Release CI validates Deep Dive without checking any other DIVE project. Separate checks cover Crystal 251, Battle Art Voxel Fork, Dramaless Shape and Dramatic Sky Ride interoperability where relevant.
