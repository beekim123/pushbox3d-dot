"""Fourfold Atelier V2 — original sculptural environment kits, no image textures.
Blender 4.3: blender -b -t 4 --python blender/rebuild_worlds_v2.py -- inferno rainforest city
Every visible surface is authored as editable Blender geometry and Principled material.
Static GLBs are consolidated by material; source .blend files retain each construction.
Grid pitch 2m, Z up, -Y front. Landscape central 14x14m remains obstacle-free.
"""
import bpy, math, os, sys, random, json
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,ROOT+'/blender')
from model_helpers import *
OUT=ROOT+'/assets/models'; SHOTS=ROOT+'/screenshots'; os.makedirs(OUT,exist_ok=True)
TAU=math.tau
ASSETS={}; STATS={}
# Deliberate game-mesh tessellation: small curves need no film-resolution rings.
_base_curve=curve
def curve(name,points,mat,radius=.05):
    o=_base_curve(name,points,mat,radius);o.data.resolution_u=8;o.data.bevel_resolution=2
    return o

def torus(name,loc,major,minor,mat,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=28,minor_segments=8,location=loc,rotation=rotation)
    return finish(bpy.context.object,name,mat,smooth=True)


def leaf(name,start,end,width,mat):
    """Low-poly thick curved blade with real underside, 11x5 smooth quad lattice."""
    a=Vector(start);b=Vector(end);d=b-a;side=d.cross(Vector((0,0,1))).normalized()
    if side.length<.01:side=Vector((1,0,0))
    verts=[]
    for j in range(11):
      t=j/10;w=width*(math.sin(math.pi*t)**.72)*(.94+.06*math.sin(t*math.pi*3))
      center=a+d*t+Vector((0,0,math.sin(math.pi*t)*width*.55))
      for i in range(5):
        q=(i/4-.5)*2;verts.append(center+side*q*w+Vector((0,0,-q*q*w*.24)))
    faces=[(j*5+i,j*5+i+1,(j+1)*5+i+1,(j+1)*5+i) for j in range(10) for i in range(4)]
    o=mesh(name,verts,faces,mat)
    for f in o.data.polygons:f.use_smooth=True
    mod=o.modifiers.new('Thick supple leaf','SOLIDIFY');mod.thickness=.032
    return o


def pal(t):
    colors={
      'inferno': dict(stone=(.24,.19,.32), stone_light=(.40,.32,.45), ground=(.53,.45,.55), dark=(.065,.075,.13), teal=(.20,.40,.43), warm=(.85,.30,.16), ivory=(.91,.78,.59), copper=(.48,.25,.14), glow=(1,.43,.10), wood=(.29,.13,.10),leaf=(.31,.35,.38),leaf_light=(.60,.52,.43),water=(.64,.16,.065)),
      'rainforest':dict(stone=(.23,.31,.22),stone_light=(.36,.45,.25),ground=(.32,.43,.19),dark=(.055,.17,.16),teal=(.08,.42,.33),warm=(.95,.37,.28),ivory=(.91,.86,.64),copper=(.40,.26,.15),glow=(.88,.78,.32),wood=(.29,.17,.09),leaf=(.055,.32,.20),leaf_light=(.26,.55,.22),water=(.065,.52,.53)),
      'city':dict(stone=(.32,.42,.42),stone_light=(.64,.66,.55),ground=(.71,.69,.58),dark=(.055,.14,.20),teal=(.12,.40,.44),warm=(.69,.28,.18),ivory=(.87,.80,.64),copper=(.46,.28,.16),glow=(.99,.69,.30),wood=(.32,.20,.13),leaf=(.13,.35,.25),leaf_light=(.38,.52,.28),water=(.10,.35,.46))}
    p={k:material('V2 '+t+' '+k,v, metallic=.42 if k=='copper' else (.18 if k=='water' else 0), roughness=.24 if k=='water' else (.32 if k=='copper' else .68),emission=.6 if k=='glow' else 0) for k,v in colors[t].items()}
    p['leaf_mid']=material('V2 '+t+' middle foliage',(.11,.43,.24),roughness=.48)
    p['bark_light']=material('V2 '+t+' pale bark',(.43,.28,.14),roughness=.85)
    p['flower_pale']=material('V2 '+t+' pale petal',(.99,.62,.47),roughness=.48)
    p['foam']=material('V2 '+t+' water glint',(.57,.82,.72),roughness=.28)
    p['soil']=material('V2 '+t+' warm ochre soil',(.32,.23,.12),roughness=.92)
    if t=='rainforest':
      p['path_paving']=material('V2 rainforest warm worn path',(.58,.50,.32),roughness=.86)
      p['path_stone']=material('V2 rainforest pale old path stone',(.72,.66,.46),roughness=.82)
      p['path_seam']=material('V2 rainforest deep earth joint',(.17,.16,.095),roughness=.95)
    return p


def ellipsoid(name,loc,scale,mat,segments=16,rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,smooth=True)


def tube(name,points,radii,mat,sides=10):
    # Parallel-to-horizontal rings follow organic branching silhouettes, no image displacement.
    verts=[]
    for i,(co,r) in enumerate(zip(points,radii)):
      tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
      tangent.normalize();axis=tangent.cross(Vector((0,1,0))).normalized()
      if axis.length<.01:axis=Vector((1,0,0))
      cross=tangent.cross(axis).normalized()
      for k in range(sides):
        a=k*TAU/sides;verts.append(Vector(co)+(axis*math.cos(a)+cross*math.sin(a))*r)
    faces=[]
    for j in range(len(points)-1):
      for k in range(sides):faces.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
    faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+k for k in range(sides))])
    o=mesh(name,verts,faces,mat)
    for f in o.data.polygons:f.use_smooth=True
    return o


