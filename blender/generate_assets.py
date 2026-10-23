"""Loom of Four Horizons: all original geometry, materials and animation.
Run: blender --background --python blender/generate_assets.py [-- heaven]
Coordinates Blender Z up/-Y forward; exported GLB Godot Y up/+Z forward.
"""
import bpy, math, os, sys, random
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));sys.path.insert(0,ROOT+'/blender')
from model_helpers import *
OUT=ROOT+'/assets/models'; SHOTS=ROOT+'/screenshots';os.makedirs(OUT,exist_ok=True);os.makedirs(SHOTS,exist_ok=True)
random.seed(24)
THEMES={
'heaven':{'base':(.12,.52,.48),'light':(.62,.85,.73),'accent':(.82,.19,.15),'dark':(.035,.16,.22),'floor':(.76,.86,.77)},
'inferno':{'base':(.32,.11,.38),'light':(.65,.34,.51),'accent':(1,.29,.18),'dark':(.13,.05,.20),'floor':(.61,.37,.48)},
'rainforest':{'base':(.06,.42,.32),'light':(.40,.73,.20),'accent':(1,.34,.30),'dark':(.035,.20,.20),'floor':(.49,.71,.49)},
'city':{'base':(.08,.46,.56),'light':(.97,.66,.20),'accent':(.91,.29,.23),'dark':(.07,.18,.27),'floor':(.72,.76,.66)},
'hub':{'base':(.12,.35,.43),'light':(.62,.81,.75),'accent':(.88,.34,.24),'dark':(.06,.15,.23),'floor':(.83,.80,.65)}}

def palette(t):
 p={k:material(t+'_'+k,v) for k,v in THEMES[t].items()}
 p.update(ivory=material('Ivory porcelain',(.94,.87,.68)),gold=material('Brushed warm brass',(.83,.53,.15),.55,.27),navy=material('Midnight enamel',(.04,.105,.17)),white=material('Porcelain highlight',(1,.96,.83)),wood=material('Warm carved wood',(.36,.18,.09)),glow=material(t+' luminous',THEMES[t]['light'],.1,.25,1.1),water=material('Glazed turquoise water',(.04,.55,.64),.35,.16))
 return p

def bands(p,z=.5):
 for y in [-.43,.43]:box('Brass crate strap',(0,y,z),(1.08,.085,1.06),p['gold'],.025)
 for x in [-.43,.43]:box('Brass crate strap',(x,0,z),(.085,1.08,1.06),p['gold'],.025)

def roof(p,loc=(0,0,2),width=2.4,depth=1.8,height=.65):
 x,y,z=loc; verts=[]
 # Curved Chinese roof surface: raised ridge and uplifted eaves at corners.
 for j in range(9):
  v=(j/8-.5)*depth
  for i in range(13):
   u=(i/12-.5)*width
   zz=z+height*(1-abs(v/(depth/2)))+.20*(abs(u/(width/2))**4)+.13*(abs(v/(depth/2))**5)
   verts.append((x+u,y+v,zz))
 faces=[(j*13+i,j*13+i+1,(j+1)*13+i+1,(j+1)*13+i) for j in range(8) for i in range(12)]
 o=mesh('Sweeping glazed eaves',verts,faces,p['base']);s=o.modifiers.new('Ceramic roof thickness','SOLIDIFY');s.thickness=.11
 b=o.modifiers.new('Glazed edge','BEVEL');b.width=.035;b.segments=2
 for yy in [-depth/2,depth/2]:curve('Golden lifted eave',[(x-width/2,y+yy,z+.33),(x,y+yy,z+.13),(x+width/2,y+yy,z+.33)],p['gold'],.045)
 for i in range(1,12):
  u=(i/12-.5)*width
  curve('Ceramic seam',[(x+u,y-depth/2,z+.13+.2*(abs(u/(width/2))**4)),(x+u,y,z+height+.2*(abs(u/(width/2))**4)),(x+u,y+depth/2,z+.13+.2*(abs(u/(width/2))**4))],p['light'],.018)
 sphere('Ridge pearl',(x,y,z+height+.1),(.13,.13,.13),p['gold'])

