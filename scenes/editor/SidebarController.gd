extends VBoxContainer
## SidebarController.gd
## Manages the layout, docking, and visibility of UI panels in the sidebar

onready var tab_container: TabContainer = get_node("SidebarTabs")
onready var tree: Tree = get_node("SidebarTabs/FileTree/Tree")
onready var spacer: Control = get_node("SidebarSpacer")
onready var collapse_btn: Button = get_node("CollapseButton")

var floating_layer: CanvasLayer = null
var tooltip_label: Label = null
var hovered_tab_idx: int = -1

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

const TAB_TOOLTIPS: Dictionary = {
	"FileTree": "File Tree",
	"Palette": "Palette",
	"Variations": "Variations",
	"Texture": "Texture Editor",
	"Paint": "Paint Mode",
	"Recolor": "Recolor Mode",
	"AutoPaint": "Auto Paintballer",
	"Preset": "Preset Mode",
	"Move": "Move Mode",
	"Line": "Line Mode",
	"Shape": "Shape Mode"
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

	tooltip_label = Label.new()
	tooltip_label.name = "TabTooltip"
	
	var custom_font: DynamicFont = DynamicFont.new()
	custom_font.font_data = load("res://resources/fonts/pixel_maz.ttf")
	custom_font.size = 30
	tooltip_label.add_font_override("font", custom_font)
	
	var custom_style: StyleBoxFlat = StyleBoxFlat.new()
	custom_style.bg_color = Color(0.294118, 0.403922, 0.403922, 1)
	custom_style.content_margin_left = 5.0
	custom_style.content_margin_right = 5.0
	custom_style.content_margin_top = 2.0
	custom_style.content_margin_bottom = 2.0
	custom_style.corner_radius_top_left = 2
	custom_style.corner_radius_top_right = 2
	custom_style.corner_radius_bottom_left = 2
	custom_style.corner_radius_bottom_right = 2
	custom_style.anti_aliasing = false
	tooltip_label.add_stylebox_override("normal", custom_style)

	floating_layer.add_child(tooltip_label)
	tooltip_label.hide()

	tab_container.connect("gui_input", self, "_on_tab_container_gui_input")
	tab_container.connect("mouse_exited", self, "_on_tab_container_mouse_exited")

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

func _on_tab_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = event.position
		var is_hovering_any_tab: bool = false

		var header_height: float = 0.0
		if tab_container.get_child_count() > 0:
			header_height = tab_container.get_child(0).rect_position.y

		if mouse_pos.y > 0 and mouse_pos.y < header_height:
			var current_x: float = 0.0
			var style_fg: StyleBox = tab_container.get_stylebox("tab_fg", "TabContainer")
			var style_bg: StyleBox = tab_container.get_stylebox("tab_bg", "TabContainer")

			for i in range(tab_container.get_child_count()):
				var child: Control = tab_container.get_child(i)

				var style: StyleBox = style_fg if i == tab_container.current_tab else style_bg
				var icon: Texture = tab_container.get_tab_icon(i)

				var tab_width: float = style.get_minimum_size().x
				if icon:
					tab_width += icon.get_size().x

				if mouse_pos.x >= current_x and mouse_pos.x <= current_x + tab_width:
					is_hovering_any_tab = true

					if hovered_tab_idx != i:
						hovered_tab_idx = i
						tooltip_label.text = TAB_TOOLTIPS.get(child.name, child.name)
						tooltip_label.show()

					var tooltip_pos: Vector2 = event.global_position + Vector2(15, 15)
					var screen_size: Vector2 = get_viewport_rect().size

					if tooltip_pos.x + tooltip_label.rect_size.x > screen_size.x:
						tooltip_pos.x = event.global_position.x - tooltip_label.rect_size.x - 15
					if tooltip_pos.y + tooltip_label.rect_size.y > screen_size.y:
						tooltip_pos.y = event.global_position.y - tooltip_label.rect_size.y - 15

					tooltip_label.rect_global_position = tooltip_pos
					break

				current_x += tab_width

		if not is_hovering_any_tab and tooltip_label.visible:
			hovered_tab_idx = -1
			tooltip_label.hide()

func _on_tab_container_mouse_exited() -> void:
	hovered_tab_idx = -1
	if tooltip_label:
		tooltip_label.hide()
