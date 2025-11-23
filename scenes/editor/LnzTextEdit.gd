extends TextEdit

# LnzTextEdit.gd – syncs the LNZ text file with the 3D pet editor
# - Loads and saves .lnz files
# - Creates automatic backups before overwriting
# - Preserves scroll and cursor positions across edits
# - Listens for visual editor events
# - Finds and updates the corresponding LNZ sections
# - Handles batch recolor and mirror‐copy operations
# - Emits signals for file_saved, file_backed_up, and find_ball actions

var is_user_file = false
var filepath: String
var r = RegEx.new()

signal file_saved(filepath)
signal find_ball(ball_no)
signal find_line(line_no)
signal find_paintball(line_no)
signal find_polygon(line_no)
signal find_move(line_no)
signal find_project_ball(line_no)
signal file_backed_up()

var min_font_size = 16

onready var apply_changes_button = get_node("../../../PetViewContainer/VBoxContainer/HelperContainer/VBoxContainer/ApplyChangesButton")

onready var find_panel = get_node("../FindPanel")

onready var frame_slider = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/FrameSlider"
) as HSlider

onready var camera_holder = get_tree().root.get_node(
	"Root/SceneRoot/ViewportContainer/Viewport/CameraHolder"
) as Spatial

func _ready():
	_setup_context_menu()

	wrap_enabled = false
	r.compile("[-.\\d]+")
	apply_changes_button.connect("pressed", self, "_on_ApplyChangesButton_pressed")
	
	add_color_region("[","]",Color(0.247119, 0.691406, 0.691406),false)
	add_color_region(";","",Color(0.168627, 0.45098, 0.45098),false)

	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var signals = [
		"ball_resized",
		"addball_created",
		"line_created"
		]
	for s in signals:
		if not pet_node.is_connected(s, self, "_on_Node_" + s):
			pet_node.connect(s, self, "_on_Node_" + s)

	var file_tree = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/Tree")
	if file_tree and not file_tree.is_connected("palette_selected", self, "_on_palette_selected"):
		file_tree.connect("palette_selected", self, "_on_palette_selected")
	if file_tree and not file_tree.is_connected("example_file_selected", self, "_on_example_file_selected"):
		file_tree.connect("example_file_selected", self, "_on_example_file_selected")

func _setup_context_menu():
    var menu = get_menu()
    
    if not menu.is_connected("id_pressed", self, "_on_menu_id_pressed"):
        menu.connect("id_pressed", self, "_on_menu_id_pressed")

    if menu.get_item_index(100) == -1:
        menu.add_item("Find/Replace", 100)
    
    if menu.get_item_index(101) == -1:
        menu.add_item("Toggle Comment", 101)

func _load_file(filepath: String, user_flag: bool):
	var file = File.new()
	file.open(filepath, File.READ)
	var contents = file.get_as_text()
	file.close()
	self.filepath = filepath
	is_user_file = user_flag
	_set_text_preserve(contents)

func _on_example_file_selected(filepath):
	_load_file(filepath, false)

func _on_user_file_selected(filepath):
	if filepath == null:
		return
	_load_file(filepath, true)

func _unhandled_key_input(event):
	if Input.is_key_pressed(KEY_CONTROL) and event.pressed and event.scancode == KEY_S:
		save_file()
	if Input.is_key_pressed(KEY_CONTROL) and event.pressed and event.scancode == KEY_F:
		find_panel.visible = !find_panel.visible
		self.readonly = find_panel.visible
		_setup_context_menu()

func _set_text_preserve(new_text: String):
	var old_v = get_v_scroll()
	var old_h = get_h_scroll()
	var old_l = cursor_get_line()
	var old_c = cursor_get_column()
	text = new_text
	set_v_scroll(old_v)
	set_h_scroll(old_h)
	cursor_set_line(old_l)
	cursor_set_column(old_c)

func _on_IncreaseFontButton_pressed():
	var font = get_font("font")
	if font:
		font.size += 2
		# Rerender to apply font changes
		_set_text_preserve(get_text())

func _on_DecreaseFontButton_pressed():
	var font = get_font("font")
	if font:
		font.size = max(min_font_size, font.size - 2)
		_set_text_preserve(get_text())

func _on_AutowrapButton_pressed():
	self.wrap_enabled = !self.wrap_enabled

	var button = get_node("../HBoxContainer/AutowrapButton")
	if self.wrap_enabled:
		button.text = "Wrap: On"
	else:
		button.text = "Wrap: Off"
	update() # Force a redraw just in case

func _on_FindReplaceButton_pressed():
	find_panel.visible = !find_panel.visible
	self.readonly = find_panel.visible
	_setup_context_menu()

func save_backup():
	if not is_user_file:
		return

	var dir = Directory.new()
	var base_path = filepath.trim_suffix(".lnz")
	var backup_path1 = base_path + "_backup_1.lnz"
	var backup_path2 = base_path + "_backup_2.lnz"
	var backup_path3 = base_path + "_backup_3.lnz"

	# Rotate backups: 2 -> 3, 1 -> 2
	if dir.file_exists(backup_path2):
		if dir.file_exists(backup_path3):
			dir.remove(backup_path3)
		dir.rename(backup_path2, backup_path3)

	if dir.file_exists(backup_path1):
		dir.rename(backup_path1, backup_path2)

	# Create new backup
	var file = File.new()
	file.open(backup_path1, File.WRITE)
	file.store_string(text)
	file.close()
	emit_signal("file_backed_up")

func save_file():
	if filepath == null or filepath.empty():
		var dir = Directory.new()
		var base_path = "user://resources/"
		dir.open("user://")
		dir.make_dir_recursive("resources") 
		
		var default_name = "unnamed.lnz"
		var possible_file_name = base_path + default_name
		var counter = 1
		
		while dir.file_exists(possible_file_name):
			possible_file_name = base_path + "unnamed_" + str(OS.get_unix_time()) + ".lnz"
			counter += 1
		
		filepath = possible_file_name
		is_user_file = true

	if is_user_file:
		var dir = Directory.new()
		dir.open("user://")
		dir.make_dir("resources")
		var file = File.new()
		file.open(filepath, File.WRITE)
		file.store_string(text)
		file.close()
	else:
		var dir = Directory.new()
		dir.open("user://")
		dir.make_dir("resources")
		var possible_file_name = filepath.replace("res://", "user://")
		var file = File.new()
		if file.file_exists(possible_file_name):
			possible_file_name = possible_file_name.replace(".lnz", str(OS.get_unix_time()) + ".lnz")
		file.open(possible_file_name, File.WRITE)
		file.store_string(text)
		file.close()
		filepath = possible_file_name
		is_user_file = true

	emit_signal("file_saved", filepath)
	_set_text_preserve(get_text())
	print("Saved LNZ and Applied Changes!")

# TBD fix all delimiter handling...

func _get_section_bounds(section_tag: String) -> Dictionary:
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		return {}
	var header_line = sec[SEARCH_RESULT_LINE]
	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var next_sec_search = search("[", 0, start_line, 0)
	var end_line
	if next_sec_search.empty():
		end_line = get_line_count()
	else:
		end_line = next_sec_search[SEARCH_RESULT_LINE]
	var empty_count = 0
	for i in range(start_line, end_line):
		if get_line(i).strip_edges() == "":
			empty_count += 1
	return {"start": start_line, "end": end_line, "header": header_line, "empties": empty_count}

func _split_line(line: String) -> PoolStringArray:
	var regex = RegEx.new()
	regex.compile("[\\s,]+") 
	
	var cleaned_line = line.strip_edges()
	if cleaned_line.empty():
		return PoolStringArray() # Return empty array for empty lines

	var normalized_line = regex.sub(cleaned_line, " ", true)
	
	var parts = normalized_line.split(" ", false) 
	return parts

func _detect_delimiter(start_line: int, end_line: int) -> String:
	# Define join strings and the patterns to find them
	# Check for most complex (comma + whitespace) first
	var delim_counts = {
		", ": 0,  # "comma-space", "comma-tab", "comma-multispace"
		",": 0,   # "comma"
		"\t": 0,  # "tab"
		" ": 0    # "space", "multispace"
	}
	var lines_scanned = 0
	
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue
		lines_scanned += 1
		
		var data_part = line.split(";", false)[0] # Only check data part

		# Check in order of specificity
		if data_part.find(",\t") != -1 or data_part.find(", ") != -1:
			# Catches comma-tab, comma-space, comma-multispace
			delim_counts[", "] += 1
		elif data_part.find(",") != -1:
			# Catches comma-only
			delim_counts[","] += 1
		elif data_part.find("\t") != -1:
			# Catches tab
			delim_counts["\t"] += 1
		elif data_part.find(" ") != -1:
			# Catches space, multispace
			if data_part.split(" ", false).size() > 1:
				delim_counts[" "] += 1

	if lines_scanned == 0:
		return " " # Default joiner

	var most_frequent_delim = " "
	var max_count = 0

	# Iterate in the same priority order to select the winner
	for delim in [", ", ",", "\t", " "]:
		if delim_counts[delim] > max_count:
			max_count = delim_counts[delim]
			most_frequent_delim = delim

	return most_frequent_delim

func _split_and_clean(line: String, p_delimiter: String = "") -> PoolStringArray:
	var line_parts = line.split(";")
	var data_part = line_parts[0].strip_edges()
	return _split_line(data_part)

func _update_fields(parts: Array, updates: Dictionary, sep: String) -> String:
	var new_parts = []
	for i in range(parts.size()):
		if updates.has(i):
			new_parts.append(updates[i])
		else:
			new_parts.append(parts[i])
	return _join_array(new_parts, sep)

func _join_array(parts: Array, delimiter: String) -> String:
	var result = ""
	for i in range(parts.size()):
		result += str(parts[i])
		if i < parts.size() - 1:
			result += delimiter
	return result

func _for_each_line_in_section(tag: String, callback):
	var bounds = _get_section_bounds(tag)
	if bounds.empty():
		return
	for i in range(bounds["start"], bounds["end"]):
		var line = get_line(i)
		if line.strip_edges() == "" or line.begins_with(";"):
			continue
		callback.call(i, line)

func _insert_text_at_cursor_at_line(line: int, text: String):
	cursor_set_line(line)
	cursor_set_column(0)
	select(line, 0, line, 0) # clear selection
	insert_text_at_cursor(text)

func _smart_split(line: String) -> PoolStringArray:
	return _split_line(line)

# Manual insert at line (workaround for Godot 3.x lacking built-in insert_line)
func _insert_text_at_line(line_no: int, text: String):
	var result = ""
	var total_lines = get_line_count()
	for i in range(total_lines):
		if i == line_no:
			result += text.strip_edges() + "\n"
		result += get_line(i) + "\n"
	if line_no >= total_lines:
		result += text.strip_edges() + "\n"
	set_text(result.strip_edges())

func find_line_in_ball_section(ball_no):
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_point = section_find[SEARCH_RESULT_LINE] + 1
	return find_line_in_ball_or_addball_section(ball_no, start_point)
	
func find_line_in_addball_section(ball_no):
	var section_find = search('[Add Ball]', 0, 0, 0)
	var start_point = section_find[SEARCH_RESULT_LINE] + 1
	return find_line_in_ball_or_addball_section(ball_no, start_point)
	
