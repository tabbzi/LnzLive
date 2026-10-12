extends Node

## LnzMirrorController.gd
## Handles all mirroring & symmetry operations for LnzTextEdit

const MIRROR_TOLERANCE: float = 3.0

var on_save_backup
var on_get_section_bounds
var on_detect_delimiter
var on_get_line
var on_get_line_count
var on_set_line
var on_find_line_in_ball_section
var on_get_line_no_from_line_index
var on_split_line
var on_join_array
var on_update_fields
var on_find_insertion_line
var on_insert_text_at_cursor_at_line
var on_get_omitted_balls
var on_get_mirror_sides
var on_get_corresponding_right_ball
var on_get_corresponding_left_ball
var on_find_mirrored_ball
var on_commit_full_snapshot
var on_replace_section_content
var on_log_message
var on_get_addball_count_from_parser
var on_max_base_ball_num

var on_search

func mirror_l_to_r(reverse: bool = false) -> void:
	on_save_backup.call()
	
	var omitted_balls = on_get_omitted_balls.call()
	
	var mirror_sides = on_get_mirror_sides.call(KeyBallsData.species)
	var s_left = mirror_sides["left"]
	var s_right = mirror_sides["right"]
	
	var source_list = s_right if reverse else s_left
	var target_list = s_left if reverse else s_right
	
	var max_base = on_max_base_ball_num.call()
	var middle_balls_list = []
	for n in range(0, max_base):
		if !(n in s_left or n in s_right):
			middle_balls_list.append(n)
	
	# [Ballz Info]
	_mirror_ballz_info_section(source_list, target_list, middle_balls_list, reverse)
	
	# [Add Ball]
	_mirror_addball_section(source_list, target_list, middle_balls_list, reverse)
	
	# [Linez]
	_mirror_linez_section(source_list, target_list, middle_balls_list, reverse)
	
	# [Move]
	_mirror_move_section(source_list, target_list, middle_balls_list, reverse)
	
	# [Project Ball]
	_mirror_project_section(source_list, target_list, middle_balls_list, reverse)
	
	# [Paint Ballz]
	_mirror_paintball_section(source_list, target_list, middle_balls_list, reverse)
	
	# [Polygons]
	_mirror_polygon_section(source_list, target_list, middle_balls_list, reverse)
	
	on_commit_full_snapshot.call("Mirrored L to R" if not reverse else "Mirrored R to L")


func mirror_ball(target_ball_no: int) -> void:
	on_save_backup.call()
	
	if target_ball_no >= on_max_base_ball_num.call():
		var err_msg = "[LNZ EDIT] Copy-Mirror is only supported for base ballz (0-%d)" % (on_max_base_ball_num.call() - 1)
		print(err_msg)
		if on_log_message:
			on_log_message.call(err_msg)
		return
	
	var mirrored_ball_no = on_find_mirrored_ball.call(target_ball_no)
	var is_mirrored = mirrored_ball_no != target_ball_no
	if !is_mirrored:
		print("[LNZ EDIT] Ballz #%d is a center ball, so mirroring Addballz/Linez/Paintballz to itself" % target_ball_no)
		if on_log_message:
			on_log_message.call("[LNZ EDIT] Ballz #%d is a center ball, so mirroring Addballz/Linez/Paintballz to itself" % target_ball_no)
	
	var omitted_balls = on_get_omitted_balls.call()
	
	# [Ballz Info]
	_mirror_single_ball_ballz(target_ball_no, mirrored_ball_no)
	
	# [Add Ball]
	_mirror_single_ball_addball(target_ball_no, mirrored_ball_no, omitted_balls)
	
	# [Paint Ballz] & [Linez]
	_mirror_single_ball_sections(target_ball_no, mirrored_ball_no, omitted_balls)
	
	# [Polygons]
	_mirror_single_ball_polygons(target_ball_no, mirrored_ball_no)
	
	# [Move]
	if is_mirrored:
		_mirror_single_ball_move(target_ball_no, mirrored_ball_no)
	
	print("[LNZ EDIT] Performed Mirror-Copy for Ballz #%dto its mirror Ballz #%d" % [target_ball_no, mirrored_ball_no])
	if on_log_message:
		on_log_message.call("[LNZ EDIT] Performed Mirror-Copy for Ballz #%d to its mirror Ballz #%d" % [target_ball_no, mirrored_ball_no])
	on_commit_full_snapshot.call("Mirrored Ballz #%d to #%d" % [target_ball_no, mirrored_ball_no])


