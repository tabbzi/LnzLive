extends VBoxContainer
## SidebarController.gd
## Manages the layout, docking, and visibility of UI panels in the sidebar

onready var tab_container: TabContainer = get_node("SidebarTabs")
onready var tree: Tree = get_node("SidebarTabs/FileTree/Tree")
onready var spacer: Control = get_node("SidebarSpacer")
onready var collapse_btn: Button = get_node("CollapseButton")

var floating_layer: CanvasLayer = null

const UTILITY_TABS: Array = ["FileTree", "Palette", "Variations", "Texture"]

const TAB_ICONS: Dictionary = {
	"FileTree": "res://resources/icons/ico_tab_file.png",
	"Palette": "res://resources/icons/ico_tab_palette.png",
	"Variations": "res://resources/icons/ico_tab_variation.png",
	"Texture": "res://resources/icons/ico_tab_texture.png",
	"Paint": "res://resources/icons/ico_tab_paint.png",
	"Recolor": "res://resources/icons/ico_tab_recolor.png",
	"AutoPaint": "res://resources/icons/ico_tab_autopaint.png",
	"Preset": "res://resources/icons/ico_tab_preset.png",
	"Move": "res://resources/icons/ico_tab_move.png",
	"Line": "res://resources/icons/ico_tab_line.png",
	"Shape": "res://resources/icons/ico_tab_shape.png"
}

func _ready() -> void:
	if tab_container:
		tab_container.visible = true

	if not floating_layer:
		var existing_layer: CanvasLayer = get_tree().root.find_node("FloatingPanelsLayer", true, false)
		if existing_layer:
			floating_layer = existing_layer
		else:
			floating_layer = CanvasLayer.new()
			floating_layer.name = "FloatingPanelsLayer"
			floating_layer.layer = 10
			get_tree().root.call_deferred("add_child", floating_layer)

	tab_container.connect("tab_changed", self, "_on_tab_changed")
	collapse_btn.connect("pressed", self, "_on_collapse_pressed")

func add_tool_tab(control: Control, title: String) -> void:
	if control == null or not is_instance_valid(control):
		return

	if control.get_parent() == tab_container:
		return

	if control.get_parent():
		control.get_parent().remove_child(control)

	tab_container.add_child(control)
	control.name = title

	_ensure_tab_order()

	if control.has_method("set_docked"):
		control.set_docked(true) 
	
	_update_tab_visibilities()

func _ensure_tab_order() -> void:
	for i in range(UTILITY_TABS.size()):
		var tab_name: String = UTILITY_TABS[i]
		var tab_node: Node = tab_container.find_node(tab_name, false, false)
		
		if tab_node and tab_node.get_parent() == tab_container:
			tab_container.move_child(tab_node, i)

func dock_panel(panel: Control) -> void:
	if panel.get_parent() != tab_container:
		if panel.get_parent():
			panel.get_parent().remove_child(panel)
		tab_container.add_child(panel)
	
	_ensure_tab_order()
	
	if panel.has_method("set_docked"):
		panel.set_docked(true)
		
	_update_tab_visibilities()
	switch_to_tab(panel)

func undock_panel(panel: Control) -> void:
	if panel.get_parent() != tab_container:
		return

	var was_current: bool = (tab_container.get_current_tab_control() == panel)
	tab_container.remove_child(panel)

	if not floating_layer:
		floating_layer = CanvasLayer.new()
		floating_layer.name = "FloatingPanelsLayer"
		floating_layer.layer = 10
		get_tree().root.add_child(floating_layer)

	floating_layer.add_child(panel)

	if panel.has_method("set_docked"):
		panel.set_docked(false)
	
	if was_current:
		tab_container.current_tab = 0
		
	_update_tab_visibilities()

func switch_to_tab(panel: Control) -> void:
	if panel.get_parent() == tab_container:
		var idx: int = panel.get_index()
		if not tab_container.get_tab_disabled(idx):
			tab_container.current_tab = idx

func _update_tab_visibilities() -> void:
	var is_any_mode_floating: bool = false
	if floating_layer:
		for panel in floating_layer.get_children():
			if panel.visible and not panel.name in UTILITY_TABS:
				is_any_mode_floating = true
				break
			
	for i in range(tab_container.get_child_count()):
		var child: Control = tab_container.get_child(i)
		if child.name in UTILITY_TABS:
			tab_container.set_tab_disabled(i, false)
		else:
			tab_container.set_tab_disabled(i, is_any_mode_floating)

		if TAB_ICONS.has(child.name):
			var icon_path: String = TAB_ICONS[child.name]
			tab_container.set_tab_icon(i, load(icon_path))
			tab_container.set_tab_title(i, "")

func _on_tab_changed(tab_index: int) -> void:
	var control: Control = tab_container.get_child(tab_index)
	var pet_view: Node = get_tree().root.find_node("PetViewContainer", true, false)
	if not pet_view or not is_instance_valid(pet_view): return

	match control.name:
		"Palette": pet_view.view_palette_check_box.pressed = true
		"Variations": pet_view.view_variations_check_box.pressed = true
		"Texture": pet_view.texture_editor_mode_check_box.pressed = true
		"Recolor": pet_view.recolor_mode_check_box.pressed = true
		"Paint": pet_view.paintball_check_box.pressed = true
		"Move": pet_view.move_mode_check_box.pressed = true
		"Line": pet_view.line_mode_check_box.pressed = true
		"Preset": pet_view.preset_mode_check_box.pressed = true
		"AutoPaint": pet_view.auto_paintballer_check_box.pressed = true
		"Shape": pet_view.project_mode_check_box.pressed = true
		"FileTree":
			pass

func _on_collapse_pressed() -> void:
	if tab_container:
		tab_container.visible = not tab_container.visible
		spacer.visible = not tab_container.visible
		
		if tab_container.visible:
			collapse_btn.text = "<< Hide Sidebar <<"
			self.rect_min_size.x = 200
			self.size_flags_stretch_ratio = 0.5
		else:
			collapse_btn.text = ">>"
			self.rect_min_size.x = 40 
			self.size_flags_stretch_ratio = 0.01
		
		property_list_changed_notify()
		minimum_size_changed()
