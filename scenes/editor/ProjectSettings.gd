extends DraggablePanel
## ProjectSettings.gd
## Manages the UI panel and logic for the Project Mode settings and Shape Mode
## This script combines three key LNZ editing features:
## 1. Project Ball Randomizer
##     Controls a Tree UI for creating and editing `[Project Ball]`. It provides methods to:
##         - Load: Copy existing projections from the LNZ or load defaults based on species
##         - Edit: Add, remove, reorder, lock, and edit projection values (Fixed/Project Ball, Min/Max/Value)
##         - Randomize: Generate random projection values within the defined Min/Max range, respecting locked or mirrored projections
##         - Apply: Gather all projections (and auto-generate symmetrical mirrors if needed) and emit the `apply_projections` signal
## 2. Body Proportion Randomizer
##     Manages UI spinboxes for defining Min/Max ranges for LNZ body proportion sections (e.g., `[Leg Extension]`, `[Head Enlargement]`)
##     and emits the `randomize_body_proportions` signal to apply random values within those ranges
## 3. Move Randomizer
##    Offers two methods for randomizing `[Move]` entries of base ballz by body group:
##        - randomly sample in defined box coordinates around base position
##        - jitter in radius around ball

signal apply_projections(projections)
signal randomize_body_proportions(settings)
signal randomize_moves(settings)

var _is_loading_settings: bool = false

onready var projections_tree: Tree = find_node("ProjectionsTree")

func _ready() -> void:
	# Connect signals
	find_node("AddButton").connect("pressed", self, "_on_AddButton_pressed")
	find_node("RemoveButton").connect("pressed", self, "_on_RemoveButton_pressed")
	find_node("ClearAllButton").connect("pressed", self, "_on_ClearAllButton_pressed")
	find_node("RestoreDefaultsButton").connect("pressed", self, "_on_RestoreDefaultsButton_pressed")
	find_node("CopyFromLNZButton").connect("pressed", self, "_on_CopyFromLNZButton_pressed")
	find_node("RandomizeProjectionsButton").connect("pressed", self, "_on_RandomizeProjectionsButton_pressed")
	find_node("ApplyButton").connect("pressed", self, "_on_ApplyButton_pressed")
	find_node("MoveUpButton").connect("pressed", self, "_on_MoveUpButton_pressed")
	find_node("MoveDownButton").connect("pressed", self, "_on_MoveDownButton_pressed")
	
	find_node("RandomizeBodyButton").connect("pressed", self, "_on_RandomizeBodyButton_pressed")
	find_node("RandomizeMovesButton").connect("pressed", self, "_on_RandomizeMovesButton_pressed")
	find_node("JitterButton").connect("pressed", self, "_on_JitterButton_pressed")
	find_node("RandomizeShapeButton").connect("pressed", self, "_on_RandomizeShapeButton_pressed")

	projections_tree.connect("item_edited", self, "_on_ProjectionsTree_item_edited")
	projections_tree.connect("button_pressed", self, "_on_ProjectionsTree_button_pressed")
	projections_tree.connect("column_title_pressed", self, "_on_ProjectionsTree_column_title_pressed")

	# Setup Tree
	projections_tree.set_column_titles_visible(true)
	projections_tree.set_column_title(0, "Fixed")
	projections_tree.set_column_title(1, "Project")
	projections_tree.set_column_title(2, "Min")
	projections_tree.set_column_title(3, "Max")
	projections_tree.set_column_title(4, "Value")
	projections_tree.set_column_title(5, "Lock")
	projections_tree.set_column_title(6, "Mirror")
	projections_tree.set_column_title(7, "Label")
	projections_tree.set_column_title(8, "")

	# Hide by default
	hide()

	var viewport_size: Vector2 = get_viewport().size
	var panel_size: Vector2 = self.rect_size
	
	var default_x: float = (viewport_size.x - panel_size.x) / 2
	var default_y: float = viewport_size.y - panel_size.y - 10
	var default_pos: Vector2 = Vector2(default_x, default_y)
	
	self.restore_position(default_pos)

	_connect_settings_signals()
	load_settings()

