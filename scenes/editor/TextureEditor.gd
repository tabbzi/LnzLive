extends DraggablePanel
## TextureEditor.gd
## Edit texture BMP files in editor

const BAYER4: Array = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

enum Tool {
	PENCIL,
	ERASER,
	FILL,
	EYEDROPPER
}

enum BrushShape {
	SQUARE,
	CIRCLE
}

enum BrushPattern {
	SOLID,
	CHECKER,
	V_STRIPES,
	H_STRIPES,
	BAYER,
	NOISE
}

enum GameMode {
	PETZ,
	BABYZ
}

var current_mode: int = GameMode.PETZ

var current_tool: int = Tool.PENCIL
var current_brush_shape: int = BrushShape.SQUARE
var current_brush_pattern: int = BrushPattern.SOLID
var current_color_index: int = 0
var current_color: Color = Color(1, 1, 1, 1)

var secondary_color_index: int = -1
var secondary_color: Color = Color(0, 0, 0, 0)

var canvas_size: Vector2 = Vector2(64, 64)
var current_zoom: int = 4
var active_image: Image = null
var active_texture: ImageTexture = null

var palette_colors: Array = []
var _color_hash_cache: Dictionary = {} 
var last_draw_pos: Vector2 = Vector2(-1, -1)
var is_drawing: bool = false
var _canvas_dirty: bool = false # Flag to prevent GPU stalling

var dog_generator: Node = null

onready var size_option_btn: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/SizeHBox/SizeOptionButton
onready var zoom_option_btn: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/SizeHBox/ZoomOptionButton
onready var texture_rect: TextureRect = $VBoxContainer/ScrollContainer/VBoxContainer/CanvasScroll/CenterContainer/TextureRect
onready var palette_grid: GridContainer = $VBoxContainer/ScrollContainer/VBoxContainer/PaletteScroll/PaletteGrid
onready var active_color_rect: ColorRect = $VBoxContainer/ScrollContainer/VBoxContainer/ColorContainer/ActiveColorRect
onready var active_color_label: Label = $VBoxContainer/ScrollContainer/VBoxContainer/ColorContainer/ActiveColorRect/ColorIndexLabel

onready var brush_size_spin: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/BrushHBox/HBoxContainer/BrushSizeSpin
onready var brush_spacing_spin: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/BrushHBox/HBoxContainer2/BrushSpacingSpin
onready var brush_shape_option: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/BrushHBox/HBoxContainer3/BrushShapeOption

onready var brush_pattern_option: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/DitherHBox/BrushPatternOption
onready var dither_amount_spin: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/DitherHBox/DitherAmountSpin
onready var use_secondary_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/HBoxContainer/UseSecondaryCheckBox
onready var active_secondary_color_rect: ColorRect = $VBoxContainer/ScrollContainer/VBoxContainer/ColorContainer/ActiveSecondaryColorRect
onready var secondary_color_label: Label = $VBoxContainer/ScrollContainer/VBoxContainer/ColorContainer/ActiveSecondaryColorRect/SecondaryColorIndexLabel

onready var current_tool_label: Label = $VBoxContainer/ScrollContainer/VBoxContainer/CurrentToolLabel

onready var pencil_btn: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ToolsHBox/PencilButton
onready var eraser_btn: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ToolsHBox/EraserButton
onready var fill_btn: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ToolsHBox/FillButton
onready var contiguous_check_box: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/ToolsHBox/ContiguousCheckBox
onready var eyedropper_btn: Button = $VBoxContainer/ScrollContainer/VBoxContainer/ToolsHBox/EyedropperButton
onready var ramp_recolor_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/HBoxContainer/RampRecolorCheckBox

onready var mirror_h_btn: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/MirrorHBox/MirrorHCheckBox
onready var mirror_v_btn: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/MirrorHBox/MirrorVCheckBox

onready var filename_line_edit = $VBoxContainer/ScrollContainer/VBoxContainer/SaveHBox/FileNameLineEdit
onready var active_textures_option: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/SaveHBox/ActiveTexturesOption

onready var show_quadrants_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/ShowQuadrantsCheckBox
onready var quadrant_overlay: CanvasItem = $VBoxContainer/ScrollContainer/VBoxContainer/CanvasScroll/CenterContainer/TextureRect/QuadrantOverlay

