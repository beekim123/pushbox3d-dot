"""Original v2 mountain-city mesh kit. No external models, textures or images.
The caller owns collection roots, export, animation, composition and render.
Coordinates are Blender Z-up; front is -Y; every unit is one metre.
"""
from model_helpers import *
import math
from mathutils import Vector


def city_palette():
    return {
        'plaster': material('City v2 warm lime plaster',(.75,.60,.43),0,.73),
        'cream': material('City v2 old ivory stucco',(.91,.80,.62),0,.77),
        'coral': material('City v2 faded terracotta plaster',(.65,.27,.19),0,.75),
        'blue': material('City v2 rainwashed blue plaster',(.26,.49,.49),0,.65),
        'stone': material('City v2 warm grey retaining stone',(.32,.38,.39),0,.86),
        'edge': material('City v2 sediment cliff',(.20,.29,.33),0,.9),
        'paving': material('City v2 riverstone paving',(.48,.48,.43),0,.87),
        'road_alt': material('City v2 warm grey street pavers',(.55,.54,.48),0,.88),
        'light_paving': material('City v2 smooth step edges',(.77,.75,.62),0,.77),
        'asphalt': material('City v2 blue slate road',(.14,.24,.28),0,.85),
        'roof': material('City v2 clay roof tiles',(.40,.18,.15),0,.72),
        'roof_light': material('City v2 tile ridges',(.56,.29,.20),0,.65),
        'teal': material('City v2 transit enamel',(.07,.39,.40),.08,.36),
        'dark': material('City v2 deep window reveals',(.035,.105,.14),0,.60),
        'glass': material('City v2 sky reflected glass',(.19,.46,.52),.12,.20),
        'warm_glass': material('City v2 butterlit windows',(.91,.65,.28),0,.45,.18),
        'metal': material('City v2 iron and rail',(.13,.24,.25),.35,.43),
        'wood': material('City v2 carved balcony wood',(.32,.17,.11),0,.69),
        'yellow': material('City v2 transit cream',(.97,.72,.28),0,.44),
        'leaf': material('City v2 terrace leaves',(.18,.42,.24),0,.67),
        'leaf_light': material('City v2 sunlit terrace leaves',(.36,.55,.27),0,.64),
        'water': material('City v2 jade river water',(.08,.41,.48),.18,.22),
        'foam': material('City v2 river glints',(.43,.71,.69),.05,.34),
    }


def _slab_polygon(name, outline, bottom, top, mat, bevel=.06):
    n=len(outline)
    verts=[(x,y,bottom) for x,y in outline]+[(x,y,top) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,mat,bevel)


def _beam(name,a,b,r,mat):
    # Cylinder rather than a high-resolution Bezier for rigid architectural bars.
    a=Vector(a);b=Vector(b);d=b-a
    o=cylinder(name,(a+b)*.5,r,d.length,mat,vertices=10,bevel=.01)
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o


def _rail(name,a,b,z,mat,height=.32,spacing=.38):
    a=Vector((a[0],a[1],z));b=Vector((b[0],b[1],z));count=max(2,int((b-a).length/spacing)+1)
    _beam(name+' top rail',a+Vector((0,0,height)),b+Vector((0,0,height)),.022,mat)
    _beam(name+' lower rail',a+Vector((0,0,.10)),b+Vector((0,0,.10)),.016,mat)
    for i in range(count):
        v=a.lerp(b,i/(count-1));_beam(name+' post',v,v+Vector((0,0,height)),.022,mat)


