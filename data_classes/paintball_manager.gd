extends Reference
## paintball_manager.gd
## Stateless paintball manager for dog_generator.gd that handles creation, removal, and visuals for paintballz

var gen = null


func init(generator_node):
	gen = generator_node


func _create_paintball_instance(base_ball_node):
	var pb = gen.paintball_scene.instance()
	base_ball_node.add_child(pb)
	pb.set_owner(gen.get_root())
	pb.add_to_group("paintballs")
	return pb


func _setup_paintball_node(pb_visual_ball, pb_data, base_ball_node, pb_pos, pb_diameter, existing_count, list_size):
	var active_custom_palette = gen._resolve_custom_palette_for_lnz()
	var target_layer = 1
	var base_mesh = base_ball_node.get_node_or_null("MeshInstance")
	if base_mesh and base_mesh is VisualInstance:
		target_layer = base_mesh.layers

	var pb_mesh = pb_visual_ball.get_node_or_null("MeshInstance")
	if pb_mesh and pb_mesh is VisualInstance:
		pb_mesh.layers = target_layer

	var final_size = gen.snap_ball_size(base_ball_node.ball_size * (float(pb_diameter) / 100.0))
	pb_visual_ball.ball_size = final_size
	pb_visual_ball.transform.origin = pb_pos
	pb_visual_ball.set_surface_normal(pb_pos.normalized())

	pb_visual_ball.set_species(gen.lnz.species, gen.is_babyz_mode)
	pb_visual_ball.set_render_flat_colors(gen.render_flat_colors_global)
	pb_visual_ball.base_ball_no = base_ball_node.name.to_int()
	pb_visual_ball.base_ball_position = base_ball_node.global_transform.origin
	pb_visual_ball.base_ball_size = base_ball_node.ball_size
	pb_visual_ball.color_index = pb_data.color
	pb_visual_ball.outline_color_index = pb_data.outline_color
	pb_visual_ball.outline = pb_data.outline
	pb_visual_ball.group = pb_data.group
	pb_visual_ball.fuzz_amount = gen.fuzz_to_amount(pb_data.fuzz)
	pb_visual_ball.palette = base_ball_node.palette

	if pb_data.texture > -1:
		var tex_pb = gen._tex_mgr.load_texture_from_list(pb_data.texture, gen.lnz.texture_list, null, active_custom_palette, gen.is_babyz_mode)
		if tex_pb:
			pb_visual_ball.texture = tex_pb
			if pb_data.texture < gen.lnz.texture_list.size():
				pb_visual_ball.transparent_color = gen.lnz.texture_list[pb_data.texture].transparent_color
	else:
		print("[WARNING] Node: _setup_paintball_node: failed to load texture %d" % pb_data.texture)

	var base_z = base_ball_node.z_add if "z_add" in base_ball_node else 0.0
	pb_visual_ball.z_add = gen.base_z_offset(base_z) + float(existing_count) + float(list_size)

	return pb_visual_ball


func add_pending_paintball(paintball_info):
	PaintballLayerManager.ensure_default_layer()
	var active_layer = PaintballLayerManager.get_active_layer()
	if active_layer:
		active_layer.add_paintball(paintball_info)

	gen._pending_paintballs_data.append(paintball_info)
	var base_ball_node = gen.ball_map[paintball_info.base_ball_no]
	var pb_visual_ball = _create_paintball_instance(base_ball_node)

	var layer_id: int = PaintballLayerManager.active_layer_id if PaintballLayerManager.active_layer_id >= 0 else -1
	pb_visual_ball.paint_layer_id = layer_id
	pb_visual_ball.set_meta("pb_uid", paintball_info.get("_pb_uid", -1))

	var pb_data = {
		"color": paintball_info.color, "outline_color": paintball_info.outline_color,
		"outline": paintball_info.outline_type, "fuzz": paintball_info.fuzz,
		"texture": paintball_info.texture, "group": paintball_info.group
	}

	_setup_paintball_node(pb_visual_ball, pb_data, base_ball_node,
						paintball_info.relative_pos_local, paintball_info.diameter,
						gen.paintball_map.get(paintball_info.base_ball_no, []).size(),
						gen._pending_paintballs_data.size())

	if paintball_info.outline_type >= 0 and paintball_info.outline_color <= 0:
		pb_visual_ball.outline_color_index = get_layer_outline_color(layer_id)

	gen._pending_paintball_nodes.append(pb_visual_ball)


