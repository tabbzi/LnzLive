extends Tree
## VariationTree.gd - Manages the tree view for selecting and configuring pet variations

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

func randomize_variations() -> void:
	var config = dog_generator.current_variation_config
	var sections = _sorted_sections()
	var all_blocks = {}
	for section in sections:
		var sec_data = _get_section_data(section)
		if sec_data == null or typeof(sec_data) != TYPE_DICTIONARY:
			continue
		if not config.has(section):
			config[section] = {}
		if not all_blocks.has(section):
			all_blocks[section] = {}
		for id in sec_data:
			if id == 0:
				continue
			var val = sec_data[id]
			if typeof(val) == TYPE_DICTIONARY:
				for sk in val:
					if not all_blocks[section].has(sk):
						all_blocks[section][sk] = []
					all_blocks[section][sk].append(id)
			elif typeof(val) == TYPE_OBJECT:
				var sk = val.subblock_key if val.has("subblock_key") else 0
				if not all_blocks[section].has(sk):
					all_blocks[section][sk] = []
				all_blocks[section][sk].append(id)

	var picked_suffixes = {}
	for section in all_blocks:
		for sk in all_blocks[section]:
			var ids = all_blocks[section][sk]
			if ids.size() == 0:
				continue
			var picked_id = ids[randi() % ids.size()]
			var sub = _get_subblock(section, picked_id, sk)
			if typeof(sub) == TYPE_OBJECT and sub.is_linked:
				var suffix_str = str(sk) if typeof(sk) == TYPE_STRING else ""
				if suffix_str != "":
					config[section][sk] = _make_suffix_key(picked_id, suffix_str)
					picked_suffixes[section + "." + str(sk)] = {"id": picked_id, "suffix": suffix_str}
				else:
					config[section][sk] = picked_id
			else:
				config[section][sk] = picked_id

	for block_key in picked_suffixes:
		var pick = picked_suffixes[block_key]
		var parts = block_key.split(".")
		var source_section = parts[0]
		var suffix_key = str(pick.id) + "." + pick.suffix
		for section in sections:
			if section == source_section:
				continue
			var sec_data = _get_section_data(section)
			if sec_data == null or not sec_data.has(pick.id):
				continue
			var id_data = sec_data[pick.id]
			if typeof(id_data) == TYPE_DICTIONARY and id_data.has(pick.suffix):
				var sk_val = id_data[pick.suffix]
				if typeof(sk_val) == TYPE_OBJECT:
					if not config.has(section):
						config[section] = {}
					config[section][pick.suffix] = suffix_key

	for section in sections:
		_rebuild_section_exclusions(section, config)
	_update_tree_checks(config)
	_sync_parser_exclusions(config)
	dog_generator.recompose_model()

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

	var sections = _sorted_sections()
	var config = dog_generator.current_variation_config
	var global_ids = _extract_global_ids(sections)
	var global_suffixes = _extract_global_suffixes(sections)

	if global_ids.size() > 0:
		var g_folder: TreeItem = create_item(root)
		g_folder.set_text(0, "Global Variations")
		g_folder.set_selectable(0, false)
		for gid in global_ids:
			var item: TreeItem = create_item(g_folder)
			_setup_check_item(item, "Global Variation #" + str(gid), {"type": "global", "id": gid})
			item.set_checked(0, _is_global_id_active(sections, gid, config))

	if global_suffixes.size() > 0:
		var g_folder: TreeItem = _find_child_by_text(root, "Global Variations")
		if g_folder != null:
			for sk in global_suffixes:
				var parts: Array = (sk as String).split(".")
				var g_id: int = parts[0].to_int()
				var suffix: String = parts[1]
				var item: TreeItem = create_item(g_folder)
				_setup_check_item(item, "Global Variation #" + str(g_id) + "." + suffix + " (linked)", {"type": "global_suffix", "id": g_id, "suffix": suffix})
				item.set_checked(0, _is_global_suffix_active(sections, g_id, suffix, config))

	for section in sections:
		var section_data = _get_section_data(section)
		if section_data == null or not _section_has_variations(section_data):
			continue
		var section_item: TreeItem = create_item(root)
		section_item.set_text(0, section)
		section_item.set_selectable(0, false)

		var items = _collect_top_level_items(section, section_data)
		items.sort_custom(self, "_sort_variation_items")
		var sorted_block_keys = _block_keys_sorted(section_data)

		for subblock_key in sorted_block_keys:
			var block_item: TreeItem = create_item(section_item)
			block_item.set_text(0, "Block " + str(subblock_key))
			block_item.set_selectable(0, false)

			var child_items = []
			for item_data in items:
				var t = item_data.get("type", "")
				if t == "bare":
					var id_data = _get_id_data(section, item_data.id)
					if id_data != null and typeof(id_data) == TYPE_DICTIONARY and id_data.has(subblock_key):
						var clone = item_data.duplicate()
						clone["subblock_key"] = subblock_key
						child_items.append(clone)
				elif t == "suffix" and str(item_data.get("subblock_key", "")) == str(subblock_key):
					child_items.append(item_data)
				elif t == "legacy" and str(subblock_key) == "0":
					var clone = item_data.duplicate()
					clone["subblock_key"] = 0
					child_items.append(clone)

			child_items.sort_custom(self, "_sort_variation_items")
			for item_data in child_items:
				var item: TreeItem = create_item(block_item)
				_setup_check_item(item, _build_item_label(item_data), _build_item_meta(item_data, section, subblock_key))
				item.set_checked(0, _is_section_item_active(section, item_data, config))