func find_line_in_move_section(ball_no):
	var section_find = search('[Move]', 0, 0, 0)
	var current_line = cursor_get_line()
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search('[', 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	var start_point
	if current_line >= start_of_section and current_line < end_of_section:
		start_point = current_line
	else:
		start_point = start_of_section
	var i = 0
	while true:
		var looped = start_point + i
		var line = get_line(looped)
		var stripped = line.strip_edges()
		if stripped.begins_with("["):
			if start_point == start_of_section:
				return start_of_section - 1
			else:
				start_point = start_of_section
				i = 0
				continue
		
		if stripped.empty() or stripped.begins_with(";"):
			i += 1
			continue

		var parts = _split_and_clean(line)
		if parts.size() > 0 and parts[0] == str(ball_no):
			break
		i += 1
	return start_point + i

func find_line_in_project_section(ball_no):
	var section_find = search('[Project Ball]', 0, 0, 0)
	var current_line = cursor_get_line()
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search('[', 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	var start_point
	if current_line >= start_of_section and current_line < end_of_section:
		start_point = current_line + 1
	else:
		start_point = start_of_section
	var i = 0
	while true:
		var looped = start_point + i
		var line = get_line(looped)
		var stripped = line.strip_edges()

		if stripped.begins_with("["):
			if start_point == start_of_section:
				return start_of_section - 1
			else:
				start_point = start_of_section
				i = 0
				continue
		
		if stripped.empty() or stripped.begins_with(";"):
			i += 1
			continue
			
		var parts = _split_and_clean(line)
		if parts.size() > 1 and (parts[1] == str(ball_no) or parts[0] == str(ball_no)):
			break
		
		i += 1
	return start_point + i
	
func find_line_in_linez_section(ball_no):
	var section_find = search('[Linez]', 0, 0, 0)
	var current_line = cursor_get_line()
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search('[', 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	var start_point
	if current_line >= start_of_section and current_line < end_of_section:
		start_point = current_line + 1
	else:
		start_point = start_of_section
	var i = 0
	while true:
		var looped = start_point + i
		var line = get_line(looped)
		var stripped = line.strip_edges()

		if stripped.begins_with("["):
			if start_point == start_of_section:
				return start_of_section - 1
			else:
				start_point = start_of_section
				i = 0
				continue
		
		if stripped.empty() or stripped.begins_with(";"):
			i += 1
			continue
			
		var parsed_line = _split_and_clean(line)
		
		if parsed_line.empty():
			i += 1
			continue

		if parsed_line[0] == str(ball_no) or parsed_line[1] == str(ball_no):
			break
		
		i += 1
	return start_point + i

func find_line_in_ball_or_addball_section(ball_no, start_point):
	var line = get_line(start_point)
	while true:
		if !line.lstrip(" ").begins_with(";"):
			break
		start_point += 1
		line = get_line(start_point)
	var i = 0
	var j = -1
	while true:
		line = get_line(start_point + i)
		if !line.lstrip(" ").begins_with(";"):
			j += 1
		if j == ball_no:
			break;
		i += 1
	return start_point + i

func get_corresponding_right_ball(left_ball_index):
	if left_ball_index < KeyBallsData.max_base_ball_num:
		if KeyBallsData.species == KeyBallsData.Species.CAT:
			if left_ball_index in [8, 9]:
				return left_ball_index + 2
			elif left_ball_index in [16, 17, 18] or left_ball_index in [49, 50, 51] or left_ball_index in [57, 58, 59]: # finger, toe, whisker
				return left_ball_index + 3
			else:
				return left_ball_index + 1
		else:
			return left_ball_index + 24
	else:
		return ball_map[ball_map[left_ball_index].corresponding_ball].new_ball_no
		
func get_corresponding_left_ball(right_ball_index):
	if right_ball_index < KeyBallsData.max_base_ball_num:
		if KeyBallsData.species == KeyBallsData.Species.CAT:
			if right_ball_index in [10, 11]:
				return right_ball_index - 2
			elif right_ball_index in [19, 20, 21] or right_ball_index in [52, 53, 54] or right_ball_index in [60, 61, 62]: # finger, toe, whisker
				return right_ball_index - 3
			else:
				return right_ball_index - 1
		else:
			return right_ball_index - 24
	else:
		return ball_map[ball_map[right_ball_index].corresponding_ball].new_ball_no

var ball_map = {}

func _on_ApplyChangesButton_pressed():
	save_backup()
	save_file()

func _on_apply_paintballz():
	save_backup()
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var pending_paintballs = pet_node._pending_paintballs_data

	if pending_paintballs.size() > 0:
		var is_babyz = pet_node.lnz.species == KeyBallsData.Species.BABY
		var bounds = _get_section_bounds("[Paint Ballz]")
		var insert_line_num

		if bounds.empty():
			var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
			var all_lines = get_text().split("\n")
			all_lines.insert(first_section, "[Paint Ballz]")
			all_lines.insert(first_section + 1, "")
			text = all_lines.join("\n")
			_set_text_preserve(text)
			bounds = _get_section_bounds("[Paint Ballz]")

		insert_line_num = bounds["start"]
		var j = 0
		while insert_line_num + j < bounds["end"]:
			var line = get_line(insert_line_num + j).strip_edges()
			if line.begins_with(";"):
				j += 1
				continue
			break
		insert_line_num += j

		var delim = _detect_delimiter(bounds["start"], bounds["end"])
		var new_paintball_lines = ""

		var paintball_lines_list = []
		for i in range(pending_paintballs.size() - 1, -1, -1):
			var paintball_info = pending_paintballs[i]
			var relative_pos_lnz = paintball_info.relative_pos_lnz

			var paintball_line = str(paintball_info.base_ball_no) + delim
			paintball_line += str(paintball_info.diameter) + delim
			paintball_line += str(round(relative_pos_lnz.x)) + delim
			paintball_line += str(round(relative_pos_lnz.y)) + delim
			paintball_line += str(round(relative_pos_lnz.z)) + delim
			paintball_line += str(paintball_info.color) + delim
			paintball_line += str(paintball_info.outline_color) + delim
			paintball_line += str(paintball_info.fuzz) + delim
			paintball_line += str(paintball_info.outline_type) + delim
			paintball_line += str(paintball_info.group) + delim
			paintball_line += str(paintball_info.texture) + delim
			paintball_line += str(int(!paintball_info.anchored))
			paintball_lines_list.append(paintball_line)

		if is_babyz:
			for rep in range(1, 6):
				for line in paintball_lines_list:
					new_paintball_lines += line + " ;rep" + str(rep) + "\n"
		else:
			for line in paintball_lines_list:
				new_paintball_lines += line + "\n"

		_insert_text_at_cursor_at_line(insert_line_num, new_paintball_lines)
		pet_node.clear_pending_paintballs()
	
	save_backup()

	save_file()

	var pet_view_container = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pet_view_container.close_paintball_on_apply:
		pet_view_container.close_paintball_mode()

func _on_Tree_backup_file():
	save_backup()

func _wrap_angle_deg(a: int) -> int:
	var ang = ((a % 360) + 360) % 360
	if ang > 180:
		ang -= 360
	return ang

func _on_palette_selected(filename_without_extension):
	save_backup()
	var bounds = _get_section_bounds("[Palette]")
	var new_line = filename_without_extension

	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Palette]")
		all_lines.insert(first_section + 1, new_line)
		text = all_lines.join("\n")
		_set_text_preserve(text)
	else:
		var start_line = bounds["start"]
		var end_line = bounds["end"]
		var found_palette_line = false
		for i in range(start_line, end_line):
			var line = get_line(i).strip_edges()
			if line.begins_with(""):
				set_line(i, new_line)
				found_palette_line = true
				break
		
		if not found_palette_line:
			var insert_line = _find_insertion_line(start_line, end_line)
			_insert_text_at_cursor_at_line(insert_line, new_line)
	
	save_file()

func _on_HeadShotButton_pressed():
	save_backup()
	var local_frame = int(frame_slider.value)
	var cam_e = camera_holder.rotation_degrees   # x=pitch, y=yaw, z=roll

	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var anim_idx = pet_node.current_animation
	var start_idx = pet_node.bhd.animation_ranges[anim_idx].actual_start
	var global_frame = start_idx + local_frame
	
	var raw_yaw  = -int(cam_e.y)
	var raw_roll = -int(cam_e.z)
	var raw_tilt = -int(cam_e.x)

	var yaw  = _wrap_angle_deg(raw_yaw)
	var roll = _wrap_angle_deg(raw_roll)
	var tilt = _wrap_angle_deg(raw_tilt)

	var shot_lines = [
		str(global_frame),
		str(yaw),
		str(roll),
		str(tilt)
	]

	var shot_labels = ["frame number", "rotation", "roll", "tilt"]
	for i in range(shot_lines.size()):
		var s = shot_lines[i]
		while s.length() < 24:
			s += " "
		shot_lines[i] = s + shot_labels[i]

	var bounds = _get_section_bounds("[Head Shot]")
	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Head Shot]")
		var temp = ""
		for line in all_lines:
			temp += line + "\n"
		_set_text_preserve(temp)
		bounds = _get_section_bounds("[Head Shot]")

	var lines = get_text().split("\n")

	var before_lines = []
	for i in range(bounds["start"]):
		before_lines.append(lines[i])

	var tail_lines = []
	var head_block_len = shot_lines.size()
	for i in range(bounds["start"] + head_block_len, bounds["end"]):
		tail_lines.append(lines[i])

	for i in range(min(3, tail_lines.size())):
		tail_lines[i] = "0"

	var tail_labels = [
		"head rotation",
		"head tilt",
		"head cock",
		"R / L eyelid height",
		"R / L eyelid tilt",
		"(X, Y) eye target"
	]

	for i in range(min(tail_labels.size(), tail_lines.size())):
		var raw = tail_lines[i]
		var num = ""
		for c in raw:
			if c.is_valid_integer() or c == "," or c == "-" or c == " ":
				num += c
			else:
				break
		num = num.strip_edges()
		while num.length() < 24:
			num += " "
		tail_lines[i] = num + tail_labels[i]

	var after_lines = []
	for i in range(bounds["end"], lines.size()):
		after_lines.append(lines[i])

	var new_text = ""
	for line in before_lines:
		new_text += line + "\n"
	for line in shot_lines:
		new_text += line + "\n"
	for line in tail_lines:
		new_text += line + "\n"
	for line in after_lines:
		new_text += line + "\n"

	_set_text_preserve(new_text)
	save_file()

# Connect by Linez
func _on_Node_line_created(start_ball, end_ball):
	save_backup()
	var bounds = _get_section_bounds("[Linez]")
	var start_line = bounds["start"]
	var end_line = bounds["end"]

	if start_line == -1:
		print("[LNZ EDIT] No [Linez] section found")
		# You might want to create the section if it doesn't exist.
		# For now, just returning.
		return

	var delim = _detect_delimiter(start_line, end_line)
	var sep = delim

	var line_mode_settings = get_tree().root.get_node("Root/SceneRoot/LineModeSettings")
	var props = line_mode_settings.get_properties()

	# Search for an existing line
	var line_updated = false
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line == "" or line.begins_with(";"):
			continue

		var parts = _split_and_clean(line)
		if parts.size() < 2:
			continue

		var b1 = int(parts[0])
		var b2 = int(parts[1])

		if (b1 == start_ball and b2 == end_ball) or (b1 == end_ball and b2 == start_ball):
			if parts.size() < 10:
				parts.resize(10)
			parts[2] = str(props.fuzz)
			parts[3] = str(props.color)
			parts[4] = str(props.left_outline_color)
			parts[5] = str(props.right_outline_color)
			parts[6] = str(props.start_thickness)
			parts[7] = str(props.end_thickness)
			parts[8] = str(props.outline_type)
			parts[9] = str(props.draw_order)

			set_line(i, parts.join(sep))
			line_updated = true
			break

	if not line_updated:
		var insert_line = end_line
		while insert_line > start_line and get_line(insert_line - 1).strip_edges() == "":
			insert_line -= 1

		var new_line_parts = [
			str(start_ball),
			str(end_ball),
			str(props.fuzz),
			str(props.color),
			str(props.left_outline_color),
			str(props.right_outline_color),
			str(props.start_thickness),
			str(props.end_thickness),
			str(props.outline_type),
			str(props.draw_order)
		]
		var new_line = ""
		for i in range(new_line_parts.size()):
			new_line += new_line_parts[i]
			if i < new_line_parts.size() - 1:
				new_line += sep
		new_line += "\n"

		_insert_text_at_cursor_at_line(insert_line, new_line)
		cursor_set_line(insert_line)
		cursor_set_column(0)
		center_viewport_to_cursor()

	save_file()

# Create Addballz (+ Linez)
func _on_ToolsMenu_add_ball(reference_ball, also_connect_line := false):
	save_backup()
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	if reference_ball == null:
		print("[LNZ EDIT] No reference ball given")
		return

	var ball_no = reference_ball.ball_no
	var lnz = pet_node.lnz

	var lnz_size := 20  # fallback

	if reference_ball != null:
		var ref_no = reference_ball.ball_no
		var is_addball_ref = ref_no >= KeyBallsData.max_base_ball_num or reference_ball.is_in_group("addballs")

		if is_addball_ref and lnz.addballs.has(ref_no):
			var ref_ab = lnz.addballs[ref_no]
			var s = 0

			if typeof(ref_ab) == TYPE_DICTIONARY:
				if ref_ab.has("ball_size"):
					s = int(ref_ab["ball_size"])
				elif ref_ab.has("size"):
					s = int(ref_ab["size"])
			else:
				if "ball_size" in ref_ab:
					s = int(ref_ab.ball_size)
				elif "size" in ref_ab:
					s = int(ref_ab.size)

			if s > 0:
				lnz_size = s
			elif reference_ball.has_method("set_ball_size"):
				lnz_size = int(round(reference_ball.ball_size))
		elif reference_ball.has_method("set_ball_size"):
			lnz_size = int(round(reference_ball.ball_size))

	var addball_data = lnz.addballs.get(ball_no, null)
	var ball_data = lnz.balls.get(ball_no, null)

	var fuzz_amount = 0
	if addball_data != null:
		fuzz_amount = addball_data.fuzz
	elif ball_data != null:
		fuzz_amount = ball_data.fuzz

	var texture_id = -1
	if addball_data != null:
		texture_id = addball_data.texture_id
	elif ball_data != null:
		texture_id = ball_data.texture_id

	var real_base_ball = ball_no
	if reference_ball.base_ball_no != -1:
		real_base_ball = reference_ball.base_ball_no

	var new_pos = Vector3(0, 0, 0)
	if reference_ball.base_ball_no != -1 and addball_data != null:
		new_pos = addball_data.position - Vector3(0, 0, 0)

	var bodyarea = 1
	if KeyBallsData.bodyarea_map.has(real_base_ball):
		bodyarea = KeyBallsData.bodyarea_map[real_base_ball]
	else:
		print("Missing bodyarea for ball", real_base_ball)
	
	var section_find = search("[Add Ball]", 0, 0, 0)
	if section_find.empty():
		print("[LNZ EDIT] No [Add Ball] section found")
		return
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	var delim = _detect_delimiter(start_line, end_line)
	var insert_line = _find_insertion_line(start_line, end_line)

	var fields = [
		str(real_base_ball),
		str(int(new_pos.x)),
		str(int(new_pos.y)),
		str(int(new_pos.z)),
		str(reference_ball.color_index),
		str(reference_ball.outline_color_index),
		"0",
		str(fuzz_amount),
		"0",
		str(reference_ball.old_outline),
		str(lnz_size),
		str(bodyarea),
		"0",
		str(texture_id)
	]

	var line_text = ""
	for i in range(fields.size()):
		line_text += fields[i]
		if i < fields.size() - 1:
			line_text += delim
	line_text += "\n"

	_insert_text_at_cursor_at_line(insert_line, line_text)
	cursor_set_line(insert_line)
	cursor_set_column(0)
	center_viewport_to_cursor()

	var addball_no = KeyBallsData.max_base_ball_num + _count_section_entries("[Add Ball]") - 1

	if also_connect_line:
		_on_Node_line_created(addball_no, reference_ball.ball_no)

	var pvc = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pvc and pvc.has_method("schedule_autodrag_for_addball"):
		pvc.schedule_autodrag_for_addball(addball_no)

	save_file()

func _count_section_entries(section_name: String) -> int:
	var section_find = search(section_name, 0, 0, 0)
	if section_find.empty():
		return 0
		
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var entry_count = 0
	var current_line_num = start_line
	
	while current_line_num < get_line_count():
		var line = get_line(current_line_num).strip_edges()
		
		if line.begins_with("["):
			break
		
		if line == "" or line.begins_with(";"):
			current_line_num += 1
			continue
		
		entry_count += 1
		current_line_num += 1
		
	return entry_count

func _find_insertion_line(start_line: int, end_line: int) -> int:
	var i = end_line
	while i > start_line and get_line(i - 1).strip_edges() == "":
		i -= 1
	return i

# Deletes an addball and references, or marks a base ball for omission
func _on_ToolsMenu_delete_ball(ball_no: int):
	save_backup()
	var is_addball = ball_no >= KeyBallsData.max_base_ball_num
	if is_addball:
		var line_no = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		if line_no != -1:
			select(line_no, 0, line_no + 1, 0)
			cut()
		_update_all_references(ball_no)
	else:
		_mark_base_ball_omitted(ball_no)

	save_file()

# Handles [Linez], [Omissions], [Project Ball], [Paint Ballz]
func _update_all_references(ball_no: int):
	_update_pairwise_section("[Linez]", ball_no)
	_update_single_number_section("[Omissions]", ball_no)
	_update_project_ball_section("[Project Ball]", ball_no)
	_update_paintballz_section("[Paint Ballz]", ball_no)

# Inserts a base ball into [Omissions] if not present
func _mark_base_ball_omitted(ball_no: int):
	var section = search("[Omissions]", 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1

	# Scan section first to avoid modifying it while iterating
	var already_omitted = false
	var end = get_line_count()
	for i in range(start, end):
		var line = get_line(i).strip_edges()
		if line.begins_with("[") or line == "":
			break
		if int(line) == ball_no:
			already_omitted = true
			break

	if not already_omitted:
		_insert_text_at_line(start, str(ball_no) + "\n")

# Generic for [Linez] with start/end ball pair
func _update_pairwise_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var tokens = _smart_split(line)
		var b1 = int(tokens[0])
		var b2 = int(tokens[1])
		if b1 == ball_no or b2 == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		if b1 > ball_no: b1 -= 1
		if b2 > ball_no: b2 -= 1
		var rest = ""
		for j in range(2, tokens.size()):
			if j > 2:
				rest += " "
			rest += tokens[j]

		set_line(start + i, "%s %s %s" % [b1, b2, rest])
		i += 1

# Generic for single-number lists like [Omissions]
func _update_single_number_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var val = int(line)
		if val == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif val > ball_no:
			set_line(start + i, str(val - 1))
		i += 1

# Specific for [Project Ball] where 2nd token is ball_no
func _update_project_ball_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var tokens = _smart_split(line)
		var move_ball = int(tokens[1])
		if move_ball == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif move_ball > ball_no:
			var rest = line.substr(tokens[2].get_start())
			set_line(start + i, "%s %s %s" % [tokens[0], str(move_ball - 1), rest])
		i += 1

# Specific for [Paint Ballz] where 1st token is base ball number
func _update_paintballz_section(header: String, ball_no: int):
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var split = line.split(" ", false, 1)
		var b = int(split[0])
		if b == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif b > ball_no:
			set_line(start + i, "%s %s" % [str(b - 1), split[1]])
		i += 1

func _on_Node_ball_selected(section, ball_no, is_addball, max_addball_no):
	# need to find line number for the ball
	var actual_start_point
	if section == Section.Section.BALL:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		else:
			actual_start_point = find_line_in_ball_section(ball_no)
	elif section == Section.Section.MOVE:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		else:
			actual_start_point = find_line_in_move_section(ball_no)
	elif section == Section.Section.PROJECT:
		actual_start_point = find_line_in_project_section(ball_no)
	elif section == Section.Section.LINE:
		actual_start_point = find_line_in_linez_section(ball_no)
	if actual_start_point == -1:
		return
	cursor_set_line(actual_start_point)
	cursor_set_column(0)
	center_viewport_to_cursor()

func _on_ToolsMenu_color_entire_pet(color_index, outline_color_index):
	save_backup()
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.nose_cat)
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
	elif species == KeyBallsData.Species.DOG:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.nose_dog)
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_bab)
		balls_to_exclude.append_array(KeyBallsData.eyebrow_bab)
		
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		if i in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		# here the first number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 0 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 1 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	
	section_find = search('[Add Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	while true:
		if i + KeyBallsData.max_base_ball_num in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		# here the fifth number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if parsed_line.size() == 0 or int(parsed_line[0]) in balls_to_exclude:
			i += 1
			continue
		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 4 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 5 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	save_file()


func _on_ToolsMenu_color_part_pet(core_ball_nos, color_index, outline_color_index, intended_part):
	save_backup()
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
		if intended_part != "NOSE":
			balls_to_exclude.append_array(KeyBallsData.nose_cat)
	elif species == KeyBallsData.Species.DOG:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
		if intended_part != "NOSE":
			balls_to_exclude.append_array(KeyBallsData.nose_dog)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_bab)
		
	var section_find = search('[Ballz Info]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		if i in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		if !(i in core_ball_nos):
			i += 1
			continue
		# here the first number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 0 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 1 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	
	section_find = search('[Add Ball]', 0, 0, 0)
	start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	i = 0
	while true:
		if i + KeyBallsData.max_base_ball_num in balls_to_exclude:
			i += 1
			continue
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";"):
			i += 1
			continue
		elif line.begins_with("["):
			break
		# here the fifth number is color

		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if parsed_line.size() == 0 or int(parsed_line[0]) in balls_to_exclude:
			i += 1
			continue
		if !(int(parsed_line[0]) in core_ball_nos):
			i+=1
			continue
		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 4 and !color_index.empty():
				final_line += str(color_index) + " "
			elif n == 5 and !outline_color_index.empty():
				final_line += str(outline_color_index) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	save_file()