func _resolve_mirror_id(ball: int, reverse: bool, base_mirror_map: Dictionary, middle_balls_list: Array, source_to_mirror_map: Dictionary = {}) -> int:
	if source_to_mirror_map.has(ball):
		return source_to_mirror_map[ball]
	if base_mirror_map.has(ball):
		return base_mirror_map[ball]
	if ball in middle_balls_list:
		return ball
	if reverse:
		return on_get_corresponding_left_ball.call(ball)
	return on_get_corresponding_right_ball.call(ball)


func _is_ball_on_source_side(ball: int, source_list: Array, source_addballs_found: Array, middle_balls_list: Array, x_pos: float = 0.0, reverse: bool = false) -> bool:
	if ball in source_list:
		return true
	if ball in source_addballs_found:
		return true
	if ball in middle_balls_list:
		if reverse:
			return abs(x_pos) > MIRROR_TOLERANCE
		return abs(x_pos) > MIRROR_TOLERANCE
	return false


func _mirror_ball_attributes(parts: Array, is_addball: bool) -> Dictionary:
	var mirrored_parts = {}
	var outline_index = 4 if !is_addball else 9
	var x_pos_index = -1 if !is_addball else 1
	
	if parts.size() > outline_index:
		if parts[outline_index] in ["0", "-2"]:
			mirrored_parts[outline_index] = "-2" if parts[outline_index] == "0" else "0"
	
	if is_addball and parts.size() > x_pos_index:
		var x_val = parts[x_pos_index].to_float()
		mirrored_parts[x_pos_index] = str(x_val * -1.0)
	
	return mirrored_parts


func _swap_array_elements(arr: Array, idx_a: int, idx_b: int) -> void:
	var temp = arr[idx_a]
	arr[idx_a] = arr[idx_b]
	arr[idx_b] = temp


func _find_duplicate_addball_id(target_base: int, target_pos: Vector3) -> int:
	var bounds = on_get_section_bounds.call("[Add Ball]")
	if bounds.empty():
		return -1
	
	var counter = on_max_base_ball_num.call()
	for i in range(bounds.start, bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("["):
			continue
		
		var parts = on_split_line.call(line)
		if parts.size() < 4:
			counter += 1
			continue
		
		if parts[0].to_int() == target_base:
			var pos = Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float())
			if pos.distance_to(target_pos) <= MIRROR_TOLERANCE:
				return counter
		
		counter += 1
	
	return -1