def rock(name,loc,scale,mat,seed=0):
    rng=random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object
    for v in o.data.vertices:v.co*=rng.uniform(.94,1.06)
    o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(o,name,mat,.045,True);return o


def polygon_slab(name,outline,z,thick,mat,bevel=.08):
    n=len(outline);v=[(x,y,z-thick) for x,y in outline]+[(x,y,z) for x,y in outline]
    f=[tuple(reversed(range(n))),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,v,f,mat,bevel)


def island(p,t):
    # Uneven rounded shoreline; flat central top stays under the playable cells.
    n=56;verts=[]
    for ring,z in [(1,-1.3),(1.025,-.65),(1,-.08)]:
      for i in range(n):
        a=i*TAU/n
        # superellipse gives a broad usable center and organic rounded corners.
        x=math.copysign(abs(math.cos(a))**.64,math.cos(a))*9.45
        y=math.copysign(abs(math.sin(a))**.64,math.sin(a))*9.0
        r=ring*(1+.017*math.sin(a*7)+.012*math.cos(a*11))
        verts.append((x*r,y*r,z+.04*math.sin(a*5) if z<-.1 else -.055))
    f=[]
    for j in range(2):
      for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    f.extend([tuple(reversed(range(n))),tuple(2*n+i for i in range(n))])
    mesh('Hand-shaped continuous terrain',verts,f,p['stone'] if t=='inferno' else p['ground'],.08)
    # strata reveal natural thickness, not a stack of gold-framed board tiles.
    for side in [-1,1]:
      for j in range(9):
        x=side*(8.9+.16*math.sin(j));y=-7.8+j*1.8
        rock('Earth escarpment strata',(x,y,-.82),(1,.94,.62),p['dark'] if t=='inferno' else p['stone'],j+20)


def ribbon(name,points,widths,mat,zoffset=0,thickness=.08):
    # Catmull-Rom bank centerline removes rigid octagonal corners from streams.
    original=[Vector(v) for v in points];ww=list(widths);points=[];widths=[]
    for i in range(len(original)-1):
      a=original[max(0,i-1)];b=original[i];c=original[i+1];d=original[min(len(original)-1,i+2)]
      for k in range(5):
        t=k/5;t2=t*t;t3=t2*t
        points.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t2+(-a+3*b-3*c+d)*t3));widths.append(ww[i]*(1-t)+ww[i+1]*t)
    points.append(original[-1]);widths.append(ww[-1])
    verts=[]
    for i,(p,w) in enumerate(zip(points,widths)):
      d=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
      side=Vector((-d.y,d.x,0)).normalized()*w
      for s in [-1,1]:verts.append(Vector(p)+side*s+Vector((0,0,zoffset)))
    faces=[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(points)-1)]
    o=mesh(name,verts,faces,mat);s=o.modifiers.new('Water body thickness','SOLIDIFY');s.thickness=thickness
    for f in o.data.polygons:f.use_smooth=True
    return o


def round_arch(p,loc=(0,0,0),width=2.2,height=2.1,depth=.75,stone=None):
    x,y,z=loc;mat=stone or p['stone'];r=width/2;th=.36;spring=height-r
    for side in [-1,1]:
      for j in range(3):
        box('Load-bearing rounded ashlar',(x+side*(r+th/2),y,z+(j+.5)*spring/3),(th+.12,depth,spring/3-.035),p['stone_light'] if j%2 else mat,.065)
      box('Broad pier foot',(x+side*(r+th/2),y,z+.10),(th+.32,depth+.18,.22),mat,.07)
    for k in range(11):
      a0=k*math.pi/11+.015;a1=(k+1)*math.pi/11-.015
      v=[]
      for yy in [-depth/2,depth/2]:
        for rr,aa in [(r,a0),(r+th,a0),(r+th,a1),(r,a1)]:v.append((x+rr*math.cos(aa),y+yy,z+spring+rr*math.sin(aa)))
      mesh('Separate radial voussoir',v,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],p['stone_light'] if k%3==1 else mat,.035)


def pipe(p,points,r=.15):
    curve('Bent burnished copper pipe',points,p['copper'],r)
    for i in [0,len(points)-1]:
      a=Vector(points[i]);b=Vector(points[1 if i==0 else -2]);d=(a-b).normalized()
      o=torus('Pipe flange',a,r*1.15,.045,p['dark']);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
      for j in [-1,1]:
        o=torus('Copper rolled seam',a+d*.09*j,r,.018,p['copper']);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()


def fire(p,loc,s=1):
    x,y,z=loc
    for i in range(5):
      a=i*TAU/5
      rock('Glowing furnace coal',(x+math.cos(a)*s*.33,y+math.sin(a)*s*.22,z+.1*s),(.22*s,.17*s,.16*s),p['dark'],i)
      tube('Honey flame tongue',[(x+(i-2)*.14*s,y,z+.10*s),(x+(i-2)*.16*s,y,z+.30*s),(x+(i-2)*.10*s+.06*s,y+.03*s,z+(.56+.14*(i%2))*s)],[.13*s,.10*s,.005],p['glow'],8)


