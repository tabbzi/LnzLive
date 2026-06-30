extends TextEdit

# LnzTextEdit.gd
# - Loads and saves .lnz files
# - Creates automatic backups before overwriting
# - Preserves scroll and cursor positions across edits
# - Listens for visual editor events
# - Finds and updates the corresponding LNZ sections
# - Handles batch recolor and mirror‐copy operations
# - Emits signals for file_saved, file_backed_up, and find_ball actions

# SECTIONS:
#	SETUP & INITIALIZATION
#	SIGNAL CALLBACKS
#	FILE SAVING & LOADING
#	UNDO / REDO HISTORY
#	TEXT EDITOR
#	FIND & REPLACE
#	LNZ TEXT FINDING
#	LNZ TEXT PARSING
#	LNZ TEXT EDITING
#	LNZ DATA GETTERS
#	LNZ DATA SETTERS
#	VISUAL NODE SIGNALS
#	TOOLS MENU SIGNALS
#	MIRRORING & SYMMETRY
#	BATCH OPERATIONS
#	HELPER FUNCTIONS

onready var file_tree = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
onready var lnz_text_edit = self
onready var pet_view = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
onready var pet_node = get_tree().root.get_node("Root/PetRoot/Node")

var px_scale: float setget , get_px_scale
var lnz_scale: float setget , get_lnz_scale

onready var camera_holder = get_tree().root.get_node(
	"Root/SceneRoot/ViewportContainer/Viewport/CameraHolder"
) as Spatial

onready var frame_slider = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/AnimationContainer/FrameSlider"
) as HSlider

onready var console_log = pet_view.find_node("ConsoleLog", true, false)
onready var apply_changes_button = pet_view.find_node("ApplyChangesButton", true, false)

onready var find_panel = get_node("../FindPanel")

var is_user_file = false
var filepath: String

var _split_regex: RegEx = RegEx.new()
var _search_regex: RegEx = RegEx.new()
var _last_compiled_pattern: String = ""

var set_column_popup: ConfirmationDialog
var col_input
var val_input

var bookmarks: Array = []

var history_stack: Array = []
var history_index: int = -1
var max_history_size: int = 25
var last_commit_time: int = 0
var last_commit_action: String = ""
var last_commit_id: int = -1

class HistoryItem extends Reference:
	enum Type { SNAPSHOT, LOGICAL }
	var type: int
	var action_name: String
	
	var full_text: String
	var cursor_line: int
	var cursor_col: int
	var v_scroll: float
	var h_scroll: float
	
	var target_section: String
	var target_id: int 
	var old_line_data: String
	var new_line_data: String

	var cached_line_index: int = -1

var ball_map = {}

signal file_saved(filepath)
signal find_ball(ball_no)
signal find_line(line_no)
signal find_paintball(line_no)
signal find_polygon(line_no)
signal find_move(line_no)
signal find_project_ball(line_no)
signal file_backed_up()

signal create_polygon

signal ball_number_changed(ball_no)

var max_move_head = 60

enum FilterMode { EXCLUDE, INCLUDE }

### SETUP & INITIALIZATION ###
# _safe_connect
# _ready
# _setup_context_menu
# _setup_set_column_popup
# initialize_history
# get_px_scale
# get_lnz_scale

func _safe_connect(target, sig, method):
	if target and target.has_signal(sig) and not target.is_connected(sig, self, method):
		target.connect(sig, self, method)

func _ready():
	_setup_context_menu()

	_split_regex.compile("[\\s,]+")

	wrap_enabled = false

	var user_settings = get_tree().root.get_node_or_null("Root/SceneRoot")
	if user_settings and user_settings.has_signal("global_font_updated"):
		_safe_connect(user_settings, "global_font_updated", "_on_global_font_updated")

	if apply_changes_button:
		apply_changes_button.connect("pressed", self, "_on_ApplyChangesButton_pressed")

	self.connect("cursor_changed", self, "_on_cursor_changed")
	
	add_color_region("[","]",Color(0.247119, 0.691406, 0.691406), false)
	add_color_region(";","",Color(0.168627, 0.45098, 0.45098), false)

	if pet_node:
		for s in ["ball_resized", "ball_moved", "addball_created", "line_created"]:
			if not pet_node.is_connected(s, self, "_on_Node_" + s):
				pet_node.connect(s, self, "_on_Node_" + s)

	if file_tree:
		var tree_node = file_tree.get_node("Tree") if file_tree.has_node("Tree") else file_tree
		_safe_connect(tree_node, "palette_selected", "_on_palette_selected")
		_safe_connect(tree_node, "example_file_selected", "_on_example_file_selected")

	var search_input = find_panel.get_node("VBoxContainer/LineEdit")
	if not search_input.is_connected("text_entered", self, "_on_FindNextButton_pressed"):
		search_input.connect("text_entered", self, "_on_FindNextButton_pressed")

	_update_section_bookmarks()
	_setup_set_column_popup()

func _setup_context_menu():
	var menu = get_menu()
	if not menu.is_connected("id_pressed", self, "_on_menu_id_pressed"):
		menu.connect("id_pressed", self, "_on_menu_id_pressed")
	if menu.get_item_index(100) == -1:
		menu.add_item("Find/Replace", 100)
	if menu.get_item_index(101) == -1:
		menu.add_item("Toggle Comment", 101)
	if menu.get_item_index(102) == -1:
		menu.add_item("Set Delimiter", 102)
	if menu.get_item_index(103) == -1:
		menu.add_item("Set Column in Selection", 103)

func _setup_set_column_popup():
	set_column_popup = ConfirmationDialog.new()
	set_column_popup.window_title = "Set Column Value"
	add_child(set_column_popup)
	
	var vbox = VBoxContainer.new()
	set_column_popup.add_child(vbox)
	
	var label_col = Label.new()
	label_col.text = "Column # (0-based):"
	vbox.add_child(label_col)
	
	col_input = LineEdit.new()
	col_input.placeholder_text = "e.g., 0 is 1st column"
	vbox.add_child(col_input)
	
	var label_val = Label.new()
	label_val.text = "New Value:"
	vbox.add_child(label_val)
	
	val_input = LineEdit.new()
	val_input.placeholder_text = "Enter value..."
	vbox.add_child(val_input)
	
	set_column_popup.connect("confirmed", self, "_on_set_column_confirmed")

func initialize_history():
	history_stack.clear()
	var item = HistoryItem.new()
	item.type = HistoryItem.Type.SNAPSHOT
	item.action_name = "Initial Load"
	item.full_text = self.text
	item.cursor_line = 0
	item.cursor_col = 0
	item.v_scroll = 0
	item.h_scroll = 0
	history_stack.append(item)
	history_index = 0

func get_px_scale() -> float:
	if not is_instance_valid(pet_node):
		return 0.002
	return pet_node.pixel_world_size

func get_lnz_scale() -> float:
	if not is_instance_valid(pet_node):
		return 1.0
	var lnz = pet_node.get("lnz")
	if not is_instance_valid(lnz):
		return 1.0
	if lnz is Dictionary:
		if not lnz.has("scales"):
			return 1.0
		return lnz.scales.x / 255.0
	return lnz.scales.x / 255.0


### SIGNAL CALLBACKS ###
# _on_NotificationTimer_timeout

func _on_NotificationTimer_timeout():
	var wrap_notification_label = find_panel.get_node("VBoxContainer/WrapNotificationLabel")
	wrap_notification_label.hide()


### FILE SAVING & LOADING ###
# _on_example_file_selected
# _on_user_file_selected
# save_backup
# save_file
# _on_Tree_backup_file
# _on_ApplyChangesButton_pressed

func _load_file(filepath: String, user_flag: bool):
	print("#".repeat(100))
	var t_start = OS.get_ticks_msec()

	if pet_node and pet_node.has_method("unhide_all_balls"):
		pet_node.unhide_all_balls()

	var file = File.new()
	var err = file.open(filepath, File.READ)
	if err != OK:
		printerr("Failed to open file: ", filepath, " Error: ", err)
		return

	var contents = file.get_as_text()
	file.close()

	if contents.strip_edges().empty() and self.text.strip_edges().empty():
		return

	self.filepath = filepath
	is_user_file = user_flag

	_set_text_preserve(contents)
	initialize_history()

	print("[TIME] LnzTextEdit: _load_file took " + str(OS.get_ticks_msec() - t_start) + "ms for " + filepath.get_file())


func _on_example_file_selected(filepath):
	_load_file(filepath, false)


func _on_user_file_selected(filepath):
	if filepath == null:
		return
	_load_file(filepath, true)


func save_backup():
	if not is_user_file:
		return

	var dir = Directory.new()
	var base_path = filepath.trim_suffix(".lnz")
	while base_path.ends_with("_backup_1") or base_path.ends_with("_backup_2") or base_path.ends_with("_backup_3"):
		base_path = base_path.trim_suffix("_backup_1").trim_suffix("_backup_2").trim_suffix("_backup_3")
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
	var err = file.open(backup_path1, File.WRITE)
	if err != OK:
		printerr("Failed to open backup file for writing: ", backup_path1)
		return
		
	file.store_string(text)
	file.close()

	if has_signal("file_backed_up"):
		emit_signal("file_backed_up")
		
	var msg = "Created Backup: " + backup_path1.get_file()
	print("[STATUS] LnzTextEdit: save_backup: " + msg)
	if console_log:
		console_log.log_message(msg)


func save_file(skip_history: bool = false, silent: bool = false):
	var t_start = OS.get_ticks_msec()

	if not silent:
		if text.strip_edges().empty():
			var msg = "No LNZ to save or load! Open example or paste LNZ into Text Editor first."
			print("[STATUS] LnzTextEdit: save_file: " + msg)
			if console_log:
				console_log.log_message(msg)
			return

		if not skip_history and history_index >= 0:
			var last_snap_idx = _find_nearest_snapshot(history_index)
			if last_snap_idx != -1:
				var last_snapshot = history_stack[last_snap_idx]
				if last_snapshot.full_text == self.text:
					var msg = "No changes detected! Skipping LNZ save..."
					print("[STATUS] LnzTextEdit: save_file: " + msg)
					if console_log:
						console_log.log_message(msg)
					return

		if not skip_history:
			commit_full_snapshot("User Save")

	if filepath == null or filepath.empty() or not is_user_file:
		var dir = Directory.new()
		dir.open("user://")
		dir.make_dir_recursive("resources")
		
		var base_name = "unnamed"
		if filepath:
			var source_file = filepath.get_file()
			if source_file.begins_with("res://"):
				base_name = source_file.trim_suffix(".lnz")
			else:
				base_name = source_file.trim_suffix(".lnz")
		
		var possible_file_name = "user://resources/" + base_name + ".lnz"
		if dir.file_exists(possible_file_name):
			possible_file_name = "user://resources/" + base_name + "_" + str(OS.get_unix_time()) + ".lnz"
		filepath = possible_file_name
		is_user_file = true

	var dir = Directory.new()
	dir.open("user://")
	dir.make_dir("resources")
	
	var file = File.new()
	var err = file.open(filepath, File.WRITE)

	if err != OK:
			printerr("Failed to open file for writing: ", filepath)
			return

	file.store_string(text)
	file.close()

	if not silent:
		var msg = "Saved LNZ and Applied Changes!"
		print("[STATUS] LnzTextEdit: save_file: " + msg)
		if console_log:
			console_log.log_message(msg)

		emit_signal("file_saved", filepath)
		_set_text_preserve(get_text()) 

	print("[TIME] LnzTextEdit: save_file took " + str(OS.get_ticks_msec() - t_start) + "ms for " + filepath.get_file())

func _on_Tree_backup_file():
	save_backup()

func _on_ApplyChangesButton_pressed():
	save_backup()
	save_file(false)


### UNDO / REDO HISTORY ###
# commit_full_snapshot
# commit_logical_change
# _trim_history_tail
# _check_history_size
# undo_visual_edit
# redo_visual_edit
# _find_nearest_snapshot
# _restore_snapshot
# _apply_logical_line

func commit_full_snapshot(action_name: String):
	if history_index >= 0:
		var last = history_stack[history_index]
		if last.type == HistoryItem.Type.SNAPSHOT and last.full_text == self.text:
			return

	_trim_history_tail()
	
	var item = HistoryItem.new()
	item.type = HistoryItem.Type.SNAPSHOT
	item.action_name = action_name
	item.full_text = self.text
	item.cursor_line = cursor_get_line()
	item.cursor_col = cursor_get_column()
	item.v_scroll = get_v_scroll()
	item.h_scroll = get_h_scroll()
	
	history_stack.append(item)
	history_index += 1
	_check_history_size()
	var msg = "[HISTORY] Snapshot Commit: %s" % action_name
	print(msg)
	if console_log:
		console_log.log_message(msg)

func commit_logical_change(action_name: String, section: String, id: int, old_line: String, new_line: String, line_idx: int = -1) -> bool:
	if line_idx == -1:
		return false 

	var current_time = OS.get_ticks_msec()

	if history_index >= 0:
		var last = history_stack[history_index]
		if last.type == HistoryItem.Type.LOGICAL and last.target_id == id and last.action_name == action_name:
			if (current_time - last_commit_time) < 300:
				last.new_line_data = new_line 
				last_commit_time = current_time
				return true

	_trim_history_tail()
	
	var item = HistoryItem.new()
	item.type = HistoryItem.Type.LOGICAL
	item.action_name = action_name
	item.target_section = section
	item.target_id = id
	item.old_line_data = old_line
	item.new_line_data = new_line
	item.cached_line_index = line_idx
	
	history_stack.append(item)
	history_index += 1
	_check_history_size()
	
	last_commit_time = current_time
	last_commit_action = action_name
	last_commit_id = id
	
	var msg = "[HISTORY] Logical Commit: %s (Ball %d, Line %d)" % [action_name, id, line_idx]
	print(msg)
	if console_log:
		console_log.log_message(msg)

	return true

func _trim_history_tail():
	if history_index < history_stack.size() - 1:
		history_stack = history_stack.slice(0, history_index)

func _check_history_size():
	if history_stack.size() > max_history_size:
		history_stack.pop_front()
		history_index -= 1

func undo_visual_edit():
	if history_index <= 0:
		print("[HISTORY] UNDO: Nothing to undo...")
		if console_log:
			console_log.log_message("[HISTORY] UNDO: Nothing to undo...")
		return
	
	var item_being_undone = history_stack[history_index] 
	
	history_index -= 1
	
	if item_being_undone.type == HistoryItem.Type.LOGICAL:
		_apply_logical_line(item_being_undone.target_section, item_being_undone.target_id, item_being_undone.old_line_data)
	else:
		var snapshot_idx = _find_nearest_snapshot(history_index)
		
		if snapshot_idx != -1:
			var snapshot = history_stack[snapshot_idx]
			_restore_snapshot(snapshot)
			
			for i in range(snapshot_idx + 1, history_index + 1):
				var log_item = history_stack[i]
				if log_item.type == HistoryItem.Type.LOGICAL:
					_apply_logical_line(log_item.target_section, log_item.target_id, log_item.new_line_data)
		else:
			var msg = "[HISTORY] WARNING: No snapshot found to restore"
			print(msg)
			if console_log:
				console_log.log_message(msg)

	var msg = "[HISTORY] UNDO: %s (ID: %d)" % [item_being_undone.action_name, history_index]
	print(msg)
	if console_log:
		console_log.log_message(msg)

	last_commit_action = ""
	
	save_file(true)

func redo_visual_edit():
	if history_index >= history_stack.size() - 1:
		var msg = "[HISTORY] REDO: Nothing to redo..."
		print(msg)
		if console_log:
			console_log.log_message(msg)
		return
	
	history_index += 1
	var item = history_stack[history_index]
	
	if item.type == HistoryItem.Type.SNAPSHOT:
		_restore_snapshot(item)
	else:
		_apply_logical_line(item.target_section, item.target_id, item.new_line_data)

	var msg = "[HISTORY] REDO: %s" % item.action_name
	print(msg)
	if console_log:
		console_log.log_message(msg)

	last_commit_action = ""
	
	save_file(true)

func _find_nearest_snapshot(from_index: int) -> int:
	var idx = from_index
	while idx >= 0:
		if history_stack[idx].type == HistoryItem.Type.SNAPSHOT:
			return idx
		idx -= 1
	return -1

func _restore_snapshot(item):
	self.text = item.full_text
	cursor_set_line(item.cursor_line)
	cursor_set_column(item.cursor_col)
	set_v_scroll(item.v_scroll)
	set_h_scroll(item.h_scroll)
	update()

func _apply_logical_line(section: String, id: int, line_content: String, cached_idx: int = -1):
	var line_idx = -1

	if cached_idx != -1 and cached_idx < get_line_count():
		var check_line = get_line(cached_idx).strip_edges()
		
		if not check_line.empty() and not check_line.begins_with(";"):
			var parts = split_line(check_line)
			var matches_cache = false
			
			if section in ["[Ballz Info]", "[Move]"]:
				if parts.size() > 0 and parts[0] == str(id):
					matches_cache = true
			elif section == "[Add Ball]":
				var relative = id
				if id >= KeyBallsData.max_base_ball_num:
					relative = id - KeyBallsData.max_base_ball_num
				if parts.size() > 0 and parts[0] == str(relative):
					matches_cache = true
			elif section == "[Linez]":
				if parts.size() >= 2 and (parts[0] == str(id) or parts[1] == str(id)):
					matches_cache = true
					
			if matches_cache:
				set_line(cached_idx, line_content)
				return

	if section == "[Ballz Info]":
		line_idx = find_line_in_ball_section(id)
	elif section == "[Add Ball]":
		var relative = id
		if id >= KeyBallsData.max_base_ball_num:
			relative = id - KeyBallsData.max_base_ball_num
		line_idx = find_line_in_addball_section(relative)
	elif section == "[Move]":
		line_idx = find_line_in_move_section(id)
	elif section == "[Project Ball]":
		line_idx = find_line_in_project_section(id)
	elif section == "[Linez]":
		line_idx = find_line_in_linez_section(id)
		
	if line_idx != -1:
		set_line(line_idx, line_content)
	else:
		var msg = "[HISTORY] No line found to apply change (%s #%d)" % [section, id]
		print(msg)
		if console_log:
			console_log.log_message(msg)


