extends WindowDialog
## ReferenceImagePopup.gd
## Displays a reference image loaded from settings

onready var texture_rect: TextureRect = $TextureRect

var programmatic_hide: bool = false

func _ready() -> void:
	window_title = "Reference Image Viewer"
	rect_min_size = Vector2(200, 200)
	texture_rect.expand = true
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	connect("popup_hide", self, "_on_popup_hide")

func _on_popup_hide() -> void:
	if programmatic_hide:
		programmatic_hide = false
		return
		
	var config_path: String = "user://settings.cfg"
	var config: ConfigFile = ConfigFile.new()
	config.load(config_path)
	config.set_value("ReferenceImage", "show_popup", false)
	config.save(config_path)

	var settings: Node = get_tree().root.find_node("ReferenceImageSettings", true, false)
	if settings:
		if settings.has_node("show_popup_checkbox"):
			var checkbox: CheckBox = settings.get_node("show_popup_checkbox")
			if checkbox:
				checkbox.pressed = false

func _on_reference_image_updated(config_data: Dictionary) -> void:
	update_config_reference_image(config_data)

func update_config_reference_image(config_data: Dictionary) -> void:
	if not texture_rect:
		texture_rect = $TextureRect

	if config_data.get("path", "") != "" and config_data.get("show_popup", false):
		var image: Image = Image.new()
		var err: int = preload("res://scripts/petz_image.gd").load_image(image, config_data.path, false, false)
		if err == OK:
			var tex: ImageTexture = ImageTexture.new()
			tex.create_from_image(image)
			texture_rect.texture = tex

			var target_size: Vector2 = image.get_size()
			if target_size.x > 800 or target_size.y > 600:
				var aspect: float = target_size.x / target_size.y
				if aspect > 1.33:
					target_size = Vector2(800, 800 / aspect)
				else:
					target_size = Vector2(600 * aspect, 600)

			rect_size = target_size
			if not visible:
				show()
				var viewport_size: Vector2 = get_viewport().size
				rect_position = (viewport_size - rect_size) / 2.0
		else:
			texture_rect.texture = null
			hide()
	else:
		texture_rect.texture = null
		programmatic_hide = true
		hide()

func _on_ToggleRefImageBtn_pressed() -> void:
	var ref_settings: Node = get_tree().root.find_node("ReferenceImageSettings", true, false)
	if ref_settings:
		if ref_settings.has_method("toggle_reference_image"):
			ref_settings.toggle_reference_image()
