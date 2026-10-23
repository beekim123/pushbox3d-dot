"""Inspect exported binary glTF without third-party dependencies."""
import os,json,struct
root=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
records=[]
for name in sorted(os.listdir(root+'/assets/models')):
 if not name.endswith('.glb'):continue
 path=root+'/assets/models/'+name
 with open(path,'rb') as f:
  magic,version,total=struct.unpack('<III',f.read(12));assert magic==0x46546c67 and version==2
  n,kind=struct.unpack('<II',f.read(8));assert kind==0x4e4f534a
  j=json.loads(f.read(n));assert not j.get('images'),name+' contains an image'
  assert all('uri' not in b for b in j.get('buffers',[])),name+' has external buffers'
  records.append({'file':name,'bytes':os.path.getsize(path),'meshes':len(j.get('meshes',[])),'materials':len(j.get('materials',[])),'animations':[a['name'] for a in j.get('animations',[])],'embedded_images':0,'external_buffers':0})
json.dump({'asset_count':len(records),'assets':records},open(root+'/blender/glb_audit.json','w'),indent=2)
print('GLB assets:',len(records),'No image textures or external buffers. Animation clips:')
for r in records:
 if r['animations']:print(r['file'],r['animations'])