func _setup_check_item(item: TreeItem, text: String, meta: Dictionary) -> void:
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_text(0, text)
	item.set_metadata(0, meta)

func _block_keys_sorted(section_data) -> Array:
	var keys = []
	for id in section_data:
		if id == 0:
			continue
		var val = section_data[id]
		if typeof(val) == TYPE_DICTIONARY:
			for sk in val:
				if not keys.has(sk):
					keys.append(sk)
	keys.sort()
	return keys

func _collect_top_level_items(section: String, section_data) -> Array:
	var items: Array = []
	for id in section_data:
		if id == 0:
			continue
		var val = section_data[id]
		if typeof(val) == TYPE_DICTIONARY:
			var display_name = _extract_display_name(val, id)
			var int_count = 0
			var first_start_line = 0
			for key in val:
				if typeof(key) == TYPE_INT:
					int_count += 1
				if typeof(val[key]) == TYPE_OBJECT and val[key].start_line > 0 and first_start_line == 0:
					first_start_line = val[key].start_line
			items.append({"id": id, "type": "bare", "is_group": true, "is_linked": false, "int_count": int_count, "display_name": display_name, "start_line": first_start_line})
			for key in val:
				if typeof(key) == TYPE_STRING:
					var subblock = val[key]
					var sub_display = ""
					if typeof(subblock) == TYPE_OBJECT and subblock.name != "Variation " + str(id):
						sub_display = subblock.name
					items.append({"id": id, "type": "suffix", "suffix": key, "is_group": false, "is_linked": typeof(subblock) == TYPE_OBJECT and subblock.is_linked, "display_name": sub_display, "start_line": subblock.start_line if typeof(subblock) == TYPE_OBJECT else 0, "subblock_key": key})
		else:
			var var_block = val
			var display_name = ""
			if var_block.name != "Variation " + str(id):
				display_name = var_block.name
			items.append({"id": id, "type": "bare", "is_group": true, "is_linked": false, "display_name": display_name, "start_line": var_block.start_line, "subblock_key": 0})
	return items

func _build_item_label(item_data) -> String:
	var label = "#" + str(item_data.id)
	var t = item_data.get("type", "")
	if t == "suffix":
		label += "." + item_data.suffix
		if item_data.get("is_linked", false):
			label += " (linked)"
	elif t == "legacy":
		label += " " + item_data.get("display_name", "")
	if item_data.get("display_name", "") != "" and t != "suffix":
		label += "; " + item_data.display_name
	return label

