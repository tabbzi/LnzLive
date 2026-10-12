extends Node

## LnzHistoryManager.gd
## Manages undo/redo history for LnzTextEdit

var _get_text
var _set_text
var _get_cursor_line
var _get_cursor_col
var _set_cursor_line
var _set_cursor_col
var _get_v_scroll
var _set_v_scroll
var _get_h_scroll
var _set_h_scroll
var _get_line_count
var _set_line

var on_snapshot_committed

var on_log_message

var history_stack: Array = []
var history_index: int = -1
var max_history_size: int = 25

var last_commit_time: int = 0
var last_commit_action: String = ""
var last_commit_id: int = -1

class HistoryItem:
	enum Type { SNAPSHOT, LOGICAL }
	var type: int
	var action_name: String
	
	var full_text: String
	var cursor_line: int
	var cursor_col: int
	var v_scroll: float
	var h_scroll: float
	
	var target_section: String
	var target_id: int
	var old_line_data: String
	var new_line_data: String

	var cached_line_index: int = -1


func initialize_history(current_text: String) -> void:
	history_stack.clear()
	history_index = -1
	
	var item = _create_snapshot_item(current_text, "Initial Load")
	history_stack.append(item)
	history_index = 0


func commit_full_snapshot(action_name: String) -> void:
	if history_index >= 0:
		var last = history_stack[history_index]
		if last.type == HistoryItem.Type.SNAPSHOT and last.full_text == _get_text.call():
			return
	
	_trim_history_tail()
	
	var item = _create_snapshot_item(_get_text.call(), action_name)
	history_stack.append(item)
	history_index += 1
	_check_history_size()
	
	var msg = "[HISTORY] Snapshot Commit: %s" % action_name
	print(msg)
	if on_log_message:
		on_log_message.call(msg)
	
	if on_snapshot_committed:
		on_snapshot_committed.call()


func commit_logical_change(action_name: String, section: String, id: int, old_line: String, new_line: String, line_idx: int) -> bool:
	if line_idx == -1:
		return false
	
	var current_time = OS.get_ticks_msec()
	
	if history_index >= 0:
		var last = history_stack[history_index]
		if last.type == HistoryItem.Type.LOGICAL and last.target_id == id and last.action_name == action_name:
			if (current_time - last_commit_time) < 300:
				last.new_line_data = new_line
				last_commit_time = current_time
				return true
	
	_trim_history_tail()
	
	var item = HistoryItem.new()
	item.type = HistoryItem.Type.LOGICAL
	item.action_name = action_name
	item.target_section = section
	item.target_id = id
	item.old_line_data = old_line
	item.new_line_data = new_line
	item.cached_line_index = line_idx
	
	history_stack.append(item)
	history_index += 1
	_check_history_size()
	
	last_commit_time = current_time
	last_commit_action = action_name
	last_commit_id = id
	
	var msg = "[HISTORY] Logical Commit: %s (Ball %d, Line %d)" % [action_name, id, line_idx]
	print(msg)
	if on_log_message:
		on_log_message.call(msg)
	
	return true


func undo_visual_edit() -> void:
	if history_index <= 0:
		var msg = "[HISTORY] UNDO: Nothing to undo..."
		print(msg)
		if on_log_message:
			on_log_message.call(msg)
		return
	
	var item_being_undone = history_stack[history_index]
	
	history_index -= 1
	
	if item_being_undone.type == HistoryItem.Type.LOGICAL:
		_apply_logical_line(item_being_undone.target_section, item_being_undone.target_id, item_being_undone.old_line_data, item_being_undone.cached_line_index)
	else:
		var snapshot_idx = _find_nearest_snapshot(history_index)
		
		if snapshot_idx != -1:
			var snapshot = history_stack[snapshot_idx]
			_restore_snapshot(snapshot)
			
			for i in range(snapshot_idx + 1, history_index + 1):
				var log_item = history_stack[i]
				if log_item.type == HistoryItem.Type.LOGICAL:
					_apply_logical_line(log_item.target_section, log_item.target_id, log_item.new_line_data, log_item.cached_line_index)
		else:
			var msg = "[HISTORY] WARNING: No snapshot found to restore"
			print(msg)
			if on_log_message:
				on_log_message.call(msg)
	
	var msg = "[HISTORY] UNDO: %s (ID: %d)" % [item_being_undone.action_name, history_index]
	print(msg)
	if on_log_message:
		on_log_message.call(msg)


func redo_visual_edit() -> void:
	if history_index >= history_stack.size() - 1:
		var msg = "[HISTORY] REDO: Nothing to redo..."
		print(msg)
		if on_log_message:
			on_log_message.call(msg)
		return
	
	history_index += 1
	var item = history_stack[history_index]
	
	if item.type == HistoryItem.Type.SNAPSHOT:
		_restore_snapshot(item)
	else:
		_apply_logical_line(item.target_section, item.target_id, item.new_line_data, item.cached_line_index)
	
	var msg = "[HISTORY] REDO: %s" % item.action_name
	print(msg)
	if on_log_message:
		on_log_message.call(msg)


func _find_nearest_snapshot(from_index: int) -> int:
	var idx = from_index
	while idx >= 0:
		if history_stack[idx].type == HistoryItem.Type.SNAPSHOT:
			return idx
		idx -= 1
	return -1


func _restore_snapshot(item: HistoryItem) -> void:
	_set_text.call(item.full_text)
	_set_cursor_line.call(item.cursor_line)
	_set_cursor_col.call(item.cursor_col)
	_set_v_scroll.call(item.v_scroll)
	_set_h_scroll.call(item.h_scroll)


func _apply_logical_line(section: String, id: int, line_content: String, cached_idx: int = -1) -> void:
	var line_idx = -1
	
	if cached_idx != -1 and cached_idx < _get_line_count.call():
		var check_line = _get_line(cached_idx).strip_edges()
		
		if not check_line.empty() and not check_line.begins_with(";"):
			var parts = _split_line(check_line)
			var matches_cache = false
			
			if section in ["[Ballz Info]", "[Move]"]:
				if parts.size() > 0 and parts[0] == str(id):
					matches_cache = true
			elif section == "[Add Ball]":
				var relative = id
				if id >= 67:
					relative = id - 67
				if parts.size() > 0 and parts[0] == str(relative):
					matches_cache = true
			elif section == "[Linez]":
				if parts.size() >= 2 and (parts[0] == str(id) or parts[1] == str(id)):
					matches_cache = true
			
			if matches_cache:
				_set_line.call(cached_idx, line_content)
				return
	
	if on_snapshot_committed:
		on_snapshot_committed.call()


func _trim_history_tail() -> void:
	if history_index < history_stack.size() - 1:
		history_stack = history_stack.slice(0, history_index)


func _check_history_size() -> void:
	if history_stack.size() > max_history_size:
		history_stack.pop_front()
		history_index -= 1


func _create_snapshot_item(full_text: String, action_name: String) -> HistoryItem:
	var item = HistoryItem.new()
	item.type = HistoryItem.Type.SNAPSHOT
	item.action_name = action_name
	item.full_text = full_text
	item.cursor_line = _get_cursor_line.call()
	item.cursor_col = _get_cursor_col.call()
	item.v_scroll = _get_v_scroll.call()
	item.h_scroll = _get_h_scroll.call()
	return item


func _get_line(_idx: int) -> String:
	return ""


func _split_line(_line: String) -> Array:
	return []