def arch(p,loc=(0,0,0),width=1.6,height=1.6):
 x,y,z=loc
 for xx in [-width/2,width/2]:box('Arch pier',(x+xx,y,z+height*.36),(.35,.50,height*.72),p['base'],.10);box('Pier shoe',(x+xx,y,z+.13),(.5,.62,.25),p['gold'],.06)
 pts=[(x+math.cos(i*math.pi/16)*width/2,y,z+height*.7+math.sin(i*math.pi/16)*height*.4) for i in range(17)]
 curve('Rounded arch crown',pts,p['base'],.20)
 curve('Arch gold inset',[(a,b-.26,c) for a,b,c in pts],p['gold'],.035)

def cloud(p,loc=(0,0,0),s=1):
 for dx,dy,dz,r in [(-.5,0,0,.4),(0,0,.12,.52),(.5,0,0,.35),(.18,.18,-.1,.35)]:sphere('Porcelain cloud',(loc[0]+dx*s,loc[1]+dy*s,loc[2]+dz*s),(r*s,r*s*.60,r*s*.65),p['ivory'])

def palm(p,loc=(0,0,0),s=1):
 x,y,z=loc
 curve('Buttressed tree trunk',[(x,y,z),(x+.1*s,y,z+1.1*s),(x-.10*s,y,z+2.1*s)],p['wood'],.15*s)
 for a in range(6):
  r=a*math.tau/6
  curve('Root buttress',[(x+math.cos(r)*.65*s,y+math.sin(r)*.65*s,z+.04),(x+math.cos(r)*.20*s,y+math.sin(r)*.20*s,z+.35*s),(x,y,z+.7*s)],p['wood'],.085*s)
  leaf('Broad canopy blade',(x-.1*s,y,z+2*s),(x+math.cos(r)*1.3*s,y+math.sin(r)*1.3*s,z+1.85*s),.34*s,p['light'] if a%2 else p['base'])
  curve('Canopy vein',[(x-.1*s,y,z+2*s),(x+math.cos(r)*.7*s,y+math.sin(r)*.7*s,z+2.10*s),(x+math.cos(r)*1.3*s,y+math.sin(r)*1.3*s,z+1.85*s)],p['ivory'],.012*s)

def flower(p,loc,s=.35):
 x,y,z=loc
 for i in range(5):
  a=i*math.tau/5;sphere('Wax flower petal',(x+math.cos(a)*s*.6,y+math.sin(a)*s*.6,z),(.24*s/.35,.14*s/.35,.08*s/.35),p['accent'])
 sphere('Pollen pearl',(x,y,z+.05),(s*.28,s*.28,s*.25),p['gold'])

def tower(p,loc=(0,0,0),w=1.4,d=1.2,h=2.8):
 x,y,z=loc;box('Terraced tower block',(x,y,z+h/2),(w,d,h),p['light'],.08)
 box('Roof cornice',(x,y,z+h+.07),(w+.18,d+.18,.14),p['ivory'],.04)
 for j in range(max(1,int(h/.45))):
  zz=z+.34+j*.43
  for i in [-1,1]:
   box('Window dark frame',(x+i*w*.23,y-d/2-.025,zz),(w*.23,.07,.27),p['navy'],.025)
   box('Window warm pane',(x+i*w*.23,y-d/2-.068,zz),(w*.15,.02,.19),p['glow'],.008)
  if j%2==1:
   box('Projecting balcony',(x,y-d/2-.17,zz-.14),(w+.10,.40,.10),p['base'],.03)
   for xx in [-w*.45,0,w*.45]:box('Balcony railing',(x+xx,y-d/2-.32,zz+.015),(.035,.035,.24),p['gold'],.01)
   box('Balcony top rail',(x,y-d/2-.32,zz+.13),(w,.035,.035),p['gold'],.01)
 box('Vertical facade stripe',(x+w*.47,y-d/2-.05,z+h/2),(.08,.08,h*.95),p['accent'],.02)