func _build_item_meta(item_data, section: String, subblock_key) -> Dictionary:
	var meta = {"type": "section", "section": section, "id": item_data.id, "subblock_key": subblock_key}
	var t = item_data.get("type", "")
	if t == "bare":
		meta["is_group"] = true
		var id_data = _get_id_data(section, item_data.id)
		if id_data != null and typeof(id_data) == TYPE_DICTIONARY and id_data.has(subblock_key):
			var blk = id_data[subblock_key]
			if typeof(blk) == TYPE_OBJECT and blk.start_line > 0:
				meta["start_line"] = blk.start_line
	elif t == "suffix":
		meta["suffix"] = item_data.suffix
		meta["is_linked"] = item_data.get("is_linked", false)
	if item_data.has("start_line") and item_data.start_line > 0 and not meta.has("start_line"):
		meta["start_line"] = item_data.start_line
	return meta

func _sort_variation_items(a, b) -> bool:
	var at = a.get("type", "")
	var bt = b.get("type", "")
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
	_create_randomize_button()
	randomize()

func _create_randomize_button() -> void:
	var hbox = HBoxContainer.new()
	add_child(hbox)
	var btn = Button.new()
	btn.text = "Randomize Variation (click me!)"
	btn.connect("pressed", self, "_on_randomize_pressed")
	hbox.add_child(btn)

func _on_randomize_pressed() -> void:
	randomize_variations()

func _on_item_edited() -> void:
	var item: TreeItem = get_edited()
	if item == null or get_edited_column() != 0:
		return
	var meta = item.get_metadata(0)
	if meta == null:
		return
	var checked: bool = item.is_checked(0)
	var config = dog_generator.current_variation_config
	var mtype = meta.get("type", "")
	if mtype == "global":
		_handle_global_toggle(meta.id, checked, config)
	elif mtype == "global_suffix":
		_handle_global_suffix_toggle(meta.id, meta.suffix, checked, config)
	elif mtype == "section":
		_handle_section_toggle(meta, checked, config)

	var sections = _sorted_sections()
	for section in sections:
		_rebuild_section_exclusions(section, config)
	_update_tree_checks(config)
	_sync_parser_exclusions(config)
	dog_generator.recompose_model()

func _on_item_selected() -> void:
	var item: TreeItem = get_selected()
	if item == null:
		return
	var meta = item.get_metadata(0)
	if meta != null and meta.has("start_line"):
		var lnz_text_edit: Node = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
		if lnz_text_edit != null:
			lnz_text_edit.cursor_set_line(meta.start_line)
			lnz_text_edit.center_viewport_to_cursor()


func _handle_global_toggle(gid: int, checked: bool, config: Dictionary) -> void:
	var sections = _sorted_sections()
	_sync_global_siblings(gid)
	for s in sections:
		var sec_data = _get_section_data(s)
		if sec_data != null and sec_data.has(gid):
			_ensure_config_section(config, s)
			var id_data = _get_id_data(s, gid)
			if id_data != null and typeof(id_data) == TYPE_DICTIONARY:
				for sk in id_data:
					config[s][sk] = gid
			elif id_data != null:
				config[s][0] = gid
		else:
			_ensure_config_section(config, s)
			if config[s] == null or typeof(config[s]) != TYPE_DICTIONARY or config[s].empty():
				var fallback_id = _find_fallback_id(s)
				if fallback_id > 0:
					_apply_fallback(config, s, fallback_id)

func _handle_global_suffix_toggle(gid: int, suffix: String, checked: bool, config: Dictionary) -> void:
	var sections = _sorted_sections()
	var suffix_key = _make_suffix_key(gid, suffix)
	for s in sections:
		var id_data = _get_id_data(s, gid)
		if id_data == null or not id_data.has(suffix):
			continue
		if checked:
			_ensure_config_section(config, s)
			if id_data != null and typeof(id_data) == TYPE_DICTIONARY:
				for sk in id_data:
					config[s][sk] = suffix_key
		else:
			if config.has(s) and config[s].has(suffix):
				config[s].erase(suffix)
			if config.has(s) and config[s].empty():
				var fallback_id = _find_fallback_id(s)
				if fallback_id > 0:
					_apply_fallback(config, s, fallback_id)