func _find_mirrored_ball(ball_no: int) -> int:
	if ball_no >= KeyBallsData.max_base_ball_num:
		return ball_no
		
	var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
	var species = pet_node.lnz.species 
	var symmetry_dict = {}

	if species == KeyBallsData.Species.CAT:
		symmetry_dict = KeyBallsData.cat_body_part_symmetry
	elif species == KeyBallsData.Species.DOG:
		symmetry_dict = KeyBallsData.dog_body_part_symmetry
	elif species == KeyBallsData.Species.BABY:
		symmetry_dict = KeyBallsData.baby_body_part_symmetry
	else:
		return ball_no

	for main_part in symmetry_dict:
		for sub_part in symmetry_dict[main_part]:
			var part_info = symmetry_dict[main_part][sub_part]
			if part_info.has("left") and part_info.has("right"):
				var index = part_info.left.find(ball_no)
				if index != -1 and index < part_info.right.size():
					return part_info.right[index]
				
				index = part_info.right.find(ball_no)
				if index != -1 and index < part_info.left.size():
					return part_info.left[index]
	
	var left_balls = []
	if species == KeyBallsData.Species.CAT:
		left_balls = KeyBallsData.symmetry_mode_hide_balls_cat
	elif species == KeyBallsData.Species.DOG:
		left_balls = KeyBallsData.symmetry_mode_hide_balls_dog
	elif species == KeyBallsData.Species.BABY:
		left_balls = KeyBallsData.symmetry_mode_hide_balls_bab
		
	if ball_no in left_balls:
		return get_corresponding_right_ball(ball_no)

	return ball_no

func _on_ToolsMenu_copy_l_to_r(selected_ball_no: int = -1):
	if selected_ball_no == -1:
		_mirror_l_to_r_full()
	else:
		_mirror_l_to_r_ball(selected_ball_no)

func _on_ToolsMenu_copy_r_to_l(selected_ball_no: int = -1):
	_mirror_l_to_r_full(true)

