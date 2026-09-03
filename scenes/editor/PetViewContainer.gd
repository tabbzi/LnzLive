extends Control

# PetViewContainer.gd
# - Translates 2D mouse input into 3D world interactions (raycasting/selection)
# - Manages Modes (Move, Paint, Line, etc.)
# - Handles coordinate conversion between spatial world and LNZ units
# - Coordinates viewport visuals (gizmos, labels, and cursors)

# SECTIONS:
#	SETUP & INITIALIZATION
#	INPUT HANDLING
#	MODE MANAGEMENT
#	PALETTE VIEWER
#	VARIATION VIEWER
#	RECOLOR MODE
#	PAINT MODE
#	SHAPE MODE
#	LINE MODE
#	PRESET MODE
#	MOVE MODE

var ui_is_dirty: bool = true

var ref_image_config: Dictionary = {}
var _last_attempted_path: String = ""

onready var default_font: Font = get_font("font")

onready var file_tree: Tree = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree"
)
onready var lnz_text_edit: TextEdit = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit"
)
onready var pet_view: Control = self
onready var pet_node: Node = get_tree().root.get_node("Root/PetRoot/Node")

var px_scale: float setget , get_px_scale
var lnz_scale: float setget , get_lnz_scale

onready var camera_holder: Spatial = get_tree().root.get_node("Root/SceneRoot/ViewportContainer/Viewport/CameraHolder") as Spatial
onready var camera: Camera = camera_holder.get_node("Camera") as Camera

onready var ball_label: Label = get_tree().root.find_node("BallLabel", true, false)
onready var help_popup: WindowDialog = get_tree().root.find_node("HelpPopupDialog", true, false)
onready var recolor_popup: ConfirmationDialog = get_tree().root.find_node("RecolorPopup", true, false)
onready var helper_label: Label = find_node("HelperLabel")
onready var cube: Spatial = get_tree().root.get_node("Root/PetRoot/MeshInstance") as Spatial
onready var tex: ViewportContainer = get_tree().root.get_node("Root/SceneRoot/ViewportContainer") as ViewportContainer

onready var auto_paintballer_check_box: CheckBox = find_node("AutoPaintballerModeCheckBox")

onready var view_palette_check_box: CheckBox = find_node("ViewPaletteButton")

onready var reference_image_bg: TextureRect = get_tree().root.find_node("ReferenceImageBg", true, false)

onready var view_variations_check_box: CheckBox = find_node("ViewVariationsCheckBox")
onready var variation_tree: Tree = get_tree().root.get_node(
	"Root/SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/Variations"
)

onready var select_check_box: CheckBox = find_node("SelectCheckBox")

onready var recolor_mode_check_box: CheckBox = find_node("RecolorModeCheckBox")
onready var texture_editor_mode_check_box: CheckBox = find_node("TextureEditorModeCheckBox")
var texture_editor_mode: bool = false

onready var paintball_check_box: CheckBox = find_node("PaintballModeCheckBox")
onready var move_mode_check_box: CheckBox = find_node("MoveModeCheckBox")
onready var line_mode_check_box: CheckBox = find_node("LineModeCheckBox")
onready var project_mode_check_box: CheckBox = find_node("ProjectModeCheckBox")
onready var preset_mode_check_box: CheckBox = find_node("PresetModeCheckBox")

onready var tools_menu: Node = get_tree().root.get_node("Root/SceneRoot/ToolsMenu")
onready var hidden_balls_label: Label = find_node("HiddenBallsLabel")

var _auto_paint_affected_cache: Array = []

var _spatial_grid_2d: Dictionary = {}
const GRID_CELL_SIZE: float = 80.0

var _nearby_balls_cache: Array = []
var _current_tab_index: int = -1
var _last_selected_by_tab: Spatial = null
var _tab_activation_mouse_pos: Vector2 = Vector2.ZERO
const MAX_NEARBY_BALLS: int = 6
const NEARBY_SCREEN_RADIUS: float = 60.0
const TAB_RESET_THRESHOLD_PIXELS: float = 15.0

enum Mode { NONE, MOVE, PAINTBALL, LINE, PRESET, RECOLOR, PROJECT, AUTO_PAINTBALLER, TEXTURE_EDITOR }
var current_mode: int = Mode.NONE

var input_is_paused: bool = false

var last_selected = null
var selecting_on: bool = false
var active_selected_ball = null

var is_dragging: bool = false
var drag_ball = null
var drag_offset: Vector3 = Vector3()
var pixel_world_size: float = 0.002

var drag_started_via_code: bool = false
var pending_autodrag_addball_no: int = -1

var is_resizing: bool = false
var original_lnz_size: int = 0
var original_scale: float = 1.0
var drag_start_pos: Vector2 = Vector2()

var _scale_group_pivot: Vector3 = Vector3.ZERO
var _scale_group_initial_data: Dictionary = {}

var _group_panning: bool = false
var _group_pan_start_pos: Vector2 = Vector2.ZERO
var _group_pan_start_origin: Vector3 = Vector3.ZERO

var sidebar_controller = null

var linez_mode: bool = false
var linez_start_ball = null
var line_mode_close: bool = false

var polygon_mode: bool = false
var polygon_balls: Array = []
const MAX_POLYGON_BALLS: int = 4

var paintball_mode: bool = false
var project_mode: bool = false
var auto_paintballer_mode: bool = false
var move_mode: bool = false
var recolor_mode: bool = false
var preset_mode: bool = false

var paintball_target_ball = null
var ray_intersect_paintball = null
var close_paintball_on_apply: bool = false

var freeline_active: bool = false
var freeline_path: Array = []
var last_freeline_point: Vector2 = Vector2()

var _ordered_color_index: int = 0
var _ordered_outline_color_index: int = 0
var _ordered_texture_index: int = 0

var gizmo_3d_root: Spatial
var gizmo_x: MeshInstance
var gizmo_y: MeshInstance
var gizmo_z: MeshInstance
var labels_3d: Dictionary = {}
const GIZMO_OPACITY: float = 0.5

# onready var paintball_settings_instance = preload("res://scenes/editor/PaintballSettings.tscn").instance()
# onready var project_settings_instance = preload("res://scenes/editor/ProjectSettings.tscn").instance()
# onready var preset_settings_instance = preload("res://scenes/editor/PresetSettings.tscn").instance()
# onready var auto_paintballer_settings_instance = preload("res://scenes/editor/AutoPaintballerSettings.tscn").instance()
# onready var palette_viewer_instance = preload("res://scenes/editor/PaletteViewer.tscn").instance()
# onready var move_mode_settings_instance = preload("res://scenes/editor/MoveModeSettings.tscn").instance()
# onready var line_mode_settings_instance = preload("res://scenes/editor/LineModeSettings.tscn").instance()

var palette_viewer_instance: Control
var recolor_settings_instance: Control
var paintball_settings_instance: Control
var move_mode_settings_instance: Control
var line_mode_settings_instance: Control
var project_settings_instance: Control
var preset_settings_instance: Control
var auto_paintballer_settings_instance: Control
var texture_editor_settings_instance: Control

var shader_settings_instance: Control

var diameter_min_spinbox: SpinBox
var diameter_max_spinbox: SpinBox
var eraser_check_box: CheckBox
var pivot_ball_spinbox: SpinBox
var use_pivot_check_box: CheckBox

#var hand_neutral = load("res://resources/icons/ico_hand_neutral_2x.png")
var hand_neutral: Texture = load("res://resources/icons/ico_hand_neutral_2x_64px.png")
#var hand_move = load("res://resources/icons/ico_hand_move_2x.png")
var hand_move: Texture = load("res://resources/icons/ico_hand_move_2x_64px.png")
#var hand_pinch = load("res://resources/icons/ico_hand_pinch_2x.png")
var hand_pinch: Texture = load("res://resources/icons/ico_hand_pinch_2x_64px.png")
#var hand_stretch = load("res://resources/icons/ico_hand_stretch_2x.png")
var hand_stretch: Texture = load("res://resources/icons/ico_hand_stretch_2x_64px.png")
#var eyedropper = load("res://resources/icons/ico_tool_eyedropper_2x.png")
var eyedropper: Texture = load("res://resources/icons/ico_tool_eyedropper_2x_64px.png")
#var smallbrush = load("res://resources/icons/ico_tool_paintbrush_2x.png")
var smallbrush: Texture = load("res://resources/icons/ico_tool_paintbrush_2x_64px.png")
#var bigbrush = load("res://resources/icons/ico_tool_brush_2x.png")
var bigbrush: Texture = load("res://resources/icons/ico_tool_brush_2x_64px.png")
#var paintbucket = load("res://resources/icons/ico_tool_bucket_2x.png")
var paintbucket: Texture = load("res://resources/icons/ico_tool_bucket_2x_64px.png")
#var rope = load("res://resources/icons/icon_line_mode.png")
var rope: Texture = load("res://resources/icons/icon_line_mode_2x_64px.png")
#var eraser = load("res://resources/icons/ico_eraser_2x.png")
var eraser: Texture = load("res://resources/icons/ico_eraser_2x_64px.png")

const ZOOM_STEP: float = 1.2

var selected_balls: Array = []
var locked_balls: Array = []
var pending_moves: Dictionary = {}  # ball_no -> {orig_pos: Vector3, new_pos: Vector3}

var _locked_balls_cache: Array = []

var _pre_move_state: Dictionary = {}

var box_selecting: bool = false
var box_start_pos: Vector2 = Vector2()
var box_end_pos: Vector2 = Vector2()

const MAX_INTERACTION_HISTORY: int = 25

var paint_history: Array = []
var paint_redo_stack: Array = []

var move_history: Array = []
var move_redo_stack: Array = []

var hotkey_overlay_scene: PackedScene = preload("res://scenes/editor/HotkeyOverlay.tscn")
var hotkey_overlay_instance: Node = null

var _overlay_viewport_container: ViewportContainer = null
var _overlay_viewport: Viewport = null
var _overlay_camera: Camera = null
var _dimmer_rect: ColorRect = null

var design_rotation_angle: float = 0.0
var design_scale_multiplier: float = 1.0


### SETUP & INITIALIZATION ###
# _safe_connect
# _ready
# update_config_reference_image
# _update_reference_image_bg
# _ensure_panel_visible
# _rebuild_spatial_hash
# _reset_tab_state
# mark_ui_dirty
# get_px_scale
# get_lnz_scale
# _process
# _draw
# _setup_3d_gizmos
# _create_gizmo_line
# _update_3d_gizmo_visibility

func _safe_connect(target: Node, sig: String, method: String) -> void:
	if target and target.has_signal(sig) and not target.is_connected(sig, self, method):
		target.connect(sig, self, method)

func _ready() -> void:
	hotkey_overlay_instance = hotkey_overlay_scene.instance()
	add_child(hotkey_overlay_instance)

	set_process_unhandled_key_input(true)
	set_process(true)

	paintball_settings_instance = load("res://scenes/editor/PaintballSettings.tscn").instance()
	project_settings_instance = load("res://scenes/editor/ProjectSettings.tscn").instance()
	preset_settings_instance = load("res://scenes/editor/PresetSettings.tscn").instance()
	auto_paintballer_settings_instance = load("res://scenes/editor/AutoPaintballerSettings.tscn").instance()
	palette_viewer_instance = load("res://scenes/editor/PaletteViewer.tscn").instance()
	move_mode_settings_instance = load("res://scenes/editor/MoveModeSettings.tscn").instance()
	line_mode_settings_instance = load("res://scenes/editor/LineModeSettings.tscn").instance()
	recolor_settings_instance = load("res://scenes/editor/RecolorSettings.tscn").instance()
	texture_editor_settings_instance = load("res://scenes/editor/TextureEditor.tscn").instance()
	shader_settings_instance = load("res://scenes/editor/ShaderSettings.tscn").instance()

	var sidebar_node: Node = get_tree().root.find_node("VBoxContainer", true, false)
	var sidebars: Array = get_tree().get_nodes_in_group("SidebarController")
	if sidebars.size() > 0:
		sidebar_controller = sidebars[0]
	elif sidebar_node and sidebar_node.has_method("add_tool_tab"):
		sidebar_controller = sidebar_node

	if sidebar_controller:
		sidebar_controller.call_deferred("add_tool_tab", palette_viewer_instance, "Palette")
		sidebar_controller.call_deferred("add_tool_tab", recolor_settings_instance, "Recolor")
		sidebar_controller.call_deferred("add_tool_tab", texture_editor_settings_instance, "Texture")
		sidebar_controller.call_deferred("add_tool_tab", paintball_settings_instance, "Paint")
		sidebar_controller.call_deferred("add_tool_tab", move_mode_settings_instance, "Move")
		sidebar_controller.call_deferred("add_tool_tab", line_mode_settings_instance, "Line")
		sidebar_controller.call_deferred("add_tool_tab", preset_settings_instance, "Preset")
		sidebar_controller.call_deferred("add_tool_tab", auto_paintballer_settings_instance, "AutoPaint")
		sidebar_controller.call_deferred("add_tool_tab", project_settings_instance, "Shape")

	else:
		print("[WARNING] PetViewContainer: SidebarController not found, adding settings to SceneRoot as fallback")
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", palette_viewer_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", recolor_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", texture_editor_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", paintball_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", move_mode_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", line_mode_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", preset_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", auto_paintballer_settings_instance)
		get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", project_settings_instance)

	get_tree().root.get_node("Root/SceneRoot").call_deferred("add_child", shader_settings_instance)
	
	paintball_check_box.connect("toggled", self, "_on_paintball_mode_toggled")
	preset_mode_check_box.connect("toggled", self, "_on_preset_mode_toggled")
	project_mode_check_box.connect("toggled", self, "_on_project_mode_toggled")

	auto_paintballer_check_box.connect("toggled", self, "_on_auto_paintballer_mode_toggled")

	view_palette_check_box.connect("toggled", self, "_on_view_palette_check_box_toggled")
	palette_viewer_instance.connect("visibility_changed", self, "_on_palette_visibility_changed")

	view_variations_check_box.connect("toggled", self, "_on_view_variations_toggled")
	variation_tree.connect("visibility_changed", self, "_on_variation_visibility_changed")

	line_mode_check_box.connect("toggled", self, "_on_line_mode_toggled")
	line_mode_settings_instance.connect("polygon_mode_toggled", self, "_on_polygon_mode_toggled")
	move_mode_check_box.connect("toggled", self, "_on_move_mode_toggled")
	recolor_mode_check_box.connect("toggled", self, "_on_recolor_mode_toggled")
	texture_editor_mode_check_box.connect("toggled", self, "_on_texture_editor_mode_toggled")

	tools_menu.connect(
		"paintball_mode_for_ball_toggled", self, "_on_paintball_mode_for_ball_toggled"
	)

	if is_instance_valid(lnz_text_edit):
		paintball_settings_instance.connect(
			"apply_paintballz", lnz_text_edit, "_on_apply_paintballz"
		)
		lnz_text_edit.connect("create_polygon", self, "_on_LnzTextEdit_create_polygon")
	if is_instance_valid(pet_node):
		paintball_settings_instance.connect("clear_paintballz", pet_node, "clear_pending_paintballz")
	paintball_settings_instance.connect("delete_mode_toggled", self, "_on_delete_mode_toggled")

	if is_instance_valid(pet_node):
		pet_node.connect("palette_changed", preset_settings_instance, "set_palette")
	preset_settings_instance.connect("eyedropper_toggled", self, "_on_eyedropper_toggled")
	preset_settings_instance.connect("apply_to_selection", self, "_on_preset_apply_selection")
	preset_settings_instance.connect("unselect_all", self, "_on_unselect_all")
	preset_settings_instance.connect("select_balls_by_ids", self, "_on_select_balls_by_ids")

	if is_instance_valid(lnz_text_edit):
		project_settings_instance.connect("apply_projections", lnz_text_edit, "write_project_ball_section")
	project_settings_instance.connect("randomize_body_proportions", self, "_on_randomize_body_proportions")
	project_settings_instance.connect("randomize_moves", self, "_on_randomize_moves")

	if is_instance_valid(pet_node):
		auto_paintballer_settings_instance.connect("randomize_auto_paintballz", pet_node, "_on_randomize_auto_paintballz")
		auto_paintballer_settings_instance.connect("clear_auto_paintballz", pet_node, "clear_auto_paintballz")
		auto_paintballer_settings_instance.connect("apply_auto_paintballz", pet_node, "_on_apply_auto_paintballz")
		pet_node.connect("hidden_balls_changed", self, "_on_hidden_balls_changed")

	auto_paintballer_settings_instance.connect("apply_auto_paintballz", self, "_restore_auto_paintballer_selection")
	auto_paintballer_settings_instance.connect("affected_list_changed", self, "_on_affected_list_changed")
	auto_paintballer_settings_instance.connect("unselect_all", self, "_on_unselect_all")

	move_mode_settings_instance.connect("apply_moves", self, "_on_move_mode_apply")
	move_mode_settings_instance.connect("clear_moves", self, "_on_move_mode_clear")
	move_mode_settings_instance.connect("unselect_all", self, "_on_unselect_all")
	move_mode_settings_instance.connect("unselect_side", self, "_on_unselect_side")
	move_mode_settings_instance.connect("align_selection", self, "_on_align_selection")
	move_mode_settings_instance.connect("snap_selection", self, "_on_snap_selection")
	move_mode_settings_instance.connect("nudge_selection", self, "_on_nudge_selection")
	move_mode_settings_instance.connect("select_group", self, "_on_move_mode_select_group")
	move_mode_settings_instance.connect("rotate_selection", self, "_on_rotate_selection")
	move_mode_settings_instance.connect("select_balls_by_ids", self, "_on_select_balls_by_ids")
	move_mode_settings_instance.connect("flip_selection", self, "_on_flip_selection")
	move_mode_settings_instance.connect("pivot_changed", self, "_on_pivot_changed")
	move_mode_settings_instance.connect("apply_scale", self, "_on_apply_scale")
	move_mode_settings_instance.connect("lock_all", self, "_on_lock_all")
	move_mode_settings_instance.connect("unlock_all", self, "_on_unlock_all")
	move_mode_settings_instance.connect("select_locked_balls_by_ids", self, "_on_select_locked_balls_by_ids")

	if is_instance_valid(lnz_text_edit):
		recolor_settings_instance.connect("recolor", lnz_text_edit, "_on_ToolsMenu_recolor")
		recolor_settings_instance.connect("apply_batch_bucket", lnz_text_edit, "apply_batch_presets")

	var shader_settings_btn: Button = get_tree().root.get_node_or_null("Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/FileOptionButton/PopupPanel/FileOptionContainer/ShaderSettingsButton")
	if is_instance_valid(shader_settings_btn):
		shader_settings_btn.connect("pressed", self, "_on_ShaderSettingsButton_pressed")

	if is_instance_valid(shader_settings_instance):
		shader_settings_instance.connect("texture_rotation_mode_changed", self, "_on_texture_rotation_mode_changed")
		shader_settings_instance.connect("texture_rotation_input_changed", self, "_on_texture_rotation_input_changed")
		shader_settings_instance.connect("texture_affected_by_size_changed", self, "_on_texture_affected_by_size_changed")
		shader_settings_instance.connect("texture_affected_by_rotation_changed", self, "_on_texture_affected_by_rotation_changed")
		shader_settings_instance.connect("texture_flat_colors_changed", self, "_on_texture_flat_colors_changed")
		# shader_settings_instance.connect("texture_use_quadrants_changed", self, "_on_texture_use_quadrants_changed")
		
#		shader_settings_instance.connect("texture_rotation_mode_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
#		shader_settings_instance.connect("texture_rotation_input_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
#		shader_settings_instance.connect("texture_affected_by_size_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
#		shader_settings_instance.connect("texture_affected_by_rotation_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")
#		shader_settings_instance.connect("texture_flat_colors_changed", get_tree().root.get_node("Root/SceneRoot"), "save_settings")

	diameter_min_spinbox = paintball_settings_instance.find_node("DiameterMin")
	diameter_max_spinbox = paintball_settings_instance.find_node("DiameterMax")
	eraser_check_box = paintball_settings_instance.find_node("EraserCheckBox")
	pivot_ball_spinbox = move_mode_settings_instance.find_node("PivotBall")
	use_pivot_check_box = move_mode_settings_instance.find_node("UsePivotCheckBox")

	Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_IBEAM, Vector2(30, 31))
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_CROSS, Vector2(30, 31))
	Input.set_custom_mouse_cursor(hand_neutral, Input.CURSOR_POINTING_HAND, Vector2(30, 31))

	helper_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	select_check_box.connect("pressed", self, "_on_SelectCheckBox_pressed")

	var mode_popup: PopupPanel = get_tree().root.get_node(
		"Root/SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer/VBoxContainer/DropDownMenu/ModeOptionButton/PopupPanel"
	)
	mode_popup.connect("about_to_show", self, "_on_ModePopup_about_to_show")

	call_deferred("_sync_shader_settings_to_pet")
	_setup_3d_gizmos()

	# check flipped view...
	tex.rect_scale.x = -1.0
	tex.rect_pivot_offset = tex.rect_size / 2.0

func _sync_shader_settings_to_pet():
	if is_instance_valid(shader_settings_instance) and is_instance_valid(pet_node):
		pet_node._shader_rotation_mode = shader_settings_instance.get_mode()
		pet_node._shader_rotation_input = shader_settings_instance.get_input_vec()
		pet_node._shader_affected_by_size = shader_settings_instance.get_affected_by_size()
		pet_node._shader_affected_by_rotation = shader_settings_instance.get_affected_by_rotation()

func _on_reference_image_updated(config_data: Dictionary) -> void:
	update_config_reference_image(config_data)