func _handle_section_toggle(meta, checked: bool, config: Dictionary) -> void:
	var section = meta.section
	var id = meta.id
	_ensure_config_section(config, section)
	if meta.get("is_group", false):
		_handle_bare_toggle(section, id, checked, config, meta.get("subblock_key"))
	elif meta.has("suffix"):
		_handle_suffix_toggle(section, id, meta, checked, config)
	elif meta.has("subblock_key"):
		_handle_subblock_toggle(section, id, meta.subblock_key, checked, config)

func _handle_bare_toggle(section: String, id: int, checked: bool, config: Dictionary, subblock_key = null) -> void:
	if checked:
		if subblock_key != null:
			config[section][subblock_key] = id
		else:
			var id_data = _get_id_data(section, id)
			if id_data != null and typeof(id_data) == TYPE_DICTIONARY:
				for sk in id_data:
					config[section][sk] = id
			else:
				config[section][0] = id
		if _has_linked_suffix(section, id):
			_broadcast_linked_suffix(section, id, config)
	else:
		if subblock_key != null and config.has(section):
			config[section].erase(subblock_key)
			var fallback_id = _get_fallback_id(section, subblock_key)
			if fallback_id > 0:
				config[section][subblock_key] = fallback_id
		if config.has(section) and config[section].empty():
			config[section] = _build_fallback_dict(section)

func _handle_suffix_toggle(section: String, id: int, meta, checked: bool, config: Dictionary) -> void:
	var suffix = meta.suffix
	var is_linked = meta.get("is_linked", false)
	var suffix_key = _make_suffix_key(id, suffix)
	if checked:
		_clear_other_numbers(section, id, config)
		_ensure_config_section(config, section)
		config[section][suffix] = suffix_key
		if is_linked:
			_broadcast_linked_suffix(section, id, config, suffix)
	else:
		if config.has(section) and config[section].has(suffix):
			config[section].erase(suffix)
		if is_linked:
			_deactivate_linked_suffix(section, id, suffix, config)
		if _should_deactivate_id(section, id, config):
			_deactivate_and_fallback(section, id, config)

func _handle_subblock_toggle(section: String, id: int, subblock_key, checked: bool, config: Dictionary) -> void:
	if checked:
		_ensure_config_section(config, section)
		config[section][subblock_key] = id
	else:
		if config.has(section) and config[section].has(subblock_key):
			config[section].erase(subblock_key)
			var fallback_id = _get_fallback_id(section, subblock_key)
			if fallback_id > 0:
				config[section][subblock_key] = fallback_id
		if config.has(section) and config[section].empty():
			config[section] = _build_fallback_dict_for_subblock(section, subblock_key)

func _rebuild_section_exclusions(section: String, config: Dictionary) -> void:
	var sec_data = _get_section_data(section)
	if sec_data == null:
		return
	var cfg = config.get(section, {})
	if typeof(cfg) != TYPE_DICTIONARY:
		return

	var excl_key = section + "_excluded"
	config[excl_key] = {}
	var active_ids = []
	for sk in cfg:
		var val = cfg[sk]
		var base_id = _base_id_from_val(val)
		if base_id != 0 and not active_ids.has(base_id):
			active_ids.append(base_id)

	for id in active_ids:
		if sec_data.has(id):
			var id_data = sec_data[id]
			if typeof(id_data) == TYPE_DICTIONARY:
				var excluded_for_id = []
				for sk in id_data:
					var active_val = cfg.get(sk)
					if not _val_matches_id(active_val, id):
						excluded_for_id.append(sk)
				if excluded_for_id.size() > 0:
					config[excl_key]["excluded_" + str(id)] = excluded_for_id

	if config[excl_key].empty():
		config.erase(excl_key)
	_save_exclusions()

func _base_id_from_val(val) -> int:
	if typeof(val) == TYPE_INT:
		return val
	if typeof(val) == TYPE_STRING:
		var parts = (val as String).split(".")
		if parts.size() > 0 and parts[0].is_valid_integer():
			return parts[0].to_int()
	return 0

func _val_matches_id(val, id) -> bool:
	if typeof(val) == TYPE_INT:
		return val == id
	if typeof(val) == TYPE_STRING:
		var parts = (val as String).split(".")
		return parts.size() > 0 and parts[0].to_int() == id
	return false

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
	var suffix_key = _make_suffix_key(source_id, source_suffix)
	var sections = _sorted_sections()
	for section in sections:
		if section == source_section:
			continue
		var id_data = _get_id_data(section, source_id)
		if id_data == null or not id_data.has(source_suffix):
			continue
		_ensure_config_section(config, section)
		config[section][source_suffix] = suffix_key

