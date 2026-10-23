#!/usr/bin/env python3
"""Audit self-contained Blender-exported resources; never downloads anything."""
import json, pathlib, struct, hashlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]

def glb_json(path):
    raw=path.read_bytes()
    magic,version,length=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and length==len(raw), path
    n,t=struct.unpack_from('<II',raw,12)
    assert t==0x4e4f534a
    return json.loads(raw[20:20+n])

def audit():
    report={'models':[], 'errors':[], 'notes':['Visual originality and aesthetic quality require human inspection; this test proves structural facts only.']}
    for path in sorted((ROOT/'assets/models').glob('*.glb')):
        try:
            obj=glb_json(path)
            external=[x.get('uri','') for section in ('buffers','images') for x in obj.get(section,[]) if x.get('uri','') and not x['uri'].startswith('data:')]
            if external: report['errors'].append(f'{path.name}: external resources {external}')
            report['models'].append({'file':str(path.relative_to(ROOT)), 'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'meshes':len(obj.get('meshes',[])), 'materials':len(obj.get('materials',[])), 'animations':[a.get('name','') for a in obj.get('animations',[])], 'generator':obj.get('asset',{}).get('generator','')})
            if not obj.get('meshes'): report['errors'].append(f'{path.name}: no meshes')
        except Exception as e: report['errors'].append(f'{path.name}: {e}')
    report['blend_sources']=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'blender').rglob('*.blend'))]
    if not report['models']: report['errors'].append('No GLB assets found')
    if not report['blend_sources']: report['errors'].append('No Blender source files found')
    report['passed']=not report['errors']
    out=ROOT/'tests/asset_audit.json';out.parent.mkdir(exist_ok=True);out.write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps({'passed':report['passed'],'models':len(report['models']),'sources':len(report['blend_sources']),'errors':report['errors']},ensure_ascii=False))
    return int(not report['passed'])
if __name__=='__main__':sys.exit(audit())