func update_config_reference_image(config_data: Dictionary) -> void:
	ref_image_config = config_data
	if not ref_image_config.empty() and ref_image_config.get("show_bg", false):
		var current_path: String = ref_image_config.get("path", "")
		if _last_attempted_path != current_path:
			_last_attempted_path = "" 
	_update_reference_image_bg()

func _update_reference_image_bg() -> void:
	var bg: TextureRect = reference_image_bg
	if not bg: return

	var current_path: String = ref_image_config.get("path", "")

	if ref_image_config.empty() or not ref_image_config.get("show_bg", false) or current_path == "":
		bg.texture = null
		bg.hide()
		_last_attempted_path = ""
		return

	if _last_attempted_path != current_path:
		_last_attempted_path = current_path
		
		if bg.texture != null:
			bg.texture.unreference()
			bg.texture = null
		
		var image: Image = Image.new()
		var err: int = image.load(current_path, false, false)
		if err == OK:
			var texture: ImageTexture = ImageTexture.new()
			texture.create_from_image(image)
			texture.resource_path = current_path
			bg.texture = texture
			bg.show()
			print("[STATUS] PetViewContainer: Successfully loaded reference background: ", current_path)
		else:
			bg.texture = null
			bg.hide()
			print("[ERROR] PetViewContainer: Failed to load reference background: ", current_path, " (Error Code: ", err, "). Aborting subsequent read attempts.")
	
	elif bg.texture != null:
		bg.show()
	else:
		bg.hide()
		return 

	if is_instance_valid(tex):
		var scene_root: Node = tex.get_parent()
		if bg.get_parent() != scene_root:
			bg.get_parent().remove_child(bg)
			scene_root.add_child(bg)
			scene_root.move_child(bg, tex.get_index())

		var manual_scale: float = ref_image_config.get("scale_value", 1.0)
		var current_zoom: float = (abs(tex.rect_scale.y) * manual_scale) if ref_image_config.get("scale", false) else manual_scale

		if ref_image_config.get("center", true):
			bg.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			bg.rect_position = tex.rect_position
			bg.rect_size = tex.rect_size
			bg.rect_pivot_offset = tex.rect_size / 2.0
			bg.rect_scale = Vector2(current_zoom, current_zoom)
		else:
			bg.stretch_mode = TextureRect.STRETCH_KEEP
			var img_size: Vector2 = bg.texture.get_size() if bg.texture else Vector2.ZERO
			
			bg.rect_size = img_size
			bg.rect_scale = Vector2(current_zoom, current_zoom)
			bg.rect_pivot_offset = Vector2.ZERO
			
			var offset_x: float = ref_image_config.get("x", 0)
			var offset_y: float = ref_image_config.get("y", 0)
			var scaled_img_size: Vector2 = img_size * current_zoom
			var center_start: Vector2 = tex.rect_position + (tex.rect_size / 2.0) - (scaled_img_size / 2.0)
			
			bg.rect_position = center_start + Vector2(offset_x, offset_y)

func _ensure_panel_visible(panel: Control) -> void:
	if panel.is_docked:
		if sidebar_controller and sidebar_controller.tab_container.current_tab != panel.get_index():
			sidebar_controller.switch_to_tab(panel)
	else:
		panel.show()
		panel.raise()

func _rebuild_spatial_hash() -> void:
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	_spatial_grid_2d.clear()
	var all_balls: Array = _get_all_visual_balls()
	var viewport_offset: Vector2 = tex.get_global_transform().origin
	
	for ball in all_balls:
		if not is_instance_valid(ball) or not ball.visible: 
			continue
			
		var projected_pos: Vector2 = camera.unproject_position(ball.global_transform.origin) 
		var screen_pos: Vector2 = viewport_offset + (projected_pos * tex.rect_scale) 
		
		var cell: Vector2 = (screen_pos / GRID_CELL_SIZE).floor()
		if not _spatial_grid_2d.has(cell):
			_spatial_grid_2d[cell] = []
		_spatial_grid_2d[cell].append(ball)
	
	#var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	#var _perf_stat_end: int = OS.get_static_memory_usage()
	#var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	#print("[PERF] _rebuild_spatial_hash took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	#	OS.get_ticks_msec() - _perf_start_time,
	#	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	#	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	#	_perf_orphans
	#])

func _reset_tab_state() -> void:
	if is_instance_valid(_last_selected_by_tab):
		if not move_mode:
			_last_selected_by_tab.apply_outline_state(
				get_visual_state_for_ball(_last_selected_by_tab)
			)
	_last_selected_by_tab = null
	_current_tab_index = -1
	_nearby_balls_cache.clear()
	_tab_activation_mouse_pos = Vector2.ZERO
	mark_ui_dirty()

func mark_ui_dirty() -> void:
	# Use to trigger _process so it's not triggering every time the mouse moves...
	ui_is_dirty = true

func get_px_scale() -> float:
	if not is_instance_valid(pet_node):
		return 0.002
	return pet_node.pixel_world_size

func get_lnz_scale() -> float:
	if not is_instance_valid(pet_node):
		return 1.0
	
	if not pet_node.has_method("get") or pet_node.get("lnz") == null:
		return 1.0
		
	var lnz_data = pet_node.get("lnz")
	
	if typeof(lnz_data) != TYPE_DICTIONARY:
		return 1.0
		
	if not lnz_data.has_key("scales"):
		return 1.0
		
	var scales = lnz_data["scales"]
	
	if scales == null:
		return 1.0
		
	if typeof(scales) == TYPE_VECTOR2:
		return scales.x / 255.0
	elif typeof(scales) == TYPE_VECTOR3:
		return scales.x / 255.0
	else:
		if scales is Array and scales.size() > 0:
			return scales[0] / 255.0
		return 1.0

func _process(_delta: float) -> void:
	_update_reference_image_bg()
	if is_instance_valid(_overlay_camera):
		_sync_overlay()

	# AXIS GIZMO
	_update_3d_gizmo_visibility()

	# Always sync Preset Mode preview ball
	if preset_mode and is_instance_valid(preset_settings_instance):
		preset_settings_instance.sync_camera(camera.global_transform)

	# Skip helper text update, if UI is not dirty
	if not ui_is_dirty:
		return

	# HELPER TEXT
	var header: String = ""
	var body: String = ""
	var footer: String = ""

	# HIGHLIGHTS
	var highlighted_ball = null
	if is_instance_valid(_last_selected_by_tab):
		highlighted_ball = _last_selected_by_tab
		var b_name: String = lnz_text_edit.get_ball_name(highlighted_ball.ball_no)
		var total_count: int = _nearby_balls_cache.size()
		var current_idx: int = max(0, _current_tab_index) + 1
		header = "Hovered: %s #%d (cyclable %d/%d)" % [b_name, highlighted_ball.ball_no, current_idx, total_count]
	elif selecting_on and last_selected_is_valid():
		highlighted_ball = last_selected
		var b_name: String = lnz_text_edit.get_ball_name(highlighted_ball.ball_no)
		header = "Hovered: %s #%d" % [b_name, highlighted_ball.ball_no]

	# MODES
	if linez_mode:
		var intended = get_intended_ball(_get_viewport_pos_from_screen_pos(get_local_mouse_position())) 
		
		if polygon_mode:
			if polygon_balls.size() > 0:
				body = "Polygon Mode: Click %d more ball(s) to complete polygon" % [MAX_POLYGON_BALLS - polygon_balls.size()]
			else:
				body = "Polygon Mode: Click 4 balls in order to create a polygon (key N to cycle ballz)"
		elif is_instance_valid(linez_start_ball): 
			body = "Line Mode: Left-click target to END line (key N to cycle ballz)"
		else:
			body = "Line Mode: Left-click target to START line (key N to cycle ballz)"
		
		Input.set_custom_mouse_cursor(rope, 0, Vector2(30, 31))

	elif paintball_mode:
		#paintball_settings_instance.sync_camera(camera.global_transform)
		var delete_mode: bool = paintball_settings_instance.find_node("EraserCheckBox").pressed
		var temp_eraser_active: bool = Input.is_key_pressed(KEY_CONTROL)
		var is_design_mode: bool = paintball_settings_instance.is_design_mode_active()

		if delete_mode:
			body = "Paintball Mode: Left-click to erase nearest paintball."
		elif temp_eraser_active:
			if is_design_mode:
				body = "Design Mode: Ctrl+Scroll to Scale | Left-Click to Stamp."
			else:
				body = "Paintball Mode: Left-click to erase nearest paintball."
				Input.set_custom_mouse_cursor(eraser, 0, Vector2(30, 31))
		elif is_design_mode:
			body = "Design Mode: Stamp pattern onto ball.\nScroll to Rotate | Ctrl+Scroll to Scale."
			Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
		else:
			var freeline_on: bool = (
				paintball_settings_instance.find_node("FreelineCheckBox").pressed
				or Input.is_key_pressed(KEY_SHIFT)
			)
			var straight_line_on: bool = (
				freeline_on
				and (
					paintball_settings_instance.find_node("StraightLineCheckBox").pressed
					or Input.is_key_pressed(KEY_ALT)
					or Input.is_key_pressed(KEY_L)
				)
			)
			if straight_line_on:
				body = "Paintball Mode (Straight Line): Click and drag to draw. Hold X/Y to lock axis."
			elif freeline_on:
				body = "Paintball Mode (Freeline): Left-click and drag to draw."
			else:
				body = "Paintball Mode: Left-click to add next paintball"
			Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			body += "\nPainting on ball " + str(paintball_target_ball.ball_no)

	elif auto_paintballer_mode:
		body = "Auto Paintballer: Use the panel to generate random paintballz patterns. Click ballz to affect. Hit 'Apply' to save changes."

	elif project_mode:
		body = "Project Mode: Use the panel to add or randomize projections.\nHit 'Apply to LNZ' to save changes."

	elif move_mode:
		var queued_count: int = pending_moves.size()
		var hint: String = "Move Mode: Click to select, CTRL+Click to toggle multiple.\nDrag selected balls to move group. Q = lock hovered ball."
		if not selected_balls.empty():
			hint += "\nSHIFT + drag = pan selected group"
		body = hint
		if queued_count > 0:
			body += "\nQueued Moves: " + str(queued_count)

	elif preset_mode:
		preset_settings_instance.sync_camera(camera.global_transform)
		var is_eyedropper: bool = (
			Input.is_key_pressed(KEY_ALT)
			or preset_settings_instance.is_eyedropper_active()
		)
		if is_eyedropper:
			body = "Eyedropper Mode: Left-click a ball to sample its properties."
			Input.set_custom_mouse_cursor(eyedropper, 0, Vector2(30, 31))
		else:
			body = "Preset Mode: Left-click to apply preset.\nHold ALT for eyedropper."
			if not preset_settings_instance.find_node("EyedropperToggle").pressed:
				Input.set_custom_mouse_cursor(bigbrush, 0, Vector2(30, 31))

	elif recolor_mode:
		body = "Recolor Mode: Use Color Swap to replace colors or Paint Bucket to queue changes.\n(key N to cycle nearby ballz)"
		Input.set_custom_mouse_cursor(paintbucket, 0, Vector2(30, 31))

	elif selecting_on:
		body = "Select Mode: when hovering, cycle ballz using N key..."

	elif is_dragging:
		pass
		#update() # AXIS GIZMO

	else:
		if Input.is_key_pressed(KEY_CONTROL):
			body = "Open Tools Menu (CTRL + SPACE)\nApply and Save Changes (CTRL + S)\nFlash Ballz (CTRL + Q)"
		elif Input.is_key_pressed(KEY_SHIFT):
			body = "Move Ball (SHIFT + left-click drag)\nScale Ball (SHIFT + ALT + left-click drag)"
		elif Input.is_key_pressed(KEY_SPACE):
			body = "Pan View (SPACE + left-click drag)"
		else:
			body = "Welcome to LnzLive!\nHelpful hints will appear here..."

	# HOTKEYS
	if highlighted_ball:
		footer = "\nZ or B: [Ball Info] or [Add Ball] | X or M: [Move]\nC or P: [Project Ball] | V or L: [Line]"

	var locks: Array = []
	if Input.is_key_pressed(KEY_X):
		locks.append("X")
	if Input.is_key_pressed(KEY_Y):
		locks.append("Y")
	if Input.is_key_pressed(KEY_Z):
		locks.append("Z")
	if locks.size() > 0:
		var lock_str: String = "Axis Lock: " + str(locks)
		if footer != "":
			footer += " | " + lock_str
		elif body != "Welcome to LnzLive!\nHelpful hints will appear here...":
			body += " | " + lock_str
		else:
			body = lock_str

	# HELPER
	var final_text: String = body
	if header != "":
		final_text = header + "\n" + final_text
	if footer != "":
		final_text += footer

	if helper_label.text != final_text:
		helper_label.text = final_text

	ui_is_dirty = false

func _draw() -> void:
	# BOX SELECTION
	if box_selecting:
		var rect: Rect2 = Rect2(box_start_pos, box_end_pos - box_start_pos)
		draw_rect(rect, Color(0.5, 1, 0.5, 0.2), true)
		draw_rect(rect, Color(0.5, 1, 0.5, 0.8), false)

	# TAB RADIUS
	# if selecting_on:
	# 	var mouse_pos: Vector2 = get_local_mouse_position()
	# 	draw_arc(mouse_pos, NEARBY_SCREEN_RADIUS, 0, TAU, 32, Color(1, 1, 0, 0.5), 2.0)

	# AXIS GIZMOS
	# var reference_ball = null

	# if is_dragging and is_instance_valid(drag_ball):
	# 	reference_ball = drag_ball
	# elif move_mode and not selected_balls.empty():
	# 	if is_instance_valid(selected_balls[0]):
	# 		reference_ball = selected_balls[0]

	# if reference_ball:
	# 	_draw_axis_gizmos(reference_ball)

func _setup_3d_gizmos() -> void:
	gizmo_3d_root = Spatial.new()
	pet_node.add_child(gizmo_3d_root)
	gizmo_3d_root.visible = false

	gizmo_x = _create_gizmo_line(Color.red, Vector3(1, 0, 0))
	gizmo_y = _create_gizmo_line(Color.green, Vector3(0, 1, 0))
	gizmo_z = _create_gizmo_line(Color.blue, Vector3(0, 0, 1))

	gizmo_3d_root.add_child(gizmo_x)
	gizmo_3d_root.add_child(gizmo_y)
	gizmo_3d_root.add_child(gizmo_z)

func _create_gizmo_line(color: Color, direction: Vector3) -> MeshInstance:
	var mi: MeshInstance = MeshInstance.new()
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.001
	cylinder.bottom_radius = 0.001
	cylinder.height = 0.5

	var mat: SpatialMaterial = SpatialMaterial.new()
	mat.flags_unshaded = true
	mat.flags_transparent = true
	mat.albedo_color = Color(color.r, color.g, color.b, GIZMO_OPACITY)
	mat.flags_no_depth_test = true

	mi.mesh = cylinder
	mi.material_override = mat

	if direction.x != 0:
		mi.rotation_degrees = Vector3(0, 0, 90)
	elif direction.z != 0:
		mi.rotation_degrees = Vector3(90, 0, 0)

	return mi

func _update_3d_gizmo_visibility() -> void:
	var reference_ball = null

	if is_dragging and is_instance_valid(drag_ball):
		reference_ball = drag_ball
	elif move_mode and not selected_balls.empty():
		reference_ball = selected_balls[0]
	elif selecting_on and is_instance_valid(last_selected):
		reference_ball = last_selected

	if not reference_ball or not is_instance_valid(reference_ball):
		gizmo_3d_root.visible = false
		return

	gizmo_3d_root.global_transform.origin = reference_ball.global_transform.origin

	var hotkey_x: bool = Input.is_key_pressed(KEY_X)
	var hotkey_y: bool = Input.is_key_pressed(KEY_Y)
	var hotkey_z: bool = Input.is_key_pressed(KEY_Z)
	var any_hotkey: bool = hotkey_x or hotkey_y or hotkey_z

	var ui_active_x: bool = false
	var ui_active_y: bool = false
	var ui_active_z: bool = false

	if move_mode and is_instance_valid(move_mode_settings_instance):
		match move_mode_settings_instance.current_constraint_mode:
			"LockX":
				ui_active_x = true
			"LockY":
				ui_active_y = true
			"LockZ":
				ui_active_z = true
			"LockXY":
				ui_active_x = true
				ui_active_y = true
			"LockXZ":
				ui_active_x = true
				ui_active_z = true
			"LockYZ":
				ui_active_y = true
				ui_active_z = true
			"Free":
				ui_active_x = false
				ui_active_y = false
				ui_active_z = false

	var show_x: bool = hotkey_x if any_hotkey else ui_active_x
	var show_y: bool = hotkey_y if any_hotkey else ui_active_y
	var show_z: bool = hotkey_z if any_hotkey else ui_active_z

	if not is_dragging:
		gizmo_3d_root.visible = false
		return

	gizmo_x.visible = show_x
	gizmo_y.visible = show_y
	gizmo_z.visible = show_z

	if not is_dragging and not any_hotkey:
		gizmo_3d_root.visible = false
		return

	gizmo_x.visible = show_x
	gizmo_y.visible = show_y
	gizmo_z.visible = show_z

	gizmo_3d_root.visible = show_x or show_y or show_z


### INPUT HANDLING ###
# _get_ball_sizing_info
# _get_viewport_pos_from_screen_pos
# _get_screen_pos_from_viewport_pos
# _handle_box_selection
# _initialize_move_drag
# _handle_move_mode_gui_input
# _handle_preset_mode_gui_input
# _gui_input
# _handle_camera_view_key_input
# _handle_mode_shortcut_key_input
# _handle_move_nudge_key_input
# _unhandled_key_input
# _set_camera_view
# _on_ShaderSettingsButton_pressed
# _on_texture_rotation_mode_changed
# _on_texture_rotation_input_changed
# _on_texture_affected_by_size_changed
# _on_texture_affected_by_rotation_changed
# _on_texture_flat_colors_changed

func _get_ball_sizing_info(pet_node: Node, ball_no: int) -> Dictionary:
	var is_addball: bool = ball_no >= KeyBallsData.max_base_ball_num
	var bhd_size: int = 0
	var enl_x: float = 100.0
	var enl_y: float = 0.0

	if not is_addball:
		bhd_size = pet_node.bhd.ball_sizes[ball_no]
		
		# Determine if the ball is part of an enlarged group
		var head_ext: Array = KeyBallsData.get_head_ext(pet_node.lnz.species)
		var foot_ext: Array = KeyBallsData.get_foot_ext(pet_node.lnz.species)

		if ball_no in head_ext:
			enl_x = pet_node.lnz.head_enlargement.x
			enl_y = pet_node.lnz.head_enlargement.y
		else:
			for foot_group in foot_ext:
				if ball_no in foot_group:
					enl_x = pet_node.lnz.foot_enlargement.x
					enl_y = pet_node.lnz.foot_enlargement.y
					break
	else:
		if pet_node.lnz.addballs.has(ball_no):
			var ab = pet_node.lnz.addballs[ball_no]
			if ab != null and ab is Dictionary:
				if ab.has("anchor_ball") and ab.anchor_ball != -1:
					if ab.anchor_ball < pet_node.bhd.ball_sizes.size():
						bhd_size = pet_node.bhd.ball_sizes[ab.anchor_ball]


	return {
		"is_addball": is_addball, 
		"bhd_size": bhd_size,
		"enl_x": enl_x,
		"enl_y": enl_y
	}

func _get_viewport_pos_from_screen_pos(screen_pos: Vector2) -> Vector2:
	var global_pos: Vector2 = self.rect_global_position + screen_pos
	return tex.get_global_transform().affine_inverse().xform(global_pos)

func _get_screen_pos_from_viewport_pos(viewport_pos: Vector2) -> Vector2:
	var global_pos: Vector2 = tex.get_global_transform().xform(viewport_pos)
	return global_pos - self.rect_global_position

func _handle_box_selection(event: InputEvent) -> bool:
	if (
		not (move_mode or preset_mode or auto_paintballer_mode)
		or not Input.is_key_pressed(KEY_CONTROL)
	):
		return false

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			box_selecting = true
			box_start_pos = event.position
			box_end_pos = event.position
			return true
		elif box_selecting:
			box_selecting = false
			update()
			if box_start_pos.distance_to(event.position) < 5.0:
				var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
				if hover:
					if hover in selected_balls:
						selected_balls.erase(hover)
					else:
						selected_balls.append(hover)
					if is_instance_valid(hover) and hover.has_method("apply_outline_state"):
						hover.apply_outline_state(get_visual_state_for_ball(hover))
					_update_selected_ballz_in_settings()
			else:
				_commit_box_selection()
			return true

	if event is InputEventMouseMotion and box_selecting:
		box_end_pos = event.position
		update()
		return true

	return false

func _initialize_move_drag(drag_target_ball: Spatial, start_pos: Vector2, resizing: bool = false) -> void:
	is_dragging = true
	drag_ball = drag_target_ball
	drag_start_pos = start_pos
	is_resizing = resizing

	if resizing:
		#_scale_group_pivot = _get_rotation_pivot_origin(int(move_mode_settings_instance.find_node("PivotBall").value) if move_mode_settings_instance.find_node("UsePivotCheckBox").pressed else -1)
		_scale_group_pivot = _get_rotation_pivot_origin(
			int(pivot_ball_spinbox.value) if use_pivot_check_box.pressed else -1
		)

		_scale_group_initial_data.clear()
		for b in selected_balls:
			if is_instance_valid(b):
				_scale_group_initial_data[b.ball_no] = {
					"pos": b.global_transform.origin, "size": b.ball_size
				}
				var partner_id: int = lnz_text_edit.find_mirrored_ball(b.ball_no)
				if partner_id != -1 and partner_id != b.ball_no:
					var mb: Spatial = find_visual_ball_by_no(partner_id)
					if mb:
						_scale_group_initial_data[partner_id] = {
							"pos": mb.global_transform.origin, "size": mb.ball_size
						}
		Input.set_custom_mouse_cursor(hand_pinch, 0, Vector2(30, 31))
	else:
		_record_move_start_state()
		for b in selected_balls:
			if is_instance_valid(b) and "ball_no" in b:
				if not pet_node._orig_world_pos.has(b.ball_no):
					pet_node._orig_world_pos[b.ball_no] = b.global_transform.origin
		Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))

	mark_ui_dirty()

