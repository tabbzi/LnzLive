extends Control

signal recolor(recolor_info)
signal apply_bucket(ball_no, properties)
signal apply_batch_bucket(changes)
signal apply_eye_colors(eye_colors_info)

onready var swap_scroll = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/ScrollContainer
onready var swap_lines_container = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/ScrollContainer/RecolorLines
onready var bucket_container = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer

onready var color_swap_check_container = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/CheckContainer

onready var bucket_color_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/ColorEdit
onready var bucket_outline_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/OutlineEdit
onready var bucket_type_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/TypeEdit
onready var bucket_fuzz_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/FuzzEdit
onready var bucket_texture_edit = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/TextureEdit

onready var bucket_color_icon: TextureRect = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/ColorIcon
onready var bucket_outline_icon: TextureRect = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/OutlineIcon
onready var bucket_texture_icon: TextureRect = $VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/GridContainer/TextureIcon

onready var eye_preview_canvas: Control = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyePreviewCanvas
onready var eye_outline_left_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeOutlineRow/EyeOutlineLeftEdit
onready var eye_outline_right_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeOutlineRow/EyeOutlineRightEdit
onready var eyelid_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyelidRow/EyelidEdit
onready var iris_outline_left_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/IrisOutlineRow/IrisOutlineLeftEdit
onready var iris_outline_right_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/IrisOutlineRow/IrisOutlineRightEdit
onready var iris_col_left_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/IrisColRow/IrisColLeftEdit
onready var iris_col_right_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/IrisColRow/IrisColRightEdit
onready var eye_col_left_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeColRow/EyeColLeftEdit
onready var eye_col_right_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeColRow/EyeColRightEdit

onready var all_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeButtonRow/AllCheckBox
onready var lid_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeButtonRow/LidCheckBox
onready var odd_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeButtonRow/OddCheckBox
onready var firefly_check: CheckBox = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeButtonRow/FireflyCheckBox
onready var randomize_eye_btn: Button = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeButtonRow2/RandomizeEyeButton
onready var apply_eye_colors_btn: Button = $VBoxContainer/ScrollContainer/VBoxContainer/EyeColorsContainer/EyeButtonRow2/ApplyEyeColorsButton

onready var header_container = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/Header

onready var top_row = header_container.get_node("TopRow")
onready var freq_edit: LineEdit = top_row.get_node_or_null("FreqEdit")

onready var middle_row = header_container.get_node("MiddleRow")
onready var rand_after_btn: Button = middle_row.get_node_or_null("RandomizeAfterButton")
onready var color_theory_select: OptionButton = middle_row.get_node_or_null("ColorTheorySelect")
onready var theory_seed_picker: ColorPickerButton = middle_row.get_node_or_null("TheorySeedColor")

onready var bottom_row = header_container.get_node("BottomRow")
onready var random_seed_check: CheckBox = bottom_row.get_node_or_null("RandomSeedCheckBox")
onready var natural_colors_check: CheckBox = bottom_row.get_node_or_null("NaturalColorsOnly")
onready var texturable_only_check: CheckBox = bottom_row.get_node_or_null("TexturableOnly")

onready var check_container_2 = $VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/CheckContainer2
onready var nose_ballz_check: CheckBox = check_container_2.get_node_or_null("NoseBallz")

var recolor_line_scene: PackedScene = preload("res://scenes/editor/RecolorLine.tscn")
var queued_bucket_changes: Dictionary = {} # ball_no -> properties

var dog_generator: Node = null
var cached_palette_colors: Array = []

var _eye_all: bool = false
var _eye_lid: bool = false
var _eye_odd: bool = false
var _eye_firefly: bool = false

onready var lnz_text_edit: TextEdit = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit"
)

var is_docked: bool = false

var _is_loading_settings: bool = false

const SETTINGS_PATH: String = "user://settings.cfg"
const RECOLOR_SECTION: String = "RecolorSettings"

const NATURAL_COLORS: Array = [10, 20, 30, 40, 50, 60, 90, 100, 110, 120]
const TEXTURABLE_COLORS: Array = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140]

func _ready() -> void:
	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_palette_changed")

	_setup_swap_lines()

	_setup_grid_preview(bucket_color_edit, bucket_color_icon, "BucketColor")
	_setup_grid_preview(bucket_outline_edit, bucket_outline_icon, "BucketOutline")

	bucket_texture_edit.connect("text_changed", self, "_on_bucket_property_changed")

	$VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/ApplyButton.connect("pressed", self, "_on_ApplyBucket_pressed")
	$VBoxContainer/ScrollContainer/VBoxContainer/BucketContainer/ClearButton.connect("pressed", self, "_on_ClearBucket_pressed")

	$VBoxContainer/ScrollContainer/VBoxContainer/SwapContainer/RecolorButton.connect("pressed", self, "_on_RecolorButton_pressed")

	top_row.get_node("AddButton").connect("pressed", self, "_on_AddSwap_pressed")
	top_row.get_node("ClearButton").connect("pressed", self, "_on_ClearSwap_pressed")
	top_row.get_node("AutofillButton").connect("pressed", self, "_on_AutofillSwap_pressed")
	top_row.get_node("RandomizeButton").connect("pressed", self, "_on_RandomizeSwap_pressed")

	find_node("ExportButton").connect("pressed", self, "export_recolor_json")
	find_node("ImportButton").connect("pressed", self, "_on_ImportPresetButton_pressed")

	if is_instance_valid(rand_after_btn):
		rand_after_btn.connect("pressed", self, "_on_RandomizeAfter_pressed")
	
	if is_instance_valid(theory_seed_picker):
		theory_seed_picker.connect("color_changed", self, "_on_theory_seed_changed")
		
	if is_instance_valid(random_seed_check):
		random_seed_check.connect("toggled", self, "_on_random_seed_toggled")
	
	if is_instance_valid(nose_ballz_check):
		nose_ballz_check.connect("toggled", self, "_on_nose_ballz_toggled")
	
	_populate_color_theory_options()
		
	_on_palette_changed()
	_setup_eye_colors()
	load_settings()

func _populate_color_theory_options() -> void:
	if not is_instance_valid(color_theory_select):
		return
	
	color_theory_select.clear()
	
	color_theory_select.add_item("Off")
	
	color_theory_select.add_item("Monochromatic")
	color_theory_select.add_item("Analogous")
	color_theory_select.add_item("Complementary")
	color_theory_select.add_item("Triadic")
	color_theory_select.add_item("Split Complementary")
	
	color_theory_select.selected = 0