### TEXT EDITOR ###
# _unhandled_key_input
# _on_LnzTextEdit_gui_input
# _get_user_preferred_delimiter
# _update_section_bookmarks
# _on_cursor_changed
# _on_global_font_updated
# _on_AutowrapButton_pressed
# _on_FindReplaceButton_pressed
# _insert_text_at_cursor_at_line
# _insert_text_at_line
# _get_active_line_range
# _escape_regex
# _wrap_angle_deg
# _set_text_preserve
# _on_menu_id_pressed

func _unhandled_key_input(event):
	if Input.is_key_pressed(KEY_CONTROL) and event.pressed and event.scancode == KEY_S:
		save_file(false)

	if Input.is_key_pressed(KEY_CONTROL) and not event.shift and event.pressed:
		if event.scancode == KEY_Z:
			undo_visual_edit() # Ctrl+Z
		elif event.scancode == KEY_Y:
			redo_visual_edit() # Ctrl+Y

	if Input.is_key_pressed(KEY_CONTROL) and event.pressed and event.scancode == KEY_F:
		find_panel.visible = !find_panel.visible
		self.readonly = find_panel.visible

		if find_panel.visible:
			var search_input = find_panel.get_node("VBoxContainer/LineEdit")
			if search_input:
				search_input.grab_focus()

		_setup_context_menu()

func _on_LnzTextEdit_gui_input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_PAGEDOWN:
			var next = _get_next_section_line_idx(cursor_get_line() + 1)
			if next != -1:
				cursor_set_line(next)
				cursor_set_column(0)
				center_viewport_to_cursor()
				print("[JUMP] Next Section: ", next)
				accept_event()
				get_tree().set_input_as_handled()

		elif event.scancode == KEY_PAGEUP:
			var prev = _get_prev_section_line_idx(cursor_get_line() - 1)
			if prev != -1:
				cursor_set_line(prev)
				cursor_set_column(0)
				center_viewport_to_cursor()
				print("[JUMP] Prev Section: ", prev)
				accept_event()
				get_tree().set_input_as_handled()

		elif event.control and event.scancode == KEY_Q:
			var ball_no = get_current_ball_index()
			var current_line_idx = cursor_get_line()
			
			var raw_section = ""
			var clean_section = ""
			for i in range(current_line_idx, -1, -1):
				var line = get_line(i).strip_edges()
				if line.begins_with("["):
					raw_section = line
					clean_section = line.split(";")[0].strip_edges()
					break

			if ball_no != -1:
				emit_signal("find_ball", ball_no)
				var b_name = get_ball_name(ball_no)
				var prefix = "[HELPER] Ballz"
				if "Override" in clean_section: prefix = "[HELPER] Override Ballz"
				if clean_section == "[Add Ball]": prefix = "[HELPER] Addballz"
				console_log.log_message("%s #%d (%s)" % [prefix, ball_no, b_name])
			
			var data_line_idx = _get_line_no_from_line_index(current_line_idx, clean_section)
			if data_line_idx != -1:
				match clean_section:
					"[Linez]": emit_signal("find_line", data_line_idx)
					"[Paint Ballz]": emit_signal("find_paintball", data_line_idx)
					"[Polygons]": emit_signal("find_polygon", data_line_idx)
					"[Move]": emit_signal("find_move", data_line_idx)
					"[Project Ball]": emit_signal("find_project_ball", data_line_idx)
			
			if ball_no == -1:
				var word = get_word_under_cursor()
				if word.is_valid_integer():
					var fallback_no = int(word)
					emit_signal("find_ball", fallback_no)
					var b_name = get_ball_name(fallback_no)
					if b_name != "":
						console_log.log_message("[HELPER] Ballz #%d (%s)" % [fallback_no, b_name])

func _get_user_preferred_delimiter() -> String:
	var settings = get_tree().root.get_node_or_null("Root/SceneRoot")
	if settings and settings.has_method("get_preferred_delimiter"):
		var delim = settings.get_preferred_delimiter()
		
		if delim != null and delim != "":
			return delim
			
	return "auto"

func _update_section_bookmarks():
	bookmarks.clear() 
	var lines = get_line_count() 
	
	for i in range(lines):
		var line_text = get_line(i).strip_edges() 
		if line_text.begins_with("["): 
			bookmarks.append(i)

func _on_cursor_changed():
	var ball_no = get_current_ball_index()
	emit_signal("ball_number_changed", ball_no)

func _on_global_font_updated():
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

func _insert_text_at_cursor_at_line(line: int, text: String):
	cursor_set_line(line)
	cursor_set_column(0)
	select(line, 0, line, 0)
	insert_text_at_cursor(text)

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

func _get_active_line_range() -> Array:
	var start_line = 0
	var end_line = 0
	
	if is_selection_active():
		start_line = get_selection_from_line()
		end_line = get_selection_to_line()
		if get_selection_to_column() == 0 and end_line > start_line:
			end_line -= 1
	else:
		start_line = cursor_get_line()
		end_line = cursor_get_line()
		
	return [start_line, end_line]

func _escape_regex(pattern_str: String) -> String:
	var special_chars = ".+*?()[]{}|^$\\/"
	var escaped_str = ""
	for this_char in pattern_str:
		if special_chars.find(this_char) != -1:
			escaped_str += "\\"
		escaped_str += this_char
	return escaped_str

func _wrap_angle_deg(a: int) -> int:
	var ang = ((a % 360) + 360) % 360
	if ang > 180:
		ang -= 360
	return ang

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
	_update_section_bookmarks()

func _on_menu_id_pressed(id):
	if id == 100: # Find/Replace
		find_panel.show()
		self.readonly = true
	elif id == 101: # Toggle Comment
		_toggle_comment()
	elif id == 102: # Set Delimiter
		_set_delimiter()
	elif id == 103: # Set Column in Selection
		set_column_popup.popup_centered(Vector2(250, 150))
		col_input.grab_focus()


### FIND & REPLACE ###
# _find_text
# _on_FindCloseButton_pressed
# _on_FindNextButton_pressed
# _on_FindPrevButton_pressed
# _on_ReplaceButton_pressed
# _on_ReplaceAllButton_pressed

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

	if pattern != _last_compiled_pattern:
		var error = _search_regex.compile(pattern)
		if error != OK:
			find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2)) # Invalid Regex
			return
		_last_compiled_pattern = pattern
		
	var all_matches = _search_regex.search_all(all_text)

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

func _on_FindCloseButton_pressed():
	find_panel.hide()
	self.readonly = false
	_setup_context_menu()

func _on_FindNextButton_pressed(new_text = ""):
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
		find_line_edit.add_color_override("font_color", Color(1, 0.2, 0.2))
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


### LNZ TEXT FINDING ###
# _pos_to_offset
# _offset_to_pos
# _get_next_section_line_idx
# _get_prev_section_line_idx
# find_line_in_ball_section
# find_line_in_addball_section
# find_line_in_move_section
# find_line_in_project_section
# find_line_in_linez_section
# find_line_in_paintball_section
# find_line_in_ball_or_addball_section
# _get_line_no_from_line_index
# _find_insertion_line
# _count_section_entries

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

func _get_next_section_line_idx(from_line: int) -> int:
	for line_index in bookmarks: 
		if line_index >= from_line: 
			return line_index 
	return -1 

func _get_prev_section_line_idx(from_line: int) -> int:
	for i in range(bookmarks.size() - 1, -1, -1): 
		var line_index = bookmarks[i] 
		if line_index <= from_line: 
			return line_index 
	return -1


###

func find_line_in_ball_section(ball_no):
	var section_find = search('[Ballz Info]', 0, 0, 0)
	if section_find.empty(): return -1
	var start_point = section_find[SEARCH_RESULT_LINE] + 1
	return find_line_in_ball_or_addball_section(ball_no, start_point)
	
func find_line_in_addball_section(ball_no):
	var section_find = search('[Add Ball]', 0, 0, 0)
	if section_find.empty(): return -1
	var start_point = section_find[SEARCH_RESULT_LINE] + 1
	return find_line_in_ball_or_addball_section(ball_no, start_point)
	
func find_line_in_move_section(ball_no, start_from = -1):
	return _find_line_in_section_with_match("[Move]", ball_no, "_linez_match_fn", start_from)

func find_line_in_project_section(ball_no, start_from = -1):
	return _find_line_in_section_with_match("[Project Ball]", ball_no, "_project_match_fn", start_from)

func find_line_in_linez_section(ball_no, start_from = -1):
	return _find_line_in_section_with_match("[Linez]", ball_no, "_linez_match_fn", start_from)

func find_line_in_paintball_section(ball_no, start_from = -1):
	return _find_line_in_section_with_match("[Paint Ballz]", ball_no, "_paintball_match_fn", start_from)

func _linez_match_fn(parts: Array, ball_no) -> bool:
	return parts.size() >= 2 and (parts[0] == str(ball_no) or parts[1] == str(ball_no))

func _project_match_fn(parts: Array, ball_no) -> bool:
	return parts.size() > 1 and (parts[0] == str(ball_no) or parts[1] == str(ball_no))

func _paintball_match_fn(parts: Array, ball_no) -> bool:
	return parts.size() > 0 and parts[0] == str(ball_no)

func _find_line_in_section_with_match(section_name: String, ball_no, match_fn_name: String, start_from = -1) -> int:
	var header = section_name if section_name.begins_with("[") else ("[" + section_name + "]")
	var section_find = search(header, 0, 0, 0)
	if section_find.empty():
		return -1
	
	var header_idx = section_find[SEARCH_RESULT_LINE]
	var start_of_section = header_idx + 1
	
	var i = 0
	if start_from >= start_of_section:
		i = start_from - start_of_section + 1
	
	while true:
		var current_line_idx = start_of_section + i
		if current_line_idx >= get_line_count():
			break
		
		var line = get_line(current_line_idx)
		var stripped = line.strip_edges()
		
		# Stop if we hit another section header
		if stripped.begins_with("["):
			break
		
		# Skip empty lines and comments
		if stripped.empty() or stripped.begins_with(";"):
			i += 1
			continue
			
		var parts = split_line(line)
		
		if call(match_fn_name, parts, ball_no):
			return current_line_idx
			
		i += 1
		
	if start_from != -1:
		return _find_line_in_section_with_match(section_name, ball_no, match_fn_name, -1)
	
	return -1

###

func find_line_in_ball_or_addball_section(ball_no, start_point):
	var line = get_line(start_point)
	while true:
		if !line.lstrip(" ").begins_with(";") and line.strip_edges() != "":
			break
		start_point += 1
		if start_point >= get_line_count(): return -1
		line = get_line(start_point)
	
	var i = 0
	var j = -1
	while true:
		var check_idx = start_point + i
		if check_idx >= get_line_count(): return -1
		
		line = get_line(check_idx)
		if line.strip_edges().begins_with("["): return -1
		
		if !line.lstrip(" ").begins_with(";") and line.strip_edges() != "":
			j += 1
		if j == ball_no:
			return check_idx
		i += 1
	return -1

func _get_line_no_from_line_index(target_line_index: int, section_tag: String) -> int:
	var bounds = get_section_bounds(section_tag)
	if bounds.empty():
		return -1
	
	var start_line = bounds.start
	var line_counter = -1
	
	for i in range(start_line, get_line_count()):
		var line = get_line(i).strip_edges()
		
		if line.begins_with("["):
			break
			
		if line.begins_with(";") or line.empty(): continue
		
		line_counter += 1
		
		if i == target_line_index:
			return line_counter
				
	return -1

func _find_insertion_line(start_line: int, end_line: int) -> int:
	var last_true_data_line = -1
	
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		
		if line.empty() or line.begins_with(";"):
			continue
			
		if line.begins_with("["):
			break
			
		last_true_data_line = i
			
	if last_true_data_line == -1:
		return start_line
		
	return last_true_data_line + 1

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


### LNZ TEXT PARSING ###
# get_section_bounds
# get_current_section_name
# _detect_delimiter
# split_line
# _update_fields
# _join_array
# _for_each_line_in_section

func get_section_bounds(section_tag: String) -> Dictionary:
	var sec = search(section_tag, 0, 0, 0)
	if sec.empty():
		return {}
	
	var header_line = sec[SEARCH_RESULT_LINE]
	var start_line = header_line + 1
	var end_line = get_line_count()
	
	for i in range(start_line, get_line_count()):
		var line = get_line(i).strip_edges()
		if line.begins_with("["):
			end_line = i
			break
			
	var empty_count = 0
	for i in range(start_line, end_line):
		if get_line(i).strip_edges() == "":
			empty_count += 1
			
	return {
		"start": start_line, 
		"end": end_line, 
		"header": header_line, 
		"empties": empty_count
	}

func get_current_section_name() -> String:
	var current_line = cursor_get_line()
	for i in range(current_line, -1, -1):
		var line = get_line(i).strip_edges()
		if line.begins_with("["):
			return line.split(";")[0].strip_edges()
	return ""

func _detect_delimiter(start_line: int, end_line: int, test: bool = false) -> String:
	if !test:
		var preferred = _get_user_preferred_delimiter()
		if preferred != "auto":
			print("[STATUS] LnzTextEdit: _detect_delimiter: Using user preferred delimiter: %s" % preferred)
			return preferred

	var delim_counts = {
		", ": 0,  # "comma-space", "comma-tab", "comma-multispace"
		",": 0,   # "comma"
		"\t": 0,  # "tab"
		" ": 0    # "space", "multispace"
	}
	var lines_scanned = 0
	
	var delim_names = {
		", ": "comma-space",
		",": "comma",
		"\t": "tab",
		" ": "space"
	}
	
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()

		if line.empty() or line.begins_with(";"): continue
		
		lines_scanned += 1
		var data_part = line.split(";", false)[0]

		if data_part.find(", ") != -1 or data_part.find(",\t") != -1:
			delim_counts[", "] += 1
		elif data_part.find(",") != -1:
			delim_counts[","] += 1
		elif data_part.find("\t") != -1:
			delim_counts["\t"] += 1
		elif data_part.find(" ") != -1:
			if data_part.split(" ", false).size() > 1:
				delim_counts[" "] += 1

	if lines_scanned == 0:
		print("[STATUS] LnzTextEdit: _detect_delimiter: No lines scanned. Returning 'space'.")
		return " "

	var most_frequent_delim = " "
	var max_count = 0
	var priority_order = [", ", ",", "\t", " "]

	for delim in priority_order:
		if delim_counts[delim] > max_count:
			print("[STATUS] LnzTextEdit: _detect_delimiter: Delimiter '%s' is top with count %d" % [delim_names[delim], delim_counts[delim]])
			max_count = delim_counts[delim]
			most_frequent_delim = delim
			
	if max_count == 0:
		print("[STATUS] LnzTextEdit: _detect_delimiter: No delimiters found in scanned lines. Returning 'space'.")
		
	return most_frequent_delim

func split_line(line: String) -> Array:
	var data_part = line
	var comment_part = ""
	var comment_idx = line.find(";")

	if comment_idx != -1:
		data_part = line.substr(0, comment_idx)
		comment_part = line.substr(comment_idx)
	
	data_part = data_part.strip_edges()
	if data_part.empty() and comment_part.empty():
		return []
		
	var normalized_line = _split_regex.sub(data_part, " ", true)
	var parts: Array = normalized_line.split(" ", false)
	
	parts.append(comment_part)
	
	return parts

func _update_fields(parts: Array, updates: Dictionary, delim: String) -> String:
	var new_parts = []
	for i in range(parts.size()):
		if updates.has(i):
			new_parts.append(updates[i])
		else:
			new_parts.append(parts[i])
	return _join_array(new_parts, delim)

func _join_array(parts: Array, delimiter: String) -> String:
	var result = ""
	for i in range(parts.size()):
		result += str(parts[i])
		if i < parts.size() - 1:
			result += delimiter
	return result

func _for_each_line_in_section(tag: String, callback):
	var bounds = get_section_bounds(tag)
	if bounds.empty():
		return
	for i in range(bounds.start, bounds.end):
		var line = get_line(i)
		if line.strip_edges() == "" or line.begins_with(";"): continue
		callback.call(i, line)


### LNZ TEXT EDITING ###
# _apply_comments
# _remove_comments
# _toggle_comment
# _set_delimiter
# _replace_section_content
# _on_set_column_confirmed

func _apply_comments(lines_array: Array, comment_prefix: String = "; "):
	for i in lines_array:
		var line_text = get_line(i)
		var indent_len = line_text.length() - line_text.lstrip(" \t").length()
		var indent = line_text.substr(0, indent_len)
		var content = line_text.lstrip(" \t")
		
		set_line(i, indent + comment_prefix + content)

func _remove_comments(lines_array: Array, comment_prefix: String = "; "):
	for i in lines_array:
		var line_text = get_line(i)
		var indent_len = line_text.length() - line_text.lstrip(" \t").length()
		var indent = line_text.substr(0, indent_len)
		var content = line_text.lstrip(" \t")
		
		if content.begins_with(comment_prefix):
			set_line(i, indent + content.substr(comment_prefix.length()))

func _toggle_comment():
	var range_bounds = _get_active_line_range()
	var start_line = range_bounds[0]
	var end_line = range_bounds[1]

	var comment_prefix = "; "
	var lines_to_process = []
	var should_uncomment = true

	for i in range(start_line, end_line + 1):
		var line_text = get_line(i)
		if line_text.strip_edges().empty(): continue
			
		lines_to_process.append(i)
		if not line_text.lstrip(" \t").begins_with(comment_prefix):
			should_uncomment = false

	if lines_to_process.empty():
		return

	if should_uncomment:
		_remove_comments(lines_to_process, comment_prefix)
	else:
		_apply_comments(lines_to_process, comment_prefix)

	deselect()
	select(start_line, 0, end_line, get_line(end_line).length())