func _deactivate_linked_suffix(source_section: String, source_id: int, source_suffix: String, config: Dictionary) -> void:
	var suffix_key = _make_suffix_key(source_id, source_suffix)
	var sections = _sorted_sections()
	for section in sections:
		if section == source_section:
			continue
		var id_data = _get_id_data(section, source_id)
		if id_data == null or not id_data.has(source_suffix):
			continue
		if config.has(section) and config[section].has(source_suffix):
			config[section].erase(source_suffix)
		if _should_deactivate_id(section, source_id, config) and config.has(section):
			if config[section].empty():
				var fallback_id = _find_fallback_id(section)
				if fallback_id > 0:
					_apply_fallback(config, section, fallback_id)

func _clear_other_numbers(section: String, keep_id: int, config: Dictionary) -> void:
	if not config.has(section):
		return
	var keys_to_erase = []
	for sk in config[section]:
		var val = config[section][sk]
		if typeof(val) == TYPE_INT and val != keep_id and val != 0:
			keys_to_erase.append(sk)
		elif typeof(val) == TYPE_STRING:
			var parts = (val as String).split(".")
			if parts.size() >= 1 and parts[0].to_int() != keep_id:
				keys_to_erase.append(sk)
	for sk in keys_to_erase:
		config[section].erase(sk)

func _should_deactivate_id(section: String, id: int, config: Dictionary) -> bool:
	var id_data = _get_id_data(section, id)
	if id_data == null:
		return true
	var excl_config = config.get(section + "_excluded", {})
	var excl_list = []
	if typeof(excl_config) == TYPE_DICTIONARY:
		var excl_key = "excluded_" + str(id)
		if excl_config.has(excl_key):
			excl_list = excl_config[excl_key]
	for k in id_data:
		if typeof(k) == TYPE_INT and k == 0:
			continue
		if (typeof(k) == TYPE_STRING or typeof(k) == TYPE_INT) and excl_list.has(k):
			continue
		if config.has(section) and config[section].has(k):
			return false
	return true

func _deactivate_and_fallback(section: String, id: int, config: Dictionary) -> void:
	if config.has(section):
		var keys_to_erase = []
		for sk in config[section]:
			var val = config[section][sk]
			if typeof(val) == TYPE_INT and val == id:
				keys_to_erase.append(sk)
			elif typeof(val) == TYPE_STRING:
				var parts = (val as String).split(".")
				if parts.size() >= 1 and parts[0].to_int() == id:
					keys_to_erase.append(sk)
		for sk in keys_to_erase:
			config[section].erase(sk)
	config[section] = _build_fallback_dict(section)


func _build_fallback_dict(section: String) -> Dictionary:
	var fallback = _find_fallback_id(section)
	var result = {}
	if fallback > 0:
		var sec_data = _get_section_data(section)
		if sec_data != null and sec_data.has(fallback):
			var val = sec_data[fallback]
			if typeof(val) == TYPE_DICTIONARY:
				for sk in val:
					result[sk] = fallback
			else:
				result[0] = fallback
	return result

func _build_fallback_dict_for_subblock(section: String, subblock_key) -> Dictionary:
	var fallback = _find_fallback_id(section)
	var result = {}
	if fallback > 0:
		var sec_data = _get_section_data(section)
		if sec_data != null and sec_data.has(fallback):
			var val = sec_data[fallback]
			if typeof(val) == TYPE_DICTIONARY:
				if val.has(subblock_key):
					result[subblock_key] = fallback
				else:
					for sk in val:
						result[sk] = fallback
			else:
				result[0] = fallback
	return result

func _get_fallback_id(section: String, subblock_key) -> int:
	var fallback = _find_fallback_id(section)
	if fallback > 0:
		var sec_data = _get_section_data(section)
		if sec_data != null and sec_data.has(fallback):
			var val = sec_data[fallback]
			if typeof(val) == TYPE_DICTIONARY and val.has(subblock_key):
				return fallback
	return fallback

