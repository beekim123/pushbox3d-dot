"""V2 Pantao orchard: original branches, blossom clusters, peach fruit and garden terrain.
No palace architecture, textures or external assets. Blender creates/export all meshes.
"""
import bpy,math,os,sys,random
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)));sys.path.insert(0,ROOT+'/blender')
from model_helpers import *
from generate_assets import animate_asset
OUT=ROOT+'/assets/models'; SHOTS=ROOT+'/screenshots';random.seed(592)
P={
'grass':material('Orchard sage grass',(.18,.36,.20),0,.76),'moss':material('Orchard moss tips',(.36,.55,.25),0,.78),
'earth':material('Orchard exposed earth',(.20,.11,.07),0,.86),'rock':material('Garden slate stone',(.29,.35,.34),0,.75),
'stone':material('Worn ivory stepping stone',(.64,.66,.53),0,.66),'stone_light':material('Pale garden limestone',(.76,.77,.62),0,.69),
'bark':material('Gnarled peach bark',(.17,.065,.038),0,.8),'bark_light':material('Bark warm ridges',(.31,.14,.065),0,.82),
'rose':material('Deep rose blossom',(.75,.10,.23),0,.43),'pink':material('Coral blush blossom',(.98,.32,.43),0,.4),
'blush':material('Light blush blossom',(1,.55,.59),0,.45),'petal':material('Ivory petal tips',(1,.77,.69),0,.46),
'leaf':material('Peach leaf celadon',(.16,.43,.27),0,.52),'leaf_light':material('Leaf sunlit side',(.39,.62,.27),0,.52),
'gold':material('Pollen warm gold',(.94,.58,.13),.15,.38),'water':material('Pond celadon reflection',(.055,.39,.43),.22,.18),
'peach':material('Peach warm fruit',(.98,.41,.25),0,.46),'peach_pink':material('Peach blushing cheek',(.89,.20,.28),0,.44),
'wood':material('Peachwood crate',(.42,.21,.10),0,.58),'brass':material('Aged warm brass',(.55,.32,.10),.35,.39),
'cloud':material('Cloud pearl',(.83,.88,.83),0,.7),'navy':material('Courier ink',(.035,.09,.12),0,.42)}
AS={}
_TINY_MESHES={}
def tiny(name,loc,scale,mat):
 key=mat.name
 if key not in _TINY_MESHES:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1)
  o=bpy.context.object;o.name=name;o.data.materials.append(mat)
  for f in o.data.polygons:f.use_smooth=True
  _TINY_MESHES[key]=o.data
 else:
  o=bpy.data.objects.new(name,_TINY_MESHES[key]);bpy.context.collection.objects.link(o)
 o.location=loc;o.scale=scale
 return o

def branch(name,pts,radii,mat):
 o=curve(name,pts,mat,1)
 o.data.resolution_u=8 if max(radii)>.12 else 4
 o.data.bevel_resolution=2 if max(radii)>.12 else 1
 for v,r in zip(o.data.splines[0].bezier_points,radii):v.radius=r
 return o

