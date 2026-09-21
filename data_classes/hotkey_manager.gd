extends Node
## HotkeyManager.gd
## Centralized hotkey management via Godot's InputMap system.
## All hotkeys are defined as InputMap actions with one or more InputEvent bindings.
## User-customizable bindings are saved to user://hotkeys.cfg under "Hotkeys" section.
## Default bindings are used as fallbacks if config is missing or corrupted.
## Context-specific bindings use a prefix: <context>_<action> (e.g., texture_editor_tool_brush).

const SETTINGS_PATH: String = "user://settings.cfg"
const HOTKEYS_SECTION: String = "HotkeyProperties"
const PROFILES_SECTION: String = "HotkeyProfiles"

signal hotkeys_reloaded

var current_context: String = "global"

var context_specific_actions: Array = [
	"texture_tool_line", "texture_tool_hline", "texture_tool_vline",
	"texture_tool_brush", "texture_tool_eraser", "texture_tool_eyedropper",
	"texture_tool_fill", "texture_tool_bucket_toggle",
	"design_stamp_scale", "design_stamp_scale_down", "design_stamp_rotate", "design_stamp_rotate_down",
	"design_sync_brush", "design_sync_line", "design_sync_horizontal", "design_sync_vertical",
	"text_save", "text_undo", "text_redo", "text_find",
	"text_next_section", "text_prev_section", "text_jump_ball_index",
]

func is_context_specific(action: String) -> bool:
	return action in context_specific_actions