func _on_theory_seed_changed(color: Color) -> void:
	pass

func _on_random_seed_toggled(is_on: bool) -> void:
	pass

func _on_nose_ballz_toggled(is_on: bool) -> void:
	if _is_loading_settings: return
	save_settings()

func set_docked(docked: bool) -> void:
	is_docked = docked

func _setup_swap_lines() -> void:
	for i in range(3):
		_add_swap_line()

func _add_swap_line() -> Control:
	var line: Control = recolor_line_scene.instance()
	swap_lines_container.add_child(line)
	var id: int = line.get_instance_id()
	line.name = "Line_" + str(id)
	
	var before_color = line.get_node("BeforeColor")
	var after_color = line.get_node("AfterColor")
	
	LnzLiveUtils.setup_preview_wrapper(self, before_color, "BeforeColor_" + str(id))
	LnzLiveUtils.setup_preview_wrapper(self, after_color, "AfterColor_" + str(id))
	
	var remove_btn: Button = line.get_node_or_null("RemoveButton")
	if remove_btn:
		remove_btn.connect("pressed", self, "_on_remove_line_pressed", [line])

	return line

func _on_AddSwap_pressed() -> void:
	_add_swap_line()

func _on_remove_line_pressed(line: Control) -> void:
	if swap_lines_container.get_child_count() > 1:
		line.queue_free()
	else:
		line.find_node("BeforeColor", true, false).text = ""
		line.find_node("BeforeTexture", true, false).text = ""
		line.find_node("AfterColor", true, false).text = ""
		line.find_node("AfterTexture", true, false).text = ""
		line.find_node("ColorRampCheck", true, false).pressed = false
		_refresh_all_previews()

func _on_bucket_property_changed(new_text: String) -> void:
	var pet_node: Node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if pet_node and bucket_texture_edit.text != "":
		var tex_idx: int = int(bucket_texture_edit.text)
		if pet_node.lnz and pet_node.lnz.texture_list:
			var tex: Texture = pet_node.load_texture_from_list(tex_idx, pet_node.lnz.texture_list)
			bucket_texture_icon.texture = tex
	else:
		bucket_texture_icon.texture = null

func _setup_grid_preview(le, icon_node: TextureRect, le_name: String) -> void:
	if not is_instance_valid(icon_node): return
	var parent: Node = icon_node.get_parent()
	var pos: int = icon_node.get_index()
	var orig_owner: Node = icon_node.owner
	
	var preview_container = HBoxContainer.new()
	preview_container.name = le_name + "_Preview"
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	parent.add_child(preview_container)
	parent.move_child(preview_container, pos)
	
	if orig_owner != null:
		preview_container.owner = orig_owner
		
	icon_node.queue_free() 
	
	if not le.is_connected("text_changed", self, "_on_color_list_text_changed"):
		le.connect("text_changed", self, "_on_color_list_text_changed", [preview_container])

func _on_color_list_text_changed(new_text: String, container: Container) -> void:
	LnzLiveUtils.update_color_list_previews(container, new_text, cached_palette_colors)

func _refresh_all_previews() -> void:
	var grid: Node = bucket_color_edit.get_parent()
	
	var bucket_c_prev: Node = grid.get_node_or_null("BucketColor_Preview")
	if bucket_c_prev: _on_color_list_text_changed(bucket_color_edit.text, bucket_c_prev)
	
	var bucket_o_prev: Node = grid.get_node_or_null("BucketOutline_Preview")
	if bucket_o_prev: _on_color_list_text_changed(bucket_outline_edit.text, bucket_o_prev)
	
	for i in range(swap_lines_container.get_child_count()):
		var line: Control = swap_lines_container.get_child(i)
		if line.is_queued_for_deletion(): continue
		var id: String = line.name.replace("Line_", "")
		
		var bc = line.get_node_or_null("BeforeColor_" + str(id) + "Wrapper/BeforeColor")
		var bc_prev: Node = line.get_node_or_null("BeforeColor_" + str(id) + "Wrapper/BeforeColor_" + str(id) + "_Preview")
		if bc and bc_prev: _on_color_list_text_changed(bc.text, bc_prev)

		var ac = line.get_node_or_null("AfterColor_" + str(id) + "Wrapper/AfterColor")
		var ac_prev: Node = line.get_node_or_null("AfterColor_" + str(id) + "Wrapper/AfterColor_" + str(id) + "_Preview")
		if ac and ac_prev: _on_color_list_text_changed(ac.text, ac_prev)

func _on_palette_changed(palette_name = "") -> void:
	if not dog_generator or not dog_generator.current_palette_texture:
		return
		
	var img: Image = dog_generator.current_palette_texture.get_data()
	if img == null:
		return
		
	img.lock()
	var img_width: int = img.get_width()
	var img_height: int = img.get_height()
	
	cached_palette_colors.clear()
	for i in range(256):
		var x: int = i % img_width
		var y: int = i / img_width
		if x < img_width and y < img_height:
			cached_palette_colors.append(img.get_pixel(x, y))
		else:
			cached_palette_colors.append(Color.black)
			
	img.unlock()
	_refresh_all_previews()

func queue_bucket_change(ball_node: Node) -> void:
	if not is_instance_valid(ball_node): return
	var ball_no: int = ball_node.ball_no

	var props: Dictionary = {
		"apply_ballz": true,
		"apply_paintballz": false
	}

	if bucket_color_edit.text != "": props["color_index"] = int(bucket_color_edit.text)
	if bucket_outline_edit.text != "": props["outline_color_index"] = int(bucket_outline_edit.text)
	if bucket_type_edit.text != "": props["outline"] = int(bucket_type_edit.text)
	if bucket_fuzz_edit.text != "": props["fuzz"] = int(bucket_fuzz_edit.text)
	if bucket_texture_edit.text != "": props["texture_id"] = int(bucket_texture_edit.text)

	queued_bucket_changes[ball_no] = props

	if props.has("color_index"): ball_node.color_index = props.color_index
	if props.has("outline_color_index"): ball_node.outline_color_index = props.outline_color_index
	if props.has("outline"): ball_node.outline = props.outline
	if props.has("fuzz"): ball_node.fuzz_amount = props.fuzz
	if props.has("texture_id"):
		var pet_node: Node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
		if pet_node and pet_node.lnz and pet_node.lnz.texture_list:
			var tex: Texture = pet_node.load_texture_from_list(props.texture_id, pet_node.lnz.texture_list)
			if tex: ball_node.texture = tex

	if ball_node.has_method("update_ball"):
		ball_node.update_ball()