_FLOWER_MESHES={}
def blossom(loc,s=.16,angle=0,shade=0):
 shade=shade%4
 if shade not in _FLOWER_MESHES:
  verts=[];faces=[]
  for pet in range(5):
   a=pet*math.tau/5;radial=Vector((math.cos(a),math.sin(a),0));tangent=Vector((-math.sin(a),math.cos(a),0));base=len(verts)
   verts.append(tuple(radial*.48+Vector((0,0,.07))))
   verts.append(tuple(radial*.48+Vector((0,0,-.055))))
   for k in range(8):
    b=k*math.tau/8;v=radial*(.48+math.cos(b)*.58)+tangent*(math.sin(b)*.38)+Vector((0,0,.055+.06*math.cos(b)));verts.append(tuple(v))
   for k in range(8):faces.append((base,base+2+k,base+2+(k+1)%8));faces.append((base+1,base+2+(k+1)%8,base+2+k))
  # Eight-face warm pollen center, deliberately low-poly at subpixel detail scale.
  base=len(verts);verts.extend([(0,0,.22),(0,0,.02),(.22,0,.11),(0,.22,.11),(-.22,0,.11),(0,-.22,.11)])
  for k in range(4):faces.extend([(base,base+2+k,base+2+(k+1)%4),(base+1,base+2+(k+1)%4,base+2+k)])
  me=bpy.data.meshes.new('Cached shallow five-petal cup');me.from_pydata(verts,[],faces);me.update();me.materials.append([P['pink'],P['blush'],P['rose'],P['petal']][shade]);me.materials.append(P['gold'])
  for f in me.polygons:f.use_smooth=True;f.material_index=1 if f.index>=80 else 0
  _FLOWER_MESHES[shade]=me
 o=bpy.data.objects.new('Five-petal peach blossom',_FLOWER_MESHES[shade]);bpy.context.collection.objects.link(o);o.location=loc;o.scale=(s,s,s);o.rotation_euler[2]=angle
 return o

def fruit(loc,s=.25):
 x,y,z=loc
 tiny('Split peach left',(x-s*.28,y,z),(s*.75,s*.73,s*.88),P['peach'])
 tiny('Split peach blush',(x+s*.28,y-.02,z+.02),(s*.73,s*.72,s*.86),P['peach_pink'])
 branch('Peach short stem',[(x,y,z+s*.77),(x+.04,y,z+s*1.08)],[.025,.015],P['bark'])
 leaf('Peach pointed leaf',(x,y,z+s*.94),(x+s*1.12,y+.12,z+s*.90),s*.25,P['leaf'])

def rock(loc,s=1,seed=0,mat=None):
 x,y,z=loc;verts=[];faces=[];N=7
 # Deliberate directional strata and angular cut planes, not potato ellipsoids.
 for layer,(h,r) in enumerate([(-.36,.82),(-.06,1.0),(.35,.73)]):
  for i in range(N):
   a=i*math.tau/N+seed*.47;variation=1+.12*math.sin(i*2.3+seed)
   verts.append((x+(math.cos(a)*.72*r*variation+layer*.035)*s,y+math.sin(a)*.57*r*variation*s,z+(h+.065*math.sin(i*1.7+seed))*s))
 faces.append(tuple(range(N-1,-1,-1)))
 for layer in range(2):
  for i in range(N):faces.append((layer*N+i,layer*N+(i+1)%N,(layer+1)*N+(i+1)%N,(layer+1)*N+i))
 faces.append(tuple(range(N*2,N*3)))
 o=mesh('Stratified cut garden stone',verts,faces,mat or P['rock'],.045*s);o.data.materials.append(P['stone']);o.data.materials.append(P['moss'])
 for f in o.data.polygons:
  if f.index==len(faces)-1:f.material_index=2
  elif f.index%4==1:f.material_index=1
 # Two inset seams emphasize geological strata; not random noise.
 for zz in [-.04,.12]:branch('Stone deep stratum',[(x-.49*s,y-.39*s,z+zz*s),(x+.04*s,y-.53*s,z+(zz+.03)*s),(x+.49*s,y-.29*s,z+(zz+.06)*s)],[.018*s,.025*s,.009*s],P['earth'])
 return o

def shrub(loc,s=1,flowers=True):
 x,y,z=loc
 for k in range(5):
  a=k*2.4;r=.22*s*(k%3)
  tiny('Low clipped moss',(x+math.cos(a)*r,y+math.sin(a)*r,z+.16*s),(.36*s,.28*s,.19*s),P['moss'] if k%2 else P['grass'])
  if flowers:blossom((x+math.cos(a)*r,y+math.sin(a)*r,z+.34*s),.095*s,a,k%2)

