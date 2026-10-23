extends "res://scripts/main.gd"
# Counter-only instrumentation. Every call delegates to the production method.
var audit_save_calls:=0
var audit_sfx: Array=[]
func save_progress() -> void:
 audit_save_calls+=1
 super.save_progress()
func sfx(name: String) -> void:
 audit_sfx.append(name)
 super.sfx(name)
