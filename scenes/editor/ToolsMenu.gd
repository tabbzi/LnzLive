extends PopupMenu
## ToolsMenu.gd
## Manages the right-click context menu (PopupMenu) for the 3D Viewport
## This script defines and controls all actions related to ball manipulation recoloring and LNZ data editing
## 1. Initialization: Defines all main and submenu items (Color... Create Addballz Delete Move Head etc)
## 2. Contextual Update: Updates menu item text and disabled status before showing the menu based on the currently selected ball
## 3. Recoloring: Handles simple recoloring for entire pets or specific parts (e g legs tail head) by opening ColorPopup
## 4. Advanced Recolor: Manages the complex RecolorPopup for color swapping across all LNZ components
## 5. Actions: Acts as a router to emit signals that perform LNZ modifications including Add/Delete Addballz Start Linez mode Copy-Mirror and Move Head Ballz

signal color_entire_pet(color_index, outline_color_index)
signal color_part_pet(core_ball_nos, color_index, outline_color_index, part)
signal create_addball(selected_ball, connect_line)
signal delete_ball(selected_ball)
signal copy_l_to_r(ball_no)
signal copy_r_to_l(ball_no)
signal recolor(recolor_info)
signal move_head(x,y,z)
signal apply_global_fuzz(fuzz)
signal clear_ball_paintballz(ball_no)
signal print_ball_colors()
signal paintball_mode_for_ball_toggled(ball)
signal omit_ball(ball_no)
signal unomit_ball(ball_no)
signal hide_ball(ball_no)

var selected_visual_ball: Node = null
var current_action: int = 0

onready var option_recolor_menu_button: Button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/RecolorMenuButton")

enum RecolorAction { ENTIRE, LEGS, TAIL, HEAD, SNOUT, EARS, PAWS, NOSE, TONGUE }

enum ToolsAction {
	RECOLOR = 10,
	CREATE_ADDBALLZ_LINEZ = 1,
	CREATE_ADDBALLZ = 2,
	DELETE_ADDBALLZ = 3,
	OMIT_UNOMIT = 4,
	CONNECT_LINEZ = 5,
	COPY_L_TO_R = 6,
	COPY_R_TO_L = 7,
	PAINTBALL_MODE = 8,
	EXPORT_CLOTHES = 9,
	HIDE_BALLZ = 11,
	APPLY_FUZZ = 12,
	COPY_COLORS = 13,
	BALL_INFO = 14,
	CLEAR_PAINTBALLZ = 15
}

var dog_generator: Node = null

var cached_palette_colors: Array = []

var color_line_edit
var outcol_line_edit
var fuzz_line_edit

