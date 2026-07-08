extends WindowDialog
## ReferenceImageSettings.gd
## Manages settings for reference images, including path selection, visibility, and scaling

const CONFIG_PATH: String = "user://settings.cfg"

onready var option_button: OptionButton = $VBoxContainer/HBoxContainer/OptionButton
onready var refresh_button: Button = $VBoxContainer/HBoxContainer/RefreshButton
onready var open_folder_button: Button = $VBoxContainer/HBoxContainer/OpenFolderButton
onready var clear_folder_button: Button = $VBoxContainer/HBoxContainer/ClearFolderButton

onready var show_bg_checkbox: CheckBox = $VBoxContainer/SettingsContainer/ShowBgCheckBox
onready var show_popup_checkbox: CheckBox = $VBoxContainer/SettingsContainer/ShowPopupCheckBox
onready var center_checkbox: CheckBox = $VBoxContainer/SettingsContainer/CenterCheckBox
onready var scale_checkbox: CheckBox = $VBoxContainer/SettingsContainer/ScaleCheckBox
onready var scale_value_spinbox: SpinBox = $VBoxContainer/SettingsContainer/HBoxContainer/ScaleValueSpinBox
onready var x_spinbox: SpinBox = $VBoxContainer/SettingsContainer/HBoxContainer/XSpinBox
onready var y_spinbox: SpinBox = $VBoxContainer/SettingsContainer/HBoxContainer/YSpinBox

var import_dialog: FileDialog
var is_active: bool = false

var image_paths: Array = []
var selected_image_path: String = ""

func _ready() -> void:
	window_title = "Reference Image"
	
	var dir: Directory = Directory.new()
	if not dir.dir_exists("user://resources/references/"):
		dir.make_dir_recursive("user://resources/references/")

	refresh_button.connect("pressed", self, "_on_refresh_button_pressed")
	open_folder_button.connect("pressed", self, "_on_open_folder_button_pressed")
	clear_folder_button.connect("pressed", self, "_on_clear_folder_button_pressed")
	option_button.connect("item_selected", self, "_on_option_button_item_selected")

	show_bg_checkbox.connect("toggled", self, "_on_show_bg_toggled")
	show_popup_checkbox.connect("toggled", self, "_on_show_popup_toggled")
	center_checkbox.connect("toggled", self, "_on_center_toggled")
	scale_checkbox.connect("toggled", self, "_on_scale_toggled")
	scale_value_spinbox.connect("value_changed", self, "_on_scale_value_changed")
	x_spinbox.connect("value_changed", self, "_on_x_changed")
	y_spinbox.connect("value_changed", self, "_on_y_changed")

	_refresh_image_list()
	_load_settings()

	open_folder_button.text = "Add Image"
	clear_folder_button.show()
	
	import_dialog = FileDialog.new()
	import_dialog.mode = FileDialog.MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.filters = PoolStringArray(["*.png, *.jpg, *.jpeg; Image Files"])
	import_dialog.window_title = "Select a Reference Image"
	import_dialog.rect_min_size = Vector2(500, 400)
	
	import_dialog.popup_exclusive = true 
	
	import_dialog.connect("file_selected", self, "_on_import_file_selected")
	
	import_dialog.connect("popup_hide", self, "_on_import_dialog_closed") 
	
	add_child(import_dialog)