func _ready() -> void:
	set_process(true)
	
	var dir: Directory = Directory.new()
	if not dir.dir_exists("user://resources/textures"):
		var err: int = dir.make_dir_recursive("user://resources/textures")
		if err != OK and err != ERR_ALREADY_EXISTS:
			print("Failed to create textures directory.")

	size_option_btn.add_item("32 x 32", 32)
	size_option_btn.add_item("64 x 64", 64)
	size_option_btn.add_item("128 x 128", 128)
	size_option_btn.add_item("256 x 256", 256)
	size_option_btn.select(1)

	zoom_option_btn.add_item("1x", 1)
	zoom_option_btn.add_item("2x", 2)
	zoom_option_btn.add_item("4x", 4)
	zoom_option_btn.add_item("8x", 8)
	zoom_option_btn.add_item("16x", 16)
	zoom_option_btn.select(2)

	brush_shape_option.add_item("Square", BrushShape.SQUARE)
	brush_shape_option.add_item("Circle", BrushShape.CIRCLE)
	
	brush_pattern_option.add_item("Solid", BrushPattern.SOLID)
	brush_pattern_option.add_item("Checker", BrushPattern.CHECKER)
	brush_pattern_option.add_item("V-Stripes", BrushPattern.V_STRIPES)
	brush_pattern_option.add_item("H-Stripes", BrushPattern.H_STRIPES)
	brush_pattern_option.add_item("Bayer", BrushPattern.BAYER)
	brush_pattern_option.add_item("Noise", BrushPattern.NOISE)

	load_settings()
	_initialize_canvas()

	# Attach saving hooks to inputs
	brush_size_spin.connect("value_changed", self, "_trigger_setting_save")
	brush_spacing_spin.connect("value_changed", self, "_trigger_setting_save")
	dither_amount_spin.connect("value_changed", self, "_trigger_setting_save")
	contiguous_check_box.connect("toggled", self, "_trigger_setting_save")
	ramp_recolor_check.connect("toggled", self, "_trigger_setting_save")
	use_secondary_check.connect("toggled", self, "_trigger_setting_save")
	mirror_h_btn.connect("toggled", self, "_trigger_setting_save")
	mirror_v_btn.connect("toggled", self, "_trigger_setting_save")

	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")

	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_pet_palette_changed")
		current_mode = GameMode.BABYZ if dog_generator.is_babyz_mode else GameMode.PETZ

		var lte: Node = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
		if lte:
			lte.connect("text_changed", self, "_on_lnz_text_changed")

		call_deferred("populate_palette")
		call_deferred("_populate_active_textures")

	_update_tool_buttons()

	show_quadrants_check.connect("toggled", self, "_trigger_setting_save")
	show_quadrants_check.connect("toggled", self, "_on_show_quadrants_toggled")
	quadrant_overlay.connect("draw", self, "_on_QuadrantOverlay_draw")

	$VBoxContainer/ScrollContainer/VBoxContainer/PaletteScroll.connect("resized", self, "_on_palette_scroll_resized")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == BUTTON_LEFT:
		if is_drawing:
			is_drawing = false
			_on_pen_up()

func _process(_delta: float) -> void:
	# GPU Optimization: Only upload image to GPU once per frame when dirty
	if _canvas_dirty and active_texture and active_image:
		active_texture.set_data(active_image)
		_canvas_dirty = false

func _initialize_canvas() -> void:
	active_image = Image.new()
	active_image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	active_image.fill(_get_background_color())

	active_texture = ImageTexture.new()
	active_texture.create_from_image(active_image, 0)
	texture_rect.texture = active_texture
	texture_rect.rect_min_size = canvas_size * current_zoom
	if quadrant_overlay:
		quadrant_overlay.update()

func load_settings() -> void:
	var data: Dictionary = LnzLiveUtils.load_config("TextureEditor", "user://settings.cfg")
	if data.empty():
		return
	print("[STATUS] TextureEditor: loading settings configuration")
	_is_loading_settings = true
	brush_size_spin.value = data.get("brush_size", 1.0)
	brush_spacing_spin.value = data.get("brush_spacing", 1.0)
	dither_amount_spin.value = data.get("dither_amount", 0.5)
	var shape_idx: int = data.get("brush_shape", BrushShape.SQUARE)
	brush_shape_option.select(shape_idx)
	current_brush_shape = shape_idx
	var pat_idx: int = data.get("brush_pattern", BrushPattern.SOLID)
	brush_pattern_option.select(pat_idx)
	current_brush_pattern = pat_idx
	contiguous_check_box.pressed = data.get("contiguous", true)
	ramp_recolor_check.pressed = data.get("ramp_recolor", false)
	use_secondary_check.pressed = data.get("use_secondary", false)
	mirror_h_btn.pressed = data.get("mirror_h", false)
	mirror_v_btn.pressed = data.get("mirror_v", false)
	show_quadrants_check.pressed = data.get("show_quadrants", false)
	_is_loading_settings = false