func _handle_move_mode_gui_input(event: InputEvent) -> bool:
	if not move_mode:
		return false

	# Group pan: SHIFT+drag on any area
	if _handle_group_pan_input(event):
		return true

	# Check for Nudge hotkey via Scroll
	if (
		event is InputEventMouseButton
		and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN)
	):
		var nudge_axis: String = ""
		if Input.is_key_pressed(KEY_X):
			nudge_axis = "x"
		elif Input.is_key_pressed(KEY_Y):
			nudge_axis = "y"
		elif Input.is_key_pressed(KEY_Z):
			nudge_axis = "z"

		if nudge_axis != "":
			var delta: float = 1.0 if event.button_index == BUTTON_WHEEL_UP else -1.0
			move_mode_settings_instance.change_nudge_value(nudge_axis, delta)
			get_tree().set_input_as_handled()
			return true

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				if Input.is_key_pressed(KEY_ALT):
					if Input.is_key_pressed(KEY_SHIFT) and selected_balls.size() > 0:
						_initialize_move_drag(selected_balls[0], event.position, true)
						return true
					else:
						var hover_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position)
						var hover_ball = get_intended_ball(hover_pos)
						if hover_ball:
							move_mode_settings_instance.set_pivot_ball(hover_ball.ball_no)
							var all_balls: Array = (
								get_tree().get_nodes_in_group("balls")
								+ get_tree().get_nodes_in_group("addballs")
							)
							for b in all_balls:
								if is_instance_valid(b) and b.has_method("apply_outline_state"):
									b.apply_outline_state(get_visual_state_for_ball(b))
							return true

				var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))

				if hover:
					# Locked balls cannot be selected or moved
					if _is_ball_locked(hover) and not Input.is_key_pressed(KEY_CONTROL):
						return true

					if Input.is_key_pressed(KEY_CONTROL):
						# Toggle selection
						if hover in selected_balls:
							selected_balls.erase(hover)
							hover.apply_outline_state(get_visual_state_for_ball(hover))
						else:
							selected_balls.append(hover)
							hover.apply_outline_state(hover.OutlineState.ACTIVE_SELECTED)
					else:
						if not (hover in selected_balls):
							_on_unselect_all()
							selected_balls.append(hover)
							hover.apply_outline_state(hover.OutlineState.ACTIVE_SELECTED)

					_update_selected_ballz_in_settings()

					if selected_balls.size() > 0:
						_initialize_move_drag(hover, event.position, false)
						return true

				else:
					if not move_mode:
						_on_unselect_all()
			else:
				# Mouse release
				if is_dragging:
					var was_resizing: bool = is_resizing
					is_dragging = false
					is_resizing = false
					Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
					drag_ball = null

					for b in selected_balls:
						if is_instance_valid(b):
							if not pending_moves.has(b.ball_no):
								var orig_p: Vector3 = b.global_transform.origin
								if pet_node._orig_world_pos.has(b.ball_no):
									orig_p = pet_node._orig_world_pos[b.ball_no]

								var orig_s: float = b.ball_size
								if was_resizing and _scale_group_initial_data.has(b.ball_no):
									orig_s = _scale_group_initial_data[b.ball_no]["size"]

								pending_moves[b.ball_no] = {
									"orig_pos": orig_p,
									"new_pos": b.global_transform.origin,
									"orig_size": orig_s,
									"new_size": b.ball_size,
									"orig_basis": b.global_transform.basis,
									"new_basis": b.global_transform.basis
								}
							else:
								pending_moves[b.ball_no]["new_pos"] = b.global_transform.origin
								pending_moves[b.ball_no]["new_size"] = b.ball_size
								if was_resizing and _scale_group_initial_data.has(b.ball_no):
									if (
										not pending_moves[b.ball_no].has("orig_size")
										or (
											pending_moves[b.ball_no]["orig_size"]
											== pending_moves[b.ball_no]["new_size"]
										)
									):
										pending_moves[b.ball_no]["orig_size"] = _scale_group_initial_data[b.ball_no]["size"]

					move_mode_settings_instance.set_queued_count(pending_moves.size())
					_record_move_end_state("Drag Move")
					return true

				mark_ui_dirty()

	elif event is InputEventMouseMotion and is_dragging and drag_ball:
		if is_resizing:
			var mouse_delta: Vector2 = event.position - drag_start_pos
			var change_amount: float = mouse_delta.dot(Vector2(1, -1).normalized()) * 0.05
			var scale_factor: float = max(0.1, 1.0 + change_amount)

			Input.set_custom_mouse_cursor(
				hand_stretch if change_amount > 0 else hand_pinch, 0, Vector2(30, 31)
			)

			var engine_scale: float = pet_node.lnz.scales[1]
			for b_no in _scale_group_initial_data:
				var b: Spatial = find_visual_ball_by_no(b_no)
				if not is_instance_valid(b):
					continue

				var initial: Dictionary = _scale_group_initial_data[b_no]

				var offset_from_pivot: Vector3 = initial.pos - _scale_group_pivot
				b.global_transform.origin = _scale_group_pivot + (offset_from_pivot * scale_factor)

				var target_visual: float = clamp(initial["size"] * scale_factor, 1.0, 500.0)
				var sizing_info: Dictionary = _get_ball_sizing_info(pet_node, b_no)
				var is_addball: bool = sizing_info.is_addball
				var bhd_s: int = sizing_info.bhd_size

				var snapped_visual: float = LnzLiveUtils.snap_visual_size(
					target_visual, is_addball, engine_scale, bhd_s, sizing_info.enl_x, sizing_info.enl_y
				)
				b.set_ball_size(snapped_visual)

			if move_mode_settings_instance.is_mirror_x_active():
				_apply_mirror_scale(
					selected_balls, scale_factor, true, true, _scale_group_pivot, true
				)
			return true

		var screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position)
		var ray_o: Vector3 = camera.project_ray_origin(screen_pos)
		var ray_d: Vector3 = camera.project_ray_normal(screen_pos)

		var plane_n: Vector3 = camera.global_transform.basis.z.normalized()
		var plane_p: Vector3 = drag_ball.global_transform.origin
		var intersect = LnzLiveUtils.intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)

		if intersect:
			var drag_current_pos: Vector3 = intersect

			var prev_screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position - event.relative)
			var prev_ray_o: Vector3 = camera.project_ray_origin(prev_screen_pos)
			var prev_ray_d: Vector3 = camera.project_ray_normal(prev_screen_pos)
			var prev_intersect = LnzLiveUtils.intersect_ray_with_plane(
				prev_ray_o, prev_ray_d, plane_n, plane_p
			)

			if prev_intersect:
				var delta: Vector3 = drag_current_pos - prev_intersect

				var constraints: Dictionary = move_mode_settings_instance.get_constraints()

				var constrain_x: bool = Input.is_key_pressed(KEY_X)
				var constrain_y: bool = Input.is_key_pressed(KEY_Y)
				var constrain_z: bool = Input.is_key_pressed(KEY_Z)

				var final_lock_x: bool = constraints.x
				var final_lock_y: bool = constraints.y
				var final_lock_z: bool = constraints.z

				if constrain_x or constrain_y or constrain_z:
					final_lock_x = not constrain_x
					final_lock_y = not constrain_y
					final_lock_z = not constrain_z

				if final_lock_x:
					delta.x = 0
				if final_lock_y:
					delta.y = 0
				if final_lock_z:
					delta.z = 0

				for b in selected_balls:
					if is_instance_valid(b):
						if _is_ball_locked(b):
							continue

						var addballz_base_selected: bool = false
						var p: Node = b.get_parent()
						while is_instance_valid(p) and p != get_tree().root:
							if p in selected_balls:
								addballz_base_selected = true
								break
							p = p.get_parent()

						if not addballz_base_selected:
							b.global_transform.origin += delta

						_track_pending_move(b)

				if move_mode_settings_instance.is_mirror_x_active():
					_apply_mirror_move(selected_balls, delta)

		return true

	return false

func _handle_preset_mode_gui_input(event: InputEvent) -> bool:
	if not preset_mode:
		return false

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var target_ball: Spatial = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if target_ball:
			var ball_no: int = target_ball.ball_no
			var sizing_info: Dictionary = _get_ball_sizing_info(pet_node, ball_no)
			
			var is_eyedropper_active: bool = (
				preset_settings_instance.find_node("EyedropperToggle").pressed
				or Input.is_key_pressed(KEY_ALT)
			)
			if is_eyedropper_active:
				var ball_data = null
				if pet_node.lnz.balls.has(ball_no):
					ball_data = pet_node.lnz.balls[ball_no]
				elif pet_node.lnz.addballs.has(ball_no):
					ball_data = pet_node.lnz.addballs[ball_no]

				if ball_data:
					var properties: Dictionary = {
						"fuzz": ball_data.fuzz,
						"outline": ball_data.outline,
						"color_index": ball_data.color_index,
						"outline_color_index": ball_data.outline_color_index,
						"texture_id": ball_data.texture_id,
						"group": ball_data.group,
						"size": int(round(target_ball.ball_size))
					}

					if pet_node.lnz.paintballs.has(ball_no):
						properties["paintballz"] = pet_node.lnz.paintballs[ball_no]
					preset_settings_instance.set_properties(properties)
			else:  # Brush mode
				var properties: Dictionary = preset_settings_instance.get_properties()
				var ref_size: int = int(round(preset_settings_instance.size_spinbox.value))
				var size_mode: int = preset_settings_instance.size_mode_option.selected

				match size_mode:
					preset_settings_instance.SizeMode.SET:
						pass

					preset_settings_instance.SizeMode.SUM:
						if properties.has("size"):
							var original_size: int = 0
							if pet_node.lnz.balls.has(ball_no):
								original_size = pet_node.lnz.balls[ball_no]["size"] 
							elif pet_node.lnz.addballs.has(ball_no):
								original_size = pet_node.lnz.addballs[ball_no]["size"]
							properties["size"] = original_size + properties["size"]

					preset_settings_instance.SizeMode.TRUE:
						if properties.has("size"):
							var scale: float = pet_node.lnz.scales[1]
							properties["size"] = LnzLiveUtils.visual_size_to_lnz_size(
								properties["size"], sizing_info.is_addball, scale, sizing_info.bhd_size, sizing_info.enl_x, sizing_info.enl_y
							)

				var scale_ratio: float = 1.0
				if properties.get("scale_paintballz", false) and properties.has("paintballz"):
					var source_ref: float = preset_settings_instance.source_ball_reference_size
					
					var final_lnz: float = properties.get("size", sizing_info.bhd_size)
					var current_base_size: float = sizing_info.bhd_size + final_lnz
					if not sizing_info.is_addball:
						current_base_size = floor(current_base_size * (sizing_info.enl_x / 100.0)) + sizing_info.enl_y
					
					var scale: float = pet_node.lnz.scales[1]
					var target_visual_size: int = round((current_base_size - 2.0) * (scale / 255.0))
					target_visual_size -= 1.0 - fmod(target_visual_size, 2.0)
					
					scale_ratio = float(target_visual_size) / float(source_ref) if source_ref > 0 else 1.0

					var p_size_mod: float = properties.get("paintball_size_scale", 1.0)
					var p_pos_mod: float = properties.get("paintball_pos_scale", 1.0)

					if scale_ratio != 1.0 or p_size_mod != 1.0 or p_pos_mod != 1.0:
						var scaled_paintballz: Array = []
						for pb in properties.paintballz:
							var new_pb: Dictionary = pb.duplicate()
							#new_pb.position *= (scale_ratio * p_pos_mod)
							#new_pb["size"] = int(round(new_pb["size"] * scale_ratio * p_size_mod))
							new_pb.position *= p_pos_mod
							new_pb.size = int(round(new_pb.size * p_size_mod))
							scaled_paintballz.append(new_pb)
						properties["paintballz"] = scaled_paintballz
						
				lnz_text_edit.write_preset_to_ball(target_ball.ball_no, properties, null, false)
		return true

	return false

func _handle_paint_mode_gui_input(event: InputEvent) -> bool:
	if not paintball_mode:
		return false
		
	if not is_instance_valid(paintball_settings_instance):
		print("[ERROR] PetViewContainer: paintball_settings_instance is invalid in _handle_paint_mode_gui_input")
		return false

	var props: Dictionary = paintball_settings_instance.get_properties()
	if props == null:
		print("[ERROR] PetViewContainer: get_properties() returned null. Aborting input handling.")
		return false
		
	if (
		event is InputEventMouseButton
		and event.shift
		and (event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN)
	):
		#var diameter_min_spinbox = paintball_settings_instance.find_node("DiameterMin")
		#var diameter_max_spinbox = paintball_settings_instance.find_node("DiameterMax")
		print("[STATUS] PetViewContainer: adjusting brush size constraints via scroll")
		if event.button_index == BUTTON_WHEEL_UP:
			diameter_min_spinbox.value += 1
			diameter_max_spinbox.value += 1
		else:
			diameter_min_spinbox.value -= 1
			diameter_max_spinbox.value -= 1
		return true

	if paintball_settings_instance.is_design_mode_active():
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == BUTTON_WHEEL_UP:
				print("[STATUS] PetViewContainer: adjusted design stamp scale/rotation (UP)")
				if event.control:
					design_scale_multiplier += 0.1
				else:
					design_rotation_angle += 0.1
				get_tree().set_input_as_handled()
				return true
			elif event.button_index == BUTTON_WHEEL_DOWN:
				print("[STATUS] PetViewContainer: adjusted design stamp scale/rotation (DOWN)")
				if event.control:
					design_scale_multiplier = max(0.1, design_scale_multiplier - 0.1)
				else:
					design_rotation_angle -= 0.1
				get_tree().set_input_as_handled()
				return true

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		var freeline_mode: bool = (
			props.freeline
			or (
				event.shift
				and not (
					event.button_index == BUTTON_WHEEL_UP
					or event.button_index == BUTTON_WHEEL_DOWN
				)
			)
		)
		var is_straight_line: bool = (
			freeline_mode
			and (
				props.get("straight_line", false)
				or Input.is_key_pressed(KEY_ALT)
				or Input.is_key_pressed(KEY_L)
			)
		)
		if freeline_mode:
			if event.pressed:
				print("[STATUS] PetViewContainer: started freeline path")
				if props.ordered and props.repeat:
					_ordered_color_index = 0
					_ordered_outline_color_index = 0
					_ordered_texture_index = 0
				freeline_active = true
				freeline_path.clear()
				last_freeline_point = event.position
			else:
				print("[STATUS] PetViewContainer: finished freeline path")
				freeline_active = false

				if is_straight_line:
					var start_pos: Vector2 = freeline_path.front()
					var end_pos: Vector2 = event.position

					if Input.is_key_pressed(KEY_X):
						end_pos.y = start_pos.y
					elif Input.is_key_pressed(KEY_Y):
						end_pos.x = start_pos.x

					freeline_path.clear()
					var dist: float = start_pos.distance_to(end_pos)
					var steps: int = max(1, round(dist / max(1.0, props.spacing)))
					for i in range(steps + 1):
						var t: float = float(i) / float(steps)
						freeline_path.append(start_pos.linear_interpolate(end_pos, t))

				_finalize_freeline(event.position)
			return true

	if event is InputEventMouseMotion and freeline_active:
		var current_pos: Vector2 = event.position
		if current_pos.distance_to(last_freeline_point) > props.spacing:
			freeline_path.append(current_pos)
			last_freeline_point = current_pos
		return true

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		#var delete_mode = paintball_settings_instance.find_node("EraserCheckBox").pressed or Input.is_key_pressed(KEY_CONTROL)
		var delete_mode: bool = eraser_check_box.pressed or Input.is_key_pressed(KEY_CONTROL)

		if delete_mode:
			print("[STATUS] PetViewContainer: attempted eraser click")
			var pending_paintballs: Array = pet_node.get_pending_paintball_nodes()
			if pending_paintballs.empty():
				print("[WARNING] PetViewContainer: no pending paintballs to erase")
				return true

			var closest_paintball = null
			var min_dist_sq: float = INF
			var click_pos_local: Vector2 = event.position  # Use local mouse position

			for pb_node in pending_paintballs:
				if not is_instance_valid(pb_node) or not pb_node.is_inside_tree():
					continue

				var projected_pos_local: Vector2 = camera.unproject_position(pb_node.global_transform.origin)
				var paintball_screen_pos: Vector2 = _get_screen_pos_from_viewport_pos(projected_pos_local)
				
				var dist_sq: float = click_pos_local.distance_squared_to(paintball_screen_pos)

				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_paintball = pb_node

			if closest_paintball and min_dist_sq < 25 * 25:  # 25px threshold
				pet_node.remove_specific_pending_paintball(closest_paintball)
				print("[STATUS] PetViewContainer: erased closest paintball node: %s" % closest_paintball.name)
			else:
				print("[WARNING] PetViewContainer: no paintball close enough to erase (threshold distance: 25px)")
			return true

		var target_ball = null

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			target_ball = paintball_target_ball
		else:
			var target_mode: int = paintball_settings_instance.find_node("Target").selected
			if target_mode == 0:  # Hovered Ball
				target_ball = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
			else:  # Selected Ball
				if active_selected_ball and is_instance_valid(active_selected_ball):
					target_ball = active_selected_ball

		if target_ball:
			var exclude_eye_ballz: bool = paintball_settings_instance.get_properties().get("exclude_eye_ballz", true)
			if exclude_eye_ballz:
				var eye_ball_ids: Array = KeyBallsData.get_group_balls("Eyes")
				if target_ball.ball_no in eye_ball_ids:
					return true
			var screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position)
			var result = _create_paintball_at_position(screen_pos, target_ball)
			if result:
				_record_paint_action([result])
		return true

	return false