func _set_delimiter():
	var range_bounds = _get_active_line_range()
	
	var preferred_delim = _get_user_preferred_delimiter()
	if preferred_delim == "auto":
		preferred_delim = " "
	
	for i in range(range_bounds[0], range_bounds[1] + 1):
		var line_text = get_line(i)
		var stripped = line_text.strip_edges()
		
		if stripped.empty() or stripped.begins_with("[") or stripped.begins_with(";"): continue
		
		var parts = split_line(line_text) 
		if parts.size() == 0: continue
			
		var data_parts = Array(parts)
		var comment_part = ""
		
		var last_part = data_parts[data_parts.size() - 1]
		if last_part.begins_with(";"):
			comment_part = data_parts.pop_back()
			
		var final_line = _join_array(data_parts, preferred_delim)
		if not comment_part.empty():
			final_line += " " + comment_part 
			
		set_line(i, final_line)

	save_file(true) 
	commit_full_snapshot("Set delimiter of LNZ selection")

func _replace_section_content(section_name: String, new_lines: Array):
	var bounds = get_section_bounds(section_name)
	if bounds.empty() and new_lines.empty():
		return # Nothing to do

	if bounds.empty():
		# Create the section if it doesn't exist
		var first_section_line = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section_line, section_name)
		#all_lines.insert(first_section_line + 1, "")
		_set_text_preserve(all_lines.join("\n"))
		bounds = get_section_bounds(section_name)

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

func _on_set_column_confirmed():
	var col_idx = col_input.text.to_int()
	var new_value = val_input.text
	
	var range_bounds = _get_active_line_range()

	save_backup()
	
	for i in range(range_bounds[0], range_bounds[1] + 1):
		var line_text = get_line(i)
		var stripped = line_text.strip_edges()
		
		if stripped.empty() or stripped.begins_with("[") or stripped.begins_with(";"): continue
			
		var parts = split_line(line_text)
		if parts.size() <= 1: continue
			
		var comment_part = parts.pop_back()
			
		if col_idx >= 0 and col_idx < parts.size():
			parts[col_idx] = new_value
			
			var delim = _detect_delimiter(i, i + 1) 
			var final_line = _join_array(parts, delim) 
			
			if not comment_part.empty():
				final_line += " " + comment_part
				
			set_line(i, final_line)

	save_file(true)
	commit_full_snapshot("Set column " + str(col_idx) + " to '" + new_value + "' in LNZ selection")


### LNZ DATA GETTERS ###
# get_ball_name
# find_mirrored_ball
# get_corresponding_right_ball
# get_corresponding_left_ball
# check_linez_limits
# _get_omitted_balls
# get_current_ball_index
# get_project_ball_section

func get_ball_name(ball_no: int) -> String:
	if KeyBallsData == null:
		return ""
		
	var species = KeyBallsData.get("species")
	var max_base = KeyBallsData.get("max_base_ball_num")
	
	if species == null or max_base == null:
		return ""

	var ball_name = ""

	if ball_no < max_base:
		var definitions = {}
		match species:
			KeyBallsData.Species.CAT: definitions = KeyBallsData.cat_ball_definitions
			KeyBallsData.Species.DOG: definitions = KeyBallsData.dog_ball_definitions
			KeyBallsData.Species.BABY: definitions = KeyBallsData.bab_ball_definitions
		
		if definitions.has(ball_no):
			ball_name = definitions[ball_no].get("name", "")
	
	else:
		var addball_idx = ball_no - max_base
		var line_idx = find_line_in_addball_section(addball_idx)
		
		if line_idx != -1:
			var current_line = get_line(line_idx)
			
			if current_line.find(";") != -1:
				var parts = current_line.split(";", false, 1)
				if parts.size() > 1:
					ball_name = parts[1].strip_edges()
			
			if ball_name == "":
				var bounds = get_section_bounds("[Add Ball]")
				var header_idx = bounds.get("header", -1)
				var search_idx = line_idx - 1
				
				while search_idx > header_idx:
					var raw_line = get_line(search_idx).strip_edges()
					
					if raw_line.begins_with(";"):
						ball_name = raw_line.substr(1).strip_edges()
						if ball_name != "":
							break
					
					elif raw_line.begins_with("["):
						break
					
					search_idx -= 1
	
	if ball_name.length() > 25:
		ball_name = ball_name.substr(0, 22) + "..."
	
	return ball_name

func find_mirrored_ball(ball_no: int) -> int:
	var max_base = KeyBallsData.max_base_ball_num
	if max_base == null: 
		return ball_no 

	if ball_no >= max_base:
		if ball_map.has(ball_no) and ball_map[ball_no].has("corresponding_ball"):
			var corr = ball_map[ball_no].corresponding_ball
			if ball_map.has(corr):
				return ball_map[corr].new_ball_no
		return ball_no # no mirror found, return self

	var species = KeyBallsData.species 
	var symmetry_dict = {}

	match species:
		KeyBallsData.Species.CAT: 
			symmetry_dict = KeyBallsData.cat_body_part_symmetry
		KeyBallsData.Species.DOG: 
			symmetry_dict = KeyBallsData.dog_body_part_symmetry
		KeyBallsData.Species.BABY: 
			symmetry_dict = KeyBallsData.baby_body_part_symmetry
		_: 
			return ball_no

	var mirrored_base = KeyBallsData.get_mirrored_ball(ball_no, symmetry_dict)
	
	# get_mirrored_ball returns -1 if the ball is a center ball (no pair)
	if mirrored_base != -1:
		return mirrored_base
		
	return ball_no

func get_corresponding_right_ball(left_ball_index: int) -> int:
	return find_mirrored_ball(left_ball_index)

func get_corresponding_left_ball(right_ball_index: int) -> int:
	return find_mirrored_ball(right_ball_index)

func check_linez_limits(b1: int, b2: int) -> bool:
	var bounds = get_section_bounds("[Linez]")
	if bounds.empty():
		return false
	
	var total_valid = 0
	var count_b1 = 0
	var count_b2 = 0
	
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue
		
		var parts = split_line(line)
		if parts.size() < 2: continue
		
		total_valid += 1
		var lb1 = int(parts[0])
		var lb2 = int(parts[1])
		
		if lb1 == b1 or lb2 == b1: count_b1 += 1
		if lb1 == b2 or lb2 == b2: count_b2 += 1
	
	# Limits: 256 total valid linez OR 32 linez for either ball
	return total_valid >= 256 or count_b1 >= 32 or count_b2 >= 32

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
		if line.empty() or line.begins_with(";"): continue
		
		var ball_no_str = line.split(";", false)[0].strip_edges().split(" ", false)[0]
		if ball_no_str.is_valid_integer():
			omitted_balls.append(ball_no_str.to_int())
		
	return omitted_balls

func get_current_ball_index() -> int:
	var current_line = cursor_get_line()
	var line_text = get_line(current_line).strip_edges()
	var nearest_section = ""
	
	for i in range(current_line, -1, -1):
		var header = get_line(i).strip_edges()
		if header.begins_with("["):
			nearest_section = header.split(";")[0].strip_edges()
			break
	
	if nearest_section == "":
		var word = get_word_under_cursor()
		return int(word) if word.is_valid_integer() else -1

	if nearest_section == "[Ballz Info]":
		return _get_line_no_from_line_index(current_line, "[Ballz Info]")
	elif nearest_section == "[Add Ball]":
		var idx = _get_line_no_from_line_index(current_line, "[Add Ball]")
		return idx + KeyBallsData.max_base_ball_num if idx != -1 else -1

	if line_text.empty() or line_text.begins_with(";"):
		return -1
		
	var parts = split_line(line_text)
	if parts.size() == 0:
		return -1

	match nearest_section:
		"[Move]", \
		"[Paint Ballz]", \
		"[Ball Size Override]", \
		"[Fuzz Override]", \
		"[Color Info Override]", \
		"[Outline Color Override]", \
		"[Linez]", \
		"[Omissions]", \
		"[Thin/Fat]":
			return int(parts[0]) if parts[0].is_valid_integer() else -1
			
		"[Add Ball Override]":
			return int(parts[0]) + KeyBallsData.max_base_ball_num if parts[0].is_valid_integer() else -1
			
		"[Project Ball]":
			if parts.size() > 1 and parts[1].is_valid_integer():
				return int(parts[1])
			return int(parts[0]) if parts[0].is_valid_integer() else -1

	return -1

func get_project_ball_section() -> Array:
	var projections = []
	var bounds = get_section_bounds("[Project Ball]")
	if bounds.empty():
		return projections

	var start_line = bounds.start
	var end_line = bounds.end

	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var comment = ""
		if line.find(";") != -1:
			comment = line.substr(line.find(";") + 1).strip_edges()
			line = line.substr(0, line.find(";")).strip_edges()

		var parts = split_line(line)
		if parts.empty(): continue

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


### LNZ DATA SETTERS ###
# _update_all_references
# _update_pairwise_section
# _update_single_number_section
# _update_project_ball_section
# _update_paintballz_section
# update_lnz_section_one_value
# update_lnz_section_two_values
# _write_project_ball_section
# _apply_preset_to_ball
# _write_preset_to_ball
# apply_batch_presets
# _transform_paintballz_section
# _on_apply_paintballz
# _on_palette_selected
# _on_HeadShotButton_pressed
# _apply_paintball_preset_no_save
# apply_batch_moves
# _apply_batch_sizes
# set_batch_moves

func _update_all_references(ball_no: int):
	# Handles [Linez], [Omissions], [Project Ball], [Paint Ballz], [Polygons]
	_update_pairwise_section("[Linez]", ball_no)
	_update_single_number_section("[Omissions]", ball_no)
	_update_project_ball_section("[Project Ball]", ball_no)
	_update_paintballz_section("[Paint Ballz]", ball_no)
	_update_polygon_section(ball_no)

func _update_pairwise_section(header: String, ball_no: int):
	# Generic for [Linez] with start/end ball pair
	var bounds = get_section_bounds(header)
	if bounds.empty(): return
	
	var delim = _detect_delimiter(bounds.start, bounds.end)
	
	# Iterate backwards so that cutting a line doesn't skip the next one
	for i in range(bounds.end - 1, bounds.start - 1, -1):
		var line = get_line(i).strip_edges()
		if line == "" or line.begins_with("[") or line.begins_with(";"): continue
			
		var parts = split_line(line)
		if parts.size() < 2: continue
			
		var b1 = int(parts[0])
		var b2 = int(parts[1])
		
		# 1. Handle Deletion
		if b1 == ball_no or b2 == ball_no:
			# Note: In Godot TextEdit, select is (from_line, from_col, to_line, to_col)
			select(i, 0, i + 1, 0)
			cut()
			continue
			
		# 2. Handle Decrementing
		var updates = {}
		if b1 > ball_no: 
			updates[0] = str(b1 - 1)
		if b2 > ball_no: 
			updates[1] = str(b2 - 1)
		
		if not updates.empty():
			# _update_fields handles the reconstruction using the detected delimiter
			var new_line = _update_fields(parts, updates, delim)
			set_line(i, new_line)

func _update_single_number_section(header: String, ball_no: int):
	# Generic for single-number lists like [Omissions]
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

func _update_project_ball_section(header: String, ball_no: int):
	# Specific for [Project Ball] where 2nd token is ball_no
	var section = search(header, 0, 0, 0)
	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	while true:
		var line = get_line(start + i).strip_edges()
		if line == "" or line.begins_with("["):
			break
		var tokens = split_line(line)
		var move_ball = int(tokens[1])
		if move_ball == ball_no:
			select(start + i, 0, start + i + 1, 0)
			cut()
			continue
		elif move_ball > ball_no:
			var rest = line.substr(tokens[2].get_start())
			set_line(start + i, "%s %s %s" % [tokens[0], str(move_ball - 1), rest])
		i += 1

func _update_paintballz_section(header: String, ball_no: int):
	# Specific for [Paint Ballz] where 1st token is base ball number
	print("[STATUS] LnzTextEdit: _update_paintballz_section: Decrementing references for deleted ball_no %d" % ball_no)
	var bounds = get_section_bounds(header)
	if bounds.empty(): return
	
	var delim = _detect_delimiter(bounds.start, bounds.end)
	var i = bounds.start
	while i < bounds.end:
		var raw_line = get_line(i)
		var parts = split_line(raw_line)
		if parts.size() < 1: 
			i += 1
			continue

		var b = int(parts[0])
		if b == ball_no:
			select(i, 0, i + 1, 0)
			cut()
			bounds.end -= 1
			continue 
		elif b > ball_no:
			set_line(i, _update_fields(parts, {0: str(b - 1)}, delim))
		i += 1

func _update_polygon_section(ball_no: int):
	# Replace deleted ball number in polygon lines with a fallback ball.
	var bounds = get_section_bounds("[Polygons]")
	if bounds.empty(): return
	
	var delim = _detect_delimiter(bounds.start, bounds.end)
	for i in range(bounds.start, bounds.end):
		var raw_line = get_line(i)
		var parts = split_line(raw_line)
		if parts.size() < 4: continue
		
		var deleted_idx = -1
		for col in [0, 1, 2, 3]:
			if int(parts[col]) == ball_no:
				deleted_idx = col
				break
		
		if deleted_idx == -1: continue
		
		# Pick fallback: if col 0, use col 1; if col 1, use col 0; if col 2, use col 1; if col 3, use col 2
		var fallback_col = -1
		if deleted_idx == 0: fallback_col = 1
		elif deleted_idx == 1: fallback_col = 0
		elif deleted_idx == 2: fallback_col = 1
		elif deleted_idx == 3: fallback_col = 2
		
		if fallback_col >= 0:
			var fallback_val = str(int(parts[fallback_col]))
			var updates = {deleted_idx: fallback_val}
			set_line(i, _update_fields(parts, updates, delim))

func update_lnz_section_one_value(section_name, val1):
	var bounds = get_section_bounds(section_name)
	if bounds.empty():
		var msg = "LNZ section not found: " + section_name
		print("[STATUS] LnzTextEdit: update_lnz_section_one_value: " + msg)
		if console_log:
			console_log.log_message(msg)
		return

	var start_line = bounds.start
	set_line(start_line, str(val1))

func update_lnz_section_two_values(section_name, val1, val2):
	var bounds = get_section_bounds(section_name)
	if bounds.empty():
		var msg = "LNZ section not found: " + section_name
		print("[STATUS] LnzTextEdit: update_lnz_section_two_values: " + msg)
		if console_log:
			console_log.log_message(msg)
		return

	var start_line = bounds.start
	var end_line = bounds.end

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

func _write_project_ball_section(projections: Array):
	save_backup()
	var bounds = get_section_bounds("[Project Ball]")
	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Project Ball]")
		all_lines.insert(first_section + 1, "")
		text = all_lines.join("\n")
		_set_text_preserve(text)
		bounds = get_section_bounds("[Project Ball]")

	var start_line = bounds.start
	var end_line = bounds.end

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
			if line_strip.empty() or line_strip.begins_with(";"): continue

			var line_parts = line_strip.split(";")
			var data_part = line_parts[0].strip_edges()
			var parts = split_line(data_part)

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

func _apply_preset_to_ball(ball_no, properties, do_save = true):
	if do_save:
		save_backup()
	var is_addball = ball_no > KeyBallsData.max_base_ball_num

	var section_tag = "[Ballz Info]"
	if is_addball:
		section_tag = "[Add Ball]"

	var bounds = get_section_bounds(section_tag)
	if bounds.empty():
		var msg = "No %s section found" % section_tag
		print("[WARNING] LnzTextEdit: _apply_preset_to_ball: " + msg)
		if console_log:
			console_log.log_message(msg)
		return

	var start_line = bounds.start
	var end_line = bounds.end

	var line_index = -1
	if is_addball:
		line_index = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
	else:
		line_index = find_line_in_ball_section(ball_no)

	if line_index != -1:
		var delim = _detect_delimiter(start_line, end_line)
		var line = get_line(line_index)
		var parts = split_line(line)

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

func write_preset_to_ball(ball_no, properties, _write_target, should_override):
	var applied_something = false
	if properties.get("apply_ballz", true):
		_apply_preset_to_ball(ball_no, properties, false)
		applied_something = true

	if properties.get("apply_paintballz", true) and properties.has("paintballz"):
		var paintballz = properties.paintballz
		if paintballz.size() > 0:
			applied_something = true
			var bounds = get_section_bounds("[Paint Ballz]")
			var insert_line_num

			if bounds.empty():
				var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
				var all_lines = get_text().split("\n")
				all_lines.insert(first_section, "[Paint Ballz]")
				all_lines.insert(first_section + 1, "")
				text = all_lines.join("\n")
				_set_text_preserve(text)
				bounds = get_section_bounds("[Paint Ballz]")

			insert_line_num = bounds.start
			var j = 0
			while insert_line_num + j < bounds.end:
				var line = get_line(insert_line_num + j).strip_edges()
				if line.begins_with(";"):
					j += 1
					continue
				break
			insert_line_num += j

			var delim = _detect_delimiter(bounds.start, bounds.end)
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
				paintball_line += str(paintball_info.group) + delim
				paintball_line += str(paintball_info.texture_id) + delim
				paintball_line += str(paintball_info.anchored)

				new_paintball_lines += paintball_line + "\n"

			_insert_text_at_cursor_at_line(insert_line_num, new_paintball_lines)

	if applied_something:
		save_file(true)
		commit_full_snapshot("Applied Preset to Ballz #%d" % ball_no)

func apply_batch_presets(changes: Dictionary):
	if changes.empty(): return
	save_backup()
	var applied_something = false

	for ball_no in changes:
		var props = changes[ball_no]
		_apply_preset_to_ball(ball_no, props, false)
		applied_something = true

	if applied_something:
		save_file(true)
		commit_full_snapshot("Batch Applied Properties to %d Ballz" % changes.size())