func _on_ClearBucket_pressed() -> void:
	clear_buckets()

func clear_buckets() -> void:
	var pet_node: Node = get_tree().root.get_node_or_null("Root/PetRoot/Node")
	if pet_node and pet_node.has_method("restore_ball_visual_states"):
		pet_node.restore_ball_visual_states(queued_bucket_changes.keys())
	
	queued_bucket_changes.clear()

func _on_ApplyBucket_pressed() -> void:
	if not queued_bucket_changes.empty():
		emit_signal("apply_batch_bucket", queued_bucket_changes.duplicate())
		queued_bucket_changes.clear()

func _on_RecolorButton_pressed() -> void:
	if not queued_bucket_changes.empty():
		_on_ApplyBucket_pressed()

	var lines: Array = swap_lines_container.get_children()
	var recolor_info: Dictionary = {recolors = []}
	for l in lines:
		if l.is_queued_for_deletion(): continue
		var before_color: String = l.find_node("BeforeColor", true, false).text
		var before_texture: String = l.find_node("BeforeTexture", true, false).text
		var after_color: String = l.find_node("AfterColor", true, false).text
		var after_texture: String = l.find_node("AfterTexture", true, false).text
		var is_ramp: bool = l.find_node("ColorRampCheck", true, false).pressed

		if before_color.empty() and before_texture.empty():
			continue
		if after_color.empty() and after_texture.empty():
			continue

		recolor_info.recolors.append({
			"before_color": before_color,
			"before_texture": before_texture,
			"after_color": after_color,
			"after_texture": after_texture,
			"is_ramp": is_ramp
		})

	var balls_on: bool = color_swap_check_container.get_node("Balls").pressed
	var ball_outlines_on: bool = color_swap_check_container.get_node("Ball outlines").pressed
	var paintballs_on: bool = color_swap_check_container.get_node("Paintballs").pressed
	var lines_on: bool = color_swap_check_container.get_node("Lines").pressed

	var polygons_on: bool = color_swap_check_container.get_parent().get_node("CheckContainer2/Polygons").pressed
	var nose_ballz_on: bool = is_instance_valid(nose_ballz_check) and nose_ballz_check.pressed

	recolor_info.balls_on = balls_on
	recolor_info.ball_outlines_on = ball_outlines_on
	recolor_info.paintballs_on = paintballs_on
	recolor_info.lines_on = lines_on
	recolor_info.polygons_on = polygons_on
	recolor_info.nose_ballz_on = nose_ballz_on

	emit_signal("recolor", recolor_info)

func _on_ClearSwap_pressed() -> void:
	var lines: Array = swap_lines_container.get_children()
	for l in lines:
		if l.is_queued_for_deletion(): continue
		l.find_node("BeforeColor", true, false).text = ""
		l.find_node("BeforeTexture", true, false).text = ""
		l.find_node("AfterColor", true, false).text = ""
		l.find_node("AfterTexture", true, false).text = ""
		l.find_node("ColorRampCheck", true, false).pressed = false

	for cb in color_swap_check_container.get_children():
		if cb is CheckBox or cb is Button:
			if cb.has_method("set_pressed"):
				cb.pressed = true

	var check_container_2 = color_swap_check_container.get_parent().get_node("CheckContainer2")
	if check_container_2:
		for cb in check_container_2.get_children():
			if cb is CheckBox:
				cb.pressed = true
				
	_refresh_all_previews()

func _gather_swap_data() -> Array:
	var swaps: Array = []
	var lines: Array = swap_lines_container.get_children()
	for l in lines:
		if l.is_queued_for_deletion(): continue
		var before_color: String = l.find_node("BeforeColor", true, false).text
		var before_texture: String = l.find_node("BeforeTexture", true, false).text
		var after_color: String = l.find_node("AfterColor", true, false).text
		var after_texture: String = l.find_node("AfterTexture", true, false).text
		var is_ramp: bool = l.find_node("ColorRampCheck", true, false).pressed
		if before_color.empty() and before_texture.empty():
			continue
		if after_color.empty() and after_texture.empty():
			continue
		swaps.append({
			"before_color": before_color,
			"before_texture": before_texture,
			"after_color": after_color,
			"after_texture": after_texture,
			"is_ramp": is_ramp
		})
	return swaps

func _get_check_states() -> Dictionary:
	var states: Dictionary = {}
	for cb in color_swap_check_container.get_children():
		if cb is CheckBox:
			states[cb.name] = cb.pressed
	var check_container_2 = color_swap_check_container.get_parent().get_node("CheckContainer2")
	if check_container_2:
		for cb in check_container_2.get_children():
			if cb is CheckBox:
				states[cb.name] = cb.pressed
	return states

func _apply_swap_data(data: Dictionary) -> void:
	if typeof(data) != TYPE_DICTIONARY: return
	var swaps: Array = data.get("swaps", [])
	for i in range(swaps.size()):
		var swap = swaps[i]
		if i < swap_lines_container.get_child_count():
			var line = swap_lines_container.get_child(i)
			line.find_node("BeforeColor", true, false).text = swap.get("before_color", "")
			line.find_node("BeforeTexture", true, false).text = swap.get("before_texture", "")
			line.find_node("AfterColor", true, false).text = swap.get("after_color", "")
			line.find_node("AfterTexture", true, false).text = swap.get("after_texture", "")
			line.find_node("ColorRampCheck", true, false).pressed = swap.get("is_ramp", false)
		else:
			var new_line = _add_swap_line()
			new_line.find_node("BeforeColor", true, false).text = swap.get("before_color", "")
			new_line.find_node("BeforeTexture", true, false).text = swap.get("before_texture", "")
			new_line.find_node("AfterColor", true, false).text = swap.get("after_color", "")
			new_line.find_node("AfterTexture", true, false).text = swap.get("after_texture", "")
			new_line.find_node("ColorRampCheck", true, false).pressed = swap.get("is_ramp", false)

	while swap_lines_container.get_child_count() > swaps.size():
		var extra = swap_lines_container.get_child(swap_lines_container.get_child_count() - 1)
		extra.find_node("BeforeColor", true, false).text = ""
		extra.find_node("BeforeTexture", true, false).text = ""
		extra.find_node("AfterColor", true, false).text = ""
		extra.find_node("AfterTexture", true, false).text = ""
		extra.find_node("ColorRampCheck", true, false).pressed = false
		extra.queue_free()

	var checks = data.get("checks", {})
	for key in checks:
		var found = false
		for cb in color_swap_check_container.get_children():
			if cb is CheckBox and cb.name == key:
				cb.pressed = checks[key]
				found = true
				break
		if not found:
			var check_container_2 = color_swap_check_container.get_parent().get_node("CheckContainer2")
			if check_container_2:
				for cb in check_container_2.get_children():
					if cb is CheckBox and cb.name == key:
						cb.pressed = checks[key]
						found = true
						break

	_refresh_all_previews()

