extends "res://tests/keyboard_navigation.gd"

func click(button: Button):
	var center:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=center
	motion.global_position=center
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var e:=InputEventMouseButton.new()
		e.button_index=MOUSE_BUTTON_LEFT
		e.position=center
		e.global_position=center
		e.pressed=pressed
		Input.parse_input_event(e)
		await process_frame
	await settle()

func run():
	root.size=Vector2i(1440,900)
	Input.use_accumulated_input=false
	Engine.max_fps=240
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	await click(game.find_focus_action(game.ui,"help"))
	check(focus_id()=="help:close","pointer opens Help with contained keyboard focus")
	await key(KEY_ENTER)
	check(game.modal==null and focus_id()=="help","keyboard closes pointer-opened Help to invoking control")
	await click(game.find_focus_action(game.ui,"hub"))
	check(game.mode=="hub" and focus_id()=="world:heaven","pointer title navigation assigns semantic hub focus")
	await click(game.find_focus_action(game.ui,"sound"))
	check(focus_id()=="sound","pointer can choose a different valid menu focus")
	var muted: bool=game.progress.muted
	await key(KEY_F1)
	await click(game.find_focus_action(game.ui,"sound"))
	check(game.progress.muted==muted and focus_id()=="help:close","modal blocks pointer and keyboard focus into background")
	await key(KEY_TAB,true)
	await key(KEY_SPACE)
	check(game.modal==null and focus_id()=="sound","modal keyboard dismissal restores previous pointer-selected control")
	await activate("world:heaven")
	var before:=snapshot()
	await click(game.find_focus_action(game.ui,"level:heaven_02"))
	check(game.mode=="world" and snapshot()==before and focus_id()=="level:heaven_01","locked level click cannot activate or steal keyboard focus")
	var removed: Button=root.gui_get_focus_owner()
	removed.queue_free()
	await settle()
	check(is_instance_valid(root.gui_get_focus_owner()) and focus_id()!="level:heaven_01","removed selected control gets valid fallback")
	await ring("removed selected action")
	# A same-frame rebuild cannot override newer valid focus selected externally.
	game.show_hub()
	game.find_focus_action(game.ui,"sound").grab_focus()
	await settle()
	check(focus_id()=="sound","generation deferred focus respects a newer valid owner")
	# A single held accept cannot close Help and activate reconstructed Next.
	for code in [KEY_ENTER,KEY_SPACE]:
		game.start_level(game.levels_by_world.heaven[0])
		await key(KEY_RIGHT)
		await create_timer(.35).timeout
		await key(KEY_F1)
		event(code,true)
		await settle()
		for i in range(3):
			event(code,true,false,true)
			await settle()
		event(code,false)
		await settle()
		check(game.level.id=="heaven_01" and focus_id()=="completion:next","held Help accept cannot auto-advance reconstructed completion: "+str(code))
		await key(code)
		check(game.level.id=="heaven_02" and root.gui_get_focus_owner()==null,"released/repressed Help accept may deliberately choose Next: "+str(code))
	var report:={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"scope":"Injected mouse motion/button and keyboard events; one explicit grab_focus fixture tests deferred owner precedence, not a claimed mouse event."}
	var file:=FileAccess.open(result_path("keyboard_mouse_races_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("KEYBOARD_MOUSE_RACES ",JSON.stringify(report))
	await game.finish_exit(0 if failures.is_empty() else 1)
