import bpy,os,sys,math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));sys.path.insert(0,ROOT+'/blender')
from model_helpers import *
bpy.ops.wm.open_mainfile(filepath=ROOT+'/blender/courier.blend')
rig=bpy.data.objects['CourierRig']
for tr in rig.animation_data.nla_tracks:tr.mute=tr.name!='idle'
bpy.context.scene.frame_set(1)
box('Preview pedestal',(0,0,-.1),(2,2,.20),material('Preview blue',(.15,.32,.40)),.12)
box('Studio',(0,0,-.25),(200,200,.1),material('Warm backdrop',(.72,.78,.74)),0)
for loc,en,size in [((-3,-4,6),700,4),((3,1,4),500,3)]:bpy.ops.object.light_add(type='AREA',location=loc);bpy.context.object.data.energy=en;bpy.context.object.data.size=size
bpy.ops.object.camera_add(location=(3,-5,3));c=bpy.context.object;c.rotation_euler=(Vector((0,0,.8))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=3.3
s=bpy.context.scene;s.camera=c;s.render.engine='CYCLES';s.cycles.samples=96;s.cycles.use_denoising=False;s.render.resolution_x=720;s.render.resolution_y=720;s.render.resolution_percentage=100;s.world.color=(.35,.35,.35);s.render.filepath=ROOT+'/screenshots/blender_courier.png'
bpy.ops.render.render(write_still=True)