func save_settings() -> void:
	var values: Dictionary = {}
	values["brush_size"] = brush_size_spin.value
	values["brush_spacing"] = brush_spacing_spin.value
	values["dither_amount"] = dither_amount_spin.value
	values["brush_shape"] = current_brush_shape
	values["brush_pattern"] = current_brush_pattern
	values["contiguous"] = contiguous_check_box.pressed
	values["ramp_recolor"] = ramp_recolor_check.pressed
	values["use_secondary"] = use_secondary_check.pressed
	values["mirror_h"] = mirror_h_btn.pressed
	values["mirror_v"] = mirror_v_btn.pressed
	values["show_quadrants"] = show_quadrants_check.pressed
	LnzLiveUtils.save_config("TextureEditor", values, "user://settings.cfg")

func _trigger_setting_save(_ignored_value = null) -> void:
	if _is_loading_settings: return
	save_settings()

func _on_ZoomOptionButton_item_selected(index: int) -> void:
	current_zoom = zoom_option_btn.get_item_id(index)
	texture_rect.rect_min_size = canvas_size * current_zoom
	quadrant_overlay.update()

func _on_SizeOptionButton_item_selected(index: int) -> void:
	var size_val: int = size_option_btn.get_item_id(index)
	canvas_size = Vector2(size_val, size_val)
	_initialize_canvas()
	quadrant_overlay.update()

func _on_BrushShapeOption_item_selected(index: int) -> void:
	current_brush_shape = brush_shape_option.get_item_id(index)
	save_settings()

func _on_BrushPatternOption_item_selected(index: int) -> void:
	current_brush_pattern = brush_pattern_option.get_item_id(index)
	save_settings()

func populate_palette() -> void:
	for child in palette_grid.get_children():
		palette_grid.remove_child(child)
		child.queue_free()

	palette_colors.clear()
	_color_hash_cache.clear()

	if dog_generator == null or dog_generator.current_palette_texture == null:
		return

	var pal_texture = dog_generator.current_palette_texture
	var img = pal_texture.get_data()
	img.lock()

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if palette_colors.size() >= 256:
				break
			var c: Color = img.get_pixel(x, y)
			palette_colors.append(c)

			var btn: Button = Button.new()
			btn.rect_min_size = Vector2(24, 24)
			
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = c
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0, 0, 0, 0) # Transparent
			
			var focus_style: StyleBoxFlat = style.duplicate()
			focus_style.border_color = Color(1, 1, 1, 1) # Solid White
			
			btn.add_stylebox_override("normal", style)
			btn.add_stylebox_override("hover", style)
			btn.add_stylebox_override("pressed", focus_style)
			btn.add_stylebox_override("focus", focus_style)

			btn.connect("pressed", self, "_on_palette_color_selected", [palette_colors.size() - 1])
			btn.connect("gui_input", self, "_on_palette_color_gui_input", [palette_colors.size() - 1])
			palette_grid.add_child(btn)

	img.unlock()

	if palette_colors.size() > 0:
		if current_color_index >= 0 and current_color_index < palette_colors.size():
			_on_palette_color_selected(current_color_index)
		else:
			_on_palette_color_selected(0)

	_on_palette_scroll_resized()

func _get_closest_palette_index(c: Color, preferred_base: int = -1) -> int:
	if preferred_base >= 0 and preferred_base + 10 <= palette_colors.size():
		for i in range(preferred_base, preferred_base + 10):
			var pc = palette_colors[i]
			var d = abs(pc.r - c.r) + abs(pc.g - c.g) + abs(pc.b - c.b)
			if d < 0.001:
				return i
				
	var key: int = c.to_rgba32()
	if _color_hash_cache.has(key):
		return _color_hash_cache[key]
		
	var best_idx: int = 0
	var best_dist: float = 100000.0
	for i in range(palette_colors.size()):
		var pc: Color = palette_colors[i]
		var d: float = abs(pc.r - c.r) + abs(pc.g - c.g) + abs(pc.b - c.b)
		if d < best_dist:
			best_dist = d
			best_idx = i
			
	_color_hash_cache[key] = best_idx
	return best_idx

func _on_palette_color_selected(index) -> void:
	current_color_index = index
	if index >= 0 and index < palette_colors.size():
		current_color = palette_colors[index]
	active_color_rect.color = current_color
	active_color_label.text = "Primary: " + str(current_color_index)
	
	var luma: float = current_color.r * 0.299 + current_color.g * 0.587 + current_color.b * 0.114
	if luma > 0.5:
		active_color_label.add_color_override("font_color", Color(0, 0, 0))
	else:
		active_color_label.add_color_override("font_color", Color(1, 1, 1))
	
	if current_tool == Tool.EYEDROPPER:
		_on_PencilButton_pressed()