func _mirror_l_to_r_full(reverse: bool = false):
	save_backup()
	
	var omitted_balls = _get_omitted_balls()
	
	var source_list = []
	var target_list = []
	var middle_balls_list = []
	
	var s_left = []
	var s_right = []
	
	if KeyBallsData.species == KeyBallsData.Species.CAT:
		s_left = KeyBallsData.symmetry_mode_hide_balls_cat.duplicate()
		s_right = KeyBallsData.symmetry_mode_right_balls_cat.duplicate()
	elif KeyBallsData.species == KeyBallsData.Species.DOG:
		s_left = KeyBallsData.symmetry_mode_hide_balls_dog.duplicate()
		s_right = KeyBallsData.symmetry_mode_right_balls_dog.duplicate()
	elif KeyBallsData.species == KeyBallsData.Species.BABY:
		s_left = KeyBallsData.symmetry_mode_hide_balls_bab.duplicate()
		s_right = KeyBallsData.symmetry_mode_right_balls_bab.duplicate()
	
	if reverse:
		source_list = s_right
		target_list = s_left
	else:
		source_list = s_left
		target_list = s_right
		
	for n in range(0, KeyBallsData.max_base_ball_num):
		if !(n in s_left or n in s_right):
			middle_balls_list.append(n)

	# [Ballz Info]
	var bounds = _get_section_bounds("[Ballz Info]")
	if bounds.empty():
		print("[LNZ EDIT] No [Ballz Info] found!")
		return

	var delim = _detect_delimiter(bounds.start, bounds.end)
	
	var base_mirror_map = {} 
	
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if line.begins_with("[") or line.begins_with(";") or line.empty():
			continue
			
		var ball_no = _get_line_no_from_line_index(i, "[Ballz Info]")
		if ball_no == -1: continue
		
		if ball_no in source_list:
			var target_base = -1
			var candidate = _find_mirrored_ball(ball_no)
			
			if candidate == ball_no:
				if reverse: target_base = get_corresponding_left_ball(ball_no)
				else: target_base = get_corresponding_right_ball(ball_no)
			else:
				target_base = candidate
				
			if target_base != -1 and target_base != ball_no:
				base_mirror_map[ball_no] = target_base
				
				if !(target_base in omitted_balls):
					var parts = _split_and_clean(line, delim)
					var mirrored_attrs = _mirror_ball_attributes(parts, false)
					var mirrored_line = _update_fields(parts, mirrored_attrs, delim)
					
					var target_line_idx = find_line_in_ball_section(target_base)
					if target_line_idx != -1:
						set_line(target_line_idx, mirrored_line)

	# [Add Ball]
	bounds = _get_section_bounds("[Add Ball]")
	delim = _detect_delimiter(bounds.start, bounds.end)
	
	var current_scan_id = KeyBallsData.max_base_ball_num
	var source_addballs_found = [] 
	var source_to_mirror_map = {}
	var mirrors_queue = []
	
	var addball_lines_content = []
	for i in range(bounds.start, bounds.end):
		addball_lines_content.append(get_line(i))

	var existing_signatures = {}
	var sig_scan_id = KeyBallsData.max_base_ball_num
	
	for line in addball_lines_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = _split_and_clean(strip, delim)
			var sig = _join_array(parts, delim)
			if !existing_signatures.has(sig):
				existing_signatures[sig] = sig_scan_id
			sig_scan_id += 1

	var next_free_id = sig_scan_id
	
	for line in addball_lines_content:
		var strip_line = line.strip_edges()
		if strip_line.begins_with("[") or strip_line.begins_with(";") or strip_line.empty():
			continue

		var is_source = false
		var parts = _split_and_clean(strip_line, delim)
		
		if current_scan_id in omitted_balls:
			is_source = false
		elif parts.size() > 0:
			var base_ball = parts[0].to_int()
			
			if base_ball in source_list:
				is_source = true
			elif base_ball in source_addballs_found:
				is_source = true
			elif base_ball in middle_balls_list:
				var x_pos = parts[1].to_float()
				if abs(x_pos) > 0.001:
					is_source = true
		
		if is_source:
			source_addballs_found.append(current_scan_id)
			
			var old_base = parts[0].to_int()
			var new_base = -1
			
			if source_to_mirror_map.has(old_base):
				new_base = source_to_mirror_map[old_base]
			elif base_mirror_map.has(old_base):
				new_base = base_mirror_map[old_base]
			elif old_base in middle_balls_list:
				new_base = old_base
			else:
				if reverse: new_base = get_corresponding_left_ball(old_base)
				else: new_base = get_corresponding_right_ball(old_base)
				
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(new_base)
			if mirrored_parts.size() > 1:
				mirrored_parts[1] = str(mirrored_parts[1].to_float() * -1.0)
			if mirrored_parts.size() > 9:
				if mirrored_parts[9] == "0": mirrored_parts[9] = "-2"
				elif mirrored_parts[9] == "-2": mirrored_parts[9] = "0"
			
			var mirror_sig = _join_array(mirrored_parts, delim)
			
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
		
	var final_addball_lines_to_append = []
	
	for item in mirrors_queue:
		final_addball_lines_to_append.append(item.mirror_line_content)

	# [Linez]
	var final_linez_lines_to_append = []

	bounds = _get_section_bounds("[Linez]")
	delim = _detect_delimiter(bounds.start, bounds.end)
	
	var existing_linez_signatures = {}
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
			var parts = _split_and_clean(line, delim)
			var sig = _join_array(parts, delim)
			existing_linez_signatures[sig] = true

	var linez_content = []
	for i in range(bounds.start, bounds.end):
		linez_content.append(get_line(i))
		
	for line in linez_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = _split_and_clean(strip, delim)
			if parts.size() < 2: continue
			
			var s = parts[0].to_int()
			var e = parts[1].to_int()
			
			var s_is_src = (s in source_list) or (s in source_addballs_found)
			var e_is_src = (e in source_list) or (e in source_addballs_found)
			
			if (s in middle_balls_list) and e_is_src: s_is_src = true
			if (e in middle_balls_list) and s_is_src: e_is_src = true

			if s_is_src or e_is_src:
				var m_s = -1
				var m_e = -1
				
				if source_to_mirror_map.has(s): m_s = source_to_mirror_map[s]
				elif base_mirror_map.has(s): m_s = base_mirror_map[s]
				elif s in middle_balls_list: m_s = s
				else: 
					if reverse: m_s = get_corresponding_left_ball(s)
					else: m_s = get_corresponding_right_ball(s)

				if source_to_mirror_map.has(e): m_e = source_to_mirror_map[e]
				elif base_mirror_map.has(e): m_e = base_mirror_map[e]
				elif e in middle_balls_list: m_e = e
				else: 
					if reverse: m_e = get_corresponding_left_ball(e)
					else: m_e = get_corresponding_right_ball(e)
				
				if m_s != -1 and m_e != -1:
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_s)
					mirror_parts[1] = str(m_e)
					if mirror_parts.size() > 8:
						if mirror_parts[8] == "0": mirror_parts[8] = "-2"
						elif mirror_parts[8] == "-2": mirror_parts[8] = "0"
					if mirror_parts.size() > 5:
						var temp = mirror_parts[4]
						mirror_parts[4] = mirror_parts[5]
						mirror_parts[5] = temp
					
					var new_line_sig = _join_array(mirror_parts, delim)
					if !existing_linez_signatures.has(new_line_sig):
						final_linez_lines_to_append.append(new_line_sig)
						existing_linez_signatures[new_line_sig] = true

	# [Move]
	var final_move_lines = []

	bounds = _get_section_bounds("[Move]")
	delim = _detect_delimiter(bounds.start, bounds.end)
	
	var move_content = []
	for i in range(bounds.start, bounds.end):
		move_content.append(get_line(i))

	for line in move_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = _split_and_clean(strip, delim)
			if parts.size() < 1: continue
			var move_ball = parts[0].to_int()

			if !(move_ball in target_list):
				final_move_lines.append(strip)

			var is_src = (move_ball in source_list) or (move_ball in source_addballs_found)
			
			if is_src:
				var m_move_ball = -1
				if source_to_mirror_map.has(move_ball): m_move_ball = source_to_mirror_map[move_ball]
				elif base_mirror_map.has(move_ball): m_move_ball = base_mirror_map[move_ball]
				
				if m_move_ball != -1:
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_move_ball)
					if mirror_parts.size() > 1:
						mirror_parts[1] = str(mirror_parts[1].to_float() * -1.0)
					
					if mirror_parts.size() > 4:
						var old_anchor = mirror_parts[4].to_int()
						var new_anchor = -1
						if source_to_mirror_map.has(old_anchor): new_anchor = source_to_mirror_map[old_anchor]
						elif base_mirror_map.has(old_anchor): new_anchor = base_mirror_map[old_anchor]
						elif old_anchor in middle_balls_list: new_anchor = old_anchor
						
						if new_anchor != -1:
							mirror_parts[4] = str(new_anchor)

					final_move_lines.append(_join_array(mirror_parts, delim))

	# [Project Ball]
	var final_proj_lines = []

	bounds = _get_section_bounds("[Project Ball]")
	delim = _detect_delimiter(bounds.start, bounds.end)
	
	var proj_content = []
	for i in range(bounds.start, bounds.end):
		proj_content.append(get_line(i))

	for line in proj_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = _split_and_clean(strip, delim)
			if parts.size() < 2: continue
			
			var b = parts[0].to_int()
			var m = parts[1].to_int()

			if !(b in target_list) and !(m in target_list):
				final_proj_lines.append(strip)

			var b_is_src = (b in source_list) or (b in source_addballs_found)
			var m_is_src = (m in source_list) or (m in source_addballs_found)
			
			if b_is_src or m_is_src:
				var m_b = -1
				var m_m = -1
				
				if source_to_mirror_map.has(b): m_b = source_to_mirror_map[b]
				elif base_mirror_map.has(b): m_b = base_mirror_map[b]
				elif b in middle_balls_list: m_b = b
				
				if source_to_mirror_map.has(m): m_m = source_to_mirror_map[m]
				elif base_mirror_map.has(m): m_m = base_mirror_map[m]
				elif m in middle_balls_list: m_m = m
				
				if m_b != -1 and m_m != -1:
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_b)
					mirror_parts[1] = str(m_m)
					final_proj_lines.append(_join_array(mirror_parts, delim))
	
	# [Paint Ballz]
	var final_paint_lines_to_append = []

	bounds = _get_section_bounds("[Paint Ballz]")
	delim = _detect_delimiter(bounds.start, bounds.end)
	
	var existing_paint_sigs = {}
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
			var parts = _split_and_clean(line, delim)
			existing_paint_sigs[_join_array(parts, delim)] = true
	
	var paint_content = []
	for i in range(bounds.start, bounds.end):
		paint_content.append(get_line(i))
		
	for line in paint_content:
		var strip = line.strip_edges()
		if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
			var parts = _split_and_clean(strip, delim)
			if parts.size() < 3: continue
			
			var base = parts[0].to_int()
			var x = parts[2].to_float()
			
			var is_src = false
			if base in source_list: is_src = true
			elif base in middle_balls_list:
				if abs(x) > 0.001: is_src = true
				
			if is_src:
				var m_base = -1
				if base_mirror_map.has(base): m_base = base_mirror_map[base]
				else: m_base = base
				
				var mirror_parts = Array(parts)
				mirror_parts[0] = str(m_base)
				mirror_parts[2] = str(x * -1.0)
				
				var new_sig = _join_array(mirror_parts, delim)
				
				if !existing_paint_sigs.has(new_sig):
					final_paint_lines_to_append.append(new_sig)
					existing_paint_sigs[new_sig] = true

	if !final_addball_lines_to_append.empty():
		var bounds_ab = _get_section_bounds("[Add Ball]")
		var ins_line = _find_insertion_line(bounds_ab.start, bounds_ab.end)
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_addball_lines_to_append, "\n") + "\n")
		
	if !final_linez_lines_to_append.empty():
		var bounds_l = _get_section_bounds("[Linez]")
		var ins_line = _find_insertion_line(bounds_l.start, bounds_l.end)
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_linez_lines_to_append, "\n") + "\n")

	if !final_move_lines.empty():
		_replace_section_content("[Move]", final_move_lines)

	if !final_proj_lines.empty():
		_replace_section_content("[Project Ball]", final_proj_lines)

	if !final_paint_lines_to_append.empty():
		var bounds_p = _get_section_bounds("[Paint Ballz]")
		var ins_line = _find_insertion_line(bounds_p.start, bounds_p.end)
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_paint_lines_to_append, "\n") + "\n")

	save_file()

func _get_omitted_balls() -> Array:
	var omitted_balls = []
	var section_find = search("[Omissions]", 0, 0, 0)
	if section_find.empty():
		return omitted_balls
		
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var end_of_section = search("[", 0, start_of_section, 0)[SEARCH_RESULT_LINE]
	if end_of_section == -1:
		end_of_section = get_line_count()
	
	for i in range(start_of_section, end_of_section):
		var line = get_line(i).lstrip(" ")
		if line.empty() or line.begins_with(";"):
			continue
		
		var ball_no_str = line.split(";", false)[0].strip_edges().split(" ", false)[0]
		if ball_no_str.is_valid_integer():
			omitted_balls.append(ball_no_str.to_int())
		
	return omitted_balls

func _mirror_l_to_r_ball(target_ball_no: int):
	save_backup()

	if target_ball_no >= KeyBallsData.max_base_ball_num:
		print("[LNZ EDIT] Copy-Mirror is only supported for base balls (0-%d)." % (KeyBallsData.max_base_ball_num - 1))
		return

	var mirrored_ball_no = _find_mirrored_ball(target_ball_no)
	var is_mirrored = mirrored_ball_no != target_ball_no
	if !is_mirrored:
		print("[LNZ EDIT] Ball #%d is a middle ball or non-symmetrical. Mirroring Addballz/Linez/Paintballz to the ball itself." % target_ball_no)

	var omitted_balls = _get_omitted_balls()

	# [Ballz Info]
	var ballz_bounds = _get_section_bounds("[Ballz Info]")
	var line_index = find_line_in_ball_section(target_ball_no)
	if line_index != -1:
		var delim = _detect_delimiter(ballz_bounds.start, ballz_bounds.end)
		var line = get_line(line_index)
		var parts = _split_and_clean(line, delim)
		var mirrored_attrs = _mirror_ball_attributes(parts, false)
		var mirrored_line = _update_fields(parts, mirrored_attrs, delim)
		
		var mirrored_line_index = find_line_in_ball_section(mirrored_ball_no)
		if mirrored_line_index != -1:
			set_line(mirrored_line_index, mirrored_line)

	# Build a temporary map for newly created addballs
	var temp_addball_map = {}
	var new_addball_lines = []

	# [Add Ball]
	var addball_bounds = _get_section_bounds("[Add Ball]")
	if !addball_bounds.empty():
		var delim = _detect_delimiter(addball_bounds.start, addball_bounds.end)
		var max_ball_no = KeyBallsData.max_base_ball_num + _count_section_entries("[Add Ball]")
		var new_addball_no = max_ball_no
		
		var addball_lines = []
		for i in range(addball_bounds.start, addball_bounds.end):
			addball_lines.append(get_line(i))

		for i in range(addball_lines.size()):
			var line = addball_lines[i].strip_edges()
			if line.empty() or line.begins_with(";"): continue

			var current_addball_no = KeyBallsData.max_base_ball_num + i
			var parts = _split_and_clean(line, delim)
			if parts.empty() or parts[0].to_int() != target_ball_no:
				continue

			if omitted_balls.has(current_addball_no):
				print("[LNZ EDIT] Skipping Addball #%d because it is in [Omissions]." % current_addball_no)
				continue

			var mirrored_attrs = _mirror_ball_attributes(parts, true)
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(mirrored_ball_no)
			for key in mirrored_attrs:
				mirrored_parts[key] = mirrored_attrs[key]
			
			new_addball_lines.append(_join_array(mirrored_parts, delim))
			temp_addball_map[current_addball_no] = new_addball_no
			new_addball_no += 1
			
		if !new_addball_lines.empty():
			var insert_line = _find_insertion_line(addball_bounds.start, addball_bounds.end)
			_insert_text_at_cursor_at_line(insert_line, _join_array(new_addball_lines, "\n") + "\n")

	var associated_left_balls = [target_ball_no] + temp_addball_map.keys()

	# [Paint Ballz] & [Linez]
	var sections_to_process = {}
	sections_to_process["[Paint Ballz]"] = "_process_paintball_line_for_mirror"
	sections_to_process["[Linez]"] = "_process_linez_line_for_mirror"

	for section_name in sections_to_process:
		var method_name = sections_to_process[section_name]
		var bounds = _get_section_bounds(section_name)
		if bounds.empty(): continue

		var new_lines = []
		var delim = _detect_delimiter(bounds.start, bounds.end)
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			
			var parts = _split_and_clean(line, delim)
			var processed_line = call(method_name, parts, target_ball_no, mirrored_ball_no, associated_left_balls, temp_addball_map)
			
			if processed_line != null and processed_line.size() > 0:
				new_lines.append(_join_array(processed_line, delim))
		
		if !new_lines.empty():
			var insert_line = _find_insertion_line(bounds.start, bounds.end)
			_insert_text_at_cursor_at_line(insert_line, _join_array(new_lines, "\n") + "\n")

	# [Move]
	if is_mirrored:
		_process_move_section_for_mirror(target_ball_no, mirrored_ball_no)

	print("[LNZ EDIT] Successfully performed selective L to R mirror for ball #%d." % target_ball_no)
	save_file()

