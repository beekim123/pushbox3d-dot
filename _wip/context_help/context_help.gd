extends RefCounted
# Chapter exercises, not a solver, route prescription, or current-state answer.
const OBSERVATIONS := {
 "heaven_13": "本关观察：一只果篮能否成为另一只的挡停点？同时给它留出再推动的位置。",
 "city_04": "本关观察：这里的灯板不是目标。若让箱子压板，之后怎样把它移走并归位？"
}
static func text_for(mode: String, entry: Dictionary) -> String:
 if mode!="level" or entry.is_empty(): return ""
 if not entry.get("chapter_name") is String or not entry.get("learning_goal") is String: return ""
 var chapter:=str(entry.get("chapter_name","")).strip_edges()
 var goal:=str(entry.get("learning_goal","")).strip_edges()
 if chapter.is_empty() or goal.is_empty(): return ""
 if str(entry.get("world",""))=="confluence":
  goal="练习两种机制配合，先观察连接处的取位与退出空间。"
 var text:="本章练习 · "+chapter+"\n"+goal
 var observation: String=OBSERVATIONS.get(str(entry.get("id","")),"")
 if not observation.is_empty(): text+="\n"+observation
 return text