func _populate_projections_tree() -> void:
	projections_tree.clear()
	var root: TreeItem = projections_tree.create_item()

	var species_key: String = KeyBallsData.get_projection_key(KeyBallsData.species)

	if KeyBallsData.projection_standards.has(species_key):
		var standards: Array = KeyBallsData.projection_standards[species_key]
		for proj_data in standards:
			var item: TreeItem = projections_tree.create_item(root)
			item.set_editable(0, true)
			item.set_editable(1, true)
			item.set_editable(2, true)
			item.set_editable(3, true)
			item.set_editable(4, true)
			item.set_cell_mode(5, TreeItem.CELL_MODE_CHECK)
			item.set_editable(5, true)
			item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
			item.set_editable(6, true)
			item.set_editable(7, true)

			item.set_text(0, str(proj_data.fixed_ball))
			item.set_text(1, str(proj_data.project_ball))
			item.set_text(2, str(proj_data.min_projection))
			item.set_text(3, str(proj_data.max_projection))
			item.set_text(4, "0")
			item.set_checked(5, false)
			item.set_checked(6, false)
			item.set_text(7, proj_data.comment)

func _on_AddButton_pressed() -> void:
	var root: TreeItem = projections_tree.get_root()
	if not root:
		root = projections_tree.create_item()
	var item: TreeItem = projections_tree.create_item(root)
	item.set_editable(0, true)
	item.set_editable(1, true)
	item.set_editable(2, true)
	item.set_editable(3, true)
	item.set_editable(4, true)
	item.set_cell_mode(5, TreeItem.CELL_MODE_CHECK)
	item.set_editable(5, true)
	item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
	item.set_editable(6, true)
	item.set_editable(7, true)

	item.set_text(0, "0")
	item.set_text(1, "0")
	item.set_text(2, "0")
	item.set_text(3, "100")
	item.set_text(4, "0")
	item.set_checked(5, false)
	item.set_checked(6, false)
	item.set_text(7, "comment")

func _on_RemoveButton_pressed() -> void:
	var selected: TreeItem = projections_tree.get_selected()
	if selected:
		selected.free()

func _swap_tree_items(item1: TreeItem, item2: TreeItem) -> void:
	for i in range(projections_tree.columns):
		var text1: String = item1.get_text(i)
		var text2: String = item2.get_text(i)
		item1.set_text(i, text2)
		item2.set_text(i, text1)

		if item1.get_cell_mode(i) == TreeItem.CELL_MODE_CHECK:
			var checked1: bool = item1.is_checked(i)
			var checked2: bool = item2.is_checked(i)
			item1.set_checked(i, checked2)
			item2.set_checked(i, checked1)

func _on_MoveUpButton_pressed() -> void:
	var selected: TreeItem = projections_tree.get_selected()
	if selected and selected.get_prev():
		_swap_tree_items(selected, selected.get_prev())
		projections_tree.select(selected.get_prev(), 0)

func _on_MoveDownButton_pressed() -> void:
	var selected: TreeItem = projections_tree.get_selected()
	if selected and selected.get_next():
		_swap_tree_items(selected, selected.get_next())
		projections_tree.select(selected.get_next(), 0)

func _on_ClearAllButton_pressed() -> void:
	projections_tree.clear()
	projections_tree.create_item() # Create root

func _on_RestoreDefaultsButton_pressed() -> void:
	_populate_projections_tree()