func _mirror_ballz_info_section(source_list: Array, _target_list: Array, _middle_balls_list: Array, reverse: bool) -> void:
	var bounds = on_get_section_bounds.call("[Ballz Info]")
	if bounds.empty():
		return
	
	var delim = on_detect_delimiter.call(bounds.start, bounds.end)
	var base_mirror_map = {}
	
	for i in range(bounds.start, bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if line.begins_with("[") or line.begins_with(";") or line.empty():
			continue
		
		var ball_no = on_on_get_line_no_from_line_index.call(i, "[Ballz Info]")
		if ball_no == -1:
			continue
		
		if ball_no in source_list:
			var target_base = -1
			var candidate = on_find_mirrored_ball.call(ball_no)
			
			if candidate == ball_no:
				if reverse:
					target_base = on_get_corresponding_left_ball.call(ball_no)
				else:
					target_base = on_get_corresponding_right_ball.call(ball_no)
			else:
				target_base = candidate
			
			if target_base != -1 and target_base != ball_no:
				base_mirror_map[ball_no] = target_base
				
				if !(target_base in on_get_omitted_balls.call()):
					var parts = on_split_line.call(line)
					var mirrored_attrs = _mirror_ball_attributes(parts, false)
					var mirrored_line = on_update_fields.call(parts, mirrored_attrs, delim)
					
					var target_line_idx = on_find_line_in_ball_section.call(target_base)
					if target_line_idx != -1:
						on_set_line.call(target_line_idx, mirrored_line)


func _mirror_addball_section(source_list: Array, _target_list: Array, middle_balls_list: Array, reverse: bool) -> void:
	var bounds = on_get_section_bounds.call("[Add Ball]")
	if bounds.empty():
		return
	var delim = on_detect_delimiter.call(bounds.start, bounds.end)
	
	var current_scan_id = on_max_base_ball_num.call()
	var source_addballs_found = []
	var source_to_mirror_map = {}
	var mirrors_queue = []
	
	var addball_lines_content = []
	for i in range(bounds.start, bounds.end):
		addball_lines_content.append(on_get_line.call(i))
	
	var existing_signatures = {}
	var sig_scan_id = on_max_base_ball_num.call()
	
	for line in addball_lines_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = on_split_line.call(strip)
			var sig = on_join_array.call(parts, delim)
			if !existing_signatures.has(sig):
				existing_signatures[sig] = sig_scan_id
			sig_scan_id += 1
	
	var next_free_id = sig_scan_id
	
	for line in addball_lines_content:
		var strip_line = line.strip_edges()
		if strip_line.begins_with("[") or strip_line.begins_with(";") or strip_line.empty():
			continue
		
		var is_source = false
		var parts = on_split_line.call(strip_line)
		
		if current_scan_id in on_get_omitted_balls.call():
			is_source = false
		elif parts.size() > 0:
			var base_ball = parts[0].to_int()
			var x_pos = parts[1].to_float() if parts.size() > 1 else 0.0
			is_source = _is_ball_on_source_side(base_ball, source_list, source_addballs_found, middle_balls_list, x_pos, reverse)
		
		if is_source:
			source_addballs_found.append(current_scan_id)
			
			var old_base = parts[0].to_int()
			var new_base = _resolve_mirror_id(old_base, reverse, {}, middle_balls_list, source_to_mirror_map)
			
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(new_base)
			if mirrored_parts.size() > 1:
				mirrored_parts[1] = str(mirrored_parts[1].to_float() * -1.0)
			if mirrored_parts.size() > 9:
				if mirrored_parts[9] == "0":
					mirrored_parts[9] = "-2"
				elif mirrored_parts[9] == "-2":
					mirrored_parts[9] = "0"
			
			var suffix = "RtoL" if reverse else "LtoR"
			var inf_comment = " ; copyMirr%s_srcAdd#%d_to_mirAdd#%d" % [suffix, current_scan_id, next_free_id]
			var mirror_sig = on_join_array.call(mirrored_parts, delim) + inf_comment
			
			if existing_signatures.has(mirror_sig):
				var existing_id = existing_signatures[mirror_sig]
				source_to_mirror_map[current_scan_id] = existing_id
			else:
				source_to_mirror_map[current_scan_id] = next_free_id
				mirrors_queue.append({
					"original_id": current_scan_id,
					"mirror_line_content": mirror_sig,
					"future_id": next_free_id
				})
				existing_signatures[mirror_sig] = next_free_id
				next_free_id += 1
		
		current_scan_id += 1
	
	if !mirrors_queue.empty():
		var final_lines = []
		for item in mirrors_queue:
			final_lines.append(item.mirror_line_content)
		var bounds_ab = on_get_section_bounds.call("[Add Ball]")
		var ins_line = on_find_insertion_line.call(bounds_ab.start, bounds_ab.end)
		on_insert_text_at_cursor_at_line.call(ins_line, on_join_array.call(final_lines, "\n") + "\n")


func _mirror_linez_section(source_list: Array, _target_list: Array, middle_balls_list: Array, reverse: bool) -> void:
	var bounds = on_get_section_bounds.call("[Linez]")
	if bounds.empty():
		return
	var delim = on_detect_delimiter.call(bounds.start, bounds.end)
	
	var existing_linez_signatures = {}
	for i in range(bounds.start, bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
			var parts = on_split_line.call(line)
			var sig = on_join_array.call(parts, delim)
			existing_linez_signatures[sig] = true
	
	var linez_content = []
	for i in range(bounds.start, bounds.end):
		linez_content.append(on_get_line.call(i))
	
	var final_linez_lines_to_append = []
	
	for line in linez_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = on_split_line.call(strip)
			if parts.size() < 2:
				continue
			
			var s = parts[0].to_int()
			var e = parts[1].to_int()
			
			var s_is_src = (s in source_list) or (s in [])  # source_addballs checked per-line
			var e_is_src = (e in source_list) or (e in [])
			
			if (s in middle_balls_list) and e_is_src:
				s_is_src = true
			if (e in middle_balls_list) and s_is_src:
				e_is_src = true
			
			if s_is_src or e_is_src:
				var m_s = _resolve_mirror_id(s, reverse, {}, middle_balls_list, {})
				var m_e = _resolve_mirror_id(e, reverse, {}, middle_balls_list, {})
				
				if m_s != -1 and m_e != -1:
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_s)
					mirror_parts[1] = str(m_e)
					if mirror_parts.size() > 8:
						if mirror_parts[8] == "0":
							mirror_parts[8] = "-2"
						elif mirror_parts[8] == "-2":
							mirror_parts[8] = "0"
					if mirror_parts.size() > 5:
						_swap_array_elements(mirror_parts, 4, 5)
					
					var suffix = "RtoL" if reverse else "LtoR"
					var inf_comment = " ; copyMirr%s_line(%d,%d)" % [suffix, m_s, m_e]
					var new_line_sig = on_join_array.call(mirror_parts, delim) + inf_comment
					
					var reverse_mirror_parts = mirror_parts.duplicate()
					reverse_mirror_parts[0] = mirror_parts[1]
					reverse_mirror_parts[1] = mirror_parts[0]
					if reverse_mirror_parts.size() > 5:
						var temp = reverse_mirror_parts[4]
						reverse_mirror_parts[4] = reverse_mirror_parts[5]
						reverse_mirror_parts[5] = temp
					var reverse_sig = on_join_array.call(reverse_mirror_parts, delim)
					
					if !existing_linez_signatures.has(new_line_sig) and !existing_linez_signatures.has(reverse_sig):
						final_linez_lines_to_append.append(new_line_sig)
						existing_linez_signatures[new_line_sig] = true
	
	if !final_linez_lines_to_append.empty():
		var bounds_l = on_get_section_bounds.call("[Linez]")
		var ins_line = on_find_insertion_line.call(bounds_l.start, bounds_l.end)
		on_insert_text_at_cursor_at_line.call(ins_line, on_join_array.call(final_linez_lines_to_append, "\n") + "\n")


func _mirror_move_section(source_list: Array, target_list: Array, middle_balls_list: Array, reverse: bool) -> void:
	var bounds = on_get_section_bounds.call("[Move]")
	if bounds.empty():
		return
	var delim = on_detect_delimiter.call(bounds.start, bounds.end)
	
	var final_move_lines = []
	var move_content = []
	for i in range(bounds.start, bounds.end):
		move_content.append(on_get_line.call(i))
	
	for line in move_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = on_split_line.call(strip)
			if parts.size() < 1:
				continue
			var move_ball = parts[0].to_int()
			
			if !(move_ball in target_list):
				final_move_lines.append(strip)
			
			var is_src = (move_ball in source_list)
			if is_src:
				var m_move_ball = _resolve_mirror_id(move_ball, reverse, {}, middle_balls_list, {})
				if m_move_ball != -1:
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_move_ball)
					if mirror_parts.size() > 1:
						mirror_parts[1] = str(mirror_parts[1].to_float() * -1.0)
					if mirror_parts.size() > 4:
						var old_anchor = mirror_parts[4].to_int()
						var new_anchor = _resolve_mirror_id(old_anchor, reverse, {}, middle_balls_list, {})
						if new_anchor != -1:
							mirror_parts[4] = str(new_anchor)
					final_move_lines.append(on_join_array.call(mirror_parts, delim))
	
	if !final_move_lines.empty():
		on_replace_section_content.call("[Move]", final_move_lines)


