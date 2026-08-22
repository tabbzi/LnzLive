extends Tree
## VariationTree.gd
## Manages the tree view for selecting and configuring pet variations

var dog_generator = null
var lnz_parser = null
var _sections_map = null
var _current_file_path = ""

func setup(p_dog_generator: Node, p_lnz_parser: Node) -> void:
	dog_generator = p_dog_generator
	lnz_parser = p_lnz_parser
	_current_file_path = dog_generator.last_loaded_filepath
	_load_exclusions()
	populate_tree()

func populate_tree() -> void:
	if lnz_parser == null:
		return
	_sections_map = lnz_parser.get("sections_map")
	if _sections_map == null or typeof(_sections_map) != TYPE_DICTIONARY:
		return

	clear()
	var root: TreeItem = create_item()
	if root == null:
		return
	set_hide_root(true)
	set_columns(1)
	set_column_title(0, "Variation Viewer")
	set_column_titles_visible(true)

	var sections: Array = _get_sorted_sections()
	var config: Dictionary = _get_config()

	var global_ids: Array = _extract_global_ids(sections)
	var global_suffixes: Array = _extract_global_suffixes(sections)

	if global_ids.size() > 0:
		var g_folder: TreeItem = create_item(root)
		g_folder.set_text(0, "Global Variations")
		g_folder.set_selectable(0, false)

		for gid in global_ids:
			var item: TreeItem = create_item(g_folder)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_text(0, "Global Variation #" + str(gid))
			item.set_metadata(0, {"type": "global", "id": gid})
			item.set_checked(0, _is_global_id_active(sections, gid, config))

	if global_suffixes.size() > 0:
		var g_folder: TreeItem = _find_child_by_text(root, "Global Variations")
		if g_folder != null:
			for sk in global_suffixes:
				var parts: Array = (sk as String).split(".")
				var g_id: int = parts[0].to_int()
				var suffix: String = parts[1]
				var item: TreeItem = create_item(g_folder)
				item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				item.set_editable(0, true)
				item.set_text(0, "Global Variation #" + str(g_id) + "." + suffix + " (linked)")
				item.set_metadata(0, {"type": "global_suffix", "id": g_id, "suffix": suffix})
				item.set_checked(0, _is_global_suffix_active(sections, g_id, suffix, config))

	for section in sections:
		var section_data = _get_section_data(section)
		if section_data == null or not _section_has_variations(section_data):
			continue

		var section_item: TreeItem = create_item(root)
		section_item.set_text(0, section)
		section_item.set_selectable(0, false)

		var items: Array = _collect_top_level_items(section, section_data)
		items.sort_custom(self, "_sort_variation_items")

		for item_data in items:
			var item: TreeItem = create_item(section_item)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_text(0, _build_item_label(item_data))
			item.set_metadata(0, _build_item_meta(item_data, section))
			item.set_checked(0, _is_section_item_active(section, item_data, config))

			if item_data.get("type", "") == "bare" and item_data.get("int_count", 0) > 0:
				_render_subblock_children(section, item_data.id, item, config)

func _collect_top_level_items(section: String, section_data) -> Array:
	var items: Array = []
	for id in section_data:
		if id == 0:
			continue
		var val = section_data[id]

		if typeof(val) == TYPE_DICTIONARY:
			var display_name: String = _extract_display_name(val, id)
			var int_count: int = 0
			for key in val:
				if typeof(key) == TYPE_INT:
					int_count += 1

			items.append({
				"id": id, "type": "bare", "is_group": true,
				"is_linked": false, "int_count": int_count,
				"display_name": display_name, "start_line": 0
			})

			for key in val:
				if typeof(key) == TYPE_STRING:
					var subblock = val[key]
					var sub_display: String = ""
					if typeof(subblock) == TYPE_OBJECT and subblock.name != "Variation " + str(id):
						sub_display = subblock.name
					items.append({
						"id": id, "type": "suffix", "suffix": key,
						"is_group": false,
						"is_linked": typeof(subblock) == TYPE_OBJECT and subblock.is_linked,
						"display_name": sub_display,
						"start_line": subblock.start_line if typeof(subblock) == TYPE_OBJECT else 0
					})
		else:
			var var_block = val
			var display_name: String = ""
			if var_block.name != "Variation " + str(id):
				display_name = var_block.name
			items.append({
				"id": id, "type": "legacy", "is_group": false,
				"is_linked": false, "display_name": display_name,
				"start_line": var_block.start_line
			})
	return items

