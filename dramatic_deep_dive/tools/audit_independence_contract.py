#!/usr/bin/env python3
import json, pathlib, sys
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "dramatic_deep_dive")
errors=[]
def bad(msg): errors.append(msg)
manifest=json.loads((root/"manifest.json").read_text())
allowed_required={"PokePCFollowers_VoxelMerge"}
allowed_optional={"DRAMALESS_SHAPE","CRYSTAL_251","DRAMATIC_SKY_RIDE@>=0.1.1 <2.0.0","BATTLE_ART_VOXEL_FORK@>=1.7.6 <2.0.0"}
if set(manifest.get("dependencies",[])) != allowed_required: bad("unexpected required dependency set")
if set(manifest.get("optional_dependencies",[])) != allowed_optional: bad("unexpected optional dependency set")
if manifest.get("conflicts",[]) != []: bad("independent build must not declare mod conflicts")
main=(root/"main.lua").read_text()
for token in ("setExternalProvider", "resolvedEnvironment", "hasMapAliases", "currentExternalZone"):
    if token in main: bad("external DIVE integration hook remains: "+token)
for required in ("DiveTravel.new", "Progression.install", "DepthEncounters.new", "data/dive_links.lua"):
    if required not in main: bad("native Deep Dive ownership missing: "+required)
if errors:
    print("Deep Dive independence contract FAILED")
    for e in errors: print(" -",e)
    raise SystemExit(1)
print("Deep Dive independence contract OK")