func _ready() -> void:
	add_submenu_item("Color...", "RecolorMenu", ToolsAction.RECOLOR)
	add_item("Create Addballz + Linez", ToolsAction.CREATE_ADDBALLZ_LINEZ)
	add_item("Create Addballz", ToolsAction.CREATE_ADDBALLZ)
	add_item("Delete Addballz / Omit", ToolsAction.DELETE_ADDBALLZ)
	add_item("Omit/Unomit Ballz", ToolsAction.OMIT_UNOMIT)
	add_item("Clear Paintballz from Ballz", ToolsAction.CLEAR_PAINTBALLZ)
	add_item("Connect by Linez", ToolsAction.CONNECT_LINEZ)
	add_item("Copy-Mirror (L-to-R)", ToolsAction.COPY_L_TO_R)
	add_item("Copy-Mirror (R-to-L)", ToolsAction.COPY_R_TO_L)
	add_item("Paintball Mode", ToolsAction.PAINTBALL_MODE)
	add_item("Export to Clothes CLZ", ToolsAction.EXPORT_CLOTHES)
	add_item("Hide Ballz", ToolsAction.HIDE_BALLZ)
	add_item("Apply Global Fuzz", ToolsAction.APPLY_FUZZ)
	add_item("Copy Ballz Colors to Clipboard", ToolsAction.COPY_COLORS)
	add_item("Ball Info", ToolsAction.BALL_INFO)

	option_recolor_menu_button.connect("pressed", self, "_on_RecolorMenuButton_pressed")
	
	var panel_style: StyleBoxFlat = preload("res://resources/styles/styleboxflat_button_normal.tres").duplicate()
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 12
	add_stylebox_override("panel", panel_style)

	var recolor_menu: PopupMenu = get_node_or_null("RecolorMenu")
	if recolor_menu:
		recolor_menu.add_stylebox_override("panel", panel_style)
	
	if get_tree().get_root().has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot/Node")
	elif get_tree().get_root().has_node("Root/PetRoot"):
		dog_generator = get_tree().get_root().get_node("Root/PetRoot")
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_palette_changed")

	_resize_and_anchor_popup("ColorPopup", Vector2(240, 110))
	_resize_and_anchor_popup("FuzzPopup", Vector2(160, 60))
	_resize_and_anchor_popup("HeadMovePopup", Vector2(160, 120))

	color_line_edit = get_parent().get_node("ColorPopup/VBoxContainer/LineEdit")
	outcol_line_edit = get_parent().get_node("ColorPopup/VBoxContainer/LineEdit2")
	fuzz_line_edit = get_parent().get_node_or_null("FuzzPopup/VBoxContainer/GlobalFuzzAmount")
	
	var color_popup = get_parent().get_node("ColorPopup")
	if color_popup:
		color_popup.rect_min_size = Vector2(200, 100) # Ensure popup is tall/wide enough for padding + icons
		
		var vbox = color_popup.get_node("VBoxContainer")
		if vbox:
			vbox.anchor_right = 1.0
			vbox.anchor_bottom = 1.0
			vbox.margin_right = 0
			vbox.margin_bottom = 0
	
	LnzLiveUtils.setup_preview_wrapper(self, color_line_edit, "ColorEdit")
	LnzLiveUtils.setup_preview_wrapper(self, outcol_line_edit, "OutcolEdit")
	
	# Apply comfortable padding to all standard LineEdits inside the menu popups
	var le_style: StyleBoxFlat = color_line_edit.get_stylebox("normal").duplicate()
	if le_style is StyleBoxFlat:
		le_style.content_margin_left = 10
		le_style.content_margin_right = 10
		le_style.content_margin_top = 6
		le_style.content_margin_bottom = 6
		
	color_line_edit.add_stylebox_override("normal", le_style)
	outcol_line_edit.add_stylebox_override("normal", le_style)
	
	if fuzz_line_edit: fuzz_line_edit.add_stylebox_override("normal", le_style)
	
	for head_edit in ["HeadMoveLineEditX", "HeadMoveLineEditY", "HeadMoveLineEditZ"]:
		var edit: Control = get_parent().get_node_or_null("HeadMovePopup/VBoxContainer/" + head_edit)
		if edit: edit.add_stylebox_override("normal", le_style)

	_on_palette_changed()

func _resize_and_anchor_popup(popup_name: String, new_size: Vector2) -> void:
	var popup = get_parent().get_node_or_null(popup_name)
	if popup:
		popup.rect_min_size = new_size
		popup.rect_size = new_size
		
		var vbox = popup.get_node_or_null("VBoxContainer")
		if vbox:
			vbox.anchor_right = 1.0
			vbox.anchor_bottom = 1.0
			vbox.margin_right = 0
			vbox.margin_bottom = 0

func _on_color_list_text_changed(new_text: String, container: Container) -> void:
	# Removed ClassDB check because LnzLiveUtils is an AutoLoad singleton.
	if LnzLiveUtils:
		LnzLiveUtils.update_color_list_previews(container, new_text, cached_palette_colors)

func _on_palette_changed(palette_name = "") -> void:
	if not is_instance_valid(dog_generator) or not dog_generator.current_palette_texture:
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

