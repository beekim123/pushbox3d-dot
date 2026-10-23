extends SceneTree

const VARIANTS := {
	"baseline": {"key":0.36,"ambient":0.18,"fill":0.05,"exposure":0.8,"pitch":-54.0,"yaw":-32.0,"sky_mix":0.0,"ambient_color":"d7e7ff","fill_color":"b7d2ff","tone":Environment.TONE_MAPPER_LINEAR},
	"daylight": {"key":0.60,"ambient":0.15,"fill":0.055,"exposure":0.90,"pitch":-48.0,"yaw":-32.0,"sky_mix":0.22,"ambient_color":"d7e7ff","fill_color":"b7d2ff","tone":Environment.TONE_MAPPER_LINEAR},
	"softbox": {"key":0.76,"ambient":0.12,"fill":0.085,"exposure":0.94,"pitch":-44.0,"yaw":-38.0,"sky_mix":0.30,"ambient_color":"d7e7ff","fill_color":"c3dded","tone":Environment.TONE_MAPPER_LINEAR},
	"filmic": {"key":0.84,"ambient":0.16,"fill":0.075,"exposure":1.08,"pitch":-48.0,"yaw":-32.0,"sky_mix":0.22,"ambient_color":"d7e7ff","fill_color":"b7d2ff","tone":Environment.TONE_MAPPER_FILMIC}
}
const BACKDROPS := {"hub":"65758a","heaven":"73998e","inferno":"62576e","rainforest":"527f79","city":"708c9b","confluence":"73788f"}
var game: Node
var args: Dictionary={}
var records: Array=[]
var errors: Array=[]

func _initialize() -> void:
	for item in OS.get_cmdline_user_args():
		var bits:=str(item).trim_prefix("--").split("=",true,1)
		args[bits[0]]=bits[1] if bits.size()>1 else true
	call_deferred("run")

func freeze_animations(node: Node) -> void:
	if node is AnimationPlayer:
		if node.current_animation!="":
			node.seek(0.0,true)
			node.pause()
	for child in node.get_children(): freeze_animations(child)

func apply_variant(id: String) -> void:
	var p: Dictionary=VARIANTS[id]
	var world=game.world
	var env: Environment=world.environment.environment
	var ok: bool=is_equal_approx(env.ambient_light_energy,float(p.ambient)) and is_equal_approx(env.tonemap_exposure,float(p.exposure)) and env.tonemap_mode==p.tone
	ok=ok and is_equal_approx(world.light.light_energy,float(p.key)) and is_equal_approx(world.light.rotation_degrees.x,float(p.pitch)) and is_equal_approx(world.light.rotation_degrees.y,float(p.yaw))
	var expected: Color=world.THEMES[world.current_world].sky.lerp(Color(BACKDROPS[world.current_world]),float(p.sky_mix))
	ok=ok and env.background_color.is_equal_approx(expected)
	for node in world.find_children("","DirectionalLight3D",true,false):
		if node!=world.light: ok=ok and is_equal_approx(node.light_energy,float(p.fill)) and node.light_color.is_equal_approx(Color(p.fill_color))
	if not ok:
		errors.append("Production parameters differ from approved candidate "+world.current_world)
		push_error(str(errors[-1]))
	print("PRODUCTION_PARAMETERS ",world.current_world," matches=",ok)

