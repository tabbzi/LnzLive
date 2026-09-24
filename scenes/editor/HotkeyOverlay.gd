extends Control

const TILE_SIZE = 16
const KEYBOARD_ATLAS = preload("res://resources/icons/keys/Pixel_Keyboard_Buttons_1x.png")
const FONT_DYNAMIC = preload("res://resources/fonts/font_pixel_maz_30.tres")

# Key display name -> [col, row, width_tiles, height_tiles]
const KEY_MAP = {
	"Q": [0, 0, 1, 1], "W": [1, 0, 1, 1], "E": [2, 0, 1, 1], "R": [3, 0, 1, 1], "T": [4, 0, 1, 1],
	"Y": [5, 0, 1, 1], "U": [6, 0, 1, 1], "I": [7, 0, 1, 1], "O": [8, 0, 1, 1], "P": [9, 0, 1, 1],
	"A": [1, 1, 1, 1], "S": [2, 1, 1, 1], "D": [3, 1, 1, 1], "F": [4, 1, 1, 1], "G": [5, 1, 1, 1],
	"H": [6, 1, 1, 1], "J": [7, 1, 1, 1], "K": [8, 1, 1, 1], "L": [9, 1, 1, 1],
	"Z": [2, 2, 1, 1], "X": [3, 2, 1, 1], "C": [4, 2, 1, 1], "V": [5, 2, 1, 1], "B": [6, 2, 1, 1],
	"N": [7, 2, 1, 1], "M": [8, 2, 1, 1],
	"1": [1, 3, 1, 1], "2": [2, 3, 1, 1], "3": [3, 3, 1, 1], "4": [4, 3, 1, 1], "5": [5, 3, 1, 1],
	"6": [6, 3, 1, 1], "7": [7, 3, 1, 1], "8": [8, 3, 1, 1], "9": [9, 3, 1, 1], "0": [10, 3, 1, 1],
	"'": [1, 4, 1, 1], '"': [2, 4, 1, 1], "-": [3, 4, 1, 1], "=": [4, 4, 1, 1],
	"[": [5, 4, 2, 1], "]": [7, 4, 2, 1], "\\": [9, 4, 2, 1],
	"TAB": [1, 5, 2, 1], "CAPS_LOCK": [3, 5, 3, 1],
	"SHIFT": [5, 6, 2, 1], "SHIFT_L": [5, 6, 2, 1],
	"CTRL": [0, 6, 2, 1], "WIN": [2, 6, 1, 1], "ALT": [3, 6, 2, 1],
	"SPACE": [5, 6, 6, 1], "SHIFT_R": [11, 6, 4, 1],
	"UP": [12, 7, 1, 2], "DOWN": [13, 8, 1, 1],
	"LEFT": [11, 7, 1, 1], "RIGHT": [15, 7, 2, 1],
	"F1": [0, 7, 1, 1], "F2": [1, 7, 1, 1], "F3": [2, 7, 1, 1], "F4": [3, 7, 1, 1],
	"F5": [0, 8, 1, 1], "F6": [1, 8, 1, 1], "F7": [2, 8, 1, 1], "F8": [3, 8, 1, 1],
	"F9": [0, 9, 1, 1], "F10": [1, 9, 2, 1], "F11": [3, 9, 2, 1], "F12": [5, 9, 2, 1],
	"ESCAPE": [1, 10, 2, 1], "BACKSPACE": [3, 10, 3, 1],
	"ENTER": [6, 10, 2, 1], "DELETE": [8, 10, 2, 1],
	"INSERT": [10, 10, 1, 1], "HOME": [11, 10, 1, 1], "END": [12, 10, 1, 1],
	"PAGE_UP": [13, 10, 1, 1], "PAGE_DOWN": [14, 10, 1, 1],
}