func _refresh_all_previews() -> void:
	if not is_instance_valid(color_line_edit) or not is_instance_valid(outcol_line_edit): return
	
	var cw = color_line_edit.get_parent()
	if cw and cw.has_node("ColorEdit_Preview"):
		_on_color_list_text_changed(color_line_edit.text, cw.get_node("ColorEdit_Preview"))

	var ow = outcol_line_edit.get_parent()
	if ow and ow.has_node("OutcolEdit_Preview"):
		_on_color_list_text_changed(outcol_line_edit.text, ow.get_node("OutcolEdit_Preview"))


func _on_LineEdit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		var base_color: String = color_line_edit.text
		var outline_color: String = outcol_line_edit.text
		if current_action == RecolorAction.ENTIRE:
			emit_signal("color_entire_pet", base_color, outline_color)
		else:
			var core_ball_nos: Array = []
			if current_action == RecolorAction.LEGS:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "LEGS")
			elif current_action == RecolorAction.TAIL:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "TAIL")
			elif current_action == RecolorAction.HEAD:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "HEAD")
			elif current_action == RecolorAction.SNOUT:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "SNOUT")
			elif current_action == RecolorAction.EARS:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "EARS")
			elif current_action == RecolorAction.PAWS:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "PAWS")
			elif current_action == RecolorAction.NOSE:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "NOSE")
			elif current_action == RecolorAction.TONGUE:
				core_ball_nos = KeyBallsData.get_recolor_targets(KeyBallsData.species, "TONGUE")
			var part: String = RecolorAction.keys()[RecolorAction.values()[current_action]]
			emit_signal("color_part_pet", core_ball_nos, base_color, outline_color, part)

func _on_RecolorMenu_id_pressed(id: int) -> void:
	current_action = id
	if id == 9: # color swap
		var pet_view: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
		if pet_view:
			pet_view.recolor_mode_check_box.pressed = true
	else:
		get_parent().get_node("ColorPopup").rect_position = get_global_mouse_position()
		get_parent().get_node("ColorPopup").popup()

func _on_RecolorMenuButton_pressed() -> void:
	var pet_view: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	if pet_view:
		pet_view.recolor_mode_check_box.pressed = true