func _on_palette_color_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_RIGHT:
		_on_palette_color_right_selected(index)

func _on_palette_color_right_selected(index: int) -> void:
	secondary_color_index = index
	if index >= 0 and index < palette_colors.size():
		secondary_color = palette_colors[index]
	active_secondary_color_rect.color = secondary_color
	secondary_color_label.text = "Secondary: " + str(secondary_color_index)

	var luma: float = secondary_color.r * 0.299 + secondary_color.g * 0.587 + secondary_color.b * 0.114
	if luma > 0.5:
		secondary_color_label.add_color_override("font_color", Color(0, 0, 0))
	else:
		secondary_color_label.add_color_override("font_color", Color(1, 1, 1))

func _on_pet_palette_changed(_palette_name) -> void:
	if dog_generator and dog_generator.has_method("get_is_babyz_mode"):
		current_mode = GameMode.BABYZ if dog_generator.is_babyz_mode else GameMode.PETZ
	elif dog_generator:
		current_mode = GameMode.BABYZ if dog_generator.get("is_babyz_mode") else GameMode.PETZ
	else:
		current_mode = GameMode.PETZ

	populate_palette()
	_populate_active_textures()

func _on_lnz_text_changed() -> void:
	call_deferred("_populate_active_textures")

func refresh_active_textures() -> void:
	_populate_active_textures()

func _populate_active_textures() -> void:
	active_textures_option.clear()
	active_textures_option.add_item("Load from List")
	active_textures_option.set_item_disabled(0, true)

	if not dog_generator or not dog_generator.lnz:
		return

	var used_textures: Array = []
	for tex_info in dog_generator.lnz.texture_list:
		if typeof(tex_info) == TYPE_DICTIONARY and tex_info.has("filename"):
			var clean_path: String = tex_info.filename.replace("\\", "/").strip_edges().to_lower()
			var txt_name: String = clean_path.get_file()
			if txt_name != "":
				if not txt_name.ends_with(".bmp"):
					txt_name += ".bmp"
				if not used_textures.has(txt_name):
					used_textures.append(txt_name)

	var dir: Directory = Directory.new()
	var custom_textures: Array = []
	if dir.open("user://resources/textures") == OK:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.to_lower().ends_with(".bmp"):
				var name_only: String = file_name.to_lower()
				if used_textures.has(name_only):
					custom_textures.append(file_name)
			file_name = dir.get_next()

	active_textures_option.add_separator()
	active_textures_option.add_item("--- Custom Textures ---")
	active_textures_option.set_item_disabled(active_textures_option.get_item_count() - 1, true)
	
	if custom_textures.size() > 0:
		for t in custom_textures:
			active_textures_option.add_item(t)
	else:
		active_textures_option.add_item("(No custom textures)")
		active_textures_option.set_item_disabled(active_textures_option.get_item_count() - 1, true)

	active_textures_option.add_separator()
	active_textures_option.add_item("--- Model Textures ---")
	active_textures_option.set_item_disabled(active_textures_option.get_item_count() - 1, true)
	
	if used_textures.size() > 0:
		for t in used_textures:
			active_textures_option.add_item(t)
	else:
		active_textures_option.add_item("(No textures in LNZ)")
		active_textures_option.set_item_disabled(active_textures_option.get_item_count() - 1, true)

func _on_ActiveTexturesOption_item_selected(index: int) -> void:
	if active_textures_option.is_item_disabled(index):
		return
		
	var text: String = active_textures_option.get_item_text(index).to_lower()
	if text.ends_with(".bmp"):
		filename_line_edit.text = text.get_basename()
		_on_LoadButton_pressed()
		
	active_textures_option.select(0)

func _update_tool_buttons() -> void:
	pencil_btn.pressed = (current_tool == Tool.PENCIL)
	eraser_btn.pressed = (current_tool == Tool.ERASER)
	fill_btn.pressed = (current_tool == Tool.FILL)
	eyedropper_btn.pressed = (current_tool == Tool.EYEDROPPER)
	
	match current_tool:
		Tool.PENCIL:
			current_tool_label.text = "Tool: Pencil"
		Tool.ERASER:
			current_tool_label.text = "Tool: Eraser"
		Tool.FILL:
			current_tool_label.text = "Tool: Fill"
		Tool.EYEDROPPER:
			current_tool_label.text = "Tool: Eyedrop"