def peach_tree(loc=(0,0,0),scale=1,variant=0):
 x,y,z=loc
 def tr(co):return (x+co[0]*scale,y+co[1]*scale,z+co[2]*scale)
 # Low serpentine trunk and asymmetrical primary forks keep negative spaces visible.
 trunk=[(0,0,0),(-.26,.04,.65),(-.13,.08,1.35),(.25,.10,2.0),(.13,.15,2.65)]
 
 if variant==1:trunk=[(0,0,0),(.28,-.1,.55),(.65,-.05,1.13),(.60,.10,1.8),(.92,.15,2.30)]
 if variant==2:trunk=[(0,0,0),(-.13,.2,.60),(-.55,.4,1.05),(-.8,.5,1.7),(-.7,.7,2.15)]
 branch('Twisted peach trunk',[tr(v) for v in trunk],[.27*scale,.23*scale,.19*scale,.13*scale,.055*scale],P['bark'])
 for a in [-2.5,-.7,1.1,2.4]:branch('Flared peach root',[tr((math.cos(a)*.72,math.sin(a)*.60,.04)),tr((math.cos(a)*.27,math.sin(a)*.23,.24)),tr((-.20,.02,.66))],[.10*scale,.16*scale,.15*scale],P['bark'])
 forks=[([(-.12,.07,1.15),(-.70,.02,1.80),(-1.35,.14,2.12),(-2.0,.15,2.40)],.15),
 ([(.05,.10,1.65),(.65,-.12,2.0),(1.42,-.17,2.40),(1.95,-.1,2.65)],.14),
 ([(.12,.12,2.05),(-.15,.62,2.70),(-.55,1.0,3.25),(-1.15,1.15,3.45)],.12),
 ([(.08,.1,2.40),(.65,.55,3.03),(1.15,.9,3.35),(1.60,1.05,3.47)],.10),
 ([(-.22,.06,1.45),(-.40,-.65,2.20),(-.8,-1.0,2.65),(-1.25,-1.10,2.8)],.10)]
 for fi,(pts,r) in enumerate(forks):
  if variant==1:
   if fi==2:continue
   pts=[(a*.82+.35+c*.10,b*1.25-.20,c*(.82 if fi%2 else .94)) for a,b,c in pts]
  elif variant==2:
   if fi==3:continue
   pts=[(-a*.88-.30,b*.8+.25,c*(.74 if fi%2 else .86)+.12*math.sin(a)) for a,b,c in pts]
  branch('Tapered orchard fork',[tr(v) for v in pts],[r*scale,r*.78*scale,r*.42*scale,.025*scale],P['bark'])
  # Golden brown bark seam follows inner fork, no procedural texture.
  branch('Subtle bark ridge',[tr((a+.045,b-.025,c)) for a,b,c in pts],[r*.13*scale,r*.1*scale,.012*scale,.003],P['bark_light'])
  for ti in range(2,7):
   q=ti/7;p0=Vector(pts[1]).lerp(Vector(pts[-1]),q);sgn=-1 if ti%2 else 1
   tip=p0+Vector((sgn*.24,.35*sgn,.30+ti*.035));mid=p0.lerp(tip,.55)
   branch('Flower bearing lateral twig',[tr(p0),tr(mid),tr(tip)],[.035*scale,.020*scale,.006],P['bark'])
   # Unequal group sizes, flowers placed along wood rather than sphere crowns.
   for bi in range(6+(ti%3)):
    t=bi/max(1,6+(ti%3)-1);pos=p0.lerp(tip,t)+Vector((math.sin(bi*2.2)*.22,math.cos(bi*1.7)*.20,.065+.06*(bi%2)))
    blossom(tr(pos),(.18+.040*((bi+fi)%3))*scale,fi+bi,(bi+fi+ti)%4)
   if ti%2==0:leaf('Sparse peach lanceolate leaf',tr(mid),tr(mid+Vector((.35,-.15,.04))),.09*scale,P['leaf'])
  fruit(tr(Vector(pts[2])+Vector((.12,-.13,-.20))),.22*scale)
 # Flowers grow along the upper central twig too.
 for k in range(8):blossom(tr((.10+math.sin(k)*.17,.12+math.cos(k)*.14,2.35+k*.095)),.14*scale,k,k%3)
 shrub(tr((-.3,.25,.05)),.65*scale)

