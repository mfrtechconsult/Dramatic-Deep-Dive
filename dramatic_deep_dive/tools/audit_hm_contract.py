#!/usr/bin/env python3
import json, pathlib, re, sys
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "dramatic_deep_dive")
errors=[]
def bad(msg): errors.append(msg)
manifest=json.loads((root/"manifest.json").read_text())
content=(root/"src/Content.lua").read_text()
progression=(root/"src/Progression.lua").read_text()
code='\n'.join(p.read_text(errors='ignore') for p in root.rglob('*.lua'))

# DIVE itself must remain HM08. HM06 is intentionally WHIRLPOOL now.
if 'id = "HM_DIVE"' not in content: bad("standalone HM_DIVE registration missing")
if 'name = "HM08"' not in content: bad("HM_DIVE is not presented as HM08")
if 'move = "DIVE", number = 8' not in content: bad("HM_DIVE does not teach DIVE as HM08")
if 'HM08 contains DIVE' not in progression: bad("progression text does not present DIVE as HM08")

# Reject only concrete legacy DIVE=HM06 code/presentation forms. Documentation
# may legitimately mention HM06 WHIRLPOOL and HM08 DIVE on the same line.
legacy_dive_patterns = (
    r'move\s*=\s*"DIVE"\s*,\s*number\s*=\s*6',
    r'name\s*=\s*"HM06"[^\n]{0,160}move\s*=\s*"DIVE"',
    r'HM06\s+contains\s+DIVE',
)
for pattern in legacy_dive_patterns:
    if re.search(pattern, code + '\n' + progression, flags=re.IGNORECASE):
        bad("legacy DIVE-as-HM06 presentation remains")
        break

# Historical save key is intentionally retained for old alpha saves.
legacy_key="MOD_DRAMATIC_DEEP_DIVE_HM06_RECEIVED"
if legacy_key not in code:
    bad("historical Deep Dive HM06 receipt save key was removed")

if "CRYSTAL_251" not in manifest.get("optional_dependencies",[]): bad("Crystal 251 must stay optional")
if errors:
    print("Deep Dive HM contract FAILED")
    for e in errors: print(" -",e)
    raise SystemExit(1)
print("Deep Dive HM08 contract OK")