func _gui_input(event: InputEvent) -> void:
	if input_is_paused:
		return

	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var focus_owner = get_focus_owner()
		if focus_owner and (focus_owner is TextEdit or focus_owner is LineEdit):
			focus_owner.release_focus()

	if _handle_box_selection(event):
		return

	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index != BUTTON_RIGHT
		and not Input.is_key_pressed(KEY_SHIFT)
		and not move_mode
		and not auto_paintballer_mode
		and not preset_mode
		and not linez_mode
		and not recolor_mode
	):
		_reset_tab_state()

	if _handle_move_mode_gui_input(event):
		return

	if _handle_preset_mode_gui_input(event):
		return

	if _handle_paint_mode_gui_input(event):
		return

	# Open Tools Menu via right-click on hovered ball:
	if event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and event.pressed:
		get_tree().set_input_as_handled()
		var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if hover:
			tools_menu.selected_visual_ball = hover
		else:
			tools_menu.selected_visual_ball = null
		tools_menu.rect_global_position = get_viewport().get_mouse_position()
		tools_menu.rect_size = Vector2(150, 350)
		tools_menu.popup()
		return

	# Zoom view using mouse wheel:
	if event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_DOWN:
		tex.rect_pivot_offset = tex.rect_size / 2.0
		tex.rect_scale /= ZOOM_STEP
		return
	elif event is InputEventMouseButton and event.button_index == BUTTON_WHEEL_UP:
		tex.rect_pivot_offset = tex.rect_size / 2.0
		tex.rect_scale *= ZOOM_STEP
		return

	# Begin moving ballz using SHIFT+left-click-drag or resizing ballz using SHIFT+ALT+left-click-drag:
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
		and Input.is_key_pressed(KEY_SHIFT)
	):
		var alt_key: bool = Input.is_key_pressed(KEY_ALT)

		#var hover = get_intended_ball((event.position - (rect_position + rect_size / 2.0)) / tex.rect_scale + Vector2(500, 500))

		var hover = null
		if is_instance_valid(_last_selected_by_tab):
			hover = _last_selected_by_tab
		else:
			hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
			
		if hover:
			drag_ball = hover
			is_dragging = true

			if alt_key:
				is_resizing = true
				Input.set_custom_mouse_cursor(hand_pinch, 0, Vector2(30, 31))
				original_scale = drag_ball.ball_size
				drag_start_pos = event.position
				print("[STATUS] PetViewContainer: started scale drag on ball:", drag_ball.name)
			else:
				print("[STATUS] PetViewContainer: started drag on ball:", drag_ball.name)
				# is_dragging = true
				Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
				pet_node._orig_world_pos[drag_ball.ball_no] = drag_ball.global_transform.origin
		return

	# Update ball position or scale during moving or resizing:
	if event is InputEventMouseMotion and is_dragging and drag_ball:
		if is_resizing:
			var delta: Vector2 = event.position - drag_start_pos
			var change: float = delta.dot(Vector2(1, -1).normalized()) * 0.5

			if change < 0:
				Input.set_custom_mouse_cursor(hand_pinch, 0, Vector2(30, 31))
			else:
				Input.set_custom_mouse_cursor(hand_stretch, 0, Vector2(30, 31))

			var target_visual: float = clamp(original_scale + change, 1.0, 500.0)

			var sizing_info: Dictionary = _get_ball_sizing_info(pet_node, drag_ball.ball_no)
			var is_ab: bool = sizing_info.is_addball
			var bhd_s: int = sizing_info.bhd_size
			var engine_scale: float = pet_node.lnz.scales[1]

			var snapped_visual: float = LnzLiveUtils.snap_visual_size(
				target_visual, is_ab, engine_scale, bhd_s, sizing_info.enl_x, sizing_info.enl_y
			)
			drag_ball.set_ball_size(snapped_visual)
		else:
			Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
			var screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position)
			var ray_o: Vector3 = camera.project_ray_origin(screen_pos)
			var ray_d: Vector3 = camera.project_ray_normal(screen_pos)
			var plane_n: Vector3 = camera.global_transform.basis.z.normalized()
			var plane_p: Vector3 = drag_ball.global_transform.origin
			var intersect = LnzLiveUtils.intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)
			if intersect:
				var new_pos: Vector3 = intersect
				var original_pos: Vector3 = drag_ball.global_transform.origin

				var press_x: bool = Input.is_key_pressed(KEY_X)
				var press_y: bool = Input.is_key_pressed(KEY_Y)
				var press_z: bool = Input.is_key_pressed(KEY_Z)

				if press_x or press_y or press_z:
					if not press_x:
						new_pos.x = original_pos.x
					if not press_y:
						new_pos.y = original_pos.y
					if not press_z:
						new_pos.z = original_pos.z

				drag_ball.global_transform.origin = new_pos
				#print("Set drag_ball position to: ", new_pos)
		return

	# Finalize drag or resize operation on mouse release:
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and not event.pressed
		and is_dragging
		and drag_ball
		and not move_mode
	):
		if is_resizing:
			var delta: Vector2 = event.position - drag_start_pos
			var change: float = delta.dot(Vector2(1, -1).normalized()) * 0.5
			var raw_target_visual: float = clamp(original_scale + change, 1.0, 500.0)

			var final_size: float = get_absolute_lnz_size(raw_target_visual, drag_ball, pet_node)
			pet_node.emit_ball_resize(drag_ball.ball_no, final_size)
		else:
			print("[STATUS] PetViewContainer: final world position:", drag_ball.global_transform.origin)
			var lnz_pos: Vector3 = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[STATUS] PetViewContainer: dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_move(drag_ball.ball_no, lnz_pos)

		is_dragging = false
		is_resizing = false
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		#update() # AXIS GIZMO
		drag_ball = null
		return

	# Select ballz via double-click in Select Mode:
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.doubleclick
		and not move_mode
	):
		if selecting_on and last_selected_is_valid():
			last_selected.selected()
		return

	if linez_mode:
		if _handle_line_mode_input(event):
			return

	# Select ballz via single-click or clear selected ballz:
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
		and selecting_on
		and not move_mode
	):
		var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if hover:
			set_active_selected_ball(hover)
		else:
			clear_active_selected_ball()

	# Rotate or pan camera during general mouse motion:
	if event is InputEventMouseMotion and not is_dragging:
		#label.rect_global_position = event.global_position

		# if is_instance_valid(_last_selected_by_tab):
		# 	var current_mouse_pos: Vector2 = get_viewport().get_mouse_position()
		# 	if current_mouse_pos.distance_to(_tab_activation_mouse_pos) > TAB_RESET_THRESHOLD_PIXELS:
		# 		_reset_tab_state()
		# 	else:
		# 		pass

		var space_and_left: bool = (
			Input.is_key_pressed(KEY_SPACE)
			and Input.is_mouse_button_pressed(BUTTON_LEFT)
		)
		var middle_drag: bool = Input.is_mouse_button_pressed(BUTTON_MIDDLE)

		if space_and_left or middle_drag:
			var motion: Vector2 = event.relative
			#camera.transform.origin.y += motion.y * 0.001 / tex.rect_scale.x
			camera.transform.origin.y -= motion.y * 0.001 / tex.rect_scale.x
			camera.transform.origin.x += motion.x * 0.001 / tex.rect_scale.x
		elif Input.is_mouse_button_pressed(BUTTON_LEFT):
			var motion: Vector2 = event.relative
			camera_holder.rotation.x += motion.y * 0.01
			#camera_holder.rotation.y += motion.x * -0.01
			camera_holder.rotation.y -= motion.x * -0.01

		# Highlight hovered ball in line creation mode:
		if linez_mode and not selecting_on:
			Input.set_custom_mouse_cursor(rope, 0, Vector2(30, 31))
			var hover = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
			for b in _get_all_visual_balls():
				if b != linez_start_ball and b.has_method("apply_outline_state"):
					b.apply_outline_state(b.OutlineState.NONE)
			if hover and hover != linez_start_ball and hover.has_method("apply_outline_state"):
				hover.apply_outline_state(hover.OutlineState.HOVER)
		elif not preset_mode and not paintball_mode and not project_mode and not move_mode and not recolor_mode:
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))

	# Update hovered ball_label and trigger highlight for selectable ball:
	if (
		event is InputEventMouseMotion
		and selecting_on
		and not paintball_mode
		and not is_instance_valid(_last_selected_by_tab)
	):
		var screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position)

		var from: Vector3 = camera.project_ray_origin(screen_pos)
		var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 950
		# Skip paintball colliders so hover reaches the underlying ball
		var paintball_nodes: Array = get_tree().get_nodes_in_group("paintballs")
		var result: Dictionary = camera.get_world().direct_space_state.intersect_ray(
			from, to, paintball_nodes, 0x7FFFFFFF, false, true
		)

		if result:
			ball_label.show()
			deal_with_last_selected()
			
			var hit_ball = result.collider.get_parent()
			
			if hit_ball.has_method("set_select_mode_active"):
				hit_ball.select_mode_active = true
				
			hit_ball._on_Area_mouse_entered()
			last_selected = hit_ball
		else:
			deal_with_last_selected()
			last_selected = null
			ball_label.hide()

	# Commit move for auto‑started drags on press, or for manual SHIFT‑drags on release
	if (
		event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and is_dragging
		and drag_ball
		and not move_mode
	):
		var commit_now: bool = (
			(drag_started_via_code and event.pressed)
			or (not drag_started_via_code and not event.pressed)
		)
		if commit_now:
			print("[STATUS] PetViewContainer: final world position:", drag_ball.global_transform.origin)
			var lnz_pos: Vector3 = get_lnz_position_from_visual(drag_ball, pet_node)
			print("[STATUS] PetViewContainer: dragged ball %d to %s (LNZ-space)" % [drag_ball.ball_no, lnz_pos])
			pet_node.emit_ball_move(drag_ball.ball_no, lnz_pos)

			is_dragging = false
			is_resizing = false
			drag_started_via_code = false
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
			#update() # AXIS GIZMO
			drag_ball = null
			return

	if (
		auto_paintballer_mode
		and event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
	):
		var target_ball: Spatial = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))

		if target_ball:
			auto_paintballer_settings_instance.add_affected_ball(target_ball.ball_no)

			if not (target_ball in selected_balls):
				selected_balls.append(target_ball)

			target_ball.apply_outline_state(target_ball.OutlineState.ACTIVE_SELECTED)

			get_tree().set_input_as_handled()
			return

	if (
		recolor_mode
		and event is InputEventMouseButton
		and event.button_index == BUTTON_LEFT
		and event.pressed
	):
		var target_ball: Spatial = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		if target_ball:
			recolor_settings_instance.queue_bucket_change(target_ball)
			_reset_tab_state()
			get_tree().set_input_as_handled()
			return

func _handle_camera_view_key_input(event: InputEventKey) -> bool:
	if not event.pressed:
		return false

	match event.scancode:
		KEY_1:
			_set_camera_view("front")
			return true
		KEY_2:
			_set_camera_view("bottom")
			return true
		KEY_3:
			_set_camera_view("top")
			return true
		KEY_4:
			_set_camera_view("right")
			return true
		KEY_5:
			_set_camera_view("left")
			return true
		KEY_6:
			_set_camera_view("back")
			return true
		KEY_7:
			_set_camera_view("isorightbottom")
			return true
		KEY_8:
			_set_camera_view("isorighttop")
			return true
		KEY_9:
			_set_camera_view("isoleftbottom")
			return true
		KEY_0:
			_set_camera_view("isolefttop")
			return true
	return false

func _handle_mode_shortcut_key_input(event: InputEventKey) -> bool:
	if not event.pressed:
		return false

	if event.alt:
		match event.scancode:
			KEY_F:
				recolor_mode_check_box.pressed = not recolor_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_B:
				paintball_check_box.pressed = not paintball_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_L:
				line_mode_check_box.pressed = not line_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_G:
				preset_mode_check_box.pressed = not preset_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_M:
				move_mode_check_box.pressed = not move_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_P:
				project_mode_check_box.pressed = not project_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true

	if not event.control and not event.alt and not event.shift:
		if _is_text_input_focused(event):
			return false
		match event.scancode:
			KEY_S:
				select_check_box.pressed = not select_check_box.pressed
				_on_SelectCheckBox_pressed()
				get_tree().set_input_as_handled()
				return true
			KEY_W:
				paintball_check_box.pressed = not paintball_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_E:
				line_mode_check_box.pressed = not line_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_R:
				preset_mode_check_box.pressed = not preset_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_U:
				move_mode_check_box.pressed = not move_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_D:
				project_mode_check_box.pressed = not project_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_A:
				auto_paintballer_check_box.pressed = not auto_paintballer_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_T:
				view_palette_check_box.pressed = not view_palette_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_G:
				recolor_mode_check_box.pressed = not recolor_mode_check_box.pressed
				get_tree().set_input_as_handled()
				return true
			KEY_K:
				lnz_text_edit.capture_headshot()
				get_tree().set_input_as_handled()
				return true
			KEY_V:
				view_variations_check_box.pressed = not view_variations_check_box.pressed
				get_tree().set_input_as_handled()
				return true
	return false

func _handle_move_nudge_key_input(event: InputEventKey) -> bool:
	if move_mode and event.pressed:
		var nudge_axis: String = ""
		if Input.is_key_pressed(KEY_X):
			nudge_axis = "x"
		elif Input.is_key_pressed(KEY_Y):
			nudge_axis = "y"
		elif Input.is_key_pressed(KEY_Z):
			nudge_axis = "z"

		if nudge_axis != "":
			if event.scancode == KEY_EQUAL or event.scancode == KEY_KP_ADD:  # + key
				_record_move_start_state()
				var dirsign: float = 1.0
				move_mode_settings_instance.apply_nudge_axis(nudge_axis, dirsign)
				_record_move_end_state("Nudge +")
				get_tree().set_input_as_handled()
				return true
			elif event.scancode == KEY_MINUS or event.scancode == KEY_KP_SUBTRACT:  # - key
				_record_move_start_state()
				var dirsign: float = -1.0
				move_mode_settings_instance.apply_nudge_axis(nudge_axis, dirsign)
				_record_move_end_state("Nudge -")
				get_tree().set_input_as_handled()
				mark_ui_dirty()
				return true
	return false

func _is_text_input_focused(event: InputEventKey) -> bool:
	var focus_owner: Node = get_focus_owner()
	if focus_owner and (focus_owner is TextEdit or focus_owner is LineEdit):
		if event.control or event.alt or event.shift:
			return false
		return true
	return false

func _exit_all_modes() -> void:
	paintball_check_box.pressed = false
	line_mode_check_box.pressed = false
	move_mode_check_box.pressed = false
	preset_mode_check_box.pressed = false
	recolor_mode_check_box.pressed = false
	texture_editor_mode_check_box.pressed = false
	project_mode_check_box.pressed = false
	auto_paintballer_check_box.pressed = false
	view_palette_check_box.pressed = false
	view_variations_check_box.pressed = false

	# Return to FileTree tab when explicitly exiting all modes (ESC)
	if sidebar_controller:
		var tree_tab: Node = sidebar_controller.tab_container.get_node_or_null("FileTree")
		if tree_tab:
			sidebar_controller.switch_to_tab(tree_tab)

	mark_ui_dirty()

func set_mode(new_mode: int) -> void:
	if current_mode == new_mode:
		return

	var old_mode = current_mode
	current_mode = new_mode

	paintball_mode = (new_mode == Mode.PAINTBALL)
	move_mode = (new_mode == Mode.MOVE)
	linez_mode = (new_mode == Mode.LINE)
	preset_mode = (new_mode == Mode.PRESET)
	recolor_mode = (new_mode == Mode.RECOLOR)
	project_mode = (new_mode == Mode.PROJECT)
	auto_paintballer_mode = (new_mode == Mode.AUTO_PAINTBALLER)
	texture_editor_mode = (new_mode == Mode.TEXTURE_EDITOR)

	if old_mode != Mode.NONE:
		_exit_mode(old_mode)
		_update_mode_panel_visibility(_get_mode_settings_instance(old_mode), false, false)

	if new_mode != Mode.NONE:
		_enter_mode(new_mode)
		_update_mode_panel_visibility(_get_mode_settings_instance(new_mode), true)
		_update_paintball_mode_ui()

	_sync_mode_checkboxes()

	_sync_mode_cursor()
	mark_ui_dirty()

func _get_mode_settings_instance(mode: int) -> Control:
	match mode:
		Mode.MOVE:
			return move_mode_settings_instance
		Mode.PAINTBALL:
			return paintball_settings_instance
		Mode.LINE:
			return line_mode_settings_instance
		Mode.PRESET:
			return preset_settings_instance
		Mode.RECOLOR:
			return recolor_settings_instance
		Mode.PROJECT:
			return project_settings_instance
		Mode.AUTO_PAINTBALLER:
			return auto_paintballer_settings_instance
		Mode.TEXTURE_EDITOR:
			return texture_editor_settings_instance
	return null

func _exit_mode(mode: int) -> void:
	match mode:
		Mode.MOVE:
			_locked_balls_cache = locked_balls.duplicate()
			_on_unselect_all()
			_on_move_mode_clear()
			selected_balls.clear()
			locked_balls.clear()
		Mode.PAINTBALL:
			var should_switch_tab = close_paintball_on_apply
			paintball_target_ball = null
			close_paintball_on_apply = false
			_restore_all_balls()
			_set_pending_paintballs_visible(false)
			if should_switch_tab and sidebar_controller:
				var tree_tab: Node = sidebar_controller.tab_container.get_node_or_null("FileTree")
				if tree_tab:
					sidebar_controller.switch_to_tab(tree_tab)
		Mode.LINE:
			var should_switch_tab = line_mode_close
			line_mode_close = false
			if is_instance_valid(linez_start_ball):
				linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
			linez_start_ball = null
			if polygon_mode:
				_clear_polygon_selection()
				polygon_balls.clear()
			if should_switch_tab and sidebar_controller:
				var tree_tab: Node = sidebar_controller.tab_container.get_node_or_null("FileTree")
				if tree_tab:
					sidebar_controller.switch_to_tab(tree_tab)
		Mode.PRESET:
			pass
		Mode.RECOLOR:
			recolor_settings_instance.clear_buckets()
		Mode.PROJECT:
			pass
		Mode.AUTO_PAINTBALLER:
			if is_instance_valid(pet_node):
				pet_node.clear_auto_paintballz()
			_on_unselect_all()
			_auto_paint_affected_cache.clear()
			var all_balls: Array = _get_all_visual_balls()
			for b in all_balls:
				if is_instance_valid(b) and b.has_method("apply_outline_state"):
					b.apply_outline_state(b.OutlineState.NONE)
		Mode.TEXTURE_EDITOR:
			pass

func _enter_mode(mode: int) -> void:
	match mode:
		Mode.MOVE:
			locked_balls = _locked_balls_cache.duplicate()
			_sync_locked_balls_to_visuals()
			move_mode_settings_instance.set_queued_count(pending_moves.size())
			ball_label.hide()
			_reset_tab_state()
		Mode.PAINTBALL:
			_restore_all_balls()
			_ordered_color_index = 0
			_ordered_outline_color_index = 0
			_ordered_texture_index = 0
			paintball_settings_instance.find_node("Target").selected = 0
		Mode.LINE:
			pass
		Mode.PRESET:
			if is_instance_valid(pet_node) and is_instance_valid(pet_node.lnz):
				if pet_node.lnz.texture_list:
					preset_settings_instance.set_texture_list(pet_node.lnz.texture_list)
				if pet_node.lnz.palette:
					preset_settings_instance.set_palette(pet_node.lnz.palette)
		Mode.RECOLOR, Mode.PROJECT, Mode.AUTO_PAINTBALLER, Mode.TEXTURE_EDITOR:
			pass

func _sync_mode_checkboxes() -> void:
	if select_check_box.pressed != selecting_on:
		select_check_box.pressed = selecting_on
	if paintball_check_box.pressed != (current_mode == Mode.PAINTBALL):
		paintball_check_box.pressed = (current_mode == Mode.PAINTBALL)
	if line_mode_check_box.pressed != (current_mode == Mode.LINE):
		line_mode_check_box.pressed = (current_mode == Mode.LINE)
	if move_mode_check_box.pressed != (current_mode == Mode.MOVE):
		move_mode_check_box.pressed = (current_mode == Mode.MOVE)
	if preset_mode_check_box.pressed != (current_mode == Mode.PRESET):
		preset_mode_check_box.pressed = (current_mode == Mode.PRESET)
	if recolor_mode_check_box.pressed != (current_mode == Mode.RECOLOR):
		recolor_mode_check_box.pressed = (current_mode == Mode.RECOLOR)
	if project_mode_check_box.pressed != (current_mode == Mode.PROJECT):
		project_mode_check_box.pressed = (current_mode == Mode.PROJECT)
	if auto_paintballer_check_box.pressed != (current_mode == Mode.AUTO_PAINTBALLER):
		auto_paintballer_check_box.pressed = (current_mode == Mode.AUTO_PAINTBALLER)
	if texture_editor_mode_check_box.pressed != (current_mode == Mode.TEXTURE_EDITOR):
		texture_editor_mode_check_box.pressed = (current_mode == Mode.TEXTURE_EDITOR)

func _sync_mode_cursor() -> void:
	match current_mode:
		Mode.NONE:
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_POINTING_HAND if selecting_on else CURSOR_ARROW
		Mode.PAINTBALL:
			Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_ARROW
		Mode.LINE:
			Input.set_custom_mouse_cursor(rope, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_ARROW
		Mode.RECOLOR:
			Input.set_custom_mouse_cursor(paintbucket, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_ARROW
		Mode.PRESET:
			Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_ARROW
		Mode.MOVE:
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_ARROW
		Mode.PROJECT, Mode.AUTO_PAINTBALLER, Mode.TEXTURE_EDITOR:
			Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
			mouse_default_cursor_shape = CURSOR_ARROW

func _unhandled_key_input(event: InputEventKey) -> void:
	if event.is_pressed() and event.scancode == KEY_ESCAPE:
		_exit_all_modes()
		var focus_owner = get_focus_owner()
		if focus_owner and (focus_owner is TextEdit or focus_owner is LineEdit):
			focus_owner.release_focus()

		if is_instance_valid(sidebar_controller) and is_instance_valid(sidebar_controller.floating_layer):
			var floating_panels = sidebar_controller.floating_layer.get_children()
			for panel in floating_panels:
				sidebar_controller.dock_panel(panel)

		get_tree().set_input_as_handled()
		return

	if input_is_paused:
		return

	if _is_text_input_focused(event):
		return

	if event is InputEventKey:
		if event.scancode in [KEY_X, KEY_Y, KEY_Z, KEY_SHIFT, KEY_CONTROL, KEY_ALT]:
			mark_ui_dirty()

	if event is InputEventKey and event.pressed and event.scancode == KEY_N:
		if selecting_on or recolor_mode:
			get_tree().set_input_as_handled()
			_cycle_nearby_ballz()
			return

	# Mini-history for Paintball and Move modes
	if event is InputEventKey and event.pressed and event.control and event.shift:
		if event.scancode == KEY_Z:  # Undo
			if paintball_mode:
				_undo_queued_paintball()
				get_tree().set_input_as_handled()
				return
			elif move_mode:
				_undo_queued_move()
				get_tree().set_input_as_handled()
				return
		elif event.scancode == KEY_X:  # Redo
			if paintball_mode:
				_redo_queued_paintball()
				get_tree().set_input_as_handled()
				return
			elif move_mode:
				_redo_queued_move()
				get_tree().set_input_as_handled()
				return

	if _handle_move_nudge_key_input(event):
		return

	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_H:
		get_tree().set_input_as_handled()
		if is_instance_valid(pet_node) and pet_node.has_method("unhide_all_balls"):
			pet_node.unhide_all_balls()
		return

	# Open Tools Menu via CTRL+SPACE for last selected ball:
	if event is InputEventKey and event.pressed and event.control and event.scancode == KEY_SPACE:
		get_tree().set_input_as_handled()
		if last_selected_is_valid():
			tools_menu.selected_visual_ball = last_selected
		else:
			tools_menu.selected_visual_ball = null
		tools_menu.rect_global_position = get_viewport().get_mouse_position()
		tools_menu.popup()
		return

	if _handle_mode_shortcut_key_input(event):
		return

	# Move Mode ball lock: Q to toggle lock on hovered ball, CTRL+Q to unlock all
	if move_mode and event.pressed and not event.alt:
		if event.control:
			if event.scancode == KEY_Q:
				_unlock_all_balls()
				get_tree().set_input_as_handled()
				return
		else:
			if event.scancode == KEY_Q:
				var hover: Spatial = get_intended_ball(_get_viewport_pos_from_screen_pos(get_local_mouse_position()))
				if hover and is_instance_valid(hover) and "ball_no" in hover:
					_toggle_lock_ball(hover)
					get_tree().set_input_as_handled()
					return

	if _handle_camera_view_key_input(event):
		return

	if event.pressed and selecting_on and last_selected_is_valid():
		last_selected._input(event)

func _set_camera_view(view_name: String) -> void:
	camera_holder.rotation = Vector3.ZERO

	match view_name:
		"front":
			camera_holder.rotation_degrees = Vector3(0, 0, 0)
		"back":
			camera_holder.rotation_degrees = Vector3(0, 180, 0)
		"right":
			camera_holder.rotation_degrees = Vector3(0, 90, 0)
		"left":
			camera_holder.rotation_degrees = Vector3(0, -90, 0)
		"bottom":
			camera_holder.rotation_degrees = Vector3(-90, 0, 0)
		"top":
			camera_holder.rotation_degrees = Vector3(90, 0, 0)
		"isorightbottom":
			camera_holder.rotation_degrees = Vector3(-35, 45, 0)
		"isorighttop":
			camera_holder.rotation_degrees = Vector3(35, 45, 0)
		"isoleftbottom":
			camera_holder.rotation_degrees = Vector3(-35, -45, 0)
		"isolefttop":
			camera_holder.rotation_degrees = Vector3(35, -45, 0)

func _on_ShaderSettingsButton_pressed() -> void:
	if is_instance_valid(shader_settings_instance):
		shader_settings_instance.popup_centered()

func _on_hidden_balls_changed(count: int) -> void:
	if count > 0:
		hidden_balls_label.text = "%d ballz hidden (CTRL+H to unhide)" % count
		hidden_balls_label.visible = true
	else:
		hidden_balls_label.visible = false

func _on_texture_rotation_mode_changed(mode: int) -> void:
	pet_node._shader_rotation_mode = mode
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_mode", mode)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_mode", mode)

func _on_texture_rotation_input_changed(input_vec: Vector2) -> void:
	pet_node._shader_rotation_input = input_vec
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_input", input_vec)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_rotation_input", input_vec)