def coal(p,loc=(0,0,0),s=1):
    x,y,z=loc
    ellipsoid('Velvety coal imp',(x,y,z+.46*s),(.45*s,.36*s,.44*s),p['dark'])
    for side in [-1,1]:
      tube('Chubby coal horn',[(x+side*.25*s,y,z+.75*s),(x+side*.4*s,y,z+.99*s),(x+side*.30*s,y-.02*s,z+1.05*s)],[.12*s,.09*s,.02*s],p['copper'])
      ellipsoid('Coal padded foot',(x+side*.22*s,y-.09*s,z+.08*s),(.17*s,.23*s,.10*s),p['stone'])
      ellipsoid('Large cream eye',(x+side*.145*s,y-.335*s,z+.52*s),(.095*s,.025*s,.12*s),p['ivory'])
      ellipsoid('Tiny coal pupil',(x+side*.14*s,y-.36*s,z+.51*s),(.035*s,.015*s,.065*s),p['dark'])
      ellipsoid('Ember cheek',(x+side*.29*s,y-.285*s,z+.37*s),(.07*s,.03*s,.035*s),p['warm'])
    curve('Cheeky imp grin',[(x-.09*s,y-.36*s,z+.32*s),(x,y-.385*s,z+.28*s),(x+.1*s,y-.35*s,z+.34*s)],p['warm'],.018*s)
    # Tiny stoker cap and a visible copper seam distinguish it from generic spheres.
    ellipsoid('Stoker cap',(x-.07*s,y,z+.86*s),(.30*s,.25*s,.10*s),p['stone'])
    box('Stoker cap brim',(x-.07*s,y-.22*s,z+.84*s),(.51*s,.20*s,.045*s),p['stone'],.025)


def inferno_build(kind,p):
    if kind=='tile':
      polygon_slab('Warm stone floor bed',[(-.99,-.97),(-.37,-.99),(.99,-.96),(.98,.98),(-.98,.99)],-.04,.31,p['stone'],.055)
      # Quiet, irregular small paving joints replace the large identical colored tiles.
      for j,(x,y,w,d) in enumerate([(-.46,-.48,.96,.94),(.50,-.49,.93,.93),(-.69,.48,.50,.93),(.28,.49,1.39,.94)]):
        box('Rounded dungeon paving',(x,y,-.012),(w-.025,d-.025,.065),p['ground'] if j%3 else p['stone_light'],.045)
    elif kind in ['wall','wall_b']:
      for row in range(2):
        for i in range(2 if row==0 else 3):
          width=.84 if row==0 else .55;x=(i-(.5 if row==0 else 1))*(width+.035)
          box('Low stacked dungeon boulder',(x,0,.18+row*.28),(width,1.52,.34),p['stone_light'] if (i+row)%3 else p['stone'],.12)
      if kind=='wall_b':pipe(p,[(-.7,-.70,.4),(0,-.79,.48),(.65,-.70,.4)],.055)
    elif kind=='edge':
      for i in range(3):rock('Rounded exposed deep foundation',((i-1)*.65,0,-.48),(.48,.93,.49),p['dark'] if i%2 else p['stone'],i)
    elif kind=='crate':
      box('Kiln-fired push block',(0,0,.55),(1.08,1.08,1.08),p['warm'],.13)
      for y in [-.55,.55]:
        box('Iron crate end',(0,y,.54),(.83,.045,.82),p['dark'],.065)
        for x in [-.23,0,.23]:box('Furnace vent slot',(x,y*1.045,.53),(.075,.035,.47),p['glow'],.025)
      for x in [-.44,.44]:box('Iron box binding',(x,0,.55),(.12,1.10,1.10),p['copper'],.035)
      box('Box lid',(0,0,1.10),(1.04,1.04,.11),p['stone'],.06)
      torus('Kiln handle',(0,0,1.2),.16,.045,p['copper'],(math.pi/2,0,0))
    elif kind=='goal':
      cylinder('Recessed ember socket',(0,0,.025),.64,.045,p['dark'],40,.02)
      torus('Warm goal ring',(0,0,.065),.48,.055,p['glow'])
      for i in range(4):
        a=i*math.pi/2;o=box('Goal locator tooth',(math.cos(a)*.64,math.sin(a)*.64,.065),(.17,.12,.07),p['ivory'],.02);o.rotation_euler[2]=a
    elif kind=='portal':
      cylinder('Portal stone well',(0,0,.05),.75,.10,p['stone'],40,.03)
      torus('Portal copper coil',(0,0,.13),.60,.07,p['copper'])
      cylinder('Portal dark pool',(0,0,.10),.57,.045,p['dark'],40,.015)
      points=[(math.cos(i*.25)*(.05+i*.011),math.sin(i*.25)*(.05+i*.011),.155) for i in range(43)]
      curve('Amber portal spiral',points,p['glow'],.035)
    elif kind=='creature':coal(p)
    elif kind=='landmark':
      # Boiler chamber is a curved mass held by a true masonry arch, not an arch decal.
      polygon_slab('Furnace raised slate apron',[(-2.0,-1.5),(1.65,-1.4),(2.1,.4),(1.4,1.65),(-1.8,1.5)],.12,.30,p['stone'],.1)
      ellipsoid('Riveted copper boiler shell',(-.3,.45,1.55),(1.15,.82,1.45),p['copper'],24,16)
      for z in [.72,1.45,2.10]:
        o=torus('Boiler rolled horizontal seam',(-.3,.45,z),1,.055,p['dark']);o.scale=(1.10,.78,1)
      round_arch(p,(-.3,-.45,.10),2.0,2.35,.75)
      box('Recessed oven shadow',(-.3,-.69,.83),(1.50,.13,1.35),p['dark'],.43)
      fire(p,(-.3,-.82,.25),1.3)
      for x in [-.92,-.51,-.10,.31]:box('Iron oven grate',(x,-.92,.60),(.045,.07,.55),p['dark'],.02)
      tube('Stone flue',[(-.3,.55,2.4),(-.3,.55,3.2),(-.55,.55,3.55)],[.34,.29,.29],p['stone'],12)
      cylinder('Chimney lip',(-.55,.55,3.55),.37,.15,p['stone_light'],16,.04)
      pipe(p,[(.7,.55,.65),(1.5,.55,.75),(1.6,.55,2.0),(.82,.55,2.2)],.17)
      pipe(p,[(-1.30,.65,.40),(-1.85,.65,.8),(-1.80,.65,2.65),(-.85,.65,2.8)],.12)
      o=torus('Boiler pressure gauge',(.74,-.38,2.30),.23,.05,p['copper'],(math.pi/2,0,0))
      ellipsoid('Gauge cream face',(.74,-.39,2.30),(.19,.035,.19),p['ivory'])
      curve('Gauge needle',[(.74,-.44,2.3),(.66,-.44,2.41)],p['dark'],.015)
      coal(p,(1.35,-.8,.13),.7)
    elif kind in ['decor_a','landmark_b']:
      round_arch(p,(-.35,.25,0),1.7,2.25,.78)
      for side in [-1,1]:
        for j in range(3):box('Side cellar masonry',(-.35+side*1.25,.25,.35+j*.62),(.35,1.2,.58),p['stone'],.09)
      pipe(p,[(-1.6,.75,.3),(-1.6,.75,2.7),(.0,.75,3.0),(.8,.75,2.4)],.12)
      torus('Hanging forged ring',(-.35,.0,1.8),.22,.05,p['copper'],(math.pi/2,0,0))
      for x in [-.9,.2]:box('Threshold worn slate',(x,-.2,.08),(.7,.9,.16),p['ground'],.05)
    elif kind in ['decor_b','decor_c']:
      if kind=='decor_b':
        cylinder('Low coal brazier',(0,0,.25),.58,.43,p['copper'],16,.06)
        torus('Brazier rolled lip',(0,0,.46),.57,.06,p['dark']);fire(p,(0,0,.47),.8)
        for a in range(3):
          x=math.cos(a*TAU/3)*.4;y=math.sin(a*TAU/3)*.4;box('Brazier foot',(x,y,.09),(.14,.14,.25),p['dark'],.04)
      else:
        rock('Coal supply boulder',(-.25,0,.20),(.65,.5,.35),p['stone'],5)
        pipe(p,[(-.65,.3,.22),(-.4,.3,1.05),(.25,.3,1.10),(.58,.3,.65)],.1)
        coal(p,(.25,-.25,.0),.58)
    elif kind=='landscape':
      island(p,'inferno')
      # Continuous curved heated channel surrounds the playable stone courtyard.
      points=[(-9,-7.8,-.02),(-8.2,-8.2,-.02),(-5.4,-8.15,-.02),(-2.1,-8.52,-.02),(1.2,-8.05,-.02),(4.8,-8.40,-.02),(7.9,-7.8,-.02),(8.5,-4.8,-.02),(8.15,-1.9,-.02),(8.6,1.1,-.02),(8.3,4.0,-.02),(7.7,7.6,-.02),(3,8.1,-.02)]
      ribbon('Curving dark furnace channel',points,[.48,.60,.68,.55,.70,.47,.55,.58,.40,.56,.65,.50,.38],p['dark'],.025)
      ribbon('Warm molten glaze in channel',points,[.30,.44,.50,.36,.53,.30,.38,.42,.25,.40,.47,.32,.22],p['water'],.045)
      for j,(x,y) in enumerate([(-7.1,-8.1),(-3.6,-8.65),(.3,-7.75),(3.8,-8.8),(6.7,-7.55),(8.75,-3.7),(7.85,.1)]):
        rock('Broken natural hot-channel bank',(x,y,.05),(.48,.36,.22),p['stone_light'] if j%2 else p['dark'],j+41)
      ellipsoid('Wide ember spring',(8.45,4.0,.03),(.68,1.0,.08),p['water'])
      for j in range(3):rock('Ember spring stepping basalt',(8.30+j*.18,3.4+j*.45,.11),(.27,.21,.15),p['dark'],j+65)
      for j in range(11):
        x=-8+j*1.6
        rock('Back cavern ledge',(x,8.15,.35),(.96,.62,.48),p['stone'],j+31)
      # Only two asymmetrical arches, integrated into terrain rather than fence of identical tokens.
      round_arch(p,(-4.5,8.25,.15),2.8,3.0,.95)
      round_arch(p,(1.3,8.4,.05),2.0,2.25,.85)
      pipe(p,[(-7.7,8.5,.4),(-7.7,8.6,1.8),(-4.8,8.65,2.0),(-1.4,8.65,1.5),(4.7,8.45,1.7),(6.4,8.25,.8)],.18)
      for x,y in [(-8.5,3),(-8.6,-3.5),(8.55,5.7)]:
        rock('Basalt embankment',(x,y,.1),(.65,1.0,.5),p['stone_light'],int(x*y))
      for i in range(6):
        x=-6.5+i*2.3
        ellipsoid('Hot river eddy',(x,-8.22,.08),(.40,.05,.018),p['glow'])


