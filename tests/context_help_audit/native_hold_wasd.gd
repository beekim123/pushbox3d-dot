extends SceneTree
# Observes native CUA/X11 input only; never calls Input.parse_input_event.
var game
var monitor
var begun:=0
var finishing:=false
class Observer extends Node:
 var audit
 var events: Array=[]
 var samples: Array=[]
 var last_sample:=0
 func _input(e: InputEvent):
  if e is InputEventKey:
   events.append({"ms":Time.get_ticks_msec()-audit.begun,"keycode":e.keycode,"physical_keycode":e.physical_keycode,"pressed":e.pressed,"echo":e.echo,"a_held":Input.is_physical_key_pressed(KEY_A),"moves":audit.game.state.moves,"help":audit.game.modal!=null and audit.game.modal.get_meta("contextual_help",false)})
   if e.keycode==KEY_F12 and e.pressed and not e.echo:audit.finish.call_deferred()
 func _process(_delta):
  if Time.get_ticks_msec()-last_sample<40:return
  last_sample=Time.get_ticks_msec()
  samples.append({"ms":last_sample-audit.begun,"a_held":Input.is_physical_key_pressed(KEY_A),"moves":audit.game.state.moves,"help":audit.game.modal!=null and audit.game.modal.get_meta("contextual_help",false),"guard":audit.game.help_release_keys.has(KEY_A)})
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
 game.start_level(game.levels_by_world.heaven[2]);game.show_help()
 begun=Time.get_ticks_msec();monitor=Observer.new();monitor.audit=self;root.add_child(monitor)
 var ready:=FileAccess.open("res://tests/context_help_audit/native_hold_wasd_ready.json",FileAccess.WRITE)
 ready.store_string(JSON.stringify({"ready":true,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"initial_moves":game.state.moves,"help_open":true}))
 print("NATIVE_HOLD_READY: use CUA A+Escape held 1200ms, then fresh A, then F12")
func finish():
 if finishing:return
 finishing=true
 await process_frame
 var failures: Array=[]
 var presses: Array=monitor.events.filter(func(e):return e.physical_keycode==KEY_A and e.pressed and not e.echo)
 var releases: Array=monitor.events.filter(func(e):return e.physical_keycode==KEY_A and not e.pressed)
 var escapes: Array=monitor.events.filter(func(e):return e.keycode==KEY_ESCAPE and e.pressed and not e.echo)
 var blocked: Array=monitor.samples.filter(func(s):return s.a_held and not s.help and s.guard and s.moves==0)
 var duration:=int(releases[0].ms)-int(presses[0].ms) if presses.size()>=1 and releases.size()>=1 else -1
 if DisplayServer.get_name()=="headless":failures.append("not a native display")
 if presses.size()!=2 or releases.size()!=2:failures.append("expected two real A presses and releases")
 if duration<1000:failures.append("first physical hold shorter than 1000ms")
 if escapes.size()!=1 or presses.is_empty() or releases.is_empty() or not (presses[0].ms<=escapes[0].ms and escapes[0].ms<releases[0].ms):failures.append("Escape did not close while first A was held")
 if blocked.size()<3 or int(blocked[-1].ms)-int(blocked[0].ms)<500:failures.append("no sustained native held interval after help dismissal")
 if monitor.samples.any(func(s):return s.ms<int(releases[0].ms) and s.moves!=0) if not releases.is_empty() else true:failures.append("movement leaked before first physical release")
 if game.state.moves!=1 or not game.help_release_keys.is_empty():failures.append("fresh physical press did not move exactly once / release guard remains")
 var echo_keys: Array=monitor.events.filter(func(e):return e.echo).map(func(e):return e.physical_keycode)
 var report={"passed":failures.is_empty(),"failures":failures,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"adapter":RenderingServer.get_video_adapter_name(),"source":"Native CUA App.pressKey X11 chord/held input; this observer never injects engine events","first_hold_ms":duration,"blocked_samples_after_help_close":blocked.size(),"native_echo_events":echo_keys.size(),"echo_physical_keycodes":echo_keys,"final_moves":game.state.moves,"events":monitor.events,"samples":monitor.samples}
 var file:=FileAccess.open("res://tests/context_help_audit/native_hold_wasd.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 print("NATIVE_HOLD_RESULT ",JSON.stringify({"passed":report.passed,"failures":failures,"first_hold_ms":duration,"blocked_samples":blocked.size(),"native_echo_events":echo_keys.size(),"final_moves":game.state.moves}))
 await game.finish_exit(0 if failures.is_empty() else 1)
