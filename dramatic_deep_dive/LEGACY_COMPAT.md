# Legacy Dramatic Shape compatibility

Dramatic Deep Dive supports three voxel-provider families on this development branch:

1. **Battle Art Voxel Fork** — preferred modern provider.
2. **Dramaless Shape** — modern alternate provider.
3. **Dramatic Shape (`DRAMATIC_SHAPE`)** — legacy compatibility provider.

Provider priority is intentionally kept in that order. Legacy Dramatic Shape is used only when neither modern provider is available.

## Legacy + Pokemon Stadium Overworld Models

When the selected provider is legacy Dramatic Shape and `STADIUM_OVERWORLD_MODELS` is installed, Deep Dive does **not** install a second Pokemon model renderer.

Instead, visible underwater wildlife remains owned by Deep Dive for:

- species and level;
- spawn/despawn;
- X/Z movement;
- free-depth position;
- encounter interception;
- flee/school behaviour.

Deep Dive explicitly delegates each swimmer's Pokemon identity to Stadium Overworld Models. The legacy renderer already consumes the entity pose's vertical `lift`, so the 3D model follows the exact underwater depth produced by Deep Dive rather than being pinned to the map floor.

This avoids two independent Stadium systems trying to patch/render the same Dramatic Shape `VoxelScene`.

## Legacy without Pokemon Stadium Overworld Models

If legacy Dramatic Shape is the selected provider but Stadium Overworld Models is absent, Deep Dive may use its own Stadium 2 DSM4 renderer when the installed Dramatic Shape build exposes the required `StadiumRig`, `StadiumPack`, `Voxel3D` and shadow modules.

If those modules are not available, visible Pokemon fall back to the existing 2D wildlife sprites rather than disappearing.

## Progression safety

HM08 registration happens before voxel-provider discovery. In addition, `main_stadium.lua` now reinstalls the exterior Cinnabar HM08 researcher if no compatible voxel provider can be initialized.

A graphics-provider mismatch must therefore no longer silently remove the HM08 NPC. The free-depth underwater renderer still requires a compatible voxel provider.

## Intended compatibility matrix

| Configuration | Result |
| --- | --- |
| Battle Art | Modern Deep Dive renderer |
| Battle Art + Dramaless | Battle Art render path + compatible Stadium backend |
| Dramaless | Modern alternate renderer |
| Dramatic Shape | Legacy Deep Dive renderer |
| Dramatic Shape + Stadium Overworld Models | Legacy renderer with delegated Pokemon models |
| No compatible voxel provider | HM08 progression retained; free-depth renderer unavailable |

`DRAMALESS_SHAPE` and `DRAMATIC_SHAPE` may conflict in their own manifests, so they are not expected to be enabled together merely for Deep Dive.
