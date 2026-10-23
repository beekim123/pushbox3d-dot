extends SceneTree
var game
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 for entry in [{"world":"city","index":3,"file":"city_04"},{"world":"city","index":5,"file":"city_06"},{"world":"heaven","index":12,"file":"heaven_13"},{"world":"title","index":0,"file":"title_generic"}]:
  if entry.world=="title": game.show_title()
  else: game.start_level(game.levels_by_world[entry.world][entry.index])
  game.show_help()
  for frame in range(8): await process_frame
  await RenderingServer.frame_post_draw
  var screenshot=root.get_texture().get_image()
  var error=screenshot.save_png("res://screenshots/context_help/"+entry.file+".png")
  print("CONTEXT_HELP_CAPTURE ",entry.file," error=",error," size=",screenshot.get_size()," mode=",game.mode," state_moves=",game.state.get("moves",0))
 await game.finish_exit(0)
