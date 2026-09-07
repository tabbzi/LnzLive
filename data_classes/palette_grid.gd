## PaletteGrid.gd
## Shared utility for building color palette grids across the editor
## Handles button creation, styling, and dynamic column calculation
extends Reference
class_name PaletteGrid

enum CellType {
	BUTTON,
	COLOR_RECT
}

static func populate_grid(
	grid_container: GridContainer,
	colors: Array,
	cell_type: int = CellType.BUTTON,
	cell_size: float = 24.0,
	h_separation: int = 0,
	v_separation: int = 0,
	on_color_selected: String = "",
	on_color_right_selected: String = "",
	callback_target: Object = null
) -> GridContainer:

	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()
	
	grid_container.columns = 1
	grid_container.add_constant_override("hseparation", h_separation)
	grid_container.add_constant_override("vseparation", v_separation)
	
	var target: Object = callback_target
	if not target or not is_instance_valid(target):
		target = grid_container.owner if is_instance_valid(grid_container.owner) else grid_container
	
	for i in range(colors.size()):
		var c: Color = colors[i]
		
		if cell_type == CellType.BUTTON:
			var btn: Button = Button.new()
			btn.rect_min_size = Vector2(cell_size, cell_size)
			
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = c
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = Color(0, 0, 0, 0)
			
			var focus_style: StyleBoxFlat = style.duplicate()
			focus_style.border_color = Color(1, 1, 1, 1)
			
			btn.add_stylebox_override("normal", style)
			btn.add_stylebox_override("hover", style)
			btn.add_stylebox_override("pressed", focus_style)
			btn.add_stylebox_override("focus", focus_style)
			
			if on_color_selected != "":
				btn.connect("pressed", target, on_color_selected, [i])
			
			if on_color_right_selected != "":
				btn.connect("gui_input", target, on_color_right_selected, [i])
			
			grid_container.add_child(btn)
		
		elif cell_type == CellType.COLOR_RECT:
			var color_rect: ColorRect = ColorRect.new()
			color_rect.color = c
			color_rect.rect_min_size = Vector2(cell_size, cell_size)
			
			var label: Label = Label.new()
			label.text = str(i)
			label.align = Label.ALIGN_CENTER
			label.valign = Label.VALIGN_CENTER
			
			var luminance: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			label.add_color_override("font_color", Color.black if luminance > 0.5 else Color.white)
			
			color_rect.add_child(label)
			label.set_anchors_and_margins_preset(Control.PRESET_WIDE)
			
			grid_container.add_child(color_rect)
	
	return grid_container

static func recalculate_columns(
	grid_container: GridContainer,
	available_width: float,
	cell_size: float,
	h_separation: int = 0,
	padding: int = 16
) -> void:
	if not is_instance_valid(grid_container):
		return
	
	var new_columns: int = max(1, int((available_width - padding) / (cell_size + h_separation)))
	if grid_container.columns != new_columns:
		grid_container.columns = new_columns