func _find_fallback_id(section: String) -> int:
	var sec_data = _get_section_data(section)
	if sec_data == null:
		return 0
	if sec_data.has(1):
		return 1
	var lowest = 0
	for id in sec_data:
		if id > 0 and (lowest == 0 or id < lowest):
			lowest = id
	return lowest

func _apply_fallback(config: Dictionary, section: String, fallback_id: int) -> void:
	var sec_data = _get_section_data(section)
	if sec_data == null or not sec_data.has(fallback_id):
		config[section][0] = fallback_id
		return
	var val = sec_data[fallback_id]
	if typeof(val) == TYPE_DICTIONARY:
		for sk in val:
			config[section][sk] = fallback_id
	else:
		config[section][0] = fallback_id


func _add_exclusion(section: String, id: int, subblock_key) -> void:
	var config = dog_generator.current_variation_config
	var excl_key = section + "_excluded"
	if not config.has(excl_key):
		config[excl_key] = {}
	var list_key = "excluded_" + str(id)
	if not config[excl_key].has(list_key):
		config[excl_key][list_key] = []
	config[excl_key][list_key].append(subblock_key)
	_save_exclusions()

func _remove_exclusion(section: String, id: int, subblock_key) -> void:
	var config = dog_generator.current_variation_config
	var excl_key = section + "_excluded"
	var list_key = "excluded_" + str(id)
	if config.has(excl_key) and config[excl_key].has(list_key):
		config[excl_key][list_key].erase(subblock_key)
		if config[excl_key][list_key].empty():
			config[excl_key].erase(list_key)
			if config[excl_key].empty():
				config.erase(excl_key)
	_save_exclusions()

func _clear_section_exclusions(section: String) -> void:
	var config = dog_generator.current_variation_config
	config.erase(section + "_excluded")
	_save_exclusions()

func _sync_parser_exclusions(config: Dictionary) -> void:
	if lnz_parser == null:
		return
	var sync_data = {}
	for key in config:
		if key is String and (key as String).ends_with("_excluded"):
			sync_data[(key as String).trim_suffix("_excluded")] = config[key]
	lnz_parser.set_excluded_subblocks(sync_data)

func _save_exclusions() -> void:
	var path = _resolve_file_path()
	if path == "":
		return
	var config = dog_generator.current_variation_config
	var exclusions = {}
	for key in config:
		if key is String and (key as String).ends_with("_excluded"):
			exclusions[(key as String).trim_suffix("_excluded")] = config[key]
	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("exclusions", "data", exclusions)
	cf.save("user://lnz_exclusions_" + _get_file_hash() + ".cfg")

func _load_exclusions() -> void:
	var path = _resolve_file_path()
	if path == "":
		return
	var cf: ConfigFile = ConfigFile.new()
	if cf.load("user://lnz_exclusions_" + _get_file_hash() + ".cfg") != OK:
		return
	if cf.has_section_key("exclusions", "data"):
		var data = cf.get_value("exclusions", "data")
		if typeof(data) == TYPE_DICTIONARY:
			var config = dog_generator.current_variation_config
			for section in data:
				config[section + "_excluded"] = data[section]


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
			var mtype = meta.get("type", "")
			if mtype == "global":
				var sections = _sorted_sections()
				child.set_checked(0, _is_global_id_active(sections, meta.id, config))
			elif mtype == "global_suffix":
				var sections = _sorted_sections()
				child.set_checked(0, _is_global_suffix_active(sections, meta.id, meta.suffix, config))
			elif mtype == "section":
				if meta.has("subblock_key"):
					child.set_checked(0, _is_subblock_active(config, meta.section, meta.id, meta.subblock_key))
				else:
					child.set_checked(0, _is_section_item_active(meta.section, meta, config))
		_sync_item_checks(child, config)
		child = child.get_next()

func _is_global_id_active(sections: Array, gid: int, config: Dictionary) -> bool:
	var any_exists = false
	for s in sections:
		var sec_data = _get_section_data(s)
		if sec_data != null and sec_data.has(gid):
			any_exists = true
			var cfg = config.get(s, {})
			if typeof(cfg) != TYPE_DICTIONARY:
				return false
			var active_for_any = false
			for sk in cfg:
				var val = cfg[sk]
				if _val_matches_id(val, gid):
					active_for_any = true
					break
			if not active_for_any:
				return false
	return any_exists

