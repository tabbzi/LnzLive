extends WindowDialog
## HotkeySettingsDialog.gd
## Dialog for viewing and remapping hotkeys.
## Shows actions grouped by context, with buttons to remap each binding.
## Supports creating/saving/loading custom hotkey profiles.

signal hotkeys_changed

onready var scroll_container: ScrollContainer = $VBoxContainer/ScrollContainer
onready var profile_hbox: HBoxContainer = $VBoxContainer/ProfileHBox
onready var profile_label: Label = $VBoxContainer/ProfileHBox/ProfileLabel
onready var profile_option: OptionButton = $VBoxContainer/ProfileHBox/ProfileOption
onready var save_profile_btn: Button = $VBoxContainer/ProfileHBox/SaveProfileBtn
onready var save_profile_line: LineEdit = $VBoxContainer/ProfileHBox/SaveProfileLine
onready var load_profile_btn: Button = $VBoxContainer/ProfileHBox/LoadProfileBtn
onready var delete_profile_btn: Button = $VBoxContainer/ProfileHBox/DeleteProfileBtn
onready var reset_btn: Button = $VBoxContainer/ButtonHBox/ResetBtn
onready var export_btn: Button = $VBoxContainer/ButtonHBox/ExportBtn
onready var import_btn: Button = $VBoxContainer/ButtonHBox/ImportBtn
onready var apply_btn: Button = $VBoxContainer/ButtonHBox/ApplyBtn
onready var cancel_btn: Button = $VBoxContainer/ButtonHBox/CancelBtn
onready var action_list_container: VBoxContainer = $VBoxContainer/ScrollContainer/ActionListVBox

onready var listening_popup: WindowDialog = $ListeningPopup
onready var file_dialog: FileDialog = $FileDialog

var _listening_for_action: String = ""
var _listening_active: bool = false
var _action_row_cache: Dictionary = {}  # action_name -> PanelContainer row

var _row_hover_style: StyleBoxFlat
var _row_normal_style: StyleBoxFlat


func _ready() -> void:
	_setup_profile_options()
	_setup_connections()


func _setup_styles() -> void:
	_row_hover_style = StyleBoxFlat.new()
	_row_hover_style.set_bg_color(Color(0.22, 0.22, 0.22, 0.9))
	_row_hover_style.set_border_color(Color(0.4, 0.5, 0.6))
	_row_hover_style.set_border_width_all(2)
	_row_hover_style.content_margin_left = 10
	_row_hover_style.content_margin_right = 10
	_row_hover_style.content_margin_top = 10
	_row_hover_style.content_margin_bottom = 10
	_row_hover_style.set_corner_radius_all(3)
	
	_row_normal_style = StyleBoxFlat.new()
	_row_normal_style.set_bg_color(Color(0.15, 0.15, 0.15, 0.8))
	_row_normal_style.set_border_color(Color(0.3, 0.3, 0.3))
	_row_normal_style.set_border_width_all(2)
	_row_normal_style.content_margin_left = 10
	_row_normal_style.content_margin_right = 10
	_row_normal_style.content_margin_top = 10
	_row_normal_style.content_margin_bottom = 10
	_row_normal_style.set_corner_radius_all(3)


func _setup_profile_options() -> void:
	_update_profile_options()


func _setup_connections() -> void:
	if save_profile_btn:
		save_profile_btn.connect("pressed", self, "_on_save_profile_pressed")
	if load_profile_btn:
		load_profile_btn.connect("pressed", self, "_on_load_profile_pressed")
	if delete_profile_btn:
		delete_profile_btn.connect("pressed", self, "_on_delete_profile_pressed")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_pressed")
	if export_btn:
		export_btn.connect("pressed", self, "_on_export_pressed")
	if import_btn:
		import_btn.connect("pressed", self, "_on_import_pressed")
	if apply_btn:
		apply_btn.connect("pressed", self, "_on_apply_pressed")
	if cancel_btn:
		cancel_btn.connect("pressed", self, "_on_cancel_pressed")
	if listening_popup:
		listening_popup.connect("popup_hide", self, "_on_listening_popup_hide")
	if file_dialog:
		file_dialog.connect("file_selected", self, "_on_file_selected")

	if HotkeyManager:
		HotkeyManager.connect("hotkeys_reloaded", self, "_on_hotkeys_reloaded")


