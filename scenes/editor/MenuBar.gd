extends HBoxContainer
## MenuBar.gd
## Manages main menu bar for File, Tool, Mode, Render, Export, and Help menus

enum FileMenu {
	IMPORT_LNZ,
	IMPORT_TEXTURE,
	IMPORT_PALETTE,
	OPEN_USER_FOLDER,
	USER_SETTINGS,
	REFERENCE_IMAGE,
	SHADER_SETTINGS
}

enum ToolMenu {
	AUTO_PAINTBALLER,
	VIEW_PALETTE,
	VIEW_VARIATIONS,
	COLOR_SWAP,
	CAPTURE_HEADSHOT
}

enum ModeMenu {
	SELECT,
	PAINTBALL,
	SHAPE,
	PRESET,
	LINE,
	MOVE,
	RECOLOR,
	TEXTURE_EDITOR
}

enum HelpMenu {
	BASIC_CONTROLS,
	USER_GUIDE,
	CAROLYNS_BIBLE,
	PALETTEIARE
}

enum RenderMenu {
	DRAW_POLYGONS,
	DRAW_LINES,
	DRAW_PAINTBALLS,
	DRAW_ADDBALLS,
	DRAW_BALLS,
	SHOW_OMITTED,
	SHOW_SPECIAL,
	TRANSPARENCY,
	UNHIDE_BALLS
}

enum ExportMenu {
	EXPORT_OBJ,
	EXPORT_CLOTHES
}

onready var file_menu_btn: MenuButton = $FileOptionButton
onready var tool_menu_btn: MenuButton = $ToolOptionButton
onready var mode_menu_btn: MenuButton = $ModeOptionButton
onready var render_menu_btn: MenuButton = $RenderOptionButton
onready var export_menu_btn: MenuButton = $ExportOptionButton
onready var help_menu_btn: MenuButton = $HelpOptionButton

onready var pet_view_container: Control = get_parent().get_parent()
onready var scene_root: Node = get_tree().root.get_node("Root/SceneRoot")
onready var lnz_text_edit: Control = scene_root.get_node("HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")

onready var _tool_checkboxes: Array = [
	$ToolOptionButton/PopupPanel/ToolOptionContainer/AutoPaintballerModeCheckBox,
	$ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton,
	$ToolOptionButton/PopupPanel/ToolOptionContainer/ViewVariationsCheckBox,
]

onready var _tool_menu_ids: Array = [
	ToolMenu.AUTO_PAINTBALLER,
	ToolMenu.VIEW_PALETTE,
	ToolMenu.VIEW_VARIATIONS,
]

onready var _mode_checkboxes: Array = [
	$ModeOptionButton/PopupPanel/ModeOptionContainer/SelectCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/PaintballModeCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/ProjectModeCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/PresetModeCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/LineModeCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/MoveModeCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/RecolorModeCheckBox,
	$ModeOptionButton/PopupPanel/ModeOptionContainer/TextureEditorModeCheckBox,
]

onready var _mode_menu_ids: Array = [
	ModeMenu.SELECT,
	ModeMenu.PAINTBALL,
	ModeMenu.SHAPE,
	ModeMenu.PRESET,
	ModeMenu.LINE,
	ModeMenu.MOVE,
	ModeMenu.RECOLOR,
	ModeMenu.TEXTURE_EDITOR,
]

onready var _render_checkboxes: Array = [
	$RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/PolygonCheckBox,
	$RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/LineCheckBox,
	$RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/PaintballCheckBox,
	$RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/AddballCheckBox,
	$RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/BallCheckBox,
	$RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/OmittedBallCheckBox,
	$RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/ToggleSpecialBalls,
	$RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/TransparencyCheckBox,
]

onready var _render_menu_ids: Array = [
	RenderMenu.DRAW_POLYGONS,
	RenderMenu.DRAW_LINES,
	RenderMenu.DRAW_PAINTBALLS,
	RenderMenu.DRAW_ADDBALLS,
	RenderMenu.DRAW_BALLS,
	RenderMenu.SHOW_OMITTED,
	RenderMenu.SHOW_SPECIAL,
	RenderMenu.TRANSPARENCY,
]

func _ready() -> void:
	file_menu_btn.flat = false
	tool_menu_btn.flat = false
	mode_menu_btn.flat = false
	render_menu_btn.flat = false
	export_menu_btn.flat = false
	help_menu_btn.flat = false
	
	_setup_file_menu()
	_setup_tool_menu()
	_setup_mode_menu()
	_setup_render_menu()
	_setup_export_menu()
	_setup_help_menu()
	
	_setup_popup_sync()