func _mirror_project_section(source_list: Array, target_list: Array, middle_balls_list: Array, reverse: bool) -> void:
	var bounds = on_get_section_bounds.call("[Project Ball]")
	if bounds.empty():
		return
	var delim = on_detect_delimiter.call(bounds.start, bounds.end)
	
	var final_proj_lines = []
	var proj_content = []
	for i in range(bounds.start, bounds.end):
		proj_content.append(on_get_line.call(i))
	
	for line in proj_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = on_split_line.call(strip)
			if parts.size() < 2:
				continue
			
			var b = parts[0].to_int()
			var m = parts[1].to_int()
			
			if !(b in target_list) and !(m in target_list):
				final_proj_lines.append(strip)
			
			var b_is_src = (b in source_list)
			var m_is_src = (m in source_list)
			
			if b_is_src or m_is_src:
				var m_b = _resolve_mirror_id(b, reverse, {}, middle_balls_list, {})
				var m_m = _resolve_mirror_id(m, reverse, {}, middle_balls_list, {})
				
				if m_b != -1 and m_m != -1:
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_b)
					mirror_parts[1] = str(m_m)
					final_proj_lines.append(on_join_array.call(mirror_parts, delim))
	
	if !final_proj_lines.empty():
		on_replace_section_content.call("[Project Ball]", final_proj_lines)