func _on_ToolsMenu_index_pressed(index: int) -> void:
	if index >= get_item_count(): return

	if get_item_text(index).begins_with("Exit "):
		var pet_view: Node = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
		if is_instance_valid(pet_view):
			pet_view.paintball_check_box.pressed = false
			pet_view.line_mode_check_box.pressed = false
			pet_view.move_mode_check_box.pressed = false
			pet_view.preset_mode_check_box.pressed = false
			pet_view.recolor_mode_check_box.pressed = false
			pet_view.project_mode_check_box.pressed = false
			pet_view.auto_paintballer_check_box.pressed = false
		return

	var id: int = get_item_id(index)
	var ball_no: int = -1
	var is_addball: bool = false
	var is_omitted: bool = false
	var is_ball_selected: bool = false

	if is_instance_valid(selected_visual_ball):
		ball_no = selected_visual_ball.ball_no
		is_ball_selected = true
		is_addball = ball_no > KeyBallsData.max_base_ball_num
		is_omitted = selected_visual_ball.get("omitted") == true

	# Match against IDs so reordering items in _ready() doesn't break logic
	match id:
		ToolsAction.CREATE_ADDBALLZ_LINEZ: # Create Addballz + Linez
			if is_instance_valid(selected_visual_ball):
				emit_signal("create_addball", selected_visual_ball, true)

		ToolsAction.CREATE_ADDBALLZ: # Create Addballz
			if is_instance_valid(selected_visual_ball):
				emit_signal("create_addball", selected_visual_ball, false)

		ToolsAction.DELETE_ADDBALLZ: # Delete Addballz
			if is_instance_valid(selected_visual_ball):
				if is_omitted:
					emit_signal("unomit_ball", ball_no)
				elif is_addball:
					emit_signal("delete_ball", ball_no)
				else:
					emit_signal("omit_ball", ball_no)

		ToolsAction.OMIT_UNOMIT: # Omit/Unomit Ballz
			if is_instance_valid(selected_visual_ball):
				if is_omitted:
					emit_signal("unomit_ball", ball_no)
				else:
					emit_signal("omit_ball", ball_no)

		ToolsAction.CONNECT_LINEZ: # Connect by Linez
			if is_instance_valid(selected_visual_ball):
				var pet_view: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
				pet_view.line_mode_close = true
				pet_view.line_mode_check_box.pressed = true
				pet_view.polygon_mode = false
				pet_view.polygon_balls.clear()
				if pet_view.line_mode_settings_instance:
					var cb = pet_view.line_mode_settings_instance.find_node("PolygonModeCheckBox")
					if cb:
						cb.pressed = false
				pet_view.linez_start_ball = selected_visual_ball
				selected_visual_ball.apply_outline_state(selected_visual_ball.OutlineState.ACTIVE_SELECTED)

		ToolsAction.COPY_L_TO_R: # Copy-Mirror (L-to-R)
			emit_signal("copy_l_to_r", ball_no)

		ToolsAction.COPY_R_TO_L: # Copy-Mirror (R-to-L)
			emit_signal("copy_r_to_l", ball_no)

		ToolsAction.PAINTBALL_MODE: # Paintball Mode
			if is_instance_valid(selected_visual_ball):
				emit_signal("paintball_mode_for_ball_toggled", selected_visual_ball)

		ToolsAction.EXPORT_CLOTHES: # Export to Clothes CLZ
			get_parent().get_node("ExportClothes").open(ball_no)

		ToolsAction.HIDE_BALLZ: # Hide Ballz
			if is_instance_valid(selected_visual_ball):
				emit_signal("hide_ball", ball_no)

		ToolsAction.APPLY_FUZZ: # Apply Global Fuzz
			var options = get_parent().get_node("FuzzPopup")
			options.popup_centered()

		ToolsAction.COPY_COLORS: # Print Ballz Colors
			emit_signal("print_ball_colors")

		ToolsAction.BALL_INFO: # Jump to ball
			if is_ball_selected:
				var lnz_text_edit: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
				if is_instance_valid(lnz_text_edit):
					lnz_text_edit.select_ball(0, ball_no, is_addball, -1)
			return

		ToolsAction.CLEAR_PAINTBALLZ: # Clear Paintballz
			if is_ball_selected:
				emit_signal("clear_ball_paintballz", ball_no)


