import bpy,sys,os
from mathutils import Vector
src,out,mode=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(src));s=bpy.context.scene
if mode=='lineup':
 for o in bpy.data.objects:o.hide_render=True
 for name,pos in [('inferno_wall',(-1.05,0,0)),('inferno_wall_b',(1.05,0,0))]:
  root=bpy.data.objects.get(name);assert root,name;root.location=pos
  for o in [root]+list(root.children_recursive):o.hide_render=False
 for o in bpy.data.objects:
  if o.type=='LIGHT':o.hide_render=False
 floor=bpy.data.objects.get('Preview matte studio floor');floor.hide_render=False;floor.location.z=-.08
 c=s.camera;c.hide_render=False;c.location=(3,-5,4.3);c.rotation_euler=(Vector((0,0,.27))-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=5.3
 s.render.resolution_x=1200;s.render.resolution_y=720
else:s.render.resolution_x=1050;s.render.resolution_y=805
s.render.resolution_percentage=100;s.cycles.samples=48;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.035;s.cycles.use_denoising=False;s.render.filepath=os.path.abspath(out)
bpy.ops.render.render(write_still=True)