def lotus(loc,s=1):
 x,y,z=loc
 cylinder('Broad lotus leaf',(x,y,z),.42*s,.035,P['leaf'],32,.015)
 for k in range(8):
  a=k*math.tau/8
  branch('Lotus vein',[(x,y,z+.02),(x+math.cos(a)*.35*s,y+math.sin(a)*.35*s,z+.02)],[.008,.003],P['leaf_light'])
 for k in range(7):
  a=k*math.tau/7;o=tiny('Lotus ivory rose petal',(x+math.cos(a)*.15*s,y+math.sin(a)*.15*s,z+.16*s),(.20*s,.09*s,.09*s),P['blush'] if k%2 else P['petal']);o.rotation_euler[2]=a;o.rotation_euler[1]=-.25
 tiny('Lotus seed center',(x,y,z+.22*s),(.09*s,.09*s,.07*s),P['gold'])

def terrace(name,outline,z_top,depth,mat):
 n=len(outline);verts=[(x,y,z_top) for x,y in outline]+[(x*.97,y*.97,z_top-depth) for x,y in outline]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 o=mesh(name,verts,faces,mat,.10);return o

def rounded_outline(x,y,r=.8,n=5):
 pts=[]
 for cx,cy,start in [(x-r,y-r,0),(-x+r,y-r,90),(-x+r,-y+r,180),(x-r,-y+r,270)]:
  for j in range(n):
   a=math.radians(start+j*90/(n-1));pts.append((cx+math.cos(a)*r,cy+math.sin(a)*r))
 return pts

def smooth_outline(points,steps=5):
 result=[];n=len(points)
 for i in range(n):
  p0=Vector(points[(i-1)%n]);p1=Vector(points[i]);p2=Vector(points[(i+1)%n]);p3=Vector(points[(i+2)%n])
  for j in range(steps):
   t=j/steps;v=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t);result.append(tuple(v))
 return result

def scholar_rock(loc=(0,0,0),s=1):
 x,y,z=loc;verts=[];faces=[]
 for j in range(24):
  a=j*math.tau/24;center=Vector((x+(math.cos(a)*.47+.12*math.sin(a*2))*s,y+.11*math.sin(a*2)*s,z+(.72+math.sin(a)*.60+.08*math.cos(a*3))*s));side=Vector((math.cos(a),0,math.sin(a)))
  thick=(.17+.12*(.5+.5*math.sin(a))+.045*math.cos(a*4))*s
  for k in range(12):
   b=k*math.tau/12;verts.append(center+side*math.cos(b)*thick+Vector((0,math.sin(b)*thick*.9,0)))
 for j in range(24):
  for k in range(12):faces.append((j*12+k,j*12+(k+1)%12,((j+1)%24)*12+(k+1)%12,((j+1)%24)*12+k))
 ob=mesh('Pierced scholar garden rock',verts,faces,P['stone'],.025*s)
 ob.data.materials.append(P['rock'])
 for f in ob.data.polygons:
  if f.index%7==0:f.material_index=1
 rock((x-.15*s,y,z+.12*s),.66*s,11,P['stone']);shrub((x+.30*s,y-.1,z+.1),.45*s)