def _stairs(name,loc,width,run,rise,count,p,rotation=0):
    before=set(bpy.data.objects);x,y,z=loc
    for i in range(count):
        top=rise*(i+1)/count
        box(name+' tread',(x,y+run*(i+.5)/count,z+top*.5),(width,run/count+.016,top),p['stone'],.035)
        box(name+' nosing',(x,y+run*i/count+.025,z+top+.016),(width+.035,.075,.035),p['light_paving'],.015)
    for side in [-1,1]:
        _beam(name+' sloping handrail',(x+side*(width*.5+.035),y,z+.36),(x+side*(width*.5+.035),y+run,z+rise+.36),.026,p['metal'])
        for i in [0,count//2,count]:
            yy=y+run*i/count;zz=z+rise*i/count
            _beam(name+' railing upright',(x+side*(width*.5+.035),yy,zz),(x+side*(width*.5+.035),yy,zz+.36),.025,p['metal'])


def _roof(name,x,y,z,w,d,p,flat=False):
    if flat:
        box(name+' roof deck',(x,y,z+.065),(w+.12,d+.12,.13),p['light_paving'],.045)
        for xx in [-w*.5,w*.5]:box(name+' low roof parapet',(x+xx,y,z+.19),(.09,d+.12,.25),p['cream'],.03)
        box(name+' rear parapet',(x,y+d*.5,z+.19),(w,.09,.25),p['cream'],.03)
        return
    # Hipped roof: four deep planes and lifted ridge create a clear silhouette.
    h=.34;over=.17;ww=w*.5+over;dd=d*.5+over;ridge=max(.05,w*.5-.30)
    verts=[(x-ww,y-dd,z),(x+ww,y-dd,z),(x+ww,y+dd,z),(x-ww,y+dd,z),
           (x-ridge,y,z+h),(x+ridge,y,z+h)]
    faces=[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4)]
    ob=mesh(name+' hipped tile roof',verts,faces,p['roof'],.025)
    so=ob.modifiers.new('Thick rounded ceramic eaves','SOLIDIFY');so.thickness=.075
    _beam(name+' roof ridge',(x-ridge,y,z+h+.025),(x+ridge,y,z+h+.025),.06,p['roof_light'])
    for i in range(max(4,int(w/.22))+1):
        xx=x-ww+.12+i*(2*ww-.24)/max(4,int(w/.22))
        if abs(xx-x)>ridge:
            ridge_z=z+h*(1-(abs(xx-x)-ridge)/(ww-ridge))
        else:ridge_z=z+h
        _beam(name+' fired tile seam front',(xx,y-dd,z+.02),(xx,y,ridge_z+.02),.014,p['roof_light'])
        _beam(name+' fired tile seam rear',(xx,y,ridge_z+.02),(xx,y+dd,z+.02),.014,p['roof_light'])


def _window(name,x,y,z,w,h,p,side=False,warm=False,shutter=False):
    mat=p['warm_glass'] if warm else p['glass']
    if not side:
        box(name+' deep inset',(x,y,z),(w+.075,.035,h+.075),p['dark'],.025)
        box(name+' glass',(x,y-.027,z),(w-.04,.018,h-.04),mat,.018)
        box(name+' mullion',(x,y-.046,z),(.025,.025,h),p['cream'],.005)
        box(name+' sill',(x,y-.065,z-h*.5-.028),(w+.15,.13,.065),p['light_paving'],.018)
        if shutter:
            for sign in [-1,1]:box(name+' side shutter',(x+sign*(w*.5+.09),y-.026,z),(.12,.045,h),p['teal'],.014)
    else:
        box(name+' side inset',(x,y,z),(.035,w+.075,h+.075),p['dark'],.025)
        box(name+' side glass',(x+.027,y,z),(.018,w-.04,h-.04),mat,.018)
        box(name+' side sill',(x+.065,y,z-h*.5-.028),(.13,w+.15,.065),p['light_paving'],.018)


def _planter(name,x,y,z,w,p):
    box(name+' terracotta trough',(x,y,z+.09),(w,.23,.18),p['coral'],.045)
    for i in range(max(2,int(w/.2))):
        xx=x-w*.4+i*w*.8/max(1,int(w/.2)-1)
        sphere(name+' clipped foliage',(xx,y,z+.22),(.17,.15,.15),p['leaf_light'] if i%2 else p['leaf'])