# Maps scancode constants to display names used in KEY_MAP
const SCANEODE_TO_DISPLAY = {
	KEY_SPACE: "SPACE", KEY_ESCAPE: "ESCAPE", KEY_ENTER: "ENTER",
	KEY_BACKSPACE: "BACKSPACE", KEY_TAB: "TAB", KEY_DELETE: "DELETE",
	KEY_UP: "UP", KEY_DOWN: "DOWN", KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT",
	KEY_SHIFT: "SHIFT", KEY_CONTROL: "CTRL", KEY_ALT: "ALT", KEY_META: "WIN",
	KEY_F1: "F1", KEY_F2: "F2", KEY_F3: "F3", KEY_F4: "F4",
	KEY_F5: "F5", KEY_F6: "F6", KEY_F7: "F7", KEY_F8: "F8",
	KEY_F9: "F9", KEY_F10: "F10", KEY_F11: "F11", KEY_F12: "F12",
	KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4", KEY_5: "5",
	KEY_6: "6", KEY_7: "7", KEY_8: "8", KEY_9: "9", KEY_0: "0",
	KEY_A: "A", KEY_B: "B", KEY_C: "C", KEY_D: "D", KEY_E: "E",
	KEY_F: "F", KEY_G: "G", KEY_H: "H", KEY_I: "I", KEY_J: "J",
	KEY_K: "K", KEY_L: "L", KEY_M: "M", KEY_N: "N", KEY_O: "O",
	KEY_P: "P", KEY_Q: "Q", KEY_R: "R", KEY_S: "S", KEY_T: "T",
	KEY_U: "U", KEY_V: "V", KEY_W: "W", KEY_X: "X", KEY_Y: "Y",
	KEY_Z: "Z",
}

# Maps display names back to scancode for sprite lookup
const DISPLAY_TO_SCANEODE = {}
func _init():
	for k in SCANEODE_TO_DISPLAY:
		DISPLAY_TO_SCANEODE[SCANEODE_TO_DISPLAY[k]] = k

# Mouse button display names
const MOUSE_DISPLAY = {
	BUTTON_LEFT: "left-click", BUTTON_RIGHT: "right-click",
	BUTTON_MIDDLE: "middle mouse",
	BUTTON_WHEEL_UP: "wheel up", BUTTON_WHEEL_DOWN: "wheel down",
}

func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.focus_mode = Control.FOCUS_NONE
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	if HotkeyManager:
		HotkeyManager.connect("hotkeys_reloaded", self, "_on_hotkeys_reloaded")
		_build_overlay()

func _input(event):
	if HotkeyManager and HotkeyManager.is_action_pressed("global_toggle_hotkey_overlay"):
		visible = not visible
		return
	if event is InputEventKey and event.pressed and event.scancode == KEY_F1:
		visible = not visible

func _on_hotkeys_reloaded():
	# Clear and rebuild to reflect remapped hotkeys
	for child in $Panel.get_children():
		$Panel.remove_child(child)
		child.free()
	_build_overlay()