func _on_texture_affected_by_size_changed(is_affected: bool) -> void:
	pet_node._shader_affected_by_size = is_affected
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_size", is_affected)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_size", is_affected)

func _on_texture_affected_by_rotation_changed(is_affected: bool) -> void:
	pet_node._shader_affected_by_rotation = is_affected
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if b.has_node("MeshInstance") and b.get_node("MeshInstance").material_override:
			b.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_rotation", is_affected)
		for child in b.get_children():
			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
				if child.get_node("MeshInstance").material_override:
					child.get_node("MeshInstance").material_override.set_shader_param("texture_affected_by_rotation", is_affected)

# func _on_texture_use_quadrants_changed(is_using: bool):
# 	var all_balls = _get_all_visual_balls()
# 	for b in all_balls:
# 		# Update the main ball
# 		if b.has_method("set_use_quadrants"):
# 			b.set_use_quadrants(is_using)
			
# 		# Update any attached paintballs
# 		for child in b.get_children():
# 			if child.is_in_group("paintballs") and child.has_node("MeshInstance"):
# 				var mat = child.get_node("MeshInstance").material_override
# 				if mat:
# 					mat.set_shader_param("use_quadrants", is_using)

func _on_texture_flat_colors_changed(is_flat: bool) -> void:
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("set_render_flat_colors"):
			b.set_render_flat_colors(is_flat)
			
			for child in b.get_children():
				if child.is_in_group("paintballs") and child.has_method("set_render_flat_colors"):
					child.set_render_flat_colors(is_flat)

	for l in get_tree().get_nodes_in_group("lines"):
		if is_instance_valid(l) and l.has_method("set_render_flat_colors"):
			l.set_render_flat_colors(is_flat)

	for p in get_tree().get_nodes_in_group("polygons"):
		if is_instance_valid(p) and p.has_method("set_render_flat_colors"):
			p.set_render_flat_colors(is_flat)

	if is_instance_valid(pet_node):
		pet_node.render_flat_colors_global = is_flat


# MODES
# _on_ModePopup_about_to_show
# _on_SelectCheckBox_pressed
# _on_HelpButton_pressed
# _on_LnzTextEdit_mouse_entered
# _on_PetViewContainer_resized
# _on_PetViewContainer_sort_children

func _on_ModePopup_about_to_show() -> void:
	select_check_box.pressed = selecting_on

func _on_SelectCheckBox_pressed() -> void:
	selecting_on = select_check_box.pressed
	if !selecting_on:
		if last_selected_is_valid():
			last_selected._on_Area_mouse_exited()
		last_selected = null
		clear_active_selected_ball()
		ball_label.hide()
		for b in _get_all_visual_balls():
			if b and b.has_method("apply_outline_state"):
				b.apply_outline_state(b.OutlineState.NONE)
				b.select_mode_active = false
		tex.update()
	else:
		for b in _get_all_visual_balls():
			if b and b.has_method("set_select_mode_active"):
				b.select_mode_active = true
	# for pb in get_tree().get_nodes_in_group("paintballs"):
	# 	if pb and pb.has_method("set_select_mode_active"):
	# 		pb.select_mode_active = selecting_on
	mark_ui_dirty()

func _on_HelpButton_pressed() -> void:
	help_popup.popup_centered()

func _on_LnzTextEdit_mouse_entered() -> void:
	if last_selected_is_valid():
		last_selected._on_Area_mouse_exited()
	last_selected = null
	ball_label.hide()

func _on_PetViewContainer_resized() -> void:
	var size_diff: Vector2 = tex.rect_size / 2.0 - self.rect_size / 2.0
	tex.rect_global_position = self.rect_global_position - size_diff

func _on_PetViewContainer_sort_children() -> void:
	_on_PetViewContainer_resized()


# VISUALS
# set_active_selected_ball
# clear_active_selected_ball
# get_visual_state_for_ball
# last_selected_is_valid
# deal_with_last_selected
# _on_Node_ball_mouse_enter
# find_visual_ball_by_no
# _get_all_visual_balls
# _on_affected_list_changed
# get_ball_under_mouse
# get_intended_ball
# _sort_by_distance
# _get_sorted_nearby_balls
# _cycle_nearby_ballz
# get_lnz_position_from_visual
# get_absolute_lnz_size
# _isolate_target_ball
# _restore_all_balls
# _create_overlay
# _sync_overlay
# _set_visual_layer_recursive

func set_active_selected_ball(ball: Spatial) -> void:
	if (
		active_selected_ball
		and is_instance_valid(active_selected_ball)
		and "ball_no" in active_selected_ball
	):
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = ball
	active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.ACTIVE_SELECTED)
	_update_selected_ballz_in_settings()
	mark_ui_dirty()

func clear_active_selected_ball() -> void:
	if (
		active_selected_ball
		and is_instance_valid(active_selected_ball)
		and "ball_no" in active_selected_ball
	):
		active_selected_ball.apply_outline_state(active_selected_ball.OutlineState.NONE)
	active_selected_ball = null
	_update_selected_ballz_in_settings()
	mark_ui_dirty()

func get_visual_state_for_ball(b: Spatial):
	if not "ball_no" in b:
		return
	else:
		if move_mode and b.ball_no in locked_balls:
			return b.OutlineState.LOCKED

		if move_mode:
			if use_pivot_check_box.pressed:
				#if move_mode_settings_instance.find_node("UsePivotCheckBox").pressed:
				#var pivot_id = int(move_mode_settings_instance.find_node("PivotBall").value)
				var pivot_id: int = int(pivot_ball_spinbox.value)
				if b.ball_no == pivot_id:
					return b.OutlineState.PIVOT

		if (move_mode or preset_mode or auto_paintballer_mode) and b in selected_balls:
			return b.OutlineState.ACTIVE_SELECTED
		elif move_mode and pending_moves.has(b.ball_no):
			return b.OutlineState.MODIFIED
		else:
			if b == active_selected_ball:
				return b.OutlineState.ACTIVE_SELECTED
			return b.OutlineState.NONE

func last_selected_is_valid() -> bool:
	return last_selected != null and is_instance_valid(last_selected)

func deal_with_last_selected() -> void:
	if last_selected != null and is_instance_valid(last_selected):
		last_selected._on_Area_mouse_exited()
		mark_ui_dirty()

func _on_Node_ball_mouse_enter(ball_info: Dictionary) -> void:
	if selecting_on:
		ball_label.text = str(ball_info.ball_no)
		ball_label.rect_global_position = get_viewport().get_mouse_position() + Vector2(25, 15)
		ball_label.show()
		mark_ui_dirty()

func find_visual_ball_by_no(no: int) -> Spatial:
	if is_instance_valid(pet_node) and pet_node.ball_map:
		if pet_node.ball_map.has(no):
			var b: Spatial = pet_node.ball_map[no]
			if is_instance_valid(b):
				return b
		return null

	var all_balls: Array = (
		get_tree().get_nodes_in_group("balls")
		+ get_tree().get_nodes_in_group("addballs")
	)
	for b in all_balls:
		if is_instance_valid(b) and "ball_no" in b:
			if b.ball_no == no:
				return b
	return null

func _get_all_visual_balls() -> Array:
	if is_instance_valid(pet_node) and pet_node.ball_map:
		return pet_node.ball_map.values()
	return get_tree().get_nodes_in_group("balls") + get_tree().get_nodes_in_group("addballs")

func _on_affected_list_changed(ids: Array) -> void:
	_auto_paint_affected_cache = ids

	selected_balls.clear()
	for id in ids:
		var ball: Spatial = find_visual_ball_by_no(id)
		if ball and is_instance_valid(ball):
			selected_balls.append(ball)

	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))

func get_ball_under_mouse(screen_pos: Vector2):
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 10000

	var space_state = camera.get_world().direct_space_state
	var result: Dictionary = space_state.intersect_ray(from, to, [], 1, false, true)

	if result and result.collider:
		var parent: Node = result.collider.get_parent()
		if parent.is_in_group("balls") or parent.is_in_group("addballs"):
			if parent.get("omitted") == true and not pet_node.draw_omitted_balls:
				return null
			return parent
	return null

func get_intended_ball(mouse_pos: Vector2) -> Spatial:
	if is_instance_valid(_last_selected_by_tab):
		return _last_selected_by_tab

	return get_ball_under_mouse(mouse_pos)

func _sort_by_distance(a: Dictionary, b: Dictionary) -> bool:
	return a.distance < b.distance

func _get_sorted_nearby_balls(raw_mouse_pos: Vector2) -> Array:
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	_rebuild_spatial_hash()
	var nearby_balls: Array = []
	var center_cell: Vector2 = (raw_mouse_pos / GRID_CELL_SIZE).floor()
	var viewport_offset: Vector2 = tex.get_global_transform().origin

	for x in range(-1, 2):
		for y in range(-1, 2):
			var cell_coord: Vector2 = center_cell + Vector2(x, y)
			if _spatial_grid_2d.has(cell_coord):
				for ball in _spatial_grid_2d[cell_coord]:
					var proj: Vector2 = camera.unproject_position(ball.global_transform.origin) 
					var ball_global_pos: Vector2 = viewport_offset + (proj * tex.rect_scale) 
					var dist: float = ball_global_pos.distance_to(raw_mouse_pos) 
					
					if dist < NEARBY_SCREEN_RADIUS: 
						nearby_balls.append({"ball": ball, "distance": dist})

	nearby_balls.sort_custom(self, "_sort_by_distance") 
	
	var result_balls: Array = []
	for i in range(min(nearby_balls.size(), MAX_NEARBY_BALLS)): 
		result_balls.append(nearby_balls[i].ball) 
	
	#var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	#var _perf_stat_end: int = OS.get_static_memory_usage()
	#var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	#print("[PERF] _get_sorted_nearby_balls took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	#	OS.get_ticks_msec() - _perf_start_time,
	#	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	#	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	#	_perf_orphans
	#])

	return result_balls

func _cycle_nearby_ballz() -> void:
	var raw_mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# Clear visual state of the previously TAB-selected ball
	deal_with_last_selected()

	if _current_tab_index == -1 or _current_tab_index >= _nearby_balls_cache.size() - 1:
		_current_tab_index = 0

		_nearby_balls_cache = _get_sorted_nearby_balls(raw_mouse_pos)

		if _nearby_balls_cache.size() > 0:
			# Store the raw mouse position where TAB was pressed for persistence checking
			_tab_activation_mouse_pos = raw_mouse_pos
	else:
		# Move to the next ball in the existing cache
		_current_tab_index += 1

	if _nearby_balls_cache.size() > 0:
		var target_ball: Spatial = _nearby_balls_cache[_current_tab_index]

		if selecting_on and target_ball.has_method("set_select_mode_active"):
			target_ball.select_mode_active = true

		# Set new selection state (updates last_selected)
		last_selected = target_ball
		_last_selected_by_tab = target_ball

		# Apply highlight
		if selecting_on and target_ball.has_method("_on_Area_mouse_entered"):
			target_ball._on_Area_mouse_entered()

		# Update floating ball number label
		ball_label.text = str(target_ball.ball_no)
		ball_label.rect_global_position = raw_mouse_pos + Vector2(35, 15)
		ball_label.show()

	else:
		# No nearby balls
		_reset_tab_state()
		# Set a temporary message for the helper label if no balls are found
		helper_label.text = (
			"No nearby ballz found for cycling (Radius: %s px)."
			% [NEARBY_SCREEN_RADIUS]
		)

	mark_ui_dirty()

func get_lnz_position_from_visual(drag_ball: Spatial, pet_node: Node) -> Vector3:
	var current_world: Vector3 = drag_ball.global_transform.origin
	var original_world: Vector3 = pet_node._orig_world_pos.get(drag_ball.ball_no, Vector3.ZERO)

	print(
		(
			"[STATUS] PetViewContainer: get_lnz_position_from_visual: ball %d world positions: current=%s, original=%s"
			% [drag_ball.ball_no, current_world, original_world]
		)
	)

	var delta_meters: Vector3 = current_world - original_world
	var lnz_offset: Vector3 = LnzLiveUtils.world_to_lnz_delta(
		delta_meters, pixel_world_size, pet_node.lnz.scales.x
		)
	print("[STATUS] PetViewContainer: get_lnz_position_from_visual: rounded LNZ‐space offset (int): %s" % lnz_offset)

	return lnz_offset

func get_absolute_lnz_size(raw_target_visual: float, drag_ball: Spatial, pet_node: Node) -> int:
	var sizing_info: Dictionary = _get_ball_sizing_info(pet_node, drag_ball.ball_no)
	var engine_scale: float = pet_node.lnz.scales[1]

	return LnzLiveUtils.visual_size_to_lnz_size(
		drag_ball.ball_size, sizing_info.is_addball, engine_scale, sizing_info.bhd_size, sizing_info.enl_x, sizing_info.enl_y
	)

func _isolate_target_ball(target_ball: Spatial) -> void:
	_create_overlay()
	camera.cull_mask = 1

	var all_balls: Array = _get_all_visual_balls()
	for ball in all_balls:
		if not is_instance_valid(ball):
			continue
		var area: Area = ball.get_node_or_null("Area")
		if not area:
			continue

		var is_dependent: bool = "base_ball_no" in ball and ball.base_ball_no == target_ball.ball_no

		if ball != target_ball:
			area.set_collision_layer_bit(0, false)
			area.set_collision_layer_bit(1, true)
			_set_visual_layer_recursive(ball, 1)
		else:
			area.set_collision_layer_bit(0, true)
			area.set_collision_layer_bit(1, false)
			_set_visual_layer_recursive(ball, 2)

func _restore_all_balls() -> void:
	var all_balls: Array = _get_all_visual_balls()
	for ball in all_balls:
		if not is_instance_valid(ball):
			continue

		_set_visual_layer_recursive(ball, 1)

		var area: Area = ball.get_node_or_null("Area")
		if not area:
			continue

		area.set_collision_layer_bit(0, true)
		area.set_collision_layer_bit(1, false)

	camera.cull_mask = 1048575

	if is_instance_valid(_overlay_viewport_container):
		_overlay_viewport_container.free()
	if is_instance_valid(_dimmer_rect):
		_dimmer_rect.free()

func _create_overlay() -> void:
	var scene_root: Node = tex.get_parent()
	var bg_rect: ColorRect = scene_root.get_node("BackgroundColorRect")

	_dimmer_rect = ColorRect.new()
	_dimmer_rect.color = bg_rect.color
	_dimmer_rect.color.a = 0.5
	_dimmer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_overlay_viewport_container = ViewportContainer.new()
	_overlay_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_viewport_container.stretch = true

	_overlay_viewport = Viewport.new()
	_overlay_viewport.transparent_bg = true
	_overlay_viewport.handle_input_locally = false
	_overlay_viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	_overlay_viewport.world = tex.get_child(0).world

	_overlay_camera = Camera.new()
	_overlay_camera.cull_mask = 2

	_overlay_viewport.add_child(_overlay_camera)
	_overlay_viewport_container.add_child(_overlay_viewport)

	scene_root.add_child(_dimmer_rect)
	scene_root.add_child(_overlay_viewport_container)

	var tex_idx: int = tex.get_index()
	scene_root.move_child(_dimmer_rect, tex_idx + 1)
	scene_root.move_child(_overlay_viewport_container, tex_idx + 2)

	_sync_overlay()

func _sync_overlay() -> void:
	if not is_instance_valid(_overlay_viewport_container):
		return

	_overlay_viewport_container.rect_position = tex.rect_position
	_overlay_viewport_container.rect_size = tex.rect_size
	_overlay_viewport_container.rect_scale = tex.rect_scale
	_overlay_viewport_container.rect_pivot_offset = tex.rect_pivot_offset

	_dimmer_rect.rect_position = tex.rect_position
	_dimmer_rect.rect_size = tex.rect_size
	_dimmer_rect.rect_scale = tex.rect_scale
	_dimmer_rect.rect_pivot_offset = tex.rect_pivot_offset

	if is_instance_valid(_overlay_camera) and is_instance_valid(camera):
		_overlay_camera.global_transform = camera.global_transform
		_overlay_camera.projection = camera.projection
		_overlay_camera.fov = camera.fov
		_overlay_camera.size = camera.size
		_overlay_camera.near = camera.near
		_overlay_camera.far = camera.far
		_overlay_camera.keep_aspect = camera.keep_aspect

func _set_visual_layer_recursive(node: Node, layer_value: int) -> void:
	if node is VisualInstance:
		node.layers = layer_value
	for child in node.get_children():
		_set_visual_layer_recursive(child, layer_value)

func _on_unselect_all() -> void:
	var to_update: Array = selected_balls.duplicate()
	selected_balls.clear()

	if auto_paintballer_mode:
		_auto_paint_affected_cache.clear()

	for b in to_update:
		if is_instance_valid(b) and "ball_no" in b:
			b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	mark_ui_dirty()

func _on_unselect_side(side: String) -> void:
	if selected_balls.empty():
		return

	var symmetry_dict: Dictionary = KeyBallsData.get_symmetry_dict(KeyBallsData.species)

	var left_lookup: Dictionary = {}
	var right_lookup: Dictionary = {}
	for main_part in symmetry_dict:
		for sub_part in symmetry_dict[main_part]:
			var part_info: Dictionary = symmetry_dict[main_part][sub_part]
			if part_info.has("left"):
				for id in part_info.left:
					left_lookup[id] = true
			if part_info.has("right"):
				for id in part_info.right:
					right_lookup[id] = true

	var to_remove: Array = []
	for b in selected_balls:
		if not is_instance_valid(b) or not "ball_no" in b:
			continue

		var ball_no: int = b.ball_no
		var is_left: bool = left_lookup.has(ball_no)
		var is_right: bool = right_lookup.has(ball_no)
		var is_center: bool = not is_left and not is_right

		var should_unselect: bool = false
		match side:
			"left":
				should_unselect = is_left
			"right":
				should_unselect = is_right
			"center":
				should_unselect = is_center

		if should_unselect:
			to_remove.append(b)

	for b in to_remove:
		selected_balls.erase(b)
		if b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	mark_ui_dirty()

func _update_selected_ballz_in_settings() -> void:
	var ids: Array = []
	var properties: Dictionary = preset_settings_instance.get_properties()
	var exclude_eyes: bool = properties.get("exclude_eyes", false) if not move_mode else false

	var filter: Array = []
	if exclude_eyes:
		filter += KeyBallsData.get_group_balls("Eyes")

	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			if not b.ball_no in filter:
				ids.append(b.ball_no)

	move_mode_settings_instance.update_selected_balls_text(ids)
	preset_settings_instance.update_selected_balls_text(ids)

	if auto_paintballer_mode:
		auto_paintballer_settings_instance.update_selected_balls_text(ids)

	var locked_ids: Array = locked_balls.duplicate()
	update_locked_ballz_text(locked_ids)

func _on_select_balls_by_ids(ids: Array) -> void:
	_on_unselect_all()

	for id in ids:
		var ball: Spatial = find_visual_ball_by_no(id)
		if ball and is_instance_valid(ball):
			if "ball_no" in ball:
				selected_balls.append(ball)
				ball.apply_outline_state(ball.OutlineState.ACTIVE_SELECTED)

	_update_selected_ballz_in_settings()
	mark_ui_dirty()

func _commit_box_selection() -> void:
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	var rect: Rect2 = Rect2(box_start_pos, box_end_pos - box_start_pos).abs()
	var all_balls: Array = _get_all_visual_balls()

	var properties: Dictionary = preset_settings_instance.get_properties()
	var exclude_eyes: bool = properties.get("exclude_eyes", false) if not move_mode else false
	var eye_ids: Array = KeyBallsData.get_group_balls("Eyes") if exclude_eyes else []

	for b in all_balls:
		#if not is_instance_valid(b) or not b.is_inside_tree():
		if not is_instance_valid(b) or not b.visible:
			continue

		if b.get("omitted") == true and not pet_node.draw_omitted_balls:
			continue

		if not ("ball_no" in b):
			continue

		if b.ball_no in eye_ids:
			continue

		var projected_pos_local: Vector2 = camera.unproject_position(b.global_transform.origin)
		var pos_in_container: Vector2 = _get_screen_pos_from_viewport_pos(projected_pos_local)

		if rect.has_point(pos_in_container):
			if _is_ball_locked(b):
				continue
			if not (b in selected_balls):
				selected_balls.append(b)
				if b.has_method("apply_outline_state"):
					b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	
	# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_end: int = OS.get_static_memory_usage()
	# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	# print("[PERF] _commit_box_selection took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	# 	OS.get_ticks_msec() - _perf_start_time,
	# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	# 	_perf_orphans
	# ])


