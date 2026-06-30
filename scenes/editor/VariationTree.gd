extends Tree
## VariationTree.gd
## Manages the tree view for selecting and configuring pet variations

var dog_generator = null
var lnz_parser = null
var _sections_map = null

func setup(p_dog_generator: Node, p_lnz_parser: Node) -> void:
	dog_generator = p_dog_generator
	lnz_parser = p_lnz_parser
	populate_tree()

func populate_tree():
	if lnz_parser == null:
		return
	_sections_map = lnz_parser.get("sections_map")
	if _sections_map == null or typeof(_sections_map) != TYPE_DICTIONARY:
		return

	clear()
	var root: TreeItem = create_item()
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
		var variations = section_data
		var var_ids = variations.keys()

		var has_variations: bool = false
		for id in var_ids:
			if id > 0:
				has_variations = true
				break

		if not has_variations:
			continue

		var section_item: TreeItem = create_item(root)
		section_item.set_text(0, section)
		section_item.set_selectable(0, false)

		var_ids.sort()

		for id in var_ids:
			if id == 0: continue

			var var_block = variations[id]
			var item = create_item(section_item)
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
						if config[s] == [0] and typeof(sec_data2) == TYPE_DICTIONARY and sec_data2.has(1):
							config[s] = [0, 1]

				_update_tree_checks()

			elif meta.type == "section":
				var section = meta.section
				var id = meta.id
				var config = dog_generator.current_variation_config
				if not config.has(section): config[section] = [0]

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

func _update_tree_checks() -> void:
	var root = get_root()
	if not root: return

	var item = root.get_children()
	while item:
		var child = item.get_children()
		while child:
			var meta = child.get_metadata(0)
			if meta and meta.type == "section":
				var config = dog_generator.current_variation_config
				var is_active = config.has(meta.section) and config[meta.section].has(meta.id)
				child.set_checked(0, is_active)
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
