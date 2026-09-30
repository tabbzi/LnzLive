extends Reference
class_name PaintballLayerData
## PaintballLayerData.gd
## A single layer containing pending paintballs for paintball mode

export var name: String = ""
export var paintballs: Array = []
export var visible: bool = true
export var layer_id: int = 0

var _next_id: int = 0


func _init(
	name: String = "",
	visible: bool = true,
	layer_id: int = 0):
	self.name = name
	self.visible = visible
	self.layer_id = layer_id


func add_paintball(pb_data: Dictionary) -> void:
	paintballs.append(pb_data.duplicate(true))


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