def creature(t,p):
 if t=='heaven':
  sphere('Bell crane body',(0,0,.5),(.4,.3,.42),p['ivory']);curve('Crane elegant neck',[(0,-.1,.6),(0,-.25,1.0),(0,-.43,1.12)],p['ivory'],.11)
  sphere('Crane head',(0,-.43,1.12),(.18,.18,.18),p['ivory']);o=cone('Golden beak',(0,-.69,1.09),.10,0,.30,p['gold']);o.rotation_euler[0]=math.pi/2
  for x in [-.12,.12]:sphere('Friendly eye',(x,-.56,1.17),(.035,.035,.045),p['navy'])
  for x in [-.20,.20]:cylinder('Brass leg',(x,0,.16),.035,.3,p['gold']);sphere('Wing',(x*1.7,.05,.58),(.13,.30,.25),p['base'])
 elif t=='inferno':
  sphere('Coal sprite',(0,0,.45),(.48,.4,.43),p['base'])
  for x in [-.30,.30]:curve('Curled ivory horn',[(x,.03,.65),(x*1.45,.04,.99),(x*.7,.02,.96)],p['ivory'],.09)
  for x in [-.16,.16]:sphere('Ember eye',(x,-.365,.52),(.065,.045,.08),p['gold']);sphere('Coal shoe',(x,-.05,.07),(.16,.2,.09),p['navy'])
  curve('Mischievous smile',[(-.1,-.39,.33),(0,-.42,.30),(.1,-.39,.33)],p['accent'],.025)
 elif t=='rainforest':
  sphere('Seed sprite',(0,0,.43),(.38,.32,.4),p['light']);sphere('Seed ivory face',(0,-.27,.48),(.27,.08,.21),p['ivory'])
  for x in [-.10,.1]:sphere('Seed eye',(x,-.35,.50),(.035,.025,.045),p['navy']);sphere('Seed foot',(x*1.5,-.04,.06),(.13,.17,.08),p['base'])
  leaf('Sprouting leaf',(0,0,.77),(.5,0,1.1),.22,p['base']);leaf('Sprouting leaf',(0,0,.77),(-.35,0,1.04),.18,p['light'])
 else:
  box('Cablecar sprite',(0,0,.45),(.7,.52,.60),p['accent'],.16);box('Cablecar face',(0,-.28,.52),(.52,.05,.27),p['ivory'],.07)
  for x in [-.13,.13]:sphere('Cablecar eye',(x,-.32,.53),(.045,.025,.055),p['navy'])
  curve('Cablecar hanger',[(-.22,0,.75),(-.22,0,1.02),(.22,0,1.02),(.22,0,.75)],p['gold'],.04)
  for x in [-.20,.20]:sphere('Cablecar shoe',(x,0,.1),(.12,.18,.11),p['navy'])

def animate_asset(kind, root, objects):
 if kind not in ['creature','portal','gate']:return
 moving=[o for o in objects if o.type in ['MESH','CURVE'] and (kind!='gate' or 'safety bar' in o.name)]
 pivot=bpy.data.objects.new('Moving_'+kind,None);bpy.context.collection.objects.link(pivot);pivot.parent=root
 for o in moving:o.parent=pivot
 pivot.animation_data_create()
 clips=['open','close'] if kind=='gate' else ['idle']
 for clip in clips:
  action=bpy.data.actions.new(clip);pivot.animation_data.action=action
  frames=[(1,0),(24,1)] if kind=='gate' else [(1,0),(25,1),(49,0)]
  for f,v in frames:
   pivot.location=(0,0,((v if clip=='open' else 1-v)*1.25 if kind=='gate' else v*.045))
   pivot.rotation_euler=(0,0,v*.06 if kind=='creature' else (v*math.tau if kind=='portal' else 0))
   pivot.keyframe_insert('location',frame=f);pivot.keyframe_insert('rotation_euler',frame=f)
  action.use_fake_user=True;pivot.animation_data.action=None
  tr=pivot.animation_data.nla_tracks.new();tr.name=clip;st=tr.strips.new(clip,1,action);st.name=clip
 pivot.location=(0,0,0);pivot.rotation_euler=(0,0,0);objects.append(pivot)

