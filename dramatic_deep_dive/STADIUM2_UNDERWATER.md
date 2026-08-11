# Stadium 2 underwater wildlife — development preview

This development branch brings the animated Pokemon Stadium 2 model path from Dramatic Sky Ride into Dramatic Deep Dive without changing Deep Dive's underwater gameplay architecture.

## Goal

Visible underwater Pokemon remain the same gameplay entities used by Deep Dive and Wilds of Kanto. When a compatible Stadium 2 DSM4 model is available, only their voxel-world representation changes from a scaled billboard to an animated skinned 3D model.

The fallback remains per Pokemon: a missing, invalid or unavailable Stadium 2 model simply keeps the existing visible 2D billboard.

## Model source

Deep Dive does not ship Stadium 2 model data. It reads the generated Crystal 251 Stadium 2 cache already used by the Dramatic Sky Ride experiment:

- `crystal_251/stadium2/normal/NNN.dsm`
- `crystal_251/stadium2/shiny/NNN.dsm`
- `crystal_251/stadium2/pack.info`

The DSM4 reader is independent and lazy. At most eight decoded model packs are retained by the loader.

## Rendering

The renderer delegates skeleton interpolation and CPU skinning to the active voxel provider's public `StadiumRig` / `StadiumPack` / `Voxel3D` / `ShadowMap` stack. Both Battle Art Voxel Fork and Dramaless Shape are therefore handled through the same provider abstraction already used by Deep Dive.

The Stadium model replaces only the sentinel billboard mesh belonging to a selected Deep Dive wildlife entity. Terrain, camera, underwater geometry, depth buffer, lighting and every ordinary NPC/follower remain owned by the normal voxel pipeline.

The same skinned model participates in the provider shadow path.

## Animation

Each runtime asks for the Stadium idle context first. If that context resolves to a static clip, Deep Dive inspects the packed bone tracks and selects a genuinely moving looping clip where one exists. This mirrors the live-animation recovery proven on the Dramatic Sky Ride Stadium 2 branch.

Animation runs at the source 30 FPS timeline while StadiumRig interpolates between source poses for the display frame rate.

Underwater movement adds procedural presentation rather than replacing the source skeleton:

- smooth yaw follows the swimmer's actual continuous heading rather than four cardinal directions;
- ascent/descent adds a restrained pitch;
- a small slow buoyancy bob prevents models from reading as rigidly pinned in the water;
- Stadium authored material/eye animation is retained;
- generated effect flipbooks such as fire/gas texture primitives remain supported.

## Physical scale

Model scale is derived from the Pokemon's Pokédex height, not from the arbitrary raw N64 model units.

A median roughly three-foot Pokemon is about one overworld cell tall. The real Pokédex size spread is compressed with an exponent so tiny Pokemon stay readable and huge Pokemon remain impressive without filling the entire camera. The current hard visual range is approximately 8.5 to 46 world pixels.

Long-bodied or unusually proportioned aquatic species receive small morphology multipliers. The raw Stadium model height is then normalized into that target world height using the model's own `rootScale` and measured bind height.

## LOD / performance

Deep Dive can still spawn a rich ocean population, but it does not skin every visible creature in 3D.

Current limits:

- nearest 10 eligible wildlife entities use Stadium 2 models;
- candidates farther than 24 movement cells stay on the existing billboard path;
- rigs are released when an entity leaves the active 3D set;
- missing/corrupt DSM4 packs never disable the rest of the wildlife system.

This keeps the rich-ocean gameplay density separate from the CPU/GPU model budget.

## Safety

The integration deliberately does **not** rewrite `OverworldState.update`, inspect/replace closure upvalues, or alter the encounter system. Animation advancement uses the public `input.step` hook and attaches a small pose decorator only to Deep Dive wildlife entities.

The existing Wilds visible-Pokemon-only battle policy is unchanged: the Stadium model is a representation of the same swimmer entity, with the same species and level that the interception system uses for battle.

## Automated contract

`.github/workflows/stadium2-underwater-contract.yml` validates:

- all Deep Dive Lua sources parse;
- a synthetic DSM4 pack can be read by the new loader;
- the Crystal 251 Stadium 2 cache path remains the source;
- StadiumRig remains the animation/skinning backend;
- moving-animation recovery and model LOD remain present;
- the module does not introduce `OverworldState.update` replacement or `debug.setupvalue` surgery.

## Runtime testing priorities

The most useful initial species are models that expose different failure modes:

- Magikarp / Horsea — small-model readability;
- Tentacool / Tentacruel — size ladder and flexible anatomy;
- Lapras — broad large-body scale;
- Gyarados — long-body scale and camera framing;
- Charizard (diagnostic only if injected into underwater ecology) — known animated DSM4 and effect-frame reference from the Sky Ride work.

The expected result is a moving, smoothly oriented model located at the exact position and depth of the existing visible underwater Pokemon. If any species cannot create a valid rig, it must remain a normal visible billboard rather than disappearing.