func _transform_paintballz_section(transforms: Dictionary):
	print("[STATUS] LnzTextEdit: _transform_paintballz_section: Transforming %d paintballs" % transforms.size())
	var bounds = get_section_bounds("[Paint Ballz]")
	if bounds.empty(): return
	
	var delim = _detect_delimiter(bounds.start, bounds.end)
	
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue
		
		var parts = split_line(line)
		if parts.size() < 5: continue
		
		var ball_no = int(parts[0])
		if transforms.has(ball_no):
			var trans = transforms[ball_no]
			var basis_delta = trans.basis
			
			var rel_pos = Vector3(float(parts[2]), float(parts[3]) * -1.0, float(parts[4]))
			
			var updated_pos = basis_delta.xform(rel_pos)
			
			var old_diam = int(parts[1])
			parts[2] = str(round(updated_pos.x))
			parts[3] = str(round(updated_pos.y * -1.0))
			parts[4] = str(round(updated_pos.z))
			
			set_line(i, _join_array(parts, delim))

func _on_apply_paintballz():
	apply_paintballz()

func apply_paintballz():
	save_backup()

	var pending_paintballs = pet_node.get_pending_paintballs_data()
	print("[STATUS] LnzTextEdit: _on_apply_paintballz: Applying %d pending paintballs to LNZ" % pending_paintballs.size())

	if pending_paintballs.size() > 0:
		var is_babyz = pet_node.lnz.species == KeyBallsData.Species.BABY
		var bounds = get_section_bounds("[Paint Ballz]")
		
		if bounds.empty():
			print("[WARNING] LnzTextEdit: _on_apply_paintballz: [Paint Ballz] section missing, generating new section.")
			var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
			var all_lines = get_text().split("\n")
			all_lines.insert(first_section, "[Paint Ballz]")
			all_lines.insert(first_section + 1, "")
			text = all_lines.join("\n")
			_set_text_preserve(text)
			bounds = get_section_bounds("[Paint Ballz]")

		var insert_at_line = bounds.start
		var need_fillers = false
		var delim = _detect_delimiter(bounds.start, bounds.end)

		if is_babyz:
			var valid_entries_count = 0
			var scanner_line = bounds.start
			var found_target = false
			var total_lines = get_line_count()
			
			while scanner_line < total_lines:
				var line = get_line(scanner_line).strip_edges()
				
				if line.begins_with("["):
					break 
				
				if !line.empty() and !line.begins_with(";"):
					valid_entries_count += 1
				
				if valid_entries_count == 17:
					insert_at_line = scanner_line + 1
					found_target = true
					break
				
				scanner_line += 1
			
			if !found_target:
				need_fillers = true
				insert_at_line = bounds.start

		else:
			var runner = bounds.start
			var total_lines = get_line_count()
			while runner < total_lines:
				var line = get_line(runner).strip_edges()
				
				if line.begins_with("["):
					break

				#if line.empty() or line.begins_with(";"):
				if line.begins_with(";"):
					runner += 1
				else:
					break
					
			insert_at_line = runner
		var text_to_insert = ""
		
		if need_fillers:
			for i in range(17):
				var filler_line = "1" + delim + "-1" + delim + "0" + delim + "0" + delim + "0" + delim + "0" + delim + "0" + delim + "0" + delim + "0" + delim + "0" + delim + "0"
				text_to_insert += filler_line + " ; chickenpox filler\n"

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

		for line in paintball_lines_list:
			text_to_insert += line + "\n"

		_insert_text_at_cursor_at_line(insert_at_line, text_to_insert)
		pet_node.clear_pending_paintballz()

	save_file(true)
	commit_full_snapshot("Commited Paintballz")

	if pet_view.close_paintball_on_apply:
		pet_view.close_paintball_mode()

func _on_palette_selected(filename_without_extension):
	save_backup()
	var bounds = get_section_bounds("[Palette]")
	var new_line = filename_without_extension

	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Palette]")
		all_lines.insert(first_section + 1, new_line)
		text = all_lines.join("\n")
		_set_text_preserve(text)
	else:
		var start_line = bounds.start
		var end_line = bounds.end
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
	
	save_file(true)
	commit_full_snapshot("Applied Palette")

func _on_HeadShotButton_pressed():
	 capture_headshot()

func capture_headshot():
	save_backup()
	var local_frame = int(frame_slider.value)
	var cam_e = camera_holder.rotation_degrees   # x=pitch, y=yaw, z=roll

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

	var bounds = get_section_bounds("[Head Shot]")
	if bounds.empty():
		var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section, "[Head Shot]")
		var temp = ""
		for line in all_lines:
			temp += line + "\n"
		_set_text_preserve(temp)
		bounds = get_section_bounds("[Head Shot]")

	var lines = get_text().split("\n")

	var before_lines = []
	for i in range(bounds.start):
		before_lines.append(lines[i])

	var tail_lines = []
	var head_block_len = shot_lines.size()
	for i in range(bounds.start + head_block_len, bounds.end):
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
	for i in range(bounds.end, lines.size()):
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
	save_file(true)
	commit_full_snapshot("Captured Head Shot")

func _apply_paintball_preset_no_save(ball_no, properties):
	var paintballz = properties.paintballz
	if paintballz.size() > 0:
		var bounds = get_section_bounds("[Paint Ballz]")
		var insert_line_num

		if bounds.empty():
			var first_section = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
			var all_lines = get_text().split("\n")
			all_lines.insert(first_section, "[Paint Ballz]")
			all_lines.insert(first_section + 1, "")
			text = all_lines.join("\n")
			_set_text_preserve(text)
			bounds = get_section_bounds("[Paint Ballz]")

		insert_line_num = bounds.start
		var j = 0
		while insert_line_num + j < bounds.end:
			var line = get_line(insert_line_num + j).strip_edges()
			if line.begins_with(";"):
				j += 1
				continue
			break
		insert_line_num += j

		var delim = _detect_delimiter(bounds.start, bounds.end)
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
			paintball_line += str(paintball_info.group) + delim
			paintball_line += str(paintball_info.texture_id) + delim
			paintball_line += str(paintball_info.anchored)

			new_paintball_lines += paintball_line + "\n"

		_insert_text_at_cursor_at_line(insert_line_num, new_paintball_lines)

func apply_batch_moves(pending_moves: Dictionary):
	if pending_moves.empty():
		return
	
	save_backup()
	
	var size_changes = {}
	var paintball_transforms = {}

	for ball_no in pending_moves.keys():
		var data = pending_moves[ball_no]
		
		var scale_delta = 1.0
		if data.has("new_size") and data.has("orig_size") and data.orig_size > 0:
			scale_delta = float(data.new_size) / float(data.orig_size)
			var size_dif = pet_view.get_absolute_lnz_size(1.0, pet_view.find_visual_ball_by_no(ball_no), pet_node)
			size_changes[ball_no] = size_dif

		var basis_delta = Basis.IDENTITY
		if data.has("new_basis") and data.has("orig_basis"):
			basis_delta = data.new_basis * data.orig_basis.inverse()
		
		if basis_delta != Basis.IDENTITY:
			paintball_transforms[ball_no] = {
				"basis": basis_delta
			}

	if not size_changes.empty():
		_apply_batch_sizes(size_changes)

	if not paintball_transforms.empty():
		_transform_paintballz_section(paintball_transforms)

	var move_section_tag = "[Move]"
	var add_ball_section_tag = "[Add Ball]"
	
	var move_sec = search(move_section_tag, 0, 0, 0)
	if move_sec.empty():
		var first_section_line = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section_line, "[Move]")
		#all_lines.insert(first_section_line + 1, "")
		text = all_lines.join("\n")
		_set_text_preserve(text)
		move_sec = search(move_section_tag, 0, 0, 0)
	
	var move_start = move_sec[SEARCH_RESULT_LINE] + 1
	var move_end = search("[", 0, move_start, 0)[SEARCH_RESULT_LINE]
	if move_end == -1: move_end = get_line_count()
	
	var add_sec = search(add_ball_section_tag, 0, 0, 0)
	var add_start = -1
	var add_end = -1
	if !add_sec.empty():
		add_start = add_sec[SEARCH_RESULT_LINE] + 1
		add_end = search("[", 0, add_start, 0)[SEARCH_RESULT_LINE]
		if add_end == -1: add_end = get_line_count()
	
	for ball_no in pending_moves.keys():
		var data = pending_moves[ball_no]
		var orig_pos = data.orig_pos
		var final_pos = data.new_pos
		var world_delta = final_pos - orig_pos

		var lnz_delta = LnzLiveUtils.world_to_lnz_delta(world_delta, pet_node.pixel_world_size, pet_node.lnz.scales.x)
		
		if ball_no < KeyBallsData.max_base_ball_num:
			var delim = _detect_delimiter(move_start, move_end)
			var updated = false
			var head_id = KeyBallsData.get_ball_id_by_name("head")
			var head_group = KeyBallsData.get_group_balls("Head")
			
			for i in range(move_start, move_end):
				var raw = get_line(i).strip_edges()
				if raw == "" or raw.begins_with(";"): continue
				var parts = split_line(raw)
				if parts.size() >= 4 and parts[0].to_int() == ball_no:
					var nx = int(round(parts[1].to_float() + lnz_delta.x))
					var ny = int(round(parts[2].to_float() + lnz_delta.y))
					var nz = int(round(parts[3].to_float() + lnz_delta.z))
					
					parts[1] = str(nx)
					parts[2] = str(ny)
					parts[3] = str(nz)
					
					if head_group.has(ball_no) and head_id != -1:
						if parts.size() < 5:
							if abs(ny) > 25 or abs(nz) > 25:
								if parts.size() < 5: parts.resize(5)
								parts[4] = str(head_id)
					
					set_line(i, _join_array(parts, delim))
					updated = true
					break
					
			if !updated:
				var nx = int(round(lnz_delta.x))
				var ny = int(round(lnz_delta.y))
				var nz = int(round(lnz_delta.z))
				var parts = [str(ball_no), str(nx), str(ny), str(nz)]
				
				if head_group.has(ball_no) and head_id != -1:
					if abs(ny) > 25 or abs(nz) > 25:
						parts.append(str(head_id))
				
				var line_txt = _join_array(parts, delim)
				var insert_at = _find_insertion_line(move_start, move_end)
				_insert_text_at_cursor_at_line(insert_at, line_txt + "\n")
				move_end += 1
				if add_start != -1 and add_start > move_start:
					add_start += 1
					add_end += 1
		else:
			if add_start != -1:
				var delim = _detect_delimiter(add_start, add_end)
				var idx = ball_no - KeyBallsData.max_base_ball_num
				var count = 0
				for i in range(add_start, add_end):
					var raw = get_line(i).strip_edges()
					if raw == "" or raw.begins_with(";"): continue
					if count == idx:
						var parts = split_line(raw)
						if parts.size() >= 4:
							var moved_ball_node = pet_node.ball_map.get(ball_no)
							if is_instance_valid(moved_ball_node) and "base_ball_no" in moved_ball_node:
								var base_ball_no = moved_ball_node.base_ball_no
								var base_ball_node = pet_node.ball_map.get(base_ball_no)
								if is_instance_valid(base_ball_node):
									var world_rel = moved_ball_node.global_transform.origin - base_ball_node.global_transform.origin
									var new_rel = LnzLiveUtils.world_to_lnz_delta(world_rel, pet_node.pixel_world_size, pet_node.lnz.scales.x)
									parts[1] = str(int(round(new_rel.x)))
									parts[2] = str(int(round(new_rel.y)))
									parts[3] = str(int(round(new_rel.z)))
								else:
									parts[1] = str(int(round(parts[1].to_float() + lnz_delta.x)))
									parts[2] = str(int(round(parts[2].to_float() + lnz_delta.y)))
									parts[3] = str(int(round(parts[3].to_float() + lnz_delta.z)))
							else:
								parts[1] = str(int(round(parts[1].to_float() + lnz_delta.x)))
								parts[2] = str(int(round(parts[2].to_float() + lnz_delta.y)))
								parts[3] = str(int(round(parts[3].to_float() + lnz_delta.z)))
								
							set_line(i, _join_array(parts, delim))
						break
					count += 1
	
	save_file(true)
	commit_full_snapshot("Batch Moved/Rotated/Scaled Ballz/Paintballz")

func _apply_batch_sizes(size_changes: Dictionary):
	var ballz_bounds = get_section_bounds("[Ballz Info]")
	var add_bounds = get_section_bounds("[Add Ball]")

	var ballz_start = ballz_bounds.get("start", -1)
	var ballz_end = ballz_bounds.get("end", -1)

	var add_start = add_bounds.get("start", -1)
	var add_end = add_bounds.get("end", -1)

	for ball_no in size_changes.keys():
		var size_val = size_changes[ball_no]

		if ball_no < KeyBallsData.max_base_ball_num:
			if ballz_start != -1:
				var count = 0
				for i in range(ballz_start, ballz_end):
					var raw = get_line(i).strip_edges()
					if raw == "" or raw.begins_with(";"): continue
					if count == ball_no:
						var parts = split_line(raw)
						if parts.size() > 5:
							parts[5] = str(size_val)
							set_line(i, _join_array(parts, " "))
						break
					count += 1
		else:
			if add_start != -1:
				var idx = ball_no - KeyBallsData.max_base_ball_num
				var count = 0
				for i in range(add_start, add_end):
					var raw = get_line(i).strip_edges()
					if raw == "" or raw.begins_with(";"): continue
					if count == idx:
						var parts = split_line(raw)
						if parts.size() > 10:
							parts[10] = str(size_val)
							set_line(i, _join_array(parts, " "))
						break
					count += 1

func set_batch_moves(moves_dict: Dictionary):
	if moves_dict.empty():
		return
	
	save_backup()
	
	var move_section_tag = "[Move]"
	var move_sec = search(move_section_tag, 0, 0, 0)
	
	if move_sec.empty():
		var first_section_line = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
		var all_lines = get_text().split("\n")
		all_lines.insert(first_section_line, "[Move]")
		#all_lines.insert(first_section_line + 1, "")
		text = all_lines.join("\n")
		_set_text_preserve(text)
		move_sec = search(move_section_tag, 0, 0, 0)
	
	var move_start = move_sec[SEARCH_RESULT_LINE] + 1
	var move_end = search("[", 0, move_start, 0)[SEARCH_RESULT_LINE]
	if move_end == -1: move_end = get_line_count()
	
	var delim = _detect_delimiter(move_start, move_end)
	
	var existing_moves_lines = {}
	for i in range(move_start, move_end):
		var raw = get_line(i).strip_edges()
		if raw == "" or raw.begins_with(";"): continue
		var parts = split_line(raw)
		if parts.size() > 0:
			existing_moves_lines[parts[0].to_int()] = i
			
	var new_lines_to_add = []
	
	for ball_no in moves_dict.keys():
		var offset = moves_dict[ball_no]
		var x = int(round(offset.x))
		var y = int(round(offset.y))
		var z = int(round(offset.z))
		
		if existing_moves_lines.has(ball_no):
			var line_idx = existing_moves_lines[ball_no]
			var raw = get_line(line_idx).strip_edges()
			var parts = split_line(raw)
			if parts.size() >= 4:
				parts[1] = str(x)
				parts[2] = str(y)
				parts[3] = str(z)
				set_line(line_idx, _join_array(parts, delim))
		else:
			var line_txt = "%d%s%d%s%d%s%d" % [ball_no, delim, x, delim, y, delim, z]
			new_lines_to_add.append(line_txt)
			
	if not new_lines_to_add.empty():
		var insert_at = _find_insertion_line(move_start, move_end)
		_insert_text_at_cursor_at_line(insert_at, _join_array(new_lines_to_add, "\n") + "\n")
		
	save_file(true)
	commit_full_snapshot("Randomized [Move] entries")


### VISUAL NODE SIGNALS ###
# _on_Node_line_created
# _on_Node_ball_selected
# _on_Node_ball_resized
# _on_Node_ball_moved

func _on_Node_line_created(start_ball, end_ball):
	create_line(start_ball, end_ball)

func create_line(start_ball, end_ball, silent: bool = false):
	if not silent:
		save_backup()

	var bounds = get_section_bounds("[Linez]")
	var start_line = bounds.start
	var end_line = bounds.end

	if start_line == -1:
		var msg = "No [Linez] section found. Cannot create line between %d and %d." % [start_ball, end_ball]
		print("[WARNING] LnzTextEdit: _on_Node_line_created: " + msg)
		if console_log:
			console_log.log_message(msg)
		return

	var delim = _detect_delimiter(start_line, end_line)

	var line_mode_settings = pet_view.line_mode_settings_instance
	var props = line_mode_settings.get_properties()

	var line_updated = false
	for i in range(start_line, end_line):
		var line = get_line(i).strip_edges()
		if line.empty() or line == "" or line.begins_with(";"): continue

		var parts = split_line(line)
		if parts.size() < 2: continue

		var b1 = int(parts[0])
		var b2 = int(parts[1])

		if (b1 == start_ball and b2 == end_ball) or (b1 == end_ball and b2 == start_ball):
			if parts.size() < 10:
				parts.resize(10)
				for k in range(parts.size()):
					if parts[k] == null: parts[k] = "-1"

			parts[0] = str(start_ball)
			parts[1] = str(end_ball)

			if props.apply_fuzz: parts[2] = str(props.fuzz)
			if props.apply_color: parts[3] = str(props.color)
			if props.apply_left_outline: parts[4] = str(props.left_outline_color)
			if props.apply_right_outline: parts[5] = str(props.right_outline_color)
			if props.apply_start_thick: parts[6] = str(props.start_thickness)
			if props.apply_end_thick: parts[7] = str(props.end_thickness)
			if props.apply_outline_type: parts[8] = str(props.outline_type)
			if props.apply_draw_order: parts[9] = str(props.draw_order)

			set_line(i, parts.join(delim))
			line_updated = true
			if not silent:
				commit_full_snapshot("Updated Linez between %d and %d" % [start_ball, end_ball])
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
		
		var new_line = _join_array(new_line_parts, delim) + "\n"

		_insert_text_at_cursor_at_line(insert_line, new_line)

		if not silent:
			cursor_set_line(insert_line)
			cursor_set_column(0)
			center_viewport_to_cursor()
		
	if not silent:
		save_file(true)

func _on_Node_ball_selected(section, ball_no, is_addball, max_addball_no):
	select_ball(section, ball_no, is_addball, max_addball_no)

