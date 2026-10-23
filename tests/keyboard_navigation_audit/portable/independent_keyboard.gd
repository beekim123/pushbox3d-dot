extends SceneTree

var app
var checks := 0
var failures: Array = []
var actions: Array = []
var saved_dir := ""

func _initialize(): call_deferred("audit")

func require(ok: bool, name: String):
	checks += 1
	if not ok:
		failures.append(name)
		print("INDEPENDENT_FAIL ", name)

func settle():
	await process_frame
	await process_frame
	await process_frame

func inject(k: Key, down: bool, shifted: bool=false, echoed: bool=false):
	var e := InputEventKey.new()
	e.keycode=k
	e.physical_keycode=k
	e.pressed=down
	e.shift_pressed=shifted
	e.echo=echoed
	Input.parse_input_event(e)

func press(k: Key, shifted: bool=false):
	inject(k,true,shifted)
	await process_frame
	inject(k,false,shifted)
	await settle()

func owner() -> Control: return root.gui_get_focus_owner()

func selected() -> String:
	return str(owner().get_meta("focus_action","")) if is_instance_valid(owner()) else ""

func button(id: String) -> Button:
	for b in app.ui.find_children("*","Button",true,false):
		if b.get_meta("focus_action","")==id: return b
	return null

func tab_to(id: String):
	var seen: Dictionary={}
	while selected()!=id and not seen.has(selected()):
		seen[selected()]=true
		await press(KEY_TAB)
	require(selected()==id,"native Tab reaches "+id)

func choose(id: String,k: Key=KEY_ENTER):
	await tab_to(id)
	if selected()==id:
		actions.append({"mode":app.mode,"action":id,"activation":k})
		await press(k)

func capture_state() -> Dictionary:
	return {"state":app.state.duplicate(true),"history":app.history.duplicate(true),"progress":app.progress.duplicate(true)}

func inspect_ring(label: String):
	var scope: Node=app.modal if is_instance_valid(app.modal) else app.ui
	var allowed: Array=scope.find_children("*","Button",true,false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)
	var first: Control=owner()
	var visited: Array=[]
	for i in range(allowed.size()):
		require(owner() in allowed,label+": current focus remains in enabled foreground scope "+str(i))
		visited.append(owner())
		await press(KEY_TAB)
	require(owner()==first and visited.size()==allowed.size() and allowed.all(func(b):return b in visited),label+": complete forward cycle contains all and only eligible controls")
	for i in range(allowed.size()): await press(KEY_TAB,true)
	require(owner()==first,label+": reverse cycle restores focus")
	for b in app.ui.find_children("*","Button",true,false):
		require(b.focus_mode==(Control.FOCUS_ALL if b in allowed else Control.FOCUS_NONE),label+": focus ownership "+b.text)

func flush_save():
	var start:=Time.get_ticks_msec()
	while app.resume_session.dirty and Time.get_ticks_msec()-start<5000:
		app.resume_session.tick(app.level,app.state,app.history,4.0,true)
		await process_frame
	require(not app.resume_session.dirty,"real isolated sidecar commits")

func held_close(k: Key, close_key: Key, label: String):
	var before:=capture_state()
	inject(k,true)
	await press(close_key)
	await create_timer(.28).timeout
	require(capture_state()==before and owner()==null,label+": held direction cannot leak into board")
	inject(k,false)
	await settle()

