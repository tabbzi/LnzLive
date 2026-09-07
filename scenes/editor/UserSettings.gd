extends Control
## UserSettings.gd
## Manages user-specific global settings and UI interactions
## 1. Handles changes to the 3D viewport's background color by connecting the ColorPickerButton to a background ColorRect
## 2. Calls populate_colors() on the viewer popup to ensure the current pet's palette is displayed before showing the popup
## 3. Saves user settings in config file

const SETTINGS_PATH: String = "user://settings.cfg"

onready var color_picker: ColorPickerButton = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/BackgroundColorPickerButton")
onready var color_rect: ColorRect = get_node("BackgroundColorRect")
onready var view_palette_button: Button = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton")
onready var shrink_spinner: SpinBox = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ShrinkSpinBox")
onready var file_tree: Tree = get_tree().get_root().get_node("Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
onready var pet_view_container: Control = get_node("HSplitContainer/HSplitContainer/PetViewContainer")

onready var settings_dialog: WindowDialog = get_node("UserSettingsDialog")
onready var user_settings_btn: Button = get_node("HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/UserSettingsButton")
onready var lnz_text_edit: Control = get_node("HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")

var _cached_window_size: Vector2 = Vector2(1024, 600)
var _cached_window_pos: Vector2 = Vector2()
var preferred_delimiter: String = "comma_space"

var using_alt_font: bool = false
var font_size_offset: int = 0

const MIN_FONT_OFFSET: int = -8
const MAX_FONT_OFFSET: int = 24

var base_fonts: Dictionary = {}

signal global_font_updated

var file_tree_expanded_sections: Dictionary = {
	"Examples": true,
	"Local Storage": true,
	"Local Textures": false,
	"Base Textures": false,
	"Local Palettes": false
}

var max_history_size: int = 25
var stretch_mode: int = SceneTree.STRETCH_MODE_2D
var stretch_aspect: int = SceneTree.STRETCH_ASPECT_EXPAND

func _ready() -> void:
	var global_theme: Theme = Theme.new()
	var default_global_font: DynamicFont = DynamicFont.new()
	default_global_font.font_data = load("res://resources/fonts/PixelCode.ttf")
	default_global_font.size = 14
	global_theme.default_font = default_global_font
	self.theme = global_theme

	base_fonts[default_global_font.get_instance_id()] = {
		"ref": weakref(default_global_font),
		"base_size": default_global_font.size,
		"base_data": default_global_font.font_data
	}

	get_tree().connect("node_added", self, "_on_node_added")
	_traverse_and_register_fonts(get_tree().root)

	_cached_window_size = OS.window_size
	_cached_window_pos = OS.window_position
	
	shrink_spinner.connect("value_changed", self, "_on_shrink_changed")

	load_settings()
	
	color_picker.connect("color_changed", self, "_on_color_changed")

	if user_settings_btn:
		user_settings_btn.connect("pressed", self, "_on_user_settings_pressed")

	if settings_dialog:
		settings_dialog.connect("delimiter_changed", self, "_on_delimiter_changed")
		settings_dialog.connect("background_color_changed", self, "_on_color_changed")
		settings_dialog.connect("shrink_changed", self, "_on_shrink_changed")
		settings_dialog.connect("max_history_changed", self, "_on_max_history_changed")
		settings_dialog.connect("stretch_mode_changed", self, "_on_stretch_mode_changed")
		settings_dialog.connect("stretch_aspect_changed", self, "_on_stretch_aspect_changed")

	get_tree().root.connect("size_changed", self, "_on_window_size_changed")

func _on_toggle_ref_image_btn_pressed() -> void:
	var ref_settings: Node = get_tree().root.find_node("ReferenceImageSettings", true, false)
	if ref_settings:
		ref_settings.toggle_reference_image()

func _on_user_settings_pressed() -> void:
	settings_dialog.init_settings(preferred_delimiter, color_rect.color, shrink_spinner.value, max_history_size, stretch_mode, stretch_aspect)
	settings_dialog.popup_centered()

func _on_delimiter_changed(new_delim: String) -> void:
	preferred_delimiter = new_delim
	save_settings()

func _on_max_history_changed(new_val) -> void:
	max_history_size = int(new_val)
	if lnz_text_edit:
		lnz_text_edit.max_history_size = max_history_size
	save_settings()

func _on_stretch_mode_changed(new_mode: int) -> void:
	stretch_mode = new_mode
	_apply_screen_shrink(shrink_spinner.value)
	save_settings()

func _on_stretch_aspect_changed(new_aspect: int) -> void:
	stretch_aspect = new_aspect
	_apply_screen_shrink(shrink_spinner.value)
	save_settings()

func _on_window_size_changed() -> void:
		if not OS.window_fullscreen and not OS.window_maximized:
			_cached_window_size = OS.window_size
			_cached_window_pos = OS.window_position

func get_preferred_delimiter() -> String:
	var delims: Dictionary = {
		"comma_space": ", ",
		"comma": ",",
		"comma_tab": ",\t",
		"tab": "\t",
		"space": " "
	}
	return delims.get(preferred_delimiter, "auto")

# func _process(_delta: float):
# 	if not OS.window_fullscreen and not OS.window_maximized:
# 		_cached_window_size = OS.window_size
# 		_cached_window_pos = OS.window_position

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_settings()

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)

	config.set_value("Display", "fullscreen", OS.window_fullscreen)
	config.set_value("Display", "maximized", OS.window_maximized)
	config.set_value("Display", "window_size", _cached_window_size)
	config.set_value("Display", "window_position", _cached_window_pos)
	config.set_value("Display", "background_color", color_rect.color)
	config.set_value("Display", "shrink", shrink_spinner.value)
	config.set_value("Display", "stretch_mode", stretch_mode)
	config.set_value("Display", "stretch_aspect", stretch_aspect)
	
	config.set_value("LNZOptions", "preferred_delimiter", preferred_delimiter)
	config.set_value("LNZOptions", "max_history_size", max_history_size)

	config.set_value("Display", "using_alt_font", using_alt_font)
	config.set_value("Display", "font_size_offset", font_size_offset)

	if file_tree and file_tree.has_method("get_expanded_states"):
		file_tree_expanded_sections = file_tree.get_expanded_states()

	config.set_value("Display", "file_tree_expanded_sections", file_tree_expanded_sections)
	
	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving window settings: ", save_err)

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	
	var default_color: Color = Color( 0.168627, 0.45098, 0.45098, 1 )
	
	if err == OK:
		var bg_color: Color = config.get_value("Display", "background_color", default_color)
		color_rect.color = bg_color
		color_picker.color = bg_color

		var saved_shrink: float = config.get_value("Display", "shrink", 1)
		shrink_spinner.value = saved_shrink
		
		stretch_mode = config.get_value("Display", "stretch_mode", SceneTree.STRETCH_MODE_2D)
		stretch_aspect = config.get_value("Display", "stretch_aspect", SceneTree.STRETCH_ASPECT_EXPAND)
		
		_apply_screen_shrink(saved_shrink)

		file_tree_expanded_sections = config.get_value("Display", "file_tree_expanded_sections", file_tree_expanded_sections)
		if file_tree and file_tree.has_method("set_expanded_states"):
			file_tree.set_expanded_states(file_tree_expanded_sections)

		var saved_size = null
		if config.has_section_key("Display", "window_size"):
			saved_size = config.get_value("Display", "window_size")
			OS.window_size = saved_size
			_cached_window_size = saved_size

		if config.has_section_key("Display", "window_position") and saved_size:
			var saved_pos = config.get_value("Display", "window_position")
			var screen_size = OS.get_screen_size(OS.current_screen)
			
			var is_off_screen = saved_pos.x < 0 or saved_pos.y < 0 or \
								saved_pos.x + saved_size.x > screen_size.x or \
								saved_pos.y + saved_size.y > screen_size.y
								
			if is_off_screen:
				OS.center_window()
				_cached_window_pos = OS.window_position
			else:
				OS.window_position = saved_pos
				_cached_window_pos = saved_pos
		else:
			OS.center_window()

		var is_maximized: bool = config.get_value("Display", "maximized", false)
		var is_fullscreen: bool = config.get_value("Display", "fullscreen", false)
		
		if is_fullscreen:
			OS.window_fullscreen = true
		elif is_maximized:
			OS.window_maximized = true

		preferred_delimiter = config.get_value("LNZOptions", "preferred_delimiter", "comma_space")
		if not preferred_delimiter in [", ", ",", ",\t", "\t", " "]:
			preferred_delimiter = "comma_space"
		max_history_size = config.get_value("LNZOptions", "max_history_size", 50)
		if lnz_text_edit:
			lnz_text_edit.max_history_size = max_history_size

		using_alt_font = config.get_value("Display", "using_alt_font", false)
		font_size_offset = config.get_value("Display", "font_size_offset", 0)

	else:
		OS.center_window()
		color_rect.color = default_color
		color_picker.color = default_color
		if lnz_text_edit:
			lnz_text_edit.max_history_size = 50

		shrink_spinner.value = 1.0
		stretch_mode = SceneTree.STRETCH_MODE_2D
		stretch_aspect = SceneTree.STRETCH_ASPECT_EXPAND
		_apply_screen_shrink(1.0)

	var btn: Button = get_node_or_null("HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/HBoxContainer/FontToggleButton")
	if btn:
		if using_alt_font:
			btn.text = "Font: Cascadia"
		else:
			btn.text = "Font: Pixel"

	_apply_global_font_settings()