func select_ball(section, ball_no, is_addball, max_addball_no):
	var actual_start_point
	var current_line = cursor_get_line()

	if section == Section.Section.BALL:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		else:
			actual_start_point = find_line_in_ball_section(ball_no)
	elif section == Section.Section.MOVE:
		if is_addball:
			actual_start_point = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		else:
			actual_start_point = find_line_in_move_section(ball_no, current_line)
	elif section == Section.Section.PROJECT:
		actual_start_point = find_line_in_project_section(ball_no, current_line)
	elif section == Section.Section.LINE:
		actual_start_point = find_line_in_linez_section(ball_no, current_line)

	if actual_start_point == -1:
		return

	cursor_set_line(actual_start_point)
	cursor_set_column(0)
	center_viewport_to_cursor()

func _on_Node_ball_resized(ball_no: int, size_dif: int):
	resize_ball(ball_no, size_dif)

func resize_ball(ball_no: int, size_dif: int):
	var max_base_ball_no = KeyBallsData.max_base_ball_num
	var moved_ball_node = pet_node.ball_map.get(ball_no) if is_instance_valid(pet_node) else null
	var is_addball = ball_no > max_base_ball_no or (is_instance_valid(moved_ball_node) and moved_ball_node.is_in_group("addballs"))

	var section_tag = "[Ballz Info]"
	var size_field_index = 5  # 6th field is size
	if is_addball:
		section_tag = "[Add Ball]"
		size_field_index = 10  # 11th field is size for addballs
	
	var msg = "Resizing ball %d from section %s with size_dif = %d" % [ball_no, section_tag, size_dif]
	print("[STATUS] LnzTextEdit: _on_Node_ball_resized: " + msg)
	if console_log:
		console_log.log_message(msg)

	var bounds = get_section_bounds(section_tag)
	if bounds.empty():
		msg = "No %s section found. Cannot resize ball %d" % [section_tag, ball_no]
		print("[WARNING] LnzTextEdit: _on_Node_ball_resized: " + msg)
		if console_log:
			console_log.log_message(msg)
		return

	var start_line = bounds.start
	var end_line = bounds.end

	if is_addball:
		var delim = _detect_delimiter(start_line, end_line)
		var addball_index = ball_no - max_base_ball_no
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			if count == addball_index:
				var old_line = get_line(i) 
				var parts = split_line(raw)
				if parts.size() > size_field_index:
					var new_size = size_dif
					parts[size_field_index] = str(new_size)
					var new_line = _join_array(parts, delim)
					set_line(i, new_line)
					save_file(true)

					var success = commit_logical_change("Resized Ballz #%d" % ball_no, section_tag, ball_no, old_line, new_line, i)
					if not success:
						msg = "[HISTORY] Fallback: Line not found for ball %d in section %s. Committing full snapshot." % [ball_no, section_tag]
						print(msg)
						console_log.log_message(msg)
						commit_full_snapshot("Resized Ballz #%d [FULL COMMIT]" % ball_no)

					return
			count += 1
	else:
		var delim = _detect_delimiter(start_line, end_line)
		var count = 0
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			if count == ball_no:
				var old_line = get_line(i)
				var parts = split_line(raw)
				if parts.size() > size_field_index:
					var new_size = size_dif
					parts[size_field_index] = str(new_size)
					var new_line = _join_array(parts, delim)
					set_line(i, new_line)
					save_file(true)

					var success = commit_logical_change("Resized Ballz #%d" % ball_no, section_tag, ball_no, old_line, new_line, i)
					if not success:
						msg = "[HISTORY] Fallback: Line not found for ball %d in section %s. Committing full snapshot." % [ball_no, section_tag]
						print(msg)
						console_log.log_message(msg)
						commit_full_snapshot("Resized Ballz #%d [FULL COMMIT]" % ball_no)

					return
				else:
					return
			count += 1

func _on_Node_ball_moved(ball_no: int, new_pos: Vector3):
	move_ball(ball_no, new_pos)

func move_ball(ball_no: int, new_pos: Vector3):
	save_backup()
	var max_base_ball_no = KeyBallsData.max_base_ball_num
	var moved_ball_node = pet_node.ball_map.get(ball_no) if is_instance_valid(pet_node) else null
	var is_addball = ball_no > max_base_ball_no or (is_instance_valid(moved_ball_node) and moved_ball_node.is_in_group("addballs"))

	var section_tag = "[Move]"
	if is_addball:
		section_tag = "[Add Ball]"
	var bounds = get_section_bounds(section_tag)
	if bounds.empty():
		if section_tag == "[Move]":
			var first_section_line = search("[", 0, 0, 0)[SEARCH_RESULT_LINE]
			var all_lines = get_text().split("\n")
			all_lines.insert(first_section_line, "[Move]")
			#all_lines.insert(first_section_line + 1, "")
			_set_text_preserve(all_lines.join("\n"))
		else:
			return

	var start_line = bounds.start
	var end_line = bounds.end

	var delim = _detect_delimiter(start_line, end_line)

	if is_addball:
		moved_ball_node = pet_node.ball_map.get(ball_no)
		if moved_ball_node:
			var base_ball_no = moved_ball_node.base_ball_no
			var base_ball_node = pet_node.ball_map.get(base_ball_no)
			if base_ball_node:
				var world_rel = moved_ball_node.global_transform.origin - base_ball_node.global_transform.origin
				var new_relative_pos = LnzLiveUtils.world_to_lnz_delta(world_rel, pet_node.pixel_world_size, pet_node.lnz.scales.x)

				var idx = ball_no - KeyBallsData.max_base_ball_num
				var count = 0
				for i in range(start_line, end_line):
					var raw = get_line(i).strip_edges()
					if raw == "" or raw.begins_with(";"): continue
					if count == idx:
						var old_line = get_line(i)
						var parts = split_line(raw)
						if parts.size() >= 4:
							parts[1] = str(round(new_relative_pos.x))
							parts[2] = str(round(new_relative_pos.y))
							parts[3] = str(round(new_relative_pos.z))
							var new_line = _join_array(parts, delim)
							set_line(i, new_line)
							save_file(true)

							var success = commit_logical_change("Moved Addballz #%d" % ball_no, section_tag, ball_no, old_line, new_line, i)
							if not success:
								var msg = "[HISTORY] Fallback: Line not found for ball %d in section %s, committing full snapshot" % [ball_no, section_tag]
								print(msg)
								console_log.log_message(msg)
								commit_full_snapshot("Moved Addballz #%d [FULL COMMIT]" % ball_no)
						break
					count += 1
	else:
		var updated = false
		var head_id = KeyBallsData.get_ball_id_by_name("head")
		
		for i in range(start_line, end_line):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			
			if parts.size() >= 4 and parts[0].to_int() == ball_no:
				var old_line = get_line(i)
				
				var nx = parts[1].to_int() + new_pos.x
				var ny = parts[2].to_int() + new_pos.y
				var nz = parts[3].to_int() + new_pos.z
				
				parts[1] = str(nx)
				parts[2] = str(ny)
				parts[3] = str(nz)
				
				if KeyBallsData.get_group_balls("Head").has(ball_no):
					if abs(ny) > max_move_head or abs(nz) > max_move_head:
						if parts.size() < 5: 
							parts.resize(5) 
							parts[4] = str(head_id)
				
				var new_line = _join_array(parts, delim)
				set_line(i, new_line)
				updated = true
				save_file(true)

				var success = commit_logical_change("Moved Ballz #%d" % ball_no, section_tag, ball_no, old_line, new_line, i)
				if not success:
					var msg = "[HISTORY] Fallback: Line not found for ball %d in section %s, committing full snapshot" % [ball_no, section_tag]
					print(msg)
					commit_full_snapshot("Moved Ballz #%d [FULL COMMIT]" % ball_no)
				break

		if not updated:
			var nx = int(new_pos.x)
			var ny = int(new_pos.y)
			var nz = int(new_pos.z)
			var parts = [str(ball_no), str(nx), str(ny), str(nz)]
			
			if KeyBallsData.get_group_balls("Head").has(ball_no):
				if abs(ny) > max_move_head or abs(nz) > max_move_head:
					parts.append(str(head_id))
			
			var line_txt = _join_array(parts, delim)
			var insert_at = _find_insertion_line(start_line, end_line)
			_insert_text_at_cursor_at_line(insert_at, line_txt + "\n")
			save_file(true)
			commit_full_snapshot("Created Move for Ballz #%d" % ball_no)


### TOOLS MENU SIGNALS ###
# _on_ToolsMenu_create_addball
# create_addball
# _on_ToolsMenu_delete_ball
# delete_ball
# _on_ToolsMenu_omit_ball
# omit_ball
# _on_ToolsMenu_unomit_ball
# unomit_ball
# _on_ToolsMenu_clear_ball_paintballz
# _on_ToolsMenu_color_entire_pet
# _on_ToolsMenu_color_part_pet
# _on_ToolsMenu_copy_l_to_r
# _on_ToolsMenu_copy_r_to_l
# _on_ToolsMenu_recolor
# _on_ToolsMenu_apply_global_fuzz
# _resolve_recolor
# _apply_color_to_section

func _on_ToolsMenu_create_addball(reference_ball, also_connect_line := false):
	create_addball(reference_ball, also_connect_line)

func _gather_addball_properties(reference_ball, addball_data, ball_data) -> Dictionary:
	var props = {
		"target_base_ball": reference_ball.ball_no,
		"size": 20,
		"fuzz": 0,
		"texture_id": -1,
		"color": reference_ball.color_index,
		"outline_color": reference_ball.outline_color_index,
		"outline": reference_ball.outline,
		"bodyarea": 1,
		"position": Vector3(0, 0, 0)
	}

	# Size: addball_data, or ball_data fallback
	var is_addball_ref = reference_ball.ball_no >= KeyBallsData.max_base_ball_num or reference_ball.is_in_group("addballs")
	var s = 0
	if is_addball_ref and addball_data != null:
		if typeof(addball_data) == TYPE_DICTIONARY:
			if addball_data.has("ball_size"): s = int(addball_data["ball_size"])
			elif addball_data.has("size"): s = int(addball_data["size"])
		else:
			if "ball_size" in addball_data: s = int(addball_data.ball_size)
			elif "size" in addball_data: s = int(addball_data.size)
		
		if s > 0:
			props.size = s
		elif reference_ball.has_method("set_ball_size"):
			props.size = int(round(reference_ball.ball_size))
	elif reference_ball.has_method("set_ball_size"):
		props.size = int(round(reference_ball.ball_size))

	# Fuzz and Texture: addball_data, or ball_data fallback
	if addball_data != null:
		props.fuzz = addball_data.fuzz
		props.texture_id = addball_data.texture_id
	elif ball_data != null:
		props.fuzz = ball_data.fuzz
		props.texture_id = ball_data.texture_id

	# 3. Visual State
	if reference_ball.get("current_outline_state") != 0:
		props.outline = reference_ball.old_outline
		props.outline_color = reference_ball.old_outline_color

	# 4. Data Dictionary
	if addball_data != null:
		if "color" in addball_data: props.color = addball_data.color
		if "outline_color" in addball_data: props.outline_color = addball_data.outline_color
		elif "outline_color_index" in addball_data: props.outline_color = addball_data.outline_color_index
		if "outline" in addball_data: props.outline = addball_data.outline
	elif ball_data != null:
		if "color" in ball_data: props.color = ball_data.color
		if "outline_color" in ball_data: props.outline_color = ball_data.outline_color
		elif "outline_color_index" in ball_data: props.outline_color = ball_data.outline_color_index
		if "outline" in ball_data: props.outline = ball_data.outline

	# 5. Base ball and position
	if reference_ball.base_ball_no != -1:
		props.target_base_ball = reference_ball.base_ball_no
		if addball_data != null:
			props.position = addball_data.position

	# 6. Bodyarea
	if KeyBallsData.bodyarea_map.has(props.target_base_ball):
		props.bodyarea = KeyBallsData.bodyarea_map[props.target_base_ball]
	else:
		print("[WARNING] LnzTextEdit: _gather_addball_properties: Missing bodyarea for ball %d. Defaulting to 1." % props.target_base_ball)

	return props

func _construct_addball_line(props: Dictionary, delim: String) -> String:
	var fields = [
		str(props.target_base_ball),
		str(int(props.position.x)),
		str(int(props.position.y)),
		str(int(props.position.z)),
		str(props.color),
		str(props.outline_color),
		"0",
		str(props.fuzz),
		"0",
		str(props.outline),
		str(props.size),
		str(props.bodyarea),
		"0",
		str(props.texture_id)
	]
	return _join_array(fields, delim) + "\n"

func create_addball(reference_ball, also_connect_line := false):
	# save_backup()
	if reference_ball == null:
		var msg = "No reference ball given. Cannot add new ball."
		print("[WARNING] LnzTextEdit: _on_ToolsMenu_add_ball: " + msg)
		if console_log:
			console_log.log_message(msg)
		return

	var ball_no = reference_ball.ball_no
	var lnz = pet_node.lnz
	var addball_data = lnz.addballs.get(ball_no, null)
	var ball_data = lnz.balls.get(ball_no, null)

	var props = _gather_addball_properties(reference_ball, addball_data, ball_data)

	var section_find = search("[Add Ball]", 0, 0, 0)
	if section_find.empty():
		var msg = "No [Add Ball] section found. Cannot add new ball."
		print("[WARNING] LnzTextEdit: _on_ToolsMenu_add_ball: " + msg)
		if console_log:
			console_log.log_message(msg)
		return
	var start_line = section_find[SEARCH_RESULT_LINE] + 1
	var end_line = search("[", 0, start_line, 0)[SEARCH_RESULT_LINE]
	var delim = _detect_delimiter(start_line, end_line)
	var insert_line = _find_insertion_line(start_line, end_line)

	var line_text = _construct_addball_line(props, delim)
	_insert_text_at_cursor_at_line(insert_line, line_text)
	cursor_set_line(insert_line)
	cursor_set_column(0)
	center_viewport_to_cursor()

	# save_file(false,true)

	var addball_no = KeyBallsData.max_base_ball_num + _count_section_entries("[Add Ball]") - 1
	commit_full_snapshot("Created Addballz #%d" % addball_no)

	var success = pet_node.inject_single_addball(props, addball_no, reference_ball)
	if not success:
		printerr("[ERROR] LnzTextEdit: create_addball: failed to inject visual ball")
		return

	if also_connect_line:
		create_line(addball_no, reference_ball.ball_no, true)

	if pet_view and pet_view.has_method("schedule_autodrag_for_addball"):
		pet_view.schedule_autodrag_for_addball(addball_no)

func _on_ToolsMenu_delete_ball(ball_no: int):
	delete_ball(ball_no)

func delete_ball(ball_no: int):
	save_backup()
	var is_addball = ball_no > KeyBallsData.max_base_ball_num
	if is_addball:
		var line_no = find_line_in_addball_section(ball_no - KeyBallsData.max_base_ball_num)
		if line_no != -1:
			select(line_no, 0, line_no + 1, 0)
			cut()
		_update_all_references(ball_no)
	else:
		pass 
	save_file(true)
	commit_full_snapshot("Deleted Addballz #%d" % ball_no)

func _on_ToolsMenu_omit_ball(ball_no: int):
	omit_ball(ball_no)

func omit_ball(ball_no: int):
	save_backup()
	var section = search("[Omissions]", 0, 0, 0)
	if section.empty():
		cursor_set_line(get_line_count())
		insert_text_at_cursor("\n[Omissions]\n" + str(ball_no))
	else:
		var line_idx = section[SEARCH_RESULT_LINE] + 1
		cursor_set_line(line_idx)
		cursor_set_column(0)
		insert_text_at_cursor(str(ball_no) + "\n")
	save_file(true)
	commit_full_snapshot("Omitted Ballz #%d" % ball_no)

func _on_ToolsMenu_unomit_ball(ball_no: int):
	unomit_ball(ball_no)

func unomit_ball(ball_no: int):
	save_backup()
	var section = search("[Omissions]", 0, 0, 0)
	if section.empty():
		return

	var start = section[SEARCH_RESULT_LINE] + 1
	var i = 0
	
	while true:
		var line_idx = start + i
		if line_idx >= get_line_count(): break
		
		var line = get_line(line_idx).strip_edges()
		if line.begins_with("["): break 
		
		if line == str(ball_no):
			select(line_idx, 0, line_idx + 1, 0)
			cut()
			save_file(true)
			commit_full_snapshot("Unomitted Ballz #%d" % ball_no)
			return
		
		i += 1

func _on_ToolsMenu_clear_ball_paintballz(ball_no: int):
	save_backup()
	print("[STATUS] LnzTextEdit: _on_ToolsMenu_clear_ball_paintballz: Commenting out paintballz for ball_no %d" % ball_no)
	var bounds = get_section_bounds("[Paint Ballz]")
	if bounds.empty(): return

	var lines_to_comment = []

	for i in range(bounds.start, bounds.end):
		var line = get_line(i)
		var stripped = line.strip_edges()
		
		if stripped.empty() or stripped.begins_with(";"): continue

		var parts = split_line(stripped) 
		if parts.size() > 0 and parts[0].is_valid_integer() and int(parts[0]) == ball_no:
			lines_to_comment.append(i)

	if not lines_to_comment.empty():
		_apply_comments(lines_to_comment, "; ")
		
		var count = lines_to_comment.size()
		save_file(true)
		commit_full_snapshot("Commented out %d Paintballz from Ballz #%d" % [count, ball_no])
		if console_log:
			console_log.log_message("[LNZ EDIT] Commented out %d Paintballz from Ballz #%d" % [count, ball_no])