ASSETS={}
def make_asset(t,kind,p):
 before=set(bpy.data.objects)
 if kind=='tile':
  box('Thick beveled tile',(0,0,-.17),(1.98,1.98,.34),p['base'],.10)
  box('Glazed tile face',(0,0,-.035),(1.83,1.83,.08),p['floor'],.05)
  for x,y in [(-.76,-.76),(.76,.76)]:box('Corner brass pin',(x,y,.014),(.075,.075,.02),p['gold'],.01)
 elif kind=='edge':
  box('Diorama edge',(0,0,-.35),(1.98,1.98,.70),p['dark'],.12)
  box('Inset edge stripe',(0,-.99,-.25),(1.70,.03,.08),p['gold'],.02)
 elif kind=='wall':
  box('Low ornamental barrier',(0,0,.30),(1.75,1.75,.60),p['base'],.14)
  box('Wall glazed cap',(0,0,.63),(1.82,1.82,.13),p['light'],.07)
  for x in [-.53,.53]:box('Carved facade',(x,-.88,.32),(.18,.06,.26),p['gold'],.04)
 elif kind=='crate':
  box('Crafted puzzle reliquary',(0,0,.56),(1.04,1.04,1.04),p['base'],.14);bands(p,.56)
  for y in [-.535,.535]:
   o=torus('Brass circular seal',(0,y,.57),.21,.045,p['gold'],(math.pi/2,0,0));sphere('Seal porcelain center',(0,y,.57),(.12,.035,.12),p['ivory'])
  box('Crate top crown',(0,0,1.09),(.42,.42,.06),p['light'],.05)
 elif kind=='goal':
  cylinder('Goal inlaid brass',(0,0,.025),.67,.045,p['gold'],48,.015);cylinder('Goal ceramic field',(0,0,.052),.56,.025,p['base'],48,.01)
  torus('Goal luminous ring',(0,0,.08),.43,.035,p['glow'])
  for a in range(4):
   o=box('Goal compass tooth',(math.sin(a*math.pi/2)*.25,math.cos(a*math.pi/2)*.25,.07),(.11,.24,.035),p['ivory'],.02);o.rotation_euler[2]=-a*math.pi/2
 elif kind=='creature':creature(t,p)
 elif kind=='landmark':
  if t=='heaven':
   cylinder('Octagonal palace plinth',(0,0,.18),1.4,.36,p['ivory'],8,.08)
   for x in [-.75,.75]:
    for y in [-.5,.5]:cylinder('Vermilion pillar',(x,y,1.12),.10,1.8,p['accent']);cylinder('Column brass foot',(x,y,.30),.16,.2,p['gold'])
   roof(p,(0,0,1.9),2.7,2.2,.65);box('Upper chamber',(0,0,2.65),(1.0,.8,.7),p['ivory'],.08);roof(p,(0,0,2.96),1.65,1.4,.45)
   for x in [-1.15,1.15]:curve('Bell chain',[(x,-.95,2.13),(x,-.95,1.83)],p['gold'],.02);cone('Hanging bell',(x,-.95,1.72),.12,.08,.19,p['gold'])
   cloud(p,(1.0,.5,.35),.8)
  elif t=='inferno':
   arch(p,(0,0,0),2.0,2.1);sphere('Furnace copper dome',(0,.35,1.1),(.9,.65,1.0),p['light']);box('Furnace mouth',(0,-.36,.70),(.95,.15,.70),p['dark'],.25)
   for x in [-.3,0,.3]:sphere('Glowing ember',(x,-.49,.48),(.16,.10,.13),p['accent'])
   for x in [-.65,.65]:curve('Playful furnace horn',[(x,.2,1.8),(x*1.5,.2,2.4),(x*.8,.2,2.3)],p['gold'],.12)
   cylinder('Furnace chimney',(0,.35,2.1),.28,.7,p['base']);torus('Chimney rim',(0,.35,2.45),.29,.07,p['gold'])
  elif t=='rainforest':
   palm(p,(-.4,.3,0),1.5);palm(p,(.7,.8,0),.95)
   cylinder('Water bowl foot',(0,-.45,.15),.65,.3,p['base']);sphere('Glazed basin',(0,-.45,.35),(.82,.72,.32),p['ivory']);cylinder('Basin water',(0,-.45,.65),.63,.03,p['water']);torus('Glazed basin lip',(0,-.45,.65),.65,.065,p['ivory']);flower(p,(.65,-.2,.6))
  else:
   tower(p,(-.65,.25,.7),1.4,1.4,3.1);tower(p,(.7,.6,1.4),1.2,1.4,3.7)
   box('Mountain terrace',(.2,.4,.3),(3,2.4,.6),p['base'],.15)
   for i in range(7):box('Mountain stair',(-1.35,-.9+i*.22,.1+i*.15),(.65,.24,.20+i*.3),p['ivory'],.035)
   deck=box('Elevated viaduct deck',(0,-.65,2.45),(4.0,.70,.18),p['base'],.06);deck.rotation_euler[1]=-.15
   for yy in [-.88,-.42]:curve('Sloping steel rail',[(-1.9,yy,2.26),(0,yy,2.55),(1.9,yy,2.83)],p['gold'],.035)
   for xx in [-1.6,-1.2,-.8,-.4,0,.4,.8,1.2,1.6]:box('Viaduct sleeper',(xx,-.65,2.57+xx*.15),(.07,.60,.06),p['navy'],.015)
   for x in [-1.3,1.3]:cylinder('Viaduct stilt',(x,-.65,1.0),.1,2,p['gold'])
 elif kind=='decor_a':
  if t=='heaven':
   for x in [-.6,.6]:cylinder('Gate red post',(x,0,.85),.10,1.7,p['accent'])
   roof(p,(0,0,1.65),1.9,1.0,.40);cloud(p,(0,0,.25),.8)
  elif t=='inferno':arch(p,width=1.2,height=1.5);torus('Iron hanging ring',(0,0,1.4),.18,.05,p['gold'],(math.pi/2,0,0))
  elif t=='rainforest':palm(p,s=.9);flower(p,(.4,-.25,.15),.24)
  else:tower(p,w=1.2,d=1.0,h=2.1)
 elif kind=='decor_b':
  if t=='heaven':
   cylinder('Lantern pedestal',(0,0,.2),.34,.4,p['ivory']);cylinder('Lantern stem',(0,0,.85),.07,1.0,p['gold']);sphere('Paper lamp',(0,0,1.35),(.3,.3,.4),p['accent']);torus('Lamp lower brass',(0,0,1.06),.19,.04,p['gold']);cone('Lamp hat',(0,0,1.74),.33,.13,.15,p['base']);cloud(p,(.3,.1,.22),.5)
  elif t=='inferno':
   cylinder('Coal dish',(0,0,.18),.48,.25,p['gold']);
   for a in range(5):sphere('Warm coal',(math.sin(a)*.25,math.cos(a)*.25,.36),(.2,.2,.18),p['accent'])
   for x in [-.42,.42]:curve('Dish curled handle',[(x,0,.23),(x*1.5,0,.45),(x,0,.6)],p['gold'],.05)
  elif t=='rainforest':
   for a in range(7):leaf('Split low frond',(0,0,.05),(math.sin(a)*.8,math.cos(a)*.8,.5+(a%2)*.2),.19,p['light'] if a%2 else p['base'])
   flower(p,(0,-.15,.28))
  else:
   for i in range(6):box('Public terrace stair',(0,i*.20,.1+i*.10),(1.25,.22,.20+i*.20),p['ivory'],.035)
   cylinder('Street lantern stem',(.55,.75,1.4),.045,1.8,p['gold']);sphere('Round street lantern',(.55,.75,2.3),(.18,.18,.20),p['glow'])
 elif kind=='glide':
  box('Wind glaze',(0,0,.025),(1.75,1.75,.055),p['light'],.06)
  for x in [-.45,0,.45]:curve('Inlaid wind trace',[(x,.65,.065),(x-.13,.15,.065),(x,-.65,.065)],p['ivory'],.025)
 elif kind=='portal':
  cylinder('Portal brass rim',(0,0,.07),.72,.14,p['gold']);cylinder('Portal violet glaze',(0,0,.15),.61,.06,p['base']);torus('Portal ember ring',(0,0,.20),.48,.045,p['glow'])
  pts=[(math.cos(i*.23)*(.05+i*.012),math.sin(i*.23)*(.05+i*.012),.19) for i in range(40)];curve('Portal spiral',pts,p['accent'],.025)
 elif kind=='arrow':
  box('Leaf turntable',(0,0,.03),(1.72,1.72,.06),p['base'],.12)
  # Blender -Y = Godot +Z.
  box('Arrow stem',(0,.20,.075),(.15,.75,.04),p['ivory'],.025)
  mesh('Arrow tip',[(-.4,0,.095),(.4,0,.095),(0,-.62,.095)],[(0,1,2)],p['gold'])
 elif kind=='plate':
  box('Pressure plate housing',(0,0,.045),(1.5,1.5,.09),p['navy'],.10);box('Pressure plate',(0,0,.10),(1.22,1.22,.06),p['light'],.08)
  for x in [-.43,.43]:box('Plate indicator',(x,0,.14),(.08,.85,.025),p['gold'],.01)
 elif kind=='gate':
  for x in [-.72,.72]:box('Lift gate post',(x,0,.70),(.22,.38,1.4),p['base'],.07)
  for i in range(4):box('Lift gate safety bar',(0,0,.28+i*.26),(1.3,.16,.12),p['light'] if i%2 else p['accent'],.035)
  box('Lift gate cap',(0,0,1.45),(1.8,.5,.18),p['navy'],.07)
 objs=list(set(bpy.data.objects)-before);root=parent_all(objs,t+'_'+kind);objs.append(root)
 animate_asset(kind,root,objs)
 export_asset(OUT+'/'+t+'_'+kind+'.glb',objs);ASSETS[t+'_'+kind]=objs
 return root