func _traverse_and_register_fonts(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_traverse_and_register_fonts(child)

func _on_node_added(node: Node) -> void:
	if not node is Control and not node is WindowDialog:
		return

	var fonts_added: bool = false
	var overrides: Array = [
		"font", "normal_font", "bold_font", "italics_font",
		"bold_italics_font", "title_font", "title_button_font",
		"font_separator", "mono_font"
	]

	for o in overrides:
		if node.has_font_override(o):
			var f: Font = node.get_font(o)
			if f is DynamicFont and not base_fonts.has(f.get_instance_id()):
				base_fonts[f.get_instance_id()] = {
					"ref": weakref(f),
					"base_size": f.size,
					"base_data": f.font_data
				}
				fonts_added = true

	if node.theme and node.theme.default_font:
		var f: Font = node.theme.default_font
		if f is DynamicFont and not base_fonts.has(f.get_instance_id()):
			base_fonts[f.get_instance_id()] = {
				"ref": weakref(f),
				"base_size": f.size,
				"base_data": f.font_data
			}
			fonts_added = true

	if fonts_added:
		_apply_global_font_settings()

func _apply_global_font_settings() -> void:
	var cascadia_data = null
	if using_alt_font:
		cascadia_data = load("res://resources/fonts/CascadiaCode.ttf")
		if not cascadia_data:
			print("WARNING: CascadiaCode.ttf not found at res://resources/fonts/CascadiaCode.ttf")

	var keys_to_erase: Array = []
	for id in base_fonts.keys():
		var f_info: Dictionary = base_fonts[id]
		var f: DynamicFont = f_info.ref.get_ref()
		
		if not f:
			keys_to_erase.append(id)
			continue

		var target_base_size: int = f_info.base_size

		if using_alt_font and cascadia_data:
			f.font_data = cascadia_data
			
			var path: String = f_info.base_data.font_path
			
			if "PixelCode" in path:
				target_base_size = int(f_info.base_size * 1.0)
			elif "pixel_maz" in path:
				target_base_size = int(f_info.base_size * 0.5) 
				
		else:
			f.font_data = f_info.base_data

		f.size = max(4, target_base_size + font_size_offset)

	for id in keys_to_erase:
		base_fonts.erase(id)

	emit_signal("global_font_updated")

func increase_font_size() -> void:
	if font_size_offset < MAX_FONT_OFFSET:
		font_size_offset += 2
		_apply_global_font_settings()
		save_settings()

func decrease_font_size() -> void:
	if font_size_offset > MIN_FONT_OFFSET:
		font_size_offset -= 2
		_apply_global_font_settings()
		save_settings()

func toggle_font_type() -> bool:
	using_alt_font = not using_alt_font
	_apply_global_font_settings()
	save_settings()
	return using_alt_font

func _on_FontToggleButton_pressed() -> void:
	toggle_font_type()
	var btn: Button = get_node_or_null("HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/HBoxContainer/FontToggleButton")
	if btn:
		if using_alt_font:
			btn.text = "Font: Cascadia"
		else:
			btn.text = "Font: Pixel"

func _on_DecreaseFontButton_pressed() -> void:
	decrease_font_size()

func _on_IncreaseFontButton_pressed() -> void:
	increase_font_size()

func _on_color_changed(new_color: Color) -> void:
	color_rect.color = new_color
	if color_picker.color != new_color:
		color_picker.color = new_color
	save_settings()

func _on_shrink_changed(value: float) -> void:
	_apply_screen_shrink(value)
	if shrink_spinner.value != value:
		shrink_spinner.value = value
	save_settings()

func _apply_screen_shrink(shrink_value: float) -> void:
	var base_size: Vector2 = Vector2(ProjectSettings.get_setting("display/window/size/width"), ProjectSettings.get_setting("display/window/size/height"))
	
	get_tree().set_screen_stretch(
		stretch_mode, 
		stretch_aspect, 
		base_size, 
		shrink_value
	)