func _on_CopyFromLNZButton_pressed() -> void:
	var lnz_text_edit: TextEdit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	var projections: Array = lnz_text_edit.get_project_ball_section()

	projections_tree.clear()
	var root: TreeItem = projections_tree.create_item()

	for proj_data in projections:
		var item: TreeItem = projections_tree.create_item(root)
		item.set_editable(0, true)
		item.set_editable(1, true)
		item.set_editable(2, true)
		item.set_editable(3, true)
		item.set_editable(4, true)
		item.set_cell_mode(5, TreeItem.CELL_MODE_CHECK)
		item.set_editable(5, true)
		item.set_cell_mode(6, TreeItem.CELL_MODE_CHECK)
		item.set_editable(6, true)
		item.set_editable(7, true)

		item.set_text(0, str(proj_data.fixed_ball))
		item.set_text(1, str(proj_data.project_ball))
		item.set_text(2, str(proj_data.min_projection))
		item.set_text(3, str(proj_data.max_projection))
		item.set_text(4, str( (proj_data.min_projection + proj_data.max_projection) / 2) )
		item.set_checked(5, false)
		item.set_checked(6, false)
		item.set_text(7, proj_data.comment)


func _on_ProjectionsTree_button_pressed(item: TreeItem, column: int, id: int) -> void:
	if column == 8: # Delete button
		item.free()

func _on_ProjectionsTree_item_edited() -> void:
	# This is mainly to handle the checkbox
	var item: TreeItem = projections_tree.get_edited()
	var column: int = projections_tree.get_edited_column()
	if column == 5 or column == 6: # Lock or Mirrored checkbox
		# The checked state is automatically updated by the tree
		pass

func _on_RandomizeProjectionsButton_pressed() -> void:
	randomize()
	var root: TreeItem = projections_tree.get_root()
	if not root:
		return

	var symmetry_dict: Dictionary = KeyBallsData.get_symmetry_dict(KeyBallsData.species)

	var processed_items: Array = []
	var all_items: Array = []
	var item: TreeItem = root.get_children()
	while item:
		all_items.append(item)
		item = item.get_next()

	for item_a in all_items:
		if item_a in processed_items:
			continue

		if not item_a.is_checked(5): # if not locked
			var min_proj: int = item_a.get_text(2).to_int()
			var max_proj: int = item_a.get_text(3).to_int()
			var random_val: int = 0
			if min_proj < max_proj:
				random_val = randi() % (max_proj - min_proj + 1) + min_proj
			else:
				random_val = min_proj
			item_a.set_text(4, str(random_val))

		processed_items.append(item_a)

		if not symmetry_dict:
			continue

		# Find and update the mirror
		var fixed_a: int = item_a.get_text(0).to_int()
		var proj_a: int = item_a.get_text(1).to_int()

		var mirrored_fixed: int = KeyBallsData.get_mirrored_ball(fixed_a, symmetry_dict)
		var mirrored_proj: int = KeyBallsData.get_mirrored_ball(proj_a, symmetry_dict)

		if mirrored_fixed == -1: mirrored_fixed = fixed_a
		if mirrored_proj == -1: mirrored_proj = proj_a

		for item_b in all_items:
			if item_b in processed_items:
				continue

			var fixed_b: int = item_b.get_text(0).to_int()
			var proj_b: int = item_b.get_text(1).to_int()

			var is_mirror: bool = (fixed_b == mirrored_fixed and proj_b == mirrored_proj)
			var is_swapped_mirror: bool = (fixed_b == mirrored_proj and proj_b == mirrored_fixed)

			if is_mirror or is_swapped_mirror:
				if not item_b.is_checked(5): # if not locked
					item_b.set_text(4, item_a.get_text(4))
				processed_items.append(item_b)
				break

