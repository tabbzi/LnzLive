extends Label
## BallNo.gd
## Displays the current ball number and associated name information

onready var ball_label: Label = self
onready var lnz_edit: Node = get_node("../../LnzTextEdit")

func _update_ball_label(ball_no: int) -> void:
	# Hide label if ball number is invalid
	if ball_no == -1:
		ball_label.visible = false
		return

	var current_section: String = lnz_edit.get_current_section_name()
	
	# Handle specific sections where line context is relevant
	if current_section == "[Linez]" or current_section == "[Project Ball]":
		var line_idx: int = lnz_edit.cursor_get_line()
		var line_text: String = lnz_edit.get_line(line_idx).strip_edges()
		var parts: Array = lnz_edit.split_line(line_text)
		
		# Ensure parts array has enough elements
		if parts.size() >= 2:
			var b1: int = int(parts[0])
			var b2: int = int(parts[1])
			var name1: String = lnz_edit.get_ball_name(b1)
			var name2: String = lnz_edit.get_ball_name(b2)
			
			var bounds = lnz_edit.get_section_bounds("[Linez]")
			var count_b1: int = 0
			var count_b2: int = 0
			var total_valid: int = 0
			if not bounds.empty():
				for i in range(bounds.start, bounds.end):
					var line = lnz_edit.get_line(i).strip_edges()
					if line.empty() or line.begins_with(";"):
						continue
					var pl = lnz_edit.split_line(line)
					if pl.size() < 2:
						continue
					total_valid += 1
					var lb1 = int(pl[0])
					var lb2 = int(pl[1])
					if lb1 == b1 or lb2 == b1:
						count_b1 += 1
					if lb1 == b2 or lb2 == b2:
						count_b2 += 1
			
			# Construct display text
			var display_text: String = "#(" + str(b1) + "): " + str(name1)
			if current_section == "[Linez]":
				display_text += " (" + str(count_b1) + "/32)"
			display_text += " to #(" + str(b2) + "): " + str(name2)
			if current_section == "[Linez]":
				display_text += " (" + str(count_b2) + "/32)"
			display_text += " (" + str(total_valid) + "/256 linez)"
			
			# Check linez limits if method exists
			var at_limit: bool = false
			if current_section == "[Linez]" and lnz_edit.has_method("check_linez_limits"):
				if lnz_edit.check_linez_limits(b1, b2):
					at_limit = true
			
			if at_limit:
				display_text += " (AT LIMIT)"
				ball_label.add_color_override("font_color", Color.red)
			else:
				ball_label.add_color_override("font_color", Color.white)
			
			ball_label.text = display_text
			ball_label.visible = true
			return

	# Default display logic for other sections
	ball_label.add_color_override("font_color", Color.white)

	var max_base: int = 0
	var max_base_val = KeyBallsData.get("max_base_ball_num")
	if max_base_val != null:
		max_base = max_base_val
	
	var type_label: String = ""
	if max_base_val != null:
		type_label = "(base)" if ball_no < max_base else "(add)"
	
	var name_ext: String = ""
	if lnz_edit.has_method("get_ball_name"):
		var b_name = lnz_edit.get_ball_name(ball_no)
		if b_name != null and b_name is String and b_name != "":
			name_ext = ": " + str(b_name)
	
	ball_label.text = "Curr Ball #" + str(ball_no) + " " + type_label + name_ext
	ball_label.visible = true
