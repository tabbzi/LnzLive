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
signal add_ball(selected_ball, connect_line)
signal delete_ball(selected_ball)
signal copy_l_to_r(ball_no)
signal copy_r_to_l(ball_no)
signal recolor(recolor_info)
signal move_head(x,y,z)
signal print_ball_colors()
signal paintball_mode_for_ball_toggled(ball)

var selected_visual_ball = null

var current_action

onready var option_recolor_menu_button = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ToolOptionButton/PopupPanel/ToolOptionContainer/RecolorMenuButton")

enum RecolorAction { ENTIRE, LEGS, TAIL, HEAD, SNOUT, EARS, PAWS, NOSE }

func _ready():
	add_submenu_item("Color...", "RecolorMenu")
	add_item("Create Addballz + Linez") # index 1
	#add_separator()
	add_item("Create Addballz") # index 2
	add_item("Delete Addballz / Omit Ballz") # index 3
	add_item("Connect by Linez") # index 4
	add_item("Copy-Mirror (cam L-to-R)") # index 5
	add_item("Copy-Mirror (cam R-to-L)") # index 6
	add_item("Paintball Mode") # index 7
	add_item("Move Head Ballz") # index 8
	add_item("Copy Ballz Colors to Clipboard") # index 9

	option_recolor_menu_button.connect("pressed", self, "_on_RecolorMenuButton_pressed")

func _on_LineEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		var base_color = get_parent().get_node("ColorPopup/VBoxContainer/LineEdit").text
		var outline_color = get_parent().get_node("ColorPopup/VBoxContainer/LineEdit2").text
		if current_action == RecolorAction.ENTIRE:
			emit_signal("color_entire_pet", base_color, outline_color)
		else:
			var core_ball_nos = []
			if current_action == RecolorAction.LEGS:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.legs_dog[0])
					core_ball_nos.append_array(KeyBallsData.legs_dog[1])
					for ar in KeyBallsData.foot_ext_dog:
						for v in ar:
							core_ball_nos.erase(v)
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					core_ball_nos.append_array(KeyBallsData.legs_cat[0])
					core_ball_nos.append_array(KeyBallsData.legs_cat[1])
					for ar in KeyBallsData.foot_ext_cat:
						for v in ar:
							core_ball_nos.erase(v)
				else:
					core_ball_nos.append_array(KeyBallsData.legs_bab[0])
					core_ball_nos.append_array(KeyBallsData.legs_bab[1])
					for ar in KeyBallsData.foot_ext_bab:
						for v in ar:
							core_ball_nos.erase(v)
			elif current_action == RecolorAction.TAIL:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.tail_dog)
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					core_ball_nos.append_array(KeyBallsData.tail_cat)
				else:
					core_ball_nos.append_array(KeyBallsData.tail_bab)
			elif current_action == RecolorAction.HEAD:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.head_ext_dog)
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					core_ball_nos.append_array(KeyBallsData.head_ext_cat)
				else:
					core_ball_nos.append_array(KeyBallsData.head_ext_bab)
			elif current_action == RecolorAction.SNOUT:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.face_ext_dog)
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					core_ball_nos.append_array(KeyBallsData.face_ext_cat)
				else:
					core_ball_nos.append_array(KeyBallsData.face_ext_bab)
			elif current_action == RecolorAction.EARS:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					var v = KeyBallsData.ear_ext_dog.values()
					core_ball_nos.append_array(v[0])
					core_ball_nos.append_array(v[1])
					core_ball_nos.append_array(KeyBallsData.ear_ext_dog.keys())
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					var v = KeyBallsData.ear_ext_cat.values()
					core_ball_nos.append_array(v[0])
					core_ball_nos.append_array(v[1])
					core_ball_nos.append_array(KeyBallsData.ear_ext_cat.keys())
				else:
					var v = KeyBallsData.ear_ext_bab.values()
					core_ball_nos.append_array(v[0])
					core_ball_nos.append_array(v[1])
					core_ball_nos.append_array(KeyBallsData.ear_ext_bab.keys())
			elif current_action == RecolorAction.PAWS:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					for ar in KeyBallsData.foot_ext_dog:
						core_ball_nos.append_array(ar)
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					for ar in KeyBallsData.foot_ext_cat:
						core_ball_nos.append_array(ar)
				else:
					for ar in KeyBallsData.foot_ext_bab:
						core_ball_nos.append_array(ar)
			elif current_action == RecolorAction.NOSE:
				if KeyBallsData.species == KeyBallsData.Species.DOG:
					core_ball_nos.append_array(KeyBallsData.nose_dog)
				elif KeyBallsData.species == KeyBallsData.Species.CAT:
					core_ball_nos.append_array(KeyBallsData.nose_cat)
				else:
					core_ball_nos.append_array(KeyBallsData.nose_bab)
			var part = RecolorAction.keys()[RecolorAction.values()[current_action]]
			emit_signal("color_part_pet", core_ball_nos, base_color, outline_color, part)