def buttress(p,x,y,z,angle,s):
    d=Vector((math.cos(angle),math.sin(angle),0));q=Vector((-d.y,d.x,0));base=Vector((x,y,z))
    v=[base+q*.12*s,base-q*.12*s,base+d*.98*s+q*.09*s,base+d*.98*s-q*.09*s,base+Vector((0,0,1.0*s)),base+d*.58*s+Vector((0,0,.15*s))]
    mesh('Sculpted plank buttress root',v,[(0,2,5,4),(1,4,5,3),(0,4,1),(2,3,5),(0,1,3,2)],p['wood'],.06*s)


def foliage_cluster(p,center,s,seed,angle=0):
    rng=random.Random(seed);x,y,z=center
    for i in range(9):
      a=angle+i*2.399+rng.uniform(-.15,.15);length=s*rng.uniform(1.05,1.55)
      start=(x+math.cos(a)*s*.05,y+math.sin(a)*s*.05,z+rng.uniform(-.08,.08)*s)
      end=(x+math.cos(a)*length,y+math.sin(a)*length,z+rng.uniform(-.38,.45)*s)
      mat=[p['leaf'],p['leaf_mid'],p['leaf_light']][(i+seed)%3]
      leaf('Curved thick canopy leaf',start,end,s*.39,mat)
      # Restrained veins follow the leaf midrib and establish scale without gold piping.
      mid=Vector(start).lerp(Vector(end),.5)+Vector((0,0,s*.17))
      curve('Soft central leaf rib',[start,mid,end],p['leaf_light'],.009*s)