def landscape():
 outline=[(-8.6,-6.4),(-10.65,-2),(-10.8,2),(-9.7,5.7),(-7.2,8.2),(-3.4,8.5),(0,8.15),(4.5,8.7),(7.9,7.4),(8.8,3.2),(8.25,-1),(8.75,-5.5),(6.8,-8.3),(2.2,-8.5),(-2,-8.15),(-6.9,-8.2)]
 outline=smooth_outline(outline)
 terrace('Sculpted earth garden',outline,-.11,.95,P['earth']);terrace('Continuous moss garden',[(x*.99,y*.99) for x,y in outline],-.03,.22,P['grass'])
 # Layered exposed garden stone contours around edge, not repeated unit blocks.
 terrace('Lower garden rock shelf',[(x*1.025,y*1.025) for x,y in outline],-.65,.52,P['rock'])
 terrace('Warm exposed upper strata',[(x*1.006,y*1.006) for x,y in outline],-.32,.15,P['stone'])
 terrace('Deep lower slate band',[(x*1.018,y*1.018) for x,y in outline],-.88,.20,P['rock'])
 # Unequal peripheral ground swells leave the playable center flat.
 for x,y,sx,sy,h in [(-7.8,6.6,1.2,1.6,.52),(7.8,6.2,1.15,1.8,.44),(7.9,-4.8,.9,1.7,.33),(-7.8,-5.8,1.1,1.3,.30)]:
  sphere('Soft mossy outer rise',(x,y,-.08),(sx,sy,h),P['grass'])
  rock((x*.99,y*.99,-.42),1.35,int(abs(x*y)))
 # Side pond deliberately outside the nominal14×14 playable center.
 pond=[]
 for i in range(25):
  a=-math.pi/2+i*math.pi/24;pond.append((-7.6-2.65*math.cos(a),1.0+3.65*math.sin(a),.025))
 for i in range(24,-1,-1):
  a=-math.pi/2+i*math.pi/24;pond.append((-7.6-.30*math.cos(a),1.0+3.65*math.sin(a),.025))
 mesh('Crescent celestial pond',pond,[tuple(reversed(range(len(pond))))],P['water'])
 for pts in [pond[:25],pond[25:]]:branch('Curved pale pond lip',[(x,y,z+.015) for x,y,z in pts],[.06]*len(pts),P['stone'])
 for x,y,sc in [(-8.8,-1.0,1.25),(-9.0,1.6,1.18),(-8.65,3.3,.85)]:lotus((x,y,.075),sc)
 for x,y,sc in [(-8.25,-2.7,.65),(-8.5,4.5,.75),(-9.7,.2,.55)]:rock((x,y,.06),sc,int(abs(y*5)))
 for k in range(20):
  a=k*math.tau/20;x=math.cos(a)*8.15;y=math.sin(a)*8.15
  if abs(x)<7.05 and abs(y)<7.05:continue
  shrub((x,y,0),.65+(k%3)*.18,flowers=k%3!=0)
 # Mist banks hug outer base rather than clutter playable cells.
 for x,y in [(-8,-6),(-6,-8),(7,7),(8,-4),(-8,5)]:
  for i in range(3):tiny('Low cloud bank',(x+i*.34,y,-.65+i*.03),(.6,.45,.27),P['cloud'])

def export_merged(path,objects):
 # Keep original editable meshes/curves in .blend, export merged material groups.
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();groups={};temp=[]
 for o in objects:
  if o.type not in ['MESH','CURVE']:continue
  evaluated=o.evaluated_get(deps);me=evaluated.to_mesh() if o.type=='CURVE' or o.modifiers else o.data
  if not me:continue
  for poly in me.polygons:
   mat=me.materials[poly.material_index] if me.materials else P['stone'];key=mat.name
   if key not in groups:groups[key]=[mat,[],[],[]]
  # All generated primitives use one material; append vertex data once per material.
  for matindex in set(f.material_index for f in me.polygons):
   mat=me.materials[matindex] if me.materials else P['stone'];g=groups[mat.name];offset=len(g[1]);g[1].extend([tuple(o.matrix_world@v.co) for v in me.vertices])
   for f in me.polygons:
    if f.material_index==matindex:g[2].append(tuple(offset+i for i in f.vertices));g[3].append(f.use_smooth)
  if o.type=='CURVE' or o.modifiers:evaluated.to_mesh_clear()
 for key,(mat,verts,faces,smooth) in groups.items():
  ob=mesh('Merged '+key,verts,faces,mat)
  for f,sm in zip(ob.data.polygons,smooth):f.use_smooth=sm
  temp.append(ob)
 root=parent_all(temp,'Runtime module');temp.append(root)
 export_asset(path,temp)
 for ob in temp:bpy.data.objects.remove(ob,do_unlink=True)