func remove_last_pending_paintball():
	print("[STATUS] Node: remove_last_pending_paintball: request received")
	var active_layer = PaintballLayerManager.get_active_layer()
	if not active_layer or active_layer.get_paintball_count() == 0:
		if gen._pending_paintballs_data.size() > 0 and gen._pending_paintball_nodes.size() > 0:
			var last_pb = gen._pending_paintballs_data[gen._pending_paintballs_data.size() - 1]
			var last_visual_node = gen._pending_paintball_nodes.pop_back()
			if is_instance_valid(last_visual_node):
				last_visual_node.queue_free()
				print("[STATUS] Node: remove_last_pending_paintball: visual node freed")
			gen._pending_paintballs_data.pop_back()
			return last_pb
		print("[WARNING] Node: remove_last_pending_paintball: no pending paintballs to remove")
		return null

	var last_pb = active_layer.paintballs[active_layer.paintballs.size() - 1]
	var uid: int = last_pb.get("_pb_uid", -1)
	active_layer.paintballs.pop_back()

	var node_to_remove = null
	for node in gen._pending_paintball_nodes:
		if not is_instance_valid(node):
			continue
		if node.has_meta("pb_uid") and node.get_meta("pb_uid") == uid:
			node_to_remove = node
			break

	if is_instance_valid(node_to_remove):
		var node_idx = gen._pending_paintball_nodes.find(node_to_remove)
		if node_idx != -1:
			gen._pending_paintball_nodes.remove(node_idx)
			if uid >= 0:
				for i in range(gen._pending_paintballs_data.size()):
					if gen._pending_paintballs_data[i].has("_pb_uid") and gen._pending_paintballs_data[i]["_pb_uid"] == uid:
						gen._pending_paintballs_data.remove(i)
						break
			node_to_remove.queue_free()
			print("[STATUS] Node: remove_last_pending_paintball: freed visual node for uid %d" % uid)
	else:
		print("[WARNING] Node: remove_last_pending_paintball: no visual node found for uid %d" % uid)
	print("[STATUS] Node: remove_last_pending_paintball: removed paintball, %d remaining on layer" % active_layer.get_paintball_count())
	return last_pb


func remove_paintball_by_uid(uid: int):
	if uid < 0:
		return
	if not is_instance_valid(PaintballLayerManager) or PaintballLayerManager.layers.empty():
		return
	for layer in PaintballLayerManager.layers:
		var idx: int = -1
		for i in range(layer.paintballs.size()):
			if layer.paintballs[i].get("_pb_uid", -1) == uid:
				idx = i
				break
		if idx >= 0:
			layer.paintballs.remove(idx)
			break

	var node_to_remove = null
	for node in gen._pending_paintball_nodes:
		if is_instance_valid(node) and node.has_meta("pb_uid") and node.get_meta("pb_uid") == uid:
			node_to_remove = node
			break

	if is_instance_valid(node_to_remove):
		var node_idx = gen._pending_paintball_nodes.find(node_to_remove)
		if node_idx != -1:
			gen._pending_paintball_nodes.remove(node_idx)
			node_to_remove.queue_free()

	for i in range(gen._pending_paintballs_data.size()):
		if gen._pending_paintballs_data[i].has("_pb_uid") and gen._pending_paintballs_data[i]["_pb_uid"] == uid:
			gen._pending_paintballs_data.remove(i)
			break


func remove_specific_pending_paintball(paintball_node):
	print("[STATUS] Node: remove_specific_pending_paintball: called for node %s" % paintball_node)
	var uid: int = -1
	if paintball_node.has_meta("pb_uid"):
		uid = paintball_node.get_meta("pb_uid")

	if uid >= 0:
		PaintballLayerManager.remove_paintball_by_uid(uid)

	var node_idx = gen._pending_paintball_nodes.find(paintball_node)
	if node_idx != -1:
		gen._pending_paintball_nodes.remove(node_idx)
		if uid >= 0:
			for i in range(gen._pending_paintballs_data.size()):
				if gen._pending_paintballs_data[i].has("_pb_uid") and gen._pending_paintballs_data[i]["_pb_uid"] == uid:
					gen._pending_paintballs_data.remove(i)
					break
		elif gen._pending_paintballs_data.size() > node_idx:
			gen._pending_paintballs_data.remove(node_idx)
		if is_instance_valid(paintball_node):
			paintball_node.queue_free()
			print("[STATUS] Node: remove_specific_pending_paintball: node freed")
	else:
		print("[WARNING] Node: remove_specific_pending_paintball: node not found in pending list")


func get_pending_paintballs_data():
	if is_instance_valid(PaintballLayerManager) and PaintballLayerManager.layers.size() > 0:
		var all_paintballs: Array = []
		for layer in PaintballLayerManager.layers:
			if not layer.visible:
				continue
			for pb in layer.paintballs:
				all_paintballs.append(pb)
		return all_paintballs
	return gen._pending_paintballs_data