func _on_RandomizeBodyButton_pressed() -> void:
	var settings: Dictionary = {
		"leg_ext_1": { "min": find_node("LegExt1MinSpinBox").value, "max": find_node("LegExt1MaxSpinBox").value },
		"leg_ext_2": { "min": find_node("LegExt2MinSpinBox").value, "max": find_node("LegExt2MaxSpinBox").value },
		"head_enl_1": { "min": find_node("HeadEnl1MinSpinBox").value, "max": find_node("HeadEnl1MaxSpinBox").value },
		"head_enl_2": { "min": find_node("HeadEnl2MinSpinBox").value, "max": find_node("HeadEnl2MaxSpinBox").value },
		"feet_enl_1": { "min": find_node("FeetEnl1MinSpinBox").value, "max": find_node("FeetEnl1MaxSpinBox").value },
		"feet_enl_2": { "min": find_node("FeetEnl2MinSpinBox").value, "max": find_node("FeetEnl2MaxSpinBox").value },
		"scales_1": { "min": find_node("Scales1MinSpinBox").value, "max": find_node("Scales1MaxSpinBox").value },
		"scales_2": { "min": find_node("Scales2MinSpinBox").value, "max": find_node("Scales2MaxSpinBox").value },
		"body_ext": { "min": find_node("BodyExtMinSpinBox").value, "max": find_node("BodyExtMaxSpinBox").value },
		"face_ext": { "min": find_node("FaceExtMinSpinBox").value, "max": find_node("FaceExtMaxSpinBox").value },
		"ear_ext": { "min": find_node("EarExtMinSpinBox").value, "max": find_node("EarExtMaxSpinBox").value }
	}
	emit_signal("randomize_body_proportions", settings)

func _get_move_settings_dict(type: String) -> Dictionary:
	var groups: Array = []
	if find_node("HeadCheckBox").pressed: groups.append("Head")
	if find_node("BodyCheckBox").pressed: groups.append("Body")
	if find_node("LegsCheckBox").pressed: groups.append("Legs")
	if find_node("TailCheckBox").pressed: groups.append("Tail")
	if find_node("EarsCheckBox").pressed: groups.append("Ears")
	if find_node("EyesCheckBox").pressed: groups.append("Eyes")
	
	var settings: Dictionary = {
		"type": type,
		"groups": groups,
		"mirror_x": find_node("MirrorXCheckBox").pressed,
		"range_min": Vector3(find_node("MoveXMin").value, find_node("MoveYMin").value, find_node("MoveZMin").value),
		"range_max": Vector3(find_node("MoveXMax").value, find_node("MoveYMax").value, find_node("MoveZMax").value),
		"jitter_radius": find_node("JitterRadius").value
	}
	return settings

func _on_RandomizeMovesButton_pressed() -> void:
	var settings: Dictionary = _get_move_settings_dict("range")
	emit_signal("randomize_moves", settings)

func _on_JitterButton_pressed() -> void:
	var settings: Dictionary = _get_move_settings_dict("jitter")
	emit_signal("randomize_moves", settings)

func _on_RandomizeShapeButton_pressed() -> void:
	if find_node("IncludeProjCheckBox").pressed:
		_on_RandomizeProjectionsButton_pressed()
		_on_ApplyButton_pressed()
		
	if find_node("IncludeBodyCheckBox").pressed:
		_on_RandomizeBodyButton_pressed()
		
	if find_node("IncludeMovesCheckBox").pressed:
		_on_RandomizeMovesButton_pressed()