func _on_PencilButton_pressed() -> void:
	current_tool = Tool.PENCIL
	_update_tool_buttons()

func _on_EraserButton_pressed() -> void:
	current_tool = Tool.ERASER
	_update_tool_buttons()

func _on_FillButton_pressed() -> void:
	current_tool = Tool.FILL
	_update_tool_buttons()

func _on_EyedropperButton_pressed() -> void:
	current_tool = Tool.EYEDROPPER
	_update_tool_buttons()

func _on_TextureRect_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				_handle_canvas_input(event.position)
			else:
				is_drawing = false
				_on_pen_up()
	elif event is InputEventMouseMotion:
		if is_drawing:
			_handle_canvas_input(event.position)

func _handle_canvas_input(pos: Vector2) -> void:
	var tex_size: Vector2 = texture_rect.rect_size
	var ratio: Vector2 = canvas_size / tex_size
	var img_pos: Vector2 = pos * ratio
	var x: int = int(img_pos.x)
	var y: int = int(img_pos.y)

	if x < 0 or x >= canvas_size.x or y < 0 or y >= canvas_size.y:
		return

	var current_pos: Vector2 = Vector2(x, y)
	var spacing: int = int(brush_spacing_spin.value)

	active_image.lock()
	var brush_size: int = int(brush_size_spin.value)

	if current_tool in [Tool.PENCIL, Tool.ERASER]:
		var target_color: Color = current_color if current_tool == Tool.PENCIL else _get_background_color()

		if last_draw_pos.x == -1:
			_draw_brush(x, y, brush_size, target_color)
			last_draw_pos = current_pos
		else:
			var dist: float = current_pos.distance_to(last_draw_pos)

			if dist < spacing:
				active_image.unlock()
				return

			var steps: int = int(dist / spacing)

			if steps == 0:
				_draw_brush(x, y, brush_size, target_color)
				last_draw_pos = current_pos
			else:
				for i in range(1, steps + 1):
					var t: float = float(i) / float(steps)
					var ix: int = int(round(lerp(last_draw_pos.x, x, t)))
					var iy: int = int(round(lerp(last_draw_pos.y, y, t)))
					_draw_brush(ix, iy, brush_size, target_color)
				last_draw_pos = current_pos
	elif current_tool == Tool.FILL:
		_flood_fill(x, y, current_color)
	elif current_tool == Tool.EYEDROPPER:
		var c: Color = active_image.get_pixel(x, y)
		if c.a > 0:
			var best_idx: int = _get_closest_palette_index(c)
			_on_palette_color_selected(best_idx)

	active_image.unlock()

	if current_tool != Tool.EYEDROPPER:
		_canvas_dirty = true

func _draw_brush(cx: int, cy: int, size: int, color: Color) -> void:
	
	var half_size: float = size / 2.0
	var center: Vector2 = Vector2(cx, cy)
	if size % 2 == 0:
		center += Vector2(0.5, 0.5)

	var start_x: int = cx - int(size / 2)
	var start_y: int = cy - int(size / 2)
	if size % 2 == 0:
		start_x += 1
		start_y += 1

	var dither_val: float = dither_amount_spin.value
	var use_secondary: bool = use_secondary_check.pressed and secondary_color_index != -1

	for by in range(size):
		for bx in range(size):
			var px: int = start_x + bx
			var py: int = start_y + by

			if px >= 0 and px < canvas_size.x and py >= 0 and py < canvas_size.y:
				var use_pixel: bool = true
				if current_brush_pattern == BrushPattern.CHECKER:
					use_pixel = (px + py) % 2 == 0
				elif current_brush_pattern == BrushPattern.V_STRIPES:
					use_pixel = (px % 2) == 0
				elif current_brush_pattern == BrushPattern.H_STRIPES:
					use_pixel = (py % 2) == 0
				elif current_brush_pattern == BrushPattern.BAYER:
					use_pixel = (BAYER4[py % 4][px % 4] / 16.0) < dither_val
				elif current_brush_pattern == BrushPattern.NOISE:
					use_pixel = randf() < dither_val

				if not use_pixel:
					if use_secondary:
						if current_brush_shape == BrushShape.CIRCLE:
							var p_center: Vector2 = Vector2(px, py)
							if size % 2 == 0:
								p_center += Vector2(0.5, 0.5)
							if p_center.distance_to(center) <= half_size:
								_draw_pixel(px, py, secondary_color)
						else:
							_draw_pixel(px, py, secondary_color)
					continue

				if current_brush_shape == BrushShape.CIRCLE:
					var p_center: Vector2 = Vector2(px, py)
					if size % 2 == 0:
						p_center += Vector2(0.5, 0.5)
					if p_center.distance_to(center) <= half_size:
						_draw_pixel(px, py, color)
				else:
					_draw_pixel(px, py, color)

