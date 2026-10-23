import bpy, os, sys, math
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));sys.path.insert(0,ROOT+'/blender')
from model_helpers import *
from generate_assets import palette, make_asset, roof, cloud, export_asset, OUT
clear();p=palette('hub');groups={}
def group(name,fn):
 before=set(bpy.data.objects);fn();groups[name]=list(set(bpy.data.objects)-before)
def body():
 sphere('Porcelain spool body',(0,0,.77),(.29,.23,.37),p['ivory'])
 cone('Navy travelling poncho',(0,0,.84),.40,.23,.37,p['navy'])
 torus('Brass poncho hem',(0,0,.66),.35,.025,p['gold'])
 sphere('Poncho clasp',(0,-.24,1),(.06,.035,.06),p['gold'])
 # Bobbin backpack horizontal axis
 o=cylinder('Wound backpack bobbin',(0,.29,.86),.20,.38,p['accent']);o.rotation_euler[1]=math.pi/2
 for x in [-.23,.23]:
  o=cylinder('Backpack spool flange',(x,.29,.86),.27,.07,p['gold']);o.rotation_euler[1]=math.pi/2
 for x in [-.12,0,.12]:o=torus('Thread coils',(x,.29,.86),.21,.018,p['ivory'],(0,math.pi/2,0))
def head():
 sphere('Pear shaped porcelain head',(0,-.015,1.29),(.31,.27,.31),p['ivory'])
 sphere('Ivory face mask',(0,-.23,1.27),(.245,.085,.20),p['white'])
 for x in [-.105,.105]:sphere('Courier ink eye',(x,-.306,1.30),(.035,.025,.055),p['navy']);sphere('Cheek glaze',(x*1.5,-.291,1.20),(.045,.015,.025),p['accent'])
 curve('Gentle smile',[(-.05,-.316,1.20),(0,-.325,1.185),(.05,-.316,1.20)],p['navy'],.012)
 cone('Spool cap',(0,0,1.54),.23,.20,.12,p['base']);torus('Cap brass rim',(0,0,1.50),.235,.025,p['gold'])
 for x in [-.10,.10]:curve('Antenna ribbon',[(x,0,1.59),(x*1.5,.02,1.82),(x*2.3,-.08,1.78)],p['accent'] if x<0 else p['gold'],.035)
def arm(side):
 x=side*.36;sphere('Poncho sleeve',(x,0,.85),(.13,.14,.22),p['base']);sphere('Little glove',(x,-.04,.62),(.12,.11,.13),p['ivory'])
def leg(side):
 x=side*.15;cylinder('Wooden leg',(x,0,.36),.07,.28,p['wood']);sphere('Rounded walking boot',(x,-.07,.16),(.13,.21,.13),p['navy']);box('Brass boot sole',(x,-.07,.055),(.25,.36,.055),p['gold'],.04)
