extends SceneTree
# Use an isolated XDG_DATA_HOME when running this test. Never touches SAVE_PATH.
var game: Node
var failures: Array = []
var checks := 0
const TARGET := "user://qa_progress_roundtrip.json"
const ARCHIVE := "user://qa_progress_roundtrip_v1_archive.json"
func write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path,FileAccess.WRITE)
	assert(f != null)
	f.store_string(text)
	f.close()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func fresh() -> void:
	game.progress={"version":2,"solved":[],"best":{},"muted":false}
	game.progress_writable=true
func _initialize() -> void:
	game=load("res://scripts/main.gd").new()
	game.args={"test-integration":true}
	game.qa_mode=true
	game.load_levels()
	for path in [TARGET,ARCHIVE,"user://qa_progress_roundtrip_v1_archive_1.json"]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path): DirAccess.remove_absolute(path)
	var original="{\n  \"version\": 1, \"solved\": [\"heaven_01\"], \"best\": {}, \"muted\": true\n}\n"
	fresh();write_text(TARGET,original);game.load_progress()
	check(FileAccess.get_file_as_string(ARCHIVE)==original,"V1 archive must preserve exact bytes")
	check(game.progress.solved.is_empty() and game.progress.version==2,"Old IDs must not complete new V2 puzzles")
	check(game.progress.muted,"Mute setting must survive migration")
	check(JSON.parse_string(FileAccess.get_file_as_string(TARGET)).version==2,"Successful migration writes V2")
	var second=original.replace("true","false")
	fresh();write_text(TARGET,second);game.load_progress()
	check(FileAccess.get_file_as_string(ARCHIVE)==original,"Existing archive must not be overwritten")
	check(FileAccess.get_file_as_string("user://qa_progress_roundtrip_v1_archive_1.json")==second,"Different original gets numbered archive")
	var future="{\"version\":99,\"solved\":[],\"muted\":true}"
	fresh();write_text(TARGET,future);game.load_progress();game.save_progress()
	check(not game.progress_writable,"Unknown future format must be protected")
	check(FileAccess.get_file_as_string(TARGET)==future,"Unknown future bytes must survive save attempts")
	fresh();write_text(TARGET,"{broken");game.load_progress();game.save_progress()
	check(not game.progress_writable and FileAccess.get_file_as_string(TARGET)=="{broken","Malformed JSON must be protected")
	for invalid in [{"version":2,"solved":"wrong","best":{}},{"version":2,"solved":[],"best":[]}]:
		var raw=JSON.stringify(invalid)
		fresh();write_text(TARGET,raw);game.load_progress();game.save_progress()
		check(not game.progress_writable and FileAccess.get_file_as_string(TARGET)==raw,"Invalid V2 schema must be protected")
	var valid_id=str(game.levels[0].id)
	var mixed={"version":2,"solved":[valid_id,valid_id,"unknown"],"best":{}}
	mixed.best[valid_id]={"moves":12,"pushes":3}
	mixed.best["unknown"]={"moves":1,"pushes":1}
	fresh();write_text(TARGET,JSON.stringify(mixed));game.load_progress()
	check(game.progress.solved==[valid_id],"V2 completion IDs must be known and deduplicated")
	check(game.progress.best.size()==1 and game.progress.best[valid_id].moves==12,"V2 score records must filter unknown IDs")
	# A directory at the candidate backup filename forces copy failure.
	DirAccess.remove_absolute(ARCHIVE)
	DirAccess.make_dir_absolute(ARCHIVE)
	fresh();write_text(TARGET,original);game.load_progress();game.save_progress()
	check(not game.progress_writable,"Failed archive must disable writes")
	check(FileAccess.get_file_as_string(TARGET)==original,"Failed archive must retain original V1")
	DirAccess.remove_absolute(ARCHIVE)
	var output={"checks":checks,"failures":failures,"passed":failures.is_empty(),"engine":Engine.get_version_info().string,"scope":"Real load_progress/save_progress with isolated QA filename. Includes intentional archive-copy failure."}
	write_text("res://tests/save_migration_v2.json",JSON.stringify(output,"  "))
	print("V2_SAVE_AUDIT checks=",checks," failures=",failures)
	game.free()
	quit(0 if failures.is_empty() else 1)