func _style_popup(popup: PopupMenu) -> void:
	popup.add_font_override("font", preload("res://resources/fonts/font_pixel_maz_24.tres"))
	
	var panel_style: StyleBoxFlat = preload("res://resources/styles/styleboxflat_button_normal.tres").duplicate()
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 12
	popup.add_stylebox_override("panel", panel_style)
	
	popup.add_stylebox_override("hover", preload("res://resources/styles/styleboxflat_button_hover.tres"))
	
	popup.add_constant_override("vseparation", 8)
	popup.add_color_override("font_color_hover", Color(1.0, 1.0, 1.0, 1.0))

func _setup_file_menu() -> void:
	var popup: PopupMenu = file_menu_btn.get_popup()
	_style_popup(popup)
	popup.add_item("Import LNZ", FileMenu.IMPORT_LNZ)
	popup.add_item("Import Texture", FileMenu.IMPORT_TEXTURE)
	popup.add_item("Import Palette", FileMenu.IMPORT_PALETTE)
	popup.add_item("Open User Folder", FileMenu.OPEN_USER_FOLDER)
	popup.add_separator()
	popup.add_item("User Settings", FileMenu.USER_SETTINGS)
	popup.add_item("Reference Image", FileMenu.REFERENCE_IMAGE)
	popup.add_item("Shader Settings", FileMenu.SHADER_SETTINGS)
	popup.connect("id_pressed", self, "_on_file_menu_id_pressed")

func _setup_tool_menu() -> void:
	var popup: PopupMenu = tool_menu_btn.get_popup()
	_style_popup(popup)
	
	popup.add_check_item("Auto Paintballer", ToolMenu.AUTO_PAINTBALLER)
	popup.set_item_tooltip(popup.get_item_index(ToolMenu.AUTO_PAINTBALLER), "Hotkey A to toggle Auto Paintballer")
	
	popup.add_check_item("View Palette", ToolMenu.VIEW_PALETTE)
	popup.set_item_tooltip(popup.get_item_index(ToolMenu.VIEW_PALETTE), "Hotkey T to toggle Palette Viewer")
	
	popup.add_check_item("Variation Viewer", ToolMenu.VIEW_VARIATIONS)
	popup.set_item_tooltip(popup.get_item_index(ToolMenu.VIEW_VARIATIONS), "Hotkey V to activate Variation Viewer")
	
	popup.add_separator()
	
	popup.add_item("Color Swap", ToolMenu.COLOR_SWAP)
	popup.set_item_tooltip(popup.get_item_index(ToolMenu.COLOR_SWAP), "Hotkey G to toggle Color Swap")
	
	popup.add_item("Capture Head Shot", ToolMenu.CAPTURE_HEADSHOT)
	popup.set_item_tooltip(popup.get_item_index(ToolMenu.CAPTURE_HEADSHOT), "Hotkey K to capture [Head Shot]")
	
	popup.connect("id_pressed", self, "_on_tool_menu_id_pressed")

func _setup_mode_menu() -> void:
	var popup: PopupMenu = mode_menu_btn.get_popup()
	_style_popup(popup)
	
	popup.add_check_item("Select Mode", ModeMenu.SELECT)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.SELECT), "Hotkey S to activate Select Mode")
	
	popup.add_check_item("Paintball Mode", ModeMenu.PAINTBALL)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.PAINTBALL), "Hotkey W or ALT+B to activate Paintball Mode")
	
	popup.add_check_item("Shape Mode", ModeMenu.SHAPE)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.SHAPE), "Hotkey D or ALT+P to activate Shape Mode")
	
	popup.add_check_item("Preset Mode", ModeMenu.PRESET)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.PRESET), "Hotkey R or ALT+G to activate Preset Mode")
	
	popup.add_check_item("Line Mode", ModeMenu.LINE)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.LINE), "Hotkey E or ALT+L to activate Line Mode")
	
	popup.add_check_item("Move Mode", ModeMenu.MOVE)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.MOVE), "Hotkey U or ALT+M to activate Move Mode")
	
	popup.add_check_item("Recolor Mode", ModeMenu.RECOLOR)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.RECOLOR), "Hotkey G to activate Recolor Mode")
	
	popup.add_check_item("Texture Editor", ModeMenu.TEXTURE_EDITOR)
	popup.set_item_tooltip(popup.get_item_index(ModeMenu.TEXTURE_EDITOR), "Activate Texture Editor")
	
	popup.connect("id_pressed", self, "_on_mode_menu_id_pressed")