func _process_paintball_line_for_mirror(parts: PoolStringArray, target_ball_no: int, mirrored_ball_no: int, associated_left_balls: Array, temp_addball_map: Dictionary) -> Array:
	if parts.size() < 6: 
		return []
	var base_ball = parts[0].to_int()
	if base_ball == target_ball_no:
		var new_parts = Array(parts)
		new_parts[0] = str(mirrored_ball_no)
		new_parts[2] = str(new_parts[2].to_float() * -1.0)
		return new_parts
	return []

func _process_linez_line_for_mirror(parts: PoolStringArray, target_ball_no: int, mirrored_ball_no: int, associated_left_balls: Array, temp_addball_map: Dictionary) -> Array:
	if parts.size() < 2:
		return []
	var start_ball = parts[0].to_int()
	var end_ball = parts[1].to_int()

	if associated_left_balls.has(start_ball) or associated_left_balls.has(end_ball):
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(_get_mirrored_counterpart(start_ball, target_ball_no, mirrored_ball_no, temp_addball_map))
		mirrored_parts[1] = str(_get_mirrored_counterpart(end_ball, target_ball_no, mirrored_ball_no, temp_addball_map))
		
		# Mirror outline type for lines
		if mirrored_parts.size() > 8:
			if mirrored_parts[8] == "0": mirrored_parts[8] = "-2"
			elif mirrored_parts[8] == "-2": mirrored_parts[8] = "0"

		return mirrored_parts
	return []

func _get_mirrored_counterpart(ball: int, target: int, mirrored: int, temp_map: Dictionary) -> int:
	if ball == target: return mirrored
	if temp_map.has(ball): return temp_map[ball]
	if ball < KeyBallsData.max_base_ball_num: return _find_mirrored_ball(ball)
	return ball

func _process_move_section_for_mirror(target_ball_no: int, mirrored_ball_no: int):
	var move_bounds = _get_section_bounds("[Move]")
	if move_bounds.empty(): return

	var delim = _detect_delimiter(move_bounds.start, move_bounds.end)
	var new_mirrored_line = ""
	var target_line_found = false

	for i in range(move_bounds.start, move_bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue
		
		var parts = _split_and_clean(line, delim)
		if parts.size() >= 4 and parts[0].to_int() == target_ball_no:
			target_line_found = true
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(mirrored_ball_no)
			mirrored_parts[1] = str(mirrored_parts[1].to_float() * -1.0)
			if parts.size() > 4:
				mirrored_parts[4] = str(_find_mirrored_ball(parts[4].to_int()))
			new_mirrored_line = _join_array(mirrored_parts, delim)
			break

	if target_line_found:
		var lines_to_remove = []
		for i in range(move_bounds.start, move_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			var parts = _split_and_clean(line, delim)
			if parts.size() > 0 and parts[0].to_int() == mirrored_ball_no:
				lines_to_remove.append(i)
		
		for i in range(lines_to_remove.size() - 1, -1, -1):
			var line_num = lines_to_remove[i]
			select(line_num, 0, line_num + 1, 0)
			cut()

		if !new_mirrored_line.empty():
			var insert_line = _find_insertion_line(move_bounds.start, move_bounds.end)
			_insert_text_at_cursor_at_line(insert_line, new_mirrored_line + "\n")

func apply_preset_to_ball(ball_no, properties, do_save = true):
	if do_save:
		save_backup()
	var is_addball = ball_no >= KeyBallsData.max_base_ball_num

	var section_tag = "[Ballz Info]"
	if is_addball:
		section_tag = "[Add Ball]"

	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return

	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]

	var line_index = -1
	if is_addball:
		line_index = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
	else:
		line_index = find_line_in_ball_section(ball_no)

	if line_index != -1:
		var delim = _detect_delimiter(start_line, end_line)
		var line = get_line(line_index)
		var parts = _split_and_clean(line)

		if is_addball:
			if properties.has("color_index"): parts[4] = str(properties.color_index)
			if properties.has("outline_color_index"): parts[5] = str(properties.outline_color_index)
			if properties.has("fuzz"): parts[7] = str(properties.fuzz)
			if properties.has("outline"): parts[9] = str(properties.outline)
			if properties.has("size"): parts[10] = str(properties.size)
			if properties.has("group"): parts[8] = str(properties.group)
			if properties.has("texture_id"): parts[13] = str(properties.texture_id)
		else:
			if properties.has("color_index"): parts[0] = str(properties.color_index)
			if properties.has("outline_color_index"): parts[1] = str(properties.outline_color_index)
			if properties.has("fuzz"): parts[3] = str(properties.fuzz)
			if properties.has("outline"): parts[4] = str(properties.outline)
			if properties.has("size"): parts[5] = str(properties.size)
			if properties.has("group"): parts[6] = str(properties.group)
			if properties.has("texture_id"): parts[7] = str(properties.texture_id)

		var new_line = ""
		for i in range(parts.size()):
			new_line += parts[i]
			if i < parts.size() - 1:
				new_line += delim

		set_line(line_index, new_line)
		if do_save:
			save_file()

#func _add_or_update_override(section_name, ball_no, values, value_indices):
#	var section_find = search(section_name, 0, 0, 0)
#	var start_line
#	var end_line
#
#	if section_find.empty():
#		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
#		var all_lines = get_text().split("\n")
#		all_lines.insert(first_section, section_name)
#		all_lines.insert(first_section + 1, "")
#		text = all_lines.join("\n")
#		_set_text_preserve(text)
#		section_find = search(section_name, 0, 0, 0)
#
#	start_line = section_find[SEARCH_RESULT_LINE] + 1
#	end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
#	if end_line == -1:
#		end_line = get_line_count()
#
#	var delim = _detect_delimiter(start_line, end_line)
#	var line_updated = false
#	for i in range(start_line, end_line):
#		var line = get_line(i).strip_edges()
#		if line.begins_with(str(ball_no) + delim):
#			var parts = _split_and_clean(line, delim)
#			var max_index = value_indices.max()
#			while parts.size() <= max_index:
#				parts.append("0")
#
#			var value_idx = 0
#			for target_idx in value_indices:
#				parts[target_idx] = str(values[value_idx])
#				value_idx += 1
#
#			set_line(i, parts.join(delim))
#			line_updated = true
#			break
#
#	if not line_updated:
#		var max_index = 0
#		if value_indices.size() > 0:
#			max_index = value_indices.max()
#
#		var new_parts = []
#		new_parts.resize(max_index + 1)
#		for i in range(new_parts.size()):
#			new_parts[i] = "0"
#		new_parts[0] = str(ball_no)
#
#		var value_idx = 0
#		for target_idx in value_indices:
#			if value_idx < values.size():
#				new_parts[target_idx] = str(values[value_idx])
#				value_idx += 1
#
#		var new_line = new_parts.join(delim)
#		var insert_line = _find_insertion_line(start_line, end_line)
#		_insert_text_at_cursor_at_line(insert_line, new_line + "\n")

func write_preset_to_ball(ball_no, properties, _write_target, should_override):
	var applied_something = false
	if properties.get("apply_ballz", true):
		apply_preset_to_ball(ball_no, properties, false)
		applied_something = true

	if properties.get("apply_paintballz", true) and properties.has("paintballz"):
		var paintballz = properties.paintballz
		if paintballz.size() > 0:
			applied_something = true
			var bounds = _get_section_bounds("[Paint Ballz]")
			var insert_line_num

			if bounds.empty():
				var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
				var all_lines = get_text().split("\n")
				all_lines.insert(first_section, "[Paint Ballz]")
				all_lines.insert(first_section + 1, "")
				text = all_lines.join("\n")
				_set_text_preserve(text)
				bounds = _get_section_bounds("[Paint Ballz]")

			insert_line_num = bounds["start"]
			var j = 0
			while insert_line_num + j < bounds["end"]:
				var line = get_line(insert_line_num + j).strip_edges()
				if line.begins_with(";"):
					j += 1
					continue
				break
			insert_line_num += j

			var delim = _detect_delimiter(bounds["start"], bounds["end"])
			var new_paintball_lines = ""
			for paintball_info in paintballz:
				var pos = paintball_info.position
				var paintball_line = str(ball_no) + delim
				paintball_line += str(paintball_info.size) + delim
				paintball_line += str(pos.x) + delim
				paintball_line += str(pos.y) + delim
				paintball_line += str(pos.z) + delim
				paintball_line += str(paintball_info.color_index) + delim
				paintball_line += str(paintball_info.outline_color_index) + delim
				paintball_line += str(paintball_info.fuzz) + delim
				paintball_line += str(paintball_info.outline) + delim
				paintball_line += "0" + delim # group, not in use for paintballz
				paintball_line += str(paintball_info.texture_id) + delim
				paintball_line += str(paintball_info.anchored)

				new_paintball_lines += paintball_line + "\n"

			_insert_text_at_cursor_at_line(insert_line_num, new_paintball_lines)

	if applied_something:
		save_file()


func _on_LnzTextEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_Q:
		var nearest_section_start = search("[", SEARCH_BACKWARDS, cursor_get_line(), 0)
		
		if nearest_section_start.empty():
			emit_signal("find_ball", int(get_word_under_cursor()))
			return
		
		var nearest_section_line = nearest_section_start[SEARCH_RESULT_LINE]
		var nearest_section = get_line(nearest_section_line)
		
		var ball_no = -1
		var line_no = -1
		
		if nearest_section == "[Ballz Info]":
			ball_no = _get_line_no_from_line_index(cursor_get_line(), "[Ballz Info]")
			if ball_no != -1:
				emit_signal("find_ball", ball_no)
		elif nearest_section == "[Add Ball]":
			ball_no = _get_line_no_from_line_index(cursor_get_line(), "[Add Ball]")
			if ball_no != -1:
				emit_signal("find_ball", ball_no + KeyBallsData.max_base_ball_num)
		elif nearest_section == "[Linez]":
			line_no = _get_line_no_from_line_index(cursor_get_line(), "[Linez]")
			if line_no != -1:
				emit_signal("find_line", line_no)
		elif nearest_section == "[Paint Ballz]":
			line_no = _get_line_no_from_line_index(cursor_get_line(), "[Paint Ballz]")
			if line_no != -1:
				emit_signal("find_paintball", line_no)
		elif nearest_section == "[Polygons]":
			line_no = _get_line_no_from_line_index(cursor_get_line(), "[Polygons]")
			if line_no != -1:
				emit_signal("find_polygon", line_no)
		elif nearest_section == "[Move]":
			line_no = _get_line_no_from_line_index(cursor_get_line(), "[Move]")
			if line_no != -1:
				emit_signal("find_move", line_no)
		elif nearest_section == "[Project Ball]":
			line_no = _get_line_no_from_line_index(cursor_get_line(), "[Project Ball]")
			if line_no != -1:
				emit_signal("find_project_ball", line_no)
		else:
			var word = get_word_under_cursor()
			if word.is_valid_integer():
				ball_no = int(word)
				if ball_no != -1:
					emit_signal("find_ball", ball_no)

func _get_line_no_from_line_index(target_line_index: int, section_tag: String) -> int:
	var section_find = search(section_tag, 0, 0, 0)
	if section_find.empty():
		return -1
	
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	if end_line == -1:
		end_line = get_line_count()

	var line_counter = -1
	for i in range(start_line, end_line):
		var line = get_line(i).lstrip(" ")
		if line.begins_with(";") or line.empty() or line.begins_with("["):
			continue
		
		line_counter += 1
		
		if i == target_line_index:
			return line_counter
				
	return -1

func _get_ramp_color(current_color_str: String, rule):
	# Rule must be a ramp rule with valid before/after colors
	if not rule.is_ramp or rule.before_color.empty() or rule.after_color.empty():
		return null

	# All colors involved must be valid numbers
	if not current_color_str.is_valid_integer() or \
	   not rule.before_color.is_valid_integer() or \
	   not rule.after_color.is_valid_integer():
		return null

	var current_color: int = int(current_color_str)
	var before_color: int = int(rule.before_color)
	var after_color: int = int(rule.after_color)

	# Ramp ranges are 10-199
	if current_color < 10 or current_color > 199:
		return null
	if before_color < 10 or before_color > 199:
		return null

	# Find the base of the 10-unit ramp range (e.g., 62 -> 60)
	var current_base: int = int(current_color / 10) * 10
	var before_base: int = int(before_color / 10) * 10

	# Check if the current color is in the same ramp range as the rule's "before" color
	if current_base != before_base:
		return null # Not in the same ramp, this rule doesn't apply

	if after_color >= 10 and after_color <= 199:
		# "After" color is *also* in a ramp range (10-199)
		# Map to the corresponding color in the "after" ramp
		# e.g., Rule: 62 -> 55. Current: 60.
		# offset = 60 - 60 = 0
		# after_base = 50
		# new_color = 50 + 0 = 50
		var offset: int = current_color - current_base
		var after_base: int = int(after_color / 10) * 10
		var new_color: int = after_base + offset
		return str(new_color)
	else:
		# "After" color is *outside* ramp ranges (e.g., 244)
		# Map all colors in the "before" range to this single "after" color
		# e.g., Rule: 62 -> 244. Current: 60.
		# new_color = 244
		return str(after_color)

func _on_ToolsMenu_recolor(all_recolor_info: Dictionary):
	save_backup()
	
	var recolor_rules = all_recolor_info.recolors
	
	var species = KeyBallsData.species
	var balls_to_exclude = []
	if species == KeyBallsData.Species.CAT:
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_cat.values())
		balls_to_exclude.append_array(KeyBallsData.nose_cat)
		balls_to_exclude.append_array(KeyBallsData.tongue_cat)
	elif species == KeyBallsData.Species.DOG:
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_dog.values())
		balls_to_exclude.append_array(KeyBallsData.nose_dog)
		balls_to_exclude.append_array(KeyBallsData.tongue_dog)
	else:
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.keys())
		balls_to_exclude.append_array(KeyBallsData.eyes_bab.values())
		balls_to_exclude.append_array(KeyBallsData.tongue_bab)

	if all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var section_find = search('[Ballz Info]', 0, 0, 0)
		if section_find:
			var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break
				
				var line = get_line(current_line_num)
				if line.begins_with("["): break

				if i in balls_to_exclude or line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue

				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 8:
					i += 1
					continue
				
				var color = parsed_line[0]
				var outline_color = parsed_line[1]
				var texture = parsed_line[7]
				var updates = {}

				for rule in recolor_rules:
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if not all_recolor_info.balls_on or not texture_match:
						continue

					var new_color = null
					if rule.is_ramp:
						new_color = _get_ramp_color(color, rule)
					else:
						var color_match = rule.before_color.empty() or rule.before_color == color
						if color_match and not rule.after_color.empty():
							new_color = rule.after_color
					
					if new_color != null:
						updates[0] = new_color
						if not rule.after_texture.empty():
							updates[7] = rule.after_texture
						break

				for rule in recolor_rules:
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if not all_recolor_info.ball_outlines_on or not texture_match:
						continue

					var new_outline_color = null
					if rule.is_ramp:
						new_outline_color = _get_ramp_color(outline_color, rule)
					else:
						var outline_color_match = rule.before_color.empty() or rule.before_color == outline_color
						if outline_color_match and not rule.after_color.empty():
							new_outline_color = rule.after_color
					
					if new_outline_color != null:
						updates[1] = new_outline_color
						break
				
				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)
				
				i += 1

	if all_recolor_info.paintballs_on or all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var addball_find = search('[Add Ball]', 0, 0, 0)
		var paintball_find = search('[Paint Ballz]', 0, 0, 0)

		if addball_find and (all_recolor_info.balls_on or all_recolor_info.ball_outlines_on):
			var start_of_section = addball_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break
				
				var line = get_line(current_line_num)
				if line.begins_with("["): break
				
				if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue

				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 14 or int(parsed_line[0]) in balls_to_exclude:
					i += 1
					continue
				
				var color = parsed_line[4]
				var outline_color = parsed_line[5]
				var texture = parsed_line[13]
				var updates = {}

				for rule in recolor_rules:
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if not all_recolor_info.balls_on or not texture_match:
						continue

					var new_color = null
					if rule.is_ramp:
						new_color = _get_ramp_color(color, rule)
					else:
						var color_match = rule.before_color.empty() or rule.before_color == color
						if color_match and not rule.after_color.empty():
							new_color = rule.after_color
					
					if new_color != null:
						updates[4] = new_color
						if not rule.after_texture.empty():
							updates[13] = rule.after_texture
						break

				for rule in recolor_rules:
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if not all_recolor_info.ball_outlines_on or not texture_match:
						continue

					var new_outline_color = null
					if rule.is_ramp:
						new_outline_color = _get_ramp_color(outline_color, rule)
					else:
						var outline_color_match = rule.before_color.empty() or rule.before_color == outline_color
						if outline_color_match and not rule.after_color.empty():
							new_outline_color = rule.after_color
					
					if new_outline_color != null:
						updates[5] = new_outline_color
						break

				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)
				
				i += 1

		if paintball_find and all_recolor_info.paintballs_on:
			var start_of_section = paintball_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break

				var line = get_line(current_line_num)
				if line.begins_with("["): break

				if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue
				
				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 11 or int(parsed_line[0]) in balls_to_exclude:
					i += 1
					continue

				var color = parsed_line[5]
				var texture = parsed_line[10]
				var updates = {}
				
				for rule in recolor_rules:
					var texture_match = rule.before_texture.empty() or rule.before_texture == texture
					if not texture_match:
						continue

					var new_color = null
					if rule.is_ramp:
						new_color = _get_ramp_color(color, rule)
					else:
						var color_match = rule.before_color.empty() or rule.before_color == color
						if color_match and not rule.after_color.empty():
							new_color = rule.after_color
					
					if new_color != null:
						updates[5] = new_color
						if not rule.after_texture.empty():
							updates[10] = rule.after_texture
						break

				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)

				i += 1

	if all_recolor_info.lines_on:
		var section_find = search('[Linez]', 0, 0, 0)
		if section_find:
			var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
			var i = 0
			while true:
				var current_line_num = start_of_section + i
				if current_line_num >= get_line_count(): break
				
				var line = get_line(current_line_num)
				if line.begins_with("["): break
				
				if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
					i += 1
					continue

				var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
				var parsed_line = _split_and_clean(line, delimiter)
				
				if parsed_line.size() < 6:
					i += 1
					continue
				
				var mainColor = parsed_line[3]
				var lColor = parsed_line[4]
				var rColor = parsed_line[5]
				var updates = {}
				
				for rule in recolor_rules:
					if not rule.before_texture.empty(): continue

					var new_color = null
					if rule.is_ramp:
						new_color = _get_ramp_color(mainColor, rule)
					else:
						var color_match = rule.before_color.empty() or rule.before_color == mainColor
						if color_match and not rule.after_color.empty():
							new_color = rule.after_color
					
					if new_color != null:
						updates[3] = new_color
						break

				for rule in recolor_rules:
					if not rule.before_texture.empty(): continue
					
					var new_color = null
					if rule.is_ramp:
						new_color = _get_ramp_color(lColor, rule)
					else:
						var color_match = rule.before_color.empty() or rule.before_color == lColor
						if color_match and not rule.after_color.empty():
							new_color = rule.after_color
					
					if new_color != null:
						updates[4] = new_color
						break

				for rule in recolor_rules:
					if not rule.before_texture.empty(): continue
					
					var new_color = null
					if rule.is_ramp:
						new_color = _get_ramp_color(rColor, rule)
					else:
						var color_match = rule.before_color.empty() or rule.before_color == rColor
						if color_match and not rule.after_color.empty():
							new_color = rule.after_color
					
					if new_color != null:
						updates[5] = new_color
						break
				
				if not updates.empty():
					var final_line = _update_fields(parsed_line, updates, delimiter)
					set_line(current_line_num, final_line)

				i += 1

	var section_find = search('[256 Eyelid Color]', 0, 0, 0)
	if section_find:
		var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
		var i = 0
		while true:
			var current_line_num = start_of_section + i
			if current_line_num >= get_line_count(): break
			
			var line = get_line(current_line_num)
			if line.begins_with("["): break
			
			if line.lstrip(" ").begins_with(";") or line.strip_edges().empty():
				i += 1
				continue

			var delimiter = _detect_delimiter(current_line_num, current_line_num + 1)
			var parsed_line = _split_and_clean(line, delimiter)
			
			if parsed_line.size() < 2:
				i += 1
				continue
			
			var l_color = parsed_line[0]
			var r_color = parsed_line[1]
			var updates = {}
			
			for rule in recolor_rules:
				if not rule.before_texture.empty(): continue

				var new_color = null
				if rule.is_ramp:
					new_color = _get_ramp_color(l_color, rule)
				else:
					var color_match = rule.before_color.empty() or rule.before_color == l_color
					if color_match and not rule.after_color.empty():
						new_color = rule.after_color
				
				if new_color != null:
					updates[0] = new_color
					break

			for rule in recolor_rules:
				if not rule.before_texture.empty(): continue
				
				var new_color = null
				if rule.is_ramp:
					new_color = _get_ramp_color(r_color, rule)
				else:
					var color_match = rule.before_color.empty() or rule.before_color == r_color
					if color_match and not rule.after_color.empty():
						new_color = rule.after_color
				
				if new_color != null:
					updates[1] = new_color
					break
			
			if not updates.empty():
				var final_line = _update_fields(parsed_line, updates, delimiter)
				set_line(current_line_num, final_line)

			i += 1
				
	save_file()

