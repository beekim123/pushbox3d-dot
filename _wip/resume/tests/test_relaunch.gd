extends SceneTree
const Codec=preload("res://resume_codec.gd")
const Store=preload("res://resume_store.gd")
const Rules=preload("res://snapshot/puzzle_rules.gd")
const ROOT:="user://relaunch_cases"
var checks:=0
var failures: Array[String]=[]
var catalog: Dictionary={}
var solutions: Dictionary={}
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func finish(codec: RefCounted,id: int,revision: int = -1) -> Dictionary:
	var guard:=0
	while codec.poll().status=="running" and guard<100000: codec.step_budget(2,id,revision);guard+=1
	check(guard<100000,"bounded drain")
	return codec.take_result(id,revision)
func run() -> void:
	var mode: String=OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "invalid"
	check(mode in ["write","read"],"explicit process phase")
	var levels: Array=JSON.parse_string(FileAccess.get_file_as_string("res://snapshot/levels.json")).levels
	for level in levels: catalog[level.id]=level
	for report in JSON.parse_string(FileAccess.get_file_as_string("res://snapshot/resume_solutions.json")).levels: solutions[report.id]=report.solution
	var sentinel:="Original future progress version 299; never alter these bytes.\n".to_utf8_buffer()
	var progress:=ROOT+"/fourfold_progress.json"
	if mode=="write":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
		var f:=FileAccess.open(progress,FileAccess.WRITE);f.store_buffer(sentinel);f.close()
	for index in [0,50,100,150,203]:
		var level: Dictionary=levels[index]
		for kind in ["animation_committed","won","reset"]:
			var state: Dictionary=Rules.initial(level)
			var history: Array=[]
			var solution: String=solutions[level.id]
			var steps:=1 if kind=="animation_committed" else solution.length()
			for j in range(steps):
				history.append(state.duplicate(true));state=Rules.step(level,state,solution[j])
			if kind=="reset": history.append(state.duplicate(true));state=Rules.initial(level)
			var store:=Store.new(ROOT+"/"+level.id+"_"+kind)
			var codec:=Codec.new(Rules)
			if mode=="write":
				check(store.inspect().status=="missing","fresh isolated process slot")
				var encoded:=finish(codec,codec.begin_encode(level,state,history,19),19)
				check(store.commit(encoded,19).status=="saved","writer flushes stable logical state before exit")
			else:
				var inspected: Dictionary=store.inspect()
				check(inspected.status=="read" and not inspected.writable,"new process requires verification")
				var restored:=finish(codec,codec.begin_decode(inspected.bytes,catalog))
				check(restored.status=="restored","reader full replay")
				check(restored.state==state and restored.history==history,"cross-process exact dictionary state and full undo")
				check(not restored.resume_animation and restored.pending_direction=="","mid-animation checkpoint restores logical endpoint only")
				check(restored.won==Rules.won(level,state),"won state derived through replay, not trusted flag")
				check(store.accept_verified_load(restored).status=="authorized","new process authorizes validated original")
				if kind=="reset": check(Rules.won(level,restored.history.pop_back()),"undo-reset after relaunch returns completed puzzle")
				var undo: Array=restored.history
				var current: Dictionary=restored.state
				while not undo.is_empty(): current=undo.pop_back()
				check(current==Rules.initial(level),"all remaining undo snapshots survive process boundary")
	check(FileAccess.get_file_as_bytes(progress)==sentinel,"progress file untouched by either process")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"mode":mode,"pid":OS.get_process_id(),"godot":Engine.get_version_info()}
	var f:=FileAccess.open("res://results/relaunch_"+mode+".json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print("RESUME_RELAUNCH ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