func _build_item_label(item_data) -> String:
	var label: String = "#" + str(item_data.id)
	var t: String = item_data.get("type", "")
	if t == "bare" and item_data.get("int_count", 0) > 0:
		label += " (" + str(item_data.int_count) + " subblocks)"
	elif t == "suffix":
		label += "." + item_data.suffix
		if item_data.get("is_linked", false):
			label += " (linked)"
	elif t == "legacy":
		label += " " + item_data.get("display_name", "")
	if item_data.get("display_name", "") != "" and t != "suffix":
		label += "; " + item_data.display_name
	return label

func _build_item_meta(item_data, section: String) -> Dictionary:
	var meta = {"type": "section", "section": section, "id": item_data.id}
	var t: String = item_data.get("type", "")
	if t == "bare":
		meta["is_group"] = true
	elif t == "suffix":
		meta["suffix"] = item_data.suffix
		meta["is_linked"] = item_data.get("is_linked", false)
	if item_data.get("start_line", 0) > 0:
		meta["start_line"] = item_data.start_line
	return meta

func _render_subblock_children(section: String, id: int, parent_item: TreeItem, config: Dictionary) -> void:
	var val = _get_id_data(section, id)
	if val == null:
		return
	var int_keys: Array = []
	for key in val:
		if typeof(key) == TYPE_INT:
			int_keys.append(key)
	int_keys.sort()
	for key in int_keys:
		var subblock = val[key]
		if typeof(subblock) != TYPE_OBJECT:
			continue
		var sub_item: TreeItem = create_item(parent_item)
		var display_name: String = subblock.name
		if display_name == "Variation " + str(id):
			display_name = ""
		var label: String = "#" + str(id) + " (" + str(key) + ")"
		if display_name != "":
			label += "; " + display_name
		
		sub_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		sub_item.set_editable(0, true)
		
		sub_item.set_text(0, label)
		sub_item.set_metadata(0, {
			"type": "section", "section": section, "id": id,
			"subblock_key": key, "start_line": subblock.start_line
		})
		sub_item.set_checked(0, _is_subblock_active(config, section, id, key))

func _sort_variation_items(a, b) -> bool:
	var at: String = a.get("type", "")
	var bt: String = b.get("type", "")
	if at == "bare" and bt != "bare":
		return true
	if at != "bare" and bt == "bare":
		return false
	if a.id < b.id:
		return true
	if a.id > b.id:
		return false
	if at == "suffix" and bt != "suffix":
		return true
	return false

func _ready() -> void:
	connect("item_edited", self, "_on_item_edited")
	connect("item_selected", self, "_on_item_selected")

func _on_item_edited() -> void:
	var item: TreeItem = get_edited()
	if item == null or get_edited_column() != 0:
		return
	var meta = item.get_metadata(0)
	if meta == null:
		return
	var checked: bool = item.is_checked(0)
	var config: Dictionary = _get_config()

	var mtype: String = meta.get("type", "")
	if mtype == "global":
		_handle_global_toggle(meta.id, checked, config)
	elif mtype == "global_suffix":
		_handle_global_suffix_toggle(meta.id, meta.suffix, checked, config)
	elif mtype == "section":
		_handle_section_toggle(meta, checked, config)

	_update_tree_checks(config)
	_sync_parser_exclusions(config)
	dog_generator.recompose_model()

func _on_item_selected() -> void:
	var item: TreeItem = get_selected()
	if item == null:
		return
	var meta = item.get_metadata(0)
	if meta != null and meta.has("start_line"):
		var lnz_text_edit: Node = get_tree().root.get_node(
			"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit"
		)
		if lnz_text_edit != null:
			lnz_text_edit.cursor_set_line(meta.start_line)
			lnz_text_edit.center_viewport_to_cursor()