def broad_tree(p,loc=(0,0,0),s=1,seed=10):
    x,y,z=loc
    tube('Twisting broadleaf trunk',[(x,y,z),(x-.10*s,y+.05*s,z+.85*s),(x-.28*s,y+.10*s,z+1.8*s),(x-.46*s,y+.15*s,z+2.9*s),(x-.8*s,y+.22*s,z+3.55*s)],[.36*s,.29*s,.22*s,.16*s,.07*s],p['wood'],12)
    for i in range(7):buttress(p,x,y,z,i*TAU/7+.2,s)
    branch_specs=[((-.23,.10,1.8),(-1.1,.2,2.65),(-1.50,.20,3.15),1.0),((-.40,.15,2.65),(.20,.48,3.4),(.64,.64,3.72),.95),((-.45,.15,2.95),(-.65,-.45,3.65),(-.7,-.65,4.0),1.0),((-.20,.1,1.7),(.45,-.25,2.35),(.83,-.31,2.65),.76)]
    for j,(a,b,c,sz) in enumerate(branch_specs):
      points=[(x+u*s,y+v*s,z+w*s) for u,v,w in [a,b,c]]
      tube('Tapered canopy branch',points,[.16*s,.10*s,.025*s],p['wood'],9)
      foliage_cluster(p,points[-1],s*sz,seed+j)
    foliage_cluster(p,(x-.8*s,y+.22*s,z+3.55*s),s*.75,seed+9)
    # Hanging vines establish vertical continuity from canopy into understory.
    for dx,dy,zz in [(-1.15,.1,3.1),(.52,.63,3.6)]:
      curve('Hanging rainforest liana',[(x+dx*s,y+dy*s,z+zz*s),(x+(dx+.13)*s,y+dy*s,z+(zz-.8)*s),(x+(dx-.1)*s,y+dy*s,z+(zz-1.3)*s)],p['leaf'],.026*s)
    for a in [0.7,2.0,3.8]:
      curve('Raised bark seam',[(x+math.cos(a)*.30*s,y+math.sin(a)*.30*s,z+.2*s),(x-.1*s+math.cos(a)*.25*s,y+math.sin(a)*.25*s,z+1.05*s),(x-.3*s+math.cos(a)*.17*s,y+.1*s+math.sin(a)*.17*s,z+2*s)],p['bark_light'],.024*s)


def flower_cluster(p,loc,s=.5,seed=1):
    x,y,z=loc
    for j in range(3):
      a=j*TAU/3;cx=x+math.cos(a)*s*.35;cy=y+math.sin(a)*s*.35;cz=z+s*(.14+j*.10)
      curve('Flower green stem',[(cx,cy,z),(cx-.08*s,cy,cz)],p['leaf'],.02*s)
      for i in range(5):
        a=i*TAU/5;o=ellipsoid('Thick coral flower petal',(cx+math.cos(a)*s*.23,cy+math.sin(a)*s*.23,cz),(.24*s,.12*s,.065*s),p['warm'] if j%2 else p['flower_pale'],12,8);o.rotation_euler[2]=a
      ellipsoid('Pollen center',(cx,cy,cz+.05*s),(.09*s,.09*s,.06*s),p['glow'],12,8)


def understory(p,loc,s=1,seed=1):
    x,y,z=loc
    for i in range(6):
      a=i*2.399;end=(x+math.cos(a)*s*.8,y+math.sin(a)*s*.8,z+s*(.35+.14*(i%3)))
      leaf('Understory broad curved leaf',(x,y,z),end,s*.25,p['leaf_mid'] if i%2 else p['leaf_light'])
    flower_cluster(p,(x-.18*s,y-.18*s,z+.05*s),s*.45,seed)


def seed_sprite(p):
    ellipsoid('Round chestnut seed body',(0,0,.43),(.34,.29,.42),p['wood'])
    ellipsoid('Cream seed face',(0,-.26,.46),(.24,.075,.23),p['ivory'])
    for x in [-.09,.09]:
      ellipsoid('Seed bright eye',(x,-.33,.49),(.035,.018,.05),p['dark'])
      ellipsoid('Root slippers',(x*1.8,-.03,.06),(.13,.18,.07),p['leaf'])
    for side in [-1,1]:leaf('Seed sprout crown',(0,0,.77),(side*.45,0,1.08),.20,p['leaf_light'] if side==1 else p['leaf_mid'])
    curve('Seed smile',[(-.06,-.34,.38),(0,-.35,.36),(.07,-.34,.39)],p['wood'],.014)