func _on_ApplyButton_pressed() -> void:
	var root: TreeItem = projections_tree.get_root()
	if not root:
		return

	var symmetry_dict: Dictionary = KeyBallsData.get_symmetry_dict(KeyBallsData.species)

	var lnz_projections: Array = []
	
	# Scan to see which projections already exist
	var existing_pairs: Dictionary = {}
	var item: TreeItem = root.get_children()
	while item:
		var fixed: int = item.get_text(0).to_int()
		var project: int = item.get_text(1).to_int()
		var key: Vector2 = Vector2(min(fixed, project), max(fixed, project))
		existing_pairs[key] = true
		item = item.get_next()

	# Build list of projections
	item = root.get_children()
	while item:
		var fixed_ball: int = item.get_text(0).to_int()
		var project_ball: int = item.get_text(1).to_int()
		
		var proj: Dictionary = {
			"fixed_ball": fixed_ball,
			"project_ball": project_ball,
			"value": item.get_text(4).to_int(),
			"comment": item.get_text(7)
		}
		lnz_projections.append(proj)

		# If mirrored, create the mirrored version and add ONLY if it doesn't already exist as a separate entry
		if item.is_checked(6) and symmetry_dict:
			var mirrored_fixed_raw: int = KeyBallsData.get_mirrored_ball(proj.fixed_ball, symmetry_dict)
			var mirrored_project_raw: int = KeyBallsData.get_mirrored_ball(proj.project_ball, symmetry_dict)

			# If a ball doesn't have a mirror, it mirrors to itself
			var mirrored_fixed: int = mirrored_fixed_raw if mirrored_fixed_raw != -1 else proj.fixed_ball
			var mirrored_project: int = mirrored_project_raw if mirrored_project_raw != -1 else proj.project_ball
			
			# Check if the mirrored pair is the same as the original
			var is_self_mirrored: bool = (mirrored_fixed == proj.fixed_ball) and (mirrored_project == proj.project_ball)
			
			if not is_self_mirrored:
				var mirror_key: Vector2 = Vector2(min(mirrored_fixed, mirrored_project), max(mirrored_fixed, mirrored_project))
				
				# If this mirrored pair was NOT found in our initial scan, add it
				if not existing_pairs.has(mirror_key):
					var mirrored_proj: Dictionary = {
						"fixed_ball": mirrored_fixed,
						"project_ball": mirrored_project,
						"value": proj.value,
						"comment": proj.comment
					}
					lnz_projections.append(mirrored_proj)
					# Add it to the set so it doesn't get added again by another mirror check
					existing_pairs[mirror_key] = true

		item = item.get_next()

	emit_signal("apply_projections", lnz_projections)


# func show():
# 	# Re-populate options in case species has changed since _ready()
# 	_populate_projections_tree()
# 	panel.show()

# func hide():
# 	panel.hide()

func _on_ProjectionsTree_column_title_pressed(column_index: int) -> void:
	if column_index == 5 or column_index == 6: # Lock or Mirror
		var root: TreeItem = projections_tree.get_root()
		if not root:
			return

		var item: TreeItem = root.get_children()
		if not item:
			return

		# Determine target state: if any are unchecked, check all. Otherwise, uncheck all.
		var target_state: bool = false
		var current_item: TreeItem = item
		while current_item:
			if not current_item.is_checked(column_index):
				target_state = true
				break
			current_item = current_item.get_next()

		# Apply the target state to all items
		current_item = item
		while current_item:
			current_item.set_checked(column_index, target_state)
			current_item = current_item.get_next()

func _connect_settings_signals() -> void:
	var spinners: Array = [
		"LegExt1MinSpinBox", "LegExt1MaxSpinBox",
		"LegExt2MinSpinBox", "LegExt2MaxSpinBox",
		"HeadEnl1MinSpinBox", "HeadEnl1MaxSpinBox",
		"HeadEnl2MinSpinBox", "HeadEnl2MaxSpinBox",
		"FeetEnl1MinSpinBox", "FeetEnl1MaxSpinBox",
		"FeetEnl2MinSpinBox", "FeetEnl2MaxSpinBox",
		"Scales1MinSpinBox", "Scales1MaxSpinBox",
		"Scales2MinSpinBox", "Scales2MaxSpinBox",
		"BodyExtMinSpinBox", "BodyExtMaxSpinBox",
		"FaceExtMinSpinBox", "FaceExtMaxSpinBox",
		"EarExtMinSpinBox", "EarExtMaxSpinBox",
		"MoveXMin", "MoveXMax",
		"MoveYMin", "MoveYMax",
		"MoveZMin", "MoveZMax",
		"JitterRadius"
	]

	for s in spinners:
		find_node(s).connect("value_changed", self, "_on_setting_changed")
		
	var checkboxes: Array = [
		"IncludeProjCheckBox", "IncludeBodyCheckBox", "IncludeMovesCheckBox",
		"HeadCheckBox", "BodyCheckBox", "LegsCheckBox", "TailCheckBox", "EarsCheckBox", "EyesCheckBox",
		"MirrorXCheckBox"
	]
	
	for c in checkboxes:
		find_node(c).connect("toggled", self, "_on_setting_changed")

	var reset_btn: Button = find_node("ResetDefaultsButton")
	if reset_btn:
		reset_btn.connect("pressed", self, "_on_reset_defaults_pressed")

