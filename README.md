# Dramatic Deep Dive

Dramatic Deep Dive is an **independent HM08 DIVE / free-depth underwater gameplay mod** for Gen1Recomp.

Version **0.4.0** turns Kanto's ocean routes into large 3D underwater spaces with continuous depth control, living visible Pokémon, depth-aware ecology, salvage, reefs, ruins, caves, shipwrecks and abyss scenery.

It owns its own gameplay stack:

- `DIVE` and the stable item id `HM_DIVE`, presented as **HM08**;
- its own progression and save state;
- its own `DDD_*` underwater maps and DIVE/SURFACE links;
- continuous depth, 1ST/3RD free swimming and seabed collision;
- visible underwater Pokémon with depth-aware spawning;
- Pokédex-height-based dynamic Pokémon sizing;
- forgiving 3D overworld interception against visible Pokémon;
- optional depth-based random encounters when Wilds of Kanto is not installed;
- salvage, 3D reefs, ruins, caves, shipwrecks, abyss scenery and ambient life;
- its own underwater mount selection and rider presentation;
- standalone HM06 WHIRLPOOL and HM07 WATERFALL support.

There is no cross-mod map handoff, zone aliasing or dependency on another DIVE implementation.

## Recommended setup

Dramatic Deep Dive can run independently, but the recommended full setup is:

1. **Dramatic Deep Dive**;
2. **Battle Art Voxel Fork** `>=1.7.6 <2.0.0` for the recommended 3D voxel renderer;
3. **Wilds of Kanto** (`overworld_wild_spawns`) for overworld Pokémon sprite integration;
4. **Dramatic Sky Ride** and **Wild Skies** may be installed alongside it;
5. **Crystal 251** is optional for Generation II content compatibility.

**Dramaless Shape** is also supported as an alternative voxel provider.

## HM08 DIVE

Deep Dive can provide the complete DIVE contract by itself. If the generic `DIVE` move or `HM_DIVE` record already exists in the game data, Deep Dive reuses the same stable ids instead of creating duplicate content.

The visible machine number is always **HM08**.

A historical Deep Dive receipt key from earlier alpha saves is retained internally so existing Deep Dive saves keep their progression. It is not used for presentation.

## Underwater world

Deep Dive currently owns four large underwater areas:

- `DDD_ROUTE19_REEF_PASSAGE` — reef passage and shelf exploration;
- `DDD_ROUTE20_SEAFLOOR` — broad seafloor, trenches and Seafoam approaches;
- `DDD_SEAFOAM_SUNKEN_CAVE` — submerged cave space;
- `DDD_ROUTE21_ABYSS` — the deepest vertical exploration area.

The release maps are intentionally much larger than their early alpha versions so 3D swimming does not feel like moving through narrow corridors.

The underwater scene includes:

- large continuous swim volumes;
- deep vertical columns;
- shelves, trenches and abyss zones;
- reefs, rocks, ruins and wrecks;
- bubble vents and ambient schools;
- salvage points;
- depth-aware lighting and atmosphere.

Instead of exposing a black void at the edge of the playable ocean, Deep Dive uses **dark blue distant boundaries** to suggest water continuing beyond the playable area. A lighter blue overhead plane recalls the surface above the player.

## Living ocean Pokémon

Visible Pokémon are part of the underwater world rather than simple decorative fish meshes.

Their ecology is driven by the same depth bands used by Deep Dive's encounter tables:

- species change as the player descends;
- Pokémon move horizontally and vertically through the water column;
- same-species Pokémon can loosely school together;
- nearby Pokémon react to the player;
- Pokémon avoid major scenery and swim-volume boundaries;
- the ocean is populated gradually around the camera instead of spawning everything at once.

### Dynamic Pokédex sizing

Visible underwater Pokémon are scaled from their **Pokédex height**.

The scaling curve is intentionally compressed:

- very small Pokémon stay readable;
- medium species show a clear size difference;
- large species such as Lapras or Gyarados become substantially more imposing;
- extreme sizes are capped so a single Pokémon does not fill the entire camera.

The same scale is used by the 2D fallback and the voxel billboard path.

## Wilds of Kanto integration

When **Wilds of Kanto** (`overworld_wild_spawns`) is installed, Deep Dive treats visible underwater Pokémon as the authoritative encounter layer.

In this configuration:

- classic invisible random encounters are disabled while Deep Dive is active;
- visible underwater Pokémon remain enabled;
- approaching a visible Pokémon can start a battle against that exact species and level;
- sprite resolution prefers installed compatible overworld/follower providers;
- the Deep Dive transition uses the compatibility-safe travel path where required.

Without Wilds of Kanto, Deep Dive keeps its normal low-frequency depth-based random encounter system.

## Forgiving underwater interception

Underwater Pokémon move in three dimensions, so requiring pixel-perfect contact would make encounters frustrating.

Deep Dive therefore uses a forgiving interception envelope inspired by Dramatic Sky Ride's Wild Skies integration:

- roughly **3 cells of horizontal tolerance**;
- roughly **80 px of vertical/depth tolerance**;
- larger Pokémon receive a slightly more generous effective target volume;
- when multiple Pokémon are close, the nearest valid target in 3D is selected;
- the battle uses the exact visible Pokémon species and level;
- a short post-battle rest prevents accidental chain encounters.

