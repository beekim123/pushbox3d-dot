#!/usr/bin/env python3
"""Produce a reproducible source/resource zip, excluding import caches and scratch output."""
from pathlib import Path
import hashlib, json, zipfile
ROOT=Path(__file__).resolve().parents[1]
EXCLUDE={'.git','.godot','__pycache__','.DS_Store'}
def eligible(p):
    rel=p.relative_to(ROOT)
    return p.is_file() and not any(s in EXCLUDE for s in rel.parts) and p.suffix not in {'.pyc','.blend1','.tmp'} and not p.name.startswith('pipeline_probe')
def main():
    files=sorted(p for p in ROOT.rglob('*') if eligible(p) and p.name!='PACKAGE_MANIFEST.json')
    manifest={str(p.relative_to(ROOT)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}
    (ROOT/'PACKAGE_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
    files.append(ROOT/'PACKAGE_MANIFEST.json')
    target=ROOT.parent/'Loom_of_Four_Horizons_Godot_4.7.2.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in files:z.write(p,Path(ROOT.name)/p.relative_to(ROOT))
    with zipfile.ZipFile(target) as z:
        bad=z.testzip()
        assert bad is None,bad
        for rel,m in manifest.items():assert hashlib.sha256(z.read(f'{ROOT.name}/{rel}')).hexdigest()==m['sha256'],rel
    print(json.dumps({'zip':str(target),'files':len(files),'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'integrity':'PASS'},ensure_ascii=False))
if __name__=='__main__':main()