## Mirror (Copy L to R) Helper Functions

func _mirror_ball_attributes(parts: PoolStringArray, is_addball: bool) -> Dictionary:
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

func _build_ball_map_for_mirror(left_balls_list: Array, middle_balls_list: Array, right_balls_list: Array) -> Dictionary:
	var new_ball_map = {}
	var ballz_bounds = _get_section_bounds("[Ballz Info]")
	var delim = _detect_delimiter(ballz_bounds.start, ballz_bounds.end)

	for i in range(ballz_bounds.start, ballz_bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("["):
			continue

		var ball_no = _get_line_no_from_line_index(i, "[Ballz Info]")
		if ball_no == -1: continue

		var entry = {"line": line, "new_ball_no": ball_no, "corresponding_ball": null}

		if ball_no in left_balls_list:
			var right_ball_no = get_corresponding_right_ball(ball_no)
			entry.corresponding_ball = right_ball_no

			var parts = _split_and_clean(line, delim)
			var mirrored_attrs = _mirror_ball_attributes(parts, false)
			var mirrored_line = _update_fields(parts, mirrored_attrs, delim)

			var right_ball_line_idx = find_line_in_ball_section(right_ball_no)
			set_line(right_ball_line_idx, mirrored_line)

			new_ball_map[right_ball_no] = {"line": mirrored_line, "corresponding_ball": ball_no, "new_ball_no": right_ball_no}

		new_ball_map[ball_no] = entry

	# Process Addballz
	var addball_bounds = _get_section_bounds("[Add Ball]")
	if !addball_bounds.empty():
		var delim_addball = _detect_delimiter(addball_bounds.start, addball_bounds.end)
		var current_addball_no = KeyBallsData.max_base_ball_num
		var new_ball_count = KeyBallsData.max_base_ball_num
		var balls_to_add_temp = []

		for i in range(addball_bounds.start, addball_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";") or line.begins_with("["):
				continue

			var parts = _split_and_clean(line, delim_addball)
			var base_ball = parts[0].to_int()

			if base_ball in right_balls_list:
				# Skip right-side addballs; they will be created by mirroring left-side ones.
				current_addball_no += 1
				continue

			var is_left_side = base_ball in left_balls_list
			var is_center_side = base_ball in middle_balls_list
			var x_pos = parts[1].to_float()

			if is_left_side or (is_center_side and x_pos >= 0):
				# This is a left or center-left addball that needs to be kept and mirrored.
				new_ball_map[current_addball_no] = {"line": line, "new_ball_no": new_ball_count}
				if is_left_side:
					left_balls_list.append(current_addball_no)
				new_ball_count += 1

				var mirrored_attrs = _mirror_ball_attributes(parts, true)
				var mirrored_line_parts = _split_and_clean(line, delim_addball)

				var right_base_ball = get_corresponding_right_ball(base_ball)
				mirrored_line_parts[0] = str(right_base_ball)
				mirrored_line_parts[1] = mirrored_attrs[1]
				if mirrored_attrs.has(9):
					mirrored_line_parts[9] = mirrored_attrs[9]

				var mirrored_line = _join_array(mirrored_line_parts, delim_addball)
				balls_to_add_temp.append({"line": mirrored_line, "corresponding_ball": current_addball_no})

			elif is_center_side and x_pos < 0:
				# This is a right-side addball on a center ball; skip it.
				pass

			else: # Is a center ball with x_pos = 0 or a utility addball
				new_ball_map[current_addball_no] = {"line": line, "new_ball_no": new_ball_count}
				middle_balls_list.append(current_addball_no)
				new_ball_count += 1

			current_addball_no += 1

		# Add the newly created mirrored addballs to the map
		var max_current_ball = new_ball_map.keys().max()
		if max_current_ball == null:
			max_current_ball = KeyBallsData.max_base_ball_num - 1
			
		var add_count = max_current_ball + 1
		
		for b in balls_to_add_temp:
			b.new_ball_no = new_ball_count
			new_ball_map[add_count] = b
			new_ball_map[b.corresponding_ball].corresponding_ball = add_count
			add_count += 1
			new_ball_count += 1

	return new_ball_map

func _process_section_for_mirror(section_name: String, line_processor, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary) -> Array:
	var results = []
	var bounds = _get_section_bounds(section_name)
	if bounds.empty():
		return results

	var delim = _detect_delimiter(bounds.start, bounds.end)

	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("["):
			continue

		var parts = _split_and_clean(line, delim)
		if parts.empty():
			continue

		var processed_lines = line_processor.call_func(parts, left_balls_list, middle_balls_list, ball_map, delim)
		results.append_array(processed_lines)

	return results

func _mirror_linez_processor(parts: PoolStringArray, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var start_ball = parts[0].to_int()
	var end_ball = parts[1].to_int()

	if not ball_map.has(start_ball) or not ball_map.has(end_ball):
		return [] # Skip lines with balls that were removed

	var is_left = start_ball in left_balls_list or end_ball in left_balls_list
	var is_middle = start_ball in middle_balls_list and end_ball in middle_balls_list

	# Update original line with new ball numbers
	var updated_parts = Array(parts)
	updated_parts[0] = str(ball_map[start_ball].new_ball_no)
	updated_parts[1] = str(ball_map[end_ball].new_ball_no)
	processed_lines.append(_join_array(updated_parts, delim))

	if is_left:
		# Create mirrored line
		var mirrored_parts = Array(parts)
		var mirrored_start = ball_map.get(start_ball, {}).get("corresponding_ball", ball_map[start_ball].new_ball_no)
		var mirrored_end = ball_map.get(end_ball, {}).get("corresponding_ball", ball_map[end_ball].new_ball_no)

		mirrored_parts[0] = str(mirrored_start)
		mirrored_parts[1] = str(mirrored_end)
		processed_lines.append(_join_array(mirrored_parts, delim))

	return processed_lines

func _mirror_move_processor(parts: PoolStringArray, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var move_ball = parts[0].to_int()

	if move_ball in left_balls_list:
		processed_lines.append(_join_array(parts, delim)) # Keep original

		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(get_corresponding_right_ball(move_ball))
		mirrored_parts[1] = str(parts[1].to_float() * -1.0)
		if parts.size() > 4:
			mirrored_parts[4] = str(_find_mirrored_ball(parts[4].to_int()))
		processed_lines.append(_join_array(mirrored_parts, delim))

	elif move_ball in middle_balls_list:
		processed_lines.append(_join_array(parts, delim))

	return processed_lines

func _mirror_projection_processor(parts: PoolStringArray, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var base_ball = parts[0].to_int()
	var move_ball = parts[1].to_int()

	# Remap original line
	var updated_parts = Array(parts)
	updated_parts[0] = str(ball_map.get(base_ball, {"new_ball_no": base_ball}).new_ball_no)
	updated_parts[1] = str(ball_map.get(move_ball, {"new_ball_no": move_ball}).new_ball_no)
	processed_lines.append(_join_array(updated_parts, delim))

	if move_ball in left_balls_list:
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(_find_mirrored_ball(base_ball))
		mirrored_parts[1] = str(_find_mirrored_ball(move_ball))
		processed_lines.append(_join_array(mirrored_parts, delim))

	return processed_lines

func _mirror_paintball_processor(parts: PoolStringArray, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var base_ball = parts[0].to_int()
	var x_pos = parts[2].to_float()

	if not ball_map.has(base_ball):
		return []

	# Update original line
	var updated_parts = Array(parts)
	updated_parts[0] = str(ball_map[base_ball].new_ball_no)
	processed_lines.append(_join_array(updated_parts, delim))

	if base_ball in left_balls_list or (base_ball in middle_balls_list and x_pos > 0):
		# Create mirrored line
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(_find_mirrored_ball(base_ball))
		mirrored_parts[2] = str(x_pos * -1.0)
		processed_lines.append(_join_array(mirrored_parts, delim))

	return processed_lines

func _replace_section_content(section_name: String, new_lines: Array):
	var bounds = _get_section_bounds(section_name)
	if bounds.empty() and new_lines.empty():
		return # Nothing to do

	if bounds.empty():
		# Create the section if it doesn't exist
		var first_section_line = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section_line, section_name)
		all_lines.insert(first_section_line + 1, "")
		_set_text_preserve(all_lines.join("\n"))
		bounds = _get_section_bounds(section_name)

	var start_line = bounds.start
	var end_line = bounds.end

	# Clear existing content
	if start_line < end_line:
		select(start_line, 0, end_line, 0)
		cut()

	if not new_lines.empty():
		# Use a Set to store unique lines
		var unique_lines = []
		var seen_lines = {} # Using a dictionary as a hash set for faster lookups
		for line in new_lines:
			if not seen_lines.has(line):
				unique_lines.append(line)
				seen_lines[line] = true

		var final_text = _join_array(unique_lines, "\n")
		if not final_text.empty():
			final_text += "\n"

		_insert_text_at_cursor_at_line(start_line, final_text)

func _on_ToolsMenu_move_head(x, y, z):
	save_backup()
	var head_balls: Array
	if KeyBallsData.species == KeyBallsData.Species.CAT:
		head_balls = KeyBallsData.head_ext_cat.duplicate()
	else:
		head_balls = KeyBallsData.head_ext_dog.duplicate()
	var section_find = search('[Move]', 0, 0, 0)
	var start_of_section = section_find[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start_of_section + i).lstrip(" ")
		if line.begins_with(";") or line.empty():
			i += 1
			continue
		elif line.begins_with("["):
			break
			
		# var parsed_line = r.search_all(line)
		var delimiters = [", ", ",", "\t", " "]
		var parsed_line = []
		for delim in delimiters:
			if line.split(delim).size() > 2:
				parsed_line = line.split(delim, false)
				break

		if !(parsed_line[0].to_int() in head_balls):
			i += 1
			continue
		head_balls.erase(parsed_line[0].to_int())
		var n = 0
		var final_line = ""
		for r_item in parsed_line:
			var item = r_item
			if n == 1:
				final_line += str(item.to_int() + x) + " "
			elif n == 2:
				final_line += str(item.to_int() + y) + " "
			elif n == 3:
				final_line += str(item.to_int() + z) + " "
			else:
				final_line += item + " "
			n += 1
		set_line(start_of_section + i, final_line)
		i += 1
	
	# now insert any we missed
	for b in head_balls:
		cursor_set_line(start_of_section + i)
		cursor_set_column(0)
		insert_text_at_cursor(str(b) + " " + str(x) + " " + str(y) + " " + str(z) + "\n")
	
	save_file()

func get_project_ball_section() -> Array:
	var projections = []
	var bounds = _get_section_bounds("[Project Ball]")
	if bounds.empty():
		return projections

	var start_line = bounds["start"]
	var end_line = bounds["end"]

	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue

		var comment = ""
		if line.find(";") != -1:
			comment = line.substr(line.find(";") + 1).strip_edges()
			line = line.substr(0, line.find(";")).strip_edges()

		var parts = _split_and_clean(line)
		if parts.empty():
			continue

		if parts.size() >= 3:
			if parts.size() == 3:
				var amount = int(parts[2])
				projections.append({
					"fixed_ball": int(parts[0]),
					"project_ball": int(parts[1]),
					"min_projection": amount - 50,
					"max_projection": amount + 50,
					"comment": comment
				})
			elif parts.size() >= 4:
				projections.append({
					"fixed_ball": int(parts[0]),
					"project_ball": int(parts[1]),
					"min_projection": int(parts[2]),
					"max_projection": int(parts[3]),
					"comment": comment
				})
	return projections

func write_project_ball_section(projections: Array):
	save_backup()
	var bounds = _get_section_bounds("[Project Ball]")
	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Project Ball]")
		all_lines.insert(first_section + 1, "")
		text = all_lines.join("\n")
		_set_text_preserve(text)
		bounds = _get_section_bounds("[Project Ball]")

	var start_line = bounds["start"]
	var end_line = bounds["end"]

	var existing_lines = []
	if start_line < end_line:
		for i in range(start_line, end_line):
			existing_lines.append(get_line(i))

	var output_lines = existing_lines.duplicate()
	var new_lines_to_prepend = []
	var processed_indices = []

	for proj in projections:
		var found_match = false
		for i in range(existing_lines.size()):
			var line = existing_lines[i]
			var line_strip = line.strip_edges()
			if line_strip.empty() or line_strip.begins_with(";"):
				continue

			var line_parts = line_strip.split(";")
			var data_part = line_parts[0].strip_edges()
			var parts = _split_and_clean(data_part)

			# var parts = []
			# var delim = " " # Default to space
			
			# if data_part.find(",") != -1:
			# 	parts = data_part.split(",", false)
			# 	delim = ","
			# elif data_part.find("\t") != -1:
			# 	parts = data_part.split("\t", false)
			# 	delim = "\t"
			# else:
			# 	parts = data_part.split(" ", false)
			# 	delim = " "

			# for j in range(parts.size()):
			# 	parts[j] = parts[j].strip_edges()

			if parts.size() >= 2 and parts[0] == str(proj.fixed_ball) and parts[1] == str(proj.project_ball):
				var line_text = str(proj.fixed_ball) + " " + str(proj.project_ball) + " " + str(proj.value)
				if proj.has("comment") and not proj.comment.empty():
					line_text += " ;" + proj.comment
				output_lines[i] = line_text
				processed_indices.append(i)
				found_match = true
				break

		if not found_match:
			var line_text = str(proj.fixed_ball) + " " + str(proj.project_ball) + " " + str(proj.value)
			if proj.has("comment") and not proj.comment.empty():
				line_text += " ;" + proj.comment
			new_lines_to_prepend.append(line_text)

	# Clear existing lines
	if start_line < end_line:
		select(start_line, 0, end_line, 0)
		cut()

	var final_text = ""
	for line in new_lines_to_prepend:
		final_text += line + "\n"
	for line in output_lines:
		final_text += line + "\n"

	_insert_text_at_cursor_at_line(start_line, final_text)
	save_file()

func update_lnz_section_one_value(section_name, val1):
	var bounds = _get_section_bounds(section_name)
	if bounds.empty():
		print("Section not found: " + section_name)
		return

	var start_line = bounds["start"]
	set_line(start_line, str(val1))

func update_lnz_section_two_values(section_name, val1, val2):
	var bounds = _get_section_bounds(section_name)
	if bounds.empty():
		print("Section not found: " + section_name)
		return

	var start_line = bounds["start"]
	var end_line = bounds["end"]

	var empty_cnt  = bounds.get("empty", 0)
	var data_cnt   = (end_line - start_line) - empty_cnt

	if data_cnt == 2:
		set_line(start_line, str(val1))
		set_line(start_line + 1, str(val2))
		return

	if data_cnt == 1:
		var delim = _detect_delimiter(start_line, end_line)
		var new_line = str(val1) + delim + str(val2)
		set_line(start_line, new_line)
		return

func _on_Node_ball_resized(ball_no: int, size_dif: int):
	var max_base_ball_no = KeyBallsData.max_base_ball_num
	var is_addball = ball_no >= max_base_ball_no

	var section_tag = "[Ballz Info]"
	var size_field_index = 5  # 6th field is size
	if is_addball:
		section_tag = "[Add Ball]"
		size_field_index = 10  # 11th field is size for addballs

	print("[LNZ EDIT] Resizing ball %d from section %s with size_dif = %d" % [ball_no, section_tag, size_dif])

	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return

	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]

	if end_line == -1:
		end_line = get_line_count()

	if is_addball:
		var addball_index = ball_no - max_base_ball_no
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			if count == addball_index:
				var parts = _split_and_clean(raw)
				if parts.size() > size_field_index:
					var old_size = parts[size_field_index].to_int()
					var new_size = size_dif
					print("[LNZ EDIT] [Add Ball] Resizing ball %d at line %d" % [ball_no, i])
					print("[LNZ EDIT] Old size = %d → New size = %d" % [old_size, new_size])
					parts[size_field_index] = str(new_size)
					var new_line = _join_array(parts, " ")
					set_line(i, new_line)
					print("[LNZ EDIT] Updated line: %s" % new_line)
					save_file()
					return
			count += 1
		print("[LNZ EDIT] No matching [Add Ball] line found for ball %d" % ball_no)
	else:
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			#print("[LNZ EDIT] Scanning line %d (count = %d): %s" % [i, count, raw])
			#print("[LNZ EDIT] Count reached = %d, looking for ball_no = %d" % [count, ball_no])
			if count == ball_no:
				var parts = _split_and_clean(raw)
				if parts.size() > size_field_index:
					var old_size = parts[size_field_index].to_int()
					var new_size = size_dif
					print("[LNZ EDIT] [Ballz Info] Resizing ball %d at line %d" % [ball_no, i])
					print("[LNZ EDIT] Old size = %d → New size = %d" % [old_size, new_size])
					parts[size_field_index] = str(new_size)
					var new_line = _join_array(parts, " ")
					set_line(i, new_line)
					print("[LNZ EDIT] Updated line: %s" % new_line)
					save_file()
					return
				else:
					print("[LNZ EDIT] Line has too few fields for resizing ball %d" % ball_no)
					return
			count += 1
		print("[LNZ EDIT] Ball %d not found in [Ballz Info]" % ball_no)

func _on_Node_ball_translation_changed(ball_no: int, new_pos: Vector3):
	save_backup()
	var is_addball = ball_no >= KeyBallsData.max_base_ball_num

	var section_tag = "[Move]"
	if is_addball:
		section_tag = "[Add Ball]"
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		print("[LNZ EDIT] No %s section found" % section_tag)
		return
	var start_line = sec[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	if end_line == -1:
		end_line = get_line_count()

	if is_addball:
		var pet_node = get_tree().root.get_node("Root/PetRoot/Node")
		var moved_ball_node = pet_node.ball_map.get(ball_no)
		if moved_ball_node:
			var base_ball_no = moved_ball_node.base_ball_no
			var base_ball_node = pet_node.ball_map.get(base_ball_no)
			if base_ball_node:
				var new_relative_pos = moved_ball_node.global_transform.origin - base_ball_node.global_transform.origin
				new_relative_pos /= (pet_node.pixel_world_size * (pet_node.lnz.scales.x / 255.0))
				new_relative_pos.y *= -1.0

				var idx = ball_no - KeyBallsData.max_base_ball_num
				var count = 0
				for i in range(start_line, end_line):
					var raw = get_line(i).strip_edges()
					if raw == "" or raw.begins_with(";"):
						continue
					if count == idx:
						var parts = _split_and_clean(raw)
						if parts.size() >= 4:
							parts[1] = str(round(new_relative_pos.x))
							parts[2] = str(round(new_relative_pos.y))
							parts[3] = str(round(new_relative_pos.z))
							var new_line = _join_array(parts, " ")
							set_line(i, new_line)
						break
					count += 1
	else:
		var updated = false
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"):
				continue
			var parts = _split_and_clean(raw)
			if parts.size() >= 4 and parts[0].to_int() == ball_no:
				parts[1] = str(parts[1].to_int() + new_pos.x)
				parts[2] = str(parts[2].to_int() + new_pos.y)
				parts[3] = str(parts[3].to_int() + new_pos.z)
				var new_line = _join_array(parts, " ")
				set_line(i, new_line)
				print("[LNZ EDIT] Summed [Move] line at %d: %s" % [i, new_line])
				updated = true
				break
		if not updated:
			var sep = " "
			var line_txt = "%d%s%d%s%d%s%d" % [
				ball_no, sep,
				new_pos.x, sep,
				new_pos.y, sep,
				new_pos.z
			]
			var insert_at = end_line
			while insert_at > start_line and get_line(insert_at - 1).strip_edges() == "":
				insert_at -= 1
			_insert_text_at_cursor_at_line(insert_at, line_txt + "\n")
			print("[LNZ EDIT] Inserting new [Move] line at %d: %s" % [insert_at, line_txt])
	save_file()

func _escape_regex(pattern_str: String) -> String:
	var special_chars = ".+*?()[]{}|^$\\/"
	var escaped_str = ""
	for this_char in pattern_str:
		if special_chars.find(this_char) != -1:
			escaped_str += "\\"
		escaped_str += this_char
	return escaped_str

func _pos_to_offset(line: int, col: int) -> int:
	var offset = 0
	for i in range(line):
		offset += get_line(i).length() + 1 # +1 for newline character
	offset += col
	return offset

func _offset_to_pos(offset: int) -> Vector2:
	var current_offset = 0
	for line_num in range(get_line_count()):
		var line_len = get_line(line_num).length() + 1 # +1 for newline
		if current_offset + line_len > offset:
			var col = offset - current_offset
			return Vector2(col, line_num) # x=col, y=line
		current_offset += line_len
	# If offset is at the very end of the file
	var last_line = get_line_count() - 1
	if last_line < 0: return Vector2(0,0)
	var col_on_last_line = offset - current_offset
	return Vector2(col_on_last_line, last_line)

func _on_menu_id_pressed(id):
	if id == 100: # Find/Replace
		find_panel.show()
		self.readonly = true
	elif id == 101: # Toggle Comment
		_toggle_comment()

func _on_NotificationTimer_timeout():
	var wrap_notification_label = find_panel.get_node("VBoxContainer/WrapNotificationLabel")
	wrap_notification_label.hide()

func _on_FindCloseButton_pressed():
	find_panel.hide()
	self.readonly = false
	_setup_context_menu()

func _on_FindNextButton_pressed():
	_find_text(true)

func _on_FindPrevButton_pressed():
	_find_text(false)

func _on_ReplaceButton_pressed():
	var find_line_edit = find_panel.get_node("VBoxContainer/LineEdit")
	var replace_line_edit = find_panel.get_node("VBoxContainer/ReplaceLineEdit")
	var search_text = find_line_edit.text
	var replace_text = replace_line_edit.text

	if search_text.empty():
		return

	if is_selection_active():
		var selected_text = get_selection_text()

		var pattern = _escape_regex(search_text)
		if find_panel.get_node("VBoxContainer/HBoxContainer/WholeWordsCheckBox").pressed:
			pattern = "\\b" + pattern + "\\b"

		if !find_panel.get_node("VBoxContainer/HBoxContainer/MatchCaseCheckBox").pressed:
			pattern = "(?i)" + pattern

		# Anchor the pattern to ensure the whole selection matches
		var anchored_pattern = "^" + pattern + "$"

		var regex = RegEx.new()
		
		var error = regex.compile(anchored_pattern) 

		if error == OK:
			var this_match = regex.search(selected_text, 0) 
			if this_match != null:
				self.readonly = false
				insert_text_at_cursor(replace_text)
				self.readonly = true

	# After attempting a replace, find the next occurrence.
	_find_text(true)


func _on_ReplaceAllButton_pressed():
	var find_line_edit = find_panel.get_node("VBoxContainer/LineEdit")
	var replace_line_edit = find_panel.get_node("VBoxContainer/ReplaceLineEdit")
	var search_text = find_line_edit.text
	var replace_text = replace_line_edit.text

	if search_text.empty():
		return

	var pattern = _escape_regex(search_text)
	if find_panel.get_node("VBoxContainer/HBoxContainer/WholeWordsCheckBox").pressed:
		pattern = "\\b" + pattern + "\\b"

	if !find_panel.get_node("VBoxContainer/HBoxContainer/MatchCaseCheckBox").pressed:
		pattern = "(?i)" + pattern

	var regex = RegEx.new()
	
	# compile() only takes 1 argument
	var error = regex.compile(pattern) 
	if error != OK:
		find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2)) # Invalid Regex
		return
	else:
		find_line_edit.add_color_override("font_color", Color(1, 1, 1, 1))

	self.readonly = false

	if is_selection_active():
		var sel_from_line = get_selection_from_line()
		var sel_from_col = get_selection_from_column()
		var sel_to_line = get_selection_to_line()
		var sel_to_col = get_selection_to_column()

		var selection_text = get_selection_text()
		var matches = regex.search_all(selection_text)

		# Iterate backwards to not mess up offsets
		for i in range(matches.size() - 1, -1, -1):
			var this_match = matches[i]
			selection_text = selection_text.substr(0, this_match.get_start()) + replace_text + selection_text.substr(this_match.get_end())

		if get_selection_text() != selection_text:
			deselect()
			select(sel_from_line, sel_from_col, sel_to_line, sel_to_col)
			insert_text_at_cursor(selection_text)

	else:
		var original_text = self.text
		var matches = regex.search_all(original_text) 
		var new_text = original_text

		# Iterate backwards
		for i in range(matches.size() - 1, -1, -1):
			var this_match = matches[i]
			new_text = new_text.substr(0, this_match.get_start()) + replace_text + new_text.substr(this_match.get_end())

		if original_text != new_text:
			_set_text_preserve(new_text)

	self.readonly = true


func _find_text(forward):
	var find_line_edit = find_panel.get_node("VBoxContainer/LineEdit")
	var search_text = find_line_edit.text
	if search_text.empty():
		return

	var wrap_notification_label = find_panel.get_node("VBoxContainer/WrapNotificationLabel")
	var notification_timer = find_panel.get_node("NotificationTimer")
	wrap_notification_label.hide()
	find_line_edit.add_color_override("font_color", Color(1, 1, 1, 1))

	var all_text = self.text
	if all_text.empty():
		find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2))
		return

	var pattern = _escape_regex(search_text)
	if find_panel.get_node("VBoxContainer/HBoxContainer/WholeWordsCheckBox").pressed:
		pattern = "\\b" + pattern + "\\b"

	if !find_panel.get_node("VBoxContainer/HBoxContainer/MatchCaseCheckBox").pressed:
		pattern = "(?i)" + pattern

	var regex = RegEx.new()
	var error = regex.compile(pattern)
	if error != OK:
		find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2)) # Invalid Regex
		return

	var all_matches = regex.search_all(all_text)
	if all_matches.size() == 0:
		find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2)) # Not found
		return

	var result = null
	var wrapped = false

	if forward:
		var start_offset
		if is_selection_active():
			# If selected, start search AFTER the selection
			start_offset = _pos_to_offset(get_selection_to_line(), get_selection_to_column())
		else:
			# If no selection, start search AFTER the cursor
			start_offset = _pos_to_offset(cursor_get_line(), cursor_get_column()) + 1
			
		var best_match = null
		# Find the first match *at or after* our starting point
		for this_match in all_matches:
			if this_match.get_start() >= start_offset:
				best_match = this_match
				break
		
		result = best_match
		if result == null: # Wrap search
			if all_matches.size() > 0:
				result = all_matches[0]
				wrapped = true

	else: # Backward
		var start_offset
		if is_selection_active():
			# If selected, start search BEFORE the selection
			start_offset = _pos_to_offset(get_selection_from_line(), get_selection_from_column())
		else:
			# If no selection, start search BEFORE the cursor
			start_offset = _pos_to_offset(cursor_get_line(), cursor_get_column())

		var best_match = null
		# Find the last match *before* our starting point
		for this_match in all_matches:
			if this_match.get_start() < start_offset:
				best_match = this_match
			else:
				break
		
		result = best_match
		if result == null: # Wrap search
			if all_matches.size() > 0:
				result = all_matches[all_matches.size() - 1]
				wrapped = true

	if result != null:
		if wrapped:
			wrap_notification_label.show()
			notification_timer.start()
			
		var start_pos = _offset_to_pos(result.get_start())
		var end_pos = _offset_to_pos(result.get_end())

		var start_col = int(start_pos.x)
		var start_line = int(start_pos.y)
		var end_col = int(end_pos.x)
		var end_line = int(end_pos.y)

		cursor_set_line(start_line)
		cursor_set_column(start_col)
		center_viewport_to_cursor()
		select(start_line, start_col, end_line, end_col)
	else:
		find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2))