func _on_ToolsMenu_color_entire_pet(color_index, outline_color_index):
	save_backup()
	var species = KeyBallsData.species
	var balls_to_exclude: Array = []
	
	if species == KeyBallsData.Species.CAT:
		for b in KeyBallsData.move_groups_cat["Eyes"]:
			balls_to_exclude.append(b)
		for n in KeyBallsData.nose_cat:
			balls_to_exclude.append(n)
		for t in KeyBallsData.tongue_cat:
			balls_to_exclude.append(t)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["left"]:
			balls_to_exclude.append(w)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["right"]:
			balls_to_exclude.append(w)
	elif species == KeyBallsData.Species.DOG:
		for b in KeyBallsData.move_groups_dog["Eyes"]:
			balls_to_exclude.append(b)
		for n in KeyBallsData.nose_dog:
			balls_to_exclude.append(n)
		for t in KeyBallsData.tongue_dog:
			balls_to_exclude.append(t)
	elif species == KeyBallsData.Species.BABY:
		for b in KeyBallsData.move_groups_bab["Eyes"]:
			balls_to_exclude.append(b)
		for t in KeyBallsData.tongue_bab:
			balls_to_exclude.append(t)
		for e in KeyBallsData.eyebrow_bab:
			balls_to_exclude.append(e)

	# Find and exclude any addballs attached to the currently excluded base balls
	var addball_bounds = get_section_bounds("[Add Ball]")
	if not addball_bounds.empty():
		var count = 0
		for i in range(addball_bounds.start, addball_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";") or line.begins_with("["): 
				continue
			
			var parts = split_line(line)
			if parts.size() > 0:
				var base_ball_id = parts[0].to_int()
				
				# If this addball's parent is in the exclusion list, protect this addball too
				if base_ball_id in balls_to_exclude:
					var absolute_addball_id = count + KeyBallsData.max_base_ball_num
					balls_to_exclude.append(absolute_addball_id)
			count += 1

	_apply_color_to_section("[Ballz Info]", 0, 1, balls_to_exclude, color_index, outline_color_index)
	_apply_color_to_section_addball("[Add Ball]", 4, 5, balls_to_exclude, color_index, outline_color_index)
	
	save_file(true)
	commit_full_snapshot("Applied Colors")

func _on_ToolsMenu_color_part_pet(core_ball_nos, color_index, outline_color_index, intended_part):
	save_backup()
	var species = KeyBallsData.species
	var balls_to_exclude: Array = []
	
	if species == KeyBallsData.Species.CAT:
		for b in KeyBallsData.move_groups_cat["Eyes"]: balls_to_exclude.append(b)
		if intended_part != "TONGUE":
			for t in KeyBallsData.tongue_cat: balls_to_exclude.append(t)
		if intended_part != "NOSE":
			for n in KeyBallsData.nose_cat: balls_to_exclude.append(n)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["left"]: balls_to_exclude.append(w)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["right"]: balls_to_exclude.append(w)
	elif species == KeyBallsData.Species.DOG:
		for b in KeyBallsData.move_groups_dog["Eyes"]: balls_to_exclude.append(b)
		if intended_part != "TONGUE":
			for t in KeyBallsData.tongue_dog: balls_to_exclude.append(t)
		if intended_part != "NOSE":
			for n in KeyBallsData.nose_dog: balls_to_exclude.append(n)
		for w in KeyBallsData.dog_body_part_symmetry["Head"]["Whiskers"]["left"]: balls_to_exclude.append(w)
		for w in KeyBallsData.dog_body_part_symmetry["Head"]["Whiskers"]["right"]: balls_to_exclude.append(w)
	elif species == KeyBallsData.Species.BABY:
		for b in KeyBallsData.move_groups_bab["Eyes"]: balls_to_exclude.append(b)
		if intended_part != "TONGUE":
			for t in KeyBallsData.tongue_bab: balls_to_exclude.append(t)
		for e in KeyBallsData.eyebrow_bab: balls_to_exclude.append(e)

	_apply_color_to_section_with_filter("[Ballz Info]", 0, 1, core_ball_nos, color_index, outline_color_index)
	_apply_color_to_section_addball_with_filter("[Add Ball]", 4, 5, core_ball_nos, color_index, outline_color_index)
	
	save_file(true)
	commit_full_snapshot("Applied Colors")

func _on_ToolsMenu_copy_l_to_r(selected_ball_no: int = -1):
	if selected_ball_no == -1:
		_mirror_l_to_r_full()
	else:
		_mirror_l_to_r_ball(selected_ball_no)

func _on_ToolsMenu_copy_r_to_l(selected_ball_no: int = -1):
	_mirror_l_to_r_full(true)

func _apply_recolor_rules_to_parts(parts: Array, recolor_rules: Array, color_idx: int, outline_idx: int, texture_idx: int, info_dict) -> Dictionary:
	var updates = {}
	if parts.size() <= color_idx: return updates

	var current_texture = ""
	if texture_idx != -1 and texture_idx < parts.size():
		current_texture = parts[texture_idx]

	var current_color = parts[color_idx]
	var new_color = _resolve_recolor(current_color, false, recolor_rules, info_dict, current_texture)
	if new_color != null:
		updates[color_idx] = new_color
		# Check for texture change on the matching rule
		for r in recolor_rules:
			var tm = r.before_texture.empty() or r.before_texture == current_texture
			if tm and not r.is_ramp and not r.before_color.empty() and not r.after_color.empty():
				if r.before_color == current_color and not r.after_texture.empty():
					if texture_idx != -1: updates[texture_idx] = r.after_texture
				break

	if outline_idx != -1 and outline_idx < parts.size():
		var current_outline = parts[outline_idx]
		var new_outline = _resolve_recolor(current_outline, true, recolor_rules, info_dict, current_texture)
		if new_outline != null:
			updates[outline_idx] = new_outline

	return updates

func _apply_multi_color_recolor(parts: Array, recolor_rules: Array, color_indices: Array, info_dict) -> Dictionary:
	var updates = {}
	for ci in color_indices:
		if ci >= parts.size(): continue
		var current_color = parts[ci]
		var new_color = _resolve_recolor(current_color, false, recolor_rules, info_dict, "")
		if new_color != null:
			updates[ci] = new_color
	return updates

