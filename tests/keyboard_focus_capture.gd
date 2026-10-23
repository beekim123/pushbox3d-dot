extends "res://tests/keyboard_navigation.gd"

var captures: Array=[]

func native_path(filename: String) -> String:
	var directory:=OS.get_environment("KEYBOARD_NATIVE_OUTPUT")
	if directory.is_empty(): directory="res://tests/keyboard_navigation/native_results"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return directory.path_join(filename)

func capture_focus(label: String):
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var owner: Control=root.gui_get_focus_owner()
	var path:=native_path(label+".png")
	var result:=root.get_texture().get_image().save_png(path)
	check(result==OK and is_instance_valid(owner),label+": native image saved with focused control")
	captures.append({"name":label,"path":path,"focus_action":focus_id(),"focus_rect":str(owner.get_global_rect()) if is_instance_valid(owner) else "none","mode":game.mode})
	print("KEYBOARD_CAPTURE ",label," ",focus_id())

func run():
	root.size=Vector2i(1440,900)
	Input.use_accumulated_input=false
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await capture_focus("title")
	await key(KEY_ENTER)
	await capture_focus("hub")
	for world in ["heaven","inferno","rainforest","city"]:
		game.show_world_menu(world,0)
		await capture_focus(world+"_level")
		await activate("chapter:next")
		await capture_focus(world+"_chapter")
	game.show_title()
	await settle()
	await activate("help")
	await capture_focus("help")
	game.start_level(game.levels_by_world.heaven[0])
	await key(KEY_RIGHT)
	await create_timer(.50).timeout
	await capture_focus("completion")
	game.initialize_resume("user://keyboard_capture_"+str(Time.get_ticks_usec()))
	game.resume_session.debounce_ms=0
	game.resume_session.interval_ms=0
	game.start_level(game.levels_by_world.heaven[1])
	await flush_resume()
	game.show_title()
	await capture_focus("continue")
	await key(KEY_SPACE)
	game.resume_session.debounce_ms=60000
	await key(KEY_LEFT)
	game.cancel_motion()
	game.resume_session.protect("keyboard_native_capture_failure")
	game.request_exit()
	game.poll_resume_exit()
	await capture_focus("failed_exit")
	await key(KEY_ESCAPE)
	game.progress.solved=game.levels.filter(func(entry): return entry.world!="confluence").map(func(entry): return entry.id)
	game.show_hub()
	await settle()
	await activate("world:confluence")
	await capture_focus("confluence")
	game.show_hub()
	game.show_ending()
	await capture_focus("ending")
	var report:={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"display_server":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"headless":DisplayServer.get_name()=="headless","captures":captures,"scope":"Native viewport captures with actual scoped focus; direct screen setup plus injected keyboard transitions. Separate independent manual keyboard-only workflow required."}
	var file:=FileAccess.open(native_path("capture_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("KEYBOARD_NATIVE_CAPTURE ",JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