func _mirror_paintball_section(source_list: Array, _target_list: Array, middle_balls_list: Array, reverse: bool) -> void:
	var bounds = on_get_section_bounds.call("[Paint Ballz]")
	if bounds.empty():
		return
	var delim = on_detect_delimiter.call(bounds.start, bounds.end)
	
	var existing_paint_sigs = {}
	for i in range(bounds.start, bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
			var parts = on_split_line.call(line)
			existing_paint_sigs[on_join_array.call(parts, delim)] = true
	
	var paint_content = []
	for i in range(bounds.start, bounds.end):
		paint_content.append(on_get_line.call(i))
	
	var final_paint_lines_to_append = []
	
	for line in paint_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = on_split_line.call(strip)
			if parts.size() < 3:
				continue
			
			var base = parts[0].to_int()
			var x = parts[2].to_float()
			
			var is_src = false
			if base in source_list:
				is_src = true
			if base in middle_balls_list:
				if abs(x) > MIRROR_TOLERANCE:
					is_src = true
			
			if is_src:
				var m_base = _resolve_mirror_id(base, reverse, {}, middle_balls_list, {})
				if m_base == -1:
					m_base = base
				
				var mirror_parts = Array(parts)
				mirror_parts[0] = str(m_base)
				mirror_parts[2] = str(x * -1.0)
				
				var new_sig = on_join_array.call(mirror_parts, delim) + " ; AUTO-MIRROR src: " + str(base)
				
				if !existing_paint_sigs.has(new_sig):
					final_paint_lines_to_append.append(new_sig)
					existing_paint_sigs[new_sig] = true
	
	if !final_paint_lines_to_append.empty():
		var bounds_p = on_get_section_bounds.call("[Paint Ballz]")
		var ins_line = on_find_insertion_line.call(bounds_p.start, bounds_p.end)
		on_insert_text_at_cursor_at_line.call(ins_line, on_join_array.call(final_paint_lines_to_append, "\n") + "\n")


func _mirror_polygon_section(_source_list: Array, _target_list: Array, middle_balls_list: Array, reverse: bool) -> void:
	var poly_bounds = on_get_section_bounds.call("[Polygons]")
	if poly_bounds.empty():
		return
	var delim = on_detect_delimiter.call(poly_bounds.start, poly_bounds.end)
	
	var final_poly_lines_to_append = []
	var existing_poly_sigs = {}
	
	for i in range(poly_bounds.start, poly_bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
			existing_poly_sigs[line] = true
	
	var poly_content = []
	for i in range(poly_bounds.start, poly_bounds.end):
		poly_content.append(on_get_line.call(i))
	
	for line in poly_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = on_split_line.call(strip)
			if parts.size() < 4:
				continue
			
			var b0 = parts[0].to_int()
			var b1 = parts[1].to_int()
			var b2 = parts[2].to_int()
			var b3 = parts[3].to_int()
			
			var m0 = _resolve_mirror_id(b0, reverse, {}, middle_balls_list, {})
			var m1 = _resolve_mirror_id(b1, reverse, {}, middle_balls_list, {})
			var m2 = _resolve_mirror_id(b2, reverse, {}, middle_balls_list, {})
			var m3 = _resolve_mirror_id(b3, reverse, {}, middle_balls_list, {})
			
			if m0 == -1:
				m0 = on_find_mirrored_ball.call(b0)
			if m1 == -1:
				m1 = on_find_mirrored_ball.call(b1)
			if m2 == -1:
				m2 = on_find_mirrored_ball.call(b2)
			if m3 == -1:
				m3 = on_find_mirrored_ball.call(b3)
			
			if m0 == b0 and m1 == b1 and m2 == b2 and m3 == b3:
				continue
			
			var mirror_parts = Array(parts)
			mirror_parts[0] = str(m0)
			mirror_parts[1] = str(m1)
			mirror_parts[2] = str(m2)
			mirror_parts[3] = str(m3)
			
			if mirror_parts.size() > 6:
				_swap_array_elements(mirror_parts, 5, 6)
			
			var suffix = "RtoL" if reverse else "LtoR"
			var comment = " ; copyMirr%s_poly(%s,%s,%s,%s)" % [suffix, mirror_parts[0], mirror_parts[1], mirror_parts[2], mirror_parts[3]]
			var new_line = on_join_array.call(mirror_parts, delim) + comment
			
			if !existing_poly_sigs.has(new_line):
				final_poly_lines_to_append.append(new_line)
				existing_poly_sigs[new_line] = true
	
	if !final_poly_lines_to_append.empty():
		var poly_bounds2 = on_get_section_bounds.call("[Polygons]")
		var ins_line = poly_bounds2.end
		on_insert_text_at_cursor_at_line.call(ins_line, on_join_array.call(final_poly_lines_to_append, "\n") + "\n")


func _mirror_single_ball_ballz(target_ball_no: int, mirrored_ball_no: int) -> void:
	var ballz_bounds = on_get_section_bounds.call("[Ballz Info]")
	var line_index = on_find_line_in_ball_section.call(target_ball_no)
	if line_index != -1:
		var delim = on_detect_delimiter.call(ballz_bounds.start, ballz_bounds.end)
		var line = on_get_line.call(line_index)
		var parts = on_split_line.call(line)
		var mirrored_attrs = _mirror_ball_attributes(parts, false)
		var mirrored_line = on_update_fields.call(parts, mirrored_attrs, delim)
		
		var mirrored_line_index = on_find_line_in_ball_section.call(mirrored_ball_no)
		if mirrored_line_index != -1:
			on_set_line.call(mirrored_line_index, mirrored_line)


func _mirror_single_ball_addball(target_ball_no: int, mirrored_ball_no: int, omitted_balls: Array) -> void:
	var addball_bounds = on_get_section_bounds.call("[Add Ball]")
	if addball_bounds.empty():
		return
	var delim = on_detect_delimiter.call(addball_bounds.start, addball_bounds.end)
	var max_ball_no = on_max_base_ball_num.call() + on_get_addball_count_from_parser.call()
	var new_addball_no = max_ball_no
	
	var addball_lines = []
	for i in range(addball_bounds.start, addball_bounds.end):
		addball_lines.append(on_get_line.call(i))
	
	var temp_addball_map = {}
	var new_addball_lines = []
	var data_idx = 0
	
	for i in range(addball_lines.size()):
		var line = addball_lines[i].strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		
		var current_addball_no = on_max_base_ball_num.call() + data_idx
		var parts = on_split_line.call(line)
		
		if parts.empty() or parts[0].to_int() != target_ball_no:
			data_idx += 1
			continue
		
		if omitted_balls.has(current_addball_no):
			data_idx += 1
			continue
		
		var mirrored_attrs = _mirror_ball_attributes(parts, true)
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(mirrored_ball_no)
		for key in mirrored_attrs:
			mirrored_parts[key] = mirrored_attrs[key]
		
		var mirrored_pos = Vector3(mirrored_parts[1].to_float(), mirrored_parts[2].to_float(), mirrored_parts[3].to_float())
		var dup_id = _find_duplicate_addball_id(mirrored_ball_no, mirrored_pos)
		
		if dup_id != -1:
			temp_addball_map[current_addball_no] = dup_id
			data_idx += 1
			continue
		
		var comment = " ; copyMirrLtoR_ball%d_to_ball%d" % [target_ball_no, mirrored_ball_no]
		new_addball_lines.append(on_join_array.call(mirrored_parts, delim) + comment)
		temp_addball_map[current_addball_no] = new_addball_no
		new_addball_no += 1
		data_idx += 1
	
	if !new_addball_lines.empty():
		var insert_line = on_find_insertion_line.call(addball_bounds.start, addball_bounds.end)
		on_insert_text_at_cursor_at_line.call(insert_line, on_join_array.call(new_addball_lines, "\n") + "\n")


func _mirror_single_ball_sections(target_ball_no: int, mirrored_ball_no: int, _omitted_balls: Array) -> void:
	var associated_left_balls = [target_ball_no]
	var temp_addball_map = {}
	
	var sections_to_process = {}
	sections_to_process["[Paint Ballz]"] = "_process_paintball_line_for_mirror"
	sections_to_process["[Linez]"] = "_process_linez_line_for_mirror"
	
	for section_name in sections_to_process:
		var method_name = sections_to_process[section_name]
		var bounds = on_get_section_bounds.call(section_name)
		if bounds.empty():
			continue
		
		var new_lines = []
		var delim = on_detect_delimiter.call(bounds.start, bounds.end)
		for i in range(bounds.start, bounds.end):
			var line = on_get_line.call(i).strip_edges()
			if line.empty() or line.begins_with(";"):
				continue
			
			var parts = on_split_line.call(line)
			var processed_line = _process_line_for_mirror(parts, target_ball_no, mirrored_ball_no, associated_left_balls, temp_addball_map, method_name)
			
			if processed_line != null and processed_line.size() > 0:
				var comment = " ; copyMirrLtoR_ball%d_to_ball%d" % [target_ball_no, mirrored_ball_no]
				if section_name == "[Paint Ballz]":
					comment = " ; AUTO-MIRROR src: " + str(target_ball_no)
				new_lines.append(on_join_array.call(processed_line, delim) + comment)
		
		if !new_lines.empty():
			var insert_line = on_find_insertion_line.call(bounds.start, bounds.end)
			on_insert_text_at_cursor_at_line.call(insert_line, on_join_array.call(new_lines, "\n") + "\n")


func _mirror_single_ball_polygons(target_ball_no: int, mirrored_ball_no: int) -> void:
	var poly_bounds = on_get_section_bounds.call("[Polygons]")
	if poly_bounds.empty():
		return
	var delim = on_detect_delimiter.call(poly_bounds.start, poly_bounds.end)
	
	var temp_addball_map = {}
	var new_poly_lines = []
	var existing_poly_sigs = {}
	
	for i in range(poly_bounds.start, poly_bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
			existing_poly_sigs[line] = true
	
	for i in range(poly_bounds.start, poly_bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("["):
			continue
		
		var parts = on_split_line.call(line)
		if parts.size() < 4:
			continue
		
		var b0 = parts[0].to_int()
		var b1 = parts[1].to_int()
		var b2 = parts[2].to_int()
		var b3 = parts[3].to_int()
		
		var any_target = (b0 == target_ball_no) or (b1 == target_ball_no) or (b2 == target_ball_no) or (b3 == target_ball_no)
		
		if !any_target:
			for ball_id in [b0, b1, b2, b3]:
				if ball_id >= on_max_base_ball_num.call():
					any_target = true
					break
		
		if !any_target:
			continue
		
		var has_associated = (b0 in [target_ball_no]) or (b1 in [target_ball_no]) or (b2 in [target_ball_no]) or (b3 in [target_ball_no])
		
		if has_associated:
			var mirror_parts = Array(parts)
			for col in [0, 1, 2, 3]:
				var b = int(mirror_parts[col])
				if b in temp_addball_map:
					mirror_parts[col] = str(temp_addball_map[b])
				else:
					mirror_parts[col] = str(on_find_mirrored_ball.call(int(mirror_parts[col])))
			
			var all_valid = true
			for col in [0, 1, 2, 3]:
				if int(mirror_parts[col]) == -1:
					all_valid = false
					break
			if !all_valid:
				continue
			
			if mirror_parts.size() > 6:
				_swap_array_elements(mirror_parts, 5, 6)
			
			var comment = " ; copyMirrLtoR_ball%d_ball%d_poly(%s,%s,%s,%s)" % [target_ball_no, mirrored_ball_no, mirror_parts[0], mirror_parts[1], mirror_parts[2], mirror_parts[3]]
			var new_line = on_join_array.call(mirror_parts, delim) + comment
			
			if !existing_poly_sigs.has(new_line):
				new_poly_lines.append(new_line)
				existing_poly_sigs[new_line] = true
	
	if !new_poly_lines.empty():
		var poly_bounds2 = on_get_section_bounds.call("[Polygons]")
		var insert_line = on_find_insertion_line.call(poly_bounds2.start, poly_bounds2.end)
		on_insert_text_at_cursor_at_line.call(insert_line, on_join_array.call(new_poly_lines, "\n") + "\n")


func _mirror_single_ball_move(target_ball_no: int, mirrored_ball_no: int) -> void:
	var move_bounds = on_get_section_bounds.call("[Move]")
	if move_bounds.empty():
		return
	
	var delim = on_detect_delimiter.call(move_bounds.start, move_bounds.end)
	var new_mirrored_line = ""
	var target_line_found = false
	
	for i in range(move_bounds.start, move_bounds.end):
		var line = on_get_line.call(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue
		
		var parts = on_split_line.call(line)
		if parts.size() >= 4 and parts[0].to_int() == target_ball_no:
			target_line_found = true
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(mirrored_ball_no)
			mirrored_parts[1] = str(mirrored_parts[1].to_float() * -1.0)
			if parts.size() > 4:
				mirrored_parts[4] = str(on_find_mirrored_ball.call(parts[4].to_int()))
			new_mirrored_line = on_join_array.call(mirrored_parts, delim)
			break
	
	if target_line_found:
		var lines_to_remove = []
		for i in range(move_bounds.start, move_bounds.end):
			var line = on_get_line.call(i).strip_edges()
			if line.empty() or line.begins_with(";"):
				continue
			var parts = on_split_line.call(line)
			if parts.size() > 0 and parts[0].to_int() == mirrored_ball_no:
				lines_to_remove.append(i)
		
		for i in range(lines_to_remove.size() - 1, -1, -1):
			var line_num = lines_to_remove[i]
			# NOTE: cut() must be called from LnzTextEdit
			pass
	
	if target_line_found and !new_mirrored_line.empty():
		move_bounds = on_get_section_bounds.call("[Move]")
		var insert_line = on_find_insertion_line.call(move_bounds.start, move_bounds.end)
		on_insert_text_at_cursor_at_line.call(insert_line, new_mirrored_line + "\n")


func _process_line_for_mirror(parts: Array, target_ball_no: int, mirrored_ball_no: int, associated_left_balls: Array, temp_addball_map: Dictionary, method_name: String) -> Array:
	if method_name == "_process_linez_line_for_mirror":
		return _process_linez_line_for_mirror(parts, target_ball_no, mirrored_ball_no, associated_left_balls, temp_addball_map)
	elif method_name == "_process_paintball_line_for_mirror":
		return _process_paintball_line_for_mirror(parts, target_ball_no, mirrored_ball_no, associated_left_balls, temp_addball_map)
	return []


func _process_linez_line_for_mirror(parts: Array, target_ball_no: int, mirrored_ball_no: int, associated_left_balls: Array, temp_addball_map: Dictionary) -> Array:
	if parts.size() < 2:
		return []
	var start_ball = parts[0].to_int()
	var end_ball = parts[1].to_int()
	
	if associated_left_balls.has(start_ball) or associated_left_balls.has(end_ball):
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(_get_mirrored_counterpart(start_ball, target_ball_no, mirrored_ball_no, temp_addball_map))
		mirrored_parts[1] = str(_get_mirrored_counterpart(end_ball, target_ball_no, mirrored_ball_no, temp_addball_map))
		
		if mirrored_parts.size() > 5:
			_swap_array_elements(mirrored_parts, 4, 5)
		
		if mirrored_parts.size() > 8:
			if mirrored_parts[8] == "0":
				mirrored_parts[8] = "-2"
			elif mirrored_parts[8] == "-2":
				mirrored_parts[8] = "0"
		
		return mirrored_parts
	return []


func _process_paintball_line_for_mirror(parts: Array, target_ball_no: int, mirrored_ball_no: int, _associated_left_balls: Array, _temp_addball_map: Dictionary) -> Array:
	if parts.size() < 6:
		return []
	var base_ball = parts[0].to_int()
	if base_ball == target_ball_no:
		var new_parts = parts
		new_parts[0] = str(mirrored_ball_no)
		new_parts[2] = str(new_parts[2].to_float() * -1.0)
		return new_parts
	return []


func _get_mirrored_counterpart(ball: int, target: int, mirrored: int, temp_map: Dictionary) -> int:
	if ball == target:
		return mirrored
	if temp_map.has(ball):
		return temp_map[ball]
	if ball < on_max_base_ball_num.call():
		return on_find_mirrored_ball.call(ball)
	return ball