func _on_setting_changed(_arg = null) -> void:
	if _is_loading_settings:
		return
	save_settings()

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		print("Error loading settings for save: ", err)
		return

	config.set_value("ProjectProperties", "leg_ext_1_min", find_node("LegExt1MinSpinBox").value)
	config.set_value("ProjectProperties", "leg_ext_1_max", find_node("LegExt1MaxSpinBox").value)
	config.set_value("ProjectProperties", "leg_ext_2_min", find_node("LegExt2MinSpinBox").value)
	config.set_value("ProjectProperties", "leg_ext_2_max", find_node("LegExt2MaxSpinBox").value)

	config.set_value("ProjectProperties", "head_enl_1_min", find_node("HeadEnl1MinSpinBox").value)
	config.set_value("ProjectProperties", "head_enl_1_max", find_node("HeadEnl1MaxSpinBox").value)
	config.set_value("ProjectProperties", "head_enl_2_min", find_node("HeadEnl2MinSpinBox").value)
	config.set_value("ProjectProperties", "head_enl_2_max", find_node("HeadEnl2MaxSpinBox").value)

	config.set_value("ProjectProperties", "feet_enl_1_min", find_node("FeetEnl1MinSpinBox").value)
	config.set_value("ProjectProperties", "feet_enl_1_max", find_node("FeetEnl1MaxSpinBox").value)
	config.set_value("ProjectProperties", "feet_enl_2_min", find_node("FeetEnl2MinSpinBox").value)
	config.set_value("ProjectProperties", "feet_enl_2_max", find_node("FeetEnl2MaxSpinBox").value)

	config.set_value("ProjectProperties", "scales_1_min", find_node("Scales1MinSpinBox").value)
	config.set_value("ProjectProperties", "scales_1_max", find_node("Scales1MaxSpinBox").value)
	config.set_value("ProjectProperties", "scales_2_min", find_node("Scales2MinSpinBox").value)
	config.set_value("ProjectProperties", "scales_2_max", find_node("Scales2MaxSpinBox").value)

	config.set_value("ProjectProperties", "body_ext_min", find_node("BodyExtMinSpinBox").value)
	config.set_value("ProjectProperties", "body_ext_max", find_node("BodyExtMaxSpinBox").value)

	config.set_value("ProjectProperties", "face_ext_min", find_node("FaceExtMinSpinBox").value)
	config.set_value("ProjectProperties", "face_ext_max", find_node("FaceExtMaxSpinBox").value)

	config.set_value("ProjectProperties", "ear_ext_min", find_node("EarExtMinSpinBox").value)
	config.set_value("ProjectProperties", "ear_ext_max", find_node("EarExtMaxSpinBox").value)
	
	# Move Mode Settings
	config.set_value("ProjectProperties", "move_x_min", find_node("MoveXMin").value)
	config.set_value("ProjectProperties", "move_x_max", find_node("MoveXMax").value)
	config.set_value("ProjectProperties", "move_y_min", find_node("MoveYMin").value)
	config.set_value("ProjectProperties", "move_y_max", find_node("MoveYMax").value)
	config.set_value("ProjectProperties", "move_z_min", find_node("MoveZMin").value)
	config.set_value("ProjectProperties", "move_z_max", find_node("MoveZMax").value)
	config.set_value("ProjectProperties", "jitter_radius", find_node("JitterRadius").value)
	
	config.set_value("ProjectProperties", "include_proj", find_node("IncludeProjCheckBox").pressed)
	config.set_value("ProjectProperties", "include_body", find_node("IncludeBodyCheckBox").pressed)
	config.set_value("ProjectProperties", "include_moves", find_node("IncludeMovesCheckBox").pressed)
	
	config.set_value("ProjectProperties", "grp_head", find_node("HeadCheckBox").pressed)
	config.set_value("ProjectProperties", "grp_body", find_node("BodyCheckBox").pressed)
	config.set_value("ProjectProperties", "grp_legs", find_node("LegsCheckBox").pressed)
	config.set_value("ProjectProperties", "grp_tail", find_node("TailCheckBox").pressed)
	config.set_value("ProjectProperties", "grp_ears", find_node("EarsCheckBox").pressed)
	config.set_value("ProjectProperties", "grp_eyes", find_node("EyesCheckBox").pressed)
	config.set_value("ProjectProperties", "mirror_x", find_node("MirrorXCheckBox").pressed)

	var save_err: int = config.save(SETTINGS_PATH)
	if save_err != OK:
		print("Error saving ProjectSettings: ", save_err)

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK:
		return

	print("[STATUS] ProjectSettings: loading settings configuration")
	_is_loading_settings = true

	find_node("LegExt1MinSpinBox").value = config.get_value("ProjectProperties", "leg_ext_1_min", -30.0)
	find_node("LegExt1MaxSpinBox").value = config.get_value("ProjectProperties", "leg_ext_1_max", 30.0)
	find_node("LegExt2MinSpinBox").value = config.get_value("ProjectProperties", "leg_ext_2_min", -30.0)
	find_node("LegExt2MaxSpinBox").value = config.get_value("ProjectProperties", "leg_ext_2_max", 30.0)

	find_node("HeadEnl1MinSpinBox").value = config.get_value("ProjectProperties", "head_enl_1_min", 100.0)
	find_node("HeadEnl1MaxSpinBox").value = config.get_value("ProjectProperties", "head_enl_1_max", 120.0)
	find_node("HeadEnl2MinSpinBox").value = config.get_value("ProjectProperties", "head_enl_2_min", 0.0)
	find_node("HeadEnl2MaxSpinBox").value = config.get_value("ProjectProperties", "head_enl_2_max", 0.0)

	find_node("FeetEnl1MinSpinBox").value = config.get_value("ProjectProperties", "feet_enl_1_min", 50.0)
	find_node("FeetEnl1MaxSpinBox").value = config.get_value("ProjectProperties", "feet_enl_1_max", 150.0)
	find_node("FeetEnl2MinSpinBox").value = config.get_value("ProjectProperties", "feet_enl_2_min", 0.0)
	find_node("FeetEnl2MaxSpinBox").value = config.get_value("ProjectProperties", "feet_enl_2_max", 20.0)

	find_node("Scales1MinSpinBox").value = config.get_value("ProjectProperties", "scales_1_min", 120.0)
	find_node("Scales1MaxSpinBox").value = config.get_value("ProjectProperties", "scales_1_max", 120.0)
	find_node("Scales2MinSpinBox").value = config.get_value("ProjectProperties", "scales_2_min", 100.0)
	find_node("Scales2MaxSpinBox").value = config.get_value("ProjectProperties", "scales_2_max", 100.0)

	find_node("BodyExtMinSpinBox").value = config.get_value("ProjectProperties", "body_ext_min", -20.0)
	find_node("BodyExtMaxSpinBox").value = config.get_value("ProjectProperties", "body_ext_max", 60.0)

	find_node("FaceExtMinSpinBox").value = config.get_value("ProjectProperties", "face_ext_min", -30.0)
	find_node("FaceExtMaxSpinBox").value = config.get_value("ProjectProperties", "face_ext_max", 30.0)

	find_node("EarExtMinSpinBox").value = config.get_value("ProjectProperties", "ear_ext_min", 50.0)
	find_node("EarExtMaxSpinBox").value = config.get_value("ProjectProperties", "ear_ext_max", 100.0)
	
	find_node("MoveXMin").value = config.get_value("ProjectProperties", "move_x_min", -10.0)
	find_node("MoveXMax").value = config.get_value("ProjectProperties", "move_x_max", 10.0)
	find_node("MoveYMin").value = config.get_value("ProjectProperties", "move_y_min", -10.0)
	find_node("MoveYMax").value = config.get_value("ProjectProperties", "move_y_max", 10.0)
	find_node("MoveZMin").value = config.get_value("ProjectProperties", "move_z_min", -10.0)
	find_node("MoveZMax").value = config.get_value("ProjectProperties", "move_z_max", 10.0)
	find_node("JitterRadius").value = config.get_value("ProjectProperties", "jitter_radius", 10.0)
	
	find_node("IncludeProjCheckBox").pressed = config.get_value("ProjectProperties", "include_proj", true)
	find_node("IncludeBodyCheckBox").pressed = config.get_value("ProjectProperties", "include_body", true)
	find_node("IncludeMovesCheckBox").pressed = config.get_value("ProjectProperties", "include_moves", true)
	
	find_node("HeadCheckBox").pressed = config.get_value("ProjectProperties", "grp_head", true)
	find_node("BodyCheckBox").pressed = config.get_value("ProjectProperties", "grp_body", true)
	find_node("LegsCheckBox").pressed = config.get_value("ProjectProperties", "grp_legs", true)
	find_node("TailCheckBox").pressed = config.get_value("ProjectProperties", "grp_tail", true)
	find_node("EarsCheckBox").pressed = config.get_value("ProjectProperties", "grp_ears", true)
	find_node("EyesCheckBox").pressed = config.get_value("ProjectProperties", "grp_eyes", true)
	find_node("MirrorXCheckBox").pressed = config.get_value("ProjectProperties", "mirror_x", true)

	_is_loading_settings = false