func _apply_pixel_color(px: int, py: int, brush_color: Color) -> void:
	if px < 0 or px >= canvas_size.x or py < 0 or py >= canvas_size.y:
		return
		
	var final_color: Color = brush_color
	
	if ramp_recolor_check and ramp_recolor_check.pressed and current_color_index >= 10 and current_color_index <= 199:
		var c: Color = active_image.get_pixel(px, py)
		if c.a > 0:
			var source_base: int = -1
			if secondary_color_index >= 10 and secondary_color_index <= 199:
				source_base = int(secondary_color_index / 10) * 10
				
			var p_idx: int = _get_closest_palette_index(c, source_base)
			
			if source_base == -1 and p_idx >= 10 and p_idx <= 199:
				source_base = int(p_idx / 10) * 10 
				
			if source_base >= 10 and p_idx >= source_base and p_idx < source_base + 10:
				var target_base: int = int(current_color_index / 10) * 10
				final_color = palette_colors[target_base + (p_idx - source_base)]
			else:
				return
		else:
			return
			
	active_image.set_pixel(px, py, final_color)

func _draw_pixel(x: int, y: int, color: Color) -> void:
	_apply_pixel_color(x, y, color)

	if mirror_h_btn.pressed:
		var mx: int = canvas_size.x - 1 - x
		_apply_pixel_color(mx, y, color)
		if mirror_v_btn.pressed:
			var my: int = canvas_size.y - 1 - y
			_apply_pixel_color(mx, my, color)

	if mirror_v_btn.pressed:
		var my: int = canvas_size.y - 1 - y
		_apply_pixel_color(x, my, color)

func _flood_fill(x: int, y: int, target_color: Color) -> void:
	var start_color: Color = active_image.get_pixel(x, y)
	
	if start_color.a == 0 and not (ramp_recolor_check and ramp_recolor_check.pressed):
		pass
	
	var is_ramp_recolor: bool = false
	var source_base: int = -1
	var target_base: int = -1
	var start_idx: int = -1
	
	if ramp_recolor_check and ramp_recolor_check.pressed and current_color_index >= 10 and current_color_index <= 199:
		if secondary_color_index >= 10 and secondary_color_index <= 199:
			source_base = int(secondary_color_index / 10) * 10
			
		start_idx = _get_closest_palette_index(start_color, source_base)
		
		if start_idx >= 10 and start_idx <= 199:
			is_ramp_recolor = true
			target_base = int(current_color_index / 10) * 10
			
			if source_base == -1:
				source_base = int(start_idx / 10) * 10
				
			if source_base == target_base:
				return
				
			if start_idx < source_base or start_idx >= source_base + 10:
				return
		else:
			return
	else:
		if start_color == target_color:
			return

	if contiguous_check_box and contiguous_check_box.pressed:
		var stack: Array = [Vector2(x, y)]
		while stack.size() > 0:
			var p: Vector2 = stack.pop_back()
			var px: int = int(p.x)
			var py: int = int(p.y)

			if px < 0 or px >= canvas_size.x or py < 0 or py >= canvas_size.y:
				continue

			var c: Color = active_image.get_pixel(px, py)
			var match_found: bool = false
			var fill_color: Color = target_color
			
			if is_ramp_recolor:
				var p_idx: int = _get_closest_palette_index(c, source_base)
				if p_idx >= source_base and p_idx < source_base + 10:
					match_found = true
					fill_color = palette_colors[target_base + (p_idx - source_base)]
			else:
				if c == start_color:
					match_found = true
					
			if match_found:
				if c != fill_color:
					active_image.set_pixel(px, py, fill_color)
					stack.append(Vector2(px + 1, py))
					stack.append(Vector2(px - 1, py))
					stack.append(Vector2(px, py + 1))
					stack.append(Vector2(px, py - 1))
	else:
		for py in range(int(canvas_size.y)):
			for px in range(int(canvas_size.x)):
				var c: Color = active_image.get_pixel(px, py)
				if is_ramp_recolor:
					var p_idx: int = _get_closest_palette_index(c, source_base)
					if p_idx >= source_base and p_idx < source_base + 10:
						active_image.set_pixel(px, py, palette_colors[target_base + (p_idx - source_base)])
				else:
					if c == start_color:
						active_image.set_pixel(px, py, target_color)

func _on_pen_up() -> void:
	last_draw_pos = Vector2(-1, -1)

