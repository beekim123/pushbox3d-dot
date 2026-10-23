extends Control
## UI-only annotations projected from the real board. Never owns gameplay state.
var view: Node3D
var answer: Dictionary={}
var tier:=0
const GOLD=Color("f6d68d")
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func point(cell: Vector2i, elevation: float=0.12) -> Vector2:
 return view.camera.unproject_position(view.grid_pos(cell)+Vector3(0,elevation,0))
func _draw() -> void:
 if not is_instance_valid(view) or answer.is_empty() or tier<2: return
 var box: Vector2i=answer.box
 var center:=point(box,0.75)
 draw_arc(center,23,0,TAU,40,Color(0.04,0.08,0.12,0.8),7,true)
 draw_arc(center,23,0,TAU,40,GOLD,3,true)
 var delta: Vector2i=answer.direction_vector
 var arrow_end:=point(box+delta,0.75)
 var direction: Vector2=(arrow_end-center).normalized()
 var start:=center+direction*27
 var tip:=center+direction*61
 draw_line(start,tip,Color(0.04,0.08,0.12,0.8),8,true)
 draw_line(start,tip,GOLD,4,true)
 draw_line(tip,tip-direction.rotated(0.55)*14,GOLD,4,true)
 draw_line(tip,tip-direction.rotated(-0.55)*14,GOLD,4,true)
 if tier<3: return
 var route: Array=answer.get("walk_path",[])
 var last: Vector2=point(answer.get("player",box))
 for cell in route:
  var next:=point(cell)
  draw_line(last,next,Color(0.05,0.12,0.14,0.85),7,true)
  draw_line(last,next,Color("baf4d2"),3,true)
  draw_circle(next,5,Color("baf4d2"))
  last=next
 var stand:=point(answer.stand_at)
 draw_arc(stand,11,0,TAU,24,Color("baf4d2"),3,true)
