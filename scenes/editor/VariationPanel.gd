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
			option_btn.add_item("Default", 0) # ID 0 for default?
			# Or do we map ID to index?
			# Let's map ID to value.

			var available_indices = variations["link_groups"][group_id]
			available_indices.sort()

			option_btn.set_meta("group_id", group_id)
			option_btn.connect("item_selected", self, "_on_link_group_selected", [option_btn])

			var idx = 1
			for val in available_indices:
				option_btn.add_item(val, idx)
				idx += 1

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
			option_btn.add_item("Default", 0)

			var available_vars = variations["sections"][section_name]
			available_vars.sort()

			option_btn.set_meta("section_name", section_name)
			option_btn.connect("item_selected", self, "_on_section_selected", [option_btn])

			var idx = 1
			for val in available_vars:
				option_btn.add_item(val, idx)
				idx += 1

			hbox.add_child(option_btn)
			sections_container.add_child(hbox)

func _on_link_group_selected(index, button):
	var group_id = button.get_meta("group_id")
	var selected_text = button.get_item_text(index)

	if selected_text == "Default":
		variation_state["Link Groups"].erase(group_id)
	else:
		variation_state["Link Groups"][group_id] = selected_text # Use string value

	emit_signal("variation_changed", variation_state)

func _on_section_selected(index, button):
	var section_name = button.get_meta("section_name")
	var selected_text = button.get_item_text(index)

	if selected_text == "Default":
		variation_state["Sections"].erase(section_name)
	else:
		variation_state["Sections"][section_name] = selected_text

	emit_signal("variation_changed", variation_state)
