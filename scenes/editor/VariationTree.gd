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

func populate_tree():
	if lnz_parser == null:
		return
	_sections_map = lnz_parser.get("sections_map")
	if _sections_map == null or typeof(_sections_map) != TYPE_DICTIONARY:
		return

	clear()
	var root: TreeItem = create_item()
	if not root:
		return
	set_hide_root(true)

	set_columns(1)
	set_column_title(0, "Variation Viewer")
	set_column_titles_visible(true)

	var sections = _sections_map.keys()
	sections.sort()

	var id_counts = {}
	for section in sections:
		var section_variations = _sections_map[section]
		if typeof(section_variations) != TYPE_DICTIONARY:
			continue
		for id in section_variations:
			if id == 0: continue
			if not id_counts.has(id): id_counts[id] = 0
			id_counts[id] += 1

	var global_ids: Array = []
	for id in id_counts:
		if id_counts[id] > 1:
			global_ids.append(id)
	global_ids.sort()

	if global_ids.size() > 0:
		var global_item: TreeItem = create_item(root)
		if not global_item:
			return
		global_item.set_text(0, "Global Variations")
		global_item.set_selectable(0, false)

		for id in global_ids:
			var item: TreeItem = create_item(global_item)
			item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			item.set_editable(0, true)
			item.set_text(0, "Global Variation #" + str(id))
			item.set_metadata(0, {"type": "global", "id": id})

			var all_active: bool = true
			for s in sections:
				var s_data = _sections_map[s]
				if typeof(s_data) == TYPE_DICTIONARY and s_data.has(id):
					var config = dog_generator.current_variation_config
					if not config.has(s) or not config[s].has(id):
						all_active = false
						break
			item.set_checked(0, all_active)

	for section in sections:
		var section_data = _sections_map[section]
		if typeof(section_data) != TYPE_DICTIONARY:
			continue

		var has_variations: bool = false
		for id in section_data:
			if id > 0:
				has_variations = true
				break

		if not has_variations:
			continue

		var section_item: TreeItem = create_item(root)
		if not section_item:
			return
		section_item.set_text(0, section)
		section_item.set_selectable(0, false)

		var variations = section_data
		var var_ids = variations.keys()
		var_ids.sort()

		for id in var_ids:
			if id == 0: continue

			var val = variations[id]

			if typeof(val) == TYPE_DICTIONARY:
				var item = create_item(section_item)
				if not item:
					return
				item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				item.set_editable(0, true)
				item.set_text(0, "#" + str(id))
				item.set_metadata(0, {"type": "section", "section": section, "id": id, "is_group": true})

				var config = dog_generator.current_variation_config
				var is_active = config.has(section) and config[section].has(id)
				item.set_checked(0, is_active)

				var subblocks = val
				var int_keys = []
				var str_keys = []
				for key in subblocks:
					if typeof(key) == TYPE_INT:
						int_keys.append(key)
					else:
						str_keys.append(key)
				int_keys.sort()

				for key in int_keys:
					var subblock = subblocks[key]
					if typeof(subblock) != TYPE_OBJECT:
						continue
					var sub_item = create_item(item)
					if not sub_item:
						return
					sub_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)

					var display_name = subblock.name
					if display_name == "Variation " + str(id):
						display_name = ""

					var label = "#" + str(id)
					if key > 0:
						label = label + " (" + str(key) + ")"
					if display_name != "":
						label = label + "; " + display_name

					sub_item.set_text(0, label)
					sub_item.set_metadata(0, {"type": "section", "section": section, "id": id, "subblock_key": key, "start_line": subblock.start_line})

					var sub_is_active = _is_subblock_active(config, section, id, key)
					sub_item.set_checked(0, sub_is_active)

				for key in str_keys:
					var subblock = subblocks[key]
					if typeof(subblock) != TYPE_OBJECT:
						continue
					var sub_item = create_item(item)
					if not sub_item:
						return
					sub_item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)

					var display_name = subblock.name
					if display_name == "Variation " + str(id):
						display_name = ""

					var label = "#" + str(id) + "." + key
					if subblock.is_linked:
						label = label + " (linked)"
					if display_name != "":
						label = label + "; " + display_name

					sub_item.set_text(0, label)
					sub_item.set_metadata(0, {"type": "section", "section": section, "id": id, "subblock_key": key, "start_line": subblock.start_line})

					sub_item.set_selectable(0, false)
					sub_item.set_checked(0, true)

			else:
				var var_block = val
				var item = create_item(section_item)
				if not item:
					return
				item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
				item.set_editable(0, true)

				var display_name = var_block.name
				if display_name == "Variation " + str(id):
					display_name = ""

				item.set_text(0, "#" + str(id) + " " + display_name)
				item.set_metadata(0, {"type": "section", "section": section, "id": id, "start_line": var_block.start_line})

				var config = dog_generator.current_variation_config
				if config.has(section) and config[section].has(id):
					item.set_checked(0, true)
				else:
					item.set_checked(0, false)