def rainforest_build(kind,p):
    if kind=='tile':
      polygon_slab('Warm earthen clearing tile',[(-.98,-.97),(.10,-.99),(.99,-.94),(.97,.97),(-.96,.99)],-.03,.30,p['path_seam'],.06)
      polygon_slab('Warm worn clearing path',[(x*.96,y*.96) for x,y in [(-.96,-.94),(.89,-.96),(.97,.61),(.83,.95),(-.92,.96)]],.005,.06,p['path_paving'],.055)
      # Warm worn path contrasts with outer moss soil; a thin earth joint keeps legal cells clear.
      for pts in [[(-.74,-.70),(-.10,-.79),(.20,-.42),(.08,.08),(-.63,.16),(-.83,-.25)],[(.28,.24),(.80,.14),(.88,.60),(.55,.84),(.17,.68)]]:
        polygon_slab('Old path stone swallowed by moss',pts,.023,.045,p['path_stone'],.07)
      for a in range(3):
        angle=a*2.0;leaf('Tiny clearing grass blade',(-.80,.72,.03),(-.80+math.cos(angle)*.17,.72+math.sin(angle)*.17,.16),.035,p['leaf_light'])
    elif kind in ['wall','wall_b']:
      rock('Root-barrier mossy earth',(-.10,.10,.10),(.76,.67,.20),p['ground'],16)
      if kind=='wall':
        tube('Broken ancient forest stump',[(-.18,.13,.08),(-.24,.10,.36),(-.19,.10,.66)],[.39,.32,.28],p['wood'],12)
        cylinder('Warm exposed stump cut',(-.19,.10,.67),.275,.025,p['bark_light'],20,.015)
        for r in [.095,.19]:torus('Stump tree growth ring',(-.19,.10,.687),r,.009,p['wood'])
        for j,a in enumerate([.25,1.8,3.3,4.7,5.7]):
          tube('Spreading tapered obstacle root',[(-.20,.10,.42),(math.cos(a)*.40,math.sin(a)*.40,.24),(math.cos(a)*.82,math.sin(a)*.72,.06)],[.16,.13,.025],p['wood'],8)
        leaf('New sprout on old root',(-.15,.14,.68),(.25,.17,.86),.14,p['leaf_mid'])
      else:
        a=Vector((-.66,-.28,.28));b=Vector((.62,.27,.40));d=(b-a).normalized()
        tube('Naturally bent fallen trunk',[a,(-.10,.03,.43),b],[.28,.30,.23],p['wood'],12)
        for center,rad in [(a,.255),(b,.215)]:
          o=cylinder('Visible pale cut wood',center,rad,.03,p['bark_light'],20,.01);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
          for rr in [.45,.78]:
            o=torus('Fallen tree growth ring',center+d*.02,rad*rr,.011,p['wood']);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
        tube('Broken branch on deadfall',[(-.10,.02,.44),(-.15,.35,.62),(-.32,.42,.75)],[.11,.08,.035],p['wood'],8)
        leaf('Fern beside deadfall',(.35,-.2,.10),(.75,-.48,.47),.18,p['leaf_light'])
    elif kind=='edge':
      rock('Dark soil bank',(-.4,0,-.45),(.70,.96,.53),p['wood'],3)
      rock('Weathered shore stone',(.45,0,-.43),(.68,.9,.48),p['stone'],6)
      tube('Exposed tapered bank root',[(-.7,-.8,-.1),(-.25,-.94,-.35),(.38,-.9,-.65)],[.08,.06,.02],p['bark_light'])
    elif kind=='crate':
      box('Carved seed transport crate',(0,0,.53),(1.04,1.04,1.06),p['wood'],.14)
      for x in [-.35,0,.35]:box('Visible carved crate plank',(x,-.535,.53),(.31,.06,.82),p['bark_light'],.045)
      for z in [.18,.88]:
        for y in [-.56,.56]:box('Living vine crate binding',(0,y,z),(1.08,.07,.09),p['leaf'],.035)
      for x in [-.54,.54]:box('Living side vine',(x,0,.53),(.07,1.06,.09),p['leaf'],.03)
      box('Seed box lid',(0,0,1.07),(1.03,1.03,.1),p['stone_light'],.05)
      leaf('Lid carved leaf',(0,.3,1.135),(0,-.35,1.135),.18,p['leaf_mid'])
      ellipsoid('Seed seal',(0,-.59,.53),(.18,.04,.24),p['ivory']);curve('Seal groove',[(0,-.64,.34),(.04,-.64,.53),(0,-.64,.73)],p['wood'],.015)
    elif kind=='goal':
      cylinder('Goal stone shallow recess',(0,0,.022),.66,.04,p['stone'],40,.015)
      torus('Porcelain clear goal ring',(0,0,.07),.46,.055,p['ivory'])
      for a in range(4):
        angle=a*math.pi/2;ellipsoid('Goal coral petal',(math.cos(angle)*.61,math.sin(angle)*.61,.07),(.1,.1,.045),p['warm'])
    elif kind=='arrow':
      box('Root direction tablet',(0,0,.025),(1.70,1.70,.05),p['leaf'],.10)
      box('Clear ivory arrow stem',(0,.17,.07),(.18,.75,.035),p['ivory'],.025)
      mesh('Clear ivory arrow head',[(-.40,.02,.09),(.40,.02,.09),(0,-.62,.09)],[(0,1,2)],p['ivory'])
      for x in [-.68,.68]:curve('Tablet curved root edge',[(x,-.65,.08),(x*.92,0,.08),(x,.65,.08)],p['wood'],.055)
    elif kind=='creature':seed_sprite(p)
    elif kind=='landmark':
      rock('Tree root island',(-.4,.4,.03),(1.90,1.50,.20),p['stone'],12)
      broad_tree(p,(-.35,.45,.08),1.08,21)
      # A clear curving stream and a flower cascade run around the buttressed base.
      pts=[(-1.5,-.60,.05),(-.9,-.85,.05),(-.1,-.95,.05),(.7,-.65,.05),(1.1,-.10,.05),(1.0,.45,.05)]
      ribbon('Clear tree-side stream',pts,[.22,.30,.30,.25,.22,.15],p['water'],.02)
      for j in range(5):
        flower_cluster(p,(-1.45+j*.28,.5+j*.12,.28+j*.20),.30,j)
      understory(p,(.65,.65,.08),.67,5)
      rock('Moss-coated root seat',(-1.25,-.1,.24),(.55,.4,.30),p['stone_light'],30)
    elif kind in ['decor_a','landmark_b']:
      broad_tree(p,(0,.15,.0),.73 if kind=='decor_a' else .85,35)
      understory(p,(.45,-.25,.02),.6,11)
      flower_cluster(p,(-.45,-.35,.05),.40)
    elif kind=='decor_b':understory(p,(0,0,0),.92,6)
    elif kind=='decor_c':
      rock('Streamside moss rock',(-.18,.1,.23),(.65,.58,.30),p['stone'],11)
      for j in range(4):flower_cluster(p,(-.4+j*.20,-.30+j*.05,.26+j*.09),.38,j)
      for i in range(3):leaf('Falling broad forest leaf',(-.05,.2,.3),(.58+ i*.1,-.22,.1+i*.13),.19,p['leaf_mid'])
    elif kind=='landscape':
      island(p,'rainforest')
      pts=[(-8.7,7.7,-.01),(-8.35,5.3,-.01),(-8.55,2.3,-.01),(-8.2,-1,-.01),(-8.7,-4.0,-.01),(-8.1,-7.6,-.01),(-5,-8.15,-.01),(-1,-8.25,-.01),(3.0,-8.15,-.01),(7.8,-8.0,-.01),(8.4,-4.8,-.01)]
      ribbon('Deep curved creek bed',pts,[.61]*len(pts),p['dark'],.03)
      ribbon('Clear turquoise forest creek',pts,[.47]*len(pts),p['water'],.065)
      for j,(x,y) in enumerate([(-8.95,5.9),(-8.9,1),(-8.9,-4.9),(-6.2,-8.6),(-1.9,-8.7),(4.8,-8.7),(8.8,-5.8)]):
        rock('Creek bank boulder',(x,y,.03),(.53,.43,.25),p['stone_light'] if j%2 else p['stone'],j+16)
        if j%2:understory(p,(x,y,.13),.48,j)
      # Rear dense understory remains entirely outside 14x14m playable footprint.
      for j,x in enumerate([-6.7,-3.8,0,3.0,6.3]):
        understory(p,(x,8.3,.02),.73,j+20)
        rock('Layered back-bank moss rock',(x+.8,8.6,.1),(.85,.6,.35),p['stone'],j+22)
      # Additional canopy tiers are built as branch-and-leaf trees, not a row of symbols.
      broad_tree(p,(-3.7,8.8,.02),.63,72)
      broad_tree(p,(3.4,8.85,.02),.69,87)
      # Two lush broad-leaf understory masses and low front grasses create density gradients.
      understory(p,(8.7,2.4,.02),1.20,98)
      understory(p,(-8.8,4.3,.02),1.05,83)
      for x,y in [(-6.2,-8.7),(-1.6,-8.7),(3.8,-8.7),(8.6,-5.5)]:
        for i in range(5):
          a=i*2.399;leaf('Low stream-bank grass',(x,y,.05),(x+math.cos(a)*.35,y+math.sin(a)*.35,.30+(i%2)*.13),.055,p['leaf_light'])
      for j in range(4):
        flower_cluster(p,(8.10+.12*math.sin(j),1.2+j*.7,.12+j*.10),.39,j)
      for x,y in [(-5.0,-8.2),(-.7,-8.2),(4.2,-8.15),(-8.3,2)]:
        curve('Soft white creek glint',[(x-.4,y,.10),(x,y-.07,.10),(x+.35,y,.10)],p['foam'],.018)