func _handle_global_toggle(gid: int, checked: bool, config: Dictionary) -> void:
	var sections: Array = _get_sorted_sections()

	_sync_global_siblings(gid)

	for s in sections:
		var sec_data = _get_section_data(s)
		if sec_data != null and sec_data.has(gid):
			config[s] = [0, gid]
		else:
			config[s] = _build_fallback_array(s)

func _handle_global_suffix_toggle(gid: int, suffix: String, checked: bool, config: Dictionary) -> void:
	var sections: Array = _get_sorted_sections()
	var suffix_key: String = _make_suffix_key(gid, suffix)
	for s in sections:
		var id_data = _get_id_data(s, gid)
		if id_data == null or not id_data.has(suffix):
			continue
		if checked:
			config[s] = [0, gid, suffix_key]
		else:
			config[s].erase(suffix_key)
			if config[s].has(gid):
				config[s].erase(gid)
			config[s] = _build_fallback_array(s)

func _handle_section_toggle(meta, checked: bool, config: Dictionary) -> void:
	var section: String = meta.section
	var id: int = meta.id

	if not config.has(section):
		config[section] = [0]

	if meta.get("is_group", false):
		_handle_bare_toggle(section, id, checked, config)
	elif meta.has("suffix"):
		_handle_suffix_toggle(section, id, meta, checked, config)
	elif meta.has("subblock_key"):
		_handle_subblock_toggle(section, id, meta.subblock_key, checked, config)
	else:
		_handle_legacy_toggle(section, id, checked, config)

func _handle_bare_toggle(section: String, id: int, checked: bool, config: Dictionary) -> void:
	if checked:
		config[section] = [0, id]
		if _has_linked_suffix(section, id):
			_broadcast_linked_suffix(section, id, config)
		
		var excl_key: String = section + "_excluded"
		var list_key: String = "excluded_" + str(id)
		if config.has(excl_key) and config[excl_key].has(list_key):
			config[excl_key].erase(list_key)
			if config[excl_key].empty():
				config.erase(excl_key)
		_save_exclusions()
	else:
		if config.has(section) and config[section].has(id):
			config[section].erase(id)
		config[section] = _build_fallback_array(section)

func _handle_suffix_toggle(section: String, id: int, meta, checked: bool, config: Dictionary) -> void:
	var suffix: String = meta.suffix
	var is_linked: bool = meta.get("is_linked", false)
	var suffix_key: String = _make_suffix_key(id, suffix)

	if checked:
		_clear_other_numbers(section, id, config)
		if not config[section].has(id):
			config[section].append(id)
		if not config[section].has(suffix_key):
			config[section].append(suffix_key)
		if is_linked:
			_broadcast_linked_suffix(section, id, config, suffix)
	else:
		config[section].erase(suffix_key)
		if is_linked:
			_deactivate_linked_suffix(section, id, suffix, config)
		if _should_deactivate_id(section, id, config):
			_deactivate_and_fallback(section, id, config)

func _handle_subblock_toggle(section: String, id: int, subblock_key, checked: bool, config: Dictionary) -> void:
	if checked:
		if not config[section].has(id):
			config[section].append(id)
		_remove_exclusion(section, id, subblock_key)
	else:
		var id_data = _get_id_data(section, id)
		if id_data != null:
			var has_other: bool = false
			for k in id_data:
				if typeof(k) != TYPE_INT:
					continue
				if k != subblock_key and _is_subblock_active(config, section, id, k):
					has_other = true
					break
			
			if has_other:
				_add_exclusion(section, id, subblock_key)
			else:
				if config[section].has(id):
					config[section].erase(id)
				config[section] = _build_fallback_array(section)

func _handle_legacy_toggle(section: String, id: int, checked: bool, config: Dictionary) -> void:
	if checked:
		config[section] = [0, id]
	else:
		config[section].erase(id)
		config[section] = _build_fallback_array(section)