func _on_ToolsMenu_recolor(all_recolor_info: Dictionary):
	save_backup()
	
	var recolor_rules = all_recolor_info.recolors
	
	var species = KeyBallsData.species
	var balls_to_exclude: Array = []
	if species == KeyBallsData.Species.CAT:
		for b in KeyBallsData.move_groups_cat["Eyes"]: balls_to_exclude.append(b)
		for n in KeyBallsData.nose_cat: balls_to_exclude.append(n)
		for t in KeyBallsData.tongue_cat: balls_to_exclude.append(t)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["left"]: balls_to_exclude.append(w)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["right"]: balls_to_exclude.append(w)
	elif species == KeyBallsData.Species.DOG:
		for b in KeyBallsData.move_groups_dog["Eyes"]: balls_to_exclude.append(b)
		for n in KeyBallsData.nose_dog: balls_to_exclude.append(n)
		for t in KeyBallsData.tongue_dog: balls_to_exclude.append(t)
		for w in KeyBallsData.dog_body_part_symmetry["Head"]["Whiskers"]["left"]: balls_to_exclude.append(w)
		for w in KeyBallsData.dog_body_part_symmetry["Head"]["Whiskers"]["right"]: balls_to_exclude.append(w)
	elif species == KeyBallsData.Species.BABY:
		for b in KeyBallsData.move_groups_bab["Eyes"]: balls_to_exclude.append(b)
		for t in KeyBallsData.tongue_bab: balls_to_exclude.append(t)

	# [Ballz Info] - color=0, outline=1, texture=7
	if all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var bounds = get_section_bounds("[Ballz Info]")
		if not bounds.empty():
			var count = 0
			for i in range(bounds.start, bounds.end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["): continue
				if _idx_in_list(count, balls_to_exclude):
					count += 1
					continue
				var parts = split_line(line)
				if parts.size() < 8:
					count += 1
					continue
				var updates = _apply_recolor_rules_to_parts(parts, recolor_rules, 0, 1, 7, all_recolor_info)
				if not updates.empty():
					var delim = _detect_delimiter(bounds.start, bounds.end)
					set_line(i, _update_fields(parts, updates, delim))
				count += 1

	# [Add Ball] - color=4, outline=5, texture=13
	if all_recolor_info.balls_on or all_recolor_info.ball_outlines_on:
		var bounds = get_section_bounds("[Add Ball]")
		if not bounds.empty():
			var count = 0
			for i in range(bounds.start, bounds.end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["): continue
				var parts = split_line(line)
				if parts.size() < 6 or int(parts[0]) in balls_to_exclude:
					count += 1
					continue
				var texture_idx = 13 if parts.size() > 13 else -1
				var updates = _apply_recolor_rules_to_parts(parts, recolor_rules, 4, 5, texture_idx, all_recolor_info)
				if not updates.empty():
					var delim = _detect_delimiter(bounds.start, bounds.end)
					set_line(i, _update_fields(parts, updates, delim))
				count += 1

	# [Paint Ballz] - color=5, outline=6, texture=10
	if all_recolor_info.paintballs_on:
		var bounds = get_section_bounds("[Paint Ballz]")
		if not bounds.empty():
			var count = 0
			for i in range(bounds.start, bounds.end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["): continue
				var parts = split_line(line)
				if parts.size() < 11 or int(parts[0]) in balls_to_exclude:
					count += 1
					continue
				var updates = _apply_recolor_rules_to_parts(parts, recolor_rules, 5, 6, 10, all_recolor_info)
				if not updates.empty():
					var delim = _detect_delimiter(bounds.start, bounds.end)
					set_line(i, _update_fields(parts, updates, delim))
				count += 1

	# [Linez] - main=3, left=4, right=5 (no texture)
	if all_recolor_info.lines_on:
		var bounds = get_section_bounds("[Linez]")
		if not bounds.empty():
			var count = 0
			for i in range(bounds.start, bounds.end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["): continue
				var parts = split_line(line)
				if parts.size() < 6:
					count += 1
					continue
				var updates = _apply_multi_color_recolor(parts, recolor_rules, [3, 4, 5], all_recolor_info)
				if not updates.empty():
					var delim = _detect_delimiter(bounds.start, bounds.end)
					set_line(i, _update_fields(parts, updates, delim))
				count += 1

	# [Polygons] - main=4, left=5, right=6, texture=8
	if all_recolor_info.polygons_on:
		var bounds = get_section_bounds("[Polygons]")
		if not bounds.empty():
			var count = 0
			for i in range(bounds.start, bounds.end):
				var line = get_line(i).strip_edges()
				if line.empty() or line.begins_with(";") or line.begins_with("["): continue
				var parts = split_line(line)
				if parts.size() < 5:
					count += 1
					continue
				var texture_idx = 8 if parts.size() > 8 else -1
				var updates = _apply_recolor_rules_to_parts(parts, recolor_rules, 4, 5, texture_idx, all_recolor_info)
				if not updates.empty():
					var delim = _detect_delimiter(bounds.start, bounds.end)
					set_line(i, _update_fields(parts, updates, delim))
				count += 1
				# Also apply to right edge if it exists
				if parts.size() > 6:
					var updates2 = _apply_recolor_rules_to_parts(parts, recolor_rules, 6, -1, texture_idx, all_recolor_info)
					if not updates2.empty():
						var delim = _detect_delimiter(bounds.start, bounds.end)
						set_line(i, _update_fields(parts, updates2, delim))
				count += 1

	# [256 Eyelid Color] - left=0, right=1 (no texture)
	var eyelid_bounds = get_section_bounds("[256 Eyelid Color]")
	if not eyelid_bounds.empty():
		var count = 0
		for i in range(eyelid_bounds.start, eyelid_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";") or line.begins_with("["): continue
			var parts = split_line(line)
			if parts.size() < 2:
				count += 1
				continue
			var updates = _apply_multi_color_recolor(parts, recolor_rules, [0, 1], all_recolor_info)
			if not updates.empty():
				var delim = _detect_delimiter(eyelid_bounds.start, eyelid_bounds.end)
				set_line(i, _update_fields(parts, updates, delim))
			count += 1
				
	save_file(true)
	commit_full_snapshot("Performed Color Swap")

func _on_ToolsMenu_apply_global_fuzz(fuzz):
	save_backup()
	var balls_to_exclude: Array = _get_omitted_balls()
	if KeyBallsData.species == KeyBallsData.Species.CAT:
		for b in KeyBallsData.move_groups_cat["Eyes"]: balls_to_exclude.append(b)
		for t in KeyBallsData.tongue_cat: balls_to_exclude.append(t)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["left"]: balls_to_exclude.append(w)
		for w in KeyBallsData.cat_body_part_symmetry["Head"]["Whiskers"]["right"]: balls_to_exclude.append(w)
	elif KeyBallsData.species == KeyBallsData.Species.DOG:
		for b in KeyBallsData.move_groups_dog["Eyes"]: balls_to_exclude.append(b)
		for t in KeyBallsData.tongue_dog: balls_to_exclude.append(t)
		for w in KeyBallsData.dog_body_part_symmetry["Head"]["Whiskers"]["left"]: balls_to_exclude.append(w)
		for w in KeyBallsData.dog_body_part_symmetry["Head"]["Whiskers"]["right"]: balls_to_exclude.append(w)
	elif KeyBallsData.species == KeyBallsData.Species.BABY:
		for b in KeyBallsData.move_groups_bab["Eyes"]: balls_to_exclude.append(b)
		for t in KeyBallsData.tongue_bab: balls_to_exclude.append(t)

	# [Ballz Info] — field index 3
	_for_each_matching_line_in_section_with_field("[Ballz Info]", -1, 3, balls_to_exclude, str(fuzz))

	# [Add Ball] — field index 7
	var addball_bounds = get_section_bounds("[Add Ball]")
	if not addball_bounds.empty():
		var delim = _detect_delimiter(addball_bounds.start, addball_bounds.end)
		var count = 0
		for i in range(addball_bounds.start, addball_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			var addball_id = KeyBallsData.max_base_ball_num + count
			var parts = split_line(line)
			if parts.size() > 7 and not (addball_id in balls_to_exclude):
				parts[7] = str(fuzz)
				set_line(i, _join_array(parts, delim))
			count += 1

	# [Linez] — field index 2, check both start/end balls
	var linez_bounds = get_section_bounds("[Linez]")
	if not linez_bounds.empty():
		var delim = _detect_delimiter(linez_bounds.start, linez_bounds.end)
		for i in range(linez_bounds.start, linez_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			var parts = split_line(line)
			if parts.size() > 2:
				var b1 = int(parts[0])
				var b2 = int(parts[1])
				if not (b1 in balls_to_exclude or b2 in balls_to_exclude):
					parts[2] = str(fuzz)
					set_line(i, _join_array(parts, delim))

	save_file(true)
	commit_full_snapshot("Applied Global Fuzz: " + str(fuzz))

func _resolve_recolor(color_str: String, is_outline: bool, rules: Array, info, texture: String):
	for rule in rules:
		var texture_match = rule.before_texture.empty() or rule.before_texture == texture
		if not texture_match: continue
		if is_outline and not info.ball_outlines_on: continue
		if not is_outline and not info.balls_on: continue
		var new_color = null
		if rule.is_ramp:
			new_color = LnzLiveUtils.get_ramp_color(color_str, rule)
		else:
			var color_match = rule.before_color.empty() or rule.before_color == color_str
			if color_match and not rule.after_color.empty():
				new_color = rule.after_color
		if new_color != null:
			return new_color
	return null

func _apply_section_colors(section_name: String, color_field: int, outline_field: int, target_list: Array, color_val, outline_val, filter_mode: int = FilterMode.EXCLUDE, is_addball: bool = false) -> void:
	var bounds = get_section_bounds(section_name)
	if bounds.empty(): return
	
	var delim = _detect_delimiter(bounds.start, bounds.end)
	var min_parts = 6 if is_addball else 2
	var item_index = 0
	
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		
		if line.empty() or line.begins_with(";") or line.begins_with("["):
			continue
			
		var parts = split_line(line)
		
		if parts.size() < min_parts:
			continue
			
		var check_id = item_index
		if is_addball:
			check_id += KeyBallsData.max_base_ball_num
			
		var in_list = _idx_in_list(check_id, target_list)
		var should_skip = false
		
		if filter_mode == FilterMode.EXCLUDE and in_list:
			should_skip = true
		elif filter_mode == FilterMode.INCLUDE and not in_list:
			should_skip = true
			
		if should_skip:
			item_index += 1
			continue
			
		if not str(color_val).empty(): 
			parts[color_field] = str(color_val)
		if not str(outline_val).empty(): 
			parts[outline_field] = str(outline_val)
			
		set_line(i, _join_array(parts, delim) + " ")
		item_index += 1

func _apply_color_to_section(section_name: String, color_field: int, outline_field: int, exclude_list: Array, color_val, outline_val) -> void:
	_apply_section_colors(section_name, color_field, outline_field, exclude_list, color_val, outline_val, FilterMode.EXCLUDE, false)

func _apply_color_to_section_addball(section_name: String, color_field: int, outline_field: int, exclude_list: Array, color_val, outline_val) -> void:
	_apply_section_colors(section_name, color_field, outline_field, exclude_list, color_val, outline_val, FilterMode.EXCLUDE, true)

func _apply_color_to_section_with_filter(section_name: String, color_field: int, outline_field: int, filter_list: Array, color_val, outline_val) -> void:
	_apply_section_colors(section_name, color_field, outline_field, filter_list, color_val, outline_val, FilterMode.INCLUDE, false)

func _apply_color_to_section_addball_with_filter(section_name: String, color_field: int, outline_field: int, filter_list: Array, color_val, outline_val) -> void:
	_apply_section_colors(section_name, color_field, outline_field, filter_list, color_val, outline_val, FilterMode.INCLUDE, true)


### MIRRORING & SYMMETRY ###
# _mirror_l_to_r_full
# _mirror_l_to_r_ball
# _build_ball_map_for_mirror
# _get_mirrored_counterpart
# _process_section_for_mirror
# _process_move_section_for_mirror
# _process_linez_line_for_mirror
# _process_paintball_line_for_mirror
# _mirror_ball_attributes
# _mirror_move_processor
# _mirror_linez_processor
# _mirror_projection_processor
# _mirror_paintball_processor

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
	var bounds = get_section_bounds("[Ballz Info]")
	if bounds.empty():
		# print("[LNZ EDIT] No [Ballz Info] found!")
		# if console_log:
		# 	console_log.log_message("[LNZ EDIT] No [Ballz Info] found!")
		return

	var delim = _detect_delimiter(bounds.start, bounds.end)
	
	var base_mirror_map = {} 
	
	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if line.begins_with("[") or line.begins_with(";") or line.empty(): continue
			
		var ball_no = _get_line_no_from_line_index(i, "[Ballz Info]")
		if ball_no == -1: continue
		
		if ball_no in source_list:
			var target_base = -1
			var candidate = find_mirrored_ball(ball_no)
			
			if candidate == ball_no:
				if reverse: target_base = get_corresponding_left_ball(ball_no)
				else: target_base = get_corresponding_right_ball(ball_no)
			else:
				target_base = candidate
				
			if target_base != -1 and target_base != ball_no:
				base_mirror_map[ball_no] = target_base
				
				if !(target_base in omitted_balls):
					var parts = split_line(line)
					var mirrored_attrs = _mirror_ball_attributes(parts, false)
					var mirrored_line = _update_fields(parts, mirrored_attrs, delim)
					
					var target_line_idx = find_line_in_ball_section(target_base)
					if target_line_idx != -1:
						set_line(target_line_idx, mirrored_line)

	# [Add Ball]
	bounds = get_section_bounds("[Add Ball]")
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
			var parts = split_line(strip)
			var sig = _join_array(parts, delim)
			if !existing_signatures.has(sig):
				existing_signatures[sig] = sig_scan_id
			sig_scan_id += 1

	var next_free_id = sig_scan_id
	
	for line in addball_lines_content:
		var strip_line = line.strip_edges()
		if strip_line.begins_with("[") or strip_line.begins_with(";") or strip_line.empty(): continue

		var is_source = false
		var parts = split_line(strip_line)
		
		if current_scan_id in omitted_balls:
			is_source = false
		elif parts.size() > 0:
			var base_ball = parts[0].to_int()
			var x_pos = parts[1].to_float() if parts.size() > 1 else 0.0
			is_source = _is_ball_on_source_side(base_ball, source_list, source_addballs_found, middle_balls_list, x_pos, reverse)
		
		if is_source:
			source_addballs_found.append(current_scan_id)
			
			var old_base = parts[0].to_int()
			var new_base = _resolve_mirror_id(old_base, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
				
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(new_base)
			if mirrored_parts.size() > 1:
				mirrored_parts[1] = str(mirrored_parts[1].to_float() * -1.0)
			if mirrored_parts.size() > 9:
				if mirrored_parts[9] == "0": mirrored_parts[9] = "-2"
				elif mirrored_parts[9] == "-2": mirrored_parts[9] = "0"

			var suffix = "RtoL" if reverse else "LtoR"
			var inf_comment = " ; copyMirr%s_srcAdd#%d_to_mirAdd#%d" % [suffix, current_scan_id, next_free_id]
			var mirror_sig = _join_array(mirrored_parts, delim) + inf_comment
			
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

	bounds = get_section_bounds("[Linez]")
	if not bounds.empty():
		delim = _detect_delimiter(bounds.start, bounds.end)
		
		var existing_linez_signatures = {}
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
				var parts = split_line(line)
				var sig = _join_array(parts, delim)
				existing_linez_signatures[sig] = true

		var linez_content = []
		for i in range(bounds.start, bounds.end):
			linez_content.append(get_line(i))
			
		for line in linez_content:
			var strip = line.strip_edges()
			if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
				var parts = split_line(strip)
				if parts.size() < 2: continue
				
				var s = parts[0].to_int()
				var e = parts[1].to_int()
				
				var s_is_src = (s in source_list) or (s in source_addballs_found)
				var e_is_src = (e in source_list) or (e in source_addballs_found)
				
				if (s in middle_balls_list) and e_is_src: s_is_src = true
				if (e in middle_balls_list) and s_is_src: e_is_src = true

				if s_is_src or e_is_src:
					var m_s = _resolve_mirror_id(s, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
					var m_e = _resolve_mirror_id(e, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
					
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
						
						var suffix = "RtoL" if reverse else "LtoR"
						var inf_comment = " ; copyMirr%s_line(%d,%d)" % [suffix, m_s, m_e]
						var new_line_sig = _join_array(mirror_parts, delim) + inf_comment

						var reverse_mirror_parts = mirror_parts.duplicate()
						reverse_mirror_parts[0] = mirror_parts[1]
						reverse_mirror_parts[1] = mirror_parts[0]
						if reverse_mirror_parts.size() > 5:
							var temp = reverse_mirror_parts[4]
							reverse_mirror_parts[4] = reverse_mirror_parts[5]
							reverse_mirror_parts[5] = temp
						var reverse_sig = _join_array(reverse_mirror_parts, delim)
						
						if !existing_linez_signatures.has(new_line_sig) and !existing_linez_signatures.has(reverse_sig):
							final_linez_lines_to_append.append(new_line_sig)
							existing_linez_signatures[new_line_sig] = true

	# [Move]
	var final_move_lines = []

	bounds = get_section_bounds("[Move]")
	if not bounds.empty():
		delim = _detect_delimiter(bounds.start, bounds.end)
		
		var move_content = []
		for i in range(bounds.start, bounds.end):
			move_content.append(get_line(i))

		for line in move_content:
			var strip = line.strip_edges()
			if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
				var parts = split_line(strip)
				if parts.size() < 1: continue
				var move_ball = parts[0].to_int()

				if !(move_ball in target_list):
					final_move_lines.append(strip)

				var is_src = (move_ball in source_list) or (move_ball in source_addballs_found)
				
				if is_src:
					var m_move_ball = _resolve_mirror_id(move_ball, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
					
					if m_move_ball != -1:
						var mirror_parts = Array(parts)
						mirror_parts[0] = str(m_move_ball)
						if mirror_parts.size() > 1:
							mirror_parts[1] = str(mirror_parts[1].to_float() * -1.0)
						
						if mirror_parts.size() > 4:
							var old_anchor = mirror_parts[4].to_int()
							var new_anchor = _resolve_mirror_id(old_anchor, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
							
							if new_anchor != -1:
								mirror_parts[4] = str(new_anchor)

						final_move_lines.append(_join_array(mirror_parts, delim))

	# [Project Ball]
	var final_proj_lines = []

	bounds = get_section_bounds("[Project Ball]")
	if not bounds.empty():
		delim = _detect_delimiter(bounds.start, bounds.end)
		
		var proj_content = []
		for i in range(bounds.start, bounds.end):
			proj_content.append(get_line(i))

		for line in proj_content:
			var strip = line.strip_edges()
			if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
				var parts = split_line(strip)
				if parts.size() < 2: continue
				
				var b = parts[0].to_int()
				var m = parts[1].to_int()

				if !(b in target_list) and !(m in target_list):
					final_proj_lines.append(strip)

				var b_is_src = (b in source_list) or (b in source_addballs_found)
				var m_is_src = (m in source_list) or (m in source_addballs_found)
				
				if b_is_src or m_is_src:
					var m_b = _resolve_mirror_id(b, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
					var m_m = _resolve_mirror_id(m, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
					
					if m_b != -1 and m_m != -1:
						var mirror_parts = Array(parts)
						mirror_parts[0] = str(m_b)
						mirror_parts[1] = str(m_m)
						final_proj_lines.append(_join_array(mirror_parts, delim))
	
	# [Paint Ballz]
	var final_paint_lines_to_append = []

	bounds = get_section_bounds("[Paint Ballz]")
	if not bounds.empty():
		delim = _detect_delimiter(bounds.start, bounds.end)
		
		var existing_paint_sigs = {}
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
				var parts = split_line(line)
				existing_paint_sigs[_join_array(parts, delim)] = true
		
		var paint_content = []
		for i in range(bounds.start, bounds.end):
			paint_content.append(get_line(i))
			
		for line in paint_content:
			var strip = line.strip_edges()
			if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
				var parts = split_line(strip)
				if parts.size() < 3: continue
				
				var base = parts[0].to_int()
				var x = parts[2].to_float()
				
				var is_src = false
				if base in source_list: is_src = true
				elif base in middle_balls_list:
					if abs(x) > 0.001: is_src = true
					
				if is_src:
					var m_base = _resolve_mirror_id(base, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
					if m_base == -1: m_base = base
					
					var mirror_parts = Array(parts)
					mirror_parts[0] = str(m_base)
					mirror_parts[2] = str(x * -1.0)
					
					var new_sig = _join_array(mirror_parts, delim)
					
					if !existing_paint_sigs.has(new_sig):
						final_paint_lines_to_append.append(new_sig)
						existing_paint_sigs[new_sig] = true

	if !final_addball_lines_to_append.empty():
		var bounds_ab = get_section_bounds("[Add Ball]")
		var ins_line = _find_insertion_line(bounds_ab.start, bounds_ab.end)
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_addball_lines_to_append, "\n") + "\n")
		
	if !final_linez_lines_to_append.empty():
		var bounds_l = get_section_bounds("[Linez]")
		var ins_line = _find_insertion_line(bounds_l.start, bounds_l.end)
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_linez_lines_to_append, "\n") + "\n")

	if !final_move_lines.empty():
		_replace_section_content("[Move]", final_move_lines)

	if !final_proj_lines.empty():
		_replace_section_content("[Project Ball]", final_proj_lines)

	if !final_paint_lines_to_append.empty():
		var bounds_p = get_section_bounds("[Paint Ballz]")
		var ins_line = _find_insertion_line(bounds_p.start, bounds_p.end)
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_paint_lines_to_append, "\n") + "\n")

	# [Polygons]
	var final_poly_lines_to_append = []
	var existing_poly_sigs = {}
	var poly_bounds = get_section_bounds("[Polygons]")
	if not poly_bounds.empty():
		delim = _detect_delimiter(poly_bounds.start, poly_bounds.end)
		for i in range(poly_bounds.start, poly_bounds.end):
			var line = get_line(i).strip_edges()
			if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
				existing_poly_sigs[line] = true
		
		var poly_content = []
		for i in range(poly_bounds.start, poly_bounds.end):
			poly_content.append(get_line(i))
		
		for line in poly_content:
			var strip = line.strip_edges()
			if !strip.begins_with("[") and !strip.begins_with(";") and !strip.empty():
				var parts = split_line(strip)
				if parts.size() < 4: continue
				
				var b0 = parts[0].to_int()
				var b1 = parts[1].to_int()
				var b2 = parts[2].to_int()
				var b3 = parts[3].to_int()
				
				var m0 = _resolve_mirror_id(b0, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
				var m1 = _resolve_mirror_id(b1, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
				var m2 = _resolve_mirror_id(b2, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
				var m3 = _resolve_mirror_id(b3, reverse, base_mirror_map, middle_balls_list, source_to_mirror_map)
				
				if m0 == -1: m0 = find_mirrored_ball(b0)
				if m1 == -1: m1 = find_mirrored_ball(b1)
				if m2 == -1: m2 = find_mirrored_ball(b2)
				if m3 == -1: m3 = find_mirrored_ball(b3)
				
				if m0 == b0 and m1 == b1 and m2 == b2 and m3 == b3: continue
				
				var mirror_parts = Array(parts)
				mirror_parts[0] = str(m0)
				mirror_parts[1] = str(m1)
				mirror_parts[2] = str(m2)
				mirror_parts[3] = str(m3)
					
				# Swap edge colors (columns 5 and 6), same pattern as Linez
				if mirror_parts.size() > 6:
					var temp = mirror_parts[5]
					mirror_parts[5] = mirror_parts[6]
					mirror_parts[6] = temp
				
				var suffix = "RtoL" if reverse else "LtoR"
				var comment = " ; copyMirr%s_poly(%s,%s,%s,%s)" % [suffix, mirror_parts[0], mirror_parts[1], mirror_parts[2], mirror_parts[3]]
				var new_line = _join_array(mirror_parts, delim) + comment
				
				if !existing_poly_sigs.has(new_line):
					final_poly_lines_to_append.append(new_line)
					existing_poly_sigs[new_line] = true

	if not final_poly_lines_to_append.empty():
		var poly_bounds2 = get_section_bounds("[Polygons]")
		var ins_line = poly_bounds2.end
		_insert_text_at_cursor_at_line(ins_line, _join_array(final_poly_lines_to_append, "\n") + "\n")

	save_file(true)
	commit_full_snapshot("Mirrored L to R" if not reverse else "Mirrored R to L")

func _mirror_l_to_r_ball(target_ball_no: int):
	save_backup()

	if target_ball_no >= KeyBallsData.max_base_ball_num:
		var err_msg = "[LNZ EDIT] Copy-Mirror is only supported for base ballz (0-%d)" % (KeyBallsData.max_base_ball_num - 1)
		print(err_msg)
		if console_log:
			console_log.log_message(err_msg)
		return

	var mirrored_ball_no = find_mirrored_ball(target_ball_no)
	var is_mirrored = mirrored_ball_no != target_ball_no
	if !is_mirrored:
		print("[LNZ EDIT] Ballz #%d is a center ball, so mirroring Addballz/Linez/Paintballz to itself" % target_ball_no)
		if console_log:
			console_log.log_message("[LNZ EDIT] Ballz #%d is a center ball, so mirroring Addballz/Linez/Paintballz to itself" % target_ball_no)

	var omitted_balls = _get_omitted_balls()

	# [Ballz Info]
	var ballz_bounds = get_section_bounds("[Ballz Info]")
	var line_index = find_line_in_ball_section(target_ball_no)
	if line_index != -1:
		var delim = _detect_delimiter(ballz_bounds.start, ballz_bounds.end)
		var line = get_line(line_index)
		var parts = split_line(line)
		var mirrored_attrs = _mirror_ball_attributes(parts, false)
		var mirrored_line = _update_fields(parts, mirrored_attrs, delim)
		
		var mirrored_line_index = find_line_in_ball_section(mirrored_ball_no)
		if mirrored_line_index != -1:
			set_line(mirrored_line_index, mirrored_line)

	# Build a temporary map for newly created addballs
	var temp_addball_map = {}
	var new_addball_lines = []

	# [Add Ball]
	var addball_bounds = get_section_bounds("[Add Ball]")
	if !addball_bounds.empty():
		var delim = _detect_delimiter(addball_bounds.start, addball_bounds.end)
		var max_ball_no = KeyBallsData.max_base_ball_num + _count_section_entries("[Add Ball]")
		var new_addball_no = max_ball_no
		
		var addball_lines = []
		for i in range(addball_bounds.start, addball_bounds.end):
			addball_lines.append(get_line(i))

		var data_idx = 0
		for i in range(addball_lines.size()):
			var line = addball_lines[i].strip_edges()
			if line.empty() or line.begins_with(";"): continue

			var current_addball_no = KeyBallsData.max_base_ball_num + data_idx
			var parts = split_line(line)

			if parts.empty() or parts[0].to_int() != target_ball_no:
				data_idx += 1
				continue

			if omitted_balls.has(current_addball_no):
				print("[LNZ EDIT] Skipping Addballz #%d because it is in [Omissions]" % current_addball_no)
				if console_log:
					console_log.log_message("[LNZ EDIT] Skipping Addballz #%d because it is in [Omissions]" % current_addball_no)
				data_idx += 1
				continue

			var mirrored_attrs = _mirror_ball_attributes(parts, true)
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(mirrored_ball_no)
			for key in mirrored_attrs:
				mirrored_parts[key] = mirrored_attrs[key]
			
			var comment = " ; copyMirrLtoR_ball%d_to_ball%d" % [target_ball_no, mirrored_ball_no]
			new_addball_lines.append(_join_array(mirrored_parts, delim) + comment)
			temp_addball_map[current_addball_no] = new_addball_no
			new_addball_no += 1
			data_idx += 1
			
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
		var bounds = get_section_bounds(section_name)
		if bounds.empty(): continue

		var new_lines = []
		var delim = _detect_delimiter(bounds.start, bounds.end)
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			
			var parts = split_line(line)
			var processed_line = call(method_name, parts, target_ball_no, mirrored_ball_no, associated_left_balls, temp_addball_map)
			
			if processed_line != null and processed_line.size() > 0:
				var comment = " ; copyMirrLtoR_ball%d_to_ball%d" % [target_ball_no, mirrored_ball_no]
				new_lines.append(_join_array(processed_line, delim) + comment)
		
		if !new_lines.empty():
			var insert_line = _find_insertion_line(bounds.start, bounds.end)
			_insert_text_at_cursor_at_line(insert_line, _join_array(new_lines, "\n") + "\n")

	# [Polygons]
	var poly_bounds = get_section_bounds("[Polygons]")
	if !poly_bounds.empty():
		var delim = _detect_delimiter(poly_bounds.start, poly_bounds.end)
		var new_poly_lines = []
		var existing_poly_sigs = {}
		for i in range(poly_bounds.start, poly_bounds.end):
			var line = get_line(i).strip_edges()
			if !line.begins_with("[") and !line.begins_with(";") and !line.empty():
				existing_poly_sigs[line] = true
		
		for i in range(poly_bounds.start, poly_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";") or line.begins_with("["): continue
			
			var parts = split_line(line)
			if parts.size() < 4: continue
			
			var b0 = parts[0].to_int()
			var b1 = parts[1].to_int()
			var b2 = parts[2].to_int()
			var b3 = parts[3].to_int()
			
			var any_target = (b0 == target_ball_no) or (b1 == target_ball_no) or \
							 (b2 == target_ball_no) or (b3 == target_ball_no)
			
			if !any_target:
				for ball_id in [b0, b1, b2, b3]:
					if ball_id >= KeyBallsData.max_base_ball_num and pet_node.lnz.addballs.has(ball_id):
						if pet_node.lnz.addballs[ball_id].base == target_ball_no:
							any_target = true
							break
			
			if !any_target: continue
			
			var has_associated = (b0 in associated_left_balls) or (b1 in associated_left_balls) or \
								 (b2 in associated_left_balls) or (b3 in associated_left_balls)
			
			if !has_associated:
				for ball_id in [b0, b1, b2, b3]:
					if ball_id >= KeyBallsData.max_base_ball_num and pet_node.lnz.addballs.has(ball_id):
						if pet_node.lnz.addballs[ball_id].base == target_ball_no:
							has_associated = true
							break
			
			if has_associated:
				var mirror_parts = Array(parts)
				for col in [0, 1, 2, 3]:
					var b = int(mirror_parts[col])
					if b in temp_addball_map:
						mirror_parts[col] = str(temp_addball_map[b])
					else:
						mirror_parts[col] = str(find_mirrored_ball(int(mirror_parts[col])))
				
				var all_valid = true
				for col in [0, 1, 2, 3]:
					if int(mirror_parts[col]) == -1:
						all_valid = false
						break
				if !all_valid: continue
				
				if mirror_parts.size() > 6:
					var temp = mirror_parts[5]
					mirror_parts[5] = mirror_parts[6]
					mirror_parts[6] = temp
				
				var comment = " ; copyMirrLtoR_ball%d_ball%d_poly(%s,%s,%s,%s)" % [target_ball_no, mirrored_ball_no, mirror_parts[0], mirror_parts[1], mirror_parts[2], mirror_parts[3]]
				var new_line = _join_array(mirror_parts, delim) + comment
				
				if !existing_poly_sigs.has(new_line):
					new_poly_lines.append(new_line)
					existing_poly_sigs[new_line] = true
		
		if !new_poly_lines.empty():
			var poly_bounds2 = get_section_bounds("[Polygons]")
			var insert_line = poly_bounds2.end
			_insert_text_at_cursor_at_line(insert_line, _join_array(new_poly_lines, "\n") + "\n")

	# [Move]
	if is_mirrored:
		_process_move_section_for_mirror(target_ball_no, mirrored_ball_no)

	print("[LNZ EDIT] Performed Mirror-Copy for Ballz #%dto its mirror Ballz #%d" % [target_ball_no, mirrored_ball_no])
	if console_log:
		console_log.log_message("[LNZ EDIT] Performed Mirror-Copy for Ballz #%d to its mirror Ballz #%d" % [target_ball_no, mirrored_ball_no])
	save_file(true)
	commit_full_snapshot("Mirrored Ballz #%d to #%d" % [target_ball_no, mirrored_ball_no])

func _build_ball_map_for_mirror(left_balls_list: Array, middle_balls_list: Array, right_balls_list: Array) -> Dictionary:
	var new_ball_map = {}
	var ballz_bounds = get_section_bounds("[Ballz Info]")
	var delim = _detect_delimiter(ballz_bounds.start, ballz_bounds.end)

	for i in range(ballz_bounds.start, ballz_bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("["): continue

		var ball_no = _get_line_no_from_line_index(i, "[Ballz Info]")
		if ball_no == -1: continue

		var entry = {"line": line, "new_ball_no": ball_no, "corresponding_ball": null}

		if ball_no in left_balls_list:
			var right_ball_no = get_corresponding_right_ball(ball_no)
			entry.corresponding_ball = right_ball_no

			var parts = split_line(line)
			var mirrored_attrs = _mirror_ball_attributes(parts, false)
			var mirrored_line = _update_fields(parts, mirrored_attrs, delim)

			var right_ball_line_idx = find_line_in_ball_section(right_ball_no)
			set_line(right_ball_line_idx, mirrored_line)

			new_ball_map[right_ball_no] = {"line": mirrored_line, "corresponding_ball": ball_no, "new_ball_no": right_ball_no}

		new_ball_map[ball_no] = entry

	# Process Addballz
	var addball_bounds = get_section_bounds("[Add Ball]")
	if !addball_bounds.empty():
		var delim_addball = _detect_delimiter(addball_bounds.start, addball_bounds.end)
		var current_addball_no = KeyBallsData.max_base_ball_num
		var new_ball_count = KeyBallsData.max_base_ball_num
		var balls_to_add_temp = []

		for i in range(addball_bounds.start, addball_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";") or line.begins_with("["): continue

			var parts = split_line(line)
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
				var mirrored_line_parts = split_line(line)

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

func _get_mirrored_counterpart(ball: int, target: int, mirrored: int, temp_map: Dictionary) -> int:
	if ball == target: return mirrored
	if temp_map.has(ball): return temp_map[ball]
	if ball < KeyBallsData.max_base_ball_num: return find_mirrored_ball(ball)
	return ball

func _process_section_for_mirror(section_name: String, line_processor, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary) -> Array:
	var results = []
	var bounds = get_section_bounds(section_name)
	if bounds.empty():
		return results

	var delim = _detect_delimiter(bounds.start, bounds.end)

	for i in range(bounds.start, bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";") or line.begins_with("["): continue

		var parts = split_line(line)
		if parts.empty(): continue

		var processed_lines = line_processor.call_func(parts, left_balls_list, middle_balls_list, ball_map, delim)
		results.append_array(processed_lines)

	return results

func _process_move_section_for_mirror(target_ball_no: int, mirrored_ball_no: int):
	var move_bounds = get_section_bounds("[Move]")
	if move_bounds.empty(): return

	var delim = _detect_delimiter(move_bounds.start, move_bounds.end)
	var new_mirrored_line = ""
	var target_line_found = false

	for i in range(move_bounds.start, move_bounds.end):
		var line = get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue
		
		var parts = split_line(line)
		if parts.size() >= 4 and parts[0].to_int() == target_ball_no:
			target_line_found = true
			var mirrored_parts = Array(parts)
			mirrored_parts[0] = str(mirrored_ball_no)
			mirrored_parts[1] = str(mirrored_parts[1].to_float() * -1.0)
			if parts.size() > 4:
				mirrored_parts[4] = str(find_mirrored_ball(parts[4].to_int()))
			new_mirrored_line = _join_array(mirrored_parts, delim)
			break

	if target_line_found:
		var lines_to_remove = []
		for i in range(move_bounds.start, move_bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			var parts = split_line(line)
			if parts.size() > 0 and parts[0].to_int() == mirrored_ball_no:
				lines_to_remove.append(i)
		
		for i in range(lines_to_remove.size() - 1, -1, -1):
			var line_num = lines_to_remove[i]
			select(line_num, 0, line_num + 1, 0)
			cut()

		if !new_mirrored_line.empty():
			move_bounds = get_section_bounds("[Move]")
			
			var insert_line = _find_insertion_line(move_bounds.start, move_bounds.end)
			_insert_text_at_cursor_at_line(insert_line, new_mirrored_line + "\n")

func _process_linez_line_for_mirror(parts: Array, target_ball_no: int, mirrored_ball_no: int, associated_left_balls: Array, temp_addball_map: Dictionary) -> Array:
	if parts.size() < 2:
		return []
	var start_ball = parts[0].to_int()
	var end_ball = parts[1].to_int()

	if associated_left_balls.has(start_ball) or associated_left_balls.has(end_ball):
		var mirrored_parts = parts
		mirrored_parts[0] = str(_get_mirrored_counterpart(start_ball, target_ball_no, mirrored_ball_no, temp_addball_map))
		mirrored_parts[1] = str(_get_mirrored_counterpart(end_ball, target_ball_no, mirrored_ball_no, temp_addball_map))
		
		# Mirror outline type for lines
		if mirrored_parts.size() > 8:
			if mirrored_parts[8] == "0": mirrored_parts[8] = "-2"
			elif mirrored_parts[8] == "-2": mirrored_parts[8] = "0"

		return mirrored_parts
	return []

func _process_paintball_line_for_mirror(parts: Array, target_ball_no: int, mirrored_ball_no: int, associated_left_balls: Array, temp_addball_map: Dictionary) -> Array:
	if parts.size() < 6: 
		return []
	var base_ball = parts[0].to_int()
	if base_ball == target_ball_no:
		var new_parts = parts
		new_parts[0] = str(mirrored_ball_no)
		new_parts[2] = str(new_parts[2].to_float() * -1.0)
		return new_parts
	return []

func _resolve_mirror_id(ball: int, reverse: bool, base_mirror_map: Dictionary, middle_balls_list: Array, source_to_mirror_map: Dictionary = {}) -> int:
	if source_to_mirror_map.has(ball): return source_to_mirror_map[ball]
	if base_mirror_map.has(ball): return base_mirror_map[ball]
	if ball in middle_balls_list: return ball
	if reverse: return get_corresponding_left_ball(ball)
	return get_corresponding_right_ball(ball)

func _is_ball_on_source_side(ball: int, source_list: Array, source_addballs_found: Array, middle_balls_list: Array, x_pos: float = 0.0, reverse: bool = false) -> bool:
	if ball in source_list: return true
	if ball in source_addballs_found: return true
	if ball in middle_balls_list:
		if reverse:
			return x_pos < -0.001 or x_pos > 0.001
		return abs(x_pos) > 0.001
	return false

func _is_source_ball(ball: int, source_list: Array, source_addballs_found: Array, middle_balls_list: Array, x_pos: float = 0.0, reverse: bool = false) -> bool:
	if ball in source_list: return true
	if ball in source_addballs_found: return true
	if ball in middle_balls_list:
		if reverse:
			return abs(x_pos) > 0.001
		return abs(x_pos) > 0.001
	return false

func _get_mirror_direction(reverse: bool) -> String:
	if reverse: return "left"
	return "right"

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

func _mirror_move_processor(parts: Array, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var move_ball = parts[0].to_int()

	if move_ball in left_balls_list:
		processed_lines.append(_join_array(parts, delim)) # Keep original

		var mirrored_parts = parts
		mirrored_parts[0] = str(get_corresponding_right_ball(move_ball))
		mirrored_parts[1] = str(parts[1].to_float() * -1.0)
		if parts.size() > 4:
			mirrored_parts[4] = str(find_mirrored_ball(parts[4].to_int()))
		processed_lines.append(_join_array(mirrored_parts, delim))

	elif move_ball in middle_balls_list:
		processed_lines.append(_join_array(parts, delim))

	return processed_lines

func _mirror_linez_processor(parts: Array, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var start_ball = parts[0].to_int()
	var end_ball = parts[1].to_int()

	if not ball_map.has(start_ball) or not ball_map.has(end_ball):
		return [] # Skip lines with balls that were removed

	var is_left = start_ball in left_balls_list or end_ball in left_balls_list
	var is_middle = start_ball in middle_balls_list and end_ball in middle_balls_list

	# Update original line with new ball numbers
	var updated_parts = parts
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

func _mirror_projection_processor(parts: Array, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var base_ball = parts[0].to_int()
	var move_ball = parts[1].to_int()

	# Remap original line
	var updated_parts = parts
	updated_parts[0] = str(ball_map.get(base_ball, {"new_ball_no": base_ball}).new_ball_no)
	updated_parts[1] = str(ball_map.get(move_ball, {"new_ball_no": move_ball}).new_ball_no)
	processed_lines.append(_join_array(updated_parts, delim))

	if move_ball in left_balls_list:
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(find_mirrored_ball(base_ball))
		mirrored_parts[1] = str(find_mirrored_ball(move_ball))
		processed_lines.append(_join_array(mirrored_parts, delim))

	return processed_lines

func _mirror_paintball_processor(parts: Array, left_balls_list: Array, middle_balls_list: Array, ball_map: Dictionary, delim: String) -> Array:
	var processed_lines = []
	var base_ball = parts[0].to_int()
	var x_pos = parts[2].to_float()

	if not ball_map.has(base_ball):
		return []

	# Update original line
	var updated_parts = parts
	updated_parts[0] = str(ball_map[base_ball].new_ball_no)
	processed_lines.append(_join_array(updated_parts, delim))

	if base_ball in left_balls_list or (base_ball in middle_balls_list and x_pos > 0):
		# Create mirrored line
		var mirrored_parts = Array(parts)
		mirrored_parts[0] = str(find_mirrored_ball(base_ball))
		mirrored_parts[2] = str(x_pos * -1.0)
		processed_lines.append(_join_array(mirrored_parts, delim))

	return processed_lines

### BATCH OPERATIONS ###

### HELPER FUNCTIONS ###

func _for_each_matching_line_in_section(section_name: String, ball_no: int, callback) -> void:
	var bounds = get_section_bounds(section_name)
	if bounds.empty():
		return

	var delim = _detect_delimiter(bounds.start, bounds.end)
	var matched = false

	if section_name == "[Ballz Info]":
		var line_idx = find_line_in_ball_section(ball_no)
		if line_idx != -1:
			var line = get_line(line_idx).strip_edges()
			var parts = split_line(line)
			if not parts.empty():
				callback.call(line_idx, parts, delim)
				matched = true

	elif section_name == "[Add Ball]":
		var idx = ball_no - KeyBallsData.max_base_ball_num
		var count = 0
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			if count == idx:
				var parts = split_line(raw)
				if not parts.empty():
					callback.call(i, parts, delim)
					matched = true
				break
			count += 1

	elif section_name == "[Move]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 0 and parts[0].to_int() == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Paint Ballz]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 0 and parts[0].to_int() == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Linez]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() >= 2 and (parts[0].to_int() == ball_no or parts[1].to_int() == ball_no):
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Polygons]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() >= 4 and (ball_no in [parts[0].to_int(), parts[1].to_int(), parts[2].to_int(), parts[3].to_int()]):
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Omissions]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with("["): continue
			if raw.to_int() == ball_no:
				var parts = Array([str(ball_no)])
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Ball Size Override]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 0 and parts[0].to_int() == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Fuzz Override]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 0 and parts[0].to_int() == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Color Info Override]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 0 and parts[0].to_int() == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Outline Color Override]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 0 and parts[0].to_int() == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Add Ball Override]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			var rel = parts[0].to_int()
			if rel + KeyBallsData.max_base_ball_num == ball_no:
				callback.call(i, parts, delim)
				matched = true

	elif section_name == "[Project Ball]":
		for i in range(bounds.start, bounds.end):
			var raw = get_line(i).strip_edges()
			if raw == "" or raw.begins_with(";"): continue
			var parts = split_line(raw)
			if parts.size() > 1 and (parts[0].to_int() == ball_no or parts[1].to_int() == ball_no):
				callback.call(i, parts, delim)
				matched = true

	if not matched:
		print("[WARNING] LnzTextEdit: _for_each_matching_line_in_section: no matching line found for ball %d in %s" % [ball_no, section_name])

func _for_each_matching_line_in_section_with_field(section_name: String, ball_no: int, field_idx: int, exclude_list: Array, value: String) -> void:
	var bounds = get_section_bounds(section_name)
	if bounds.empty(): return
	var delim = _detect_delimiter(bounds.start, bounds.end)
	
	if section_name == "[Ballz Info]":
		var count = 0
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";") or line.begins_with("["): continue
			var ball_no_check = count
			if _idx_in_list(ball_no_check, exclude_list):
				count += 1
				continue
			var parts = split_line(line)
			if parts.size() > field_idx:
				parts[field_idx] = value
				set_line(i, _join_array(parts, delim))
			count += 1

	elif section_name == "[Move]":
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			var parts = split_line(line)
			if parts.size() > 0 and _idx_in_list(parts[0].to_int(), exclude_list): continue
			if parts.size() > field_idx:
				parts[field_idx] = value
				set_line(i, _join_array(parts, delim))

	elif section_name == "[Linez]":
		for i in range(bounds.start, bounds.end):
			var line = get_line(i).strip_edges()
			if line.empty() or line.begins_with(";"): continue
			var parts = split_line(line)
			if parts.size() >= 2 and (_idx_in_list(parts[0].to_int(), exclude_list) or _idx_in_list(parts[1].to_int(), exclude_list)): continue
			if parts.size() > field_idx:
				parts[field_idx] = value
				set_line(i, _join_array(parts, delim))

func write_polygon_section(ball_ids: Array) -> void:
	if ball_ids.size() != 4:
		return

	save_backup()
	commit_full_snapshot("Add Polygon")

	var delim = _detect_delimiter(0, get_line_count())

	var props: Dictionary = {}
	if is_instance_valid(pet_view) and is_instance_valid(pet_view.line_mode_settings_instance):
		props = pet_view.line_mode_settings_instance.get_properties()

	var apply_color: bool = props.get("apply_color", true)
	var apply_l_edge: bool = props.get("apply_left_outline", true)
	var apply_r_edge: bool = props.get("apply_right_outline", true)
	var apply_fuzz: bool = props.get("apply_fuzz", true)

	var color_val: int = -1
	if apply_color and props.has("color"):
		var color_str = str(props["color"])
		if color_str.is_valid_integer():
			color_val = color_str.to_int()

	var l_edge_val: int = -1
	if apply_l_edge and props.has("left_outline_color"):
		var l_str = str(props["left_outline_color"])
		if l_str.is_valid_integer():
			l_edge_val = l_str.to_int()

	var r_edge_val: int = -1
	if apply_r_edge and props.has("right_outline_color"):
		var r_str = str(props["right_outline_color"])
		if r_str.is_valid_integer():
			r_edge_val = r_str.to_int()

	var fuzz_val: int = 0
	if apply_fuzz and props.has("fuzz"):
		fuzz_val = int(props["fuzz"])

	var poly_bounds = get_section_bounds("[Polygons]")
	if poly_bounds.empty():
		var first_section = search("[", 0, 0, 0)
		if not first_section.empty():
			var all_lines = get_text().split("\n")
			all_lines.insert(first_section[SEARCH_RESULT_LINE], "[Polygons]")
			text = all_lines.join("\n")
			_set_text_preserve(text)
		else:
			var new_text = "[Polygons]\n"
			if not text.strip_edges().empty():
				new_text += text
			text = new_text
			_set_text_preserve(text)

	poly_bounds = get_section_bounds("[Polygons]")
	var insert_line = poly_bounds.end - 1
	if insert_line < poly_bounds.start:
		insert_line = poly_bounds.start

	var poly_line = _join_array([
		str(ball_ids[0]),
		str(ball_ids[1]),
		str(ball_ids[2]),
		str(ball_ids[3]),
		str(color_val),
		str(l_edge_val),
		str(r_edge_val),
		str(fuzz_val),
		"-1"
	], delim)

	_insert_text_at_cursor_at_line(insert_line, poly_line + "\n")

### HELPER FUNCTIONS ###
# _idx_in_list

func _idx_in_list(idx: int, list: Array) -> bool:
	for v in list:
		if v == idx:
			return true
	return false