func _on_ToolsMenu_about_to_show() -> void:
	while get_item_count() > 15:
		remove_item(get_item_count() - 1)

	for i in range(14):
		set_item_disabled(i, false)

	var ball_no: int = -1
	var is_addball: bool = false
	var is_omitted: bool = false
	var is_ball_selected: bool = false
	var b_name: String = "Unknown Ball"
	
	var pet_view: Node = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	var active_mode: String = ""
	if is_instance_valid(pet_view):
		if pet_view.move_mode: active_mode = "Move Mode"
		elif pet_view.paintball_mode: active_mode = "Paintball Mode"
		elif pet_view.linez_mode: active_mode = "Line Mode"
		elif pet_view.preset_mode: active_mode = "Preset Mode"
		elif pet_view.project_mode: active_mode = "Project Mode"
		elif pet_view.auto_paintballer_mode: active_mode = "Auto Paintballer"
		elif pet_view.recolor_mode: active_mode = "Recolor Mode"

	var in_mode: bool = active_mode != ""

	if is_instance_valid(selected_visual_ball):
		ball_no = selected_visual_ball.ball_no
		is_ball_selected = is_instance_valid(selected_visual_ball)

		var lnz_text_edit: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
		if is_instance_valid(lnz_text_edit):
			b_name = lnz_text_edit.get_ball_name(ball_no)

		is_addball = ball_no > KeyBallsData.max_base_ball_num
		is_omitted = selected_visual_ball.get("omitted") == true

	if is_ball_selected:
		set_item_text(get_item_index(ToolsAction.BALL_INFO), "Jump to #%d (%s)" % [ball_no, b_name])
	else:
		set_item_text(get_item_index(ToolsAction.BALL_INFO), "No Ballz Selected")

	var option_text: String = ""

	# Create Addballz + Linez
	var idx: int =  get_item_index(ToolsAction.CREATE_ADDBALLZ_LINEZ)
	option_text = "Create Addballz + Linez"
	set_item_disabled(idx, !is_ball_selected)
	if is_ball_selected:
		option_text += " (#" + str(ball_no) + ")"
	set_item_text(idx, option_text)

	# Create Addballz
	idx = get_item_index(ToolsAction.CREATE_ADDBALLZ)
	option_text = "Create Addballz"
	set_item_disabled(idx, !is_ball_selected)
	if is_ball_selected:
		option_text += " (#" + str(ball_no) + ")"
	set_item_text(idx, option_text)

	# Delete Addballz
	idx = get_item_index(ToolsAction.DELETE_ADDBALLZ)
	option_text = "Delete Addballz"
	set_item_disabled(idx, !is_ball_selected or !is_addball)
	if is_ball_selected and is_addball:
		option_text += " (#" + str(ball_no) + ")"
	set_item_text(idx, option_text)

	# Omit/Unomit Ballz
	idx =  get_item_index(ToolsAction.OMIT_UNOMIT)
	set_item_disabled(idx, !is_ball_selected)
	if is_ball_selected:
		var type_str: String = "Addballz" if is_addball else "Ballz"
		if is_omitted:
			set_item_text(idx, "Unomit " + type_str + " (#" + str(ball_no) + ")")
		else:
			set_item_text(idx, "Omit " + type_str + " (#" + str(ball_no) + ")")
	else:
		set_item_text(idx, "Omit / Unomit Ballz")
		set_item_disabled(idx, !is_ball_selected)

	# Connect by Linez
	idx = get_item_index(ToolsAction.CONNECT_LINEZ)
	option_text = "Connect by Linez"
	set_item_disabled(idx, !is_ball_selected)
	if is_ball_selected:
		option_text += " (Start: #" + str(ball_no) + ")"
	set_item_text(idx, option_text)

	# Copy-Mirror (L-to-R/R-to-L)
	if is_ball_selected:
		idx = get_item_index(ToolsAction.COPY_L_TO_R)
		set_item_text(idx, "Copy-Mirror (#" + str(ball_no) + ")")
		set_item_disabled(idx, false)

		idx = get_item_index(ToolsAction.COPY_R_TO_L)
		set_item_text(idx, "Copy-Mirror (all ballz)")
		set_item_disabled(idx, true)
	else:
		idx = get_item_index(ToolsAction.COPY_L_TO_R)
		set_item_text(idx, "Copy-Mirror (L-to-R, all ballz)")
		set_item_disabled(idx, false)

		idx = get_item_index(ToolsAction.COPY_R_TO_L)
		set_item_text(idx, "Copy-Mirror (R-to-L, all ballz)")
		set_item_disabled(idx, false)

	# Paintball Mode
	idx = get_item_index(ToolsAction.PAINTBALL_MODE)
	option_text = "Paintball Mode"
	if is_ball_selected:
		option_text += " (#" + str(ball_no) + ")"
	else:
		option_text += " (all ballz)"
	set_item_text(idx, option_text)

	# Export to Clothes CLZ
	idx = get_item_index(ToolsAction.EXPORT_CLOTHES)
	option_text = "Export to Clothes CLZ"
	if is_ball_selected:
		option_text += " (#" + str(ball_no) + ")"
	set_item_text(idx, option_text)

	# Hide Ballz
	idx = get_item_index(ToolsAction.HIDE_BALLZ)
	option_text = "Hide Ballz"
	set_item_disabled(idx, !is_ball_selected)
	if is_ball_selected:
		option_text += " (#" + str(ball_no) + ")"
	set_item_text(idx, option_text)

	# Apply Global Fuzz
	idx = get_item_index(ToolsAction.APPLY_FUZZ)
	set_item_text(idx, "Apply Global Fuzz")

	# Copy Ballz Colors to Clipboard
	idx = get_item_index(ToolsAction.COPY_COLORS)
	set_item_text(idx, "Copy Ballz Colors to Clipboard")

	# Clear Paintballz
	idx = get_item_index(ToolsAction.CLEAR_PAINTBALLZ)
	set_item_disabled(idx, !is_ball_selected)
	set_item_text(idx, "Clear Paintballz (#%d)" % ball_no if is_ball_selected else "Clear Paintballz")

	if in_mode:
		# Disable everything involving interactive left-click
		var allowed_ids: Array = [
			ToolsAction.RECOLOR,
			ToolsAction.DELETE_ADDBALLZ,
			ToolsAction.OMIT_UNOMIT,
			ToolsAction.EXPORT_CLOTHES,
			ToolsAction.APPLY_FUZZ,
			ToolsAction.HIDE_BALLZ,
			ToolsAction.COPY_COLORS,
			ToolsAction.BALL_INFO,
			ToolsAction.CLEAR_PAINTBALLZ
		]
		
		for i in range(15):
			var item_id: int = get_item_id(i)
			if not item_id in allowed_ids:
				set_item_disabled(i, true)

		add_separator()
		add_item("Exit " + active_mode)