func export_recolor_json() -> void:
	var swaps = _gather_swap_data()
	var checks = _get_check_states()
	var settings_dict: Dictionary = {
		"exporter": "LnzLive",
		"swaps": swaps,
		"checks": checks
	}
	var json_string: String = JSON.print(settings_dict, "  ")
	var filename: String = str("LnzLive_recolor_preset_", OS.get_unix_time(), ".json")
	
	if OS.has_feature("HTML5"):
		var base64_content: String = Marshalls.raw_to_base64(json_string.to_utf8())
		var js_code: String = """
		var element = document.createElement('a');
		element.setAttribute('href', 'data:application/json;base64,' + '""" + base64_content + """');
		element.setAttribute('download', '""" + filename + """');
		element.style.display = 'none';
		document.body.appendChild(element);
		element.click();
		document.body.removeChild(element);
		"""
		JavaScript.eval(js_code)
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Export Recolor Preset"
		file_dialog.mode = FileDialog.MODE_SAVE_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.current_file = filename
		file_dialog.connect("file_selected", self, "_save_recolor_file")
		file_dialog.connect("popup_hide", self, "_on_file_dialog_closed", [file_dialog])
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_ImportPresetButton_pressed() -> void:
	if OS.has_feature("HTML5"):
		var js_code: String = """
		var input = document.createElement('input');
		input.type = 'file';
		input.accept = '.json';
		input.onchange = e => { 
		   var file = e.target.files[0]; 
		   var reader = new FileReader();
		   reader.readAsText(file,'UTF-8');
		   reader.onload = readerEvent => {
			   var content = readerEvent.target.result;
			   window.godotRecolorImport(content);
		   }
		}
		input.click();
		"""
		var callback = JavaScript.create_callback(self, "_on_web_import_completed")
		JavaScript.get_interface("window").godotRecolorImport = callback
		JavaScript.eval(js_code)
	else:
		var file_dialog: FileDialog = FileDialog.new()
		file_dialog.window_title = "Import Recolor Preset"
		file_dialog.mode = FileDialog.MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.json ; JSON Preset"]
		file_dialog.rect_min_size = Vector2(400, 400)
		file_dialog.connect("file_selected", self, "_load_recolor_file")
		file_dialog.connect("popup_hide", self, "_on_file_dialog_closed", [file_dialog])
		get_tree().root.add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_web_import_completed(args: Array) -> void:
	var content: String = args[0]
	var json_res = JSON.parse(content)
	if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
		print("[STATUS] RecolorSettings: web import parsed, applying swap data")
		_apply_swap_data(json_res.result)
	else:
		print("[ERROR] RecolorSettings: web import failed to parse JSON (Error code: %d)" % json_res.error)

func _on_file_dialog_closed(dialog: FileDialog) -> void:
	if is_instance_valid(dialog):
		dialog.queue_free()

func _save_recolor_file(path: String) -> void:
	var swaps = _gather_swap_data()
	var checks = _get_check_states()
	var settings_dict: Dictionary = {
		"exporter": "LnzLive",
		"swaps": swaps,
		"checks": checks
	}
	var json_string: String = JSON.print(settings_dict, "  ")
	var file: File = File.new()
	var err = file.open(path, File.WRITE)
	if err == OK:
		file.store_string(json_string)
		file.close()
		print("[STATUS] RecolorSettings: exported to ", path)

func _load_recolor_file(path: String) -> void:
	var file: File = File.new()
	var err = file.open(path, File.READ)
	if err == OK:
		var text: String = file.get_as_text()
		file.close()
		var json_res = JSON.parse(text)
		if json_res.error == OK and typeof(json_res.result) == TYPE_DICTIONARY:
			print("[STATUS] RecolorSettings: loaded from ", path)
			_apply_swap_data(json_res.result)
		else:
			print("[ERROR] RecolorSettings: failed to parse JSON from %s (Error code: %d)" % [path, json_res.error])

func _on_AutofillSwap_pressed() -> void:
	if not is_instance_valid(lnz_text_edit): return

	var pair_counts: Dictionary = {}
	_process_section_for_autofill(lnz_text_edit, "[Ballz Info]", 0, 7, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Add Ball]", 4, 13, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Paint Ballz]", 5, 10, pair_counts)

	var global_max_count: int = 0
	for key in pair_counts:
		if pair_counts[key] > global_max_count:
			global_max_count = pair_counts[key]

	var freq_percent: int = 100
	if is_instance_valid(freq_edit) and freq_edit.text.is_valid_integer():
		freq_percent = int(freq_edit.text)
	
	freq_percent = clamp(freq_percent, 0, 100)

	var threshold: int = 0
	if global_max_count > 0:
		threshold = int(global_max_count * (freq_percent / 100.0))
	else:
		threshold = 0

	var filtered_pairs: Dictionary = {}
	for key in pair_counts:
		if threshold == 0 or pair_counts[key] >= threshold:
			filtered_pairs[key] = pair_counts[key]

	var sorted_pairs: Array = []
	for key in filtered_pairs:
		sorted_pairs.append({"key": key, "count": filtered_pairs[key]})

	sorted_pairs.sort_custom(self, "_sort_by_count")

	var needed_lines: int = sorted_pairs.size()
	if needed_lines == 0:
		needed_lines = 1
		
	var lines: Array = swap_lines_container.get_children()
	
	# Add if missing
	while lines.size() < needed_lines:
		var l: Control = _add_swap_line()
		lines.append(l)
		
	# Remove if too many
	while lines.size() > needed_lines:
		var l: Control = lines.pop_back()
		l.queue_free()

	for i in range(lines.size()):
		var line_node: Control = lines[i]
		if line_node.is_queued_for_deletion(): continue
		if i < sorted_pairs.size():
			var pair: Array = sorted_pairs[i].key.split(",")
			line_node.find_node("BeforeColor", true, false).text = pair[0]
			line_node.find_node("BeforeTexture", true, false).text = pair[1]
			line_node.find_node("AfterColor", true, false).text = ""
			line_node.find_node("AfterTexture", true, false).text = ""
		else:
			line_node.find_node("BeforeColor", true, false).text = ""
			line_node.find_node("BeforeTexture", true, false).text = ""
			line_node.find_node("AfterColor", true, false).text = ""
			line_node.find_node("AfterTexture", true, false).text = ""
		
		line_node.find_node("ColorRampCheck", true, false).pressed = false
		
	_refresh_all_previews()

