extends Node
## PaintballLayerManager.gd
## Autoload singleton that manages paintball layers for paintball mode
## Provides layer CRUD, active layer tracking, and signals for UI updates

signal layer_changed
signal layer_added
signal layer_removed
signal layer_cleared
signal layer_renamed
signal layer_visibility_toggled
signal layer_reordered

var layers: Array = []
var active_layer_id: int = -1
var next_layer_id: int = 1
var _next_pb_uid: int = 1


func create_layer(name: String = "") -> int:
	var new_id: int = next_layer_id
	next_layer_id += 1

	if name == "":
		name = "Layer " + str(new_id)

	var layer: PaintballLayerData = PaintballLayerData.new(name, true, new_id)
	layers.append(layer)

	active_layer_id = new_id
	print("[STATUS] PaintballLayerManager: created layer '%s' with id %d" % [name, new_id])

	emit_signal("layer_added", new_id)
	emit_signal("layer_changed", new_id)

	return new_id


func delete_layer(layer_id: int, merge_to_below: bool = false) -> bool:
	var idx: int = _get_layer_index(layer_id)
	if idx < 0:
		print("[WARNING] PaintballLayerManager: layer %d not found for deletion" % layer_id)
		return false

	var layer: PaintballLayerData = layers[idx]

	if merge_to_below and idx > 0:
		var target: PaintballLayerData = layers[idx - 1]
		for pb in layer.paintballs:
			target.paintballs.append(pb)
		print("[STATUS] PaintballLayerManager: merged %d paintballs from layer %d to layer below"
			% [layer.paintballs.size(), layer_id])

	if active_layer_id == layer_id:
		if layers.size() > 1:
			if idx > 0:
				active_layer_id = layers[idx - 1].layer_id
			else:
				active_layer_id = layers[1].layer_id
		else:
			active_layer_id = -1

	layers.remove(idx)

	print("[STATUS] PaintballLayerManager: deleted layer %d" % layer_id)

	emit_signal("layer_removed", layer_id)

	return true


func clear_layer(layer_id: int) -> void:
	var layer: PaintballLayerData = get_layer(layer_id)
	if layer:
		var count: int = layer.paintballs.size()
		layer.clear_paintballs()
		print("[STATUS] PaintballLayerManager: cleared %d paintballs from layer %d" % [count, layer_id])
		emit_signal("layer_cleared", layer_id)


func set_active_layer(layer_id: int) -> bool:
	var layer: PaintballLayerData = get_layer(layer_id)
	if not layer:
		print("[WARNING] PaintballLayerManager: cannot set active layer %d - not found" % layer_id)
		return false

	active_layer_id = layer_id
	print("[STATUS] PaintballLayerManager: active layer set to %d" % layer_id)

	emit_signal("layer_changed", layer_id)
	return true


func get_active_layer() -> PaintballLayerData:
	ensure_default_layer()
	for layer in layers:
		if layer.layer_id == active_layer_id:
			return layer
	return null


func ensure_default_layer() -> int:
	if layers.empty():
		create_layer("Layer 1")
		return layers[0].layer_id
	return active_layer_id


func get_layer(layer_id: int) -> PaintballLayerData:
	for layer in layers:
		if layer.layer_id == layer_id:
			return layer
	return null


func get_layer_index(layer_id: int) -> int:
	for i in range(layers.size()):
		if layers[i].layer_id == layer_id:
			return i
	return -1


func move_layer_up(layer_id: int) -> bool:
	var idx: int = _get_layer_index(layer_id)
	if idx <= 0:
		return false
	var temp: PaintballLayerData = layers[idx]
	layers[idx] = layers[idx - 1]
	layers[idx - 1] = temp
	print("[STATUS] PaintballLayerManager: moved layer %d up to index %d" % [layer_id, idx - 1])
	emit_signal("layer_reordered", idx, idx - 1)
	return true


func move_layer_down(layer_id: int) -> bool:
	var idx: int = _get_layer_index(layer_id)
	if idx < 0 or idx >= layers.size() - 1:
		return false
	var temp: PaintballLayerData = layers[idx]
	layers[idx] = layers[idx + 1]
	layers[idx + 1] = temp
	print("[STATUS] PaintballLayerManager: moved layer %d down to index %d" % [layer_id, idx + 1])
	emit_signal("layer_reordered", idx, idx + 1)
	return true


func rename_layer(layer_id: int, new_name: String) -> bool:
	var layer: PaintballLayerData = get_layer(layer_id)
	if not layer:
		return false
	layer.name = new_name
	print("[STATUS] PaintballLayerManager: renamed layer %d to '%s'" % [layer_id, new_name])
	emit_signal("layer_renamed", layer_id, new_name)
	return true


func toggle_layer_visibility(layer_id: int) -> void:
	var layer: PaintballLayerData = get_layer(layer_id)
	if layer:
		layer.visible = not layer.visible
		print("[STATUS] PaintballLayerManager: toggled visibility of layer %d to %s"
			% [layer_id, str(layer.visible)])
		emit_signal("layer_visibility_toggled", layer_id, layer.visible)


func get_total_paintball_count(visible_only: bool = true) -> int:
	var total: int = 0
	for layer in layers:
		if visible_only and not layer.visible:
			continue
		total += layer.get_paintball_count()
	return total


func get_active_layer_paintball_count() -> int:
	var layer: PaintballLayerData = get_active_layer()
	if layer:
		return layer.get_paintball_count()
	return 0


func clear_all_layers() -> void:
	for layer in layers:
		layer.clear_paintballs()
	print("[STATUS] PaintballLayerManager: cleared paintballs from all layers")


func clear_all_paintballs() -> void:
	for layer in layers:
		layer.clear_paintballs()
	print("[STATUS] PaintballLayerManager: cleared all paintballs (kept layer structure)")


func remove_paintball_by_uid(uid: int) -> bool:
	for layer in layers:
		if layer.remove_paintball_by_uid(uid):
			return true
	return false


func merge_layer_to_below(layer_id: int) -> bool:
	var idx: int = _get_layer_index(layer_id)
	if idx <= 0:
		print("[WARNING] PaintballLayerManager: layer %d has no layer below to merge to" % layer_id)
		return false

	var source: PaintballLayerData = layers[idx]
	var target: PaintballLayerData = layers[idx - 1]

	for pb in source.paintballs:
		target.paintballs.append(pb)

	print("[STATUS] PaintballLayerManager: merged %d paintballs from layer %d to layer %d"
		% [source.paintballs.size(), layer_id, target.layer_id])

	layers.remove(idx)

	if active_layer_id == layer_id:
		active_layer_id = target.layer_id

	emit_signal("layer_removed", layer_id)
	return true


func _get_layer_index(layer_id: int) -> int:
	for i in range(layers.size()):
		if layers[i].layer_id == layer_id:
			return i
	return -1


func allocate_paintball_uid() -> int:
	var uid: int = _next_pb_uid
	_next_pb_uid += 1
	return uid
