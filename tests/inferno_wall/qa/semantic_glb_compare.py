"""Compare semantic triangle/material data despite exporter object/index ordering."""
import argparse,json,struct,hashlib,pathlib
import sys
def fingerprint(p):
 raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];j=json.loads(raw[20:20+n]);off=20+n;blen,btype=struct.unpack_from('<II',raw,off);blob=raw[off+8:off+8+blen]
 def acc(i):
  a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];fmt,size={5126:('f',4),5125:('I',4),5123:('H',2),5121:('B',1)}[a['componentType']];width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];stride=v.get('byteStride',size*width);start=v.get('byteOffset',0)+a.get('byteOffset',0)
  return [struct.unpack_from('<'+fmt*width,blob,start+k*stride) for k in range(a['count'])]
 rows=[];materials={}
 for m in j['meshes']:
  for pr in m['primitives']:
   if pr.get('mode',4)!=4 or set(pr['attributes'])!={'POSITION','NORMAL'}:
    raise ValueError('Only triangle primitives with exactly POSITION/NORMAL are supported')
   mat=j['materials'][pr['material']];name=mat['name'];materials[name]=mat;pos=acc(pr['attributes']['POSITION']);normal=acc(pr['attributes']['NORMAL']);idx=[x[0] for x in acc(pr['indices'])]
   for k in range(0,len(idx),3):
    vs=[tuple(round(x,6) for x in pos[i]+normal[i]) for i in idx[k:k+3]];tri=min(tuple(vs[r:]+vs[:r]) for r in range(3));rows.append((name,tri))
 content=json.dumps({'materials':materials,'triangles':sorted(rows)},sort_keys=True,separators=(',',':')).encode()
 return {'semantic_sha256_rounded_1e_6':hashlib.sha256(content).hexdigest(),'triangles':len(rows),'materials':len(materials),'file_sha256':hashlib.sha256(raw).hexdigest()}

def main():
 parser=argparse.ArgumentParser(description="Compare triangle/material semantics independent of GLB export ordering. Node hierarchy/transforms are NOT compared.")
 parser.add_argument('before',type=pathlib.Path)
 parser.add_argument('after',type=pathlib.Path)
 parser.add_argument('--output',required=True,type=pathlib.Path)
 args=parser.parse_args()
 a=fingerprint(args.before);b=fingerprint(args.after)
 equal=a['semantic_sha256_rounded_1e_6']==b['semantic_sha256_rounded_1e_6']
 report={'before':a,'after':b,'semantic_equal':equal,'coverage':'Orientation-preserving triangles with POSITION/NORMAL rounded 1e-6 plus full named material JSON; excludes node transforms and scene hierarchy.'}
 args.output.parent.mkdir(parents=True,exist_ok=True)
 args.output.write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report,indent=2))
 return 0 if equal else 1
if __name__=='__main__':sys.exit(main())