func get_pending_paintball_nodes():
	return gen._pending_paintball_nodes


func clear_pending_paintballz():
	print("[STATUS] Node: clear_pending_paintballz: clearing %d paintballz" % gen._pending_paintball_nodes.size())
	_clear_paintball_list(gen._pending_paintball_nodes, gen._pending_paintballs_data)
	PaintballLayerManager.clear_all_paintballs()


func _clear_paintball_state_on_model_load():
	print("[STATUS] Node: _clear_paintball_state_on_model_load: clearing %d pending / %d auto"
		% [gen._pending_paintball_nodes.size(), gen._auto_paintball_nodes.size()])
	if is_instance_valid(PaintballLayerManager):
		PaintballLayerManager.clear_all_layers()
	for node in gen._pending_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	gen._pending_paintball_nodes.clear()
	gen._pending_paintballs_data.clear()
	for node in gen._auto_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	gen._auto_paintball_nodes.clear()
	gen._auto_paintballs_data.clear()


func clear_auto_paintballz():
	print("[STATUS] Node: clear_auto_paintballz: clearing %d paintballz" % gen._auto_paintball_nodes.size())
	_clear_paintball_list(gen._auto_paintball_nodes, gen._auto_paintballs_data)


func _on_randomize_auto_paintballz(paintballz):
	print("[STATUS] Node: _on_randomize_auto_paintballz: clearing and generating %d auto-paintballs" % paintballz.size())
	clear_auto_paintballz()
	gen._auto_paintballs_data = paintballz

	for pb_data in gen._auto_paintballs_data:
		var base_ball_node = gen.ball_map.get(pb_data.base)

		if not is_instance_valid(base_ball_node):
			print("[WARNING] Node: _on_randomize_auto_paintballz: base_ball_no %d not found or invalid" % pb_data.base)
			continue

		var pb_visual_ball = _create_paintball_instance(base_ball_node)

		var pb_pos = auto_paintball_world_offset(pb_data, base_ball_node)

		var adapter = make_paintball_adapter(pb_data)

		_setup_paintball_node(
			pb_visual_ball,
			adapter,
			base_ball_node,
			pb_pos,
			pb_data.size,
			gen.paintball_map.get(pb_data.base, []).size(),
			gen._auto_paintball_nodes.size()
		)

		gen._auto_paintball_nodes.append(pb_visual_ball)


func _on_apply_auto_paintballz():
	print("[STATUS] Node: _on_apply_auto_paintballz: attempting to apply auto paintballs")
	PaintballLayerManager.ensure_default_layer()
	var active_layer = PaintballLayerManager.get_active_layer()
	if active_layer and not active_layer.visible:
		active_layer.visible = true
	var processed_paintballs = {}
	var processed_count = 0
	var cap = 1000

	for pb_data in gen._auto_paintballs_data:
		if processed_count >= cap:
			print("[WARNING] Node: _on_apply_auto_paintballz: hit cap of %d auto paintballs" % cap)
			break

		var base_ball_node = gen.ball_map.get(pb_data.base)
		if not is_instance_valid(base_ball_node):
			continue

		var local_pos = auto_paintball_world_offset(pb_data, base_ball_node)

		var lnz_scale = gen.lnz.scales[0] / 255.0
		var relative_pos_lnz = local_pos / (gen.pixel_world_size * lnz_scale)
		relative_pos_lnz.y *= -1

		var key = hash([pb_data.base, relative_pos_lnz, pb_data.size])

		if processed_paintballs.has(key):
			continue

		processed_paintballs[key] = true

		var paintball_info = {
			"base_ball_no": pb_data.base,
			"relative_pos_local": local_pos,
			"relative_pos_lnz": relative_pos_lnz,
			"diameter": pb_data.size,
			"color": pb_data.color_index,
			"outline_color": pb_data.outline_color_index,
			"outline_type": pb_data.outline,
			"fuzz": pb_data.fuzz,
			"texture": pb_data.texture_id,
			"group": pb_data.group,
			"anchored": pb_data.anchored == 1
		}
		if active_layer:
			active_layer.add_paintball(paintball_info)
		gen._pending_paintballs_data.append(paintball_info)

		processed_count += 1

	print("[STATUS] Node: _on_apply_auto_paintballz: appended %d paintballs to pending queue" % processed_count)

	var lnz_text_edit = LnzLiveUtils.get_lnz_text_edit(gen.get_tree().root)
	if lnz_text_edit:
		print("[STATUS] Node: _on_apply_auto_paintballz: passing apply command to LnzTextEdit")
		lnz_text_edit.apply_paintballz()
	else:
		print("[ERROR] Node: _on_apply_auto_paintballz: could not locate LnzTextEdit node")

	clear_auto_paintballz()


