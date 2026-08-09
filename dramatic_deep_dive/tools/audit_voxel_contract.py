#!/usr/bin/env python3
import json, pathlib, re, sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "dramatic_deep_dive")
errors = []
def bad(msg): errors.append(msg)

manifest = json.loads((root / "manifest.json").read_text())
deps = [str(x) for x in manifest.get("dependencies", [])]
opts = [str(x) for x in manifest.get("optional_dependencies", [])]
if any(x.startswith("BATTLE_ART_VOXEL_FORK") for x in deps):
    bad("Battle Art Voxel Fork must not be required; renderer dependency is OR")
if any(x == "DRAMALESS_SHAPE" or x.startswith("DRAMALESS_SHAPE@") for x in deps):
    bad("Dramaless Shape must not be required; renderer dependency is OR")
if not any(x.startswith("BATTLE_ART_VOXEL_FORK") for x in opts):
    bad("Battle Art Voxel Fork is not optional")
if not any(x == "DRAMALESS_SHAPE" or x.startswith("DRAMALESS_SHAPE@") for x in opts):
    bad("DRAMALESS_SHAPE is not optional")

provider = (root / "src/VoxelProvider.lua").read_text()
for token in ("BATTLE_ART_VOXEL_FORK", "DRAMALESS_SHAPE", '"voxel"', '"st_voxel"'):
    if token not in provider: bad(f"VoxelProvider missing {token}")
if "exports.lib" not in provider and "handle.exports" not in provider:
    bad("VoxelProvider does not consume provider public exports")

legacy_runtime = []
for rel in ("src/DeepDive.lua", "src/VoxelRenderer.lua", "src/UnderwaterLighting.lua"):
    p = root / rel
    if not p.exists():
        bad(f"missing runtime file {rel}")
        continue
    text = p.read_text(errors="replace")
    if re.search(r'mod\.find[^\n]+BATTLE_ART_VOXEL_FORK', text):
        legacy_runtime.append(rel)
if legacy_runtime and "installCompatibilityShim" not in provider:
    bad("legacy renderer lookups remain but VoxelProvider compatibility shim is missing")

main = (root / "main.lua").read_text()
for needle in ("VoxelProvider.new", "voxelProvider:discover", "installCompatibilityShim", "voxelProvider:id"):
    if needle not in main: bad(f"main.lua missing {needle}")

def audit_external(path, expected_id):
    path = pathlib.Path(path)
    if not path.exists():
        bad(f"external provider path not found: {path}")
        return
    mf = path / "manifest.json"
    if not mf.exists():
        bad(f"{path}: manifest missing")
        return
    data = json.loads(mf.read_text())
    if data.get("id") != expected_id:
        bad(f"{path}: expected id {expected_id}, got {data.get('id')}")
    mainp = path / "main.lua"
    if not mainp.exists():
        bad(f"{path}: main.lua missing")
    else:
        text = mainp.read_text(errors="replace")
        if "exports.lib" not in text:
            bad(f"{path}: public exports.lib seam missing")
    for rel in ("lib/Voxel3D.lua", "lib/FreeMove.lua", "lib/FirstPerson.lua"):
        if not (path / rel).exists(): bad(f"{path}: missing {rel}")

args = sys.argv[2:]
for spec in args:
    if "=" not in spec: continue
    expected, path = spec.split("=", 1)
    audit_external(path, expected)

if errors:
    print("Voxel provider audit FAILED")
    for e in errors: print(" -", e)
    sys.exit(1)
print("Voxel provider audit OK")