func _process_section_for_autofill(lnz_text_edit: TextEdit, section_name: String, color_idx: int, texture_idx: int, pair_counts: Dictionary) -> void:
	var bounds: Dictionary = lnz_text_edit.get_section_bounds(section_name)
	if bounds.empty(): return

	for i in range(bounds.start, bounds.end):
		var line: String = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var parts: Array = lnz_text_edit.split_line(line)
		if parts.size() > max(color_idx, texture_idx):
			var color: String = parts[color_idx]
			var texture: String = parts[texture_idx]
			var key: String = color + "," + texture
			if not pair_counts.has(key): pair_counts[key] = 0
			pair_counts[key] += 1

func _sort_by_count(a: Dictionary, b: Dictionary) -> bool:
	return a.count > b.count

func _on_RandomizeSwap_pressed() -> void:
	randomize()
	if not is_instance_valid(lnz_text_edit): return

	var max_texture_id: int = -1
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Ballz Info]", 7, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Add Ball]", 13, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Paint Ballz]", 10, max_texture_id)

	if max_texture_id == -1: max_texture_id = 0

	var lines: Array = swap_lines_container.get_children()

	for l in lines:
		if l.is_queued_for_deletion(): continue
		var before_color_edit = l.find_node("BeforeColor", true, false)
		var before_texture_edit = l.find_node("BeforeTexture", true, false)
		
		var random_color: int = randi() % 256
		before_color_edit.text = str(random_color)
		
		var random_texture: int = randi() % (max_texture_id + 1)
		before_texture_edit.text = str(random_texture)

	_refresh_all_previews()

func _on_RandomizeAfter_pressed() -> void:
	randomize()
	if not is_instance_valid(lnz_text_edit): return

	var max_texture_id: int = -1
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Ballz Info]", 7, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Add Ball]", 13, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Paint Ballz]", 10, max_texture_id)

	if max_texture_id == -1: max_texture_id = 0

	var lines: Array = swap_lines_container.get_children()
	
	var theory_idx: int = 0
	if is_instance_valid(color_theory_select):
		theory_idx = color_theory_select.selected
		
	var seed_color: Color = Color.white # Default to White
	var use_random_seed: bool = false
	
	if is_instance_valid(random_seed_check):
		use_random_seed = random_seed_check.pressed
		
	if is_instance_valid(theory_seed_picker):
		# If using random seed, we ignore the picker
		if not use_random_seed:
			seed_color = theory_seed_picker.color
		else:
			var rand_idx: int = randi() % 256
			seed_color = get_color_from_index(rand_idx)
		
	var use_natural: bool = false
	if is_instance_valid(natural_colors_check):
		use_natural = natural_colors_check.pressed
		
	var use_texturable: bool = false
	if is_instance_valid(texturable_only_check):
		use_texturable = texturable_only_check.pressed

	for l in lines:
		if l.is_queued_for_deletion(): continue
		
		var after_color_edit = l.find_node("AfterColor", true, false)
		var after_texture_edit = l.find_node("AfterTexture", true, false)
		var is_ramp: bool = l.find_node("ColorRampCheck", true, false).pressed

		var random_color: int
		var base_color: Color = Color.white
		var target_color: Color = Color.white

		if use_natural:
			var idx: int = randi() % NATURAL_COLORS.size()
			random_color = NATURAL_COLORS[idx]
			
		elif use_texturable:
			var idx: int = randi() % TEXTURABLE_COLORS.size()
			random_color = TEXTURABLE_COLORS[idx]
			
		elif theory_idx > 0:
			base_color = seed_color
			
			var new_colors: Array = LnzLiveUtils.generate_theory_colors(base_color, theory_idx, 3) # Use 3 steps for theory
			
			if new_colors.size() > 0:
				var chosen_color: Color = new_colors[randi() % new_colors.size()]
				random_color = get_closest_palette_index(chosen_color)
			else:
				random_color = randi() % 256
				
		else:
			if is_ramp:
				var ramp_base: int = (randi() % 12) * 10 # 0 to 110
				ramp_base = max(ramp_base, 10) # Ensure at least 10
				random_color = ramp_base + (randi() % 10)
			else:
				random_color = randi() % 256

		if random_color >= cached_palette_colors.size():
			random_color = cached_palette_colors.size() - 1
		if random_color < 0:
			random_color = 0

		after_color_edit.text = str(random_color)

		var random_texture: int = randi() % (max_texture_id + 1)
		after_texture_edit.text = str(random_texture)

	_refresh_all_previews()

func get_closest_palette_index(target_color: Color) -> int:
	if cached_palette_colors.empty():
		return 0
	var best_index: int = 0
	var min_dist: float = INF
	for i in range(cached_palette_colors.size()):
		var c: Color = cached_palette_colors[i]
		var dist: float = pow(c.r - target_color.r, 2) + pow(c.g - target_color.g, 2) + pow(c.b - target_color.b, 2)
		if dist < min_dist:
			min_dist = dist
			best_index = i
	return best_index

func get_color_from_index(index: int) -> Color:
	if index >= 0 and index < cached_palette_colors.size():
		return cached_palette_colors[index]
	return Color.white