func _toggle_comment():
	# Get the selection range
	var start_line
	var end_line
	
	if is_selection_active():
		start_line = get_selection_from_line()
		end_line = get_selection_to_line()
		
		# If the selection ends at column 0 of a new line,
		# it shouldn't include that new line.
		if get_selection_to_column() == 0 and end_line > start_line:
			end_line -= 1
	else:
		# No selection, just use the current line
		start_line = cursor_get_line()
		end_line = cursor_get_line()

	var comment_prefix = "; "
	var lines_to_process = []
	var should_uncomment = true

	# We only uncomment if ALL non-empty selected lines are already commented.
	for i in range(start_line, end_line + 1):
		var line_text = get_line(i)
		
		# Skip empty lines
		if line_text.strip_edges().empty():
			continue
		
		lines_to_process.append(i)
		var stripped_line = line_text.lstrip(" \t")
		
		if not stripped_line.begins_with(comment_prefix):
			should_uncomment = false

	if lines_to_process.empty():
		return # Nothing to do

	if should_uncomment:
		# --- UNCOMMENT ---
		for i in lines_to_process:
			var line_text = get_line(i)
			# Find the indentation
			var indent_len = line_text.length() - line_text.lstrip(" \t").length()
			var indent = line_text.substr(0, indent_len)
			var content = line_text.lstrip(" \t")
			
			# Remove the prefix
			var new_line = indent + content.substr(comment_prefix.length())
			set_line(i, new_line)
	else:
		# --- COMMENT ---
		for i in lines_to_process:
			var line_text = get_line(i)
			# Find the indentation
			var indent_len = line_text.length() - line_text.lstrip(" \t").length()
			var indent = line_text.substr(0, indent_len)
			var content = line_text.lstrip(" \t")
			
			# Add the prefix, preserving indentation
			var new_line = indent + comment_prefix + content
			set_line(i, new_line)

	# Restore selection to cover the lines we just modified
	deselect()
	select(start_line, 0, end_line, get_line(end_line).length())