func _is_global_suffix_active(sections: Array, gid: int, suffix: String, config: Dictionary) -> bool:
	var suffix_key = _make_suffix_key(gid, suffix)
	var any_exists = false
	for s in sections:
		var id_data = _get_id_data(s, gid)
		if id_data != null and id_data.has(suffix):
			any_exists = true
			var cfg = config.get(s, {})
			if typeof(cfg) != TYPE_DICTIONARY:
				return false
			if not cfg.has(suffix):
				return false
			var val = cfg[suffix]
			var matches = typeof(val) == TYPE_STRING and val == suffix_key
			if not matches and typeof(val) == TYPE_INT and val == gid:
				matches = true
			if not matches:
				return false
	return any_exists

func _is_section_item_active(section: String, item_data, config: Dictionary) -> bool:
	if not config.has(section):
		return false
	var cfg = config[section]
	if typeof(cfg) != TYPE_DICTIONARY:
		return false
	var id = item_data.id
	var t = item_data.get("type", "")
	if t == "suffix":
		var suffix = item_data.suffix
		if cfg.has(suffix):
			var val = cfg[suffix]
			if val == _make_suffix_key(id, suffix) or (typeof(val) == TYPE_INT and val == id):
				return true
		return false
	else:
		for sk in cfg:
			var val = cfg[sk]
			if typeof(val) == TYPE_INT and val == id:
				return true
			if typeof(val) == TYPE_STRING:
				var parts = (val as String).split(".")
				if parts.size() >= 1 and parts[0].to_int() == id:
					return true
	return false

func _is_subblock_active(config: Dictionary, section: String, id: int, subblock_key) -> bool:
	if not config.has(section):
		return false
	var cfg = config[section]
	if typeof(cfg) != TYPE_DICTIONARY:
		return false
	if not cfg.has(subblock_key):
		return false
	var val = cfg[subblock_key]
	if typeof(val) == TYPE_INT and val == id:
		return true
	if typeof(val) == TYPE_STRING:
		var parts = (val as String).split(".")
		if parts.size() >= 1 and parts[0].to_int() == id:
			return true
	return false

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

func _sorted_sections() -> Array:
	var sections = _sections_map.keys()
	sections.sort()
	return sections

func _ensure_config_section(config: Dictionary, section: String) -> void:
	if not config.has(section):
		config[section] = {}

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
	var result = []
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
						var sk = _make_suffix_key(id, key)
						if not suffix_counts.has(sk):
							suffix_counts[sk] = 0
						suffix_counts[sk] += 1
	var result = []
	for sk in suffix_counts:
		if suffix_counts[sk] > 1:
			result.append(sk)
	result.sort()
	return result

func _get_active_ids_for_section(section: String) -> Array:
	var config = dog_generator.current_variation_config
	if not config.has(section):
		return [0]
	var dict = config[section]
	if typeof(dict) != TYPE_DICTIONARY:
		return [0]
	var result = [0]
	var seen_ids = {}
	for sk in dict:
		var val = dict[sk]
		if typeof(val) == TYPE_INT:
			if val != 0 and not seen_ids.has(val):
				seen_ids[val] = true
				result.append(val)
		elif typeof(val) == TYPE_STRING:
			if not seen_ids.has(val):
				seen_ids[val] = true
				result.append(val)
	return result

func _resolve_file_path() -> String:
	if _current_file_path != "":
		return _current_file_path
	if is_instance_valid(dog_generator):
		return dog_generator.last_loaded_filepath
	return ""

func _get_file_hash() -> String:
	var path = _resolve_file_path()
	if path == "":
		return "empty"
	return str(path.hash())

func _get_subblock(section: String, id: int, sk):
	var sec = _get_section_data(section)
	if sec == null or not sec.has(id):
		return null
	var val = sec[id]
	if typeof(val) == TYPE_DICTIONARY and val.has(sk):
		return val[sk]
	return null