func _setup_render_menu() -> void:
	var popup: PopupMenu = render_menu_btn.get_popup()
	_style_popup(popup)
	
	popup.add_check_item("Draw Polygons", RenderMenu.DRAW_POLYGONS)
	popup.add_check_item("Draw Lines", RenderMenu.DRAW_LINES)
	popup.add_check_item("Draw Paintballs", RenderMenu.DRAW_PAINTBALLS)
	popup.add_check_item("Draw Addballs", RenderMenu.DRAW_ADDBALLS)
	popup.add_check_item("Draw Balls", RenderMenu.DRAW_BALLS)
	
	popup.add_separator()
	
	popup.add_check_item("Show Omitted Ballz", RenderMenu.SHOW_OMITTED)
	popup.add_check_item("Show Special Balls", RenderMenu.SHOW_SPECIAL)
	popup.add_check_item("Transparency (253)", RenderMenu.TRANSPARENCY)
	
	popup.add_separator()
	popup.add_item("Unhide Ballz", RenderMenu.UNHIDE_BALLS)
	
	popup.connect("id_pressed", self, "_on_render_menu_id_pressed")

func _setup_export_menu() -> void:
	var popup: PopupMenu = export_menu_btn.get_popup()
	_style_popup(popup)
	
	popup.add_item("Export OBJ 3D Model", ExportMenu.EXPORT_OBJ)
	popup.add_item("Export to Clothes CLZ", ExportMenu.EXPORT_CLOTHES)
	
	popup.connect("id_pressed", self, "_on_export_menu_id_pressed")

func _setup_help_menu() -> void:
	var popup: PopupMenu = help_menu_btn.get_popup()
	_style_popup(popup)
	popup.add_item("Basic Controls", HelpMenu.BASIC_CONTROLS)
	popup.add_separator()
	popup.add_item("User Guide", HelpMenu.USER_GUIDE)
	popup.add_item("Carolyn's Bible", HelpMenu.CAROLYNS_BIBLE)
	popup.add_item("Petz Paletteiare", HelpMenu.PALETTEIARE)
	popup.connect("id_pressed", self, "_on_help_menu_id_pressed")

func _setup_popup_sync() -> void:
	tool_menu_btn.get_popup().connect("about_to_show", self, "_sync_tool_menu")
	mode_menu_btn.get_popup().connect("about_to_show", self, "_sync_mode_menu")
	render_menu_btn.get_popup().connect("about_to_show", self, "_sync_render_menu")

func _sync_tool_menu() -> void:
	var popup: PopupMenu = tool_menu_btn.get_popup()
	for i in range(_tool_checkboxes.size()):
		popup.set_item_checked(popup.get_item_index(_tool_menu_ids[i]), _tool_checkboxes[i].pressed)

func _sync_mode_menu() -> void:
	var popup: PopupMenu = mode_menu_btn.get_popup()
	for i in range(_mode_checkboxes.size()):
		popup.set_item_checked(popup.get_item_index(_mode_menu_ids[i]), _mode_checkboxes[i].pressed)

func _sync_render_menu() -> void:
	var popup: PopupMenu = render_menu_btn.get_popup()
	for i in range(_render_checkboxes.size()):
		popup.set_item_checked(popup.get_item_index(_render_menu_ids[i]), _render_checkboxes[i].pressed)

func _on_file_menu_id_pressed(id: int) -> void:
	match id:
		FileMenu.IMPORT_LNZ:
			$FileOptionButton/PopupPanel/FileOptionContainer/MenuImportLNZ.emit_signal("pressed")
		FileMenu.IMPORT_TEXTURE:
			$FileOptionButton/PopupPanel/FileOptionContainer/MenuImportTexture.emit_signal("pressed")
		FileMenu.IMPORT_PALETTE:
			$FileOptionButton/PopupPanel/FileOptionContainer/MenuImportPalette.emit_signal("pressed")
		FileMenu.OPEN_USER_FOLDER:
			$FileOptionButton/PopupPanel/FileOptionContainer/MenuOpenUserFolder.emit_signal("pressed")
		FileMenu.USER_SETTINGS:
			$FileOptionButton/PopupPanel/FileOptionContainer/UserSettingsButton.emit_signal("pressed")
		FileMenu.REFERENCE_IMAGE:
			scene_root.get_node("ReferenceImageSettings").popup_centered()
		FileMenu.SHADER_SETTINGS:
			if pet_view_container.has_method("_on_ShaderSettingsButton_pressed"):
				pet_view_container._on_ShaderSettingsButton_pressed()