func _ready() -> void:
	connect("item_edited", self, "_on_item_edited")
	connect("item_selected", self, "_on_item_selected")

func _on_item_edited():
	var item = get_edited()
	var col = get_edited_column()
	if col == 0:
		var meta = item.get_metadata(0)
		if meta:
			var checked = item.is_checked(0)

			if meta.type == "global":
				var id = meta.id
				var sections = _sections_map.keys()
				var config = dog_generator.current_variation_config

				var root = get_root()
				if root:
					var global_folder = root.get_children()
					if global_folder and global_folder.get_text(0) == "Global Variations":
						var g_item = global_folder.get_children()
						while g_item:
							var g_meta = g_item.get_metadata(0)
							if g_meta and g_meta.id != id:
								g_item.set_checked(0, false)
							g_item = g_item.get_next()

				var all_global_ids = []
				if root:
					var global_folder = root.get_children()
					if global_folder and global_folder.get_text(0) == "Global Variations":
						var g_item = global_folder.get_children()
						while g_item:
							var g_meta = g_item.get_metadata(0)
							if g_meta: all_global_ids.append(g_meta.id)
							g_item = g_item.get_next()

				for s in sections:
					if not config.has(s): config[s] = [0]

					for g_id in all_global_ids:
						if config[s].has(g_id):
							config[s].erase(g_id)

					if checked:
						var sec_data = _sections_map[s]
						if typeof(sec_data) == TYPE_DICTIONARY and sec_data.has(id):
							config[s] = [0, id]
						elif typeof(sec_data) == TYPE_DICTIONARY and sec_data.has(1):
							config[s] = [0, 1]
						else:
							config[s] = [0]
					elif not checked:
						if config[s].empty(): config[s] = [0]
						var sec_data2 = _sections_map[s]
						if typeof(sec_data2) == TYPE_DICTIONARY:
							var lowest_id = _find_lowest_variation_id(sec_data2)
							if lowest_id > 0:
								config[s] = [0, lowest_id]

				_update_tree_checks()

			elif meta.type == "section":
				var section = meta.section
				var id = meta.id
				var config = dog_generator.current_variation_config
				if not config.has(section): config[section] = [0]

				if meta.has("is_group") and meta.is_group:
					if not checked:
						return
					config[section] = [0, id]
					if _source_has_linked(section, id):
						_broadcast_linked_variations(section, id, config)
					_clear_section_exclusions(section)

				elif meta.has("subblock_key"):
					var subblock_key = meta.subblock_key
					if checked:
						if not config[section].has(id):
							config[section].append(id)
						_remove_exclusion(section, id, subblock_key)
					else:
						var sec_data = _sections_map[section]
						var all_active = true
						if typeof(sec_data) == TYPE_DICTIONARY and sec_data.has(id):
							var val = sec_data[id]
							if typeof(val) == TYPE_DICTIONARY:
								for k in val:
									if k != 0:
										all_active = false
										break
						if all_active:
							if config[section].has(id):
								config[section].erase(id)
						else:
							_add_exclusion(section, id, subblock_key)

				else:
					# Legacy single block
					if checked:
						config[section] = [0, id]
					else:
						if config[section].has(id):
							config[section].erase(id)

						var sec_data3 = _sections_map[section]
						if config[section] == [0] and typeof(sec_data3) == TYPE_DICTIONARY and sec_data3.has(1):
							config[section] = [0, 1]

				_update_tree_checks()

			dog_generator.recompose_model()

func _add_exclusion(section: String, id: int, subblock_key) -> void:
	var config = dog_generator.current_variation_config
	if not config.has(section):
		config[section] = [0]
	var excl_key = section + "_excluded"
	if not config.has(excl_key):
		config[excl_key] = {}
	if not config[excl_key].has("excluded_" + str(id)):
		config[excl_key]["excluded_" + str(id)] = []
	config[excl_key]["excluded_" + str(id)].append(subblock_key)
	_save_exclusions()

func _remove_exclusion(section: String, id: int, subblock_key) -> void:
	var config = dog_generator.current_variation_config
	var excl_key = section + "_excluded"
	if config.has(excl_key):
		var excl_dict = config[excl_key]
		var excl_list_key = "excluded_" + str(id)
		if excl_dict.has(excl_list_key):
			var excl_list = excl_dict[excl_list_key]
			if excl_list.has(subblock_key):
				excl_list.erase(subblock_key)
			if excl_list.empty():
				excl_dict.erase(excl_list_key)
				if excl_dict.empty():
					config.erase(excl_key)
	_save_exclusions()

func _clear_section_exclusions(section: String) -> void:
	var config = dog_generator.current_variation_config
	var excl_key = section + "_excluded"
	if config.has(excl_key):
		config.erase(excl_key)
	_save_exclusions()

