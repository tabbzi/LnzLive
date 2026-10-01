extends Reference
class_name PaintballLayerData
## PaintballLayerData.gd
## A single layer containing pending paintballs for paintball mode

export var name: String = ""
export var visible: bool = true
export var layer_id: int = 0

var paintballs: Array = []
var _next_id: int = 0
var _paintball_uid_counter: int = 0


func _init(
	name: String = "",
	visible: bool = true,
	layer_id: int = 0):
	self.name = name
	self.visible = visible
	self.layer_id = layer_id
	paintballs = []


func add_paintball(pb_data: Dictionary) -> int:
	if not pb_data.has("_pb_uid") or pb_data["_pb_uid"] <= 0:
		pb_data["_pb_uid"] = PaintballLayerManager.allocate_paintball_uid()
	paintballs.append(pb_data.duplicate(true))
	return pb_data["_pb_uid"]


func remove_paintball_by_uid(uid: int) -> bool:
	for i in range(paintballs.size()):
		if paintballs[i].get("_pb_uid", -1) == uid:
			paintballs.remove(i)
			return true
	return false


func remove_paintball(index: int) -> bool:
	if index >= 0 and index < paintballs.size():
		paintballs.remove(index)
		return true
	return false


func clear_paintballs() -> void:
	paintballs.clear()


func get_paintball_count() -> int:
	return paintballs.size()


func has_paintballs() -> bool:
	return paintballs.size() > 0