def create(kind):
 before=set(bpy.data.objects)
 if kind=='landscape':landscape()
 elif kind=='landmark':peach_tree(scale=1.28)
 elif kind=='landmark_b':peach_tree(scale=1.05,variant=1);peach_tree((1.7,1.1,0),.63,2)
 elif kind=='decor_a':peach_tree(scale=.78)
 elif kind=='decor_b':
  scholar_rock((-.20,.16,0),.80);rock((.40,.22,.15),.56,6);shrub((0,-.15,.1),.85)
 elif kind=='decor_c':
  sphere('Pond pebble basin',(0,0,.02),(1.1,.83,.15),P['rock']);sphere('Pond still water',(0,0,.14),(.93,.70,.04),P['water']);lotus((-.2,-.1,.19),1);lotus((.45,.15,.18),.5)
 elif kind=='tile':
  # Four subtly unequal worn slabs, continuous lawn belongs to landscape below.
  for i,(x,y,w,d) in enumerate([(-.47,-.45,.92,.93),(.48,-.44,.93,.94),(-.47,.50,.94,.89),(.49,.50,.91,.88)]):
   o=box('Soft garden paving',(x,y,-.005),(w,d,.07),P['stone'] if i%3 else P['stone_light'],.09);o.rotation_euler[2]=[.012,-.008,-.015,.006][i]
 elif kind=='edge':rock((0,0,-.40),1.6,2)
 elif kind=='wall':
  rock((-.30,.08,.34),.95,4);rock((.40,.20,.23),.68,8);shrub((.15,-.26,.25),.84)
 elif kind=='crate':
  box('Peachwood basket core',(0,0,.52),(1.02,1.02,.95),P['wood'],.10)
  for y in [-.52,.52]:
   for x in [-.36,-.12,.12,.36]:box('Basket vertical wood slat',(x,y,.54),(.20,.045,.88),P['bark_light'],.045)
  for x in [-.53,.53]:
   for y in [-.36,-.12,.12,.36]:box('Basket side slat',(x,y,.54),(.045,.20,.88),P['bark_light'],.035)
  for z in [.19,.84]:
   for y in [-.55,.55]:box('Basket aged brass strap',(0,y,z),(1.12,.035,.08),P['brass'],.015)
   for x in [-.55,.55]:box('Basket aged brass strap',(x,0,z),(.035,1.12,.08),P['brass'],.015)
  box('Basket inset lid',(0,0,1.01),(.88,.88,.07),P['stone'],.10);fruit((0,-.02,1.11),.14)
 elif kind=='goal':
  cylinder('Flower stone socket',(0,0,.025),.63,.07,P['rock'],48,.05);torus('Socket celadon rim',(0,0,.07),.53,.045,P['leaf_light']);blossom((0,0,.08),.45,0,3)
 elif kind=='glide':
  box('Celadon wind water inlay',(0,0,.025),(1.90,1.90,.07),P['water'],.12)
  for x in [-.52,0,.52]:branch('Gentle cloud current',[(x,.75,.075),(x-.18,.15,.075),(x+.10,-.65,.075)],[.02,.025,.012],P['cloud'])
 elif kind=='creature':
  tiny('Peach guardian body',(0,0,.43),(.33,.28,.39),P['peach']);tiny('Peach guardian blush',(0,-.1,.46),(.31,.23,.32),P['peach_pink']);tiny('Guardian ivory face',(0,-.29,.46),(.23,.065,.17),P['petal'])
  for x in [-.08,.08]:tiny('Guardian eye',(x,-.35,.49),(.026,.02,.035),P['navy']);tiny('Guardian foot',(x*1.6,0,.08),(.1,.14,.08),P['leaf'])
  leaf('Guardian leaf crest',(0,0,.75),(.35,0,1.04),.13,P['leaf']);blossom((-.16,0,.80),.13,0,1)
 objs=list(set(bpy.data.objects)-before);root=parent_all(objs,'heaven_'+kind);objs.append(root)
 if kind=='creature':animate_asset('creature',root,objs)
 
 if kind=='creature':export_asset(OUT+'/heaven_'+kind+'.glb',objs)
 else:export_merged(OUT+'/heaven_'+kind+'.glb',objs)
 AS[kind]=objs;return root

