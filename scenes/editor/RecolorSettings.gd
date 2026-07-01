extends Control

signal recolor(recolor_info)
signal apply_bucket(ball_no, properties)
signal apply_batch_bucket(changes)

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

var recolor_line_scene: PackedScene = preload("res://scenes/editor/RecolorLine.tscn")
var queued_bucket_changes: Dictionary = {} # ball_no -> properties

var dog_generator: Node = null
var cached_palette_colors: Array = []

onready var lnz_text_edit: TextEdit = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit"
)

var is_docked: bool = false

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
	
	_populate_color_theory_options()
		
	_on_palette_changed()

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
	
	_setup_preview_wrapper(before_color, "BeforeColor_" + str(id))
	_setup_preview_wrapper(after_color, "AfterColor_" + str(id))
	
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

func _setup_preview_wrapper(le, le_name: String) -> void:
	if not le: return
	var parent: Node = le.get_parent()

	var hbox = HBoxContainer.new()
	hbox.name = le_name + "Wrapper"
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pos: int = le.get_index()
	var orig_owner: Node = le.owner
	
	parent.remove_child(le)
	parent.add_child(hbox)
	
	if orig_owner != null:
		hbox.owner = orig_owner
	
	parent.move_child(hbox, pos)

	hbox.add_child(le)
	if orig_owner != null:
		le.owner = orig_owner
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var preview_container = HBoxContainer.new()
	preview_container.name = le_name + "_Preview"
	hbox.add_child(preview_container)
	if orig_owner != null:
		preview_container.owner = orig_owner

	if not le.is_connected("text_changed", self, "_on_color_list_text_changed"):
		le.connect("text_changed", self, "_on_color_list_text_changed", [preview_container])

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

	recolor_info.balls_on = balls_on
	recolor_info.ball_outlines_on = ball_outlines_on
	recolor_info.paintballs_on = paintballs_on
	recolor_info.lines_on = lines_on
	recolor_info.polygons_on = polygons_on

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
		"swaps": swaps,
		"checks": checks
	}
	var json_string: String = JSON.print(settings_dict, "  ")
	var filename: String = "LnzLive_recolor_settings_" + str(OS.get_unix_time()) + ".json"
	
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
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
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
		file_dialog.connect("popup_hide", file_dialog, "queue_free")
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

func _save_recolor_file(path: String) -> void:
	var swaps = _gather_swap_data()
	var checks = _get_check_states()
	var settings_dict: Dictionary = {
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