def _house(name,loc,w,d,h,p,body='cream',floors=3,flat=False,balcony=True,stilts=False):
    x,y,z=loc
    if stilts:
        for xx in [-w*.38,w*.38]:
            for yy in [-d*.38,d*.38]:box(name+' hillside support',(x+xx,y+yy,z+.35),(.13,.13,.7),p['wood'],.025)
        z+=.6
    box(name+' plaster volume',(x,y,z+h*.5),(w,d,h),p[body],.075)
    box(name+' footing',(x,y,z+.07),(w+.08,d+.08,.14),p['stone'],.045)
    for level in range(floors):
        zz=z+(level+.55)*h/floors
        ww=min(.32,w*.20);hh=min(.45,h/floors*.53)
        for col in [-1,1]:
            _window(name+' front window',x+col*w*.26,y-d*.5-.026,zz,ww,hh,p,warm=(level+col)%3==0,shutter=level==floors-1 and w>1.25)
        for yy in [-d*.23,d*.23]:_window(name+' side window',x+w*.5+.027,y+yy,zz,ww*.83,hh,p,side=True,warm=level%3==1)
        if balcony and level%2==1:
            bz=zz-hh*.5-.08
            box(name+' balcony slab',(x,y-d*.5-.20,bz),(w+.10,.43,.10),p['light_paving'],.025)
            _rail(name+' balcony',(x-w*.47,y-d*.5-.37),(x+w*.47,y-d*.5-.37),bz+.045,p['metal'],.28,.24)
            _rail(name+' return left',(x-w*.47,y-d*.5-.37),(x-w*.47,y-d*.5),bz+.045,p['metal'],.28)
            _rail(name+' return right',(x+w*.47,y-d*.5-.37),(x+w*.47,y-d*.5),bz+.045,p['metal'],.28)
            if level==1:_planter(name+' balcony garden',x+w*.23,y-d*.5-.27,bz+.08,w*.36,p)
        if level>0:box(name+' plaster string course',(x,y-d*.5-.02,z+level*h/floors),(w+.05,.07,.055),p['cream'],.012)
    # The doorway distinguishes a ground floor from a stack of window cubes.
    box(name+' shop door reveal',(x-w*.18,y-d*.5-.035,z+.31),(.40,.045,.61),p['dark'],.045)
    box(name+' shop door',(x-w*.18,y-d*.5-.062,z+.29),(.30,.025,.52),p['teal'],.025)
    box(name+' fabric shop awning',(x,y-d*.5-.19,z+.75),(w*.91,.43,.09),p['yellow'] if body=='blue' else p['coral'],.035)
    _roof(name,x,y,z+h,w,d,p,flat)
    if flat:
        box(name+' roof utility hut',(x-w*.18,y+d*.08,z+h+.32),(w*.45,d*.43,.48),p['blue'],.06)
        box(name+' roof utility cap',(x-w*.18,y+d*.08,z+h+.58),(w*.51,d*.50,.09),p['cream'],.025)
        _planter(name+' roof garden',x+w*.20,y-d*.25,z+h+.16,w*.43,p)


def _transit(name,loc,length,p):
    x,y,z=loc
    box(name+' rounded tram body',(x,y,z+.23),(length,.48,.46),p['yellow'],.12)
    box(name+' teal lower trim',(x,y,z+.10),(length+.025,.495,.14),p['teal'],.06)
    box(name+' roof',(x,y,z+.49),(length*.94,.49,.10),p['cream'],.05)
    for i in range(4):
        xx=x+(i-1.5)*(length*.20)
        box(name+' passenger window',(xx,y-.25,z+.29),(length*.145,.025,.22),p['dark'],.035)
        box(name+' passenger glass',(xx,y-.267,z+.30),(length*.108,.014,.16),p['glass'],.018)
    for xx in [-length*.33,length*.33]:
        for yy in [-.19,.19]:
            ob=cylinder(name+' wheel',(x+xx,y+yy,z+.04),.09,.05,p['metal'],16,.015);ob.rotation_euler[0]=math.pi/2