def animate(kind,root,objects):
    if kind not in ['creature','portal','gate']:return
    moving=[o for o in objects if o.type in ['MESH','CURVE'] and (kind!='gate' or 'safety bar' in o.name)]
    pivot=bpy.data.objects.new('Moving_'+kind,None);bpy.context.collection.objects.link(pivot);pivot.parent=root
    for o in moving:o.parent=pivot
    for clip in (['open','close'] if kind=='gate' else ['idle']):
      pivot.animation_data_create();act=bpy.data.actions.new(clip);pivot.animation_data.action=act
      for f,v in ([(1,0),(24,1)] if kind=='gate' else [(1,0),(25,1),(49,0)]):
        pivot.location.z=(v if clip=='open' else 1-v)*1.25 if kind=='gate' else v*.045
        pivot.rotation_euler.z=v*(.06 if kind=='creature' else TAU if kind=='portal' else 0)
        pivot.keyframe_insert('location',frame=f);pivot.keyframe_insert('rotation_euler',frame=f)
      act.use_fake_user=True;pivot.animation_data.action=None
      tr=pivot.animation_data.nla_tracks.new();tr.name=clip;tr.strips.new(clip,1,act)
    pivot.location=(0,0,0);pivot.rotation_euler=(0,0,0);objects.append(pivot)


def consolidated_export(path,objects):
    """Evaluate modifiers into temporary meshes and combine static geometry by material.
    Unmerged editable source remains untouched and is saved in the Blender kit."""
    bpy.context.view_layer.update();dep=bpy.context.evaluated_depsgraph_get();groups={}
    for o in objects:
      if o.type not in ['MESH','CURVE','SURFACE']:continue
      ev=o.evaluated_get(dep);me=bpy.data.meshes.new_from_object(ev,depsgraph=dep)
      for matid in sorted({p.material_index for p in me.polygons}):
        mat=me.materials[matid] if me.materials else None;key=mat.name if mat else 'none'
        data=groups.setdefault(key,{'verts':[],'faces':[],'smooth':[],'mat':mat});offset=len(data['verts'])
        data['verts'].extend([o.matrix_world@v.co for v in me.vertices])
        for f in me.polygons:
          if f.material_index==matid:data['faces'].append(tuple(offset+v for v in f.vertices));data['smooth'].append(f.use_smooth)
      bpy.data.meshes.remove(me)
    temp=[]
    for name,g in groups.items():
      o=mesh('Batched '+name,g['verts'],g['faces'],g['mat']);temp.append(o)
      for f,smooth in zip(o.data.polygons,g['smooth']):f.use_smooth=smooth
    export_asset(path,temp)
    stats={'material_batches':len(temp),'vertices':sum(len(o.data.vertices) for o in temp),'triangles':sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in temp)}
    for o in temp:
      data=o.data;bpy.data.objects.remove(o,do_unlink=True);bpy.data.meshes.remove(data)
    return stats