var default_bindings: Dictionary = {
	# === Viewport / Camera ===
	"viewport_zoom_in": { "scancode": BUTTON_WHEEL_UP, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_zoom_out": { "scancode": BUTTON_WHEEL_DOWN, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_zoom_in_incremental": { "scancode": KEY_PLUS, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"viewport_zoom_out_incremental": { "scancode": KEY_MINUS, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"viewport_zoom_in_alt2": { "scancode": KEY_KP_ADD, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"viewport_zoom_out_alt2": { "scancode": KEY_KP_SUBTRACT, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"viewport_pan": { "scancode": BUTTON_MIDDLE, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_pan_alt": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": false, "meta": false, "key_code": KEY_SPACE },
	"viewport_rotate": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_front": { "scancode": KEY_1, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_bottom": { "scancode": KEY_2, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_top": { "scancode": KEY_3, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_right": { "scancode": KEY_4, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_left": { "scancode": KEY_5, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_back": { "scancode": KEY_6, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_iso_rb": { "scancode": KEY_7, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_iso_rt": { "scancode": KEY_8, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_iso_lb": { "scancode": KEY_9, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"viewport_view_iso_lt": { "scancode": KEY_0, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"global_undo": { "scancode": KEY_Z, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"global_redo": { "scancode": KEY_Y, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"global_exit_mode": { "scancode": KEY_ESCAPE, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"global_box_select": { "scancode": BUTTON_LEFT, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"global_multi_select": { "scancode": BUTTON_LEFT, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"global_unhide_all": { "scancode": KEY_H, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"global_flash_ballz": { "scancode": KEY_Q, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"global_toggle_hotkey_overlay": { "scancode": KEY_F1, "ctrl": false, "shift": false, "alt": false, "meta": false },

	# === Mode Toggles ===
	"mode_toggle_select": { "scancode": KEY_S, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_paintball": { "scancode": KEY_W, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_paintball_alt": { "scancode": KEY_B, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"mode_toggle_move": { "scancode": KEY_U, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_move_alt": { "scancode": KEY_M, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"mode_toggle_preset": { "scancode": KEY_R, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_preset_alt": { "scancode": KEY_G, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"mode_toggle_line": { "scancode": KEY_E, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_line_alt": { "scancode": KEY_L, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"mode_toggle_recolor": { "scancode": KEY_G, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_recolor_alt": { "scancode": KEY_F, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"mode_toggle_shape": { "scancode": KEY_D, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_shape_alt": { "scancode": KEY_P, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"mode_toggle_auto_paintballer": { "scancode": KEY_A, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_palette_viewer": { "scancode": KEY_T, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_variation_viewer": { "scancode": KEY_V, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"mode_toggle_capture_headshot": { "scancode": KEY_K, "ctrl": false, "shift": false, "alt": false, "meta": false },

	# === Select Mode (hovering a ball) ===
	"select_jump_info": { "scancode": KEY_B, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_info_alt": { "scancode": KEY_Z, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_move": { "scancode": KEY_X, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_move_alt": { "scancode": KEY_M, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_project": { "scancode": KEY_C, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_project_alt": { "scancode": KEY_P, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_line": { "scancode": KEY_V, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_jump_line_alt": { "scancode": KEY_L, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_delete_ball": { "scancode": KEY_DELETE, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_hide_ball": { "scancode": KEY_H, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_cycle_nearby": { "scancode": KEY_N, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"select_tools_menu": { "scancode": KEY_SPACE, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"select_tools_menu_alt": { "scancode": BUTTON_RIGHT, "ctrl": false, "shift": false, "alt": false, "meta": false },

	# === Move Mode ===
	"move_lock_ball": { "scancode": KEY_Q, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_unlock_all": { "scancode": KEY_Q, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"move_set_pivot": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"move_scale_group": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": true, "alt": true, "meta": false },
	"move_group_pan": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"move_nudge_positive": { "scancode": KEY_EQUAL, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_nudge_positive_alt": { "scancode": KEY_KP_ADD, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_nudge_negative": { "scancode": KEY_MINUS, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_nudge_negative_alt": { "scancode": KEY_KP_SUBTRACT, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_nudge_value_up": { "scancode": KEY_UP, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_nudge_value_down": { "scancode": KEY_DOWN, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"move_mini_undo": { "scancode": KEY_Z, "ctrl": true, "shift": true, "alt": false, "meta": false },
	"move_mini_redo": { "scancode": KEY_X, "ctrl": true, "shift": true, "alt": false, "meta": false },

	# === Paintball Mode ===
	"paint_draw": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"paint_eraser": { "scancode": BUTTON_LEFT, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"paint_freeline": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"paint_straight_line": { "scancode": KEY_L, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"paint_straight_line_alt": { "scancode": KEY_ALT, "ctrl": false, "shift": false, "alt": true, "meta": false },
	"paint_lock_axis_x": { "scancode": KEY_X, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"paint_lock_axis_y": { "scancode": KEY_Y, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"paint_scale_brush": { "scancode": BUTTON_WHEEL_UP, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"paint_scale_brush_down": { "scancode": BUTTON_WHEEL_DOWN, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"paint_scale_brush_alt": { "scancode": KEY_UP, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"paint_scale_brush_alt_down": { "scancode": KEY_DOWN, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"paint_mini_undo": { "scancode": KEY_Z, "ctrl": true, "shift": true, "alt": false, "meta": false },
	"paint_mini_redo": { "scancode": KEY_X, "ctrl": true, "shift": true, "alt": false, "meta": false },

	# === Paintball Design Mode ===
	"design_stamp_scale": { "scancode": BUTTON_WHEEL_UP, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"design_stamp_scale_down": { "scancode": BUTTON_WHEEL_DOWN, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"design_stamp_rotate": { "scancode": BUTTON_WHEEL_UP, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"design_stamp_rotate_down": { "scancode": BUTTON_WHEEL_DOWN, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"design_sync_brush": { "scancode": KEY_B, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"design_sync_line": { "scancode": KEY_L, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"design_sync_horizontal": { "scancode": KEY_H, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"design_sync_vertical": { "scancode": KEY_V, "ctrl": true, "shift": false, "alt": false, "meta": false },

	# === Visual Editing (global drag) ===
	"visual_move": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": true, "alt": false, "meta": false },
	"visual_scale": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": true, "alt": true, "meta": false },

	# === Axis Lock (dragging) ===
	"axis_lock_x": { "scancode": KEY_X, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"axis_lock_y": { "scancode": KEY_Y, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"axis_lock_z": { "scancode": KEY_Z, "ctrl": false, "shift": false, "alt": false, "meta": false },

	# === Preset Mode ===
	"preset_apply": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"preset_eyedropper": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": true, "meta": false },

	# === Recolor Mode ===
	"recolor_apply": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": false, "meta": false },

	# === Line Mode ===
	"line_connect": { "scancode": BUTTON_LEFT, "ctrl": false, "shift": false, "alt": false, "meta": false },

	# === Text Editor ===
	"text_save": { "scancode": KEY_S, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"text_undo": { "scancode": KEY_Z, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"text_redo": { "scancode": KEY_Y, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"text_find": { "scancode": KEY_F, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"text_next_section": { "scancode": KEY_PAGEDOWN, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"text_prev_section": { "scancode": KEY_PAGEUP, "ctrl": false, "shift": false, "alt": false, "meta": false },
	"text_jump_ball_index": { "scancode": KEY_Q, "ctrl": true, "shift": false, "alt": false, "meta": false },

	# === Texture Editor ===
	"texture_tool_line": { "scancode": KEY_L, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_hline": { "scancode": KEY_H, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_vline": { "scancode": KEY_V, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_brush": { "scancode": KEY_B, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_eraser": { "scancode": KEY_E, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_eyedropper": { "scancode": KEY_Q, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_fill": { "scancode": KEY_F, "ctrl": true, "shift": false, "alt": false, "meta": false },
	"texture_tool_bucket_toggle": { "scancode": KEY_G, "ctrl": false, "shift": false, "alt": false, "meta": false },
}

var action_groups: Dictionary = {
	"Viewport / Camera": [
		"viewport_zoom_in", "viewport_zoom_out", "viewport_zoom_in_incremental", "viewport_zoom_out_incremental",
		"viewport_pan", "viewport_rotate",
		"viewport_view_front", "viewport_view_bottom", "viewport_view_top", "viewport_view_right",
		"viewport_view_left", "viewport_view_back", "viewport_view_iso_rb", "viewport_view_iso_rt",
		"viewport_view_iso_lb", "viewport_view_iso_lt",
		"global_undo", "global_redo", "global_exit_mode",
		"global_box_select", "global_multi_select", "global_unhide_all", "global_flash_ballz",
		"global_toggle_hotkey_overlay"
	],
	"Mode Toggles": [
		"mode_toggle_select", "mode_toggle_paintball", "mode_toggle_paintball_alt",
		"mode_toggle_move", "mode_toggle_move_alt", "mode_toggle_preset", "mode_toggle_preset_alt",
		"mode_toggle_line", "mode_toggle_line_alt", "mode_toggle_recolor", "mode_toggle_recolor_alt",
		"mode_toggle_shape", "mode_toggle_shape_alt",
		"mode_toggle_auto_paintballer", "mode_toggle_palette_viewer",
		"mode_toggle_variation_viewer", "mode_toggle_capture_headshot"
	],
	"Select Mode": [
		"select_jump_info", "select_jump_info_alt", "select_jump_move", "select_jump_move_alt",
		"select_jump_project", "select_jump_project_alt", "select_jump_line", "select_jump_line_alt",
		"select_delete_ball", "select_hide_ball", "select_cycle_nearby",
		"select_tools_menu", "select_tools_menu_alt"
	],
	"Move Mode": [
		"move_lock_ball", "move_unlock_all", "move_set_pivot", "move_scale_group", "move_group_pan",
		"move_nudge_positive", "move_nudge_positive_alt", "move_nudge_negative", "move_nudge_negative_alt",
		"move_nudge_value_up", "move_nudge_value_down",
		"move_mini_undo", "move_mini_redo"
	],
	"Paintball Mode": [
		"paint_draw", "paint_eraser", "paint_freeline",
		"paint_straight_line", "paint_straight_line_alt",
		"paint_lock_axis_x", "paint_lock_axis_y",
		"paint_scale_brush", "paint_scale_brush_down", "paint_scale_brush_alt", "paint_scale_brush_alt_down",
		"paint_mini_undo", "paint_mini_redo"
	],
	"Paintball Design": [
		"design_stamp_scale", "design_stamp_scale_down", "design_stamp_rotate", "design_stamp_rotate_down",
		"design_sync_brush", "design_sync_line", "design_sync_horizontal", "design_sync_vertical"
	],
	"Visual Editing": [
		"visual_move", "visual_scale"
	],
	"Axis Lock": [
		"axis_lock_x", "axis_lock_y", "axis_lock_z"
	],
	"Preset Mode": [
		"preset_apply", "preset_eyedropper"
	],
	"Recolor Mode": [
		"recolor_apply"
	],
	"Line Mode": [
		"line_connect"
	],
	"Text Editor": [
		"text_save", "text_undo", "text_redo", "text_find",
		"text_next_section", "text_prev_section", "text_jump_ball_index"
	],
	"Texture Editor": [
		"texture_tool_line", "texture_tool_hline", "texture_tool_vline",
		"texture_tool_brush", "texture_tool_eraser", "texture_tool_eyedropper",
		"texture_tool_fill", "texture_tool_bucket_toggle"
	],
}

# User-customized bindings: action_name -> binding dictionary
var user_bindings: Dictionary = {}

# Loaded hotkey profiles: profile_name -> bindings dictionary
var profiles: Dictionary = {}

var action_display_names: Dictionary = {
	"viewport_zoom_in": "Zoom In (continuous)",
	"viewport_zoom_out": "Zoom Out (continuous)",
	"viewport_zoom_in_incremental": "Zoom In (incremental)",
	"viewport_zoom_out_incremental": "Zoom Out (incremental)",
	"viewport_pan": "Pan Camera",
	"viewport_rotate": "Rotate Camera",
	"viewport_view_front": "View: Front",
	"viewport_view_bottom": "View: Bottom",
	"viewport_view_top": "View: Top",
	"viewport_view_right": "View: Right",
	"viewport_view_left": "View: Left",
	"viewport_view_back": "View: Back",
	"viewport_view_iso_rb": "View: Right-Bottom Iso",
	"viewport_view_iso_rt": "View: Right-Top Iso",
	"viewport_view_iso_lb": "View: Left-Bottom Iso",
	"viewport_view_iso_lt": "View: Left-Top Iso",
	"global_undo": "Undo",
	"global_redo": "Redo",
	"global_exit_mode": "Exit Mode",
	"global_box_select": "Box Selection",
	"global_multi_select": "Multi-Select",
	"global_unhide_all": "Unhide All Balls",
	"global_flash_ballz": "Flash Ballz/Linez",
	"global_toggle_hotkey_overlay": "Toggle Hotkey Overlay",
	"mode_toggle_select": "Toggle Select Mode",
	"mode_toggle_paintball": "Toggle Paintball Mode",
	"mode_toggle_paintball_alt": "Toggle Paintball Mode (alt)",
	"mode_toggle_move": "Toggle Move Mode",
	"mode_toggle_move_alt": "Toggle Move Mode (alt)",
	"mode_toggle_preset": "Toggle Preset Mode",
	"mode_toggle_preset_alt": "Toggle Preset Mode (alt)",
	"mode_toggle_line": "Toggle Line Mode",
	"mode_toggle_line_alt": "Toggle Line Mode (alt)",
	"mode_toggle_recolor": "Toggle Recolor Mode",
	"mode_toggle_recolor_alt": "Toggle Recolor Mode (alt)",
	"mode_toggle_shape": "Toggle Shape Mode",
	"mode_toggle_shape_alt": "Toggle Shape Mode (alt)",
	"mode_toggle_auto_paintballer": "Toggle Auto Paintballer",
	"mode_toggle_palette_viewer": "Toggle Palette Viewer",
	"mode_toggle_variation_viewer": "Toggle Variation Viewer",
	"mode_toggle_capture_headshot": "Capture Headshot",
	"select_jump_info": "Jump to Ball Info",
	"select_jump_info_alt": "Jump to Ball Info (alt)",
	"select_jump_move": "Jump to Move Lines",
	"select_jump_move_alt": "Jump to Move Lines (alt)",
	"select_jump_project": "Jump to Project Lines",
	"select_jump_project_alt": "Jump to Project Lines (alt)",
	"select_jump_line": "Jump to Linez",
	"select_jump_line_alt": "Jump to Linez (alt)",
	"select_delete_ball": "Delete Ball",
	"select_hide_ball": "Hide Ball",
	"select_cycle_nearby": "Cycle Nearby Balls",
	"select_tools_menu": "Open Tools Menu",
	"select_tools_menu_alt": "Open Tools Menu (alt)",
	"move_lock_ball": "Lock/Unlock Ball",
	"move_unlock_all": "Unlock All",
	"move_set_pivot": "Set Pivot Ball",
	"move_scale_group": "Scale/Resize Group",
	"move_group_pan": "Group Pan",
	"move_nudge_positive": "Nudge +",
	"move_nudge_positive_alt": "Nudge + (alt)",
	"move_nudge_negative": "Nudge -",
	"move_nudge_negative_alt": "Nudge - (alt)",
	"move_nudge_value_up": "Increase Nudge Value",
	"move_nudge_value_down": "Decrease Nudge Value",
	"move_mini_undo": "Mini-History Undo",
	"move_mini_redo": "Mini-History Redo",
	"paint_draw": "Draw Paintball",
	"paint_eraser": "Eraser",
	"paint_freeline": "Freeline",
	"paint_straight_line": "Straight Line",
	"paint_straight_line_alt": "Straight Line (alt)",
	"paint_lock_axis_x": "Lock Axis X (straight line)",
	"paint_lock_axis_y": "Lock Axis Y (straight line)",
	"paint_scale_brush": "Scale Brush (up)",
	"paint_scale_brush_down": "Scale Brush (down)",
	"paint_scale_brush_alt": "Scale Brush (alt up)",
	"paint_scale_brush_alt_down": "Scale Brush (alt down)",
	"paint_mini_undo": "Mini-History Undo",
	"paint_mini_redo": "Mini-History Redo",
	"design_stamp_scale": "Scale Stamp",
	"design_stamp_scale_down": "Scale Stamp (down)",
	"design_stamp_rotate": "Rotate Stamp",
	"design_stamp_rotate_down": "Rotate Stamp (down)",
	"design_sync_brush": "Sync Brush Mode",
	"design_sync_line": "Sync Line Mode",
	"design_sync_horizontal": "Sync Horizontal",
	"design_sync_vertical": "Sync Vertical",
	"visual_move": "Move Ball (drag)",
	"visual_scale": "Scale Ball (drag)",
	"axis_lock_x": "Axis Lock X",
	"axis_lock_y": "Axis Lock Y",
	"axis_lock_z": "Axis Lock Z",
	"preset_apply": "Apply Preset",
	"preset_eyedropper": "Eyedropper",
	"recolor_apply": "Apply Paint Bucket",
	"line_connect": "Connect Linez",
	"text_save": "Save / Apply Changes",
	"text_undo": "Undo (Text Editor)",
	"text_redo": "Redo (Text Editor)",
	"text_find": "Find/Replace",
	"text_next_section": "Jump to Next Section",
	"text_prev_section": "Jump to Previous Section",
	"text_jump_ball_index": "Jump to Ball Index",
	"texture_tool_line": "Line Tool",
	"texture_tool_hline": "Horizontal Line",
	"texture_tool_vline": "Vertical Line",
	"texture_tool_brush": "Brush Tool",
	"texture_tool_eraser": "Eraser Tool",
	"texture_tool_eyedropper": "Eyedropper",
	"texture_tool_fill": "Fill Tool",
	"texture_tool_bucket_toggle": "Toggle Paint Bucket",
}


func _ready() -> void:
	load_hotkeys()


## Load hotkeys from config, falling back to defaults
func load_hotkeys() -> void:
	user_bindings = {}
	profiles = {}

	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err == OK:
		if config.has_section(HOTKEYS_SECTION) and config.has_section_key(HOTKEYS_SECTION, "bindings"):
			var json_str: String = config.get_value(HOTKEYS_SECTION, "bindings")
			var json: JSONParseResult = JSON.parse(json_str)
			if json.result is Dictionary:
				user_bindings = json.result

		# Load profiles from JSON
		if config.has_section(PROFILES_SECTION):
			var profile_names: Array = config.get_section_keys(PROFILES_SECTION)
			for profile_name in profile_names:
				var val = config.get_value(PROFILES_SECTION, profile_name)
				if val is String:
					var json: JSONParseResult = JSON.parse(val)
					if json.result is Dictionary:
						profiles[profile_name] = json.result

	_apply_bindings()
	emit_signal("hotkeys_reloaded")


func save_hotkeys() -> void:
	var config: ConfigFile = ConfigFile.new()

	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		printerr("[HotkeyManager] Error loading settings config: ", err)

	if config.has_section(HOTKEYS_SECTION):
		config.erase_section(HOTKEYS_SECTION)

	var json_str: String = JSON.print(user_bindings)
	config.set_value(HOTKEYS_SECTION, "bindings", json_str)

	var err2: int = config.save(SETTINGS_PATH)
	if err2 != OK:
		printerr("[HotkeyManager] Error saving settings config: ", err2)

	# Reapply bindings to live InputMap
	_apply_bindings()
	emit_signal("hotkeys_reloaded")

	print("[HotkeyManager] Hotkeys saved to settings.cfg")


func save_profile(name: String) -> bool:
	if name == "" or name in ["Default"]:
		return false

	var profile: Dictionary = {}
	for action in user_bindings:
		if user_bindings.has(action):
			profile[action] = user_bindings[action]

	profiles[name] = profile

	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		printerr("[HotkeyManager] Error loading settings config for profile save: ", err)

	if not config.has_section(PROFILES_SECTION):
		config.add_section(PROFILES_SECTION)

	config.set_value(PROFILES_SECTION, name, profile)

	var err2: int = config.save(SETTINGS_PATH)
	if err2 != OK:
		printerr("[HotkeyManager] Error saving profile: ", err2)
		return false

	print("[HotkeyManager] Profile '", name, "' saved.")
	return true


func load_profile(name: String) -> bool:
	if not profiles.has(name):
		print("[HotkeyManager] Profile '", name, "' not found.")
		return false

	user_bindings = {}
	for action in profiles[name]:
		user_bindings[action] = profiles[name][action]

	_apply_bindings()
	emit_signal("hotkeys_reloaded")
	print("[HotkeyManager] Profile '", name, "' loaded.")
	return true


func reset_to_defaults() -> void:
	user_bindings = {}
	_apply_bindings()
	_save_hotkeys_to_config()
	emit_signal("hotkeys_reloaded")
	print("[HotkeyManager] Reset to defaults.")


func _save_hotkeys_to_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		printerr("[HotkeyManager] Error loading settings config: ", err)

	if config.has_section(HOTKEYS_SECTION):
		config.erase_section(HOTKEYS_SECTION)

	var json_str: String = JSON.print(user_bindings)
	config.set_value(HOTKEYS_SECTION, "bindings", json_str)

	config.save(SETTINGS_PATH)


func get_binding(action: String) -> Dictionary:
	if user_bindings.has(action):
		return user_bindings[action]
	if default_bindings.has(action):
		return default_bindings[action]
	return {}


func get_all_actions() -> Array:
	var actions: Array = []
	for action in default_bindings:
		actions.append(action)
	for action in user_bindings:
		if not actions.has(action):
			actions.append(action)
	return actions


func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func is_action_pressed_frame(action: String) -> bool:
	return Input.is_action_pressed(action) and Input.is_action_released(action + "_latched") == false


func get_action_display_name(action: String) -> String:
	if action_display_names.has(action):
		return action_display_names[action]
	return action


func get_key_string(binding: Dictionary) -> String:
	if not binding or binding.size() == 0:
		return "None"

	var parts: Array = []

	if binding.get("ctrl", false):
		parts.append("Ctrl")
	if binding.get("shift", false):
		parts.append("Shift")
	if binding.get("alt", false):
		parts.append("Alt")
	if binding.get("meta", false):
		parts.append("Meta")

	var scancode: int = binding.get("scancode", 0)
	var key_code: int = binding.get("key_code", -1)

	if scancode >= KEY_SPACE and scancode <= KEY_Z:
		parts.append(_scancode_to_string(scancode))
	elif scancode == BUTTON_WHEEL_UP:
		parts.append("Wheel Up")
	elif scancode == BUTTON_WHEEL_DOWN:
		parts.append("Wheel Down")
	elif scancode == BUTTON_LEFT:
		if key_code != -1:
			parts.append("L" + _scancode_to_string(key_code))
		else:
			parts.append("LMB")
	elif scancode == BUTTON_MIDDLE:
		if key_code != -1:
			parts.append("M" + _scancode_to_string(key_code))
		else:
			parts.append("MMB")
	elif scancode == BUTTON_RIGHT:
		if key_code != -1:
			parts.append("R" + _scancode_to_string(key_code))
		else:
			parts.append("RMB")
	elif scancode >= BUTTON_LEFT and scancode <= BUTTON_RIGHT:
		parts.append("Button " + str(scancode))

	var result: String = ""
	for i in range(parts.size()):
		result += parts[i]
		if i < parts.size() - 1:
			result += " + "
	return result


func check_conflict(proposed_binding: Dictionary, exclude_action: String = "") -> String:
	if not proposed_binding or proposed_binding.size() == 0:
		return ""

	for action in default_bindings:
		if action == exclude_action:
			continue
		if is_context_specific(action) and not is_context_specific(exclude_action):
			continue
		if is_context_specific(exclude_action) and not is_context_specific(action):
			continue
		var existing = default_bindings[action]
		if _bindings_match(proposed_binding, existing):
			return action

	for action in user_bindings:
		if action == exclude_action:
			continue
		if is_context_specific(action) and not is_context_specific(exclude_action):
			continue
		var user_val = user_bindings[action]
		if _bindings_match(proposed_binding, user_val):
			return action

	return ""


func _bindings_match(a: Dictionary, b: Dictionary) -> bool:
	if a.get("ctrl", false) != b.get("ctrl", false):
		return false
	if a.get("shift", false) != b.get("shift", false):
		return false
	if a.get("alt", false) != b.get("alt", false):
		return false
	if a.get("meta", false) != b.get("meta", false):
		return false

	var key_a: int = a.get("key_code", -1)
	var key_b: int = b.get("key_code", -1)
	if key_a != -1 and key_b != -1:
		if key_a != key_b:
			return false
	elif key_a != -1 or key_b != -1:
		return false

	return a.get("scancode", 0) == b.get("scancode", 0)


func _scancode_to_string(scancode: int) -> String:
	match scancode:
		KEY_ESCAPE:
			return "Esc"
		KEY_TAB:
			return "Tab"
		KEY_BACKSPACE:
			return "Bksp"
		KEY_ENTER:
			return "Enter"
		KEY_KP_ENTER:
			return "KP Enter"
		KEY_INSERT:
			return "Ins"
		KEY_DELETE:
			return "Del"
		KEY_PAUSE:
			return "Pause"
		KEY_PRINT:
			return "Print"
		KEY_HOME:
			return "Home"
		KEY_END:
			return "End"
		KEY_LEFT:
			return "Left"
		KEY_UP:
			return "Up"
		KEY_RIGHT:
			return "Right"
		KEY_DOWN:
			return "Down"
		KEY_PAGEUP:
			return "PgUp"
		KEY_PAGEDOWN:
			return "PgDn"
		KEY_SHIFT:
			return "Shift"
		KEY_CONTROL:
			return "Ctrl"
		KEY_ALT:
			return "Alt"
		KEY_META:
			return "Meta"
		KEY_KP_ADD:
			return "KP +"
		KEY_KP_SUBTRACT:
			return "KP -"
		KEY_KP_MULTIPLY:
			return "KP *"
		KEY_KP_DIVIDE:
			return "KP /"
		KEY_KP_0:
			return "KP 0"
		KEY_KP_1:
			return "KP 1"
		KEY_KP_2:
			return "KP 2"
		KEY_KP_3:
			return "KP 3"
		KEY_KP_4:
			return "KP 4"
		KEY_KP_5:
			return "KP 5"
		KEY_KP_6:
			return "KP 6"
		KEY_KP_7:
			return "KP 7"
		KEY_KP_8:
			return "KP 8"
		KEY_KP_9:
			return "KP 9"
		KEY_0:
			return "0"
		KEY_1:
			return "1"
		KEY_2:
			return "2"
		KEY_3:
			return "3"
		KEY_4:
			return "4"
		KEY_5:
			return "5"
		KEY_6:
			return "6"
		KEY_7:
			return "7"
		KEY_8:
			return "8"
		KEY_9:
			return "9"
		KEY_A:
			return "A"
		KEY_B:
			return "B"
		KEY_C:
			return "C"
		KEY_D:
			return "D"
		KEY_E:
			return "E"
		KEY_F:
			return "F"
		KEY_G:
			return "G"
		KEY_H:
			return "H"
		KEY_I:
			return "I"
		KEY_J:
			return "J"
		KEY_K:
			return "K"
		KEY_L:
			return "L"
		KEY_M:
			return "M"
		KEY_N:
			return "N"
		KEY_O:
			return "O"
		KEY_P:
			return "P"
		KEY_Q:
			return "Q"
		KEY_R:
			return "R"
		KEY_S:
			return "S"
		KEY_T:
			return "T"
		KEY_U:
			return "U"
		KEY_V:
			return "V"
		KEY_W:
			return "W"
		KEY_X:
			return "X"
		KEY_Y:
			return "Y"
		KEY_Z:
			return "Z"
		KEY_COMMA:
			return ","
		KEY_PERIOD:
			return "."
		KEY_SLASH:
			return "/"
		KEY_EQUAL:
			return "="
		KEY_PLUS:
			return "+"
		KEY_MINUS:
			return "-"
		KEY_F1:
			return "F1"
		KEY_F2:
			return "F2"
		KEY_F3:
			return "F3"
		KEY_F4:
			return "F4"
		KEY_F5:
			return "F5"
		KEY_F6:
			return "F6"
		KEY_F7:
			return "F7"
		KEY_F8:
			return "F8"
		KEY_F9:
			return "F9"
		KEY_F10:
			return "F10"
		KEY_F11:
			return "F11"
		KEY_F12:
			return "F12"
		KEY_F13:
			return "F13"
		KEY_F14:
			return "F14"
		KEY_F15:
			return "F15"
		KEY_F16:
			return "F16"
		KEY_SPACE:
			return "Space"
		KEY_SEMICOLON:
			return ";"
		KEY_COLON:
			return ":"
		KEY_LESS:
			return "<"
		KEY_GREATER:
			return ">"
		KEY_BRACKETLEFT:
			return "["
		KEY_BRACKETRIGHT:
			return "]"
		KEY_APOSTROPHE:
			return "'"
		KEY_BACKSLASH:
			return "\\"
		KEY_SLASH:
			return "/"
		KEY_ASCIITILDE:
			return "~"
		KEY_KP_DIVIDE:
			return "KP /"
		KEY_KP_PERIOD:
			return "KP ."
		_:
			return "Key " + str(scancode)


func _apply_bindings() -> void:
	var actions: Array = InputMap.get_actions()
	for action in actions:
		if action in default_bindings:
			InputMap.erase_action(action)

	for action_name in default_bindings:
		var binding: Dictionary = default_bindings[action_name]
		var user_override: Dictionary = {}
		if user_bindings.has(action_name):
			user_override = user_bindings[action_name]

		var effective: Dictionary = binding.duplicate()
		for key in user_override:
			effective[key] = user_override[key]

		_input_add_action_input(action_name, effective)


func _input_add_action_input(action_name: String, binding: Dictionary) -> void:
	var input_event: InputEvent = _create_input_event(binding)
	if input_event == null:
		return

	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_add_event(action_name, input_event)


func _create_input_event(binding: Dictionary) -> InputEvent:
	if not binding or binding.size() == 0:
		return null

	var scancode: int = binding.get("scancode", 0)

	if scancode == BUTTON_WHEEL_UP or scancode == BUTTON_WHEEL_DOWN or \
	   scancode == BUTTON_LEFT or scancode == BUTTON_RIGHT or \
	   scancode == BUTTON_MIDDLE or (scancode >= BUTTON_LEFT and scancode <= BUTTON_XBUTTON2):
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = scancode
		event.control = binding.get("ctrl", false)
		event.shift = binding.get("shift", false)
		event.alt = binding.get("alt", false)
		event.meta = binding.get("meta", false)
		return event

	if scancode >= KEY_SPACE and scancode <= KEY_Z:
		var event: InputEventKey = InputEventKey.new()
		event.scancode = scancode
		event.pressed = true
		event.control = binding.get("ctrl", false)
		event.shift = binding.get("shift", false)
		event.alt = binding.get("alt", false)
		event.meta = binding.get("meta", false)
		return event

	return null


func set_context(context: String) -> void:
	current_context = context


func get_profile_names() -> Array:
	var names: Array = ["Default"]
	for name in profiles:
		if not names.has(name):
			names.append(name)
	return names


func has_profile(name: String) -> bool:
	return profiles.has(name) or name == "Default"


func get_all_user_bindings() -> Dictionary:
	return user_bindings.duplicate()


func set_all_user_bindings(bindings: Dictionary) -> void:
	user_bindings = bindings.duplicate()
	_apply_bindings()
	emit_signal("hotkeys_reloaded")