def _viaduct(name,points,p,train=True):
    # Sampled ribbon; constant-width deck follows a deliberate gentle curve.
    verts=[];n=len(points)
    for i,(x,y,z) in enumerate(points):
        tang=Vector(points[min(i+1,n-1)])-Vector(points[max(0,i-1)])
        nor=Vector((-tang.y,tang.x,0)).normalized()
        for side in [-1,1]:verts.append(Vector((x,y,z))+nor*side*.42)
    faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(n-1)]
    ob=mesh(name+' curved viaduct slab',verts,faces,p['teal'],.045)
    sol=ob.modifiers.new('Bridge deck depth','SOLIDIFY');sol.thickness=.18
    for side in [-1,1]:
        rail=[]
        for i in range(n):rail.append(tuple(verts[2*i+(1 if side==1 else 0)]+Vector((0,0,.22))))
        curve(name+' continuous parapet',rail,p['cream'],.055)
        for i in range(0,n,2):
            v=verts[2*i+(1 if side==1 else 0)];_beam(name+' safety uprights',v,v+Vector((0,0,.22)),.025,p['metal'])
    for idx in [1,n//2,n-2]:
        x,y,z=points[idx]
        box(name+' flared pier capital',(x,y,z-.23),(.56,.64,.20),p['stone'],.06)
        box(name+' reinforced pier',(x,y,(z-.4)*.5),(.26,.35,z-.4),p['stone'],.045)
        box(name+' pier foot',(x,y,.08),(.53,.62,.16),p['light_paving'],.05)
    for i in range(n-1):
        a=Vector(points[i]);b=Vector(points[i+1]);mid=a.lerp(b,.5)
        _beam(name+' two steel running rails',a+Vector((0,-.14,.035)),b+Vector((0,-.14,.035)),.027,p['metal'])
        _beam(name+' two steel running rails',a+Vector((0,.14,.035)),b+Vector((0,.14,.035)),.027,p['metal'])
    if train:
        q=points[n//2];_transit(name+' hill tram',(q[0],q[1],q[2]+.035),1.65,p)


def _lamp(name,x,y,z,p):
    cylinder(name+' pole',(x,y,z+.60),.035,1.2,p['metal'],12,.01)
    curve(name+' swan neck',[(x,y,z+1.18),(x+.08,y,z+1.35),(x+.27,y,z+1.35)],p['metal'],.03)
    sphere(name+' shaded lamp',(x+.26,y,z+1.30),(.13,.13,.08),p['warm_glass'])
    cone(name+' rain hood',(x+.26,y,z+1.38),.17,.06,.10,p['teal'],16)


def _river_patch(name,path,width,z,p):
    verts=[]
    for i,pt in enumerate(path):
        tangent=Vector((*path[min(i+1,len(path)-1)],0))-Vector((*path[max(0,i-1)],0))
        normal=Vector((-tangent.y,tangent.x,0)).normalized()
        for sign in [-1,1]:verts.append(Vector((*pt,z))+normal*width*.5*sign)
    faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(path)-1)]
    ob=mesh(name+' broad river surface',verts,faces,p['water']);sol=ob.modifiers.new('River water depth','SOLIDIFY');sol.thickness=.12
    for i in range(1,len(path)-1,2):
        x,y=path[i];curve(name+' quiet surface current',[(x-.36,y-.08,z+.025),(x,y+.02,z+.025),(x+.42,y+.04,z+.025)],p['foam'],.012)


