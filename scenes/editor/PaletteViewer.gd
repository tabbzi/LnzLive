extends DraggablePanel
## PaletteViewer.gd
## Manages a popup that displays the currently loaded pet color palette
## This script generates a visual grid of colors from the active palette file
## 1. Initialization: Connects the close button to hide the popup
## 2. Population: Clears the existing view, loads the correct palette texture for the active pet, and creates a GridContainer
## 3. Display: Iterates through the palette's colors, generating a ColorRect and a numbered Label for each color index
## 4. Loading: Contains logic to find the appropriate palette file based on  LNZ document data

var dog_generator: Node = null

var color_grid: GridContainer

onready var vbox = $VBoxContainer/ScrollContainer/VBoxContainer/MarginContainer/MainVBox/PaletteViewerScrollContainer/PaletteViewerVBoxContainer
onready var title_label: Label = $VBoxContainer/ScrollContainer/VBoxContainer/MarginContainer/MainVBox/TitleLabel
onready var main_container: MarginContainer = $VBoxContainer/ScrollContainer/VBoxContainer/MarginContainer
onready var scroll_view = $VBoxContainer/ScrollContainer
onready var pixel_font: Font = load("res://resources/fonts/font_pixel_code_14.tres")

func _ready() -> void:
	dog_generator = LnzLiveUtils.get_pet_node(get_tree().root)
		
	if dog_generator:
		dog_generator.connect("palette_changed", self, "_on_pet_palette_changed")
		populate_colors()
	else:
		print("PaletteViewer Error: Could not find dog_generator node.")

	vbox.connect("resized", self, "_on_vbox_resized")
	
	var user_settings: Node = get_tree().root.find_node("SceneRoot", true, false)
	if user_settings:
		user_settings.connect("global_font_updated", self, "populate_colors")

	scroll_view.connect("resized", self, "_on_vbox_resized")

func populate_colors() -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

	if dog_generator == null or dog_generator.lnz == null:
		title_label.text = "No palette loaded"
		var label: Label = Label.new()
		label.text = "No pet loaded"
		vbox.add_child(label)
		return

	var pal_texture: Texture = dog_generator.current_palette_texture
	var palette_path = dog_generator.lnz.palette
	
	if palette_path == null or palette_path == "":
		title_label.text = "default Babyz game palette" if dog_generator.is_babyz_mode else "default Petz game palette"
	else:
		title_label.text = "Palette: " + palette_path.get_basename()
		if dog_generator.is_babyz_mode and dog_generator.lnz.species != 3:
			title_label.text += " (game: Babyz)"

	if pal_texture == null:
		var label: Label = Label.new()
		label.text = "palette not found"
		vbox.add_child(label)
		return

	var img: Image = pal_texture.get_data()
	img.lock()
	
	var colors: Array = []
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var color: Color = img.get_pixel(x, y)
			colors.append(color)
	
	img.unlock()
	
	color_grid = GridContainer.new()
	vbox.add_child(color_grid)
	
	PaletteGrid.populate_grid(
		color_grid,
		colors,
		PaletteGrid.CellType.COLOR_RECT,
		max(22.0, pixel_font.size * 2 + 4),
		0,
		0,
		"",
		"",
		self
	)
	
	call_deferred("_on_vbox_resized")

func _on_vbox_resized() -> void:
	if not color_grid or color_grid.get_child_count() == 0:
		return
	
	var available_width: float = scroll_view.rect_size.x
	
	var v_scroll: VScrollBar = scroll_view.get_v_scrollbar()
	if v_scroll.is_visible_in_tree():
		available_width -= v_scroll.rect_size.x

	var margin_container: MarginContainer = vbox.get_parent() 
	if margin_container is MarginContainer:
		available_width -= (margin_container.get_constant("margin_right") + margin_container.get_constant("margin_left"))
	
	var cell_width: float = color_grid.get_child(0).rect_min_size.x
	PaletteGrid.recalculate_columns(color_grid, available_width, cell_width, 0, 0)

func load_palette_texture(palette_filename: String) -> Texture:
	var texture: Texture = null
	var clean_filename: String = palette_filename.strip_edges()
	
	var user_res_path: String = "user://resources/palettes".plus_file(clean_filename)
	var res_res_path: String = "res://resources/palettes".plus_file(clean_filename)

	if ResourceLoader.exists(user_res_path):
		texture = ResourceLoader.load(user_res_path)
	elif ResourceLoader.exists(res_res_path):
		texture = ResourceLoader.load(res_res_path)
	else:
		var resource_key: String = "palette_" + clean_filename.to_lower()
		var preloader: ResourcePreloader = get_tree().root.get_node("Root/ResourcePreloader") as ResourcePreloader
		if preloader.has_resource(resource_key):
			texture = preloader.get_resource(resource_key)

	return texture

func _on_palette_selected(filename_no_ext: String) -> void:
	if dog_generator.lnz == null:
		return 
		
	dog_generator.lnz.palette = filename_no_ext + ".png"
	populate_colors()

func _on_pet_palette_changed(palette_name) -> void:
	populate_colors()