func _find_max_texture_for_randomize(lnz_text_edit: TextEdit, section_name: String, texture_idx: int, current_max: int) -> int:
	var bounds: Dictionary = lnz_text_edit.get_section_bounds(section_name)
	if bounds.empty(): return current_max

	var new_max: int = current_max
	for i in range(bounds.start, bounds.end):
		var line: String = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"): continue

		var parts: Array = lnz_text_edit.split_line(line)
		if parts.size() > texture_idx:
			var texture_str: String = parts[texture_idx]
			if texture_str.is_valid_integer():
				var texture_id: int = int(texture_str)
				if texture_id > new_max:
						new_max = texture_id
	return new_max

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("[WARNING] RecolorSettings: error loading existing settings config for save: ", err)
		return

	if is_instance_valid(nose_ballz_check):
		config.set_value(RECOLOR_SECTION, "nose_ballz", nose_ballz_check.pressed)

	var check_container = color_swap_check_container
	var checks: Dictionary = {}
	for cb in check_container.get_children():
		if cb is CheckBox:
			checks[cb.name] = cb.pressed
	var check_container_2 = check_container.get_parent().get_node("CheckContainer2")
	if check_container_2:
		for cb in check_container_2.get_children():
			if cb is CheckBox:
				checks[cb.name] = cb.pressed
	config.set_value(RECOLOR_SECTION, "checks", checks)

	var swaps = _gather_swap_data()
	config.set_value(RECOLOR_SECTION, "swaps", swaps)

	save_eye_colors_settings(config)

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("[ERROR] RecolorSettings: failed to save config to %s (Error: %s)" % [SETTINGS_PATH, save_err])

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		print("[WARNING] RecolorSettings: could not load config from %s, using defaults (Error: %d)" % [SETTINGS_PATH, err])
		return

	print("[STATUS] RecolorSettings: loading settings configuration")
	_is_loading_settings = true

	load_eye_colors_settings(config)

	if is_instance_valid(nose_ballz_check):
		nose_ballz_check.pressed = config.get_value(RECOLOR_SECTION, "nose_ballz", true)

	var checks = config.get_value(RECOLOR_SECTION, "checks", {})
	for key in checks:
		var found = false
		for cb in color_swap_check_container.get_children():
			if cb is CheckBox and cb.name == key:
				cb.pressed = checks[key]
				found = true
				break
		if not found:
			var check_container_2 = color_swap_check_container.get_parent().get_node("CheckContainer2")
			if check_container_2:
				for cb in check_container_2.get_children():
					if cb is CheckBox and cb.name == key:
						cb.pressed = checks[key]
						found = true
						break

	var swaps = config.get_value(RECOLOR_SECTION, "swaps", [])
	for i in range(swaps.size()):
		var swap = swaps[i]
		if i < swap_lines_container.get_child_count():
			var line = swap_lines_container.get_child(i)
			line.find_node("BeforeColor", true, false).text = swap.get("before_color", "")
			line.find_node("BeforeTexture", true, false).text = swap.get("before_texture", "")
			line.find_node("AfterColor", true, false).text = swap.get("after_color", "")
			line.find_node("AfterTexture", true, false).text = swap.get("after_texture", "")
			line.find_node("ColorRampCheck", true, false).pressed = swap.get("is_ramp", false)
		else:
			var new_line = _add_swap_line()
			new_line.find_node("BeforeColor", true, false).text = swap.get("before_color", "")
			new_line.find_node("BeforeTexture", true, false).text = swap.get("before_texture", "")
			new_line.find_node("AfterColor", true, false).text = swap.get("after_color", "")
			new_line.find_node("AfterTexture", true, false).text = swap.get("after_texture", "")
			new_line.find_node("ColorRampCheck", true, false).pressed = swap.get("is_ramp", false)

	_is_loading_settings = false
	_refresh_all_previews()

func _setup_eye_colors() -> void:
	if is_instance_valid(all_check):
		all_check.connect("toggled", self, "_on_all_toggled")
	if is_instance_valid(lid_check):
		lid_check.connect("toggled", self, "_on_lid_toggled")
	if is_instance_valid(odd_check):
		odd_check.connect("toggled", self, "_on_odd_toggled")
	if is_instance_valid(firefly_check):
		firefly_check.connect("toggled", self, "_on_firefly_toggled")
	if is_instance_valid(randomize_eye_btn):
		randomize_eye_btn.connect("pressed", self, "_on_RandomizeEye_pressed")
	if is_instance_valid(apply_eye_colors_btn):
		apply_eye_colors_btn.connect("pressed", self, "_on_ApplyEyeColors_pressed")
	
	var line_edits = [eye_outline_left_edit, eye_outline_right_edit, eyelid_edit, iris_outline_left_edit, iris_outline_right_edit, iris_col_left_edit, iris_col_right_edit, eye_col_left_edit, eye_col_right_edit]
	for le in line_edits:
		if is_instance_valid(le) and not le.is_connected("text_changed", self, "_on_eye_color_text_changed"):
			le.connect("text_changed", self, "_on_eye_color_text_changed")
	
	_refresh_eye_preview()


func _on_eye_color_text_changed(new_text: String) -> void:
	_refresh_eye_preview()


func _refresh_eye_preview() -> void:
	if not is_instance_valid(eye_preview_canvas):
		return
	if not is_instance_valid(eye_outline_left_edit):
		return
		
	eye_preview_canvas.eye_outline_left = _get_eye_color(eye_outline_left_edit.text) if eye_outline_left_edit.text != "" else Color(0.0, 0.0, 0.0, 1.0)
	eye_preview_canvas.eye_outline_right = _get_eye_color(eye_outline_right_edit.text) if eye_outline_right_edit.text != "" else Color(0.0, 0.0, 0.0, 1.0)
	eye_preview_canvas.eyelid_color = _get_eye_color(eyelid_edit.text) if eyelid_edit.text != "" else Color(0.0, 0.0, 0.0, 1.0)
	
	eye_preview_canvas.iris_outline_left = _get_eye_color(iris_outline_left_edit.text) if iris_outline_left_edit.text != "" else Color(1.0, 0.5, 1.0, 1.0)
	eye_preview_canvas.iris_outline_right = _get_eye_color(iris_outline_right_edit.text) if iris_outline_right_edit.text != "" else Color(1.0, 0.5, 1.0, 1.0)
	
	eye_preview_canvas.iris_color_left = _get_eye_color(iris_col_left_edit.text) if iris_col_left_edit.text != "" else Color(0.0, 0.0, 0.0, 1.0)
	eye_preview_canvas.iris_color_right = _get_eye_color(iris_col_right_edit.text) if iris_col_right_edit.text != "" else Color(0.0, 0.0, 0.0, 1.0)
	
	eye_preview_canvas.eye_color_left = _get_eye_color(eye_col_left_edit.text) if eye_col_left_edit.text != "" else Color(1.0, 1.0, 1.0, 1.0)
	eye_preview_canvas.eye_color_right = _get_eye_color(eye_col_right_edit.text) if eye_col_right_edit.text != "" else Color(1.0, 1.0, 1.0, 1.0)
	
	eye_preview_canvas.update()


func _get_eye_color(index_str: String) -> Color:
	if not index_str.is_valid_integer():
		return Color.white
	var idx: int = int(index_str)
	if idx >= 0 and idx < cached_palette_colors.size():
		return cached_palette_colors[idx]
	return Color.white