func _on_RecolorPopup_confirmed() -> void:
	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines: Array = popup.get_node("RecolorLines").get_children()
	var recolor_info: Dictionary = {recolors = []}
	for l in lines:
		var before_color: String = l.get_node("BeforeColor").text
		var before_texture: String = l.get_node("BeforeTexture").text
		var after_color: String = l.get_node("AfterColor").text
		var after_texture: String = l.get_node("AfterTexture").text
		var is_ramp: bool = l.get_node("ColorRampCheck").pressed

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

	var balls_on: bool = popup.get_node("CheckContainer/Balls").pressed
	var ball_outlines_on: bool = popup.get_node("CheckContainer/Ball outlines").pressed
	var paintballs_on: bool = popup.get_node("CheckContainer/Paintballs").pressed
	var lines_on: bool = popup.get_node("CheckContainer/Lines").pressed
	var polygons_on: bool = popup.get_node("CheckContainer/Polygons").pressed
	recolor_info.balls_on = balls_on
	recolor_info.ball_outlines_on = ball_outlines_on
	recolor_info.paintballs_on = paintballs_on
	recolor_info.lines_on = lines_on
	recolor_info.polygons_on = polygons_on
	emit_signal("recolor", recolor_info)

func _on_ClearButton_pressed() -> void:
	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines: Array = popup.get_node("RecolorLines").get_children()
	for l in lines:
		l.get_node("BeforeColor").text = ""
		l.get_node("BeforeTexture").text = ""
		l.get_node("AfterColor").text = ""
		l.get_node("AfterTexture").text = ""
	for cb in popup.get_node("CheckContainer").get_children():
		if cb.has_method("set_pressed"):
			cb.pressed = true

func _sort_by_count(a: Dictionary, b: Dictionary) -> bool:
	return a.count > b.count