func _save_exclusions() -> void:
	var path = _current_file_path
	if path == "":
		if is_instance_valid(dog_generator):
			path = dog_generator.last_loaded_filepath
	if path == "":
		return
	var config = dog_generator.current_variation_config
	var exclusions = {}
	for key in config:
		if key is String and key.ends_with("_excluded"):
			var section_name = key.trim_suffix("_excluded")
			exclusions[section_name] = config[key]
	var cf = ConfigFile.new()
	cf.set_value("exclusions", "data", exclusions)
	cf.save("user://lnz_exclusions_" + _get_file_hash() + ".cfg")

func _load_exclusions() -> void:
	var path = _current_file_path
	if path == "":
		if is_instance_valid(dog_generator):
			path = dog_generator.last_loaded_filepath
	if path == "":
		return
	var cf = ConfigFile.new()
	var err = cf.load("user://lnz_exclusions_" + _get_file_hash() + ".cfg")
	if err != OK:
		return
	if cf.has_section_key("exclusions", "data"):
		var data = cf.get_value("exclusions", "data")
		if typeof(data) == TYPE_DICTIONARY:
			var config = dog_generator.current_variation_config
			for section in data:
				var excl_key = section + "_excluded"
				config[excl_key] = data[section]

func _get_file_hash() -> String:
	if _current_file_path == "":
		return "empty"
	return str(_current_file_path.hash())

func _is_subblock_active(config: Dictionary, section: String, id: int, subblock_key) -> bool:
	if not config.has(section) or not config[section].has(id):
		return false
	var excl_config = config.get(section + "_excluded", {})
	if typeof(excl_config) != TYPE_DICTIONARY:
		return true
	var excl_key = "excluded_" + str(id)
	if not excl_config.has(excl_key):
		return true
	var excl_list = excl_config[excl_key]
	if typeof(excl_list) != TYPE_ARRAY:
		return true
	return not excl_list.has(subblock_key)

func _find_lowest_variation_id(section_data) -> int:
	var lowest = 0
	if typeof(section_data) == TYPE_DICTIONARY:
		for id in section_data:
			if id > 0 and (lowest == 0 or id < lowest):
				lowest = id
	return lowest

func _source_has_linked(source_section: String, source_id: int) -> bool:
	var source_data = _sections_map.get(source_section, {})
	if typeof(source_data) != TYPE_DICTIONARY:
		return false
	var source_id_data = source_data.get(source_id, {})
	if typeof(source_id_data) != TYPE_DICTIONARY:
		return false
	for key in source_id_data:
		if typeof(key) == TYPE_STRING:
			return true
	return false

func _broadcast_linked_variations(source_section: String, source_id: int, config: Dictionary) -> void:
	if not _source_has_linked(source_section, source_id):
		return
	var sections = _sections_map.keys()
	for section in sections:
		if section == source_section:
			continue
		var sec_data = _sections_map[section]
		if typeof(sec_data) != TYPE_DICTIONARY:
			continue
		if not sec_data.has(source_id):
			continue
		var id_data = sec_data[source_id]
		if typeof(id_data) != TYPE_DICTIONARY:
			continue
		var linked_suffixes = []
		for key in id_data:
			if typeof(key) == TYPE_STRING:
				linked_suffixes.append(key)
		if linked_suffixes.size() == 0:
			continue
		if not config.has(section):
			config[section] = [0]
		if not config[section].has(source_id):
			config[section].append(source_id)

func _update_tree_checks() -> void:
	var root = get_root()
	if not root: return

	var config = dog_generator.current_variation_config

	var item = root.get_children()
	while item:
		var child = item.get_children()
		while child:
			var meta = child.get_metadata(0)
			if meta and meta.type == "section":
				var is_active = config.has(meta.section) and config[meta.section].has(meta.id)
				child.set_checked(0, is_active)
				# Also sync subblock children
				var subchild = child.get_children()
				while subchild:
					var sub_meta = subchild.get_metadata(0)
					if sub_meta and sub_meta.has("subblock_key"):
						var sub_is_active = config.has(sub_meta.section) and config[sub_meta.section].has(sub_meta.id)
						var excl_key = "excluded_" + str(sub_meta.id)
						var excluded_list = []
						var excl_config = config.get(sub_meta.section + "_excluded", {})
						if excl_config.has(excl_key):
							excluded_list = excl_config[excl_key]
						if sub_is_active and excluded_list.has(sub_meta.subblock_key):
							sub_is_active = false
						subchild.set_checked(0, sub_is_active)
					subchild = subchild.get_next()
			child = child.get_next()
		item = item.get_next()

func _on_item_selected() -> void:
	var item = get_selected()
	if item:
		var meta = item.get_metadata(0)
		if meta and meta.has("start_line"):
			var lnz_text_edit = get_tree().root.get_node("Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
			if lnz_text_edit:
				lnz_text_edit.cursor_set_line(meta.start_line)
				lnz_text_edit.center_viewport_to_cursor()