func _get_head_ball_color() -> Color:
	if not dog_generator:
		return Color.white
	var species = dog_generator.species if dog_generator.has_method("get_species") else KeyBallsData.species
	var head_balls = KeyBallsData.get_head_ext(species)
	if head_balls.empty():
		return Color.white
	var head_ball_no = head_balls[0]
	
	if not is_instance_valid(lnz_text_edit):
		return Color.white
	
	var bounds = lnz_text_edit.get_section_bounds("[Ballz Info]")
	if bounds.empty():
		return Color.white
	
	var current_ball_no = 0
	
	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue
			
		if current_ball_no == head_ball_no:
			var parts = lnz_text_edit.split_line(line)
			# parts[0] is the color index
			if parts.size() > 0 and parts[0].is_valid_integer():
				var idx = int(parts[0])
				if idx >= 0 and idx < cached_palette_colors.size():
					return cached_palette_colors[idx]
			return Color.white
			
		current_ball_no += 1
		
	return Color.white

func _on_all_toggled(is_on: bool) -> void:
	_eye_all = is_on
	save_settings()

func _on_lid_toggled(is_on: bool) -> void:
	_eye_lid = is_on
	save_settings()

func _on_odd_toggled(is_on: bool) -> void:
	_eye_odd = is_on
	save_settings()

func _on_firefly_toggled(is_on: bool) -> void:
	_eye_firefly = is_on
	save_settings()


func _on_RandomizeEye_pressed() -> void:
	randomize()
	if not dog_generator or not dog_generator.current_palette_texture:
		return
	
	var head_color = _get_head_ball_color()
	
	var iris_out_left = randi() % cached_palette_colors.size()
	var iris_out_right = iris_out_left
	
	if _eye_odd:
		iris_out_right = randi() % cached_palette_colors.size()
		
	iris_outline_left_edit.text = str(iris_out_left)
	iris_outline_right_edit.text = str(iris_out_right)
	
	eyelid_edit.text = ""
	eye_outline_left_edit.text = ""
	eye_outline_right_edit.text = ""
	eye_col_left_edit.text = ""
	eye_col_right_edit.text = ""
	iris_col_left_edit.text = ""
	iris_col_right_edit.text = ""
	
	if _eye_firefly:
		var darken_left = rand_range(0.25, 0.75)
		var target_iris_left = LnzLiveUtils.darken_color(_get_eye_color(iris_outline_left_edit.text), darken_left)
		iris_col_left_edit.text = str(get_closest_palette_index(target_iris_left))
		
		if _eye_odd:
			var darken_right = rand_range(0.25, 0.75)
			var target_iris_right = LnzLiveUtils.darken_color(_get_eye_color(iris_outline_right_edit.text), darken_right)
			iris_col_right_edit.text = str(get_closest_palette_index(target_iris_right))
		else:
			iris_col_right_edit.text = iris_col_left_edit.text

	if _eye_lid:
		var target_dark = LnzLiveUtils.darken_color(head_color, 0.75)
		var dark_idx = get_closest_palette_index(target_dark)
		
		eyelid_edit.text = str(dark_idx)
		eye_outline_left_edit.text = str(dark_idx)
		eye_outline_right_edit.text = str(dark_idx)
		
	if _eye_all:
		var theories = [1, 2, 3, 4, 5] # Exclude 0 (Off)
		
		var ref_left = _get_eye_color(iris_col_left_edit.text) if iris_col_left_edit.text != "" else _get_eye_color(iris_outline_left_edit.text)
		var theory_left = theories[randi() % theories.size()]
		var generated_left = LnzLiveUtils.generate_theory_colors(ref_left, theory_left, 3)
		var chosen_left = generated_left[randi() % generated_left.size()]
		
		var iris_out_color_left = _get_eye_color(iris_outline_left_edit.text)
		var min_v_left = min(iris_out_color_left.v + 0.25, 1.0)
		var eye_col_target_left = Color.from_hsv(chosen_left.h, chosen_left.s, rand_range(min_v_left, 1.0))
		eye_col_left_edit.text = str(get_closest_palette_index(eye_col_target_left))
		
		if _eye_odd:
			var ref_right = _get_eye_color(iris_col_right_edit.text) if iris_col_right_edit.text != "" else _get_eye_color(iris_outline_right_edit.text)
			var theory_right = theories[randi() % theories.size()]
			var generated_right = LnzLiveUtils.generate_theory_colors(ref_right, theory_right, 3)
			var chosen_right = generated_right[randi() % generated_right.size()]
			
			var iris_out_color_right = _get_eye_color(iris_outline_right_edit.text)
			var min_v_right = min(iris_out_color_right.v + 0.25, 1.0)
			var eye_col_target_right = Color.from_hsv(chosen_right.h, chosen_right.s, rand_range(min_v_right, 1.0))
			eye_col_right_edit.text = str(get_closest_palette_index(eye_col_target_right))
		else:
			eye_col_right_edit.text = eye_col_left_edit.text
			
	_refresh_eye_preview()

func _on_ApplyEyeColors_pressed() -> void:
	if not is_instance_valid(lnz_text_edit):
		return
	
	var eye_colors_info = {
		"eye_outline_left": eye_outline_left_edit.text,
		"eye_outline_right": eye_outline_right_edit.text,
		"eyelid_color_index": eyelid_edit.text,
		"iris_outline_left": iris_outline_left_edit.text,
		"iris_outline_right": iris_outline_right_edit.text,
		"iris_color_left": iris_col_left_edit.text,
		"iris_color_right": iris_col_right_edit.text,
		"eye_color_left": eye_col_left_edit.text,
		"eye_color_right": eye_col_right_edit.text
	}
	
	_write_eye_colors_to_lnz(eye_colors_info)
	
	emit_signal("apply_eye_colors", eye_colors_info)
	
	print("[STATUS] RecolorSettings: Eye colors applied: ", eye_colors_info)