func _has_linked_suffix(section: String, id: int) -> bool:
	var id_data = _get_id_data(section, id)
	if id_data == null:
		return false
	for key in id_data:
		if typeof(key) == TYPE_STRING:
			return true
	return false

func _broadcast_linked_suffix(source_section: String, source_id: int, config: Dictionary, source_suffix: String = "") -> void:
	if source_suffix == "":
		var id_data = _get_id_data(source_section, source_id)
		if id_data == null:
			return
		for key in id_data:
			if typeof(key) == TYPE_STRING:
				source_suffix = key
				break
		if source_suffix == "":
			return

	var suffix_key: String = _make_suffix_key(source_id, source_suffix)
	var sections: Array = _get_sorted_sections()
	for section in sections:
		if section == source_section:
			continue
		var id_data = _get_id_data(section, source_id)
		if id_data == null or not id_data.has(source_suffix):
			continue
		config[section] = [0, source_id, suffix_key]

func _deactivate_linked_suffix(source_section: String, source_id: int, source_suffix: String, config: Dictionary) -> void:
	var suffix_key: String = _make_suffix_key(source_id, source_suffix)
	var sections: Array = _get_sorted_sections()
	for section in sections:
		if section == source_section:
			continue
		var id_data = _get_id_data(section, source_id)
		if id_data == null or not id_data.has(source_suffix):
			continue
		if config.has(section) and config[section].has(suffix_key):
			config[section].erase(suffix_key)
		if _should_deactivate_id(section, source_id, config) and config.has(section):
			if config[section].has(source_id):
				config[section].erase(source_id)
			config[section] = _build_fallback_array(section)

func _clear_other_numbers(section: String, keep_id: int, config: Dictionary) -> void:
	if not config.has(section):
		return
	var cfg: Array = config[section]
	var to_remove: Array = []
	for entry in cfg:
		if entry == 0:
			continue
		if typeof(entry) == TYPE_INT:
			if entry != keep_id:
				to_remove.append(entry)
		elif entry is String:
			var parts: Array = (entry as String).split(".")
			if parts.size() >= 1 and parts[0].to_int() != keep_id:
				to_remove.append(entry)
	for entry in to_remove:
		cfg.erase(entry)

func _build_fallback_array(section: String) -> Array:
	var fallback: int = _find_fallback_id(section)
	if fallback > 0:
		return [0, fallback]
	return [0]

func _find_fallback_id(section: String) -> int:
	var sec_data = _get_section_data(section)
	if sec_data == null:
		return 0
	if sec_data.has(1):
		return 1
	return _find_lowest_variation_id(sec_data)

func _find_lowest_variation_id(section_data) -> int:
	var lowest: int = 0
	for id in section_data:
		if id > 0 and (lowest == 0 or id < lowest):
			lowest = id
	return lowest

func _should_deactivate_id(section: String, id: int, config: Dictionary) -> bool:
	var id_data = _get_id_data(section, id)
	if id_data == null:
		return true
	var excl_config = config.get(section + "_excluded", {})
	var excl_list: Array = []
	if typeof(excl_config) == TYPE_DICTIONARY:
		var excl_key: String = "excluded_" + str(id)
		if excl_config.has(excl_key):
			excl_list = excl_config[excl_key]
	for k in id_data:
		if k == 0:
			continue
		if excl_list.has(k):
			continue
		return false
	return true

func _deactivate_and_fallback(section: String, id: int, config: Dictionary) -> void:
	if config.has(section):
		config[section].erase(id)
	config[section] = _build_fallback_array(section)

func _add_exclusion(section: String, id: int, subblock_key) -> void:
	var config: Dictionary = _get_config()
	var excl_key: String = section + "_excluded"
	if not config.has(excl_key):
		config[excl_key] = {}
	var list_key: String = "excluded_" + str(id)
	if not config[excl_key].has(list_key):
		config[excl_key][list_key] = []
	config[excl_key][list_key].append(subblock_key)
	_save_exclusions()

