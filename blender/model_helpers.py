"""Original procedural modelling utilities. Blender coordinates: Z up, -Y front."""
import bpy, math, os
from mathutils import Vector

def material(name, color, metallic=0.0, roughness=.35, emission=0.0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color[:3],1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color[:3],1)
    p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=roughness
    if emission:p.inputs['Emission Color'].default_value=(*color[:3],1);p.inputs['Emission Strength'].default_value=emission
    return m

def finish(o,name,mat=None,bevel=0,smooth=False):
    o.name=name
    if mat:o.data.materials.append(mat)
    if bevel:
        m=o.modifiers.new('Rounded crafted edges','BEVEL');m.width=bevel;m.segments=3
        m=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    if smooth:
        for f in o.data.polygons:f.use_smooth=True
    return o

def box(name,loc,scale,mat,bevel=.06):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,bevel)

def sphere(name,loc,scale,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=1,location=loc);o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,mat,smooth=True)

def cylinder(name,loc,radius,depth,mat,vertices=32,bevel=.04):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    return finish(bpy.context.object,name,mat,bevel)

def cone(name,loc,radius1,radius2,depth,mat,vertices=32):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius1,radius2=radius2,depth=depth,location=loc)
    return finish(bpy.context.object,name,mat,.025,True)

def torus(name,loc,major,minor,mat,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=40,minor_segments=10,location=loc,rotation=rotation)
    return finish(bpy.context.object,name,mat,smooth=True)

def curve(name,points,mat,radius=.05):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=radius;c.bevel_resolution=3;c.resolution_u=16
    s=c.splines.new('BEZIER');s.bezier_points.add(len(points)-1)
    for p,co in zip(s.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o

def mesh(name,verts,faces,mat,bevel=0):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,name,mat,bevel)

def leaf(name,start,end,width,mat):
    a=Vector(start);b=Vector(end);d=b-a;side=d.cross(Vector((0,0,1))).normalized()
    if side.length<.01:side=Vector((1,0,0))
    verts=[]
    for j in range(13):
        t=j/12;w=width*(math.sin(math.pi*t)**.72)*(.9+.1*math.sin(t*math.pi*3))
        center=a+d*t+Vector((0,0,math.sin(math.pi*t)*width*.55))
        for i in range(7):
            q=(i/6-.5)*2
            verts.append(center+side*q*w+Vector((0,0,-q*q*w*.22)))
    faces=[(j*7+i,j*7+i+1,(j+1)*7+i+1,(j+1)*7+i) for j in range(12) for i in range(6)]
    o=mesh(name,verts,faces,mat)
    for f in o.data.polygons:f.use_smooth=True
    m=o.modifiers.new('Wax leaf thickness','SOLIDIFY');m.thickness=.025
    m=o.modifiers.new('Rounded leaf rim','BEVEL');m.width=.02;m.segments=2
    return o

def parent_all(objects,name='Asset'):
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
    for o in objects:o.parent=root
    return root

def export_asset(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False)

def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