func _on_RecolorMenu_id_pressed(id):
	current_action = id
	if id == 8: # color swap
		get_parent().get_node("RecolorPopup").popup_centered()
	else:
		get_parent().get_node("ColorPopup").rect_position = get_global_mouse_position()
		get_parent().get_node("ColorPopup").popup()

func _on_RecolorMenuButton_pressed():
	get_parent().get_node("RecolorPopup").popup_centered()

func _on_ToolsMenu_index_pressed(index):
	var ball_no = -1

	if is_instance_valid(selected_visual_ball):
		ball_no = selected_visual_ball.ball_no

	if index == 5: # Copy-Mirror (L-to-R)
		emit_signal("copy_l_to_r", ball_no)
	elif index == 6: # Copy-Mirror (R-to-L)
		emit_signal("copy_r_to_l", ball_no)
	elif index == 1: # Create Addballz + Linez
		if is_instance_valid(selected_visual_ball):
			emit_signal("add_ball", selected_visual_ball, true)
	elif index == 2: # Create Addballz
		if is_instance_valid(selected_visual_ball):
			emit_signal("add_ball", selected_visual_ball, false)
	elif index == 3: # Delete Addballz or Omit Base Ball
		if is_instance_valid(selected_visual_ball):
			emit_signal("delete_ball", selected_visual_ball.ball_no)
	elif index == 4: # Connect by Linez
		if is_instance_valid(selected_visual_ball):
			var pet_view = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
			pet_view.line_mode_close = true
			pet_view.line_mode_check_box.pressed = true
			pet_view.linez_start_ball = selected_visual_ball
			selected_visual_ball.apply_outline_state(selected_visual_ball.OutlineState.ACTIVE_SELECTED)
	elif index == 7: # Paintball Mode
		if is_instance_valid(selected_visual_ball):
			emit_signal("paintball_mode_for_ball_toggled", selected_visual_ball)
	elif index == 8: # Move Head
		var options = get_parent().get_node("HeadMovePopup")
		options.popup_centered()
	elif index == 9: # Print Ballz Colors
		emit_signal("print_ball_colors")

# func _on_ToolsMenu_about_to_show():
# 	var view_container = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
# 	#set_item_disabled(1, !view_container.last_selected_is_valid())

func _on_ToolsMenu_about_to_show():
	var is_ball_selected = is_instance_valid(selected_visual_ball)
	var ball_no = -1
	if is_ball_selected:
		ball_no = selected_visual_ball.ball_no

	# 1: Create Addballz + Linez
	var item_1_text = "Create Addballz + Linez"
	set_item_disabled(1, !is_ball_selected)
	if is_ball_selected:
		item_1_text += " (#" + str(ball_no) + ")"
	set_item_text(1, item_1_text)

	# 2: Create Addballz
	var item_2_text = "Create Addballz"
	set_item_disabled(2, !is_ball_selected)
	if is_ball_selected:
		item_2_text += " (#" + str(ball_no) + ")"
	set_item_text(2, item_2_text)

	# 3: Delete Addballz / Omit Ballz
	var item_3_text = "Delete Addballz / Omit Ballz"
	set_item_disabled(3, !is_ball_selected)
	if is_ball_selected:
		item_3_text += " (#" + str(ball_no) + ")"
	set_item_text(3, item_3_text)

	# 4: Connect by Linez
	var item_4_text = "Connect by Linez"
	set_item_disabled(4, !is_ball_selected)
	if is_ball_selected:
		item_4_text += " (Start: #" + str(ball_no) + ")"
	set_item_text(4, item_4_text)

	# 5: Copy-Mirror (L-to-R)
	var item_5_text = "Copy-Mirror"
	if is_ball_selected:
		item_5_text += " (#" + str(ball_no) + ")"
	else:
		item_5_text += " (cam L-to-R, all ballz)"
	set_item_text(5, item_5_text)

	# 6: Copy-Mirror (R-to-L)
	var item_6_text = "Copy-Mirror"
	set_item_disabled(6, is_ball_selected)
	if is_ball_selected:
		item_6_text += " (all ballz)"
	else:
		item_6_text += " (cam R-to-L, all ballz)"
	set_item_text(6, item_6_text)
	# 7: Paintball Mode
	var item_7_text = "Paintball Mode"
	if is_ball_selected:
		item_7_text += " (#" + str(ball_no) + ")"
	else:
		item_7_text += " (all ballz)"
	set_item_text(7, item_7_text)

	# 8: Move Head Ballz
	set_item_text(8, "Move Head Ballz")
	
	# 9: Copy Ballz Colors to Clipboard
	set_item_text(9, "Copy Ballz Colors to Clipboard")