# HISTORY
# _capture_pending_state_snapshot
# _record_move_history_entry
# _restore_move_snapshot
# _cap_history_arrays
# _undo_queued_move
# _redo_queued_move
# _record_paint_action
# _undo_queued_paintball
# _redo_queued_paintball
# _record_move_start_state
# _record_move_end_state

func _capture_pending_state_snapshot() -> Dictionary:
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	var snapshot: Dictionary = {}

	for b_no in pending_moves.keys():
		snapshot[b_no] = pending_moves[b_no].duplicate()

	for b in selected_balls:
		if is_instance_valid(b) and not snapshot.has(b.ball_no):
			snapshot[b.ball_no] = {
				"new_pos": b.global_transform.origin,
				"new_size": b.ball_size,
				"new_basis": b.global_transform.basis
			}

	# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_end: int = OS.get_static_memory_usage()
	# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	# print("[PERF] _capture_pending_state_snapshot took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	# 	OS.get_ticks_msec() - _perf_start_time,
	# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	# 	_perf_orphans
	# ])
	
	return snapshot

func _record_move_history_entry(old_snapshot: Dictionary, new_snapshot: Dictionary) -> void:
	if old_snapshot.hash() == new_snapshot.hash():
		return

	move_history.append({"old": old_snapshot, "new": new_snapshot})
	move_redo_stack.clear()

func _restore_move_snapshot(snapshot: Dictionary) -> void:
	pending_moves = snapshot.duplicate(true)

	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if not "ball_no" in b:
			continue

		if pending_moves.has(b.ball_no):
			var data: Dictionary = pending_moves[b.ball_no]
			b.global_transform.origin = data.new_pos
			if data.has("new_size"):
				b.set_ball_size(data.new_size)
			b.apply_outline_state(get_visual_state_for_ball(b))
		else:
			if pet_node._orig_world_pos.has(b.ball_no):
				b.global_transform.origin = pet_node._orig_world_pos[b.ball_no]

			b.apply_outline_state(get_visual_state_for_ball(b))

	move_mode_settings_instance.set_queued_count(pending_moves.size())

func _cap_history_arrays() -> void:
	if paint_history.size() > MAX_INTERACTION_HISTORY:
		paint_history.pop_front()
	if move_history.size() > MAX_INTERACTION_HISTORY:
		move_history.pop_front()

func _undo_queued_move() -> void:
	if move_history.empty():
		return
	var entry: Dictionary = move_history.pop_back()
	move_redo_stack.append(entry)
	_restore_move_snapshot(entry.old)

func _redo_queued_move() -> void:
	if move_redo_stack.empty():
		return
	var entry: Dictionary = move_redo_stack.pop_back()
	move_history.append(entry)
	_restore_move_snapshot(entry.new)

func _record_paint_action(paintballs_added: Array) -> void:
	if paintballs_added.empty():
		return
	print("[STATUS] PetViewContainer: Recording paint action with %d paintballs" % paintballs_added.size())
	paint_history.append(paintballs_added)
	paint_redo_stack.clear()
	_cap_history_arrays()

func _undo_queued_paintball() -> void:
	print("[STATUS] PetViewContainer: Undoing queued paintball action")
	if paint_history.empty():
		var data = pet_node.remove_last_pending_paintball()
		if data:
			paint_redo_stack.append([data])
		return

	var last_action: Array = paint_history.pop_back()
	paint_redo_stack.append(last_action)

	for i in range(last_action.size()):
		pet_node.remove_last_pending_paintball()

func _redo_queued_paintball() -> void:
	print("[STATUS] PetViewContainer: Redoing queued paintball action")
	if paint_redo_stack.empty():
		return

	var action_to_redo: Array = paint_redo_stack.pop_back()
	paint_history.append(action_to_redo)

	for pb_data in action_to_redo:
		pet_node.add_pending_paintball(pb_data)

func _record_move_start_state() -> void:
	var t_start: int = OS.get_ticks_msec()

	_pre_move_state = _capture_pending_state_snapshot()

	print("[TIME] PetViewContainer: _record_move_start_state took " + str(OS.get_ticks_msec() - t_start) + "ms")

func _record_move_end_state(action_name: String) -> void:
	var t_start: int = OS.get_ticks_msec()
	var current_state: Dictionary = _capture_pending_state_snapshot()
	_record_move_history_entry(_pre_move_state, current_state)
	_cap_history_arrays()

	print("[TIME] PetViewContainer: _record_move_end_state took " + str(OS.get_ticks_msec() - t_start) + "ms")

# HELPERS
# _flatten_symmetry_dict
# _begin_auto_move_for_ball
# schedule_autodrag_for_addball
# _wait_for_addball_then_autodrag

func _flatten_symmetry_dict(dict: Dictionary) -> Array:
	var flat_list: Array = []
	for main_part in dict:
		for sub_part in dict[main_part]:
			var part_info: Dictionary = dict[main_part][sub_part]
			if (
				part_info.has("left")
				and part_info.has("right")
				and not part_info.left.empty()
				and not part_info.right.empty()
			):
				flat_list.append(part_info)
	return flat_list

func _begin_auto_move_for_ball(ball: Spatial) -> void:
	if not ball:
		return
	drag_ball = ball
	is_dragging = true
	is_resizing = false
	drag_started_via_code = true
	Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
	pet_node._orig_world_pos[ball.ball_no] = ball.global_transform.origin

func schedule_autodrag_for_addball(ball_no: int) -> void:
	pending_autodrag_addball_no = ball_no
	_wait_for_addball_then_autodrag()

func _wait_for_addball_then_autodrag() -> void:
	var tries: int = 10
	while tries > 0 and pending_autodrag_addball_no != -1:
		yield(get_tree(), "idle_frame")
		var visual: Spatial = find_visual_ball_by_no(pending_autodrag_addball_no)
		if visual:
			_begin_auto_move_for_ball(visual)
			pending_autodrag_addball_no = -1
			return
		tries -= 1


### MODE MANAGEMENT ###
# _deactivate_other_modes
# _update_mode_panel_visibility
# _on_recolor_mode_toggled
# _on_paintball_mode_toggled
# _on_move_mode_toggled
# _on_line_mode_toggled
# _on_preset_mode_toggled
# _on_auto_paintballer_mode_toggled
# _on_project_mode_toggled
# _on_texture_editor_mode_toggled

func _deactivate_other_modes(active_mode_name: String) -> void:
	if active_mode_name != "Paintball Mode":
		paintball_check_box.pressed = false
	if active_mode_name != "Line Mode":
		line_mode_check_box.pressed = false
	if active_mode_name != "Move Mode":
		move_mode_check_box.pressed = false
	if active_mode_name != "Preset Mode":
		preset_mode_check_box.pressed = false
	if active_mode_name != "Project Mode":
		project_mode_check_box.pressed = false
	if active_mode_name != "Auto Paintballer":
		auto_paintballer_check_box.pressed = false
	if active_mode_name != "Recolor Mode":
		recolor_mode_check_box.pressed = false
	if active_mode_name != "Texture Editor":
		texture_editor_mode_check_box.pressed = false
		texture_editor_mode_check_box.pressed = false

func _update_mode_panel_visibility(panel: Control, is_active: bool, switch_to_filetree_on_hide: bool = false) -> void:
	if is_active:
		if "is_docked" in panel and panel.is_docked:
			sidebar_controller.switch_to_tab(panel)
		elif sidebar_controller and (panel == variation_tree or panel == palette_viewer_instance):
			sidebar_controller.switch_to_tab(panel)
		else:
			panel.show()
			panel.raise()
	else:
		if "is_docked" in panel and not panel.is_docked:
			panel.hide()
		elif panel != variation_tree and panel != palette_viewer_instance:
			panel.hide()

		if switch_to_filetree_on_hide and sidebar_controller:
			var tree_tab: Node = sidebar_controller.tab_container.get_node_or_null("FileTree")
			if tree_tab:
				var current_tab: Node = sidebar_controller.tab_container.get_current_tab_control()
				if current_tab == null or current_tab == panel:
					sidebar_controller.switch_to_tab(tree_tab)

func _on_recolor_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.RECOLOR)
	elif current_mode == Mode.RECOLOR:
		set_mode(Mode.NONE)

func _on_paintball_mode_toggled(is_on: bool) -> void:
	print("[STATUS] PetViewContainer: Paintball Mode toggled %s" % is_on)
	if is_on:
		set_mode(Mode.PAINTBALL)
	elif current_mode == Mode.PAINTBALL:
		# Only exit Paintball if we're actually in Paintball mode.
		# When syncing checkboxes during a mode switch, the checkbox is already
		# false so this won't fire. If it does fire (user clicked off), we're
		# in PAINTBALL so it's a legitimate exit.
		set_mode(Mode.NONE)

func _on_move_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.MOVE)
	elif current_mode == Mode.MOVE:
		set_mode(Mode.NONE)

func _on_line_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.LINE)
	elif current_mode == Mode.LINE:
		set_mode(Mode.NONE)

func _on_polygon_mode_toggled(is_on: bool) -> void:
	polygon_mode = is_on
	_clear_polygon_selection()
	polygon_balls.clear()
	mark_ui_dirty()

func _clear_polygon_selection() -> void:
	for b in polygon_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(b.OutlineState.NONE)
	polygon_balls.clear()

func _finalize_polygon() -> void:
	if polygon_balls.size() == MAX_POLYGON_BALLS:
		var ball_ids: Array = []
		for b in polygon_balls:
			if is_instance_valid(b) and "ball_no" in b:
				ball_ids.append(b.ball_no)
		if is_instance_valid(lnz_text_edit) and ball_ids.size() == 4:
			lnz_text_edit.emit_signal("create_polygon", ball_ids)
		_clear_polygon_selection()
		polygon_balls.clear()

func _on_preset_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.PRESET)
	elif current_mode == Mode.PRESET:
		set_mode(Mode.NONE)

func _on_auto_paintballer_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.AUTO_PAINTBALLER)
	elif current_mode == Mode.AUTO_PAINTBALLER:
		set_mode(Mode.NONE)

func _on_project_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.PROJECT)
	elif current_mode == Mode.PROJECT:
		set_mode(Mode.NONE)

func _on_texture_editor_mode_toggled(is_on: bool) -> void:
	if is_on:
		set_mode(Mode.TEXTURE_EDITOR)
	elif current_mode == Mode.TEXTURE_EDITOR:
		set_mode(Mode.NONE)


### PALETTE VIEWER ###
# _on_view_palette_check_box_toggled
# _on_palette_popup_closed
# _on_palette_visibility_changed

func _on_view_palette_check_box_toggled(is_on: bool) -> void:
	if is_instance_valid(palette_viewer_instance):
		_update_mode_panel_visibility(palette_viewer_instance, is_on)

	if is_on:
		if palette_viewer_instance is WindowDialog or palette_viewer_instance is Popup:
			palette_viewer_instance.popup()
		palette_viewer_instance.populate_colors()

func _on_palette_popup_closed() -> void:
	if view_palette_check_box.pressed:
		view_palette_check_box.pressed = false

func _on_palette_visibility_changed() -> void:
	if view_palette_check_box.pressed != palette_viewer_instance.visible:
		view_palette_check_box.pressed = palette_viewer_instance.visible


### VARIATION VIEWER ###
# _on_view_variations_toggled
# _on_variation_visibility_changed

func _on_view_variations_toggled(is_on: bool) -> void:
	if is_instance_valid(variation_tree):
		_update_mode_panel_visibility(variation_tree, is_on)

	if is_on and sidebar_controller:
		sidebar_controller.switch_to_tab(variation_tree)

	if is_instance_valid(variation_tree):
		var lnz_data = pet_node.get("lnz") if is_instance_valid(pet_node) else null
		if lnz_data:
			variation_tree.dog_generator = pet_node
			variation_tree.lnz_parser = lnz_data
		variation_tree.populate_tree()

func _on_variation_visibility_changed() -> void:
	if view_variations_check_box.pressed != variation_tree.visible:
		view_variations_check_box.pressed = variation_tree.visible


### RECOLOR MODE ###


### PAINT MODE ###
# _update_paintball_mode_ui
# _on_delete_mode_toggled
# _set_pending_paintballs_visible
# _on_paintball_mode_for_ball_toggled
# close_paintball_mode
# _finalize_freeline
# _create_paintball_at_position
# _restore_auto_paintballer_selection

func _update_paintball_mode_ui() -> void:
	print("[STATUS] PetViewContainer: updating paintball mode UI (visible: %s)" % paintball_mode)
	if paintball_mode:
		_ensure_panel_visible(paintball_settings_instance)

		_set_pending_paintballs_visible(true)

		paintball_settings_instance.show()
		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_ARROW

		if paintball_target_ball and is_instance_valid(paintball_target_ball):
			paintball_settings_instance.find_node("Target").disabled = true
		else:
			paintball_settings_instance.find_node("Target").disabled = false
	else:
		_set_pending_paintballs_visible(false)

		paintball_settings_instance.hide()
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		mouse_default_cursor_shape = CURSOR_POINTING_HAND

func _on_delete_mode_toggled(is_on: bool) -> void:
	if is_on:
		Input.set_custom_mouse_cursor(eraser, 0, Vector2(30, 31))
	else:
		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))

func _set_pending_paintballs_visible(is_visible: bool) -> void:
	if is_instance_valid(pet_node):
		var pending: Array = pet_node.get_pending_paintball_nodes()
		for pb in pending:
			if is_instance_valid(pb):
				pb.visible = is_visible

func _on_paintball_mode_for_ball_toggled(ball: Spatial) -> void:
	print("[STATUS] PetViewContainer: paintball mode specifically focused on ball #%d" % ball.ball_no)
	close_paintball_on_apply = true
	paintball_target_ball = ball
	set_active_selected_ball(ball)
	paintball_settings_instance.find_node("Target").selected = 1
	if not paintball_check_box.pressed:
		paintball_check_box.pressed = true
	else:
		_update_paintball_mode_ui()
	_isolate_target_ball(ball)
	mark_ui_dirty()

func close_paintball_mode() -> void:
	print("[STATUS] PetViewContainer: closing paintball mode")
	paintball_check_box.pressed = false

func _finalize_freeline(end_position = null) -> void:
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	if freeline_path.empty():
		print("[WARNING] PetViewContainer: freeline path is empty upon finalize")
		return
		
	print("[STATUS] PetViewContainer: finalizing freeline with %d points" % freeline_path.size())
	var props: Dictionary = paintball_settings_instance.get_properties()
	var jitter: float = props.jitter
	var stroke: Array = []

	# Determine if there is a single target for the entire stroke
	var stroke_target_ball: Spatial = null
	if paintball_target_ball and is_instance_valid(paintball_target_ball):
		stroke_target_ball = paintball_target_ball
	elif (
		props.target_mode == 1
		and active_selected_ball
		and is_instance_valid(active_selected_ball)
	):
		stroke_target_ball = active_selected_ball

	var path_len: int = freeline_path.size()
	for i in range(path_len):
		var point: Vector2 = freeline_path[i]
		var jittered_point: Vector2 = (
			point
			+ Vector2(rand_range(-jitter, jitter), rand_range(-jitter, jitter))
		)
		var screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(jittered_point)

		var point_target_ball: Spatial = stroke_target_ball
		if not point_target_ball:  # If no stroke-wide target, use hover mode
			point_target_ball = get_intended_ball(screen_pos)

		var current_diameter: float = -1  # default = random
		if props.tapered:
			var min_diam: float = props.diameter_min
			var max_diam: float = props.diameter_max

			if path_len == 1:
				current_diameter = min_diam
			else:
				var t: float = float(i) / (path_len - 1)
				var pingpong_t: float = 1.0 - abs(t * 2.0 - 1.0)  # 0 -> 1 -> 0
				var calculated_diameter: float = lerp(min_diam, max_diam, pingpong_t)

				current_diameter = int(round(calculated_diameter))

		if point_target_ball:
			stroke.append({"pos": screen_pos, "ball": point_target_ball, "diam": current_diameter})

	if props.get("shuffle", false):
		stroke.shuffle()

	var added_paintballs: Array = []
	for data in stroke:
		var result = _create_paintball_at_position(data.pos, data.ball, data.diam)
		if result:
			added_paintballs.append(result)

	print("[STATUS] PetViewContainer: freeline generated %d valid paintballs" % added_paintballs.size())
	_record_paint_action(added_paintballs)

	# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_end: int = OS.get_static_memory_usage()
	# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)

	# print("[PERF] _finalize_freeline took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	# 	OS.get_ticks_msec() - _perf_start_time,
	# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	# 	_perf_orphans
	# ])

func _create_paintball_at_position(screen_pos: Vector2, target_ball: Spatial, diameter_override: float = -1):
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	if not is_instance_valid(target_ball):
		print("[ERROR] PetViewContainer: target_ball is invalid in _create_paintball_at_position")
		return null
		
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 10000
	var space_state = camera.get_world().direct_space_state
	var result: Dictionary = space_state.intersect_ray(from, to, [self], 1, true, true)

	if result and result.collider and result.collider.get_parent() == target_ball:
		print("[STATUS] PetViewContainer: paintball raycast hit target ball #%d" % target_ball.ball_no)
		var intersection_point: Vector3 = result.position

		if paintball_settings_instance.is_design_mode_active():
			var visual_radius: float = (intersection_point - target_ball.global_transform.origin).length()
			var engine_scale: float = pet_node.lnz.scales[1]
			var lnz_diam: float = (visual_radius * 2.0 / pixel_world_size) / (engine_scale / 255.0)

			var normal: Vector3 = (intersection_point - target_ball.global_transform.origin).normalized()
			var cam_up: Vector3 = camera.global_transform.basis.y
			var tangent_up: Vector3 = (cam_up - normal * cam_up.dot(normal)).normalized()
			if tangent_up.length_squared() < 0.001:
				tangent_up = camera.global_transform.basis.x.cross(normal).normalized()
			var tangent_right: Vector3 = tangent_up.cross(normal).normalized()
			var basis: Basis = Basis(tangent_right, normal, tangent_up)

			var pattern_pbs: Dictionary = paintball_settings_instance.paste_paintball_design(
				normal,
				basis,
				target_ball.ball_no,
				lnz_diam,
				design_scale_multiplier,
				design_rotation_angle
			)

			if not pattern_pbs or not pattern_pbs.has("positions") or not pattern_pbs.has("diameters"):
				print("[WARNING] PetViewContainer: paste_paintball_design returned invalid data")
				return null

			var px_scale: float = pet_node.pixel_world_size
			var lnz_scale: float = pet_node.lnz.scales.x / 255.0

			if px_scale == 0 or lnz_scale == 0:
				print("[ERROR] PetViewContainer: px_scale or lnz_scale is 0, cannot project design paintballz")
				return null

			var pos_arr: PoolVector3Array = pattern_pbs.positions
			var diam_arr: PoolIntArray = pattern_pbs.diameters
			var col_arr: PoolIntArray = pattern_pbs.colors
			var out_col_arr: PoolIntArray = pattern_pbs.outlines
			var out_type_arr: PoolIntArray = pattern_pbs.outline_types
			var fuzz_arr: PoolIntArray = pattern_pbs.fuzzes
			var group_arr: PoolIntArray = pattern_pbs.groups
			var tex_arr: PoolIntArray = pattern_pbs.textures
			var anc_arr: PoolIntArray = pattern_pbs.anchored

			var count: int = pos_arr.size()
			if count == 0:
				print("[WARNING] PetViewContainer: Design pattern produced 0 paintballs")
				return null

			for i in range(count):
				var pos_normalized: Vector3 = pos_arr[i]
				var spot_world_rel: Vector3 = pos_normalized * (lnz_diam * 0.5 * px_scale * lnz_scale)
				var spot_local_rel: Vector3 = target_ball.global_transform.basis.xform_inv(spot_world_rel)
				
				var relative_pos_lnz: Vector3 = LnzLiveUtils.world_to_lnz_delta(
					spot_local_rel, px_scale, pet_node.lnz.scales.x
				)

				var pb_data: Dictionary = {
					"base_ball_no": target_ball.ball_no,
					"diameter": diam_arr[i],
					"color": col_arr[i],
					"outline_color": out_col_arr[i],
					"outline_type": out_type_arr[i],
					"fuzz": fuzz_arr[i],
					"group": group_arr[i],
					"texture": tex_arr[i],
					"anchored": anc_arr[i],
					"relative_pos_local": spot_local_rel,
					"relative_pos_lnz": relative_pos_lnz
				}

				pet_node.add_pending_paintball(pb_data)
			
			print("[STATUS] PetViewContainer: successfully created %d paintballs from design onto ball #%d" % [count, target_ball.ball_no])
			
			pos_arr.resize(0)
			diam_arr.resize(0)
			col_arr.resize(0)
			out_col_arr.resize(0)
			out_type_arr.resize(0)
			fuzz_arr.resize(0)
			group_arr.resize(0)
			tex_arr.resize(0)
			anc_arr.resize(0)
			
			if pattern_pbs.has("positions"): pattern_pbs.erase("positions")
			if pattern_pbs.has("diameters"): pattern_pbs.erase("diameters")
			if pattern_pbs.has("colors"): pattern_pbs.erase("colors")
			if pattern_pbs.has("outlines"): pattern_pbs.erase("outlines")
			if pattern_pbs.has("outline_types"): pattern_pbs.erase("outline_types")
			if pattern_pbs.has("fuzzes"): pattern_pbs.erase("fuzzes")
			if pattern_pbs.has("groups"): pattern_pbs.erase("groups")
			if pattern_pbs.has("textures"): pattern_pbs.erase("textures")
			if pattern_pbs.has("anchored"): pattern_pbs.erase("anchored")

			# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
			# var _perf_stat_end: int = OS.get_static_memory_usage()
			# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
			# print("[PERF] _create_paintball_at_position (Design) took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
			# 	OS.get_ticks_msec() - _perf_start_time,
			# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
			# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
			# 	_perf_orphans
			# ])

			return null

		var props: Dictionary = paintball_settings_instance.get_properties()

		var exclude_eye_ballz: bool = props.get("exclude_eye_ballz", true)
		if exclude_eye_ballz and KeyBallsData.get_group_balls("Eyes").has(target_ball.ball_no):
			return null

		var color_list: Array = LnzLiveUtils.parse_number_list(props.color)
		if color_list.empty():
			print("[ERROR] PetViewContainer: invalid color list format for paintball")
			return null

		var outline_color_list: Array = LnzLiveUtils.parse_number_list(props.outline_color, true)
		if outline_color_list.empty():
			print("[ERROR] PetViewContainer: invalid outline color list format for paintball")
			return null

		var texture_list: Array = LnzLiveUtils.parse_number_list(props.texture, true)
		if texture_list.empty():
			texture_list.append(-1)

		var local_relative_pos: Vector3 = target_ball.to_local(intersection_point)
		# var world_relative_pos: Vector3 = intersection_point - target_ball.global_transform.origin
		
		var relative_pos_lnz: Vector3 = LnzLiveUtils.world_to_lnz_delta(
			local_relative_pos, pet_node.pixel_world_size, pet_node.lnz.scales.x
		)

		var color: int
		var outline_color: int
		var texture: int
		if props.ordered:
			color = color_list[_ordered_color_index % color_list.size()]
			_ordered_color_index += 1
			outline_color = outline_color_list[(
				_ordered_outline_color_index
				% outline_color_list.size()
			)]
			_ordered_outline_color_index += 1
			texture = texture_list[_ordered_texture_index % texture_list.size()]
			_ordered_texture_index += 1
		else:
			color = color_list[randi() % color_list.size()]
			outline_color = outline_color_list[randi() % outline_color_list.size()]
			texture = texture_list[randi() % texture_list.size()]

		var diameter: float
		if diameter_override != -1:
			diameter = diameter_override
			if props.get("pixel_mode", false):
				var base_size: float = float(target_ball.ball_size)
				if base_size == 0:
					base_size = 1.0
				diameter = int(ceil((diameter / base_size) * 100.0))
		else:
			if props.get("pixel_mode", false):
				var base_size: float = float(target_ball.ball_size)
				if base_size == 0:
					base_size = 1.0
				var rand_px: float = rand_range(props["diameter_min"], props["diameter_max"])
				diameter = int(ceil((rand_px / base_size) * 100.0))
			else:
				diameter = int(round(rand_range(props["diameter_min"], props["diameter_max"])))

		var paintball_info: Dictionary = {
			"base_ball_no": target_ball.ball_no,
			"relative_pos_local": local_relative_pos,
			"relative_pos_lnz": relative_pos_lnz,
			"diameter": int(diameter),
			"color": color,
			"outline_color": outline_color,
			"outline_type": floor(rand_range(props.outline_type_min, props.outline_type_max)),
			"fuzz": floor(rand_range(props.fuzz_min, props.fuzz_max)),
			"texture": texture,
			"group": props.group,
			"anchored": props.anchored,
		}

		pet_node.add_pending_paintball(paintball_info)
		print("[STATUS] PetViewContainer: successfully created paintball on ball #%d" % target_ball.ball_no)
		
		# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
		# var _perf_stat_end: int = OS.get_static_memory_usage()
		# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		# print("[PERF] _create_paintball_at_position took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
		# 	OS.get_ticks_msec() - _perf_start_time,
		# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
		# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
		# 	_perf_orphans
		# ])

		return paintball_info

	# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_end: int = OS.get_static_memory_usage()
	# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	# print("[PERF] _create_paintball_at_position (Failed Raycast) took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	# 	OS.get_ticks_msec() - _perf_start_time,
	# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	# 	_perf_orphans
	# ])

	return null