def inst(kind,loc,scale=1,rot=0):
 mp={}
 for o in AS[kind]:
  n=o.copy();n.data=o.data;bpy.context.collection.objects.link(n);mp[o]=n
 for o,n in mp.items():
  if o.parent in mp:n.parent=mp[o.parent]
 root=mp[next(o for o in AS[kind] if o.parent is None)];root.location=loc;root.scale=(scale,)*3;root.rotation_euler[2]=rot;return root

def main():
 clear()
 for i,k in enumerate(['landscape','landmark','landmark_b','decor_a','decor_b','decor_c','tile','edge','wall','crate','goal','glide','creature']):create(k).location=(50+i*22,0,0)
 inst('landscape',(0,0,0))
 # A small actual-readable path is embedded in the garden, not a square board tray.
 for y in range(-2,3):
  for x in range(-2,3):
   if (x,y) not in [(-2,-2),(2,2)]:inst('tile',(x*2,y*2,0))
 for loc in [(-4,4),(2,2),(4,-2)]:inst('wall',(*loc,0))
 for loc in [(-2,0),(2,-2)]:inst('crate',(*loc,0))
 for loc in [(0,2),(2,0)]:inst('goal',(*loc,0))
 inst('landmark',(-5.4,5.1,0),1.1,.2);inst('landmark_b',(4.6,5.6,0),1,-.35);inst('decor_a',(-6,-3.4,0),.85,-.2)
 for loc,s in [((5.7,-4.8,0),1.35),((-5.2,-5.2,0),1),((6,1.2,0),1.3)]:inst('decor_b',loc,s)
 inst('decor_c',(-5.8,1.0,0),1.5);inst('creature',(0,-3.4,0),1.2)
 # Import original hero into this Blender composition to judge actual toy scale.
 bpy.ops.import_scene.gltf(filepath=OUT+'/courier.glb')
 for o in bpy.context.selected_objects:
  if o.parent is None:o.location=(0,-1.5,0);o.rotation_euler[2]=-.25
 box('Preview sky studio',(0,0,-1.5),(200,200,.1),material('Orchard pale sky',(.57,.72,.67)),0)
 bpy.ops.object.light_add(type='AREA',location=(-7,-8,13));bpy.context.object.data.energy=3600;bpy.context.object.data.size=7;bpy.context.object.data.color=(1,.87,.73)
 bpy.ops.object.light_add(type='AREA',location=(5,5,10));bpy.context.object.data.energy=2200;bpy.context.object.data.size=9;bpy.context.object.data.color=(.72,.86,1)
 bpy.ops.object.camera_add(location=(16,-22,19));c=bpy.context.object;c.rotation_euler=(Vector((0,0,1.8))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=27
 s=bpy.context.scene;s.camera=c;s.render.engine='CYCLES';s.cycles.samples=96;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.04;s.cycles.use_denoising=False;s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.55,.72,.75,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.65;s.render.resolution_x=1400;s.render.resolution_y=1050;s.render.resolution_percentage=100;s.render.filepath=SHOTS+'/blender_heaven_v2.png'
 bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/heaven_orchard.blend')
 if not os.environ.get('FOURFOLD_SKIP_RENDER'):bpy.ops.render.render(write_still=True)
if __name__=='__main__':main()