func _update_profile_options() -> void:
	if not profile_option:
		return
	profile_option.clear()
	if not HotkeyManager:
		return
	var names: Array = HotkeyManager.get_profile_names()
	for name in names:
		profile_option.add_item(name)


func show_dialog() -> void:
	_update_profile_options()
	_populate_action_list()
	_sync_profile_selection()
	popup_centered(Vector2(700, 550))


func _sync_profile_selection() -> void:
	if not profile_option or not HotkeyManager:
		return
	var current_bindings = HotkeyManager.get_all_user_bindings()
	for i in range(profile_option.get_item_count()):
		var name = profile_option.get_item_text(i)
		if name == "Default":
			if current_bindings.size() == 0:
				profile_option.select(i)
		elif HotkeyManager.has_profile(name):
			var profile = HotkeyManager.profiles[name]
			if _bindings_match_dict(current_bindings, profile):
				profile_option.select(i)
				return


func _bindings_match_dict(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a:
		if not b.has(key) or a[key] != b[key]:
			return false
	return true


func _populate_action_list() -> void:
	for child in action_list_container.get_children():
		action_list_container.remove_child(child)
		child.free()
	_action_row_cache.clear()

	if not HotkeyManager:
		return

	var groups: Dictionary = HotkeyManager.action_groups
	var all_actions: Array = HotkeyManager.get_all_actions()

	var grouped: Dictionary = {}
	for group_name in groups:
		grouped[group_name] = []
		for action in groups[group_name]:
			if all_actions.has(action):
				grouped[group_name].append(action)

	for action in all_actions:
		var found: bool = false
		for group_name in grouped:
			if grouped[group_name].has(action):
				found = true
				break
		if not found:
			if not grouped.has("Other"):
				grouped["Other"] = []
			grouped["Other"].append(action)

	for group_name in grouped:
		var header: Label = Label.new()
		header.text = group_name
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_list_container.add_child(header)

		var separator: HBoxContainer = HBoxContainer.new()
		var sep_line: Control = Control.new()
		sep_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sep_line.set_custom_minimum_size(Vector2(0, 2))
		separator.add_child(sep_line)
		action_list_container.add_child(separator)

		for action in grouped[group_name]:
			_add_action_row(action)


func _add_action_row(action: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_stylebox_override("panel", _row_normal_style)
	
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.set_custom_minimum_size(Vector2(0, 2))
	row.add_constant_override("separation", 8)
	
	panel.add_child(row)

	var name_label: Label = Label.new()
	name_label.text = HotkeyManager.get_action_display_name(action)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_FILL
	name_label.set_custom_minimum_size(Vector2(180, 0))
	row.add_child(name_label)

	var bind_label: Label = Label.new()
	bind_label.text = _get_current_binding_string(action)
	bind_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_label.set_custom_minimum_size(Vector2(120, 0))
	row.add_child(bind_label)

	var remap_btn: Button = Button.new()
	remap_btn.text = "Remap"
	remap_btn.set_custom_minimum_size(Vector2(70, 0))
	if not HotkeyManager.is_non_remappable(action):
		remap_btn.connect("pressed", self, "_on_remap_pressed", [action])
		row.add_child(remap_btn)

	var reset_btn_local: Button = Button.new()
	reset_btn_local.text = "Reset"
	reset_btn_local.set_custom_minimum_size(Vector2(60, 0))
	reset_btn_local.connect("pressed", self, "_on_reset_action_pressed", [action])
	row.add_child(reset_btn_local)

	panel.connect("mouse_entered", self, "_on_row_mouse_entered", [panel])
	panel.connect("mouse_exited", self, "_on_row_mouse_exited", [panel])

	action_list_container.add_child(panel)
	_action_row_cache[action] = panel


func _get_current_binding_string(action: String) -> String:
	if not HotkeyManager:
		return "None"
	var binding: Dictionary = HotkeyManager.get_binding(action)
	return HotkeyManager.get_key_string(binding)


func _on_remap_pressed(action: String) -> void:
	_listening_for_action = action
	_listening_active = true
	listening_popup.window_title = "Remap: " + HotkeyManager.get_action_display_name(action)
	listening_popup.popup_centered(Vector2(300, 100))


func _on_reset_action_pressed(action: String) -> void:
	if not HotkeyManager:
		return
	if HotkeyManager.user_bindings.has(action):
		HotkeyManager.user_bindings.erase(action)
		HotkeyManager._apply_bindings()
		_update_row_binding(action)
		emit_signal("hotkeys_changed")


func _on_save_profile_pressed() -> void:
	if not save_profile_line:
		return
	var name: String = save_profile_line.text.strip_edges()
	if name == "":
		print("[HotkeySettings] Please enter a profile name.")
		return
	if HotkeyManager:
		HotkeyManager.save_profile(name)
		_update_profile_options()
		save_profile_line.text = ""
		print("[HotkeySettings] Profile saved.")


func _on_load_profile_pressed() -> void:
	if not profile_option or profile_option.selected < 0:
		return
	var selected_id: int = profile_option.get_item_id(profile_option.selected)
	var selected_text: String = profile_option.get_item_text(profile_option.selected)
	if selected_text == "Default":
		return  # Can't "load" default as a profile
	if HotkeyManager:
		HotkeyManager.load_profile(selected_text)
		_populate_action_list()
		_sync_profile_selection()
		emit_signal("hotkeys_changed")


func _on_delete_profile_pressed() -> void:
	if not profile_option or profile_option.selected < 0:
		return
	var selected_text: String = profile_option.get_item_text(profile_option.selected)
	if selected_text == "Default":
		print("[HotkeySettings] Cannot delete Default profile.")
		return
	if HotkeyManager:
		if HotkeyManager.erase_profile(selected_text):
			_update_profile_options()
			_sync_profile_selection()
			print("[HotkeySettings] Profile '", selected_text, "' deleted.")


func _on_reset_pressed() -> void:
	if HotkeyManager:
		HotkeyManager.reset_to_defaults()
		_populate_action_list()
		emit_signal("hotkeys_changed")


func _on_export_pressed() -> void:
	if not HotkeyManager:
		return
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.clear_filters()
	file_dialog.add_filter("*.json ; JSON Files")
	file_dialog.current_path = "user://hotkeys_export.json"
	file_dialog.popup_centered(Vector2(600, 400))

func _on_import_pressed() -> void:
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.clear_filters()
	file_dialog.add_filter("*.json ; JSON Files")
	file_dialog.current_path = "user://hotkeys_export.json"
	file_dialog.popup_centered(Vector2(600, 400))

func _on_file_selected(path: String) -> void:
	if file_dialog.mode == FileDialog.MODE_SAVE_FILE:
		if not HotkeyManager:
			return
		var file: File = File.new()
		var err: int = file.open(path, File.WRITE)
		if err == OK:
			var bindings: Dictionary = HotkeyManager.get_all_user_bindings()
			file.store_string(JSON.print(bindings))
			file.close()
			print("[HotkeySettings] Exported to ", path)
		else:
			printerr("[HotkeySettings] Export failed: ", err)
	elif file_dialog.mode == FileDialog.MODE_OPEN_FILE:
		var file: File = File.new()
		var err: int = file.open(path, File.READ)
		if err == OK:
			var json_str: String = file.get_as_text()
			file.close()
			var json: JSONParseResult = JSON.parse(json_str)
			if json.result is Dictionary:
				if HotkeyManager:
					HotkeyManager.set_all_user_bindings(json.result)
					_populate_action_list()
					emit_signal("hotkeys_changed")
					print("[HotkeySettings] Import successful from ", path)
			else:
				printerr("[HotkeySettings] Invalid JSON in import file.")
		else:
			printerr("[HotkeySettings] Import file not found: ", path)


func _on_apply_pressed() -> void:
	if HotkeyManager:
		HotkeyManager.save_hotkeys()
		_populate_action_list()
		emit_signal("hotkeys_changed")
	print("[HotkeySettings] Changes saved.")


func _on_cancel_pressed() -> void:
	hide()


func _on_hotkeys_reloaded() -> void:
	_populate_action_list()
	emit_signal("hotkeys_changed")


func _on_listening_popup_hide() -> void:
	_listening_active = false


func _input(event: InputEvent) -> void:
	if not _listening_active:
		return

	if _listening_active and event is InputEventKey and event.pressed:
		if event.scancode == KEY_ESCAPE:
			_listening_active = false
			listening_popup.window_title = "Press any key..."
			listening_popup.hide()
			return

		if event.scancode in [KEY_CONTROL, KEY_SHIFT, KEY_ALT, KEY_META]:
			listening_popup.window_title = "Holding modifier..."
			return

		get_viewport().set_input_as_handled()

		var binding: Dictionary = {
			"scancode": event.scancode,
			"ctrl": event.control,
			"shift": event.shift,
			"alt": event.alt,
			"meta": event.meta,
		}

		if HotkeyManager:
			var display: String = HotkeyManager.get_key_string(binding)
			if display == "Key " + str(event.scancode) or display == "":
				listening_popup.window_title = "Unsupported key: " + str(event.scancode)
				get_viewport().set_input_as_handled()
				return

		if HotkeyManager:
			var conflict: String = HotkeyManager.check_conflict(binding, _listening_for_action)
			if conflict != "":
				listening_popup.window_title = "Conflict! '" + HotkeyManager.get_key_string(binding) + "' is used by " + HotkeyManager.get_action_display_name(conflict)
				get_viewport().set_input_as_handled()
				return

		if not HotkeyManager:
			return
		HotkeyManager.user_bindings[_listening_for_action] = binding
		HotkeyManager._apply_bindings()
		_update_row_binding(_listening_for_action)
		_listening_active = false
		listening_popup.hide()
		emit_signal("hotkeys_changed")
		print("[HotkeySettings] Remapped '", _listening_for_action, "' to '", HotkeyManager.get_key_string(binding), "'")
		get_tree().set_input_as_handled()
		return

	if _listening_active and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		var binding: Dictionary = {
			"scancode": event.button_index,
			"ctrl": event.control,
			"shift": event.shift,
			"alt": event.alt,
			"meta": event.meta,
		}

		if HotkeyManager:
			var conflict: String = HotkeyManager.check_conflict(binding, _listening_for_action)
			if conflict != "":
				listening_popup.window_title = "Conflict! '" + HotkeyManager.get_key_string(binding) + "' is used by " + HotkeyManager.get_action_display_name(conflict)
				get_viewport().set_input_as_handled()
				return

		if not HotkeyManager:
			return
		HotkeyManager.user_bindings[_listening_for_action] = binding
		HotkeyManager._apply_bindings()
		_update_row_binding(_listening_for_action)
		_listening_active = false
		listening_popup.hide()
		emit_signal("hotkeys_changed")
		print("[HotkeySettings] Remapped '", _listening_for_action, "' to '", HotkeyManager.get_key_string(binding), "'")
		return


func _update_row_binding(action: String) -> void:
	if _action_row_cache.has(action):
		var panel: PanelContainer = _action_row_cache[action]
		var row: HBoxContainer = panel.get_child(0)
		var children: Array = row.get_children()
		if children.size() >= 2:
			var bind_label: Label = children[1]
			if HotkeyManager:
				var binding: Dictionary = HotkeyManager.get_binding(action)
				bind_label.text = HotkeyManager.get_key_string(binding)


func _on_row_mouse_entered(panel: PanelContainer) -> void:
	if _row_hover_style:
		panel.add_stylebox_override("panel", _row_hover_style)


func _on_row_mouse_exited(panel: PanelContainer) -> void:
	if _row_normal_style:
		panel.add_stylebox_override("panel", _row_normal_style)