func _restore_auto_paintballer_selection() -> void:
	# Double yield needed: dog_generator.generate_pet() calls init_visual_balls()
	# which uses call_deferred("_finish_dependent_geometry"). 
	# Frame 1: generate_pet completes, deferred geometry scheduled
	# Frame 2: deferred geometry runs, _restore resumes (1st yield)
	#           but ball_map may still be updating — need another frame
	# Frame 3: _restore resumes (2nd yield), ball_map is stable
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	_on_affected_list_changed(_auto_paint_affected_cache)


### SHAPE MODE ###
# _on_randomize_body_proportions
# _on_randomize_moves

func _on_randomize_body_proportions(settings: Dictionary) -> void:
	randomize()
	lnz_text_edit.save_backup()

	# Two-value sections
	var leg_ext1_min: int = int(settings.leg_ext_1.min)
	var leg_ext1_max: int = int(settings.leg_ext_1.max)
	var leg_ext1: int = randi() % (leg_ext1_max - leg_ext1_min + 1) + leg_ext1_min
	var leg_ext2_min: int = int(settings.leg_ext_2.min)
	var leg_ext2_max: int = int(settings.leg_ext_2.max)
	var leg_ext2: int = randi() % (leg_ext2_max - leg_ext2_min + 1) + leg_ext2_min
	lnz_text_edit.update_lnz_section_two_values("[Leg Extension]", leg_ext1, leg_ext2)

	var head_enl1_min: int = int(settings.head_enl_1.min)
	var head_enl1_max: int = int(settings.head_enl_1.max)
	var head_enl1: int = randi() % (head_enl1_max - head_enl1_min + 1) + head_enl1_min
	var head_enl2_min: int = int(settings.head_enl_2.min)
	var head_enl2_max: int = int(settings.head_enl_2.max)
	var head_enl2: int = randi() % (head_enl2_max - head_enl2_min + 1) + head_enl2_min
	lnz_text_edit.update_lnz_section_two_values("[Head Enlargement]", head_enl1, head_enl2)

	var feet_enl1_min: int = int(settings.feet_enl_1.min)
	var feet_enl1_max: int = int(settings.feet_enl_1.max)
	var feet_enl1: int = randi() % (feet_enl1_max - feet_enl1_min + 1) + feet_enl1_min
	var feet_enl2_min: int = int(settings.feet_enl_2.min)
	var feet_enl2_max: int = int(settings.feet_enl_2.max)
	var feet_enl2: int = randi() % (feet_enl2_max - feet_enl2_min + 1) + feet_enl2_min
	lnz_text_edit.update_lnz_section_two_values("[Feet Enlargement]", feet_enl1, feet_enl2)

	var scales1_min: int = int(settings.scales_1.min)
	var scales1_max: int = int(settings.scales_1.max)
	var scales1: int = randi() % (scales1_max - scales1_min + 1) + scales1_min
	var scales2_min: int = int(settings.scales_2.min)
	var scales2_max: int = int(settings.scales_2.max)
	var scales2: int = randi() % (scales2_max - scales2_min + 1) + scales2_min
	lnz_text_edit.update_lnz_section_two_values("[Default Scales]", scales1, scales2)

	# One-value sections
	var body_ext_min: int = int(settings.body_ext.min)
	var body_ext_max: int = int(settings.body_ext.max)
	var body_ext: int = randi() % (body_ext_max - body_ext_min + 1) + body_ext_min
	lnz_text_edit.update_lnz_section_one_value("[Body Extension]", body_ext)

	var face_ext_min: int = int(settings.face_ext.min)
	var face_ext_max: int = int(settings.face_ext.max)
	var face_ext: int = randi() % (face_ext_max - face_ext_min + 1) + face_ext_min
	lnz_text_edit.update_lnz_section_one_value("[Face Extension]", face_ext)

	var ear_ext_min: int = int(settings.ear_ext.min)
	var ear_ext_max: int = int(settings.ear_ext.max)
	var ear_ext: int = randi() % (ear_ext_max - ear_ext_min + 1) + ear_ext_min
	lnz_text_edit.update_lnz_section_one_value("[Ear Extension]", ear_ext)

	# A short delay to allow the text edit to process, then save.
	yield(get_tree().create_timer(0.1), "timeout")
	lnz_text_edit.save_file()
	print("[STATUS] PetViewContainer: _on_randomize_body_proportions: randomized body proportions and applied to LNZ")

func _on_randomize_moves(settings: Dictionary) -> void:
	# var _perf_start_time: int = OS.get_ticks_msec()
	# var _perf_dyn_start: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_start: int = OS.get_static_memory_usage()

	var target_groups: Array = settings.groups
	var mirror_x: bool = settings.mirror_x
	var type: String = settings.type
	var range_min: Vector3 = settings.range_min
	var range_max: Vector3 = settings.range_max
	var jitter_radius_percent: float = settings.jitter_radius

	var moves_to_apply: Dictionary = {}

	var target_balls: Array = []
	for group_name in target_groups:
		target_balls.append_array(KeyBallsData.get_group_balls(group_name))

	var unique_targets: Dictionary = {}
	for b in target_balls:
		unique_targets[b] = true
	target_balls = unique_targets.keys()

	var symmetry_dict: Dictionary = KeyBallsData.get_symmetry_dict(KeyBallsData.species)

	var eye_pairs_source: Dictionary = KeyBallsData.get_eyes(KeyBallsData.species)
	var eye_iris_pairs: Dictionary = {}  # iris_id -> eye_id
	for iris in eye_pairs_source:
		eye_iris_pairs[iris] = eye_pairs_source[iris]

	var assigned_offsets: Dictionary = {}

	randomize()

	for ball_no in target_balls:
		if assigned_offsets.has(ball_no):
			continue

		var offset: Vector3 = Vector3.ZERO

		# iris, check if eye already has offset
		if eye_iris_pairs.has(ball_no):
			var parent_eye: int = eye_iris_pairs[ball_no]
			if assigned_offsets.has(parent_eye):
				offset = assigned_offsets[parent_eye]
				assigned_offsets[ball_no] = offset
				moves_to_apply[ball_no] = offset
				continue

		# random offset
		if type == "range":
			var rx: float = rand_range(range_min.x, range_max.x)
			var ry: float = rand_range(range_min.y, range_max.y)
			var rz: float = rand_range(range_min.z, range_max.z)
			offset = Vector3(rx, ry, rz)
		elif type == "jitter":
			# % radius offset from ball size
			var ball_size: float = 10.0
			if pet_node.bhd and ball_no < pet_node.bhd.ball_sizes.size():
				ball_size = pet_node.bhd.ball_sizes[ball_no]
			elif pet_node.lnz.addballs.has(ball_no):
				var ab = pet_node.lnz.addballs[ball_no]
				if typeof(ab) == TYPE_OBJECT:
					ball_size = ab.size
				elif typeof(ab) == TYPE_DICTIONARY:
					ball_size = ab.get("size", 10)

			var radius: float = ball_size / 2.0
			var jitter_amount: float = radius * (jitter_radius_percent / 100.0)

			var v: Vector3 = Vector3(rand_range(-1, 1), rand_range(-1, 1), rand_range(-1, 1)).normalized()
			offset = v * jitter_amount

		assigned_offsets[ball_no] = offset
		moves_to_apply[ball_no] = offset

		# Symmetry
		if mirror_x:
			var mirrored_ball: int = KeyBallsData.get_mirrored_ball(ball_no, symmetry_dict)

			if mirrored_ball != -1:
				var mirror_offset: Vector3 = Vector3(-offset.x, offset.y, offset.z)
				assigned_offsets[mirrored_ball] = mirror_offset
				moves_to_apply[mirrored_ball] = mirror_offset
			else:
				# zero out if center ball
				offset.x = 0
				assigned_offsets[ball_no] = offset
				moves_to_apply[ball_no] = offset

		# Find iris for eye
		for iris in eye_iris_pairs:
			if eye_iris_pairs[iris] == ball_no:
				assigned_offsets[iris] = offset
				moves_to_apply[iris] = offset

				if mirror_x:
					var mirrored_iris: int = KeyBallsData.get_mirrored_ball(iris, symmetry_dict)
					if mirrored_iris != -1:
						var mirror_offset: Vector3 = Vector3(-offset.x, offset.y, offset.z)
						assigned_offsets[mirrored_iris] = mirror_offset
						moves_to_apply[mirrored_iris] = mirror_offset

	if not moves_to_apply.empty():
		lnz_text_edit.set_batch_moves(moves_to_apply)
		print("[STATUS] PetViewContainer: _on_randomize_moves: randomized moves applied to %d ballz" % moves_to_apply.size())
		
	# var _perf_dyn_end: int = OS.get_dynamic_memory_usage()
	# var _perf_stat_end: int = OS.get_static_memory_usage()
	# var _perf_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	# print("[PERF] _on_randomize_moves took %d ms | DynRAM: %s -> Peak: %s | StatRAM: %s -> Peak: %s | Orphans: %d" % [
	# 	OS.get_ticks_msec() - _perf_start_time,
	# 	String.humanize_size(_perf_dyn_start), String.humanize_size(_perf_dyn_end),
	# 	String.humanize_size(_perf_stat_start), String.humanize_size(_perf_stat_end),
	# 	_perf_orphans
	# ])


### LINE MODE ###
# _handle_line_mode_input
# _on_LnzTextEdit_create_polygon

func _handle_line_mode_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		var hover: Spatial = get_intended_ball(_get_viewport_pos_from_screen_pos(event.position))
		
		if hover:
			if polygon_mode:
				polygon_balls.append(hover)
				hover.apply_outline_state(hover.OutlineState.ACTIVE_SELECTED)
				_reset_tab_state()
				if polygon_balls.size() == MAX_POLYGON_BALLS:
					_finalize_polygon()
			else:
				if !is_instance_valid(linez_start_ball):
					linez_start_ball = hover
					linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.ACTIVE_SELECTED)
					_reset_tab_state()
				else:
					if hover != linez_start_ball:
						pet_node.emit_signal("line_created", linez_start_ball.ball_no, hover.ball_no)
						linez_start_ball.apply_outline_state(linez_start_ball.OutlineState.NONE)
						linez_start_ball = null
						_reset_tab_state()
						if line_mode_close:
							line_mode_check_box.pressed = false
			return true
	return false

func _on_LnzTextEdit_create_polygon(ball_ids) -> void:
	if is_instance_valid(lnz_text_edit):
		lnz_text_edit.write_polygon_section(ball_ids)
		lnz_text_edit.save_file(true)


### PRESET MODE ###
# _on_eyedropper_toggled
# _on_preset_apply_selection
# _restore_preset_selection

func _on_eyedropper_toggled(is_on: bool) -> void:
	if is_on:
		Input.set_custom_mouse_cursor(eyedropper, 0, Vector2(30, 31))
	else:
		Input.set_custom_mouse_cursor(smallbrush, 0, Vector2(30, 31))

func _on_preset_apply_selection() -> void:
	if selected_balls.empty():
		return

	var ids_to_restore: Array = []
	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			ids_to_restore.append(b.ball_no)

	var base_properties: Dictionary = preset_settings_instance.get_properties()

	var exclusion_list: Array = []
	if base_properties.get("exclude_eyes", false):
		exclusion_list = KeyBallsData.get_group_balls("Eyes")

	var batch_changes: Dictionary = {}

	for b in selected_balls:
		if not is_instance_valid(b) or not "ball_no" in b:
			continue
		if b.ball_no in exclusion_list:
			continue

		var ball_no: int = b.ball_no
		var per_ball_props: Dictionary = base_properties.duplicate()
		var sizing_info: Dictionary = _get_ball_sizing_info(pet_node, ball_no)

		var size_mode: int = base_properties.get("size_mode", 0)
		var ref_val: float = base_properties.get("size", 10)

		if size_mode == preset_settings_instance.SizeMode.SUM:
			var original: int = 0
			if pet_node.lnz.balls.has(ball_no):
				original = pet_node.lnz.balls[ball_no]["size"] 
			elif pet_node.lnz.addballs.has(ball_no):
				original = pet_node.lnz.addballs[ball_no]["size"] 
			per_ball_props["size"] = original + ref_val

		elif size_mode == preset_settings_instance.SizeMode.TRUE:
			var scale: float = pet_node.lnz.scales[1]
			per_ball_props["size"] = LnzLiveUtils.visual_size_to_lnz_size(
				ref_val, sizing_info.is_addball, scale, sizing_info.bhd_size, sizing_info.enl_x, sizing_info.enl_y
			)

		if per_ball_props.get("scale_paintballz", false) and per_ball_props.has("paintballz"):
			var source_ref: float = preset_settings_instance.source_ball_reference_size
			
			var final_lnz: float = per_ball_props["size"]
			var current_base_size: float = sizing_info.bhd_size + final_lnz
			if not sizing_info.is_addball:
				current_base_size = floor(current_base_size * (sizing_info.enl_x / 100.0)) + sizing_info.enl_y
			
			var scale: float = pet_node.lnz.scales[1]
			var target_visual_size: int = round((current_base_size - 2.0) * (scale / 255.0))
			target_visual_size -= 1.0 - fmod(target_visual_size, 2.0)
			
			var scale_ratio: float = float(target_visual_size) / float(source_ref) if source_ref > 0 else 1.0

			var p_size_mod: float = per_ball_props.get("paintball_size_scale", 1.0)
			var p_pos_mod: float = per_ball_props.get("paintball_pos_scale", 1.0)

			if scale_ratio != 1.0 or p_size_mod != 1.0 or p_pos_mod != 1.0:
				var scaled_paintballz: Array = []
				for pb in per_ball_props["paintballz"]:
					var new_pb: Dictionary = pb.duplicate()
					#new_pb.position *= (scale_ratio * p_pos_mod)
					#new_pb.size = int(round(new_pb.size * scale_ratio * p_size_mod))
					new_pb.position *= p_pos_mod
					new_pb.size = int(round(new_pb.size * p_size_mod))
					scaled_paintballz.append(new_pb)
				per_ball_props["paintballz"] = scaled_paintballz

		batch_changes[ball_no] = per_ball_props

	if not batch_changes.empty():
		lnz_text_edit.apply_batch_presets(batch_changes)
		_restore_preset_selection(ids_to_restore)

func _restore_preset_selection(ids: Array) -> void:
	selected_balls.clear()

	for id in ids:
		var ball: Spatial = find_visual_ball_by_no(id)
		if is_instance_valid(ball):
			selected_balls.append(ball)
			if ball.has_method("apply_outline_state"):
				ball.apply_outline_state(ball.OutlineState.ACTIVE_SELECTED)

	_update_selected_ballz_in_settings()


### MOVE MODE ###
# _on_move_mode_clear
# _update_pivot_limit
# _track_pending_move
# _on_move_mode_apply
# _on_align_selection
# _align_ball_list
# _get_axis_val
# _on_snap_selection
# _snap_ball_list_to_target
# _on_nudge_selection
# _on_move_mode_select_group
# _apply_eye_iris_binding
# _apply_mirror_move
# _apply_mirror_scale
# _get_rotation_pivot_origin
# _on_rotate_selection
# _on_flip_selection
# _on_apply_scale
# _on_pivot_changed
# _toggle_lock_ball
# _unlock_all_balls
# _is_ball_locked
# _handle_group_pan_input

func _on_move_mode_clear() -> void:
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if not "ball_no" in b:
			continue

		if pending_moves.has(b.ball_no):
			var move_data: Dictionary = pending_moves[b.ball_no]

			b.global_transform.origin = move_data.orig_pos

			if move_data.has("orig_size"):
				b.set_ball_size(move_data.orig_size)

	pending_moves.clear()
	move_mode_settings_instance.set_queued_count(0)

	for b in all_balls:
		if not "ball_no" in b:
			continue
		b.apply_outline_state(get_visual_state_for_ball(b))

	mark_ui_dirty()

func _update_pivot_limit() -> void:
	if is_instance_valid(pet_node) and is_instance_valid(move_mode_settings_instance):
		var total_balls: int = 0
		if pet_node.ball_map:
			total_balls = pet_node.ball_map.size()
		else:
			total_balls = (
				get_tree().get_nodes_in_group("balls").size()
				+ get_tree().get_nodes_in_group("addballs").size()
			)

		move_mode_settings_instance.update_pivot_max(total_balls)

func _track_pending_move(ball: Spatial) -> void:
	var current_size: float = ball.ball_size
	if not pending_moves.has(ball.ball_no):
		var orig_pos: Vector3 = ball.global_transform.origin
		if pet_node._orig_world_pos.has(ball.ball_no):
			orig_pos = pet_node._orig_world_pos[ball.ball_no]

		pending_moves[ball.ball_no] = {
			"orig_pos": orig_pos,
			"orig_size": current_size,
			"orig_basis": ball.global_transform.basis,
			"new_pos": ball.global_transform.origin,
			"new_size": current_size,
			"new_basis": ball.global_transform.basis
		}
	else:
		pending_moves[ball.ball_no]["new_pos"] = ball.global_transform.origin
		pending_moves[ball.ball_no]["new_size"] = current_size
		pending_moves[ball.ball_no]["new_basis"] = ball.global_transform.basis

	ball.apply_outline_state(get_visual_state_for_ball(ball))
	move_mode_settings_instance.set_queued_count(pending_moves.size())

	mark_ui_dirty()