func _refresh_image_list() -> void:
	option_button.clear()
	image_paths.clear()

	var dir: Directory = Directory.new()
	if dir.open("user://resources/references/") == OK:
		dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg") or file_name.ends_with(".gif")):
				option_button.add_item(file_name)
				image_paths.append("user://resources/references/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if option_button.get_item_count() > 0:
		option_button.set_disabled(false) 
		
		if selected_image_path in image_paths:
			option_button.select(image_paths.find(selected_image_path))
		else:
			option_button.select(0)
			selected_image_path = image_paths[0]
			_save_settings()
		_emit_image_update()
	else:
		option_button.add_item("No images found")
		option_button.set_disabled(true)
		selected_image_path = ""
		_emit_image_update()

func _on_refresh_button_pressed() -> void:
	_refresh_image_list()

func _on_open_folder_button_pressed() -> void:
	if OS.has_feature("HTML5"):
		LnzLiveUtils.web_upload_image("user://resources/references/", self, "_on_web_ref_upload_confirmed")
		return
	self.popup_exclusive = true
	import_dialog.popup_centered()

func _on_web_ref_upload_confirmed() -> void:
	var file_blob = LnzLiveUtils.get_web_ref_blob()
	if file_blob == null:
		print("[ERROR] ReferenceImageSettings: web upload cancelled or failed.")
		return
	var file_name = LnzLiveUtils.get_web_ref_name()
	var err = LnzLiveUtils.save_web_ref_to_disk(file_name, file_blob)
	if err == OK:
		_refresh_image_list()
		var idx: int = image_paths.find("user://resources/references/" + file_name)
		if idx != -1:
			option_button.select(idx)
			_on_option_button_item_selected(idx)
	else:
		print("[ERROR] ReferenceImageSettings: failed to save uploaded image: ", err)

func _on_import_dialog_closed() -> void:
	self.popup_exclusive = false

func _on_import_file_selected(path: String) -> void:
	var dir: Directory = Directory.new()
	var file_name: String = path.get_file()
	var dest_path: String = "user://resources/references/" + file_name
	
	var err: int = dir.copy(path, dest_path)
	if err == OK:
		_refresh_image_list()
		
		var idx: int = image_paths.find(dest_path)
		if idx != -1:
			option_button.select(idx)
			_on_option_button_item_selected(idx)
	else:
		print("Error copying reference image: ", err)

func _on_clear_folder_button_pressed() -> void:
	var dir: Directory = Directory.new()
	if dir.open("user://resources/references/") == OK:
		dir.list_dir_begin(true, true)
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	_refresh_image_list()

func _on_option_button_item_selected(index: int) -> void:
	if index < image_paths.size():
		selected_image_path = image_paths[index]
		_save_settings()
		_emit_image_update()

func _on_show_bg_toggled(pressed: bool) -> void:
	_save_settings()
	_emit_image_update()

func _on_show_popup_toggled(pressed: bool) -> void:
	_save_settings()
	_emit_image_update()
	var popup: Node = get_tree().root.find_node("ReferenceImagePopup", true, false)

func _on_center_toggled(pressed: bool) -> void:
	x_spinbox.set_editable(!pressed)
	y_spinbox.set_editable(!pressed)
	_save_settings()
	_emit_image_update()

func _on_scale_toggled(pressed: bool) -> void:
	_save_settings()
	_emit_image_update()

func _on_scale_value_changed(value: float) -> void:
	_emit_image_update()

func _on_x_changed(value: float) -> void:
	_emit_image_update()

func _on_y_changed(value: float) -> void:
	_emit_image_update()

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST or what == NOTIFICATION_POPUP_HIDE:
		_save_settings()

func _emit_image_update() -> void:
	var config_data: Dictionary = {
		"path": selected_image_path,
		"show_bg": show_bg_checkbox.pressed and is_active,
		"show_popup": show_popup_checkbox.pressed and is_active,
		"center": center_checkbox.pressed,
		"scale": scale_checkbox.pressed,
		"scale_value": scale_value_spinbox.value, # NEW PROPERTY
		"x": x_spinbox.value,
		"y": y_spinbox.value
	}

	var container: Node = get_tree().root.find_node("PetViewContainer", true, false)
	if container and container.has_method("_on_reference_image_updated"):
		container.update_config_reference_image(config_data)

	var popup: Node = get_tree().root.find_node("ReferenceImagePopup", true, false)
	if popup and popup.has_method("_on_reference_image_updated"):
		popup.update_config_reference_image(config_data)

func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("ReferenceImage", "is_active", is_active)
	config.set_value("ReferenceImage", "path", selected_image_path)
	config.set_value("ReferenceImage", "show_bg", show_bg_checkbox.pressed)
	config.set_value("ReferenceImage", "show_popup", show_popup_checkbox.pressed)
	config.set_value("ReferenceImage", "center", center_checkbox.pressed)
	config.set_value("ReferenceImage", "scale", scale_checkbox.pressed)
	config.set_value("ReferenceImage", "x", x_spinbox.value)
	config.set_value("ReferenceImage", "y", y_spinbox.value)
	config.set_value("ReferenceImage", "scale_value", scale_value_spinbox.value)
	config.save(CONFIG_PATH)

func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		is_active = config.get_value("ReferenceImage", "is_active", false)
		selected_image_path = config.get_value("ReferenceImage", "path", "")

		var file: File = File.new()
		if not file.file_exists(selected_image_path):
			selected_image_path = ""

		show_bg_checkbox.pressed = config.get_value("ReferenceImage", "show_bg", false)
		show_popup_checkbox.pressed = config.get_value("ReferenceImage", "show_popup", false)
		center_checkbox.pressed = config.get_value("ReferenceImage", "center", true)
		scale_checkbox.pressed = config.get_value("ReferenceImage", "scale", false)
		x_spinbox.value = config.get_value("ReferenceImage", "x", 0)
		y_spinbox.value = config.get_value("ReferenceImage", "y", 0)
		scale_value_spinbox.value = config.get_value("ReferenceImage", "scale_value", 1.0)

		x_spinbox.set_editable(!center_checkbox.pressed)
		y_spinbox.set_editable(!center_checkbox.pressed)

		if option_button.get_item_count() > 0 and not option_button.is_disabled():
			if selected_image_path in image_paths:
				option_button.select(image_paths.find(selected_image_path))

		_emit_image_update()

func toggle_reference_image() -> void:
	if selected_image_path == "":
		popup_centered()
		return
		
	if not is_active and not show_bg_checkbox.pressed and not show_popup_checkbox.pressed:
		show_bg_checkbox.pressed = true
		
	is_active = not is_active
	_save_settings()
	_emit_image_update()
	
	var popup: Node = get_tree().root.find_node("ReferenceImagePopup", true, false)
	if popup:
		if is_active and show_popup_checkbox.pressed:
			popup.show()
		else:
			popup.programmatic_hide = true
			popup.hide()