func _remove_exclusion(section: String, id: int, subblock_key) -> void:
	var config: Dictionary = _get_config()
	var excl_key: String = section + "_excluded"
	var list_key: String = "excluded_" + str(id)
	if config.has(excl_key) and config[excl_key].has(list_key):
		config[excl_key][list_key].erase(subblock_key)
		if config[excl_key][list_key].empty():
			config[excl_key].erase(list_key)
			if config[excl_key].empty():
				config.erase(excl_key)
	_save_exclusions()

func _clear_section_exclusions(section: String) -> void:
	var config: Dictionary = _get_config()
	config.erase(section + "_excluded")
	_save_exclusions()

func _sync_parser_exclusions(config: Dictionary) -> void:
	if lnz_parser == null:
		return
	var sync_data = {}
	for key in config:
		if key is String and (key as String).ends_with("_excluded"):
			var section_name: String = (key as String).trim_suffix("_excluded")
			sync_data[section_name] = config[key]
	lnz_parser.set_excluded_subblocks(sync_data)

func _save_exclusions() -> void:
	var path: String = _resolve_file_path()
	if path == "":
		return
	var config: Dictionary = _get_config()
	var exclusions = {}
	for key in config:
		if key is String and (key as String).ends_with("_excluded"):
			var section_name: String = (key as String).trim_suffix("_excluded")
			exclusions[section_name] = config[key]
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("exclusions", "data", exclusions)
	cf.save("user://lnz_exclusions_" + _get_file_hash() + ".cfg")

func _load_exclusions() -> void:
	var path: String = _resolve_file_path()
	if path == "":
		return
	var cf: ConfigFile = ConfigFile.new()
	if cf.load("user://lnz_exclusions_" + _get_file_hash() + ".cfg") != OK:
		return
	if cf.has_section_key("exclusions", "data"):
		var data = cf.get_value("exclusions", "data")
		if typeof(data) == TYPE_DICTIONARY:
			var config: Dictionary = _get_config()
			for section in data:
				config[section + "_excluded"] = data[section]

func _resolve_file_path() -> String:
	if _current_file_path != "":
		return _current_file_path
	if is_instance_valid(dog_generator):
		return dog_generator.last_loaded_filepath
	return ""

func _get_file_hash() -> String:
	var path: String = _resolve_file_path()
	if path == "":
		return "empty"
	return str(path.hash())

func _update_tree_checks(config: Dictionary) -> void:
	var root: TreeItem = get_root()
	if root == null:
		return
	_sync_item_checks(root, config)

func _sync_item_checks(item: TreeItem, config: Dictionary) -> void:
	var child: TreeItem = item.get_children()
	while child != null:
		var meta = child.get_metadata(0)
		if meta != null:
			var mtype: String = meta.get("type", "")
			if mtype == "global":
				child.set_checked(0, _is_global_id_active(_get_sorted_sections(), meta.id, config))
			elif mtype == "global_suffix":
				child.set_checked(0, _is_global_suffix_active(_get_sorted_sections(), meta.id, meta.suffix, config))
			elif mtype == "section":
				if meta.has("subblock_key"):
					child.set_checked(0, _is_subblock_active(config, meta.section, meta.id, meta.subblock_key))
				else:
					child.set_checked(0, _is_section_item_active(meta.section, meta, config))
		_sync_item_checks(child, config)
		child = child.get_next()


func _is_global_id_active(sections: Array, gid: int, config: Dictionary) -> bool:
	var any_exists: bool = false
	for s in sections:
		var sec_data = _get_section_data(s)
		if sec_data != null and sec_data.has(gid):
			any_exists = true
			var cfg = config.get(s, [])
			if typeof(cfg) != TYPE_ARRAY or not cfg.has(gid):
				return false
	return any_exists

