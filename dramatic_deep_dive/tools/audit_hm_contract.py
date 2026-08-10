#!/usr/bin/env python3
import json, pathlib, re, sys
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "dramatic_deep_dive")
errors=[]
def bad(msg): errors.append(msg)
manifest=json.loads((root/"manifest.json").read_text())
content=(root/"src/Content.lua").read_text()
progression=(root/"src/Progression.lua").read_text()
text='\n'.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file() and p.suffix in {'.lua','.json','.md'})

# DIVE itself must remain HM08. HM06 is now intentionally occupied by
# Crystal-style WHIRLPOOL, so generic HM06 text is no longer a legacy error.
if 'id = "HM_DIVE"' not in content: bad("standalone HM_DIVE registration missing")
if 'name = "HM08"' not in content: bad("HM_DIVE is not presented as HM08")
if 'move = "DIVE", number = 8' not in content: bad("HM_DIVE does not teach DIVE as HM08")
if 'HM08 contains DIVE' not in progression: bad("progression text does not present DIVE as HM08")

# Reject only the old DIVE-as-HM06 contract, not the legitimate WHIRLPOOL HM06.
legacy_dive_patterns = (
    r'move\s*=\s*"DIVE"\s*,\s*number\s*=\s*6',
    r'HM06\s+contains\s+DIVE',
    r'HM06[^\n]{0,80}\bDIVE\b',
    r'\bDIVE\b[^\n]{0,80}HM06',
)
for pattern in legacy_dive_patterns:
    if re.search(pattern, text, flags=re.IGNORECASE):
        bad("legacy DIVE-as-HM06 presentation remains")
        break

# Historical save key is intentionally retained for old alpha saves.
legacy_key="MOD_DRAMATIC_DEEP_DIVE_HM06_RECEIVED"
if legacy_key not in text:
    bad("historical Deep Dive HM06 receipt save key was removed")

if "CRYSTAL_251" not in manifest.get("optional_dependencies",[]): bad("Crystal 251 must stay optional")
if errors:
    print("Deep Dive HM contract FAILED")
    for e in errors: print(" -",e)
    raise SystemExit(1)
print("Deep Dive HM08 contract OK")