group('body',body);group('head',head)
for s,n in [(-1,'left'),(1,'right')]:group(n+'_arm',lambda s=s:arm(s));group(n+'_leg',lambda s=s:leg(s))
# Apply bevel modifiers and convert curve ribbon/face to skinned mesh.
for objs in groups.values():
 for o in list(objs):
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
  if o.type=='CURVE':bpy.ops.object.convert(target='MESH')
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0));rig=bpy.context.object;rig.name='CourierRig';ed=rig.data.edit_bones;ed.remove(ed[0])
coords={'body':((0,0,.55),(0,0,1.0),None),'head':((0,0,1.05),(0,0,1.55),'body'),'left_arm':((-.34,0,.98),(-.34,0,.62),'body'),'right_arm':((.34,0,.98),(.34,0,.62),'body'),'left_leg':((-.15,0,.51),(-.15,0,.15),'body'),'right_leg':((.15,0,.51),(.15,0,.15),'body')}
for name,(a,b,parent) in coords.items():bone=ed.new(name);bone.head=a;bone.tail=b
for name,(_,_,parent) in coords.items():
 if parent:ed[name].parent=ed[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for name,objs in groups.items():
 for o in objs:
  vg=o.vertex_groups.new(name=name);vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE');mod=o.modifiers.new('Rigid toy articulation','ARMATURE');mod.object=rig;o.parent=rig
for pb in rig.pose.bones:pb.rotation_mode='XYZ'
rig.animation_data_create()
for clip,length in [('idle',48),('walk',24),('push',30),('celebrate',60)]:
 action=bpy.data.actions.new(clip);rig.animation_data.action=action
 for f in range(1,length+2,3):
  phase=(f-1)/length*math.tau
  for pb in rig.pose.bones:pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
  if clip=='idle':
   rig.pose.bones['head'].rotation_euler[1]=math.sin(phase)*.045;rig.pose.bones['body'].location[1]=math.sin(phase)*.018
   for n in ['left_arm','right_arm']:rig.pose.bones[n].rotation_euler[0]=math.sin(phase)*.035
  elif clip=='walk':
   rig.pose.bones['body'].location[1]=abs(math.sin(phase))*.045
   for n,sgn in [('left',1),('right',-1)]:rig.pose.bones[n+'_leg'].rotation_euler[0]=math.sin(phase)*.48*sgn;rig.pose.bones[n+'_arm'].rotation_euler[0]=-math.sin(phase)*.34*sgn
   rig.pose.bones['head'].rotation_euler[2]=math.sin(phase)*.04
  elif clip=='push':
   effort=math.sin((f-1)/length*math.pi)**2;rig.pose.bones['body'].rotation_euler[0]=-.20*effort
   for n in ['left_arm','right_arm']:rig.pose.bones[n].rotation_euler[0]=-1.10*effort
   rig.pose.bones['left_leg'].rotation_euler[0]=.25*effort;rig.pose.bones['right_leg'].rotation_euler[0]=-.23*effort
  else:
   rig.pose.bones['body'].location[1]=abs(math.sin(phase))*0.18;rig.pose.bones['head'].rotation_euler[2]=math.sin(phase)*.17
   rig.pose.bones['left_arm'].rotation_euler[2]=-.9*abs(math.sin(phase));rig.pose.bones['right_arm'].rotation_euler[2]=.9*abs(math.sin(phase));rig.pose.bones['left_arm'].rotation_euler[0]=-.5
  for pb in rig.pose.bones:pb.keyframe_insert('rotation_euler',frame=f);pb.keyframe_insert('location',frame=f)
 action.use_fake_user=True
 rig.animation_data.action=None
 # Each named NLA track yields one clean GLB animation clip.
 tr=rig.animation_data.nla_tracks.new();tr.name=clip;st=tr.strips.new(clip,1,action);st.name=clip
# GLTF NLA export, one animation for every named track; disable tracks influencing rest export.
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=OUT+'/courier.glb',export_format='GLB',use_selection=True,export_apply=False,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/courier.blend')
# V2 uses generate_hub_garden.py. Legacy generator is opt-in for archival rebuilds.
if '--legacy-hub' not in sys.argv:
 sys.exit(0)
# Hub kit reuses common craft vocabulary; independent authored modular exports.
clear();p=palette('hub')
for i,k in enumerate(['tile','edge','wall','crate','goal','decor_a','decor_b','creature']):
 # hub decorators handled by city branch in shared generator; all original.
 make_asset('hub',k,p).location=(40+i*4,0,0)
before=set(bpy.data.objects)
cylinder('Compass loom plinth',(0,0,.16),1.45,.32,p['ivory'],64,.08);torus('Compass brass orbit',(0,0,.36),1.12,.055,p['gold'])
for a in range(4):
 th=a*math.pi/2;curve('Loom arch',[(math.cos(th)*1.1,math.sin(th)*1.1,.36),(math.cos(th)*.9,math.sin(th)*.9,2.3),(0,0,2.6)],p['gold'],.055)
 o=box('Compass inlay',(math.sin(th)*.90,math.cos(th)*.90,.34),(.15,.30,.03),p['base'],.025);o.rotation_euler[2]=-th
cylinder('Central great spool',(0,0,1),.45,1.1,p['base']);cylinder('Spool lower lip',(0,0,.50),.65,.17,p['gold']);cylinder('Spool upper lip',(0,0,1.5),.65,.17,p['gold'])
for z in [.66,.85,1.04,1.23,1.42]:torus('Woven porcelain thread',(0,0,z),.47,.038,p['ivory'])
sphere('Loom crown pearl',(0,0,2.6),(.18,.18,.18),p['accent'])
objs=list(set(bpy.data.objects)-before);root=parent_all(objs,'hub_center');objs.append(root);export_asset(OUT+'/hub_center.glb',objs)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/hub_kit.blend')