func _build_overlay():
	if not HotkeyManager:
		return
	
	var panel = $Panel
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.margin_left = -10.0
	scroll.margin_top = -10.0
	scroll.margin_right = -10.0
	scroll.margin_bottom = -10.0
	panel.add_child(scroll)
	
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0, 0, 0, 0)
	scroll.set("custom_styles/normal", scroll_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.margin_left = 15.0
	main_vbox.margin_top = 15.0
	main_vbox.margin_right = 15.0
	main_vbox.margin_bottom = 15.0
	scroll.add_child(main_vbox)
	
	var groups = HotkeyManager.action_groups
	for group_name in groups:
		var actions = groups[group_name]
		var section_vbox = VBoxContainer.new()
		section_vbox.set_custom_minimum_size(Vector2(500, 0))
		section_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(section_vbox)
		
		var title_label = Label.new()
		title_label.name = "Title_" + group_name
		title_label.text = group_name
		title_label.set_custom_minimum_size(Vector2(0, 30))
		title_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
		title_label.add_color_override("font_color", Color(0.168627, 0.45098, 0.45098, 1))
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_vbox.add_child(title_label)
		
		for action in actions:
			var binding = HotkeyManager.get_binding(action)
			if not binding or binding.size() == 0:
				continue
			
			var display_name = HotkeyManager.get_action_display_name(action)
			var key_components = _binding_to_key_components(binding)
			
			var item_hbox = HBoxContainer.new()
			item_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_hbox.set_custom_minimum_size(Vector2(480, 32))
			section_vbox.add_child(item_hbox)
			
			var context_label = Label.new()
			context_label.name = "Label_Context"
			context_label.text = display_name
			context_label.set_custom_minimum_size(Vector2(180, 24))
			context_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
			context_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			context_label.size_flags_vertical = 0
			item_hbox.add_child(context_label)
			
			for i in range(len(key_components)):
				var comp = key_components[i]
				var key_node = _create_key_node(comp["display"])
				if key_node:
					key_node.size_flags_horizontal = 0
					key_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					item_hbox.add_child(key_node)
				
				if i < len(key_components) - 1:
					var plus_label = Label.new()
					plus_label.name = "Label_Plus"
					plus_label.text = "+"
					plus_label.set_custom_minimum_size(Vector2(16, 24))
					plus_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
					plus_label.size_flags_horizontal = 0
					plus_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					item_hbox.add_child(plus_label)

func _binding_to_key_components(binding: Dictionary) -> Array:
	var components = []
	
	if binding.get("ctrl", false):
		components.append({"display": "CTRL", "scancode": KEY_CONTROL})
	if binding.get("shift", false):
		components.append({"display": "SHIFT", "scancode": KEY_SHIFT})
	if binding.get("alt", false):
		components.append({"display": "ALT", "scancode": KEY_ALT})
	if binding.get("meta", false):
		components.append({"display": "WIN", "scancode": KEY_META})
	
	var scancode = binding.get("scancode", 0)
	
	if scancode == BUTTON_LEFT:
		components.append({"display": "left-click", "scancode": BUTTON_LEFT})
	elif scancode == BUTTON_RIGHT:
		components.append({"display": "right-click", "scancode": BUTTON_RIGHT})
	elif scancode == BUTTON_MIDDLE:
		components.append({"display": "middle mouse", "scancode": BUTTON_MIDDLE})
	elif scancode == BUTTON_WHEEL_UP:
		components.append({"display": "wheel up", "scancode": BUTTON_WHEEL_UP})
	elif scancode == BUTTON_WHEEL_DOWN:
		components.append({"display": "wheel down", "scancode": BUTTON_WHEEL_DOWN})
	elif scancode == KEY_EQUAL or scancode == KEY_PLUS or scancode == KEY_KP_ADD:
		# Render combo '+' as text, not as a sprite tile
		var plus_label = Label.new()
		plus_label.name = "Label_Plus"
		plus_label.text = "+"
		plus_label.set_custom_minimum_size(Vector2(16, 24))
		plus_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
		plus_label.size_flags_horizontal = 0
		plus_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		components.append({"display": "+", "scancode": scancode, "is_plus": true})
	elif SCANEODE_TO_DISPLAY.has(scancode):
		components.append({"display": SCANEODE_TO_DISPLAY[scancode], "scancode": scancode})
	
	return components

func _create_key_node(display_name: String) -> Control:
	if display_name == "+":
		var label = Label.new()
		label.name = "Label_Plus"
		label.text = "+"
		label.set_custom_minimum_size(Vector2(16, 24))
		label.set("custom_fonts/normal_font", FONT_DYNAMIC)
		label.align = Label.ALIGN_CENTER
		label.size_flags_horizontal = 0
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return label
	
	# Check KEY_MAP for sprite tiles
	if KEY_MAP.has(display_name):
		var atlas = _get_atlas_for_key(display_name)
		if atlas:
			var tex_rect = TextureRect.new()
			tex_rect.name = "Key_" + display_name
			tex_rect.texture = atlas
			tex_rect.expand = true
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var region = atlas.region
			var tw = region.size.x
			var th = region.size.y
			tex_rect.set_custom_minimum_size(Vector2(tw * 2, th * 2))
			tex_rect.size_flags_horizontal = 0
			tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			return tex_rect
	
	# Fallback: text label for mouse actions, unknown keys
	var label = Label.new()
	label.name = "Label_Key_" + display_name
	label.text = display_name
	label.set_custom_minimum_size(Vector2(60, 24))
	label.set("custom_fonts/normal_font", FONT_DYNAMIC)
	label.align = Label.ALIGN_CENTER
	label.size_flags_horizontal = 0
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

func _get_atlas_for_key(key_name: String) -> AtlasTexture:
	var pos = KEY_MAP.get(key_name)
	if not pos:
		return null
	
	var col = pos[0]
	var row = pos[1]
	var tile_w = pos[2] if len(pos) > 2 else 1
	var tile_h = pos[3] if len(pos) > 3 else 1
	
	var atlas = AtlasTexture.new()
	atlas.atlas = KEYBOARD_ATLAS
	atlas.region = Rect2(
		col * TILE_SIZE,
		row * TILE_SIZE,
		tile_w * TILE_SIZE,
		tile_h * TILE_SIZE
	)
	return atlas
