extends Control

## FindReplaceController.gd
## Handles all find/replace UI callbacks and regex compilation for LnzTextEdit

var on_find_text
var on_get_text
var on_is_selection_active
var on_get_selection_text
var on_get_selection_from_line
var on_get_selection_from_column
var on_get_selection_to_line
var on_get_selection_to_column
var on_cursor_get_line
var on_cursor_get_column
var on_get_line_count

var on_select_range
var on_insert_text_at_cursor
var on_deselect
var on_cursor_set_line
var on_cursor_set_column
var on_center_viewport_to_cursor
var on_set_v_scroll
var on_set_h_scroll

var on_show_wrap_notification
var on_hide_wrap_notification
var on_start_notification_timer
var on_set_search_error_color
var on_set_search_ok_color

var on_replace_all
var on_get_replace_text

var _compiled_regex: RegEx = RegEx.new()
var _last_compiled_pattern: String = ""
var _last_compiled_params: String = ""


func _ready() -> void:
	pass


static func build_search_pattern(search_text: String, whole_words: bool, match_case: bool) -> String:
	var pattern = _escape_regex(search_text)
	if whole_words:
		pattern = "\\b" + pattern + "\\b"
	if not match_case:
		pattern = "(?i)" + pattern
	return pattern


static func _escape_regex(pattern_str: String) -> String:
	var special_chars = ".+*?()[]{}|^$\\/"
	var escaped_str = ""
	for this_char in pattern_str:
		if special_chars.find(this_char) != -1:
			escaped_str += "\\"
		escaped_str += this_char
	return escaped_str


func _ensure_compiled(pattern: String, whole_words: bool, match_case: bool) -> int:
	var params = str(whole_words, match_case)
	if pattern == _last_compiled_pattern and params == _last_compiled_params:
		return OK
	
	var error = _compiled_regex.compile(pattern)
	if error != OK:
		return error
	
	_last_compiled_pattern = pattern
	_last_compiled_params = params
	return OK


func find_text(forward: bool) -> void:
	var find_line_edit = get_node("VBoxContainer/LineEdit")
	var search_text = find_line_edit.text
	if search_text.empty():
		return
	
	var wrap_notification_label = get_node("VBoxContainer/WrapNotificationLabel")
	var notification_timer = get_node("NotificationTimer")
	_hide_wrap_notification.call()
	on_set_search_ok_color.call()
	
	var all_text = on_get_text.call()
	if all_text.empty():
		on_set_search_error_color.call()
		return
	
	var whole_words = get_node("VBoxContainer/HBoxContainer/WholeWordsCheckBox").pressed
	var match_case = get_node("VBoxContainer/HBoxContainer/MatchCaseCheckBox").pressed
	var pattern = build_search_pattern(search_text, whole_words, match_case)
	
	var error = _ensure_compiled(pattern, whole_words, match_case)
	if error != OK:
		on_set_search_error_color.call()
		return
	
	var all_matches = _compiled_regex.search_all(all_text)
	if all_matches.size() == 0:
		on_set_search_error_color.call()
		return
	
	var result = null
	var wrapped = false
	
	if forward:
		var start_offset
		if on_is_selection_active.call():
			start_offset = _pos_to_offset(on_get_selection_to_line.call(), on_get_selection_to_column.call())
		else:
			start_offset = _pos_to_offset(on_cursor_get_line.call(), on_cursor_get_column.call()) + 1
		
		var best_match = null
		for this_match in all_matches:
			if this_match.get_start() >= start_offset:
				best_match = this_match
				break
		
		result = best_match
		if result == null:
			if all_matches.size() > 0:
				result = all_matches[0]
				wrapped = true
	else:
		var start_offset
		if on_is_selection_active.call():
			start_offset = _pos_to_offset(on_get_selection_from_line.call(), on_get_selection_from_column.call())
		else:
			start_offset = _pos_to_offset(on_cursor_get_line.call(), on_cursor_get_column.call())
		
		var best_match = null
		for this_match in all_matches:
			if this_match.get_start() < start_offset:
				best_match = this_match
			else:
				break
		
		result = best_match
		if result == null:
			if all_matches.size() > 0:
				result = all_matches[all_matches.size() - 1]
				wrapped = true
	
	if result != null:
		if wrapped:
			_show_wrap_notification.call()
			_start_notification_timer.call()
		
		var start_pos = _offset_to_pos(result.get_start())
		var end_pos = _offset_to_pos(result.get_end())
		
		var start_col = int(start_pos.x)
		var start_line = int(start_pos.y)
		var end_col = int(end_pos.x)
		var end_line = int(end_pos.y)
		
		on_cursor_set_line.call(start_line)
		on_cursor_set_column.call(start_col)
		on_center_viewport_to_cursor.call()
		on_select_range.call(start_line, start_col, end_line, end_col)
	else:
		on_set_search_error_color.call()