func _is_global_suffix_active(sections: Array, gid: int, suffix: String, config: Dictionary) -> bool:
	var suffix_key: String = _make_suffix_key(gid, suffix)
	var any_exists: bool = false
	for s in sections:
		var id_data = _get_id_data(s, gid)
		if id_data != null and id_data.has(suffix):
			any_exists = true
			var cfg = config.get(s, [])
			if typeof(cfg) != TYPE_ARRAY or not cfg.has(suffix_key):
				return false
	return any_exists

func _is_section_item_active(section: String, item_data, config: Dictionary) -> bool:
	if not config.has(section):
		return false
	var cfg: Array = config[section]
	var is_active: bool = cfg.has(item_data.id)
	if item_data.get("type", "") == "suffix":
		is_active = is_active or cfg.has(_make_suffix_key(item_data.id, item_data.suffix))
	return is_active

func _is_subblock_active(config: Dictionary, section: String, id: int, subblock_key) -> bool:
	if not config.has(section) or not config[section].has(id):
		return false
	var excl_config = config.get(section + "_excluded", {})
	if typeof(excl_config) != TYPE_DICTIONARY:
		return true
	var excl_key: String = "excluded_" + str(id)
	if not excl_config.has(excl_key):
		return true
	var excl_list = excl_config[excl_key]
	if typeof(excl_list) != TYPE_ARRAY:
		return true
	return not excl_list.has(subblock_key)

func _find_child_by_text(parent: TreeItem, text: String) -> TreeItem:
	var child: TreeItem = parent.get_children()
	while child != null:
		if child.get_text(0) == text:
			return child
		child = child.get_next()
	return null

func _sync_global_siblings(gid: int) -> void:
	var root: TreeItem = get_root()
	if root == null:
		return
	var folder: TreeItem = _find_child_by_text(root, "Global Variations")
	if folder == null:
		return
	var child: TreeItem = folder.get_children()
	while child != null:
		var meta = child.get_metadata(0)
		if meta != null and meta.get("id", -1) != gid:
			child.set_checked(0, false)
		child = child.get_next()

func _get_config() -> Dictionary:
	return dog_generator.current_variation_config

func _get_sorted_sections() -> Array:
	var sections: Array = _sections_map.keys()
	sections.sort()
	return sections

func _get_section_data(section: String):
	if _sections_map == null or not _sections_map.has(section):
		return null
	var data = _sections_map[section]
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return data

func _get_id_data(section: String, id: int):
	var sec_data = _get_section_data(section)
	if sec_data == null or not sec_data.has(id):
		return null
	var data = sec_data[id]
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return data

func _make_suffix_key(id: int, suffix: String) -> String:
	return str(id) + "." + suffix

func _extract_display_name(id_data, id: int) -> String:
	for key in id_data:
		if typeof(id_data[key]) == TYPE_OBJECT:
			var blk = id_data[key]
			if blk.name != "Variation " + str(id):
				return blk.name
			break
	return ""

func _section_has_variations(section_data) -> bool:
	for id in section_data:
		if id > 0:
			return true
	return false

func _extract_global_ids(sections: Array) -> Array:
	var id_counts = {}
	for section in sections:
		var sec_data = _get_section_data(section)
		if sec_data == null:
			continue
		for id in sec_data:
			if id == 0:
				continue
			if not id_counts.has(id):
				id_counts[id] = 0
			id_counts[id] += 1
	var result: Array = []
	for id in id_counts:
		if id_counts[id] > 1:
			result.append(id)
	result.sort()
	return result

func _extract_global_suffixes(sections: Array) -> Array:
	var suffix_counts = {}
	for section in sections:
		var sec_data = _get_section_data(section)
		if sec_data == null:
			continue
		for id in sec_data:
			if id == 0:
				continue
			var val = sec_data[id]
			if typeof(val) == TYPE_DICTIONARY:
				for key in val:
					if typeof(key) == TYPE_STRING:
						var sk: String = _make_suffix_key(id, key)
						if not suffix_counts.has(sk):
							suffix_counts[sk] = 0
						suffix_counts[sk] += 1
	var result: Array = []
	for sk in suffix_counts:
		if suffix_counts[sk] > 1:
			result.append(sk)
	result.sort()
	return result