func _on_reset_defaults_pressed() -> void:
	_is_loading_settings = true

	find_node("LegExt1MinSpinBox").value = -30.0
	find_node("LegExt1MaxSpinBox").value = 30.0
	find_node("LegExt2MinSpinBox").value = -30.0
	find_node("LegExt2MaxSpinBox").value = 30.0

	find_node("HeadEnl1MinSpinBox").value = 100.0
	find_node("HeadEnl1MaxSpinBox").value = 120.0
	find_node("HeadEnl2MinSpinBox").value = 0.0
	find_node("HeadEnl2MaxSpinBox").value = 0.0

	find_node("FeetEnl1MinSpinBox").value = 50.0
	find_node("FeetEnl1MaxSpinBox").value = 150.0
	find_node("FeetEnl2MinSpinBox").value = 0.0
	find_node("FeetEnl2MaxSpinBox").value = 20.0

	find_node("Scales1MinSpinBox").value = 120.0
	find_node("Scales1MaxSpinBox").value = 120.0
	find_node("Scales2MinSpinBox").value = 100.0
	find_node("Scales2MaxSpinBox").value = 100.0

	find_node("BodyExtMinSpinBox").value = -20.0
	find_node("BodyExtMaxSpinBox").value = 60.0

	find_node("FaceExtMinSpinBox").value = -30.0
	find_node("FaceExtMaxSpinBox").value = 30.0

	find_node("EarExtMinSpinBox").value = 50.0
	find_node("EarExtMaxSpinBox").value = 100.0
	
	find_node("MoveXMin").value = -10.0
	find_node("MoveXMax").value = 10.0
	find_node("MoveYMin").value = -10.0
	find_node("MoveYMax").value = 10.0
	find_node("MoveZMin").value = -10.0
	find_node("MoveZMax").value = 10.0
	find_node("JitterRadius").value = 10.0
	
	find_node("IncludeProjCheckBox").pressed = true
	find_node("IncludeBodyCheckBox").pressed = true
	find_node("IncludeMovesCheckBox").pressed = true
	
	find_node("HeadCheckBox").pressed = true
	find_node("BodyCheckBox").pressed = true
	find_node("LegsCheckBox").pressed = true
	find_node("TailCheckBox").pressed = true
	find_node("EarsCheckBox").pressed = true
	find_node("EyesCheckBox").pressed = true
	find_node("MirrorXCheckBox").pressed = true

	_is_loading_settings = false
	save_settings()