func replace_current() -> void:
	var find_line_edit = get_node("VBoxContainer/LineEdit")
	var replace_line_edit = get_node("VBoxContainer/ReplaceLineEdit")
	var search_text = find_line_edit.text
	var replace_text = replace_line_edit.text
	
	if search_text.empty():
		return
	
	if on_is_selection_active.call():
		var selected_text = on_get_selection_text.call()
		
		var whole_words = get_node("VBoxContainer/HBoxContainer/WholeWordsCheckBox").pressed
		var match_case = get_node("VBoxContainer/HBoxContainer/MatchCaseCheckBox").pressed
		var pattern = build_search_pattern(search_text, whole_words, match_case)
		
		var anchored_pattern = "^" + pattern + "$"
		
		var regex = RegEx.new()
		var err = regex.compile(anchored_pattern)
		if err != OK:
			return
		
		var this_match = regex.search(selected_text, 0)
		if this_match != null:
			on_insert_text_at_cursor.call(replace_text)
	
	find_text(true)


func replace_all() -> void:
	var find_line_edit = get_node("VBoxContainer/LineEdit")
	var replace_line_edit = get_node("VBoxContainer/ReplaceLineEdit")
	var search_text = find_line_edit.text
	var replace_text = on_get_replace_text.call()
	
	if search_text.empty():
		return
	
	var whole_words = get_node("VBoxContainer/HBoxContainer/WholeWordsCheckBox").pressed
	var match_case = get_node("VBoxContainer/HBoxContainer/MatchCaseCheckBox").pressed
	var pattern = build_search_pattern(search_text, whole_words, match_case)
	
	var regex: RegEx = _compiled_regex
	var err = _ensure_compiled(pattern, whole_words, match_case)
	if err != OK:
		on_set_search_error_color.call()
		return
	
	on_set_search_ok_color.call()
	
	var all_text = on_get_text.call()
	var estimated_matches = all_text.count(search_text)
	if estimated_matches > 10000:
		print("[WARNING] LnzTextEdit: Replace All found ~%d matches. This may cause performance issues." % estimated_matches)
	
	on_replace_all.call(search_text, replace_text)


func _pos_to_offset(line: int, col: int) -> int:
	var offset = 0
	for i in range(line):
		offset += _get_line_length(i) + 1
	offset += col
	return offset


func _get_line_length(line: int) -> int:
	var all_text = on_get_text.call()
	var lines = all_text.split("\n", false)
	if line < lines.size():
		return lines[line].length()
	return 0


func _offset_to_pos(offset: int) -> Vector2:
	var current_offset = 0
	for line_num in range(on_get_line_count.call()):
		var line_len = _get_line_length(line_num) + 1
		if current_offset + line_len > offset:
			var col = offset - current_offset
			return Vector2(col, line_num)
		current_offset += line_len
	var last_line = on_get_line_count.call() - 1
	if last_line < 0:
		return Vector2(0, 0)
	var col_on_last_line = offset - current_offset
	return Vector2(col_on_last_line, last_line)