def duplicate_asset(key,loc,scale=1,rot=0):
 orig=ASSETS[key];mapping={}
 for o in orig:
  n=o.copy();n.data=o.data; bpy.context.collection.objects.link(n);mapping[o]=n
 for o,n in mapping.items():
  if o.parent in mapping:n.parent=mapping[o.parent]
 root=mapping[next(o for o in orig if o.parent is None)];root.location=loc;root.scale=(scale,)*3;root.rotation_euler[2]=rot
 return root

def setup_render(t):
 p=palette(t)
 for j in range(5):
  for i in range(5):duplicate_asset(t+'_tile',((i-2)*2,(j-2)*2,0));duplicate_asset(t+'_edge',((i-2)*2,(j-2)*2,-.25))
 for xy in [(-2,-2),(2,0)]:duplicate_asset(t+'_goal',(*xy,0))
 for xy in [(-2,0),(0,2)]:duplicate_asset(t+'_crate',(*xy,0))
 for xy in [(-4,2),(4,-2),(0,4)]:duplicate_asset(t+'_wall',(*xy,0))
 duplicate_asset(t+'_landmark',(1,4.3,0),1.15)
 duplicate_asset(t+'_decor_a',(-4,3,0),1.2);duplicate_asset(t+'_decor_b',(4,2,0),1.2);duplicate_asset(t+'_decor_b',(-4,-3,0),.85)
 duplicate_asset(t+'_creature',(2,-3,0),1.15)
 # Studio ground is Blender-authored preview-only, not external image.
 box('Preview studio floor',(0,0,-1.12),(200,200,.12),material('Studio '+t,tuple(v*.18+.64 for v in THEMES[t]['floor'])),.0)
 bpy.ops.object.light_add(type='AREA',location=(-4,-5,12));bpy.context.object.data.energy=1800;bpy.context.object.data.size=8
 bpy.ops.object.light_add(type='AREA',location=(6,2,8));bpy.context.object.data.energy=1200;bpy.context.object.data.size=7
 bpy.ops.object.camera_add(location=(13,-17,15));c=bpy.context.object;c.rotation_euler=(Vector((0,.5,1.25 if t=='city' else .6))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=18 if t=='city' else 16
 s=bpy.context.scene;s.camera=c;s.render.engine='CYCLES';s.cycles.samples=160;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.025;s.cycles.use_denoising=False;s.render.resolution_x=1200;s.render.resolution_y=900;s.render.resolution_percentage=100;s.world.color=(.35,.35,.35)
 s.view_settings.view_transform='AgX';s.render.filepath=SHOTS+'/blender_'+t+'.png'
 bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/'+t+'_kit.blend');
 if not os.environ.get('FOURFOLD_SKIP_RENDER'):bpy.ops.render.render(write_still=True)

def world(t):
 clear();ASSETS.clear();p=palette(t)
 for idx,k in enumerate(['tile','wall','edge','crate','goal','decor_a','decor_b','creature','landmark']):
  root=make_asset(t,k,p);root.location=(50+idx*4,0,0)
 extras={'heaven':'glide','inferno':'portal','rainforest':'arrow','city':'plate'}
 r=make_asset(t,extras[t],p);r.location=(90,0,0)
 if t=='city':make_asset(t,'gate',p).location=(94,0,0)
 setup_render(t)

if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['heaven','inferno','rainforest','city']
 for t in args:world(t)
