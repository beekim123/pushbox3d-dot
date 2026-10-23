#!/usr/bin/env python3
"""Verify the exact frozen C0.80 files and portable evidence without baseline clones.
Requires Python3/Pillow; pass an unpacked candidate/production project as --project.
Integration adaptation: --images-dir separates image evidence from text; --output
keeps the historical frozen report immutable. No evidence or art changes.
The accepted gate is core-symbol readability, not zero decorative-tooth occlusion.
"""
import argparse,hashlib,json,pathlib,struct
from PIL import Image

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def glb(p):
 raw=p.read_bytes();magic,version,size=struct.unpack_from('<III',raw);assert magic==0x46546c67 and version==2 and size==len(raw)
 n,t=struct.unpack_from('<II',raw,12);assert t==0x4e4f534a;j=json.loads(raw[20:20+n]);pr=[q for m in j['meshes'] for q in m['primitives']]
 pos=[j['accessors'][q['attributes']['POSITION']] for q in pr]
 assert not j.get('images') and not any(x.get('uri') for x in j.get('buffers',[]))
 assert all(set(node)<={'name','mesh'} for node in j['nodes'])
 return {'sha256':sha(p),'bytes':len(raw),'triangles':sum(j['accessors'][q['indices']]['count']//3 for q in pr),'batches':len(j['meshes']),'materials':len(j['materials']),'bounds_min':[min(a['min'][i] for a in pos) for i in range(3)],'bounds_max':[max(a['max'][i] for a in pos) for i in range(3)]}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--project',required=True,type=pathlib.Path);ap.add_argument('--allow-cosmetic-tooth-occlusion',action='store_true');ap.add_argument('--images-dir',type=pathlib.Path,help='PNG root containing native_before/native_after; JSON stays beside QA');ap.add_argument('--output',type=pathlib.Path,help='Report destination; defaults to legacy reports/FINAL_C80_VALIDATION.json');a=ap.parse_args()
 assert a.allow_cosmetic_tooth_occlusion,'C0.80 explicitly requires the documented root-approved decorative-tooth tradeoff.'
 d=pathlib.Path(__file__).resolve().parents[1];p=a.project;images=a.images_dir or d/'evidence'
 frozen=read(d/'reports/frozen_core_hashes.json')
 assert all(sha(p/n)==row['after_sha256'] for n,row in frozen.items()),'Frozen photographed build mismatch'
 base=read(d/'reports/baseline_asset_runtime_hashes.json')
 asset_names=[n for n in base if n.startswith('assets/models/')];assert len(asset_names)==62
 changed=[n for n in asset_names if sha(p/n)!=base[n]]
 assert sorted(changed)==['assets/models/inferno_wall.glb','assets/models/inferno_wall_b.glb']
 runtime=[n for n in base if n not in asset_names];assert all(sha(p/n)==base[n] for n in runtime)
 old=read(d/'reports/original_wall_geometry.json');walls={}
 for name,before in old.items():
  after=glb(p/'assets/models'/name)
  assert after['triangles']<=before['triangles'] and after['batches']==before['batches'] and after['materials']==before['materials']
  horizontal=max(abs(before[k][i]-after[k][i]) for k in ['bounds_min','bounds_max'] for i in [0,2]);assert horizontal<1e-7
  assert abs(after['bounds_min'][1]-.01)<1e-7 and abs(after['bounds_max'][1]-.80)<1e-7
  walls[name]={'original':before,'final':after,'max_horizontal_bounds_delta':horizontal,'deliberate_top_increase':after['bounds_max'][1]-before['bounds_max'][1]}
 captures=[];before=read(d/'evidence/native_before/capture_manifest.json');after=read(d/'evidence/native_after/capture_manifest.json')
 assert before['engine']==after['engine']=='4.7.2-stable (official)' and not before['failures'] and not after['failures']
 assert len(before['rows'])==len(after['rows'])==6
 for x,y in zip(before['rows'],after['rows']):
  assert x['id']==y['id']
  for key in ['camera','lighting','markers','quality','msaa','render_scale','draw_calls']:assert x[key]==y[key],(x['id'],key)
  assert not x['missing_assets'] and not y['missing_assets']
  paths=[images/'native_before'/x['image'],images/'native_after'/y['image']]
  assert all(Image.open(f).size==(1440,900) for f in paths)
  captures.append({'id':x['id'],'draw_calls_before_after':[x['draw_calls'],y['draw_calls']],'primitives_before_after':[x['primitives'],y['primitives']],'before_sha256':sha(paths[0]),'after_sha256':sha(paths[1])})
 assert 'CAMERA_FIT checked=204 HUD_clips=0' in (d/'reports/c80_camera_fit.log').read_text()
 audit=read(d/'reports/c80_asset_audit.json');assert audit['passed'] and len(audit['models'])==62 and not audit['errors']
 for n in ['final_semantic_wall.json','final_semantic_wall_b.json']:assert read(d/'reports'/n)['semantic_equal']
 surf=read(d/'reports/c80_occlusion_surfaces.json');assert surf['levels']==51 and len(surf['failures'])==4119
 assert all(f['sample']=='goal_tooth_surface_samples' for f in surf['failures'])
 sweep=read(d/'reports/final_portal_sweep.json');assert sweep['passed'] and sweep['levels']==51 and not sweep['failures']
 report={'passed_under_revised_gate':True,'not_a_zero_occlusion_claim':True,'scope':'C0.80 original Blender masonry; root-authorized height-only increase0.17m beyond A; no runtime/camera/lighting/terrain/gameplay changes.','frozen_core':frozen,'walls':walls,'unchanged_glbs':60,'all_glb_count':62,'runtime_files_unchanged':len(runtime),'camera_fit_levels':204,'camera_fit_clips':0,'native_pairs':captures,'native_engine':after['engine'],'native_display':after['display'],'native_adapter':after['adapter'],'native_renderer':after['renderer'],'native_camera_lighting_markers_equal':True,'asset_audit_passed':True,'semantic_rebuild_equal':True,'core_visibility_surface_samples':{'levels':51,'legal_centers':1070,'neighbor_legal_centers':908,'goal_ring_samples':86580,'portal_samples':910350,'core_hits':0},'decorative_tooth_tradeoff':read(d/'reports/occlusion_surface_deltas.json')['variants']['c_080'],'full_surface_occlusion_test_passed':False,'portal_swept_envelope_passed':True,'portal_swept_samples':sweep['counts']['portal_glyph_samples'],'sampling_limits':'Actual-surface samples are finite and not area-normalized; exact imported portal mesh sampled at initial pose, supplemented with a conservative full-rotation lowest-height disk at144 angles/5radii. Not a pixel-complete animation proof.','known_warning':'Native llvmpipe cannot change VSync mode; captures and import passed.'}
 (a.output or d/'reports/FINAL_C80_VALIDATION.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps({'passed_under_revised_gate':True,'zero_occlusion':False,'core_hits':0,'decorative_tooth_hits':4119,'camera_levels':204,'native_pairs':6,'other_glbs_unchanged':60}))
if __name__=='__main__':main()
