extends Control

const TILE_SIZE = 16
const KEYBOARD_ATLAS = preload("res://resources/icons/keys/Pixel_Keyboard_Buttons_1x.png")
const FONT_DYNAMIC = preload("res://resources/fonts/font_pixel_maz_30.tres")

# Key position map: key name -> [col, row, width_tiles, height_tiles]
const KEY_MAP = {
	"Q": [0, 0], "W": [1, 0], "E": [2, 0], "R": [3, 0], "T": [4, 0],
	"Y": [5, 0], "U": [6, 0], "I": [7, 0], "O": [8, 0], "P": [9, 0],
	"A": [1, 1], "S": [2, 1], "D": [3, 1], "F": [4, 1], "G": [5, 1],
	"H": [6, 1], "J": [7, 1], "K": [8, 1], "L": [9, 1],
	"Z": [2, 2], "X": [3, 2], "C": [4, 2], "V": [5, 2], "B": [6, 2],
	"N": [7, 2], "M": [8, 2],
	"1": [1, 3], "2": [2, 3], "3": [3, 3], "4": [4, 3], "5": [5, 3],
	"6": [6, 3], "7": [7, 3], "8": [8, 3], "9": [9, 3], "0": [10, 3],
	"'": [1, 4], '"': [2, 4], "-": [3, 4], "=": [4, 4],
	"[": [5, 4, 2], "]": [7, 4, 2], "\\": [9, 4, 2],
	"TAB": [1, 5, 2], "CAPS_LOCK": [3, 5, 3],
	"SHIFT": [6, 5, 4], "SHIFT_L": [6, 5, 4],
	"CTRL": [0, 6, 2], "WIN": [2, 6], "ALT": [3, 6, 2],
	"SPACE": [5, 6, 6], "SHIFT_R": [11, 6, 4],
	"UP": [12, 7, 1, 2], "DOWN": [13, 8],
	"LEFT": [11, 7], "RIGHT": [15, 7, 2],
	"F1": [0, 7], "F2": [1, 7], "F3": [2, 7], "F4": [3, 7],
	"F5": [0, 8], "F6": [1, 8], "F7": [2, 8], "F8": [3, 8],
	"F9": [0, 9], "F10": [1, 9, 2], "F11": [3, 9, 2], "F12": [5, 9, 2],
	"ESCAPE": [1, 10, 2], "BACKSPACE": [3, 10, 3],
	"ENTER": [6, 10, 2], "DELETE": [8, 10, 2],
	"INSERT": [10, 10], "HOME": [11, 10], "END": [12, 10],
	"PAGE_UP": [13, 10], "PAGE_DOWN": [14, 10],
}

func _ready():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.focus_mode = Control.FOCUS_NONE
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_build_overlay()

func _input(event):
	if HotkeyManager and HotkeyManager.is_action_pressed("global_toggle_hotkey_overlay"):
		visible = not visible
		return
	if event is InputEventKey and event.pressed and event.scancode == KEY_F1:
		visible = not visible