func _write_eye_colors_to_lnz(info: Dictionary) -> void:
	if not is_instance_valid(lnz_text_edit):
		return
	
	if info.has("eyelid_color_index") and info.eyelid_color_index != "":
		var bounds = lnz_text_edit.get_section_bounds("[256 Eyelid Color]")
		if not bounds.empty():
			var start_line = bounds.start
			var current_line = lnz_text_edit.get_line(start_line).strip_edges()
			var parts = lnz_text_edit.split_line(current_line)
			if parts.size() > 0:
				parts[0] = info.eyelid_color_index
			lnz_text_edit.set_line(start_line, lnz_text_edit._join_array(parts, " "))
	
	var ballz_bounds = lnz_text_edit.get_section_bounds("[Ballz Info]")
	if ballz_bounds.empty():
		return
	
	var eye_balls = KeyBallsData.get_eyes(KeyBallsData.species)
	if eye_balls.empty():
		return
		
	var irises = eye_balls.keys()
	irises.sort() 
	var left_iris = irises[0]
	var right_iris = irises[1]
	
	var left_eye = eye_balls[left_iris]
	var right_eye = eye_balls[right_iris]
	
	var current_ball_no = 0
	
	for i in range(ballz_bounds.start, ballz_bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue
			
		var parts = lnz_text_edit.split_line(line)
		if parts.size() < 2:
			current_ball_no += 1
			continue
		
		var changed = false
		var apply_texture = false
		
		if current_ball_no == left_eye:
			if info.has("eye_color_left") and info.eye_color_left != "":
				parts[0] = info.eye_color_left
				changed = true
			if info.has("eye_outline_left") and info.eye_outline_left != "":
				parts[1] = info.eye_outline_left
				changed = true
			apply_texture = true
				
		elif current_ball_no == right_eye:
			if info.has("eye_color_right") and info.eye_color_right != "":
				parts[0] = info.eye_color_right
				changed = true
			if info.has("eye_outline_right") and info.eye_outline_right != "":
				parts[1] = info.eye_outline_right
				changed = true
			apply_texture = true
				
		elif current_ball_no == left_iris:
			if info.has("iris_color_left") and info.iris_color_left != "":
				parts[0] = info.iris_color_left
				changed = true
			if info.has("iris_outline_left") and info.iris_outline_left != "":
				parts[1] = info.iris_outline_left
				changed = true
			apply_texture = true
				
		elif current_ball_no == right_iris:
			if info.has("iris_color_right") and info.iris_color_right != "":
				parts[0] = info.iris_color_right
				changed = true
			if info.has("iris_outline_right") and info.iris_outline_right != "":
				parts[1] = info.iris_outline_right
				changed = true
			apply_texture = true
			
		if apply_texture:
			while parts.size() <= 7:
				parts.append("0")
			if parts[7] != "-1":
				parts[7] = "-1"
				changed = true
				
		if changed:
			lnz_text_edit.set_line(i, lnz_text_edit._join_array(parts, " "))
			
		current_ball_no += 1
	
	lnz_text_edit.save_file(true)
	lnz_text_edit.commit_full_snapshot("Eye Colors Apply")

func save_eye_colors_settings(config: ConfigFile) -> void:
	config.set_value(RECOLOR_SECTION, "eye_outline_left", int(eye_outline_left_edit.text) if eye_outline_left_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "eye_outline_right", int(eye_outline_right_edit.text) if eye_outline_right_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "eyelid_color_index", int(eyelid_edit.text) if eyelid_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "iris_outline_left", int(iris_outline_left_edit.text) if iris_outline_left_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "iris_outline_right", int(iris_outline_right_edit.text) if iris_outline_right_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "iris_color_left", int(iris_col_left_edit.text) if iris_col_left_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "iris_color_right", int(iris_col_right_edit.text) if iris_col_right_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "eye_color_left", int(eye_col_left_edit.text) if eye_col_left_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "eye_color_right", int(eye_col_right_edit.text) if eye_col_right_edit.text.is_valid_integer() else -1)
	config.set_value(RECOLOR_SECTION, "eye_all", _eye_all)
	config.set_value(RECOLOR_SECTION, "eye_lid", _eye_lid)
	config.set_value(RECOLOR_SECTION, "eye_odd", _eye_odd)
	config.set_value(RECOLOR_SECTION, "eye_firefly", _eye_firefly)


func load_eye_colors_settings(config: ConfigFile) -> void:
	if _is_loading_settings:
		return
	
	var eye_outline_left = config.get_value(RECOLOR_SECTION, "eye_outline_left", -1)
	var eye_outline_right = config.get_value(RECOLOR_SECTION, "eye_outline_right", -1)
	var eyelid_idx = config.get_value(RECOLOR_SECTION, "eyelid_color_index", -1)
	var iris_outline_left = config.get_value(RECOLOR_SECTION, "iris_outline_left", -1)
	var iris_outline_right = config.get_value(RECOLOR_SECTION, "iris_outline_right", -1)
	var iris_left_idx = config.get_value(RECOLOR_SECTION, "iris_color_left", -1)
	var iris_right_idx = config.get_value(RECOLOR_SECTION, "iris_color_right", -1)
	var eye_left_idx = config.get_value(RECOLOR_SECTION, "eye_color_left", -1)
	var eye_right_idx = config.get_value(RECOLOR_SECTION, "eye_color_right", -1)
	
	if eye_outline_left >= 0:
		eye_outline_left_edit.text = str(eye_outline_left)
	if eye_outline_right >= 0:
		eye_outline_right_edit.text = str(eye_outline_right)
	if eyelid_idx >= 0:
		eyelid_edit.text = str(eyelid_idx)
	if iris_outline_left >= 0:
		iris_outline_left_edit.text = str(iris_outline_left)
	if iris_outline_right >= 0:
		iris_outline_right_edit.text = str(iris_outline_right)
	if iris_left_idx >= 0:
		iris_col_left_edit.text = str(iris_left_idx)
	if iris_right_idx >= 0:
		iris_col_right_edit.text = str(iris_right_idx)
	if eye_left_idx >= 0:
		eye_col_left_edit.text = str(eye_left_idx)
	if eye_right_idx >= 0:
		eye_col_right_edit.text = str(eye_right_idx)
	
	_eye_all = config.get_value(RECOLOR_SECTION, "eye_all", false)
	_eye_lid = config.get_value(RECOLOR_SECTION, "eye_lid", false)
	_eye_odd = config.get_value(RECOLOR_SECTION, "eye_odd", false)
	_eye_firefly = config.get_value(RECOLOR_SECTION, "eye_firefly", false)
	
	if is_instance_valid(all_check):
		all_check.pressed = _eye_all
	if is_instance_valid(lid_check):
		lid_check.pressed = _eye_lid
	if is_instance_valid(odd_check):
		odd_check.pressed = _eye_odd
	if is_instance_valid(firefly_check):
		firefly_check.pressed = _eye_firefly
	
	_refresh_eye_preview()
