extends SceneTree
# QA-only native capture: never changes runtime source or primary user save.
var game
var args: Dictionary={}
var rows: Array=[]
var failures: Array=[]
var baseline: Dictionary={}
func _initialize():
 for item in OS.get_cmdline_user_args():
  var bits=str(item).trim_prefix("--").split("=",true,1)
  args[bits[0]]=bits[1] if bits.size()>1 else true
 call_deferred("run")
func freeze(node: Node):
 if node is AnimationPlayer and node.current_animation!="":
  node.seek(0,true);node.pause()
 for child in node.get_children():freeze(child)
func v3(v: Vector3)->Array:return [v.x,v.y,v.z]
func v2(v: Vector2)->Array:return [v.x,v.y]
func camera_record(c: Camera3D)->Dictionary:return {"position":v3(c.global_position),"rotation":v3(c.global_rotation),"size":c.size,"fit_bounds":str(c.get_meta("fit_bounds",Rect2()))}
func marker_record()->Dictionary:
 var out={"crates":[],"goals":[]}
 if game.mode!="level":return out
 for p in game.state.crates:out.crates.append(v2(game.world.camera.unproject_position(game.world.grid_pos(p)+Vector3(0,.55,0))))
 for p in game.RULES.cells(game.level.goals):out.goals.append(v2(game.world.camera.unproject_position(game.world.grid_pos(p)+Vector3(0,.13,0))))
 return out
func screenshot(path: String):
 for i in range(10):await process_frame
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 var result=img.save_png(path)
 if result!=OK or img.get_size()!=Vector2i(1440,900):failures.append("Capture/size: "+path)
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 if not game.qa_mode or DisplayServer.get_name()=="headless":push_error("Native --qa required");quit(2);return
 game.set_process(false);game.set_process_unhandled_key_input(false)
 if game.music:game.music.stop()
 if game.ambience:game.ambience.stop()
 var output=str(args["output"]);DirAccess.make_dir_recursive_absolute(output)
 if args.has("baseline"):
  var doc=JSON.parse_string(FileAccess.get_file_as_string(str(args.baseline)))
  for row in doc.rows:baseline[row.id]=row
 for quality in str(args.get("qualities","high,low")).split(","):
  game.low_quality=quality=="low";game.apply_quality()
  for entry in [{"name":"inferno_10","index":9},{"name":"inferno_23","index":22},{"name":"inferno_45","index":44}]:
   if entry.index<0:game.show_hub()
   else:game.start_level(game.levels_by_world.inferno[entry.index])
   freeze(game.world);await process_frame
   var id=entry.name+"_"+quality
   var c:Camera3D=game.world.camera
   var raw=camera_record(c)
   if baseline.has(id):
    var ref=baseline[id].camera
    var same_position=c.global_position.distance_to(Vector3(ref.position[0],ref.position[1],ref.position[2]))<0.00001
    var same_rotation=c.global_rotation.distance_to(Vector3(ref.rotation[0],ref.rotation[1],ref.rotation[2]))<0.00001
    if not same_position or not same_rotation or absf(raw.size-ref.size)>0.0001:failures.append("Native camera differs from baseline: "+id)
   await screenshot(output+"/"+id+".png")
   var env:Environment=game.world.environment.environment
   rows.append({"id":id,"image":id+".png","native_image":id+".png","native_camera":raw,"camera":camera_record(c),"markers":marker_record(),"missing_assets":game.world.missing_assets.keys(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"quality":quality,"msaa":root.msaa_3d,"render_scale":root.scaling_3d_scale,"lighting":{"key":game.world.light.light_energy,"ambient":env.ambient_light_energy,"exposure":env.tonemap_exposure,"background":str(env.background_color)}})
   if not game.world.missing_assets.is_empty():failures.append("Missing assets "+id)
   print("INFERNO_WALL_NATIVE ",id," camera=",raw," captured=",output)
 var doc={"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":[root.size.x,root.size.y],"qa":game.qa_mode,"failures":failures,"rows":rows}
 FileAccess.open(output+"/capture_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(doc,"  "))
 print("INFERNO_WALL_NATIVE_COMPLETE ",JSON.stringify({"captures":rows.size(),"failures":failures,"output":output}))
 await game.finish_exit(0 if failures.is_empty() else 1)