def make(t,kind,p):
    before=set(bpy.data.objects)
    if t=='inferno':inferno_build(kind,p)
    elif t=='rainforest':rainforest_build(kind,p)
    else:
      from city_meshes_v2 import build_city
      build_city(kind,p)
    objs=list(set(bpy.data.objects)-before)
    for o in objs:
      # Tiny rail/window edges do not need the same tessellation as large silhouettes.
      for mod in o.modifiers:
        if mod.type=='BEVEL':mod.segments=1 if mod.width<=.03 else 2 if mod.width<=.08 else 3
      if o.type=='CURVE':o.data.resolution_u=min(o.data.resolution_u,8);o.data.bevel_resolution=min(o.data.bevel_resolution,2)
    if kind=='landmark' and t!='city':
      for o in objs:o.location+=Vector((-1.3,.8,0))
    if not objs:return None
    root=parent_all(objs,t+'_'+kind);objs.append(root)
    if kind in ['creature','portal','gate']:
      animate(kind,root,objs);export_asset(OUT+'/'+t+'_'+kind+'.glb',objs)
      stats={'animated':True,'source_objects':len(objs)}
    else:stats=consolidated_export(OUT+'/'+t+'_'+kind+'.glb',objs)
    ASSETS[t+'_'+kind]=objs;STATS[t+'_'+kind]=stats
    return root


def duplicate(key,loc=(0,0,0),s=1,rot=0):
    if key not in ASSETS:return
    mapping={}
    for o in ASSETS[key]:
      n=o.copy();n.data=o.data;bpy.context.collection.objects.link(n);mapping[o]=n
    for o,n in mapping.items():
      if o.parent in mapping:n.parent=mapping[o.parent]
    root=mapping[next(o for o in ASSETS[key] if o.parent is None)];root.location=loc;root.scale=(s,)*3;root.rotation_euler.z=rot
    return root


def preview(t,p):
    duplicate(t+'_landscape')
    # The full 7x7 board demonstrates landscape clearance at actual asset scale.
    for j in range(7):
      for i in range(7):duplicate(t+'_tile',((i-3)*2,(j-3)*2,0))
    for x,y in [(-6,-4),(-6,-2),(-6,0),(0,6),(2,6),(4,6),(6,6),(2,2),(4,2),(-2,-2)]:duplicate(t+'_wall_b' if int(x+y)%4==0 else t+'_wall',(x,y,0))
    for x,y in [(-2,2),(2,-2)]:duplicate(t+'_goal',(x,y,0))
    for x,y in [(0,2),(2,0)]:duplicate(t+'_crate',(x,y,0))
    duplicate(t+'_landmark',(-7.7,6.7,0),1)
    duplicate(t+'_landmark_b',(7.6,6.5,0),.8)
    duplicate(t+'_decor_b',(-8.0,-3.0,0),.75)
    duplicate(t+'_decor_c',(8.1,-1.2,0),.8)
    duplicate(t+'_creature',(6.3,-5.2,0),1.1)
    special={'inferno':'portal','rainforest':'arrow','city':'plate'}[t]
    duplicate(t+'_'+special,(-2,-4,.02))
    if t=='city':duplicate('city_gate',(4,0,.01))
    box('Preview matte studio floor',(0,0,-1.55),(200,200,.12),material('V2 studio '+t,{'inferno':(.17,.19,.25),'rainforest':(.42,.57,.51),'city':(.45,.57,.61)}[t],roughness=.8),0)
    bpy.ops.object.light_add(type='AREA',location=(-8,-8,18));o=bpy.context.object;o.name='Large warm softbox';o.data.energy=2500;o.data.size=10;o.data.color=(1,.86,.70)
    bpy.ops.object.light_add(type='AREA',location=(7,5,13));o=bpy.context.object;o.name='Cool canopy fill';o.data.energy=1900;o.data.size=9;o.data.color=(.70,.85,1)
    if t=='inferno':
      bpy.ops.object.light_add(type='AREA',location=(-7.7,4.7,3));o=bpy.context.object;o.data.energy=100;o.data.color=(1,.36,.10);o.data.size=2
    bpy.ops.object.camera_add(location=(20,-29,27));c=bpy.context.object;c.rotation_euler=(Vector((0,.7,1.3 if t=='city' else 1.0 if t=='rainforest' else .5))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=30.5 if t=='city' else 29.7 if t=='rainforest' else 27.5
    sc=bpy.context.scene;sc.camera=c;sc.render.engine='CYCLES';sc.cycles.samples=int(os.environ.get('FOURFOLD_SAMPLES','64'));sc.cycles.use_adaptive_sampling=True;sc.cycles.adaptive_threshold=.025;sc.cycles.use_denoising=False
    sc.render.resolution_x=1500;sc.render.resolution_y=1150;sc.render.resolution_percentage=int(os.environ.get('FOURFOLD_RES','100'));sc.world.color=(.30,.30,.30);sc.view_settings.view_transform='AgX'
    sc.render.filepath=SHOTS+'/blender_'+t+'_v2.png'
    bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/blender/'+t+'_v2.blend',compress=True)
    if not os.environ.get('FOURFOLD_SKIP_RENDER'):bpy.ops.render.render(write_still=True)


def world(t):
    clear();ASSETS.clear();p=pal(t)
    kinds=['tile','wall','wall_b','edge','crate','goal','decor_a','decor_b','decor_c','creature','landmark','landmark_b','landscape']+[{'inferno':'portal','rainforest':'arrow','city':'plate'}[t]]+(['gate'] if t=='city' else [])
    for i,k in enumerate(kinds):
      root=make(t,k,p)
      if root:root.location=(60+i*26,0,0)
    preview(t,p)
    with open(ROOT+'/blender/v2_'+t+'_stats.json','w') as f:json.dump({k:v for k,v in STATS.items() if k.startswith(t+'_')},f,indent=2)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['inferno','rainforest','city']
    for t in args:world(t)