def build_city(kind,p=None):
    created_before=set(bpy.data.objects)
    p=city_palette()
    if kind=='tile':
        box('Mountain street tile substrate',(0,0,-.21),(1.98,1.98,.30),p['stone'],.075)
        # Broad paving with subtle offset joints, no decorative metal frame.
        for row in range(2):
            for col in range(2):
                x=(col-.5)*.97;y=(row-.5)*.97
                box('Large rainwashed street paver',(x,y,-.020),(.935,.935,.05),p['paving'] if (col+row)%2 else p['road_alt'],.025)
        for yy in [-.73,-.57,-.41]:box('Side drain slit',(.78,yy,.003),(.12,.035,.012),p['dark'],.008)
    elif kind in ('wall','wall_b'):
        # Low retaining wall, asymmetrical raised planter, not a crate-shaped solid.
        box('Retaining plinth',(0,0,.12),(1.80,1.70,.24),p['stone'],.09)
        for row in range(2):
            for col in range(3):
                box('Retaining ashlar masonry',((col-1)*.56,-.04,.24+row*.20),(.53,1.46,.19),p['stone'] if (row+col)%2 else p['paving'],.055)
        box('Wide rounded retaining coping',(0,0,.65),(1.86,1.71,.14),p['light_paving'],.085)
        box('Retaining top planted strip',(0,.46,.742),(1.48,.30,.045),p['leaf'],.09)
        for x in [-.47,0,.46]:sphere('Low clipped retaining greenery',(x,.46,.745),(.28,.22,.045),p['leaf_light'])
        if kind=='wall_b':
            box('Retaining inset ceramic drain',(0,-.78,.41),(.48,.05,.20),p['dark'],.04)
            for xx in [-.15,0,.15]:box('Retaining drain slat',(xx,-.815,.41),(.035,.025,.17),p['metal'],.008)
    elif kind=='edge':
        _slab_polygon('Layered riverfront edge',[(-1,-1),(1,-1),(1,.9),(.55,1),(-.73,.96),(-1,.5)],-.92,-.04,p['edge'],.09)
        for row in range(3):
            for col in range(3):box('Riverfront ashlar course',((col-1)*.65,-.96,-.19-row*.23),(.62,.10,.21),p['stone'] if (row+col)%2 else p['paving'],.045)
        box('Embankment coping',(0,-.97,-.05),(1.99,.20,.16),p['light_paving'],.045)
    elif kind=='crate':
        box('Enamel transport trunk',(0,0,.53),(1.02,1.02,1.02),p['teal'],.11)
        for x in [-.39,.39]:
            box('Crate reinforced vertical rail',(x,-.522,.53),(.075,.04,.84),p['cream'],.018)
            box('Crate lid binding',(x,0,1.05),(.075,.99,.055),p['cream'],.016)
        for y in [-.50,.50]:box('Crate inset panel',(0,y,.56),(.58,.035,.56),p['blue'],.045)
        for y in [-.53,.53]:
            torus('Crate circular freight seal',(0,y,.57),.18,.035,p['yellow'],(math.pi/2,0,0))
            box('Crate freight seal stem',(0,y-.018,.57),(.055,.025,.20),p['cream'],.01)
        for x in [-.54,.54]:box('Crate recessed lifting handle',(x,0,.68),(.035,.35,.13),p['dark'],.04)
        box('Crate inset lid',(0,0,1.055),(.57,.67,.035),p['blue'],.05)
    elif kind=='goal':
        cylinder('Station delivery marker base',(0,0,.025),.68,.05,p['dark'],40,.015)
        cylinder('Station delivery marker ceramic',(0,0,.058),.59,.025,p['teal'],40,.01)
        torus('Station clear destination ring',(0,0,.09),.46,.045,p['yellow'])
        for a in range(4):
            ang=a*math.pi/2
            o=box('Destination station notch',(math.cos(ang)*.34,math.sin(ang)*.34,.09),(.13,.06,.025),p['cream'],.015);o.rotation_euler[2]=ang
    elif kind=='creature':
        box('Cablecar pal rounded body',(0,0,.46),(.72,.57,.67),p['coral'],.18)
        box('Cablecar pal cream face',(0,-.285,.53),(.54,.055,.31),p['cream'],.10)
        box('Cablecar pal teal bumper',(0,-.30,.22),(.63,.075,.13),p['teal'],.055)
        for x in [-.14,.14]:
            sphere('Cablecar friendly eye',(x,-.323,.55),(.038,.025,.052),p['dark'])
            sphere('Cablecar tiny shoe',(x*1.5,-.04,.085),(.14,.19,.085),p['metal'])
        curve('Cablecar soft smile',[(-.075,-.331,.43),(0,-.345,.405),(.075,-.331,.43)],p['coral'],.018)
        curve('Cablecar curved hanger',[(-.20,.02,.78),(-.19,.02,1.02),(.19,.02,1.02),(.20,.02,.78)],p['metal'],.035)
        box('Cablecar rain roof',(0,0,.83),(.81,.64,.10),p['yellow'],.08)
    elif kind=='landmark':
        # Three structural terraces grow into a little quarter; it has a back,
        # passages, supporting columns and several different roof heights.
        _slab_polygon('Cliff quarter irregular foundation',[(-3,-2.1),(2.8,-2.1),(3.15,-.9),(2.8,1.8),(.9,2.2),(-2.8,1.7)],0,.42,p['stone'],.13)
        box('Middle neighborhood terrace',(-.15,.25,.83),(5.2,2.85,.86),p['paving'],.12)
        box('Upper neighborhood terrace',(.68,.78,1.55),(3.6,1.95,.65),p['stone'],.10)
        _house('Lower coral riverside house',(-1.65,-.32,.43),1.50,1.48,1.8,p,'coral',2,False,True)
        _house('Middle blue merchant house',(.05,.14,1.27),1.55,1.65,2.55,p,'blue',3,False,True)
        _house('Highest cream courtyard residence',(1.70,.82,1.88),1.32,1.43,3.55,p,'cream',4,True,True)
        _house('Backside ochre lane house',(-1.63,1.13,1.29),1.32,1.10,2.65,p,'plaster',3,False,False)
        _house('Stilted small tea shop',(1.85,-1.0,.44),1.30,1.02,1.10,p,'plaster',1,False,False,True)
        # Front public route has an actual stair run and upper landing.
        _stairs('Cliff lane climb',(-2.50,-1.82,.43),.66,2.1,1.30,10,p)
        box('Cliff pedestrian balcony',(-.20,-1.66,1.53),(3.70,.53,.16),p['light_paving'],.04)
        _rail('Public balcony rail',(-1.93,-1.91),(1.59,-1.91),1.63,p['metal'],.35,.30)
        for x in [-1.6,.0,1.35]:box('Public walkway support',(x,-1.64,.80),(.14,.19,1.43),p['wood'],.025)
        _viaduct('Neighborhood light railway',[(-3.05,-.77,2.80),(-2.2,-.89,2.86),(-1.2,-.98,2.93),(0,-1.05,3.03),(1.2,-1.00,3.13),(2.2,-.85,3.20),(3.15,-.61,3.25)],p)
        _planter('Public corner planter',-.70,-1.85,.45,.68,p)
        _lamp('Neighborhood lane lamp',2.55,-1.55,.43,p)
    elif kind=='decor_a':
        _slab_polygon('Small street quarter foundation',[(-1.6,-1.3),(1.5,-1.3),(1.65,.6),(.8,1.35),(-1.4,1.1)],0,.22,p['stone'],.09)
        box('Sloping lane landing',(.52,.24,.55),(1.75,1.7,.65),p['paving'],.09)
        _house('Lane coral shop',(-.73,-.05,.22),1.05,1.3,1.7,p,'coral',2,False,False)
        _house('Raised blue residence',(.70,.45,.88),1.12,1.30,2.05,p,'blue',2,True,True)
        _stairs('Pocket lane steps',(.45,-1.15,.22),.62,1.0,.65,6,p)
        _planter('Lane flower trough',-1.1,-1.0,.25,.65,p)
    elif kind=='decor_b':
        _slab_polygon('Stepped pocket park',[(-1.1,-1.0),(.95,-1.0),(1.0,.85),(-.85,1.0)],0,.17,p['stone'],.06)
        _stairs('Public river steps',(-.40,-.85,.17),.78,1.48,.82,7,p)
        box('Top river landing',(-.4,.77,1.05),(.90,.36,.14),p['light_paving'],.04)
        _rail('Top river lookout',(-.82,.9),(.03,.9),1.12,p['metal'],.31)
        _lamp('Pocket streetlamp',.58,.39,.17,p)
        _planter('River terrace garden',.55,-.48,.17,.62,p)
        box('Pocket park bench seat',(.54,.05,.48),(.61,.30,.09),p['wood'],.035)
        for xx in [.31,.77]:box('Park bench feet',(xx,.05,.32),(.07,.25,.27),p['metal'],.018)
    elif kind=='landmark_b':
        _slab_polygon('Secondary station quarter foundation',[(-2.2,-1.3),(2.1,-1.3),(2.3,1.2),(.9,1.8),(-2.2,1.4)],0,.35,p['stone'],.11)
        box('Station upper landing',(.55,.6,.71),(2.95,1.85,.72),p['paving'],.09)
        _house('Old ticket hall',(-1.12,.0,.35),1.52,1.40,1.70,p,'plaster',2,False,False)
        _house('Blue hillside lookout',(.83,.80,1.08),1.55,1.28,2.55,p,'blue',3,True,True)
        _stairs('Station climbing lane',(1.72,-1.15,.35),.58,1.65,.74,8,p)
        box('Station public canopy',(0,-.99,1.56),(3.45,.66,.13),p['teal'],.055)
        for x in [-1.4,1.4]:box('Canopy timber pier',(x,-.97,.96),(.12,.15,1.2),p['wood'],.025)
        _rail('Station terrace edge',(-1.8,-1.3),(1.6,-1.3),.36,p['metal'],.33)
        _lamp('Station path light',-1.8,1.20,.35,p)
    elif kind=='decor_c':
        _slab_polygon('Riverside ticket kiosk plaza',[(-1.40,-1.15),(1.45,-1.15),(1.32,1.15),(-1.16,1.27)],0,.19,p['paving'],.08)
        _house('Riverside tiny ferry kiosk',(-.38,.20,.19),1.21,1.13,1.33,p,'cream',1,False,False)
        box('Ferry schedule board',(1.0,.45,.78),(.50,.10,.72),p['teal'],.055)
        box('Ferry schedule ivory inset',(1.0,.385,.84),(.37,.025,.47),p['cream'],.025)
        for zz in [.71,.84,.97]:box('Ferry route graphic',(1.0,.365,zz),(.24,.015,.025),p['coral'],.006)
        box('Ferry schedule post',(1.0,.45,.32),(.075,.09,.40),p['metal'],.015)
        _planter('Kiosk side garden',-.88,-.78,.19,.73,p)
        _lamp('Ferry waiting light',.93,-.68,.19,p)
    elif kind=='plate':
        box('Freight pressure plate kerb',(0,0,.045),(1.52,1.52,.09),p['dark'],.09)
        box('Freight pressure plate',(0,0,.105),(1.27,1.27,.07),p['yellow'],.07)
        for x in [-.43,0,.43]:box('Plate grip bars',(x,0,.15),(.07,.91,.025),p['teal'],.012)
        for x in [-.61,.61]:cylinder('Pressure plate status lamp',(x,.58,.15),.055,.03,p['warm_glass'],16,.005)
    elif kind=='gate':
        for x in [-.73,.73]:
            box('Freight lifting barrier pillar',(x,0,.64),(.22,.34,1.28),p['teal'],.06)
            box('Freight barrier column foot',(x,0,.11),(.36,.44,.22),p['stone'],.045)
            sphere('Freight pillar signal',(x,-.19,1.04),(.065,.035,.065),p['yellow'])
        for row in range(3):
            box('Freight gate safety bar',(0,0,.31+row*.29),(1.32,.17,.14),p['yellow'],.035)
            for xx in [-.43,0,.43]:
                o=box('Freight gate safety bar diagonal marking',(xx,-.092,.31+row*.29),(.13,.018,.16),p['dark'],.01);o.rotation_euler[1]=-.42
        box('Freight gate upper gantry',(0,0,1.36),(1.78,.39,.17),p['teal'],.055)
    elif kind in ('landscape','environment'):
        # A continuous shoreline diorama, not a tiled border. Central gameplay
        # clearance x[-7,7], y[-7,7], z>=-.03 is preserved by this scenery.
        outline=[(-11.4,-6.7),(-10.8,-8.7),(-7.4,-9.7),(-3.5,-9.9),(1.0,-9.5),(5.0,-9.9),(9.5,-8.6),(11.4,-5.0),(11.2,3.8),(10.3,8.8),(6.9,10.2),(.5,10.5),(-5.7,10.1),(-10.7,8.3),(-11.7,2.2)]
        _slab_polygon('Mountain city whole river island',outline,-1.65,-.68,p['edge'],.22)
        _slab_polygon('Continuous city bank shelf',[(-10.9,-5.7),(-7.9,-6.35),(-4,-6.4),(1,-6.4),(5,-6.35),(8,-5.75),(9.45,-2),(9.2,5.7),(6.8,8.5),(-6.4,8.3),(-10.3,5.8)],-.82,-.56,p['stone'],.12)
        central=_slab_polygon('Continuous central street ground',[(-7.20,-7.22),(6.95,-7.22),(7.24,-6.92),(7.24,6.95),(6.93,7.24),(-6.95,7.24),(-7.25,6.95),(-7.25,-6.93)],-.65,-.03,p['stone'],.045)
        central.data.materials.append(p['paving'])
        central.data.polygons[1].material_index=1
        front_start=set(bpy.data.objects)
        river=[(-10.9,-5.9),(-9.2,-7.0),(-6.4,-7.5),(-3.0,-7.7),(.6,-7.5),(3.8,-7.7),(7.2,-6.9),(9.2,-5.3),(10.0,-2.5),(10.3,.8),(9.9,4.0)]
        _river_patch('Mountain city curved jade river',river,1.90,-.62,p)
        # Riverbank is a long curved masonry edge; paths are low and outside board.
        curve('Curved public riverbank coping',[(-10.4,-5.5,-.45),(-8.1,-6.15,-.45),(-4.7,-6.4,-.45),(-1,-6.35,-.45),(3.2,-6.35,-.45),(6.8,-5.9,-.45),(8.4,-3.5,-.45),(8.85,.2,-.45),(8.5,4.3,-.45)],p['light_paving'],.11)
        for x,y in [(-8.8,-6.4),(-5.8,-6.8),(-2.2,-6.8),(1.4,-6.8),(5.1,-6.5),(8.1,-4.8),(8.9,-1.1)]:
            curve('Masonry riverbank pale joint',[(x-.17,y,-.57),(x-.1,y-.01,-.89)],p['paving'],.025)
        for ob in set(bpy.data.objects)-front_start:ob.location.y-=1.0
        # Back hill uses wide uneven terraces, supporting the skyline modules.
        back_start=set(bpy.data.objects)
        _slab_polygon('Back hill broad urban terrace',[(-10.7,6.15),(-6.5,6.3),(-1.2,6.35),(4.0,6.30),(9.3,6.0),(10.0,8.0),(6.8,9.0),(-5.7,8.9),(-10.7,7.2)],-.60,.48,p['stone'],.13)
        _slab_polygon('Upper hill quiet street',[(-8.6,7.6),(-3,7.5),(3.6,7.3),(8.3,7.2),(7.9,8.75),(1.2,9.15),(-7.3,8.75)],.47,1.13,p['paving'],.11)
        for x in [-8.6,-6.6,-4.6,-2.6,-.6,1.4,3.4,5.4,7.4]:
            box('Back hill retaining buttress',(x,6.38,-.01),(.24,.31,1.0),p['light_paving'],.045)
        for ob in set(bpy.data.objects)-back_start:ob.location.y+=1.0
        # Asymmetrical side escarpments leave broad breathing room at front.
        _slab_polygon('West sloping neighborhood shelf',[(-11.0,-2.1),(-8.1,-2.5),(-7.55,-.3),(-7.60,5.8),(-10.5,6.2)],-.65,.18,p['paving'],.15)
        _slab_polygon('East compact river terrace',[(7.8,1.8),(9.3,1.5),(9.55,5.8),(7.65,6.0)],-.65,.28,p['paving'],.11)
        # The skyline is sparse, coherent and varied, not a row of repeated towers.
        skyline_start=set(bpy.data.objects)
        _house('Back hill coral apartment',(-7.9,7.65,1.13),1.55,1.22,2.55,p,'coral',3,False,True)
        _house('Back hill old cream apartment',(-5.7,7.75,1.13),1.34,1.3,3.25,p,'cream',4,True,True)
        _house('Back hill low tea pavilion',(-3.15,8.05,1.13),1.80,1.35,1.65,p,'plaster',2,False,False)
        _house('Back hill blue apartment',(5.55,7.65,1.13),1.65,1.30,3.0,p,'blue',3,True,True)
        _house('Back hill cream corner',(7.8,7.55,1.13),1.20,1.35,2.0,p,'cream',2,False,False)
        # Elevated transport layer remains behind the playable cells.
        _viaduct('Back ridge looping transit',[(-10,6.75,1.45),(-8,6.80,1.5),(-6,6.9,1.57),(-4,7.0,1.68),(-2,7.0,1.81),(0,6.95,1.98),(2,6.90,2.15),(4,6.80,2.27),(6,6.7,2.34),(8,6.55,2.40),(9.8,6.45,2.43)],p)
        for ob in set(bpy.data.objects)-skyline_start:ob.location.y+=1.0
        _stairs('West hillside public stair',(-9.35,2.4,.18),1.08,3.75,1.0,14,p)
        for x,y in [(-10.4,-1.3),(-8.1,3.6),(8.3,3.2),(-9.5,5.4)]:_planter('City hillside landscaping',x,y,.22,.80,p)
        for x,y in [(-9.4,-3.9),(-6.7,-7.65),(5.7,-7.55),(8.9,1.45)]:_lamp('River embankment light',x,y,-.50,p)
        # Three moored low-profile ferries are intentionally far from mechanisms.
        for x,y,ang in [(-7.1,-8.55,.12),(3.8,-8.65,-.16)]:
            hull=sphere('Jade river small ferry hull',(x,y,-.50),(.64,.23,.12),p['teal']);hull.rotation_euler[2]=ang
            cabin=box('Ferry cream cabin',(x,y,-.31),(.54,.31,.24),p['cream'],.06);cabin.rotation_euler[2]=ang
            roof=box('Ferry clay roof',(x,y,-.15),(.66,.38,.06),p['coral'],.025);roof.rotation_euler[2]=ang
    else:
        raise ValueError('Unknown city asset kind: '+kind)

    # Inner-corner scenery anchor: the large quarter grows outward, not over tiles.
    if kind=='landmark':
        for ob in set(bpy.data.objects)-created_before:
            ob.location.x-=2.2
            ob.location.y+=.6