func xy(p: Vector2) -> Array: return [snappedf(p.x,0.01),snappedf(p.y,0.01)]
func markers() -> Dictionary:
	var out: Dictionary={"paving":[],"crates":[],"goals":[]}
	if game.mode!="level": return out
	var level: Dictionary=game.level
	var state: Dictionary=game.state
	var walls=game.RULES.cells(level.walls)
	var specials=game.RULES.cells(level.goals)+game.RULES.cells(level.get("glide",[]))+game.RULES.cells(level.get("plates",[]))+game.RULES.cells(level.get("gates",[]))
	for pair in level.get("portals",[]): specials+=game.RULES.cells(pair)
	for arrow in level.get("arrows",[]): specials.append(game.RULES.cell(arrow.cell))
	for y in range(int(level.height)):
		for x in range(int(level.width)):
			var p:=Vector2i(x,y)
			if p in walls or p in specials or p in state.crates or p==state.player: continue
			for dx in [-0.45,0.45]:
				for dz in [-0.45,0.45]:
					out.paving.append(xy(game.world.camera.unproject_position(game.world.grid_pos(p)+Vector3(dx,0.03,dz))))
	for p in state.crates:
		out.crates.append(xy(game.world.camera.unproject_position(game.world.grid_pos(p)+Vector3(0,0.55,0))))
	for p in game.RULES.cells(level.goals):
		out.goals.append(xy(game.world.camera.unproject_position(game.world.grid_pos(p)+Vector3(0,0.13,0))))
	return out

func sample(id: String, world_id: String, output: String) -> void:
	apply_variant(id)
	for i in range(8): await process_frame
	var frame_ms: Array=[]
	var previous:=Time.get_ticks_usec()
	for i in range(30):
		await RenderingServer.frame_post_draw
		var now:=Time.get_ticks_usec()
		frame_ms.append(float(now-previous)/1000.0)
		previous=now
	frame_ms.sort()
	var image:=root.get_texture().get_image()
	var repeats:=records.filter(func(r): return r.world==world_id and r.variant==id).size()
	var filename:=world_id+"_"+id+("_"+str(repeats+1) if repeats>0 else "")+".png"
	var result:=image.save_png(output+"/"+filename)
	var cam: Camera3D=game.world.camera
	var entry: Dictionary={"world":world_id,"variant":id,"level":game.level.get("id","hub"),"image":filename,"image_size":[image.get_width(),image.get_height()],"result":result,"markers":markers(),"frame_ms_median":frame_ms[15],"frame_ms_p95":frame_ms[28],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"memory_render":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"camera_size":cam.size,"camera_transform":str(cam.global_transform),"geometry_bounds":str(cam.get_meta("fit_bounds",Rect2())),"missing_assets":game.world.missing_assets.keys(),"parameters":VARIANTS[id]}
	records.append(entry)
	if result!=OK or not game.world.missing_assets.is_empty(): errors.append(world_id+"/"+id+" capture or assets")
	print("LOOKDEV_CAPTURE ",world_id," ",id," median_ms=",entry.frame_ms_median," draw_calls=",entry.draw_calls," output=",output+"/"+filename)
	var f:=FileAccess.open(output+"/capture_metrics.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"viewport":[root.size.x,root.size.y],"quality":"high","errors":errors,"records":records},"\t"))

func run() -> void:
	root.size=Vector2i(1440,900)
	Engine.max_fps=0
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_process_unhandled_key_input(false)
	# QA is mandatory: never load/save a primary progress file.
	if not game.qa_mode:
		push_error("Lookdev must be launched with --qa")
		quit(2)
		return
	game.low_quality=false
	game.apply_quality()
	if game.music: game.music.stop()
	if game.ambience: game.ambience.stop()
	var output:=str(args.get("lookdev-output","res://../results"))
	DirAccess.make_dir_recursive_absolute(output)
	var worlds:=str(args.get("lookdev-worlds","heaven,inferno,rainforest,city,hub,confluence")).split(",")
	var variants:=str(args.get("lookdev-variants","baseline,daylight,softbox,filmic")).split(",")
	for world_id in worlds:
		if world_id=="hub": game.show_hub()
		else:
			var index:=int(args.get("lookdev-level",9))
			if world_id=="confluence": index=0
			game.start_level(game.levels_by_world[world_id][index])
		freeze_animations(game.world)
		await process_frame
		for id in variants: await sample(id,world_id,output)
	print("LOOKDEV_COMPLETE captures=",records.size()," errors=",errors)
	await game.finish_exit(0 if errors.is_empty() else 1)