func _on_tool_menu_id_pressed(id: int) -> void:
	match id:
		ToolMenu.AUTO_PAINTBALLER:
			_toggle_legacy($ToolOptionButton/PopupPanel/ToolOptionContainer/AutoPaintballerModeCheckBox)
		ToolMenu.VIEW_PALETTE:
			_toggle_legacy($ToolOptionButton/PopupPanel/ToolOptionContainer/ViewPaletteButton)
		ToolMenu.VIEW_VARIATIONS:
			_toggle_legacy($ToolOptionButton/PopupPanel/ToolOptionContainer/ViewVariationsCheckBox)
		ToolMenu.COLOR_SWAP:
			$ToolOptionButton/PopupPanel/ToolOptionContainer/RecolorMenuButton.emit_signal("pressed")
		ToolMenu.CAPTURE_HEADSHOT:
			if lnz_text_edit.has_method("_on_HeadShotButton_pressed"):
				lnz_text_edit._on_HeadShotButton_pressed()

func _on_mode_menu_id_pressed(id: int) -> void:
	match id:
		ModeMenu.SELECT:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/SelectCheckBox, true)
		ModeMenu.PAINTBALL:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/PaintballModeCheckBox)
		ModeMenu.SHAPE:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/ProjectModeCheckBox)
		ModeMenu.PRESET:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/PresetModeCheckBox)
		ModeMenu.LINE:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/LineModeCheckBox)
		ModeMenu.MOVE:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/MoveModeCheckBox)
		ModeMenu.RECOLOR:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/RecolorModeCheckBox)
		ModeMenu.TEXTURE_EDITOR:
			_toggle_legacy($ModeOptionButton/PopupPanel/ModeOptionContainer/TextureEditorModeCheckBox)

func _on_render_menu_id_pressed(id: int) -> void:
	match id:
		RenderMenu.DRAW_POLYGONS:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/PolygonCheckBox)
		RenderMenu.DRAW_LINES:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/LineCheckBox)
		RenderMenu.DRAW_PAINTBALLS:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/PaintballCheckBox)
		RenderMenu.DRAW_ADDBALLS:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/AddballCheckBox)
		RenderMenu.DRAW_BALLS:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/DrawToggleContainer/BallCheckBox)
		RenderMenu.SHOW_OMITTED:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/OmittedBallCheckBox)
		RenderMenu.SHOW_SPECIAL:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/ToggleSpecialBalls)
		RenderMenu.TRANSPARENCY:
			_toggle_legacy($RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/TransparencyCheckBox)
		RenderMenu.UNHIDE_BALLS:
			$RenderOptionButton/PopupPanel/HBoxContainer/VisualToggleContainer/UnhideBallsButton.emit_signal("pressed")

func _on_export_menu_id_pressed(id: int) -> void:
	match id:
		ExportMenu.EXPORT_OBJ:
			$ExportOptionButton/PopupPanel/VBoxContainer/ExportButtonOBJ.emit_signal("pressed")
		ExportMenu.EXPORT_CLOTHES:
			$ExportOptionButton/PopupPanel/VBoxContainer/ExportButtonClothes.emit_signal("pressed")

func _toggle_legacy(node: CheckBox, emit_pressed: bool = false) -> void:
	node.pressed = not node.pressed
	if emit_pressed:
		node.emit_signal("pressed")
	else:
		node.emit_signal("toggled", node.pressed)

func _on_help_menu_id_pressed(id: int) -> void:
	match id:
		HelpMenu.BASIC_CONTROLS:
			scene_root.get_node("HelpPopupDialog").popup_centered()
		HelpMenu.USER_GUIDE:
			OS.shell_open("https://github.com/tabbzi/LnzLive/blob/master/docs/GUIDE.md")
		HelpMenu.CAROLYNS_BIBLE:
			OS.shell_open("https://github.com/melissamcewen/carolyns-bible")
		HelpMenu.PALETTEIARE:
			OS.shell_open("https://tabbzi.github.io/petz-paletteiare/")