func _build_overlay():
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
	
	var sections = [
		{
			"title": "Viewport",
			"items": [
				{ "desc": "Rotate Camera View", "keys": ["left-click drag"] },
				{ "desc": "Pan Camera View", "keys": ["SPACE", "+", "left-click drag"] },
				{ "desc": "Pan Camera View", "keys": ["middle mouse drag"] },
				{ "desc": "Zoom In (continuous)", "keys": ["wheel up"] },
				{ "desc": "Zoom Out (continuous)", "keys": ["wheel down"] },
				{ "desc": "Zoom In/Out (incremental)", "keys": ["SHIFT", "+", "-"] },
				{ "desc": "Front View", "keys": ["1"] },
				{ "desc": "Bottom View", "keys": ["2"] },
				{ "desc": "Top View", "keys": ["3"] },
				{ "desc": "Right View", "keys": ["4"] },
				{ "desc": "Left View", "keys": ["5"] },
				{ "desc": "Back View", "keys": ["6"] },
				{ "desc": "Right-Bottom Iso", "keys": ["7"] },
				{ "desc": "Right-Top Iso", "keys": ["8"] },
				{ "desc": "Left-Bottom Iso", "keys": ["9"] },
				{ "desc": "Left-Top Iso", "keys": ["0"] },
				{ "desc": "Undo last committed action", "keys": ["CTRL", "+", "Z"] },
				{ "desc": "Redo last committed action", "keys": ["CTRL", "+", "Y"] },
				{ "desc": "Exit Current Mode", "keys": ["ESCAPE"] },
				{ "desc": "Add or remove ballz in group selection", "keys": ["CTRL", "+", "left-click"] },
				{ "desc": "Box selection of ballz", "keys": ["CTRL", "+", "left-click drag"] },
				{ "desc": "Toggle Hotkey Overlay", "keys": ["F1"] },
			]
		},
		{
			"title": "Tools",
			"items": [
				{ "desc": "Open/Close Auto Paintballer", "keys": ["A"] },
				{ "desc": "Open/Close Palette Viewer", "keys": ["T"] },
				{ "desc": "Open/Close Variation Viewer", "keys": ["V"] },
				{ "desc": "Open/Close Texture Editor (none yet)", "keys": [] },
				{ "desc": "Capture [Head Shot]", "keys": ["K"] },
			]
		},
		{
			"title": "Text Editing",
			"items": [
				{ "desc": "Apply and Save Changes", "keys": ["CTRL", "+", "S"] },
				{ "desc": "Flash Ballz / Linez", "keys": ["CTRL", "+", "Q"] },
				{ "desc": "Toggle Find and Replace panel", "keys": ["CTRL", "+", "F"] },
			]
		},
		{
			"title": "Visual Editing",
			"items": [
				{ "desc": "Move selected Ball", "keys": ["SHIFT", "+", "left-click drag"] },
				{ "desc": "Scale/Resize selected Ball", "keys": ["SHIFT", "+", "ALT", "+", "left-click drag"] },
				{ "desc": "Lock movement to axis during drag", "keys": ["X", "or", "Y", "or", "Z"] },
			]
		},
		{
			"title": "Select Mode",
			"items": [
				{ "desc": "Open/Close Select Mode", "keys": ["S"] },
				{ "desc": "Select Ball (or Deselect)", "keys": ["left-click"] },
				{ "desc": "Jump to Ballz Info / Add Ball", "keys": ["B", "or", "Z", "or", "dbl-click"] },
				{ "desc": "Jump to [Move] entries", "keys": ["X", "or", "M"] },
				{ "desc": "Jump to [Project Ball] entries", "keys": ["C", "or", "P"] },
				{ "desc": "Jump to [Linez] entries", "keys": ["V", "or", "L"] },
				{ "desc": "Cycle through nearby balls", "keys": ["N"] },
				{ "desc": "Hide hovered ball", "keys": ["H"] },
				{ "desc": "Omit or delete hovered ball", "keys": ["DELETE"] },
				{ "desc": "Open Tools Menu", "keys": ["right-click"] },
				{ "desc": "Open Tools Menu", "keys": ["CTRL", "+", "SPACE"] },
			]
		},
		{
			"title": "Global",
			"items": [
				{ "desc": "Unhide all hidden balls", "keys": ["CTRL", "+", "H"] },
			]
		},
		{
			"title": "Shape Mode",
			"items": [
				{ "desc": "Open/Close Shape Mode", "keys": ["D"] },
				{ "desc": "Open/Close Shape Mode", "keys": ["ALT", "+", "P"] },
			]
		},
		{
			"title": "Paintball Mode",
			"items": [
				{ "desc": "Open/Close Paintball Mode", "keys": ["W"] },
				{ "desc": "Open/Close Paintball Mode", "keys": ["ALT", "+", "B"] },
				{ "desc": "Add paintballz by point-and-click", "keys": ["left-click"] },
				{ "desc": "Delete nearest queued paintballz", "keys": ["CTRL", "+", "left-click"] },
				{ "desc": "Draw continuously by click-and-drag", "keys": ["SHIFT", "+", "left-click drag"] },
				{ "desc": "Constrain freeline to straight line", "keys": ["L", "or", "ALT"] },
				{ "desc": "Lock axis during freeline", "keys": ["X", "or", "Y"] },
				{ "desc": "Resize diameter of paintballz", "keys": ["SHIFT", "+", "wheel up/down"] },
				{ "desc": "Resize diameter of paintballz", "keys": ["SHIFT", "+", "up/down arrows"] },
				{ "desc": "Increase/decrease stamp size", "keys": ["CTRL", "+", "wheel up/down"] },
				{ "desc": "Increase/decrease rotation angle", "keys": ["ALT", "+", "wheel up/down"] },
				{ "desc": "Activate brush tool in Design canvas", "keys": ["CTRL", "+", "B"] },
				{ "desc": "Activate line tool in Design canvas", "keys": ["CTRL", "+", "L"] },
				{ "desc": "Activate H-line tool in Design canvas", "keys": ["CTRL", "+", "H"] },
				{ "desc": "Activate V-line tool in Design canvas", "keys": ["CTRL", "+", "V"] },
				{ "desc": "Undo queued paintball action", "keys": ["CTRL", "+", "SHIFT", "+", "Z"] },
				{ "desc": "Redo queued paintball action", "keys": ["CTRL", "+", "SHIFT", "+", "X"] },
			]
		},
		{
			"title": "Recolor Mode",
			"items": [
				{ "desc": "Open/Close Recolor Mode", "keys": ["G"] },
				{ "desc": "Open/Close Recolor Mode", "keys": ["ALT", "+", "F"] },
				{ "desc": "Apply Paint Bucket to ball", "keys": ["left-click"] },
			]
		},
		{
			"title": "Preset Mode",
			"items": [
				{ "desc": "Open/Close Preset Mode", "keys": ["R"] },
				{ "desc": "Open/Close Preset Mode", "keys": ["ALT", "+", "G"] },
				{ "desc": "Apply current Preset to ball", "keys": ["left-click"] },
				{ "desc": "Sample properties from ball", "keys": ["ALT", "+", "left-click"] },
			]
		},
		{
			"title": "Line Mode",
			"items": [
				{ "desc": "Open/Close Line Mode", "keys": ["E"] },
				{ "desc": "Connect linez between clicked ballz", "keys": ["left-click"] },
			]
		},
		{
			"title": "Move Mode",
			"items": [
				{ "desc": "Open/Close Move Mode", "keys": ["U"] },
				{ "desc": "Open/Close Move Mode", "keys": ["ALT", "+", "M"] },
				{ "desc": "Lock/unlock hovered ball", "keys": ["Q"] },
				{ "desc": "Unlock all locked ballz", "keys": ["CTRL", "+", "Q"] },
				{ "desc": "Select pivot ball", "keys": ["ALT", "+", "left-click"] },
				{ "desc": "Scale/Resize selected group", "keys": ["ALT", "+", "SHIFT", "+", "left-click drag"] },
				{ "desc": "Move target ball or selected group", "keys": ["left-click drag"] },
				{ "desc": "Lock movement to axis/plane", "keys": ["X", "or", "Y", "or", "Z"] },
				{ "desc": "Change nudge amount for axis", "keys": ["X/Y/Z", "+", "wheel up/down"] },
				{ "desc": "Change nudge amount for axis", "keys": ["X/Y/Z", "+", "up/down arrows"] },
				{ "desc": "Nudge specific axis", "keys": ["X/Y/Z", "+", "+/-"] },
				{ "desc": "Undo queued move/scale", "keys": ["CTRL", "+", "SHIFT", "+", "Z"] },
				{ "desc": "Redo queued move/scale", "keys": ["CTRL", "+", "SHIFT", "+", "X"] },
			]
		},
	]
	
	for section_data in sections:
		var section_vbox = VBoxContainer.new()
		section_vbox.set_custom_minimum_size(Vector2(500, 0))
		section_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(section_vbox)
		
		var title_label = Label.new()
		title_label.name = "Title_" + section_data["title"]
		title_label.text = section_data["title"]
		title_label.set_custom_minimum_size(Vector2(0, 30))
		title_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
		title_label.add_color_override("font_color", Color(0.168627, 0.45098, 0.45098, 1))
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section_vbox.add_child(title_label)
		
		for item_data in section_data["items"]:
			var item_hbox = HBoxContainer.new()
			item_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_hbox.set_custom_minimum_size(Vector2(480, 32))
			section_vbox.add_child(item_hbox)
			
			var context_label = Label.new()
			context_label.name = "Label_Context"
			context_label.text = item_data["desc"]
			context_label.set_custom_minimum_size(Vector2(180, 24))
			context_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
			context_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			context_label.size_flags_vertical = 0
			item_hbox.add_child(context_label)
			
			var key_count = len(item_data["keys"])
			for i in range(key_count):
				var key_name = item_data["keys"][i]
				
				if key_name == "or":
					var or_label = Label.new()
					or_label.name = "Label_Or"
					or_label.text = "or"
					or_label.set_custom_minimum_size(Vector2(30, 24))
					or_label.set("custom_fonts/normal_font", FONT_DYNAMIC)
					or_label.add_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
					or_label.size_flags_horizontal = 0
					or_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					item_hbox.add_child(or_label)
					continue
				
				var key_node = _create_key_node(key_name)
				if key_node:
					key_node.size_flags_horizontal = 0
					key_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					item_hbox.add_child(key_node)

func _create_key_node(key_name: String) -> Control:
	if not KEY_MAP.has(key_name):
		var label = Label.new()
		label.name = "Label_Key_" + key_name
		label.text = key_name
		label.set_custom_minimum_size(Vector2(60, 24))
		label.set("custom_fonts/normal_font", FONT_DYNAMIC)
		label.align = Label.ALIGN_CENTER
		label.size_flags_horizontal = 0
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return label
	
	var atlas = _get_atlas_for_key(key_name)
	if not atlas:
		var label = Label.new()
		label.name = "Label_Key_" + key_name
		label.text = key_name
		label.set_custom_minimum_size(Vector2(40, 24))
		label.set("custom_fonts/normal_font", FONT_DYNAMIC)
		label.align = Label.ALIGN_CENTER
		label.size_flags_horizontal = 0
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return label
	
	var tex_rect = TextureRect.new()
	tex_rect.name = "Key_" + key_name
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