func _on_SaveButton_pressed() -> void:
	var fname: String = filename_line_edit.text.strip_edges()
	if fname == "":
		return

	if not fname.to_lower().ends_with(".bmp"):
		fname += ".bmp"

	var path: String = "user://resources/textures".plus_file(fname)
	save_indexed_bmp(path)

	var root: Node = get_tree().get_root()
	var editor: Node = root.get_node_or_null("Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
	
	if editor and editor.has_method("rescan_textures"):
		editor.rescan_textures(true)
	elif editor and editor.has_method("rescan"):
		editor.rescan()

func save_indexed_bmp(path: String) -> void:
	var f: File = File.new()
	if f.open(path, File.WRITE) != OK:
		print("Failed to save BMP at ", path)
		return

	var w: int = int(canvas_size.x)
	var h: int = int(canvas_size.y)

	if w > 1024 or h > 1024:
		printerr("[ERROR] TextureEditor: canvas size %dx%d exceeds 1024x1024 limit. Aborting save." % [w, h])
		return

	var row_size = int((w + 3) / 4) * 4
	var pixel_data_size = row_size * h
	var palette_size = 256 * 4
	var file_size = 54 + palette_size + pixel_data_size

	f.store_8(0x42)
	f.store_8(0x4D)
	f.store_32(file_size)
	f.store_16(0)
	f.store_16(0)
	f.store_32(54 + palette_size)

	f.store_32(40)
	f.store_32(w)
	f.store_32(h)
	f.store_16(1)
	f.store_16(8)
	f.store_32(0)
	f.store_32(pixel_data_size)
	f.store_32(2835)
	f.store_32(2835)
	f.store_32(256)
	f.store_32(256)

	for i in range(256):
		if i < palette_colors.size():
			var c = palette_colors[i]
			f.store_8(int(round(c.b * 255.0)))
			f.store_8(int(round(c.g * 255.0)))
			f.store_8(int(round(c.r * 255.0)))
			f.store_8(0)
		else:
			f.store_32(0)

	active_image.lock()
	for y in range(h - 1, -1, -1):
		for x in range(w):
			var c = active_image.get_pixel(x, y)
			if c.a == 0:
				f.store_8(0)
			else:
				f.store_8(_get_closest_palette_index(c))

		for p in range(row_size - w):
			f.store_8(0)

	active_image.unlock()
	f.close()
	print("Saved texture to ", path)

func _get_background_color() -> Color:
	if palette_colors.size() > 253:
		return palette_colors[253]
	elif palette_colors.size() > 0:
		return palette_colors[palette_colors.size() - 1]
	return Color(1, 0, 1, 1)

func _on_LoadButton_pressed() -> void:
	var fname: String = filename_line_edit.text.strip_edges()
	if fname == "":
		return

	if not fname.to_lower().ends_with(".bmp"):
		fname += ".bmp"

	var base_name: String = fname.get_basename()
	var extension: String = fname.get_extension()
	var variants: Array = [
		fname, fname.to_upper(), fname.to_lower(),
		base_name + "." + extension.to_upper(),
		base_name + "." + extension.to_lower(),
		base_name.to_upper() + "." + extension,
		base_name.to_lower() + "." + extension,
		base_name.to_upper() + "." + extension.to_upper(),
		base_name.to_lower() + "." + extension.to_lower()
	]
	
	var loaded_path: String = ""
	var dir: Directory = Directory.new()
	for v in variants:
		if dir.file_exists("user://resources/textures/" + v):
			loaded_path = "user://resources/textures/" + v
			break
		elif dir.file_exists("res://resources/textures/" + v):
			loaded_path = "res://resources/textures/" + v
			break

	var raw_bmp_data: Dictionary = {}
	if loaded_path != "":
		if loaded_path != "":
			var is_babyz: bool = (current_mode == GameMode.BABYZ)
			raw_bmp_data = LnzLiveUtils.load_raw_8bit_bmp(loaded_path, is_babyz)

	# 8bit BMP
	if raw_bmp_data.has("data"):
		var w: int = raw_bmp_data["w"]
		var h: int = raw_bmp_data["h"]
		var data: PoolByteArray = raw_bmp_data["data"]

		canvas_size = Vector2(w, h)
		_sync_size_ui(w, h)
		_initialize_canvas()

		active_image.lock()
		for y in range(h):
			for x in range(w):
				var idx: int = data[y * w + x]
				if idx >= 0 and idx < palette_colors.size():
					active_image.set_pixel(x, y, palette_colors[idx])
				else:
					active_image.set_pixel(x, y, _get_background_color())
		active_image.unlock()
		
		active_texture.set_data(active_image)
		print("Loaded texture purely from raw index: ", fname)

	# RGB or cached texture
	else:
		var loaded_tex: Texture = null
		for v in variants:
			if ResourceLoader.exists("user://resources/textures/" + v):
				loaded_tex = ResourceLoader.load("user://resources/textures/" + v)
				break
			elif ResourceLoader.exists("res://resources/textures/" + v):
				loaded_tex = ResourceLoader.load("res://resources/textures/" + v)
				break
				
		if loaded_tex == null:
			var preloader: ResourcePreloader = get_tree().root.get_node_or_null("Root/ResourcePreloader")
			if preloader and preloader.has_resource(fname.to_lower()):
				loaded_tex = preloader.get_resource(fname.to_lower())

		if not loaded_tex:
			print("Failed to load texture: ", fname)
			return

		var img: Image = loaded_tex.get_data()
		if not img: return

		img.lock()
		canvas_size = Vector2(img.get_width(), img.get_height())
		_sync_size_ui(canvas_size.x, canvas_size.y)
		_initialize_canvas()

		active_image.lock()
		
		var is_index_map: bool = false
		if loaded_tex.resource_path.begins_with("res://") or img.get_format() == Image.FORMAT_R8 or img.get_format() == Image.FORMAT_L8:
			is_index_map = true
			
		for y in range(canvas_size.y):
			for x in range(canvas_size.x):
				var c: Color = img.get_pixel(x, y)
				if c.a == 0:
					active_image.set_pixel(x, y, _get_background_color())
				else:
					var idx: int = -1
					if is_index_map:
						idx = int(round(c.r * 255.0))
					else:
						idx = _get_closest_palette_index(c)
						
					if idx >= 0 and idx < palette_colors.size():
						active_image.set_pixel(x, y, palette_colors[idx])
					else:
						active_image.set_pixel(x, y, _get_background_color())
		active_image.unlock()
		img.unlock()
		
		active_texture.set_data(active_image)
		print("Loaded texture via Godot fallback (RGB mapped): ", fname)

func _sync_size_ui(w: int, h: int) -> void:
	var found_size: bool = false
	for i in range(size_option_btn.get_item_count()):
		if size_option_btn.get_item_id(i) == w:
			size_option_btn.select(i)
			found_size = true
			break
	if not found_size:
		size_option_btn.add_item(str(w) + " x " + str(h), w)
		size_option_btn.select(size_option_btn.get_item_count() - 1)

func _on_show_quadrants_toggled(_pressed: bool) -> void:
	quadrant_overlay.update()

func _on_QuadrantOverlay_draw() -> void:
	if show_quadrants_check.pressed:
		var size: Vector2 = quadrant_overlay.rect_size
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		
		# Draw Crosshair
		quadrant_overlay.draw_line(Vector2(cx, 0), Vector2(cx, size.y), Color(1, 0, 0, 0.4), max(1.0, current_zoom / 2.0))
		quadrant_overlay.draw_line(Vector2(0, cy), Vector2(size.x, cy), Color(1, 0, 0, 0.4), max(1.0, current_zoom / 2.0))
		
		# Draw Labels
		var font: Font = show_quadrants_check.get_font("font")
		var text_color: Color = Color(0, 0, 0, 0.5) # Semi-transparent black
		var scale_factor: float = 2.0
		quadrant_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_factor, scale_factor))
		
		# Calculate positions in the scaled coordinate space
		var f_pos: Vector2 = Vector2(cx / 4.0 - 6, cy / 4.0 + 6)
		var b_pos: Vector2 = Vector2((cx + cx/2) / 2.0 - 6, cy / 4.0 + 6)
		var r_pos: Vector2 = Vector2(cx / 4.0 - 6, (cy + cy/2) / 2.0 + 6)
		var l_pos: Vector2 = Vector2((cx + cx/2) / 2.0 - 6, (cy + cy/2) / 2.0 + 6)
		
		quadrant_overlay.draw_string(font, f_pos, "F", text_color)
		quadrant_overlay.draw_string(font, b_pos, "B", text_color)
		quadrant_overlay.draw_string(font, r_pos, "R", text_color)
		quadrant_overlay.draw_string(font, l_pos, "L", text_color)
		
		# Reset transform to prevent affecting subsequent draw calls
		quadrant_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _on_palette_scroll_resized() -> void:
	if palette_grid and palette_grid is GridContainer:
		var available_width: float = $VBoxContainer/ScrollContainer/VBoxContainer/PaletteScroll.rect_size.x
		var new_columns: int = max(1, int((available_width - 16) / 28.0))
		palette_grid.columns = new_columns
