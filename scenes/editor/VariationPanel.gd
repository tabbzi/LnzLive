extends PanelContainer

signal variation_changed(variation_state)

var lnz_parser: LnzParser = null
var variation_state = {
	"Link Groups": {},
	"Sections": {}
}

onready var container = $VBoxContainer
onready var link_groups_container = $VBoxContainer/LinkGroupsContainer
onready var sections_container = $VBoxContainer/SectionsContainer

func _ready():
	hide()

func setup(parser: LnzParser):
	lnz_parser = parser
	_refresh_ui()

func save_state() -> Dictionary:
	return variation_state.duplicate(true)

func restore_state(state: Dictionary):
	if state.empty():
		return

	# Restore Link Groups
	if state.has("Link Groups"):
		for group_id in state["Link Groups"]:
			var val = state["Link Groups"][group_id]
			var btn = _find_option_button_by_meta("group_id", group_id)
			if btn:
				_select_item_by_text(btn, str(val))
				variation_state["Link Groups"][group_id] = val

	# Restore Sections
	if state.has("Sections"):
		for section_name in state["Sections"]:
			var val = state["Sections"][section_name]
			var btn = _find_option_button_by_meta("section_name", section_name)
			if btn:
				_select_item_by_text(btn, str(val))
				variation_state["Sections"][section_name] = val

	emit_signal("variation_changed", variation_state)

func _find_option_button_by_meta(meta_key: String, meta_val):
	for container in [link_groups_container, sections_container]:
		for child in container.get_children():
			if child is HBoxContainer:
				for node in child.get_children():
					if node is OptionButton and node.has_meta(meta_key) and node.get_meta(meta_key) == meta_val:
						return node
	return null

func _select_item_by_text(btn: OptionButton, text: String):
	for i in range(btn.get_item_count()):
		if btn.get_item_text(i) == text:
			btn.select(i)
			return

func _refresh_ui():
	# Clear existing controls
	for child in link_groups_container.get_children():
		child.queue_free()
	for child in sections_container.get_children():
		child.queue_free()

	variation_state = {
		"Link Groups": {},
		"Sections": {}
	}

	if lnz_parser == null:
		hide()
		return

	var variations = lnz_parser.get_available_variations()

	if variations["sections"].empty() and variations["link_groups"].empty():
		hide()
		return

	show()

	# Create Link Group controls
	if not variations["link_groups"].empty():
		var label = Label.new()
		label.text = "Link Groups"
		link_groups_container.add_child(label)

		for group_id in variations["link_groups"]:
			var hbox = HBoxContainer.new()
			var name_label = Label.new()
			name_label.text = "Group " + group_id
			hbox.add_child(name_label)

			var option_btn = OptionButton.new()
			# No "Default" option for Link Groups, force selection

			var available_indices = variations["link_groups"][group_id]
			available_indices.sort()
			available_indices.invert()

			option_btn.set_meta("group_id", group_id)
			option_btn.connect("item_selected", self, "_on_link_group_selected", [option_btn])

			var idx = 0
			for val in available_indices:
				option_btn.add_item(val, idx)
				idx += 1

			# Select highest (first) by default
			if not available_indices.empty():
				option_btn.select(0)
				variation_state["Link Groups"][group_id] = available_indices[0]

			hbox.add_child(option_btn)
			link_groups_container.add_child(hbox)

	# Create Section controls
	if not variations["sections"].empty():
		var label = Label.new()
		label.text = "Section Overrides"
		sections_container.add_child(label)

		for section_name in variations["sections"]:
			var hbox = HBoxContainer.new()
			var name_label = Label.new()
			name_label.text = section_name
			hbox.add_child(name_label)

			var option_btn = OptionButton.new()
			var available_vars = variations["sections"][section_name]
			available_vars.sort()
			available_vars.invert()

			var has_linked = false
			for v in available_vars:
				if "." in v:
					has_linked = true
					break

			var idx = 0
			if has_linked:
				option_btn.add_item("Linked", idx)
				idx += 1

			for val in available_vars:
				option_btn.add_item(val, idx)
				idx += 1

			option_btn.set_meta("section_name", section_name)
			option_btn.connect("item_selected", self, "_on_section_selected", [option_btn])

			# Select "Linked" default if available, else highest
			if has_linked:
				option_btn.select(0)
				variation_state["Sections"][section_name] = "Linked"
			elif not available_vars.empty():
				option_btn.select(0)
				variation_state["Sections"][section_name] = available_vars[0]

			hbox.add_child(option_btn)
			sections_container.add_child(hbox)

	# Emit initial state if we selected defaults
	if not variation_state["Link Groups"].empty() or not variation_state["Sections"].empty():
		emit_signal("variation_changed", variation_state)

func _on_link_group_selected(index, button):
	var group_id = button.get_meta("group_id")
	var selected_text = button.get_item_text(index)

	variation_state["Link Groups"][group_id] = selected_text
	emit_signal("variation_changed", variation_state)

func _on_section_selected(index, button):
	var section_name = button.get_meta("section_name")
	var selected_text = button.get_item_text(index)

	variation_state["Sections"][section_name] = selected_text
	emit_signal("variation_changed", variation_state)
