extends SceneTree
# QA-only exact wall mesh rays. No runtime source, materials or camera changes.
const VIEW=preload("res://scripts/world_view.gd")
const RULES=preload("res://scripts/puzzle_rules.gd")
var output:=""
var failures:Array=[]
var counts:Dictionary={"legal_cell_centers":0,"neighbor_legal_cell_centers":0,"goal_ring_surface_samples":0,"goal_tooth_surface_samples":0,"portal_surface_samples":0,"self_hidden_candidates":0,"wall_mesh_triangle_tests":0}
var wall_meshes:Array=[]
var view
var current_self:Array=[]
func _initialize():
 for s in OS.get_cmdline_user_args():
  if s.begins_with("--output="):output=s.trim_prefix("--output=")
 call_deferred("run")
func gather_walls():
 wall_meshes.clear()
 for asset in view.set_root.get_children():
  if not str(asset.scene_file_path).get_file() in ["inferno_wall.glb","inferno_wall_b.glb"]:continue
  # Original hidden MeshInstances retain the exact transforms used by batching.
  for mesh_node in asset.find_children("","MeshInstance3D",true,false):
   var faces:PackedVector3Array=mesh_node.mesh.get_faces()
   var transform:Transform3D=mesh_node.global_transform
   var world_faces:PackedVector3Array=[]
   for v in faces:world_faces.append(transform*v)
   var bounds:AABB=transform*mesh_node.mesh.get_aabb()
   wall_meshes.append({"bounds":bounds,"faces":world_faces})
func check_point(level_id:String,kind:String,point:Vector3):
 counts[kind]+=1
 var from:Vector3=point+view.camera.global_basis.z*100.0
 for wall in wall_meshes:
  var bounds:AABB=wall.bounds
  if not bounds.intersects_segment(from,point):continue
  var faces:PackedVector3Array=wall.faces
  for i in range(0,faces.size(),3):
   counts.wall_mesh_triangle_tests+=1
   var hit=Geometry3D.segment_intersects_triangle(from,point,faces[i],faces[i+1],faces[i+2])
   if hit!=null:
    if self_hidden(from,point):
     counts.self_hidden_candidates+=1;return
    failures.append({"level":level_id,"sample":kind,"point":[point.x,point.y,point.z],"wall_hit":[hit.x,hit.y,hit.z]});return
func self_hidden(from:Vector3,point:Vector3)->bool:
 var end:Vector3=point+view.camera.global_basis.z*.0001
 for part in current_self:
  var bounds:AABB=part.bounds
  if not bounds.intersects_segment(from,end):continue
  var faces:PackedVector3Array=part.faces
  for i in range(0,faces.size(),3):
   if Geometry3D.segment_intersects_triangle(from,end,faces[i],faces[i+1],faces[i+2])!=null:return true
 return false
func check_imported_glyphs(level_id:String):
 for asset in view.set_root.get_children():
  var file:String=str(asset.scene_file_path).get_file()
  if not file in ["inferno_goal.glb","inferno_portal.glb"]:continue
  current_self=[]
  var samples:Dictionary={}
  for node in asset.find_children("","MeshInstance3D",true,false):
   var mesh:Mesh=node.mesh;var transform:Transform3D=node.global_transform
   var own_faces:PackedVector3Array=[]
   for v in mesh.get_faces():own_faces.append(transform*v)
   current_self.append({"bounds":transform*mesh.get_aabb(),"faces":own_faces})
   for surface in range(mesh.get_surface_count()):
    var mat:Material=mesh.surface_get_material(surface)
    if mat==null:continue
    var name:String=mat.resource_name
    var kind:String=""
    if name.ends_with("glow"):kind="portal_surface_samples" if file=="inferno_portal.glb" else "goal_ring_surface_samples"
    elif name.ends_with("ivory") and file=="inferno_goal.glb":kind="goal_tooth_surface_samples"
    if kind=="":continue
    var arrays:Array=mesh.surface_get_arrays(surface)
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    for i in range(0,indices.size(),3):
     var ia:int=indices[i];var ib:int=indices[i+1];var ic:int=indices[i+2]
     var normal:Vector3=transform.basis*(normals[ia]+normals[ib]+normals[ic])
     if normal.dot(view.camera.global_basis.z)<=0:continue
     var a:Vector3=transform*vertices[ia];var b:Vector3=transform*vertices[ib];var c:Vector3=transform*vertices[ic]
     for p in [a,b,c,(a+b)*.5,(b+c)*.5,(c+a)*.5,(a+b+c)/3.0]:
      samples[p.snapped(Vector3(.00001,.00001,.00001))]={"point":p,"kind":kind}
  for sample in samples.values():check_point(level_id,sample.kind,sample.point)
 current_self=[]
func run():
 root.size=Vector2i(1440,900);view=VIEW.new();root.add_child(view);await process_frame
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels.json"));var records:Array=[]
 for level in data.levels:
  var asset_world:String=str(level.get("visual_world","heaven")) if level.world=="confluence" else str(level.world)
  if asset_world!="inferno":continue
  view.setup_level(level,RULES.initial(level));gather_walls()
  if wall_meshes.is_empty():failures.append({"level":level.id,"error":"No wall mesh nodes found"})
  var walls=RULES.cells(level.walls);var before:int=failures.size()
  for y in range(int(level.height)):
   for x in range(int(level.width)):
    var cell:=Vector2i(x,y)
    if cell in walls:continue
    check_point(level.id,"legal_cell_centers",view.grid_pos(cell)+Vector3(0,.03,0))
    for d in RULES.DIRS.values():
     if cell+d in walls:
      counts.neighbor_legal_cell_centers+=1;break
  check_imported_glyphs(level.id)
  records.append({"level":level.id,"wall_meshes":wall_meshes.size(),"occluded_samples":failures.size()-before})
  await process_frame
 view.queue_free();await process_frame
 var report={"passed":failures.is_empty(),"engine":Engine.get_version_info().string,"scope":"All inferno and inferno-skinned confluence levels at production 1440x900 camera. Rays from all legal-cell centers plus actual imported camera-facing goal ring/tooth and portal spiral triangle vertices, edge midpoints and centroids toward orthographic camera against exact transformed wall triangles. Candidate hits self-occluded by the glyph asset are excluded using its exact triangles. Finite surface sampling is not a whole-pixel proof; matched native frames independently reviewed.","levels":records.size(),"counts":counts,"failures":failures,"records":records}
 if counts.goal_ring_surface_samples==0 or counts.goal_tooth_surface_samples==0 or counts.portal_surface_samples==0:push_error("Missing expected glyph material samples");quit(2);return
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("INFERNO_WALL_OCCLUSION ",JSON.stringify({"passed":failures.is_empty(),"levels":records.size(),"counts":counts,"failures":failures.size()}))
 quit(0 if failures.is_empty() else 1)