This lets the player deliberately chase Pokémon without needing perfect overlap in both horizontal position and depth.

## Depth controls

Deep Dive uses a stable fixed-step depth path so vertical swimming remains responsive even when other overworld mods install their own update wrappers.

Controls:

- free movement: renderer 1ST/3RD movement controls;
- `R2` / `Page Up`: ascend;
- `L2` / `Page Down`: descend;
- hold `B`: swim boost;
- `SURFACE`: return through Deep Dive's authored surface links.

## Wild Skies and Dramatic Sky Ride compatibility

Dramatic Sky Ride and Wild Skies are optional.

Deep Dive deliberately avoids self-healing or rewriting their `OverworldState.update` wrapper chain. Earlier experimental guards could create circular wrapper chains; the release uses public/fixed-step seams instead.

When Sky-family compatibility is detected, DIVE/SURFACE uses the safe travel path rather than forcing a cinematic through a conflicting overworld wrapper chain. Once underwater, the full Deep Dive runtime remains active.

## HM06 WHIRLPOOL and HM07 WATERFALL

Deep Dive also provides the two Crystal water HMs as standalone Gen1Recomp mechanics:

- **HM06 WHIRLPOOL** uses the Generation II move (`15` power, `70` accuracy, `15` PP) and removes authored whirlpool barriers for the current map visit, like Crystal;
- **HM07 WATERFALL** uses the Generation II move (`80` power, `100` accuracy, `15` PP), allows climbing authored waterfalls while descending remains free, like Crystal;
- Generation I compatibility follows Pokémon Crystal's HM learnsets;
- extended HMs are protected from move deletion;
- Kanto uses the 7th/8th Kanto badges (`VOLCANOBADGE` / `EARTHBADGE`) as progression equivalents for Crystal's 7th/8th badge field-move gates.

When Crystal 251 is absent, Deep Dive supplies the moves, HM items and standalone Kanto acquisition points. When Crystal 251 is installed, its `WHIRLPOOL`, `WATERFALL`, `HM_06`, `HM_07` and imported Pokémon compatibility are reused instead of duplicated.

The public exports `registerWhirlpool`, `registerWaterfall`, `canWhirlpoolHere` and `canWaterfallHere` let other map/content mods add compatible field-move regions.

## In-game WHIRLPOOL / WATERFALL showcase

DIVE keeps its own presentation. The release also contains two authored examples for the Crystal mechanics:

- **Route 20 — HM06 WHIRLPOOL:** the Seafoam channel has a whirlpool spanning `x=49..50`, covering the full 4-cell channel height. It physically blocks Surf travel until WHIRLPOOL is used while facing it.
- **Route 21 — HM07 WATERFALL:** the central Route 21 current has a 14-cell-wide waterfall at `y=50..51`. The player can descend through the current normally, but must use WATERFALL from below to return north.

## Crystal 251

Crystal 251 is optional. When installed, Deep Dive additively enables DIVE for the canonical Generation II R/S/E-compatible species without replacing Crystal's complete TM/HM lists.

Supported DIVE compatibility:

`TOTODILE`, `CROCONAW`, `FERALIGATR`, `CHINCHOU`, `LANTURN`, `MARILL`, `AZUMARILL`, `POLITOED`, `WOOPER`, `QUAGSIRE`, `SLOWKING`, `QWILFISH`, `REMORAID`, `OCTILLERY`, `MANTINE`, `KINGDRA`, `SUICUNE`, `LUGIA`.

Mount suitability is intentionally separate. Small or visually unsuitable DIVE users are not automatically used as rideable underwater mounts.

## Renderer compatibility

Deep Dive supports either:

- **Battle Art Voxel Fork** — recommended; or
- **Dramaless Shape** — supported alternative.

`VoxelProvider.lua` discovers the installed renderer through its public library API and supplies the same provider to free movement, underwater lighting and custom 3D geometry.

Dramatic Sky Ride remains optional. Deep Dive does not depend on it for mounts and does not add a competing `Player:draw()` path.

## Mount sprites

The active party is searched for a Pokémon that:

1. knows `DIVE`;
2. is considered visually suitable by Deep Dive's mount policy;
3. has an available compatible follower/overworld sprite.

Wilds of Kanto and maintained follower providers can supply these sprites. The normal following Pokémon is suspended while submerged so the mount is not duplicated beside the player.

## Compatibility design

The release intentionally follows several rules that came out of the compatibility testing cycle:

- strict Gen1Recomp event namespace: `mod.DRAMATIC_DEEP_DIVE.*`;
- no dynamic rewriting of Sky Ride / Wild Skies overworld wrapper upvalues;
- fixed-step vertical depth control;
- compatibility-safe DIVE/SURFACE transitions;
- optional dependencies only — Deep Dive remains an independent content mod;
- launcher package keeps `manifest.json` and `main.lua` at archive root.

## Validation

Release CI covers:

- standalone Deep Dive contracts;
- HM06/HM07/HM08 behavior;
- Crystal 251 compatibility;
- Battle Art Voxel Fork compatibility;
- Dramaless Shape compatibility;
- Dramatic Sky Ride interoperability;
- Wilds/Sky compatibility paths;
- launcher-ready packaging.

## Version

Current release: **0.4.0**.
