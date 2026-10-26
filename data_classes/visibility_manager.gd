extends Reference
## visibility_manager.gd
## Stateless visibility manager for dog_generator.gd that handles visibility logic for ballz, linez, polygonz, and paintballz

var gen = null


func init(generator_node):
	gen = generator_node


func _should_ball_be_visible(ball_no: int, node) -> bool:
	if gen._hidden_balls.has(ball_no):
		return false
	if node.get("omitted") == true:
		return gen.draw_omitted_balls
	if gen._negative_balls.has(ball_no) and not gen.draw_negative_balls:
		return false
	if node.is_in_group("special_balls") and not gen.draw_special_balls:
		return false
	if node.is_in_group("addballs") and not gen.draw_addballs:
		return false
	if node.is_in_group("balls") and not gen.draw_balls:
		return false
	return true


func _should_line_be_visible(line_idx: int, node) -> bool:
	if gen._hidden_lines.has(line_idx):
		return false
	if node.is_in_group("special_balls") and not gen.draw_special_balls:
		return false
	if not gen.draw_lines:
		return false
	if gen.lnz and line_idx < gen.lnz.lines.size():
		var line_data = gen.lnz.lines[line_idx]
		for b_no in [line_data.start, line_data.end]:
			if gen.ball_map.has(b_no) and not _should_ball_be_visible(b_no, gen.ball_map[b_no]):
				return false
	return true


func _should_polygon_be_visible(poly_idx: int, node) -> bool:
	if gen._hidden_polygons.has(poly_idx):
		return false
	if node.is_in_group("special_balls") and not gen.draw_special_balls:
		return false
	if not gen.draw_polygons:
		return false
	if gen.lnz and poly_idx < gen.lnz.polygons.size():
		var poly = gen.lnz.polygons[poly_idx]
		for b_no in [poly.ball1, poly.ball2, poly.ball3, poly.ball4]:
			if gen.ball_map.has(b_no) and not _should_ball_be_visible(b_no, gen.ball_map[b_no]):
				return false
	return true


func _update_all_ball_visibility():
	for ball_no in gen.ball_map:
		var node = gen.ball_map[ball_no]
		if is_instance_valid(node) and node.is_inside_tree():
			var vis = _should_ball_be_visible(ball_no, node)
			node.visible_override = vis
			node.set_visible(vis)

			if gen.paintball_map.has(ball_no):
				for pb in gen.paintball_map[ball_no]:
					if is_instance_valid(pb):
						var pb_vis = vis and gen.draw_paintballs
						pb.visible_override = pb_vis
						pb.set_visible(pb_vis)

	for line_idx in gen.lines_map:
		var line = gen.lines_map[line_idx]
		if is_instance_valid(line):
			line.set_visible(_should_line_be_visible(line_idx, line))

	for poly_idx in gen.polygons_map:
		var poly = gen.polygons_map[poly_idx]
		if is_instance_valid(poly):
			poly.set_visible(_should_polygon_be_visible(poly_idx, poly))


func is_special_ball(_species: int, ball_no: int) -> bool:
	if gen.lnz != null and gen.lnz.addballs.has(ball_no):
		if gen.lnz.addballs[ball_no].add_group != 0:
			return true
	return false


func hide_ball(ball_no):
	if not gen._hidden_balls.has(ball_no):
		gen._hidden_balls.append(ball_no)
		gen.emit_signal("hidden_balls_changed", gen._hidden_balls.size())

	_apply_hidden_state_to_visuals(ball_no)


func unhide_all_balls():
	print("[STATUS] Node: unhide_all_balls: restoring %d balls" % gen._hidden_balls.size())
	gen._hidden_balls.clear()
	gen._hidden_lines.clear()
	gen._hidden_polygons.clear()
	gen._hidden_paintballs.clear()

	_apply_visibility_state(gen.ball_map, "set_hidden", false)
	_apply_visibility_state(gen.lines_map, "set_hidden", false)
	_apply_visibility_state(gen.polygons_map, "set_hidden", false)

	gen.emit_signal("hidden_balls_changed", 0)
	_update_all_ball_visibility()


func _apply_hidden_state_to_visuals(ball_no):
	if gen.ball_map.has(ball_no):
		var node = gen.ball_map[ball_no]
		if is_instance_valid(node) and node.has_method("set_hidden"):
			node.set_hidden(true)
	_update_all_ball_visibility()


func _restore_hidden_states():
	for ball_no in gen._hidden_balls:
		if gen.ball_map.has(ball_no):
			var node = gen.ball_map[ball_no]
			if is_instance_valid(node) and node.has_method("set_hidden"):
				node.set_hidden(true)
	_update_all_ball_visibility()


func _apply_visibility_state(node_map, method_name, state):
	for key in node_map:
		var node = node_map[key]
		if is_instance_valid(node) and node.has_method(method_name):
			node.call(method_name, state)


func _clear_hidden_state_lists():
	gen._hidden_balls.clear()
	gen._hidden_lines.clear()
	gen._hidden_polygons.clear()
	gen._hidden_paintballs.clear()
	gen._negative_balls.clear()

func is_hidden_ball(ball_no: int) -> bool:
	return gen._hidden_balls.has(ball_no)
