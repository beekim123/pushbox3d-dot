"""Independent binary-GLB bounds/material/image/animation audit for the three v2 kits."""
import json,struct,pathlib,math
ROOT=pathlib.Path(__file__).resolve().parents[1]

def read(path):
    raw=path.read_bytes();magic,version,length=struct.unpack_from('<III',raw,0)
    assert magic==0x46546c67 and version==2 and length==len(raw)
    jlen,jtype=struct.unpack_from('<II',raw,12);assert jtype==0x4e4f534a
    j=json.loads(raw[20:20+jlen]);boff=20+jlen;blen,btype=struct.unpack_from('<II',raw,boff)
    assert btype==0x004e4942
    return j,raw[boff+8:boff+8+blen]

def positions(j,b,index):
    a=j['accessors'][index];v=j['bufferViews'][a['bufferView']]
    assert a['type']=='VEC3' and a['componentType']==5126
    off=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',12)
    return [struct.unpack_from('<fff',b,off+i*stride) for i in range(a['count'])]

report=[]
for path in sorted((ROOT/'assets/models').glob('*.glb')):
    if not path.name.startswith(('inferno_','rainforest_','city_')):continue
    j,b=read(path);assert not j.get('images') and all('uri' not in v for v in j.get('buffers',[]))
    pts=[];triangles=0;primitives=0
    for me in j.get('meshes',[]):
        for p in me.get('primitives',[]):
            primitives+=1
            pts+=positions(j,b,p['attributes']['POSITION'])
            if 'indices' in p:triangles+=j['accessors'][p['indices']]['count']//3
    rec={'asset':path.name,'bytes':path.stat().st_size,'mesh_batches':len(j.get('meshes',[])),'materials':len(j.get('materials',[])),'triangles':triangles,'animations':[a['name'] for a in j.get('animations',[])],'embedded_images':0,'external_buffers':0}
    # Static consolidated meshes have identity transforms, hence direct bounds are game-space.
    if not rec['animations']:
        rec['bounds_min']=[round(min(v[i] for v in pts),4) for i in range(3)]
        rec['bounds_max']=[round(max(v[i] for v in pts),4) for i in range(3)]
        if path.stem.endswith('_landscape'):
            invading=[v for v in pts if abs(v[0])<6.98 and abs(v[2])<6.98 and v[1]>.15]
            rec['playable_clearance_violating_vertices']=len(invading)
            rec['clearance_pass']=not invading
        if path.stem.endswith('_tile'):
            rec['tile_height_pass']=rec['bounds_max'][1]<.18
        if '_wall' in path.stem:rec['wall_height_pass']=rec['bounds_max'][1]<1.0
    report.append(rec)
result={'asset_count':len(report),'original_texture_free':True,'assets':report}
out=ROOT/'blender/worlds_v2_geometry_audit.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2))
for r in report:
    if r['asset'].endswith(('_landscape.glb','_landmark.glb','_tile.glb','_wall.glb')):
        print(r['asset'],r['mesh_batches'],'batches',r['triangles'],'tris',r.get('bounds_min'),r.get('bounds_max'),'clearance',r.get('clearance_pass','n/a'))
print('Audited',len(report),'original texture-free self-contained GLBs')
