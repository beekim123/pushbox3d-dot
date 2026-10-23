extends SceneTree
const GAME=preload("res://scripts/main.gd")
var failures:Array=[]
var checks:=0
func check(value:bool,message:String)->void:
 checks+=1
 if not value: failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var output:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--audit-output="):output=arg.trim_prefix("--audit-output=")
 if output.is_empty():
  printerr("--audit-output=PATH is required")
  quit(2);return
 var game=GAME.new()
 root.add_child(game)
 await process_frame
 var records:Dictionary={}
 for world_name in ["heaven","inferno","rainforest","city"]:
  game.start_level(game.levels_by_world[world_name][0])
  await create_timer(0.12,true,false,true).timeout
  var stream=game.ambience.stream
  check(game.music.playing,world_name+" music playback")
  check(game.ambience.playing,world_name+" ambience playback")
  check(stream is AudioStreamOggVorbis,world_name+" Ogg stream")
  if stream is AudioStreamOggVorbis:
   check(stream.loop,world_name+" loop enabled by runtime")
   check(abs(stream.get_length()-16.0)<0.001,world_name+" 16-second duration")
   check(stream.resource_path.ends_with(world_name+"_ambient.ogg"),world_name+" correct resource")
   records[world_name]={"resource":stream.resource_path,"length":stream.get_length(),"loop":stream.loop,"playing":game.ambience.playing}
 game.show_hub()
 await create_timer(0.12,true,false,true).timeout
 check(game.music.playing,"hub music playback")
 check(not game.ambience.playing,"hub stops world ambience")
 var report={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"assets":records,"scope":"Actual game AudioStreamPlayer routing with headless audio enabled, then graceful finish_exit. Not subjective listening or a recorded bus mix."}
 var file=FileAccess.open(output,FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("AMBIENT_RUNTIME checks=",checks," failures=",failures)
 await game.finish_exit(0 if failures.is_empty() else 1)