func _on_AutofillButton_pressed() -> void:
	var lnz_text_edit: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if not is_instance_valid(lnz_text_edit):
		print("LnzTextEdit not found")
		return

	var pair_counts: Dictionary = {}
	_process_section_for_autofill(lnz_text_edit, "[Ballz Info]", 0, 7, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Add Ball]", 4, 13, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Paint Ballz]", 5, 10, pair_counts)

	var sorted_pairs: Array = []
	for key in pair_counts:
		sorted_pairs.append({"key": key, "count": pair_counts[key]})

	sorted_pairs.sort_custom(self, "_sort_by_count")

	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines: Array = popup.get_node("RecolorLines").get_children()

	for i in range(lines.size()):
		var line_node: Container = lines[i]
		if i < sorted_pairs.size():
			var pair: Array = sorted_pairs[i].key.split(",")
			line_node.get_node("BeforeColor").text = pair[0]
			line_node.get_node("BeforeTexture").text = pair[1]
			line_node.get_node("AfterColor").text = ""
			line_node.get_node("AfterTexture").text = ""
		else:
			line_node.get_node("BeforeColor").text = ""
			line_node.get_node("BeforeTexture").text = ""
			line_node.get_node("AfterColor").text = ""
			line_node.get_node("AfterTexture").text = ""

func _process_section_for_autofill(lnz_text_edit: Node, section_name: String, color_idx: int, texture_idx: int, pair_counts: Dictionary) -> void:
	var bounds: Dictionary = lnz_text_edit.get_section_bounds(section_name)
	if bounds.empty():
		return

	for i in range(bounds.start, bounds.end):
		var line: String = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue

		var parts: Array = lnz_text_edit.split_line(line)
		if parts.size() > max(color_idx, texture_idx):
			var color: String = parts[color_idx]
			var texture: String = parts[texture_idx]
			var key: String = color + "," + texture
			if not pair_counts.has(key):
				pair_counts[key] = 0
			pair_counts[key] += 1

func _on_RandomizeButton_pressed() -> void:
	randomize()

	var lnz_text_edit: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if not is_instance_valid(lnz_text_edit):
		print("LnzTextEdit not found")
		return

	var max_texture_id: int = -1
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Ballz Info]", 7, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Add Ball]", 13, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Paint Ballz]", 10, max_texture_id)

	if max_texture_id == -1:
		max_texture_id = 0

	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines: Array = popup.get_node("RecolorLines").get_children()

	for l in lines:
		var after_color_edit = l.get_node("AfterColor")
		var after_texture_edit = l.get_node("AfterTexture")
		var is_ramp: bool = l.get_node("ColorRampCheck").pressed

		var random_color: int
		if is_ramp:
			random_color = (randi() % 14 + 1) * 10
		else:
			random_color = randi() % (215 - 10 + 1) + 10

		after_color_edit.text = str(random_color)

		var random_texture: int = randi() % (max_texture_id + 1)
		after_texture_edit.text = str(random_texture)

func _find_max_texture_for_randomize(lnz_text_edit: Node, section_name: String, texture_idx: int, current_max: int) -> int:
	var bounds: Dictionary = lnz_text_edit.get_section_bounds(section_name)
	if bounds.empty():
		return current_max

	var new_max: int = current_max
	for i in range(bounds.start, bounds.end):
		var line: String = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue

		var parts: Array = lnz_text_edit.split_line(line)
		if parts.size() > texture_idx:
			var texture_str: String = parts[texture_idx]
			if texture_str.is_valid_integer():
				var texture_id: int = int(texture_str)
				if texture_id > new_max:
					new_max = texture_id
	return new_max

# func _on_HeadMoveLineEdit_gui_input(event):
# 	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
# 		var popup = get_parent().get_node("HeadMovePopup/VBoxContainer")
# 		var x: int = popup.get_node("HeadMoveLineEditX").text.to_int()
# 		var y: int = popup.get_node("HeadMoveLineEditY").text.to_int()
# 		var z: int = popup.get_node("HeadMoveLineEditZ").text.to_int()
# 		emit_signal("move_head", x, y, z)

func _on_ApplyGlobalFuzz_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		var popup = get_parent().get_node("FuzzPopup/VBoxContainer")
		var fuzz: int = popup.get_node("GlobalFuzzAmount").text.to_int()
		emit_signal("apply_global_fuzz", fuzz)