func get_pending_paintball_nodes_for_layer(layer_id: int) -> Array:
	var result: Array = []
	for node in gen._pending_paintball_nodes:
		if not is_instance_valid(node):
			continue
		if "paint_layer_id" in node and node.paint_layer_id == layer_id:
			result.append(node)
	return result


func get_layer_outline_color(layer_id: int) -> int:
	var layer_colors: Array = [1, 165, 100, 130, 170]
	if layer_id < layer_colors.size():
		return layer_colors[layer_id]
	var offset: int = (layer_id - layer_colors.size()) % 100 + 100
	return offset


func rebuild_pending_paintball_visuals():
	for node in gen._pending_paintball_nodes:
		if is_instance_valid(node):
			node.queue_free()
	gen._pending_paintball_nodes.clear()

	var total_visible: int = 0
	for layer in PaintballLayerManager.layers:
		if layer.visible:
			total_visible += layer.get_paintball_count()

	var layer_offsets: Array = []
	var running_count: int = 0
	for layer in PaintballLayerManager.layers:
		if layer.visible:
			layer_offsets.append(running_count)
			running_count += layer.get_paintball_count()
		else:
			layer_offsets.append(-1)

	for layer in PaintballLayerManager.layers:
		if not layer.visible:
			continue
		var layer_idx: int = -1
		for li in range(PaintballLayerManager.layers.size()):
			if PaintballLayerManager.layers[li] == layer:
				layer_idx = li
				break
		var layer_pb_count: int = layer.get_paintball_count()
		for i in range(layer_pb_count):
			var pb_data = layer.paintballs[i]
			var base_ball_node = gen.ball_map.get(pb_data.base_ball_no)
			if not is_instance_valid(base_ball_node):
				continue

			var local_pos = pb_data.get("relative_pos_local", Vector3.ZERO)
			if local_pos == Vector3.ZERO and pb_data.has("relative_pos_lnz"):
				var engine_scale: float = 1.0
				if "lnz" in gen and is_instance_valid(gen.lnz):
					if "scales" in gen.lnz:
						engine_scale = gen.lnz.scales[0]
				local_pos = LnzLiveUtils.lnz_to_world_delta(pb_data["relative_pos_lnz"], gen.pixel_world_size, engine_scale)
				pb_data["relative_pos_local"] = local_pos

			var pb_visual = _create_paintball_instance(base_ball_node)
			pb_visual.paint_layer_id = layer.layer_id
			pb_visual.set_meta("pb_uid", pb_data.get("_pb_uid", -1))
			pb_visual.visible = layer.visible

			var pb_info_data = {
				"color": pb_data.color,
				"outline_color": pb_data.outline_color,
				"outline": pb_data.outline_type,
				"fuzz": pb_data.fuzz,
				"texture": pb_data.texture,
				"group": pb_data.group
			}

			var commit_output_index: int = layer_offsets[layer_idx] + (layer_pb_count - 1 - i)
			var z_add_value: int = total_visible - commit_output_index - 1
			_setup_paintball_node(
				pb_visual,
				pb_info_data,
				base_ball_node,
				pb_data.relative_pos_local,
				pb_data.diameter,
				gen.paintball_map.get(pb_data.base_ball_no, []).size(),
				z_add_value
			)

			if pb_data.outline_type >= 0 and pb_data.outline_color <= 0:
				pb_visual.outline_color_index = get_layer_outline_color(layer.layer_id)

			gen._pending_paintball_nodes.append(pb_visual)

	print("[STATUS] Node: rebuild_pending_paintball_visuals: rebuilt %d visual nodes from %d layers"
		% [gen._pending_paintball_nodes.size(), PaintballLayerManager.layers.size()])


func _clear_paintball_list(node_list: Array, data_list: Array):
	for node in node_list:
		if is_instance_valid(node):
			node.queue_free()
	node_list.clear()
	data_list.clear()


func auto_paintball_world_offset(pb_data, base_node):
	return pb_data.position * (base_node.ball_size / 2.0) * gen.pixel_world_size


func make_paintball_adapter(src):
	return {
		"color": src.color_index,
		"outline_color": src.outline_color_index,
		"outline": src.outline,
		"fuzz": src.fuzz,
		"texture": src.texture_id,
		"group": src.group
	}
