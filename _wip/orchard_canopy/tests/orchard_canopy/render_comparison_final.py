import bpy,sys,os,json
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:];src,out,mode=args
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(src));s=bpy.context.scene
if mode=='lineup':
 for o in bpy.data.objects:o.hide_render=True
 for name,pos in [('heaven_landmark',(-4.4,0,0)),('heaven_landmark_b',(1.1,0,0)),('heaven_decor_a',(5.5,0,0))]:
  root=bpy.data.objects.get(name);assert root,name;root.location=pos
  for o in [root]+list(root.children_recursive):o.hide_render=False
 for o in list(bpy.data.objects):
  if o.type=='LIGHT':o.hide_render=False
 ground=bpy.data.objects.get('Preview sky studio');ground.hide_render=False;ground.location.z=-.25
 c=s.camera;c.hide_render=False;c.location=(10,-23,14);c.rotation_euler=(Vector((0,0,2.2))-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=18
 s.render.resolution_x=1800;s.render.resolution_y=960
else:s.render.resolution_x=1400;s.render.resolution_y=1050
s.render.resolution_percentage=100;s.cycles.samples=48;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.035;s.cycles.use_denoising=False;s.render.filepath=os.path.abspath(out)
bpy.ops.render.render(write_still=True)