func audit():
	root.size=Vector2i(1440,900)
	Input.use_accumulated_input=false
	Engine.max_fps=240
	app=load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	# This first journey is entirely native keyboard input; no direct screen calls.
	require(app.mode=="title" and selected()=="hub","fresh title selects primary action")
	await inspect_ring("fresh title")
	await press(KEY_KP_ENTER)
	require(app.mode=="hub" and selected()=="world:heaven","native keypad Enter opens hub with Heaven selected")
	await inspect_ring("locked hub")
	require(button("world:confluence").disabled,"finale is genuinely locked")
	await press(KEY_SPACE)
	require(app.mode=="world" and selected()=="level:heaven_01","native Space opens Heaven with first unlocked puzzle selected")
	await press(KEY_ENTER)
	require(app.mode=="level" and app.level.id=="heaven_01" and owner()==null,"native Enter reaches puzzle with no HUD focus")
	var before:=capture_state()
	for k in [KEY_TAB,KEY_ENTER,KEY_SPACE,KEY_KP_ENTER]: await press(k)
	await press(KEY_TAB,true)
	require(capture_state()==before and owner()==null,"ordinary HUD cannot take focus or mutate via menu keys")
	await press(KEY_RIGHT)
	await create_timer(.35).timeout
	require(app.RULES.won(app.level,app.state) and selected()=="completion:next","native winning move produces focused Next")
	before=capture_state()
	await inspect_ring("completion")
	await press(KEY_F1)
	await inspect_ring("completion help")
	await press(KEY_F1)
	await press(KEY_F1)
	require(app.ui.find_children("*","CenterContainer",true,false).size()==1,"repeated F1 keeps one modal container")
	await press(KEY_SPACE)
	require(selected()=="completion:next" and capture_state()==before,"native help acknowledgment restores completion without state mutation")
	await held_close(KEY_LEFT,KEY_ESCAPE,"completion Escape")
	inject(KEY_LEFT,true)
	inject(KEY_LEFT,false)
	await create_timer(.30).timeout
	require(app.state.moves==int(before.state.moves)+1 and owner()==null,"release/repress after completion resumes exactly one movement")
	await press(KEY_R)
	await press(KEY_Z)
	require(app.RULES.won(app.level,app.state) and selected()=="completion:next","reset undo on won state reconciles completion focus")
	await press(KEY_SPACE)
	require(app.level.id=="heaven_02" and app.modal==null and owner()==null,"native Next opens second puzzle")
	await press(KEY_ESCAPE)
	require(selected()=="level:heaven_02","puzzle return restores selected level")
	await press(KEY_ESCAPE)
	require(selected()=="world:heaven","world return restores selected hub world")
	for w in ["inferno","rainforest","city"]:
		await choose("world:"+w,KEY_SPACE)
		require(selected()=="level:"+w+"_01",w+": initial unlocked puzzle focused")
		await press(KEY_ENTER)
		require(app.mode=="level" and app.level.id==w+"_01" and owner()==null,w+": keyboard-only puzzle entry")
		await press(KEY_ESCAPE)
		require(selected()=="level:"+w+"_01",w+": puzzle return focus")
		await press(KEY_ESCAPE)
		require(selected()=="world:"+w,w+": world return focus")
	await choose("help")
	await inspect_ring("hub help")
	await press(KEY_ESCAPE)
	require(selected()=="help","menu Help returns to invoking control")
	await choose("world:city")
	for page in range(1,10):
		await choose("chapter:next",KEY_SPACE)
		require(int(app.chapter_pages.city)==page,"native chapter next reaches "+str(page+1))
		require(selected()==("chapter:previous" if page==9 else "chapter:next"),"chapter next retains valid navigation focus "+str(page+1))
	await inspect_ring("last locked chapter")
	for page in range(8,-1,-1):
		await choose("chapter:previous",KEY_KP_ENTER)
		require(int(app.chapter_pages.city)==page,"native chapter previous reaches "+str(page+1))
	require(selected()=="level:city_01","first chapter boundary falls back to unlocked level")
	# Live availability/removal is independent of the candidate's internal arrays.
	var original: Button=owner()
	original.disabled=true
	await settle()
	require(owner()!=original and owner()!=null,"focused disabled control receives valid replacement")
	var retained: Control=owner()
	original.disabled=false
	await settle()
	require(owner()==retained,"reenabling old control does not steal focus")
	retained.hide()
	await settle()
	require(owner()!=retained and owner()!=null,"focused hidden control receives valid replacement")
	retained.show()
	await settle()
	var removed: Control=owner()
	removed.get_parent().remove_child(removed)
	removed.queue_free()
	await settle()
	require(owner()!=null and owner().is_inside_tree(),"removing focused control repairs stale candidate")
	# Same-frame rebuilds must focus only the surviving modal/screen.
	for w in ["heaven","city","inferno","rainforest"]:
		app.show_title()
		app.show_hub()
		app.show_world_menu(w,0)
		app.show_help()
		app.show_help()
		await settle()
		require(selected()=="help:close",w+": stale deferred jobs cannot escape newest modal")
		await press(KEY_ESCAPE)
		require(selected().begins_with("level:"+w),w+": help opened before deferred initial focus restores world primary")
	# Repeated native acceptance, including non-echo duplicate down, one screen only.
	for k in [KEY_ENTER,KEY_SPACE,KEY_KP_ENTER]:
		app.show_title()
		await settle()
		inject(k,true)
		await settle()
		for repeated in [true,false,true,false]:
			inject(k,true,false,repeated)
			await settle()
		inject(k,false)
		await settle()
		require(app.mode=="hub",str(k)+": held activation cannot chain through rebuilt screens")
		inject(k,true)
		inject(k,false)
		await settle()
		require(app.mode=="world",str(k)+": same-frame fresh activation works")
	# Held physical directions through Help; hints and undo are unaffected.
	for k in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_W,KEY_A,KEY_S,KEY_D]:
		app.start_level(app.levels_by_world.heaven[1])
		await settle()
		await press(KEY_F1)
		await held_close(k,KEY_ENTER,"Help "+str(k))
		before=capture_state()
		var direction: String={KEY_UP:"U",KEY_DOWN:"D",KEY_LEFT:"L",KEY_RIGHT:"R",KEY_W:"U",KEY_A:"L",KEY_S:"D",KEY_D:"R"}[k]
		var expected: Dictionary=app.RULES.step(app.level,app.state,direction)
		inject(k,true)
		inject(k,false)
		await settle()
		app.cancel_motion()
		require(not expected.is_empty() and app.state==expected and app.history.size()==before.history.size()+1,"Help "+str(k)+": release/repress accepts one normal action")
	before=capture_state()
	await press(KEY_H)
	await press(KEY_J)
	await create_timer(.15).timeout
	require(capture_state()==before and owner()==null,"optional hint search does not mutate or focus gameplay")
	await press(KEY_ESCAPE)
	require(app.mode=="level" and app.hint_panel==null,"Escape closes hint before leaving gameplay")
	await press(KEY_R)
	await press(KEY_Z)
	require(capture_state()==before,"unlimited undo semantics retain undoable reset")
	# Actual checkpoint write/load; async Continue addition must preserve owner.
	saved_dir="user://independent_keyboard_"+str(Time.get_ticks_usec())
	app.initialize_resume(saved_dir)
	app.resume_session.debounce_ms=0
	app.resume_session.interval_ms=0
	app.mark_resume_changed()
	await press(KEY_R)
	await flush_save()
	before=capture_state()
	app.initialize_resume("user://independent_keyboard_empty_"+str(Time.get_ticks_usec()))
	app.show_title()
	await settle()
	require(app.resume_button.disabled and selected()=="hub","missing Continue excluded with safe primary focus")
	await inspect_ring("disabled Continue")
	app.initialize_resume(saved_dir)
	app.refresh_resume_ui()
	require(app.resume_button.disabled,"reading Continue remains disabled")
	var began:=Time.get_ticks_msec()
	while app.resume_session.reading and Time.get_ticks_msec()-began<5000: await process_frame
	await settle()
	require(not app.resume_button.disabled and selected()=="hub","asynchronous verified Continue enables without stealing focus")
	await choose("continue",KEY_SPACE)
	require(app.mode=="level" and capture_state()==before and owner()==null,"native Continue restores exact full checkpoint")
	app.resume_session.debounce_ms=60000
	await press(KEY_Z)
	require(app.state.moves>0,"restored reset can be undone")
	app.resume_session.protect("independent_audit_failure")
	app.request_exit()
	require(app.exit_pending and not app.exit_waiting and owner()==null,"save-pending modal has no active choice")
	inject(KEY_ESCAPE,true)
	inject(KEY_ESCAPE,false)
	require(app.exit_pending,"Escape cannot cancel save-before-choice phase")
	app.poll_resume_exit()
	await settle()
	require(app.exit_waiting and selected()=="exit:return","failed save focuses safe Return")
	await inspect_ring("failed exit")
	before=capture_state()
	await press(KEY_ENTER)
	require(not app.exit_pending and app.modal==null and owner()==null and capture_state()==before,"native Enter Return works despite exit_pending without mutation")
	app.request_exit()
	app.poll_resume_exit()
	await settle()
	await press(KEY_TAB)
	require(selected()=="exit:unsaved","unsafe choice reachable only after deliberate navigation")
	await press(KEY_ESCAPE)
	require(not app.exit_pending and capture_state()==before,"Escape from unsafe selection still returns safely")
	# Ending/unlocked finale setup is explicit, not represented as played campaign.
	app.progress.solved=app.levels.filter(func(l):return l.world!="confluence").map(func(l):return l.id)
	app.show_hub()
	await settle()
	await choose("world:confluence",KEY_KP_ENTER)
	require(app.mode=="world" and app.active_world=="confluence" and selected().begins_with("level:confluence"),"unlocked finale enters through native keyboard")
	app.show_hub()
	app.show_ending()
	await settle()
	await inspect_ring("ending")
	await press(KEY_SPACE)
	require(app.modal==null and app.mode=="hub" and selected()!="","ending native Return restores hub scope")
	var report={"engine":Engine.get_version_info().string,"main_sha256":FileAccess.get_file_as_string("res://scripts/main.gd").sha256_text(),"independent_checks":checks,"failures":failures,"native_actions":actions,"scope":"Independent injected-key audit using actual Godot Button dispatch, not desktop/hardware keyboard proof. Initial title→hub→four worlds→levels uses injected keys only; later race/resume/finale scenarios use explicit setup. No author assertions counted. Headless, QA-isolated user saves; GUI visibility and actual unsaved exit have separate evidence."}
	var file:=FileAccess.open(OS.get_environment("KEYBOARD_AUDIT_OUT")+"/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("INDEPENDENT_KEYBOARD ",JSON.stringify({"checks":checks,"failures":failures}))
	await app.finish_exit(0 if failures.is_empty() else 1)
