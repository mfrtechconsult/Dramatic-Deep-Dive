#!/usr/bin/env python3
import pathlib, sys
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "vendor/crystal-251")
text="\n".join(p.read_text(errors="replace") for p in root.rglob("*.lua"))
required=["TOTODILE","CROCONAW","FERALIGATR","CHINCHOU","LANTURN","MARILL","AZUMARILL","POLITOED","WOOPER","QUAGSIRE","SLOWKING","QWILFISH","REMORAID","OCTILLERY","MANTINE","KINGDRA","SUICUNE","LUGIA"]
missing=[x for x in required if x not in text]
if missing:
    print("Crystal 251 source audit FAILED; missing:",", ".join(missing)); sys.exit(1)
print("Crystal 251 source audit OK: all 18 requested species are present")
