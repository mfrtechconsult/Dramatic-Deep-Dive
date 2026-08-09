#!/usr/bin/env python3
import json, pathlib, re, sys
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "dramatic_deep_dive")
errors=[]
def bad(msg): errors.append(msg)
manifest=json.loads((root/"manifest.json").read_text())
text='\n'.join(p.read_text(errors='ignore') for p in root.rglob('*') if p.is_file() and p.suffix in {'.lua','.json','.md'})
content=(root/"src/Content.lua").read_text()
progression=(root/"src/Progression.lua").read_text()
if 'id = "HM_DIVE"' not in content: bad("standalone HM_DIVE registration missing")
if 'name = "HM08"' not in content: bad("HM_DIVE is not presented as HM08")
if 'move = "DIVE", number = 8' not in content: bad("HM_DIVE does not teach DIVE as HM08")
if 'HM08 contains DIVE' not in progression: bad("progression text does not present DIVE as HM08")
old_label="HM"+"06"
old_number="number = "+"6"
old_compare="machine.number == "+"6"
if old_number in text or old_compare in text: bad("legacy numerical DIVE machine assumption remains")
legacy="MOD_DRAMATIC_DEEP_DIVE_HM"+"06_RECEIVED"
for m in re.finditer(old_label, text):
    if legacy not in text[max(0,m.start()-80):m.end()+80]:
        bad("legacy HM label appears outside the historical Deep Dive save key")
        break
if "CRYSTAL_251" not in manifest.get("optional_dependencies",[]): bad("Crystal 251 must stay optional")
if errors:
    print("Deep Dive HM contract FAILED")
    for e in errors: print(" -",e)
    raise SystemExit(1)
print("Deep Dive HM08 contract OK")