func _on_RecolorPopup_confirmed():
	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines = popup.get_node("RecolorLines").get_children()
	var recolor_info = {recolors = []}
	for l in lines:
		var before_color = l.get_node("BeforeColor").text
		var before_texture = l.get_node("BeforeTexture").text
		var after_color = l.get_node("AfterColor").text
		var after_texture = l.get_node("AfterTexture").text
		var is_ramp = l.get_node("ColorRampCheck").pressed

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

	var balls_on = popup.get_node("CheckContainer/Balls").pressed
	var ball_outlines_on = popup.get_node("CheckContainer/Ball outlines").pressed
	var paintballs_on = popup.get_node("CheckContainer/Paintballs").pressed
	var lines_on = popup.get_node("CheckContainer/Lines").pressed
	var write_variation = popup.get_node("CheckContainer/WriteVariationCheckBox").pressed

	recolor_info.balls_on = balls_on
	recolor_info.ball_outlines_on = ball_outlines_on
	recolor_info.paintballs_on = paintballs_on
	recolor_info.lines_on = lines_on
	recolor_info.write_to_variation = write_variation

	emit_signal("recolor", recolor_info)

func _on_ClearButton_pressed():
	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines = popup.get_node("RecolorLines").get_children()
	for l in lines:
		l.get_node("BeforeColor").text = ""
		l.get_node("BeforeTexture").text = ""
		l.get_node("AfterColor").text = ""
		l.get_node("AfterTexture").text = ""
	for cb in popup.get_node("CheckContainer").get_children():
		cb.pressed = true

func _sort_by_count(a, b):
	return a.count > b.count

func _on_AutofillButton_pressed():
	var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if not is_instance_valid(lnz_text_edit):
		print("LnzTextEdit not found")
		return

	var pair_counts = {}
	_process_section_for_autofill(lnz_text_edit, "[Ballz Info]", 0, 7, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Add Ball]", 4, 13, pair_counts)
	_process_section_for_autofill(lnz_text_edit, "[Paint Ballz]", 5, 10, pair_counts)

	var sorted_pairs = []
	for key in pair_counts:
		sorted_pairs.append({"key": key, "count": pair_counts[key]})

	sorted_pairs.sort_custom(self, "_sort_by_count")

	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines = popup.get_node("RecolorLines").get_children()

	for i in range(lines.size()):
		var line_node = lines[i]
		if i < sorted_pairs.size():
			var pair = sorted_pairs[i].key.split(",")
			line_node.get_node("BeforeColor").text = pair[0]
			line_node.get_node("BeforeTexture").text = pair[1]
			line_node.get_node("AfterColor").text = ""
			line_node.get_node("AfterTexture").text = ""
		else:
			line_node.get_node("BeforeColor").text = ""
			line_node.get_node("BeforeTexture").text = ""
			line_node.get_node("AfterColor").text = ""
			line_node.get_node("AfterTexture").text = ""

func _process_section_for_autofill(lnz_text_edit, section_name, color_idx, texture_idx, pair_counts):
	var bounds = lnz_text_edit._get_section_bounds(section_name)
	if bounds.empty():
		return

	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue

		var parts = lnz_text_edit._split_and_clean(line)
		if parts.size() > max(color_idx, texture_idx):
			var color = parts[color_idx]
			var texture = parts[texture_idx]
			var key = color + "," + texture
			if not pair_counts.has(key):
				pair_counts[key] = 0
			pair_counts[key] += 1

func _on_RandomizeButton_pressed():
	randomize()

	var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	if not is_instance_valid(lnz_text_edit):
		print("LnzTextEdit not found")
		return

	var max_texture_id = -1
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Ballz Info]", 7, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Add Ball]", 13, max_texture_id)
	max_texture_id = _find_max_texture_for_randomize(lnz_text_edit, "[Paint Ballz]", 10, max_texture_id)

	if max_texture_id == -1:
		max_texture_id = 0

	var popup = get_parent().get_node("RecolorPopup/VBoxContainer")
	var lines = popup.get_node("RecolorLines").get_children()

	for l in lines:
		var after_color_edit = l.get_node("AfterColor")
		var after_texture_edit = l.get_node("AfterTexture")
		var is_ramp = l.get_node("ColorRampCheck").pressed

		var random_color
		if is_ramp:
			random_color = (randi() % 14 + 1) * 10
		else:
			random_color = randi() % (215 - 10 + 1) + 10

		after_color_edit.text = str(random_color)

		var random_texture = randi() % (max_texture_id + 1)
		after_texture_edit.text = str(random_texture)

func _find_max_texture_for_randomize(lnz_text_edit, section_name, texture_idx, current_max):
	var bounds = lnz_text_edit._get_section_bounds(section_name)
	if bounds.empty():
		return current_max

	var new_max = current_max
	for i in range(bounds.start, bounds.end):
		var line = lnz_text_edit.get_line(i).strip_edges()
		if line.empty() or line.begins_with(";"):
			continue

		var parts = lnz_text_edit._split_and_clean(line)
		if parts.size() > texture_idx:
			var texture_str = parts[texture_idx]
			if texture_str.is_valid_integer():
				var texture_id = int(texture_str)
				if texture_id > new_max:
					new_max = texture_id
	return new_max

func _on_HeadMoveLineEdit_gui_input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		var popup = get_parent().get_node("HeadMovePopup/VBoxContainer")
		var x = popup.get_node("HeadMoveLineEditX").text.to_int()
		var y = popup.get_node("HeadMoveLineEditY").text.to_int()
		var z = popup.get_node("HeadMoveLineEditZ").text.to_int()
		emit_signal("move_head", x, y, z)