func _on_move_mode_apply() -> void:
	if pending_moves.empty():
		return

	var needs_rebuild: bool = false
	for b_no in pending_moves:
		var data: Dictionary = pending_moves[b_no]
		
		if data.has("orig_basis") and data.has("new_basis"):
			if data.orig_basis != data.new_basis:
				needs_rebuild = true
			else:
				data.erase("orig_basis")
				data.erase("new_basis")
				
		if data.has("orig_size") and data.has("new_size"):
			# if data.orig_size != data.new_size:
			if not is_equal_approx(data.orig_size, data.new_size):
				needs_rebuild = true
			else:
				data.erase("orig_size")
				data.erase("new_size")

	var selected_ids: Array = []
	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			selected_ids.append(b.ball_no)

	pet_node.set_skip_next_rebuild(!needs_rebuild)
	lnz_text_edit.apply_batch_moves(pending_moves)

	pending_moves.clear()
	move_mode_settings_instance.set_queued_count(0)

	selected_balls.clear()
	for id in selected_ids:
		var new_b: Spatial = find_visual_ball_by_no(id)
		if new_b and is_instance_valid(new_b):
			selected_balls.append(new_b)

	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if not "ball_no" in b:
			continue
		pet_node._orig_world_pos[b.ball_no] = b.global_transform.origin
		b.apply_outline_state(get_visual_state_for_ball(b))

	_update_selected_ballz_in_settings()
	mark_ui_dirty()

func _on_align_selection(axis: String, mode: int) -> void:
	if selected_balls.empty():
		return

	_record_move_start_state()

	_align_ball_list(selected_balls, axis, mode)

	if move_mode_settings_instance.is_mirror_x_active():
		var mirrored_group: Array = []

		for b in selected_balls:
			var partner_id: int = lnz_text_edit.find_mirrored_ball(b.ball_no)

			if partner_id != -1 and partner_id != b.ball_no:
				var partner_visual: Spatial = find_visual_ball_by_no(partner_id)

				if (
					partner_visual
					and not (partner_visual in selected_balls)
					and not (partner_visual in mirrored_group)
				):
					mirrored_group.append(partner_visual)

		if not mirrored_group.empty():
			var target_mode: int = mode
			if axis == "x":
				if mode == 0:
					target_mode = 2
				elif mode == 2:
					target_mode = 0

			_align_ball_list(mirrored_group, axis, target_mode)

	_record_move_end_state("Align " + axis)

func _align_ball_list(ball_list: Array, axis: String, mode: int) -> void:
	var reference_val: float = 0.0
	var first: bool = true

	if mode == 1:
		var sum: float = 0.0
		for b in ball_list:
			if not "ball_no" in b:
				continue
			sum += _get_axis_val(b, axis)
		reference_val = sum / ball_list.size()
	else:
		for b in ball_list:
			if not "ball_no" in b:
				continue
			var val: float = _get_axis_val(b, axis)
			if first:
				reference_val = val
				first = false
			else:
				if mode == 0:
					if val < reference_val:
						reference_val = val
				elif mode == 2:
					if val > reference_val:
						reference_val = val

	for b in ball_list:
		if not "ball_no" in b:
			continue
		if axis == "x":
			b.global_transform.origin.x = reference_val
		elif axis == "y":
			b.global_transform.origin.y = reference_val
		elif axis == "z":
			b.global_transform.origin.z = reference_val
		_track_pending_move(b)

func _get_axis_val(ball: Spatial, axis: String) -> float:
	if axis == "x":
		return ball.global_transform.origin.x
	if axis == "y":
		return ball.global_transform.origin.y
	if axis == "z":
		return ball.global_transform.origin.z
	return 0.0

func _on_snap_selection(axis: String, direction: int) -> void:
	if selected_balls.empty():
		return

	var all_balls: Array = _get_all_visual_balls()
	var target_val: float = 0.0
	var first: bool = true

	for b in all_balls:
		if not is_instance_valid(b):
			continue

		if b.get("omitted") == true:
			continue

		var val: float = _get_axis_val(b, axis)

		if first:
			target_val = val
			first = false
		else:
			if direction == -1:
				if val < target_val:
					target_val = val
			else:
				if val > target_val:
					target_val = val

	_snap_ball_list_to_target(selected_balls, axis, direction, target_val)

	if move_mode_settings_instance.is_mirror_x_active():
		var mirrored_group: Array = []
		for b in selected_balls:
			var partner_id: int = lnz_text_edit.find_mirrored_ball(b.ball_no)
			if partner_id != -1 and partner_id != b.ball_no:
				var partner_visual: Spatial = find_visual_ball_by_no(partner_id)
				if (
					partner_visual
					and not (partner_visual in selected_balls)
					and not (partner_visual in mirrored_group)
				):
					mirrored_group.append(partner_visual)

		if not mirrored_group.empty():
			_snap_ball_list_to_target(mirrored_group, axis, direction, target_val)

func _snap_ball_list_to_target(ball_list: Array, axis: String, direction: int, target_val: float) -> void:
	var selection_extreme: float = 0.0
	var first: bool = true

	for b in ball_list:
		if not "ball_no" in b:
			continue
		var val: float = _get_axis_val(b, axis)

		if first:
			selection_extreme = val
			first = false
		else:
			if direction == -1:
				if val < selection_extreme:
					selection_extreme = val
			else:
				if val > selection_extreme:
					selection_extreme = val

	if first:
		return

	var offset: float = target_val - selection_extreme

	for b in ball_list:
		if not "ball_no" in b:
			continue
		if axis == "y":
			b.global_transform.origin.y += offset
		elif axis == "z":
			b.global_transform.origin.z += offset
		_track_pending_move(b)

func _on_nudge_selection(vector: Vector3) -> void:
	if selected_balls.empty():
		return

	_record_move_start_state()

	# var px_scale = pet_node.pixel_world_size
	# var lnz_scale = pet_node.lnz.scales.x / 255.0

	# var world_delta = vector
	# world_delta.y *= -1
	# world_delta = world_delta * (px_scale * lnz_scale)
	var world_delta: Vector3 = LnzLiveUtils.lnz_to_world_delta(
		vector, pet_node.pixel_world_size, pet_node.lnz.scales.x
	)

	for b in selected_balls:
		var addballz_base_selected: bool = false
		var p: Node = b.get_parent()
		while is_instance_valid(p) and p != get_tree().root:
			if p in selected_balls:
				addballz_base_selected = true
				break
			p = p.get_parent()

		if not addballz_base_selected:
			b.global_transform.origin += world_delta

		_track_pending_move(b)

	_record_move_end_state("Nudge")

func _on_move_mode_select_group(group_name: String) -> void:
	if not Input.is_key_pressed(KEY_CONTROL):
		_on_unselect_all()

	var balls_to_select: Array = KeyBallsData.get_group_balls(group_name)

	for b_no in balls_to_select:
		var b: Spatial = find_visual_ball_by_no(b_no)

		if b and is_instance_valid(b):
			if not (b in selected_balls):
				selected_balls.append(b)
				if not "ball_no" in b:
					continue
				b.apply_outline_state(b.OutlineState.ACTIVE_SELECTED)
	_update_selected_ballz_in_settings()

func _apply_eye_iris_binding(ball: Spatial, delta: Vector3) -> void:
	# Check for eye -> iris binding
	var eye_pairs_source: Dictionary = KeyBallsData.get_eyes(KeyBallsData.species)

	for iris_id in eye_pairs_source:
		var eye_id: int = eye_pairs_source[iris_id]
		if eye_id == ball.ball_no:
			# ball is an Eye, so move its Iris if not already selected
			var iris_visual: Spatial = find_visual_ball_by_no(iris_id)
			if iris_visual and is_instance_valid(iris_visual):
				if not (iris_visual in selected_balls):
					# Iris not manually selected, so move it along with the eye
					iris_visual.global_transform.origin += delta
					_track_pending_move(iris_visual)

func _apply_mirror_move(balls_moved: Array, delta: Vector3) -> void:
	var mirror_mult: Vector3 = move_mode_settings_instance.get_mirror_vector()

	for b in balls_moved:
		if not "ball_no" in b:
			continue

		var addballz_base_selected: bool = false
		var p: Node = b.get_parent()
		while is_instance_valid(p) and p != get_tree().root:
			if p in balls_moved:
				addballz_base_selected = true
				break
			p = p.get_parent()

		if addballz_base_selected:
			var partner_id_check: int = lnz_text_edit.find_mirrored_ball(b.ball_no)
			if partner_id_check != -1 and partner_id_check != b.ball_no:
				var partner_visual: Spatial = find_visual_ball_by_no(partner_id_check)
				if partner_visual:
					_track_pending_move(partner_visual)
			continue

		var partner_id: int = lnz_text_edit.find_mirrored_ball(b.ball_no)
		if partner_id != -1 and partner_id != b.ball_no:
			# Find visual ball for partner
			var partner_visual: Spatial = find_visual_ball_by_no(partner_id)
			if partner_visual and not (partner_visual in selected_balls):
				var mirrored_delta: Vector3 = delta * mirror_mult

				partner_visual.global_transform.origin += mirrored_delta
				_track_pending_move(partner_visual)

func _apply_mirror_scale(targets: Array, factor: float, scale_dist: bool, scale_size: bool, pivot_origin: Vector3, is_interactive: bool = false) -> void:
	var selected_nos: Dictionary = {}
	for b in targets:
		selected_nos[b.ball_no] = true

	for b in targets:
		if not is_instance_valid(b):
			continue

		var partner_id: int = lnz_text_edit.find_mirrored_ball(b.ball_no)
		if partner_id == -1 or partner_id == b.ball_no or selected_nos.has(partner_id):
			continue

		var mb: Spatial = find_visual_ball_by_no(partner_id)
		if not is_instance_valid(mb):
			continue

		if scale_dist:
			var start_pos: Vector3 = mb.global_transform.origin

			if is_interactive and _scale_group_initial_data.has(partner_id):
				start_pos = _scale_group_initial_data[partner_id].pos
			elif not is_interactive:
				if not pet_node._orig_world_pos.has(partner_id):
					pet_node._orig_world_pos[partner_id] = start_pos

			var rel_pos: Vector3 = start_pos - pivot_origin
			mb.global_transform.origin = pivot_origin + (rel_pos * factor)

		if scale_size:
			mb.set_ball_size(b.ball_size)

		_track_pending_move(mb)

func _get_rotation_pivot_origin(pivot_id: int) -> Vector3:
	var pivot_origin: Vector3 = Vector3.ZERO
	var pivot_visual: Spatial = null

	if pivot_id != -1:
		pivot_visual = find_visual_ball_by_no(pivot_id)

	if pivot_visual and is_instance_valid(pivot_visual):
		pivot_origin = pivot_visual.global_transform.origin
	else:
		var sum_pos: Vector3 = Vector3.ZERO
		var count: int = 0
		for b in selected_balls:
			if is_instance_valid(b):
				sum_pos += b.global_transform.origin
				count += 1
		if count > 0:
			pivot_origin = sum_pos / count
	return pivot_origin

func _on_rotate_selection(rotation_degrees: Vector3, pivot_id: int) -> void:
	if selected_balls.empty():
		return

	_record_move_start_state()

	var pivot_origin: Vector3 = _get_rotation_pivot_origin(pivot_id)

	var rot_rad: Vector3 = Vector3(
		deg2rad(rotation_degrees.x), deg2rad(rotation_degrees.y), deg2rad(rotation_degrees.z)
	)

	var basis: Basis = Basis(Quat(rot_rad))

	for b in selected_balls:
		if is_instance_valid(b):
			var addballz_base_selected: bool = false
			var p: Node = b.get_parent()
			while is_instance_valid(p) and p != get_tree().root:
				if p in selected_balls:
					addballz_base_selected = true
					break
				p = p.get_parent()

			if addballz_base_selected:
				continue

			var current_pos: Vector3 = b.global_transform.origin
			var current_basis: Basis = b.global_transform.basis
			_track_pending_move(b)

			var rel_pos: Vector3 = current_pos - pivot_origin
			var rotated_rel: Vector3 = basis.xform(rel_pos)
			var new_pos: Vector3 = pivot_origin + rotated_rel

			if not pet_node._orig_world_pos.has(b.ball_no):
				pet_node._orig_world_pos[b.ball_no] = current_pos

			b.global_transform.origin = new_pos
			b.global_transform.basis = basis * b.global_transform.basis

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

	_record_move_end_state("Rotate")

func _on_flip_selection(axis_vector: Vector3, pivot_id: int) -> void:
	if selected_balls.empty():
		return

	_record_move_start_state()

	var pivot_origin: Vector3 = _get_rotation_pivot_origin(pivot_id)

	for b in selected_balls:
		if is_instance_valid(b):
			var addballz_base_selected: bool = false
			var p: Node = b.get_parent()
			while is_instance_valid(p) and p != get_tree().root:
				if p in selected_balls:
					addballz_base_selected = true
					break
				p = p.get_parent()

			if addballz_base_selected:
				continue

			var current_pos: Vector3 = b.global_transform.origin
			var current_basis: Basis = b.global_transform.basis

			if not pending_moves.has(b.ball_no):
				_track_pending_move(b)

			var rel_pos: Vector3 = current_pos - pivot_origin
			var flipped_rel: Vector3 = rel_pos * axis_vector
			var new_pos: Vector3 = pivot_origin + flipped_rel

			if not pet_node._orig_world_pos.has(b.ball_no):
				pet_node._orig_world_pos[b.ball_no] = current_pos

			b.global_transform.origin = new_pos

			var scale_basis: Basis = Basis().scaled(axis_vector)
			b.global_transform.basis = scale_basis * b.global_transform.basis

			if scale_basis.determinant() < 0:
				var mesh_instance: MeshInstance = b.get_node_or_null("MeshInstance")
				if mesh_instance:
					mesh_instance.scale.x *= -1.0

				for child in b.get_children():
					if child.is_in_group("paintballs"):
						var pb_mesh: MeshInstance = child.get_node_or_null("MeshInstance")
						if pb_mesh:
							pb_mesh.scale.x *= -1.0

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

	_record_move_end_state("Flip")

func _on_apply_scale(factor: float, scale_dist: bool, scale_size: bool, pivot_id: int) -> void:
	if selected_balls.empty():
		return

	_record_move_start_state()

	var pivot_origin: Vector3 = _get_rotation_pivot_origin(pivot_id)

	for b in selected_balls:
		if not is_instance_valid(b):
			continue

		var addballz_base_selected: bool = false
		var p: Node = b.get_parent()
		while is_instance_valid(p) and p != get_tree().root:
			if p in selected_balls:
				addballz_base_selected = true
				break
			p = p.get_parent()

		if scale_dist:
			if not addballz_base_selected:
				var current_pos: Vector3 = b.global_transform.origin
				var rel_pos: Vector3 = current_pos - pivot_origin
				var new_rel_pos: Vector3 = rel_pos * factor
				var new_pos: Vector3 = pivot_origin + new_rel_pos

				if not pet_node._orig_world_pos.has(b.ball_no):
					pet_node._orig_world_pos[b.ball_no] = current_pos

				var delta: Vector3 = new_pos - current_pos
				b.global_transform.origin = new_pos

				_apply_eye_iris_binding(b, delta)

		if scale_size:
			var original_s: float = b.ball_size
			var target_visual: float = original_s * factor
			target_visual = clamp(target_visual, 1.0, 500.0)
			var sizing_info: Dictionary = _get_ball_sizing_info(pet_node, b.ball_no)
			var is_ab: bool = sizing_info.is_addball
			var bhd_s: int = sizing_info.bhd_size
			var engine_scale: float = pet_node.lnz.scales[1]
			var snapped_visual: float = LnzLiveUtils.snap_visual_size(
				target_visual, is_ab, engine_scale, bhd_s, sizing_info.enl_x, sizing_info.enl_y
			)
			b.set_ball_size(snapped_visual)

			pass

	for b in selected_balls:
		if is_instance_valid(b):
			_track_pending_move(b)

	if move_mode_settings_instance.is_mirror_x_active():
		_apply_mirror_scale(selected_balls, factor, scale_dist, scale_size, pivot_origin)

	_record_move_end_state("Scale")

func _on_pivot_changed() -> void:
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if is_instance_valid(b) and b.has_method("apply_outline_state"):
			b.apply_outline_state(get_visual_state_for_ball(b))

func _toggle_lock_ball(ball: Spatial) -> void:
	if not is_instance_valid(ball) or not "ball_no" in ball:
		return
	var ball_no: int = ball.ball_no
	if ball_no in locked_balls:
		locked_balls.erase(ball_no)
	else:
		locked_balls.append(ball_no)
	_sync_locked_balls_to_visuals()
	update_locked_ballz_text(locked_balls)

func _unlock_all_balls() -> void:
	locked_balls.clear()
	_sync_locked_balls_to_visuals()
	update_locked_ballz_text([])

func _sync_locked_balls_to_visuals() -> void:
	var all_balls: Array = _get_all_visual_balls()
	for b in all_balls:
		if not is_instance_valid(b) or not "ball_no" in b:
			continue
		var script_path: String = ""
		if b.get_script():
			script_path = b.get_script().resource_path
		if script_path.find("Ball.gd") == -1:
			continue
		if b.ball_no in locked_balls:
			b.is_locked = true
		else:
			b.is_locked = false
		b.apply_outline_state(get_visual_state_for_ball(b))
	mark_ui_dirty()

func _is_ball_locked(ball: Spatial) -> bool:
	if not is_instance_valid(ball) or not "ball_no" in ball:
		return false
	return ball.ball_no in locked_balls

func _handle_group_pan_input(event: InputEvent) -> bool:
	if not move_mode:
		return false

	# Group pan: SHIFT + left-click drag on any area (background or selected area)
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed and Input.is_key_pressed(KEY_SHIFT):
		_group_panning = true
		_group_pan_start_pos = event.position
		# Capture the current world position of the first selected ball as reference
		if selected_balls.size() > 0 and is_instance_valid(selected_balls[0]):
			_group_pan_start_origin = selected_balls[0].global_transform.origin
		Input.set_custom_mouse_cursor(hand_move, 0, Vector2(30, 31))
		return true

	# End group pan on mouse release
	if _group_panning and event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed:
		_group_panning = false
		Input.set_custom_mouse_cursor(hand_neutral, 0, Vector2(30, 31))
		return true

	# Handle group pan drag
	if _group_panning and event is InputEventMouseMotion:
		var screen_pos: Vector2 = _get_viewport_pos_from_screen_pos(event.position)
		
		var ray_o: Vector3 = camera.project_ray_origin(screen_pos)
		var ray_d: Vector3 = camera.project_ray_normal(screen_pos)
		var plane_n: Vector3 = camera.global_transform.basis.z.normalized()
		var plane_p: Vector3 = _group_pan_start_origin
		var current_intersect = LnzLiveUtils.intersect_ray_with_plane(ray_o, ray_d, plane_n, plane_p)

		var prev_mouse_pos: Vector2 = event.position - event.relative
		var prev_ray_o: Vector3 = camera.project_ray_origin(_get_viewport_pos_from_screen_pos(prev_mouse_pos))
		var prev_ray_d: Vector3 = camera.project_ray_normal(_get_viewport_pos_from_screen_pos(prev_mouse_pos))
		var prev_intersect = LnzLiveUtils.intersect_ray_with_plane(prev_ray_o, prev_ray_d, plane_n, plane_p)

		if current_intersect and prev_intersect:
			var delta: Vector3 = current_intersect - prev_intersect

			# Apply axis/plane constraints
			var constrain_x: bool = Input.is_key_pressed(KEY_X)
			var constrain_y: bool = Input.is_key_pressed(KEY_Y)
			var constrain_z: bool = Input.is_key_pressed(KEY_Z)

			if constrain_x or constrain_y or constrain_z:
				if not constrain_x:
					delta.x = 0
				if not constrain_y:
					delta.y = 0
				if not constrain_z:
					delta.z = 0

			for b in selected_balls:
				if is_instance_valid(b):
					if _is_ball_locked(b):
						continue
					b.global_transform.origin += delta
					_track_pending_move(b)

			if move_mode_settings_instance.is_mirror_x_active():
				_apply_mirror_move(selected_balls, delta)

		return true

	return false

func _on_lock_all() -> void:
	for b in selected_balls:
		if is_instance_valid(b) and "ball_no" in b:
			if not b.ball_no in locked_balls:
				locked_balls.append(b.ball_no)
	_sync_locked_balls_to_visuals()
	update_locked_ballz_text(locked_balls)

func _on_unlock_all() -> void:
	_unlock_all_balls()

func _on_select_locked_balls_by_ids(ids: Array) -> void:
	if ids.empty():
		locked_balls.clear()
	else:
		locked_balls = ids.duplicate()
	_sync_locked_balls_to_visuals()
	update_locked_ballz_text(locked_balls)

func update_locked_ballz_text(ball_ids: Array) -> void:
	if not is_instance_valid(move_mode_settings_instance):
		return
	var locked_node = move_mode_settings_instance.find_node("LockedBallz")
	if not locked_node:
		return
	if ball_ids.empty():
		locked_node.text = ""
		return
	var sorted_ids: Array = ball_ids.duplicate()
	sorted_ids.sort()
	var start: int = sorted_ids[0]
	var prev: int = start
	var ranges: Array = []
	for i in range(1, sorted_ids.size()):
		var curr: int = sorted_ids[i]
		if curr == prev + 1:
			prev = curr
		else:
			if start == prev:
				ranges.append(str(start))
			else:
				ranges.append(str(start) + "-" + str(prev))
			start = curr
			prev = curr
	if start == prev:
		ranges.append(str(start))
	else:
		ranges.append(str(start) + "-" + str(prev))
	var s: String = ""
	for i in range(ranges.size()):
		if i > 0:
			s += ","
		s += str(ranges[i])
	locked_node.text = s
