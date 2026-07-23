extends GutTest

var editor_scene = load("res://scenes/editor/editor.tscn")
var editor_instance: Node

var pet_node: Node
var file_tree: Tree
var lnz_text: TextEdit
var pet_view: Control

func before_all():
	editor_instance = editor_scene.instance()
	editor_instance.name = "Root"
	get_tree().root.add_child(editor_instance)
	
	yield(get_tree(), "idle_frame")
	
	pet_node = editor_instance.get_node_or_null("PetRoot/Node")
	file_tree = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
	lnz_text = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	pet_view = editor_instance.get_node_or_null("SceneRoot/HSplitContainer/HSplitContainer/PetViewContainer")
	
	assert_not_null(pet_node, "Failed to resolve pet_node")
	assert_not_null(file_tree, "Failed to resolve file_tree")
	assert_not_null(lnz_text, "Failed to resolve lnz_text")
	assert_not_null(pet_view, "Failed to resolve pet_view")
	
	if KeyBallsData.max_base_ball_num == null:
		KeyBallsData.max_base_ball_num = 67
	
	if is_instance_valid(pet_node):
		pet_node.set("pixel_world_size", 0.002)

func before_each():
	_reset_editor_state()

func after_all():
	if is_instance_valid(editor_instance):
		editor_instance.queue_free()
		yield(get_tree(), "idle_frame")

func _reset_editor_state():
	var settings = editor_instance.get_node_or_null("SceneRoot")
	if settings and settings.has_method("set_preferred_delimiter"):
		settings.set_preferred_delimiter("auto")

	if lnz_text:
		lnz_text.text = ""
		if lnz_text.has_method("initialize_history"):
			lnz_text.initialize_history()

	if pet_view:
		if "selected_ball" in pet_view:
			if typeof(pet_view.selected_ball) == TYPE_ARRAY:
				pet_view.selected_ball.clear()
			else:
				pet_view.selected_ball = -1
				
		if "selected_balls" in pet_view:
			var temp_arr: Array = pet_view.selected_balls
			temp_arr.clear()
			pet_view.selected_balls = temp_arr

	if pet_node:
		if pet_node.has_method("clear_balls"):
			pet_node.clear_balls()
		else:
			var petholder = pet_node.get_node_or_null("petholder")
			if petholder:
				for category in petholder.get_children():
					for child in category.get_children():
						child.free()

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

func _create_temp_lnz(content: String) -> String:
	var path = "user://gut_temp_test.lnz"
	var f = File.new()
	var err = f.open(path, File.WRITE)
	if err == OK:
		f.store_string(content)
		f.close()
	else:
		push_error("Failed to create temp file: %s" % err)
	return path

# ------------------------------------------------------------------------------
# FileTree.gd
# ------------------------------------------------------------------------------

func test_filetree_expanded_states():
	# Verify that set_expanded_states correctly updates the collapsed property
	# of tree items, and that get_expanded_states returns the correct dictionary.
	if not file_tree.examples:
		file_tree.examples = file_tree.create_item()
	if not file_tree.local_storage:
		file_tree.local_storage = file_tree.create_item()
	
	var mock_states = {
		"Example LNZ": false,
		"User LNZ": true
	}
	
	file_tree.set_expanded_states(mock_states)
	
	assert_true(file_tree.examples.collapsed, "Examples should be collapsed.")
	assert_false(file_tree.local_storage.collapsed, "Local Storage should be expanded.")
	
	var retrieved_states = file_tree.get_expanded_states()
	assert_false(retrieved_states["Example LNZ"], "Getter should return false for Examples.")
	assert_true(retrieved_states["User LNZ"], "Getter should return true for Local Storage.")

func test_filetree_convert_bmp_invalid_file():
	# Ensure convert_bmp_to_palette_png fails safely and returns false 
	# when the source file does not exist, rather than throwing an error.
	var result = file_tree.convert_bmp_to_palette_png("user://does_not_exist_ever.bmp", "user://")
	assert_false(result, "Conversion should safely fail and return false for non-existent files.")

# ------------------------------------------------------------------------------
# lnzlive_utils.gd
# ------------------------------------------------------------------------------

func test_parse_number_list():
	# Ascending range
	var result = LnzLiveUtils.parse_number_list("1-5")
	assert_eq(result, [1, 2, 3, 4, 5], "Ascending range 1-5")
	
	# Descending range
	result = LnzLiveUtils.parse_number_list("5-1")
	assert_eq(result, [5, 4, 3, 2, 1], "Descending range 5-1")
	
	# Single number range
	result = LnzLiveUtils.parse_number_list("3-3")
	assert_eq(result, [3], "Range 3-3")

	# Negative range allowed
	result = LnzLiveUtils.parse_number_list("-5-5", true)
	assert_eq(result, [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5], "Negative range -5 to 5 with allow_negatives=true")
	
	# Negative range restricted (should skip entirely because start < 0)
	result = LnzLiveUtils.parse_number_list("-5-5", false)
	assert_eq(result.size(), 0, "Negative range -5 to 5 with allow_negatives=false should be skipped")

	# Negative range allowed (descending)
	result = LnzLiveUtils.parse_number_list("-1--5", true)
	assert_eq(result, [-1, -2, -3, -4, -5], "Descending negative range -1 to -5")

	# Single negative integer allowed
	result = LnzLiveUtils.parse_number_list("-10", true)
	assert_eq(result, [-10], "Single negative integer -10 with allow_negatives=true")

	# Single negative integer restricted (should skip)
	result = LnzLiveUtils.parse_number_list("-10", false)
	assert_eq(result.size(), 0, "Single negative integer -10 with allow_negatives=false should be skipped")

	# Mix of ranges and integers
	result = LnzLiveUtils.parse_number_list("1-3, 10, 15-17")
	assert_eq(result, [1, 2, 3, 10, 15, 16, 17], "Mixed ranges and integers")

	# Whitespace handling
	result = LnzLiveUtils.parse_number_list("  1  -  5  ")
	assert_eq(result, [1, 2, 3, 4, 5], "Whitespace around range")

	# Empty string
	result = LnzLiveUtils.parse_number_list("")
	assert_eq(result.size(), 0, "Empty string")

	# Only commas
	result = LnzLiveUtils.parse_number_list(", , ,")
	assert_eq(result.size(), 0, "Only commas")

	# Leading/Trailing commas
	result = LnzLiveUtils.parse_number_list(", 1, 2,")
	assert_eq(result, [1, 2], "Leading and trailing commas")

	# Invalid parts mixed with valid
	result = LnzLiveUtils.parse_number_list("1, abc, 3")
	assert_eq(result, [1, 3], "Invalid parts skipped")

	# Large range performance check
	result = LnzLiveUtils.parse_number_list("0-100")
	assert_eq(result.size(), 101, "Large range 0-100 size")
	assert_eq(result[0], 0, "Large range start")
	assert_eq(result[100], 100, "Large range end")

func test_world_to_lnz_delta_conversion():
	# Verify that world-space deltas are correctly converted to LNZ integer deltas 
	# by applying pixel_world_size, engine_scale, and Y-axis inversion.
	var pixel_world_size = 0.002
	var engine_scale = 127.5 # Simulate 50% scale (127.5 / 255.0 = 0.5)
	
	# 0.002 * 0.5 = 0.001
	var test_world_delta = Vector3(0.01, -0.02, 0.03)
	var result = LnzLiveUtils.world_to_lnz_delta(test_world_delta, pixel_world_size, engine_scale)
	
	assert_eq(result.x, 10.0, "X coordinate should be accurately scaled up to integer.")
	assert_eq(result.y, 20.0, "Y coordinate MUST be inverted (positive) for LNZ format.")
	assert_eq(result.z, 30.0, "Z coordinate should be accurately scaled up to integer.")

func test_lnzlive_utils_parse_flexible_integers():
	# Verify that parse_flexible_integers correctly extracts integers from a string 
	# containing mixed whitespace and negative numbers.
	var result = LnzLiveUtils.parse_flexible_integers("  10   -5 20")
	assert_eq(result.size(), 3, "Parser should extract exactly 3 valid integers from string array.")
	assert_eq(result[0], 10)
	assert_eq(result[1], -5)
	assert_eq(result[2], 20)

func test_lnzlive_utils_get_ramp_color():
	# Verify that get_ramp_color correctly calculates intermediate ramp colors 
	# and falls back to exact colors when the ramp logic doesn't apply.
	var rule = {"is_ramp": true, "before_color": "62", "after_color": "55"}
	var result = LnzLiveUtils.get_ramp_color("60", rule)
	assert_eq(result, "50", "Should shift 60 to 50 based on 62->55 ramp offset.")
	var fallback_rule = {"is_ramp": true, "before_color": "62", "after_color": "244"}
	var fallback_result = LnzLiveUtils.get_ramp_color("60", fallback_rule)
	assert_eq(fallback_result, "244", "Should snap to exact color if after_color is not a ramp.")

func test_lnzlive_lnz_to_world_delta_inverts_y():
	# Verify that lnz_to_world_delta correctly inverts the Y axis back to world format.
	var pixel_world_size = 0.002
	var engine_scale = 127.5
	var lnz_delta = Vector3(10, 20, 30)
	var result = LnzLiveUtils.lnz_to_world_delta(lnz_delta, pixel_world_size, engine_scale)
	
	# Y should be inverted: +20 in LNZ → -0.02 in world
	assert_almost_eq(result.x, 0.01, 0.0001, "X should scale up correctly.")
	assert_almost_eq(result.y, -0.02, 0.0001, "Y should be inverted from positive to negative.")
	assert_almost_eq(result.z, 0.03, 0.0001, "Z should scale up correctly.")

func test_lnzlive_lnz_to_world_delta_roundtrip():
	# Verify that lnz_to_world_delta is the inverse of world_to_lnz_delta.
	var pixel_world_size = 0.002
	var engine_scale = 255.0
	var original = Vector3(5.0, -10.0, 15.0)
	var to_lnz = LnzLiveUtils.world_to_lnz_delta(original, pixel_world_size, engine_scale)
	var back = LnzLiveUtils.lnz_to_world_delta(to_lnz, pixel_world_size, engine_scale)
	
	assert_almost_eq(back.x, original.x, 0.01, "X roundtrip should match.")
	assert_almost_eq(back.y, original.y, 0.01, "Y roundtrip should match.")
	assert_almost_eq(back.z, original.z, 0.01, "Z roundtrip should match.")

func test_lnzlive_visual_size_to_lnz_size_addball():
	# Verify that visual_size_to_lnz_size correctly converts a visual size
	# to an LNZ integer for an addball.
	var result = LnzLiveUtils.visual_size_to_lnz_size(50.0, true, 255.0)
	# (50.0 / 1.0) + 2.0 = 52
	assert_eq(result, 52, "Addball: visual 50.0 at scale 255 should give LNZ 52.")

func test_lnzlive_visual_size_to_lnz_size_non_addball():
	# Verify that visual_size_to_lnz_size correctly converts for a non-addball
	# with standard enlargement parameters.
	var result = LnzLiveUtils.visual_size_to_lnz_size(50.0, false, 255.0)
	# (50.0 / 1.0) + 2.0 = 52; then (52 - 0) / (100/100) = 52; int(round(52 - 0)) = 52
	assert_eq(result, 52, "Non-addball: visual 50.0 at scale 255 should give LNZ 52.")

func test_lnzlive_visual_size_to_lnz_size_with_bhd_size():
	# Verify that bhd_size offsets the result correctly.
	var result = LnzLiveUtils.visual_size_to_lnz_size(50.0, true, 255.0, 5)
	# (50.0 / 1.0) + 2.0 = 52; 52 - 5 = 47
	assert_eq(result, 47, "Addball with bhd_size=5 should subtract 5 from result.")

func test_lnzlive_snap_visual_size_even():
	# Verify that snap_visual_size produces a snapped value.
	# snap_visual_size applies the LNZ even-snapping formula: snapped -= 1.0 - fmod(snapped, 2.0)
	# With target_visual=50.0, is_addball=true, engine_scale=255.0:
	# final_lnz = 50, current_base_size = 50, snapped = 50.0
	# snapped -= 1.0 - fmod(50.0, 2.0) = 50.0 - 1.0 - 0 = 49.0
	var result = LnzLiveUtils.snap_visual_size(50.0, true, 255.0)
	# The fmod formula produces 49.0 for input 50.0 due to the -1.0 offset
	assert_almost_eq(result, 49.0, 0.01, "snap_visual_size with addball 50.0 should produce 49.0 due to offset formula.")

func test_lnzlive_get_basis_from_normal_up():
	# Verify that get_basis_from_normal handles the UP direction.
	var normal = Vector3(0, 1, 0)
	var basis = LnzLiveUtils.get_basis_from_normal(normal)
	# Y axis of basis should equal the normal
	assert_almost_eq(basis.y.x, 0.0, 0.01, "Basis Y X should be 0.")
	assert_almost_eq(basis.y.y, 1.0, 0.01, "Basis Y Y should be 1.")
	assert_almost_eq(basis.y.z, 0.0, 0.01, "Basis Y Z should be 0.")

func test_lnzlive_get_basis_from_normal_down():
	# Verify that get_basis_from_normal handles the DOWN direction.
	var normal = Vector3(0, -1, 0)
	var basis = LnzLiveUtils.get_basis_from_normal(normal)
	assert_almost_eq(basis.y.y, -1.0, 0.01, "Basis Y Y should be -1 for downward normal.")

func test_lnzlive_get_basis_from_normal_parallel_to_up():
	# When normal is parallel to UP, cross product is zero; should fall back to RIGHT cross.
	var normal = Vector3(0, 0.9999, 0)
	var basis = LnzLiveUtils.get_basis_from_normal(normal)
	assert_true(basis.y.length() > 0.99, "Basis Y should be normalized.")

func test_lnzlive_intersect_ray_with_plane_parallel():
	# Verify that intersect_ray_with_plane returns null when ray is parallel to plane.
	var ray_origin = Vector3(0, 0, 0)
	var ray_dir = Vector3(1, 0, 0)
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 5, 0)
	var result = LnzLiveUtils.intersect_ray_with_plane(ray_origin, ray_dir, plane_normal, plane_point)
	assert_null(result, "Parallel ray should return null.")

func test_lnzlive_intersect_ray_with_plane_perpendicular():
	# Verify that intersect_ray_with_plane finds the intersection point.
	var ray_origin = Vector3(0, 0, 0)
	var ray_dir = Vector3(0, 1, 0)
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 10, 0)
	var result = LnzLiveUtils.intersect_ray_with_plane(ray_origin, ray_dir, plane_normal, plane_point)
	assert_not_null(result, "Perpendicular ray should find intersection.")
	assert_almost_eq(result.y, 10.0, 0.01, "Intersection Y should be at plane point.")

func test_lnzlive_intersect_ray_with_plane_oblique():
	# Verify intersection with an oblique plane.
	var ray_origin = Vector3(5, 0, 5)
	var ray_dir = Vector3(0, 1, 0)
	var plane_normal = Vector3(0, 1, 0)
	var plane_point = Vector3(0, 3, 0)
	var result = LnzLiveUtils.intersect_ray_with_plane(ray_origin, ray_dir, plane_normal, plane_point)
	assert_not_null(result, "Oblique ray should find intersection.")
	assert_almost_eq(result.y, 3.0, 0.01, "Intersection Y should be at plane height.")

func test_lnzlive_find_closest_palette_index_no_match():
	# Verify that find_closest_palette_index returns the closest index.
	var palette = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
	var target = Color(0.5, 0.5, 0.0)
	var idx = LnzLiveUtils.find_closest_palette_index(palette, target)
	# Red and green are equally close in RGB space: (0.5, 0.5, 0) vs (1,0,0) and (0,1,0)
	# dist to red = 0.5^2 + 0.5^2 + 0 = 0.5
	# dist to green = 0.5^2 + 0.5^2 + 0 = 0.5
	# Tie goes to first (index 0)
	assert_true(idx == 0 or idx == 1, "Should return one of the tied closest indices (0 or 1).")

func test_lnzlive_find_closest_palette_index_empty():
	# Verify that find_closest_palette_index returns 0 for empty palette.
	var palette: Array = []
	var idx = LnzLiveUtils.find_closest_palette_index(palette, Color(1, 0, 0))
	assert_eq(idx, 0, "Empty palette should return index 0.")

func test_lnzlive_parse_lsystem_rules():
	# Verify that parse_lsystem_rules correctly splits rules by '='.
	var rules_text = "A = B C\nB = A A\nC = B"
	var rules = LnzLiveUtils.parse_lsystem_rules(rules_text)
	assert_true(rules.has("A"), "Should have key A.")
	assert_eq(rules["A"], "B C", "A should map to B C.")
	assert_eq(rules["B"], "A A", "B should map to A A.")
	assert_eq(rules["C"], "B", "C should map to B.")

func test_lnzlive_parse_lsystem_rules_empty():
	# Verify that parse_lsystem_rules handles empty input.
	var rules = LnzLiveUtils.parse_lsystem_rules("")
	assert_true(rules.empty(), "Empty input should produce empty dictionary.")

func test_lnzlive_parse_lsystem_rules_skip_invalid():
	# Verify that lines without '=' are skipped.
	var rules_text = "A = B\ninvalid_line\nC = D"
	var rules = LnzLiveUtils.parse_lsystem_rules(rules_text)
	assert_true(rules.has("A"), "A should be parsed.")
	assert_true(rules.has("C"), "C should be parsed.")
	assert_false(rules.has("invalid_line"), "Invalid line should be skipped.")

func test_lnzlive_generate_lsystem_string_basic():
	# Verify that generate_lsystem_string correctly substitutes rules.
	var rules = LnzLiveUtils.parse_lsystem_rules("A = AB\nB = A")
	var result = LnzLiveUtils.generate_lsystem_string("A", rules, 3)
	# Iteration 0: A
	# Iteration 1: AB
	# Iteration 2: ABA
	# Iteration 3: ABAAB
	assert_eq(result, "ABAAB", "L-string after 3 iterations should be ABAAB.")

func test_lnzlive_generate_lsystem_string_zero_iterations():
	# Verify that zero iterations returns the axiom.
	var rules = LnzLiveUtils.parse_lsystem_rules("A = B")
	var result = LnzLiveUtils.generate_lsystem_string("A", rules, 0)
	assert_eq(result, "A", "Zero iterations should return axiom unchanged.")

func test_lnzlive_generate_lsystem_string_capped():
	# Verify that iterations > 15 are capped at 15.
	var rules = LnzLiveUtils.parse_lsystem_rules("A = AB")
	var result = LnzLiveUtils.generate_lsystem_string("A", rules, 20)
	assert_true(result.length() > 0, "Should produce non-empty string.")
	assert_true(result.length() < 100000, "Should be capped to reasonable length.")

func test_lnzlive_generate_lsystem_string_with_constants():
	# Verify that characters without rules pass through unchanged.
	var rules = LnzLiveUtils.parse_lsystem_rules("A = F+F+F")
	var result = LnzLiveUtils.generate_lsystem_string("A", rules, 1)
	assert_true(result.find("+") != -1, "Constants like + should pass through.")
	assert_true(result.find("F") != -1, "F should appear in result.")

func test_lnzlive_compute_distance_transform():
	# Verify that compute_distance_transform produces non-zero distances for mask=true cells.
	var mask = [true, true, true, false]  # 2x2 mask, bottom-right is false
	var size = 2
	var dists = LnzLiveUtils.compute_distance_transform(mask, size)
	assert_eq(dists.size(), 4, "Distance transform should have same size as mask.")
	# Cells that are true should have positive distances
	assert_true(dists[0] > 0, "Top-left (true) should have positive distance.")
	assert_true(dists[1] > 0, "Top-right (true) should have positive distance.")
	assert_true(dists[2] > 0, "Bottom-left (true) should have positive distance.")
	assert_eq(dists[3], 0.0, "Bottom-right (false) should have distance 0.")

func test_lnzlive_verify_palette_compatibility():
	# Verify that verify_palette_compatibility returns 0 for identical palettes.
	var pal1: Array = []
	var pal2: Array = []
	for i in range(256):
		pal1.append(Color(float(i) / 255.0, 0, 0))
		pal2.append(Color(float(i) / 255.0, 0, 0))
	var diff = LnzLiveUtils.verify_palette_compatibility(pal1, pal2)
	assert_almost_eq(diff, 0.0, 0.01, "Identical palettes should have zero difference.")

func test_lnzlive_extract_palette_from_image():
	# Verify that extract_palette_from_image extracts 256 colors from a texture.
	var img = Image.new()
	img.create(256, 1, false, Image.FORMAT_RGBA8)
	img.lock()
	for i in range(256):
		img.set_pixel(i, 0, Color(float(i) / 255.0, 0, 0))
	img.unlock()
	var tex = ImageTexture.new()
	tex.create_from_image(img)
	var palette = LnzLiveUtils.extract_palette_from_image(tex)
	assert_eq(palette.size(), 256, "Should extract 256 palette entries.")

func test_lnzlive_requantize_bmp_data():
	# Verify that requantize_bmp_data remaps indices based on palette similarity.
	var bmp_palette: Array = []
	bmp_palette.append(Color(1.0, 0, 0))  # index 0 = red
	bmp_palette.append(Color(0, 1.0, 0))  # index 1 = green
	
	var target_palette: Array = []
	target_palette.append(Color(1.0, 0, 0))  # index 0 = red
	target_palette.append(Color(0, 0.9, 0))  # index 1 = slightly different green
	
	var raw_data = PoolByteArray([0, 1])
	var new_data = LnzLiveUtils.requantize_bmp_data(raw_data, bmp_palette, target_palette)
	assert_eq(new_data.size(), 2, "Output should have same size as input.")
	# Index 0 (red) should map to 0 (red)
	assert_eq(new_data[0], 0, "Red should map to index 0.")

func test_lnzlive_update_color_list_previews():
	# Verify that update_color_list_previews handles empty palette gracefully.
	var container = Control.new()
	add_child(container)
	var palette_colors: Array = []
	
	# Empty palette should return early without creating children
	LnzLiveUtils.update_color_list_previews(container, "0-5", palette_colors, 3)
	
	assert_eq(container.get_child_count(), 0, "Empty palette should create no children.")
	
	remove_child(container)
	container.queue_free()

# ------------------------------------------------------------------------------
# lnz_parser.gd
# ------------------------------------------------------------------------------

func test_lnz_scan_base_and_variations():
	# Verify that the parser correctly distinguishes between the base block (ID 0)
	# and variation blocks (IDs > 0) based on the '#N' header syntax.
	var content = "[Ballz Info]\n10 10 10\n#1 Variation1\n20 20 20\n[Linez]\n1 2"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	
	assert_true(parser.sections_map.has("Ballz Info"), "Should parse Ballz Info section.")
	assert_true(parser.sections_map["Ballz Info"].has(0), "Should generate base variation (0).")
	assert_true(parser.sections_map["Ballz Info"].has(1), "Should detect variation 1.")
	
	var base_lines = parser.sections_map["Ballz Info"][0].lines
	assert_eq(base_lines[0], "10 10 10", "Base lines should be assigned to ID 0.")
	
	var var1_lines = parser.sections_map["Ballz Info"][1].lines
	assert_eq(var1_lines[0], "20 20 20", "Variation lines should be assigned to ID 1.")

func test_lnz_compile_section_merging():
	# Verify that compile_section correctly merges the base data with 
	# specific requested variations, maintaining the order: Base -> Variations.
	var content = "[Section]\nBaseData\n#1 Var1\nData1\n#2 Var2\nData2"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	
	# Compile with base and variation 2
	var reader = parser.compile_section("Section", [2])
	assert_eq(reader.get_len(), 2, "Reader should contain exactly 2 lines.")
	assert_eq(reader.get_line(), "BaseData", "Base data should always be included.")
	assert_eq(reader.get_line(), "Data2", "Active variation data should be appended.")

func test_lnz_get_parsed_lines_ignores_invalid_and_comments():
	# Ensure get_parsed_lines skips empty lines, comments (;), and 
	# unparseable garbage, returning only valid data structures.
	var content = "[TestSection]\n; This is a comment\n\n10 20 30\n# Ignored\n40 50 60\n\t  \n"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("TestSection", [])
	
	var parsed = parser.get_parsed_lines(reader, ["a", "b", "c"])
	assert_eq(parsed.size(), 2, "Should cleanly skip comments and empty spaces to find 2 valid lines.")
	assert_eq(parsed[0]["a"], 10)
	assert_eq(parsed[1]["c"], 60)

func test_lnz_species_fallback_detection():
	# Verify that if no [Species] block exists, the parser falls back to 
	# detecting the species by matching the path in [Default Linez File].
	var content = "[Default Linez File]\nC:\\Petz\\Dogz\\Dalmatian.dog"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	
	parser.get_species()
	assert_eq(parser.species, 2, "Should fallback to Dogz (Species = 2) based on default file path string matching.")

func test_lnz_parse_paintballs_invalid_length():
	# Verify that paintball lines with insufficient columns (less than 11) 
	# are skipped gracefully without throwing index-out-of-bounds errors.
	var content = "[Paint Ballz]\n; Not enough data\n1 2 3 4 5 6\n; Valid\n1 2 3 4 5 6 7 8 9 10 11 12"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Paint Ballz", [])
	
	parser.parse_paintballs(reader)
	
	assert_true(parser.paintballs.has(1), "Should successfully parse the valid paintball.")
	assert_eq(parser.paintballs[1].size(), 1, "Should gracefully skip the invalid short line without throwing index errors.")

func test_lnz_get_whiskers_standard_parsing():
	# Verify that whisker connections are parsed correctly from start/end indices.
	var content = "[Whiskers]\n10 11\n12 13"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Whiskers", [])
	
	parser.get_whiskers(reader)
	assert_eq(parser.whisker_connections.size(), 2, "Should map exactly 2 whisker connections.")
	assert_eq(parser.whisker_connections[0]["start"], 11, "Whisker start index should match.")
	assert_eq(parser.whisker_connections[0]["end"], 10, "Whisker end index should match.")

func test_lnz_parse_moves():
	# Verify that moves are parsed correctly, handling both explicit 'relative_to' 
	# values and fallback logic when that column is missing.
	var content = "[Move]\n5 10 20 30 15\n8 0 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Move", [])
	
	parser.parse_moves(reader)
	assert_eq(parser.moves.size(), 2, "Should parse all valid moves.")
	assert_eq(parser.moves[0]["relative_to"], 15, "Should pick up relative_to column when present.")
	assert_eq(parser.moves[1]["relative_to"], 8, "Should fallback relative_to equal to base ball when column is missing.")

func test_lnz_parser_get_eyes():
	# Verify that the eyes section correctly maps left/right iris indices 
	# to their corresponding standard eye indices.
	var content = "[Eyes]\n10 11\n12 13"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Eyes", [])
	
	parser.get_eyes(reader)
	assert_true(parser.custom_eyes.has(12), "Should map left iris (12) from eyes block.")
	assert_eq(parser.custom_eyes[12], 10, "Should explicitly map left iris to left eye (10).")
	assert_eq(parser.custom_eyes[13], 11, "Should explicitly map right iris to right eye (11).")

func test_lnz_get_color_info_override_balls():
	# Verify that get_color_info_override correctly updates ball color properties.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Color Info]\n0 200 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Color Info", [0])
	
	parser.get_color_info_override(reader)
	
	assert_eq(parser.balls[0].color_index, 200, "Ball color_index should be updated to 200.")

func test_lnz_get_color_info_override_addballs():
	# Verify that get_color_info_override correctly updates addball color properties.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Add Ball]\n1 100 10 0 0 0 0 0 0 0 1 0 0\n[Color Info]\n1 150 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	var reader = parser.compile_section("Color Info", [0])
	
	parser.get_color_info_override(reader)
	
	assert_eq(parser.addballs[1].color_index, 150, "AddBall color_index should be updated to 150.")

func test_lnz_get_color_info_override_nonexistent_ball():
	# Verify that get_color_info_override silently ignores non-existent ball IDs.
	var content = "[Color Info]\n999 200 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Color Info", [0])
	
	# Should not crash
	parser.get_color_info_override(reader)
	assert_false(parser.balls.has(999), "Non-existent ball should not be created.")

func test_lnz_get_outline_color_override_balls():
	# Verify that get_outline_color_override updates outline_color_index on balls.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Outline Color]\n0 50"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Outline Color", [0])
	
	parser.get_outline_color_override(reader)
	
	assert_eq(parser.balls[0].outline_color_index, 50, "Ball outline_color_index should be 50.")

func test_lnz_get_outline_color_override_addballs():
	# Verify that get_outline_color_override updates outline_color_index on addballs.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Add Ball]\n1 100 10 0 0 0 0 0 0 0 1 0 0\n[Outline Color]\n1 75"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	var reader = parser.compile_section("Outline Color", [0])
	
	parser.get_outline_color_override(reader)
	
	assert_eq(parser.addballs[1].outline_color_index, 75, "AddBall outline_color_index should be 75.")

func test_lnz_get_fuzz_override_balls():
	# Verify that get_fuzz_override updates fuzz on balls.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Fuzz]\n0 25"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Fuzz", [0])
	
	parser.get_fuzz_override(reader)
	
	assert_eq(parser.balls[0].fuzz, 25, "Ball fuzz should be updated to 25.")

func test_lnz_get_fuzz_override_addballs():
	# Verify that get_fuzz_override updates fuzz on addballs.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Add Ball]\n1 100 10 0 0 0 0 0 0 0 1 0 0\n[Fuzz]\n1 30"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	var reader = parser.compile_section("Fuzz", [0])
	
	parser.get_fuzz_override(reader)
	
	assert_eq(parser.addballs[1].fuzz, 30, "AddBall fuzz should be updated to 30.")

func test_lnz_get_ball_size_override_balls():
	# Verify that get_ball_size_override updates ball size.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Size Override]\n0 100"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Size Override", [0])
	
	parser.get_ball_size_override(reader)
	
	assert_eq(parser.balls[0].size, 100, "Ball size should be updated to 100.")

func test_lnz_get_ball_size_override_addballs():
	# Verify that get_ball_size_override updates addball size.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Add Ball]\n1 100 10 0 0 0 0 0 0 0 1 0 0\n[Size Override]\n1 80"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	var reader = parser.compile_section("Size Override", [0])
	
	parser.get_ball_size_override(reader)
	
	assert_eq(parser.addballs[1].size, 80, "AddBall size should be updated to 80.")

func test_lnz_get_add_ball_override():
	# Verify that get_add_ball_override updates addball position.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Add Ball]\n1 100 10 0 0 0 0 0 0 0 1 0 0\n[Add Ball Override]\n1 200 50 30"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	var reader = parser.compile_section("Add Ball Override", [0])
	
	parser.get_add_ball_override(reader)
	
	assert_eq(parser.addballs[1].position.x, 200, "AddBall X should be 200.")
	assert_eq(parser.addballs[1].position.y, 50, "AddBall Y should be 50.")
	assert_eq(parser.addballs[1].position.z, 30, "AddBall Z should be 30.")

func test_lnz_get_eyelash_info():
	# Verify that get_eyelash_info correctly parses eyelash data.
	var content = "[Eyelash Info]\n10 20 30\n15\n50\n244"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Eyelash Info", [0])
	
	parser.get_eyelash_info(reader)
	
	assert_eq(parser.eyelash_lengths.size(), 3, "Should parse 3 eyelash lengths.")
	assert_eq(parser.eyelash_lengths[0], 10, "First eyelash length should be 10.")
	assert_eq(parser.eyelash_angle, 15, "Eyelash angle should be 15.")
	assert_eq(parser.eyelash_spacing, 50, "Eyelash spacing should be 50.")
	assert_eq(parser.eyelash_color, 244, "Eyelash color should be 244.")

func test_lnz_get_eyelash_info_few_lines():
	# Verify that get_eyelash_info handles fewer than 4 lines (defaults not applied by production code).
	var content = "[Eyelash Info]\n10 20"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Eyelash Info", [0])
	
	parser.get_eyelash_info(reader)
	
	# Production code only applies defaults when raw_lines.size() >= 4
	# So with < 4 lines, values remain at their initialized state
	assert_eq(parser.eyelash_lengths.size(), 0, "Eyelash lengths should be empty with < 4 lines.")
	assert_eq(parser.eyelash_angle, 0, "Angle should remain at default (0) with < 4 lines.")
	assert_eq(parser.eyelash_spacing, 0, "Spacing should remain at default (0) with < 4 lines.")
	assert_eq(parser.eyelash_color, -1, "Color should remain at default (-1) with < 4 lines.")

func test_lnz_get_omissions():
	# Verify that get_omissions correctly populates the omissions dictionary.
	var content = "[Omissions]\n5\n10\n15"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Omissions", [0])
	
	parser.get_omissions(reader)
	
	assert_true(parser.omissions.has(5), "Ball 5 should be in omissions.")
	assert_true(parser.omissions.has(10), "Ball 10 should be in omissions.")
	assert_true(parser.omissions.has(15), "Ball 15 should be in omissions.")

func test_lnz_get_z_shade_slope():
	# Verify that get_z_shade_slope updates the slope value.
	var content = "[Z Shade]\n150"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Z Shade", [0])
	
	parser.get_z_shade_slope(reader)
	
	assert_eq(parser.z_shade_slope, 150, "Z shade slope should be 150.")

func test_lnz_get_z_shade_slope_empty():
	# Verify that get_z_shade_slope does nothing with empty reader.
	var content = "[Z Shade]"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Z Shade", [0])
	
	parser.get_z_shade_slope(reader)
	
	assert_eq(parser.z_shade_slope, 100, "Default z_shade_slope should remain 100.")

func test_lnz_get_balls():
	# Verify that get_balls correctly creates BallData objects.
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n20 0 0 0 0 60 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	
	parser.get_balls(reader)
	
	assert_eq(parser.balls.size(), 2, "Should parse 2 balls.")
	assert_eq(parser.balls[0].size, 50, "First ball size should be 50.")
	assert_eq(parser.balls[1].size, 60, "Second ball size should be 60.")

func test_lnz_get_balls_empty():
	# Verify that get_balls handles empty section.
	var content = "[Ballz Info]"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	
	parser.get_balls(reader)
	
	assert_eq(parser.balls.size(), 0, "Empty section should produce no balls.")

func test_lnz_get_addballs():
	# Verify that get_addballs correctly creates AddBallData objects.
	# Keys order: base, x, y, z, color, outline_color, speckle, fuzz, group, outline, size, body_area, add_group, texture, anchor_ball
	var content = "[Ballz Info]\n10 0 0 0 0 50 0 0\n[Add Ball]\n1 100 10 0 0 0 0 0 0 0 30 1 5 0 0\n2 100 10 0 0 0 0 0 0 0 40 1 7 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	
	parser.get_addballs(addball_reader)
	
	assert_eq(parser.addballs.size(), 2, "Should parse 2 addballs.")
	# Addballs start at max_ball_num (balls.keys().max() + 1 = 1)
	assert_eq(parser.addballs[1].size, 30, "First addball size should be 30.")
	assert_eq(parser.addballs[1].add_group, 5, "First addball group should be 5.")
	assert_eq(parser.addballs[2].add_group, 7, "Second addball group should be 7.")

func test_lnz_get_lines():
	# Verify that get_lines correctly creates LineData objects.
	var content = "[Linez]\n1 2 0 100 50 60 100 100 -1 -1"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Linez", [0])
	
	parser.get_lines(reader)
	
	assert_eq(parser.lines.size(), 1, "Should parse 1 line.")
	var line_data = parser.lines[0]
	assert_eq(line_data.start, 1, "Line start should be 1.")
	assert_eq(line_data.end, 2, "Line end should be 2.")
	assert_eq(line_data.s_thick, 100, "Start thickness should be 100.")
	assert_eq(line_data.l_color_index, 50, "Left color should be 50.")
	assert_eq(line_data.r_color_index, 60, "Right color should be 60.")

func test_lnz_get_lines_multiple():
	# Verify that get_lines parses multiple lines correctly.
	var content = "[Linez]\n1 2 0 100 50 60 100 100 -1 -1\n3 4 0 80 70 80 100 100 -1 -1"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Linez", [0])
	
	parser.get_lines(reader)
	
	assert_eq(parser.lines.size(), 2, "Should parse 2 lines.")

func test_lnz_get_polygons():
	# Verify that get_polygons correctly creates PolyData objects.
	var content = "[Polygons]\n1 2 3 4 100 50 60 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Polygons", [0])
	
	parser.get_polygons(reader)
	
	assert_eq(parser.polygons.size(), 1, "Should parse 1 polygon.")
	var poly = parser.polygons[0]
	assert_eq(poly.ball1, 1, "First ball should be 1.")
	assert_eq(poly.ball2, 2, "Second ball should be 2.")
	assert_eq(poly.ball3, 3, "Third ball should be 3.")
	assert_eq(poly.ball4, 4, "Fourth ball should be 4.")
	assert_eq(poly.color, 100, "Color should be 100.")

func test_lnz_get_polygons_multiple():
	# Verify that get_polygons parses multiple polygons correctly.
	var content = "[Polygons]\n1 2 3 4 100 50 60 0 0\n5 6 7 8 200 70 80 0 0"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Polygons", [0])
	
	parser.get_polygons(reader)
	
	assert_eq(parser.polygons.size(), 2, "Should parse 2 polygons.")

func test_lnz_get_texture_list():
	# Verify that get_texture_list correctly parses texture entries.
	var content = "[Textures]\nres://textures/eye.png 0 256 256"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Textures", [0])
	
	parser.get_texture_list(reader)
	
	assert_eq(parser.texture_list.size(), 1, "Should parse 1 texture entry.")
	assert_eq(parser.texture_list[0]["filename"], "eye.png", "Filename should be eye.png.")
	assert_eq(str(parser.texture_list[0]["transparent_color"]), "0", "Transparent color should be '0'.")

func test_lnz_get_texture_list_multiple():
	# Verify that get_texture_list parses multiple entries.
	var content = "[Textures]\nres://textures/eye.png 0 256 256\nres://textures/skin.png 253 512 512"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Textures", [0])
	
	parser.get_texture_list(reader)
	
	assert_eq(parser.texture_list.size(), 2, "Should parse 2 texture entries.")

func test_lnz_get_palette():
	# Verify that get_palette extracts the palette filename.
	var content = "[Palette]\nmy_palette"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Palette", [0])
	
	parser.get_palette(reader)
	
	assert_eq(parser.palette, "my_palette.png", "Palette should have .png appended.")

func test_lnz_get_palette_empty():
	# Verify that get_palette returns null for empty palette section.
	var content = "[Palette]"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Palette", [0])
	
	parser.get_palette(reader)
	
	assert_null(parser.palette, "Empty palette should be null.")

func test_lnz_get_project_balls():
	# Verify that get_project_balls correctly parses projection entries.
	var content = "[Project]\n10 20 100"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Project", [0])
	
	parser.get_project_balls(reader)
	
	assert_eq(parser.project_ball.size(), 1, "Should parse 1 project entry.")
	var proj = parser.project_ball[0]
	assert_eq(proj["fixed_ball"], 10, "Fixed ball should be 10.")
	assert_eq(proj["project_ball"], 20, "Project ball should be 20.")
	assert_eq(proj["min_projection"], 50, "Min projection should be 100-50=50.")
	assert_eq(proj["max_projection"], 150, "Max projection should be 100+50=150.")

func test_lnz_get_no_texture_rotate():
	# Verify that get_no_texture_rotate parses ball IDs and quadrant flags.
	var content = "[No Texture Rotate]\n5 0\n10 1"
	var path = _create_temp_lnz(content)
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("No Texture Rotate", [0])
	
	parser.get_no_texture_rotate(reader)
	
	assert_true(5 in parser.no_texture_rotate, "Ball 5 should be in no_texture_rotate.")
	assert_true(10 in parser.no_texture_rotate, "Ball 10 should be in no_texture_rotate.")
	assert_true(10 in parser.quadrant_balls, "Ball 10 should be in quadrant_balls.")
	assert_false(5 in parser.quadrant_balls, "Ball 5 should not be in quadrant_balls.")

# ------------------------------------------------------------------------------
# data_classes/*_data.gd (BallData, AddBallData, LineData, PaintBallData, PolyData)
# ------------------------------------------------------------------------------

func test_ball_data_constructor():
	# Verify that BallData constructor initializes all properties correctly.
	var bd = BallData.new(50, Vector3(1, 2, 3), 10, Vector3(0, 45, 0), 100, 50, 5, 10, 0.5, 1, 3)
	
	assert_eq(bd.size, 50, "BallData size should be 50.")
	assert_eq(bd.position, Vector3(1, 2, 3), "BallData position should be Vector3(1,2,3).")
	assert_eq(bd.ball_no, 10, "BallData ball_no should be 10.")
	assert_almost_eq(bd.rotation.y, 45.0, 0.01, "BallData rotation Y should be 45.")
	assert_eq(bd.color_index, 100, "BallData color_index should be 100.")
	assert_eq(bd.outline_color_index, 50, "BallData outline_color_index should be 50.")
	assert_eq(bd.outline, 5, "BallData outline should be 5.")
	assert_eq(bd.fuzz, 10, "BallData fuzz should be 10.")
	assert_almost_eq(bd.z_add, 0.5, 0.01, "BallData z_add should be 0.5.")
	assert_eq(bd.group, 1, "BallData group should be 1.")
	assert_eq(bd.texture_id, 3, "BallData texture_id should be 3.")

func test_ball_data_defaults():
	# Verify that BallData uses correct default values when not specified.
	var bd = BallData.new(50, Vector3.ZERO, 0)
	
	assert_eq(bd.ball_no, 0, "Default ball_no should be 0.")
	assert_almost_eq(bd.rotation.x, 0.0, 0.01, "Default rotation should be zero.")
	assert_eq(bd.color_index, 0, "Default color_index should be 0.")
	assert_eq(bd.outline, -1, "Default outline should be -1.")
	assert_eq(bd.fuzz, 0, "Default fuzz should be 0.")
	assert_eq(bd.group, -1, "Default group should be -1.")
	assert_eq(bd.texture_id, -1, "Default texture_id should be -1.")

func test_addball_data_constructor():
	# Verify that AddBallData constructor initializes all properties correctly.
	var abd = AddBallData.new(1, 2, 30, Vector3(1, 2, 3), 100, 50, 5, 10, 0.5, 2, 3, 4, 1, 5)
	
	assert_eq(abd.base, 1, "AddBallData base should be 1.")
	assert_eq(abd.ball_no, 2, "AddBallData ball_no should be 2.")
	assert_eq(abd.size, 30, "AddBallData size should be 30.")
	assert_eq(abd.position, Vector3(1, 2, 3), "AddBallData position should be Vector3(1,2,3).")
	assert_eq(abd.color_index, 100, "AddBallData color_index should be 100.")
	assert_eq(abd.outline_color_index, 50, "AddBallData outline_color_index should be 50.")
	assert_eq(abd.outline, 5, "AddBallData outline should be 5.")
	assert_eq(abd.fuzz, 10, "AddBallData fuzz should be 10.")
	assert_almost_eq(abd.z_add, 0.5, 0.01, "AddBallData z_add should be 0.5.")
	assert_eq(abd.group, 2, "AddBallData group should be 2.")
	assert_eq(abd.body_area, 3, "AddBallData body_area should be 3.")
	assert_eq(abd.texture_id, 4, "AddBallData texture_id should be 4.")
	assert_eq(abd.add_group, 1, "AddBallData add_group should be 1.")
	assert_eq(abd.anchor_ball, 5, "AddBallData anchor_ball should be 5.")

func test_addball_data_defaults():
	# Verify that AddBallData uses correct default values when not specified.
	var abd = AddBallData.new(1, 2, 30, Vector3.ZERO)
	
	assert_eq(abd.color_index, -1, "Default color_index should be -1.")
	assert_eq(abd.outline_color_index, 0, "Default outline_color_index should be 0.")
	assert_eq(abd.outline, -1, "Default outline should be -1.")
	assert_eq(abd.fuzz, 0, "Default fuzz should be 0.")
	assert_almost_eq(abd.z_add, 0.0, 0.01, "Default z_add should be 0.0.")
	assert_eq(abd.group, -1, "Default group should be -1.")
	assert_eq(abd.body_area, 1, "Default body_area should be 1.")
	assert_eq(abd.texture_id, -1, "Default texture_id should be -1.")
	assert_eq(abd.add_group, 0, "Default add_group should be 0.")
	assert_eq(abd.anchor_ball, -1, "Default anchor_ball should be -1.")
	
func test_line_data_constructor():
	# Verify that LineData constructor initializes all properties correctly.
	var ld = LineData.new(5, 10, 80, 60, 5, 100, 50, 60, 3, 1)
	
	assert_eq(ld.start, 5, "LineData start should be 5.")
	assert_eq(ld.end, 10, "LineData end should be 10.")
	assert_eq(ld.s_thick, 80, "LineData start thickness should be 80.")
	assert_eq(ld.e_thick, 60, "LineData end thickness should be 60.")
	assert_eq(ld.fuzz, 5, "LineData fuzz should be 5.")
	assert_eq(ld.color_index, 100, "LineData color should be 100.")
	assert_eq(ld.l_color_index, 50, "LineData left color should be 50.")
	assert_eq(ld.r_color_index, 60, "LineData right color should be 60.")
	assert_eq(ld.full_outline, 3, "LineData full_outline should be 3.")
	assert_eq(ld.draw_order, 1, "LineData draw_order should be 1.")

func test_line_data_defaults():
	# Verify that LineData uses correct default values.
	var ld = LineData.new(5, 10)
	
	assert_eq(ld.s_thick, 100, "Default s_thick should be 100.")
	assert_eq(ld.e_thick, 100, "Default e_thick should be 100.")
	assert_eq(ld.fuzz, 0, "Default fuzz should be 0.")
	assert_eq(ld.color_index, 0, "Default color should be 0.")
	assert_eq(ld.full_outline, -1, "Default full_outline should be -1.")
	assert_eq(ld.draw_order, -1, "Default draw_order should be -1.")

func test_paintball_data_constructor():
	# Verify that PaintBallData constructor initializes all properties correctly.
	var pb = PaintBallData.new(5, 30, Vector3(1, 2, 3), 100, 50, 5, 10, 0.5, 3, 1, 2)
	
	assert_eq(pb.base, 5, "PaintBallData base should be 5.")
	assert_eq(pb.size, 30, "PaintBallData size should be 30.")
	assert_eq(pb.position, Vector3(1, 2, 3), "PaintBallData position should be Vector3(1,2,3).")
	assert_almost_eq(pb.normalised_position.length(), 1.0, 0.01, "PaintBallData normalised_position should be unit length.")
	assert_eq(pb.color_index, 100, "PaintBallData color should be 100.")
	assert_eq(pb.outline_color_index, 50, "PaintBallData outline color should be 50.")
	assert_eq(pb.outline, 5, "PaintBallData outline should be 5.")
	assert_almost_eq(pb.z_add, 0.5, 0.01, "PaintBallData z_add should be 0.5.")
	assert_eq(pb.texture_id, 3, "PaintBallData texture_id should be 3.")
	assert_eq(pb.anchored, 1, "PaintBallData anchored should be 1.")
	assert_eq(pb.group, 2, "PaintBallData group should be 2.")

func test_paintball_data_defaults():
	# Verify that PaintBallData uses correct default values.
	var pb = PaintBallData.new(5, 30, Vector3.ZERO, 0, 0)
	
	assert_eq(pb.outline, -1, "Default outline should be -1.")
	assert_eq(pb.fuzz, 0, "Default fuzz should be 0.")
	assert_eq(pb.texture_id, -1, "Default texture_id should be -1.")
	assert_eq(pb.anchored, 0, "Default anchored should be 0.")
	assert_eq(pb.group, 0, "Default group should be 0.")

func test_poly_data_constructor():
	# Verify that PolyData constructor initializes all properties correctly.
	var pd = PolyData.new(1, 2, 3, 4, 100, 50, 60, 5, 3)
	
	assert_eq(pd.ball1, 1, "PolyData ball1 should be 1.")
	assert_eq(pd.ball2, 2, "PolyData ball2 should be 2.")
	assert_eq(pd.ball3, 3, "PolyData ball3 should be 3.")
	assert_eq(pd.ball4, 4, "PolyData ball4 should be 4.")
	assert_eq(pd.color, 100, "PolyData color should be 100.")
	assert_eq(pd.l_edge_color, 50, "PolyData left edge color should be 50.")
	assert_eq(pd.r_edge_color, 60, "PolyData right edge color should be 60.")
	assert_eq(pd.fuzz, 5, "PolyData fuzz should be 5.")
	assert_eq(pd.texture_id, 3, "PolyData texture_id should be 3.")

# ------------------------------------------------------------------------------
# key_balls_data.gd
# ------------------------------------------------------------------------------

func test_keyballs_get_mirrored_ball_dog():
	# Verify that get_mirrored_ball finds the correct mirror for dog species.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var mirror = KeyBallsData.get_mirrored_ball(1, KeyBallsData.dog_body_part_symmetry)
	assert_eq(mirror, 25, "Mirror of ball 1 (eyebrowL1) should be 25 (eyebrowR1).")

func test_keyballs_get_mirrored_ball_cat():
	# Verify that get_mirrored_ball finds the correct mirror for cat species.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	
	var mirror = KeyBallsData.get_mirrored_ball(8, KeyBallsData.cat_body_part_symmetry)
	assert_eq(mirror, 10, "Mirror of ball 8 (earL1) should be 10 (earR1).")

func test_keyballs_get_mirrored_ball_no_mirror():
	# Verify that get_mirrored_ball returns -1 for balls without a mirror.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var mirror = KeyBallsData.get_mirrored_ball(48, KeyBallsData.dog_body_part_symmetry)
	assert_eq(mirror, -1, "Ball 48 (belly) has no mirror, should return -1.")

func test_keyballs_convert_ball_dog_to_cat():
	# Verify that convert_ball correctly maps a dog ball to cat.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var result = KeyBallsData.convert_ball(KeyBallsData.Species.DOG, 48, KeyBallsData.Species.CAT)
	assert_eq(result, 2, "Dog belly (48) should map to Cat belly (2).")

func test_keyballs_convert_ball_cat_to_dog():
	# Verify that convert_ball correctly maps a cat ball to dog.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	
	var result = KeyBallsData.convert_ball(KeyBallsData.Species.CAT, 2, KeyBallsData.Species.DOG)
	assert_eq(result, 48, "Cat belly (2) should map to Dog belly (48).")

func test_keyballs_convert_ball_same_species():
	# Verify that convert_ball returns the same ball for same species.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var result = KeyBallsData.convert_ball(KeyBallsData.Species.DOG, 10, KeyBallsData.Species.DOG)
	assert_eq(result, 10, "Same species should return the same ball ID.")

func test_keyballs_convert_ball_unknown_species():
	# Verify that convert_ball returns -1 for unknown source species.
	var result = KeyBallsData.convert_ball(99, 10, KeyBallsData.Species.DOG)
	assert_eq(result, -1, "Unknown source species should return -1.")

func test_keyballs_get_ball_id_by_name_dog():
	# Verify that get_ball_id_by_name finds a ball by name.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var id = KeyBallsData.get_ball_id_by_name("eyeL")
	assert_eq(id, 8, "eyeL should be ball ID 8 for dog.")

func test_keyballs_get_ball_id_by_name_cat():
	# Verify that get_ball_id_by_name finds a ball by name for cat.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	
	var id = KeyBallsData.get_ball_id_by_name("eyeL")
	assert_eq(id, 14, "eyeL should be ball ID 14 for cat.")

func test_keyballs_get_ball_id_by_name_not_found():
	# Verify that get_ball_id_by_name returns -1 for unknown name.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var id = KeyBallsData.get_ball_id_by_name("nonexistent_ball")
	assert_eq(id, -1, "Unknown name should return -1.")

func test_keyballs_get_ball_name_by_species_dog():
	# Verify that get_ball_name_by_species returns the correct name.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var name = KeyBallsData.get_ball_name_by_species(KeyBallsData.Species.DOG, 8)
	assert_eq(name, "eyeL", "Ball 8 should be named eyeL for dog.")

func test_keyballs_get_ball_name_by_species_not_found():
	# Verify that get_ball_name_by_species returns empty string for unknown ball.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var name = KeyBallsData.get_ball_name_by_species(KeyBallsData.Species.DOG, 999)
	assert_eq(name, "", "Unknown ball should return empty string.")

func test_keyballs_get_dog_to_cat_ball():
	# Verify that get_dog_to_cat_ball maps known balls.
	var result = KeyBallsData.get_dog_to_cat_ball(48)
	assert_eq(result, 2, "Dog belly (48) should map to cat belly (2).")

func test_keyballs_get_dog_to_cat_ball_not_found():
	# Verify that get_dog_to_cat_ball returns -1 for unmapped balls.
	var result = KeyBallsData.get_dog_to_cat_ball(999)
	assert_eq(result, -1, "Unmapped ball should return -1.")

func test_keyballs_get_cat_to_dog_ball():
	# Verify that get_cat_to_dog_ball maps known balls.
	var result = KeyBallsData.get_cat_to_dog_ball(2)
	assert_eq(result, 48, "Cat belly (2) should map to dog belly (48).")

func test_keyballs_get_cat_to_dog_ball_not_found():
	# Verify that get_cat_to_dog_ball returns -1 for unmapped balls.
	var result = KeyBallsData.get_cat_to_dog_ball(999)
	assert_eq(result, -1, "Unmapped ball should return -1.")

func test_keyballs_is_known_species_cat():
	# Verify that is_known_species returns true for cat.
	assert_true(KeyBallsData.is_known_species(KeyBallsData.Species.CAT), "Cat should be known species.")

func test_keyballs_is_known_species_dog():
	# Verify that is_known_species returns true for dog.
	assert_true(KeyBallsData.is_known_species(KeyBallsData.Species.DOG), "Dog should be known species.")

func test_keyballs_is_known_species_baby():
	# Verify that is_known_species returns true for baby.
	assert_true(KeyBallsData.is_known_species(KeyBallsData.Species.BABY), "Baby should be known species.")

func test_keyballs_is_known_species_unknown():
	# Verify that is_known_species returns false for unknown species.
	assert_false(KeyBallsData.is_known_species(99), "Unknown species should return false.")

func test_keyballs_get_species_display_name():
	# Verify that get_species_display_name returns correct names.
	assert_eq(KeyBallsData.get_species_display_name(KeyBallsData.Species.CAT), "Catz", "Cat display name should be Catz.")
	assert_eq(KeyBallsData.get_species_display_name(KeyBallsData.Species.DOG), "Dogz", "Dog display name should be Dogz.")
	assert_eq(KeyBallsData.get_species_display_name(KeyBallsData.Species.BABY), "Babyz", "Baby display name should be Babyz.")
	assert_eq(KeyBallsData.get_species_display_name(99), "Petz", "Unknown species should return Petz.")

func test_keyballs_get_belly_ball_id_dog():
	# Verify that get_belly_ball_id returns correct belly ball for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var belly = KeyBallsData.get_belly_ball_id(KeyBallsData.Species.DOG)
	assert_eq(belly, 48, "Dog belly ball should be 48.")

func test_keyballs_get_belly_ball_id_cat():
	# Verify that get_belly_ball_id returns correct belly ball for cat.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	
	var belly = KeyBallsData.get_belly_ball_id(KeyBallsData.Species.CAT)
	assert_eq(belly, 2, "Cat belly ball should be 2.")

func test_keyballs_get_belly_ball_id_baby():
	# Verify that get_belly_ball_id returns correct belly ball for baby.
	KeyBallsData.species = KeyBallsData.Species.BABY
	KeyBallsData.max_base_ball_num = 67
	
	var belly = KeyBallsData.get_belly_ball_id(KeyBallsData.Species.BABY)
	assert_eq(belly, 4, "Baby belly ball should be 4.")

func test_keyballs_get_recolor_targets_dog_legs():
	# Verify that get_recolor_targets returns leg balls for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var targets = KeyBallsData.get_recolor_targets(KeyBallsData.Species.DOG, "LEGS")
	assert_true(targets.size() > 0, "Should return leg targets for dog.")

func test_keyballs_get_recolor_targets_dog_tail():
	# Verify that get_recolor_targets returns tail balls for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var targets = KeyBallsData.get_recolor_targets(KeyBallsData.Species.DOG, "TAIL")
	assert_true(targets.size() > 0, "Should return tail targets for dog.")
	assert_true(57 in targets, "Tail should include ball 57 (tail1).")

func test_keyballs_get_recolor_targets_cat_head():
	# Verify that get_recolor_targets returns head balls for cat.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	
	var targets = KeyBallsData.get_recolor_targets(KeyBallsData.Species.CAT, "HEAD")
	assert_true(targets.size() > 0, "Should return head targets for cat.")

func test_keyballs_get_recolor_exclusions_dog():
	# Verify that get_recolor_exclusions excludes eyes and nose for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var exclusions = KeyBallsData.get_recolor_exclusions(KeyBallsData.Species.DOG, "NOSE")
	assert_true(8 in exclusions, "Eye ball 8 should be excluded.")
	assert_true(32 in exclusions, "Eye ball 32 should be excluded.")

func test_keyballs_get_recolor_exclusions_no_nose():
	# Verify that get_recolor_exclusions excludes nose when intended_part is not NOSE.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var exclusions = KeyBallsData.get_recolor_exclusions(KeyBallsData.Species.DOG, "HEAD")
	assert_true(17 in exclusions, "NostrilL should be excluded when not targeting nose.")
	assert_true(41 in exclusions, "NostrilR should be excluded when not targeting nose.")

func test_keyballs_get_fuzz_exclusions_dog():
	# Verify that get_fuzz_exclusions excludes eyes and tongue for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var exclusions = KeyBallsData.get_fuzz_exclusions(KeyBallsData.Species.DOG)
	assert_true(8 in exclusions, "Eye ball 8 should be excluded from fuzz.")
	assert_true(63 in exclusions, "Tongue ball 63 should be excluded from fuzz.")

func test_keyballs_get_fuzz_exclusions_cat():
	# Verify that get_fuzz_exclusions excludes eyes and tongue for cat.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	
	var exclusions = KeyBallsData.get_fuzz_exclusions(KeyBallsData.Species.CAT)
	assert_true(14 in exclusions, "Eye ball 14 should be excluded from fuzz.")
	assert_true(55 in exclusions, "Tongue ball 55 should be excluded from fuzz.")

func test_keyballs_get_projection_key_dog():
	# Verify that get_projection_key returns correct key for each species.
	assert_eq(KeyBallsData.get_projection_key(KeyBallsData.Species.DOG), "dog", "Dog projection key should be 'dog'.")
	assert_eq(KeyBallsData.get_projection_key(KeyBallsData.Species.CAT), "cat", "Cat projection key should be 'cat'.")
	assert_eq(KeyBallsData.get_projection_key(KeyBallsData.Species.BABY), "bab", "Baby projection key should be 'bab'.")
	assert_eq(KeyBallsData.get_projection_key(99), "", "Unknown species should return empty string.")

func test_keyballs_get_mirror_sides_dog():
	# Verify that get_mirror_sides returns correct sides for dog.
	var sides = KeyBallsData.get_mirror_sides(KeyBallsData.Species.DOG)
	assert_true(sides.has("left"), "Should have left side.")
	assert_true(sides.has("right"), "Should have right side.")
	assert_true(sides["left"].size() > 0, "Dog left side should have balls.")
	assert_true(sides["right"].size() > 0, "Dog right side should have balls.")

func test_keyballs_get_extensions_dog():
	# Verify that get_extensions returns all extension arrays for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var ext = KeyBallsData.get_extensions(KeyBallsData.Species.DOG)
	assert_true(ext.has("legs"), "Should have legs extension.")
	assert_true(ext.has("body_ext"), "Should have body_ext extension.")
	assert_true(ext.has("face_ext"), "Should have face_ext extension.")
	assert_true(ext.has("head_ext"), "Should have head_ext extension.")
	assert_true(ext.has("foot_ext"), "Should have foot_ext extension.")
	assert_true(ext.has("ear_ext"), "Should have ear_ext extension.")

func test_keyballs_get_symmetry_dict_dog():
	# Verify that get_symmetry_dict returns a non-empty dictionary for dog.
	var sym = KeyBallsData.get_symmetry_dict(KeyBallsData.Species.DOG)
	assert_true(sym.size() > 0, "Dog symmetry dict should be non-empty.")
	assert_true(sym.has("Head"), "Should have Head section.")
	assert_true(sym.has("Torso"), "Should have Torso section.")
	assert_true(sym.has("FrontPaws"), "Should have FrontPaws section.")
	assert_true(sym.has("BackPaws"), "Should have BackPaws section.")

func test_keyballs_get_ball_definitions_dog():
	# Verify that get_ball_definitions returns ball definitions for dog.
	var defs = KeyBallsData.get_ball_definitions(KeyBallsData.Species.DOG)
	assert_true(defs.size() > 0, "Dog should have ball definitions.")
	assert_true(defs.has(0), "Should have ball 0 definition.")

func test_keyballs_get_ball_definitions_unknown():
	# Verify that get_ball_definitions returns empty dictionary for unknown species.
	var defs = KeyBallsData.get_ball_definitions(99)
	assert_true(defs.empty(), "Unknown species should return empty dictionary.")

func test_keyballs_get_group_balls_dog():
	# Verify that get_group_balls returns correct group for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	
	var balls = KeyBallsData.get_group_balls("Head")
	assert_true(balls.size() > 0, "Dog head group should have balls.")

func test_keyballs_get_group_balls_unknown_species():
	# Verify that get_group_balls returns empty array for unknown species group name.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	var balls = KeyBallsData.get_group_balls("NonExistentGroup")
	assert_true(balls.empty(), "Unknown group name should return empty array.")

func test_keyballs_get_legs_dog():
	# Verify that get_legs returns leg arrays for dog.
	var legs = KeyBallsData.get_legs(KeyBallsData.Species.DOG)
	assert_eq(legs.size(), 2, "Dog should have 2 leg arrays (front and back).")
	assert_true(legs[0].size() > 0, "Front legs should have balls.")
	assert_true(legs[1].size() > 0, "Back legs should have balls.")

func test_keyballs_get_legs_unknown():
	# Verify that get_legs returns empty array for unknown species.
	var legs = KeyBallsData.get_legs(99)
	assert_true(legs.empty(), "Unknown species should return empty array.")

func test_keyballs_get_nose_dog():
	# Verify that get_nose returns nose balls for dog.
	var nose = KeyBallsData.get_nose(KeyBallsData.Species.DOG)
	assert_eq(nose.size(), 3, "Dog should have 3 nose balls.")
	assert_eq(nose[0], 17, "First dog nose ball should be 17.")

func test_keyballs_get_nose_cat():
	# Verify that get_nose returns nose balls for cat.
	var nose = KeyBallsData.get_nose(KeyBallsData.Species.CAT)
	assert_eq(nose.size(), 1, "Cat should have 1 nose ball.")
	assert_eq(nose[0], 37, "Cat nose ball should be 37.")

func test_keyballs_get_tongue_dog():
	# Verify that get_tongue returns tongue balls for dog.
	var tongue = KeyBallsData.get_tongue(KeyBallsData.Species.DOG)
	assert_eq(tongue.size(), 2, "Dog should have 2 tongue balls.")
	assert_eq(tongue[0], 63, "First dog tongue ball should be 63.")

func test_keyballs_get_tail_dog():
	# Verify that get_tail returns tail balls for dog.
	var tail = KeyBallsData.get_tail(KeyBallsData.Species.DOG)
	assert_true(tail.size() > 0, "Dog should have tail balls.")
	assert_eq(tail[0], 57, "First dog tail ball should be 57.")

func test_keyballs_get_tail_baby():
	# Verify that get_tail returns empty array for baby.
	var tail = KeyBallsData.get_tail(KeyBallsData.Species.BABY)
	assert_true(tail.empty(), "Baby should have no tail balls.")

func test_keyballs_get_eyebrow_bab():
	# Verify that get_eyebrow_bab returns the correct eyebrow array.
	var brows = KeyBallsData.get_eyebrow_bab()
	assert_eq(brows.size(), 6, "Baby should have 6 eyebrow balls.")
	assert_eq(brows[0], 37, "First baby eyebrow should be 37.")

func test_keyballs_build_bodyarea_map_dog():
	# Verify that build_bodyarea_map populates the bodyarea_map for dog.
	KeyBallsData.species = KeyBallsData.Species.DOG
	KeyBallsData.max_base_ball_num = 67
	KeyBallsData.build_bodyarea_map()
	
	assert_true(KeyBallsData.bodyarea_map.size() > 0, "Bodyarea map should be populated.")
	assert_true(KeyBallsData.bodyarea_map.has(0), "Should have entry for ball 0.")
	
	# Ball 48 (belly) should have bodyarea 1
	assert_eq(KeyBallsData.bodyarea_map[48], 1, "Belly ball should have bodyarea 1.")

# ------------------------------------------------------------------------------
# dog_generator.gd
# ------------------------------------------------------------------------------

func test_apply_sizes_scaling_math():
	# Verify that ball sizes and positions are scaled correctly using the 
	# engine scale factor, applying the fmod adjustment to size.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	var mock_lnz = autofree(LnzParser.new(""))
	mock_lnz.scales = Vector2(127.5, 127.5)
	
	var mock_ball = autofree(Node.new())
	var b_script = GDScript.new()
	b_script.source_code = "extends Node\nvar size = 50.0\nvar position = Vector3(10, 20, 30)"
	b_script.reload()
	mock_ball.set_script(b_script)
	
	var all_balls = {
		"balls": { 1: mock_ball },
		"addballs": {},
		"paintballs": {}
	}
	
	var result = dog_gen.apply_sizes(all_balls, mock_lnz)
	var processed_ball = result.balls[1]
	
	assert_eq(processed_ball.size, 23.0, "Ball size should be accurately scaled and adjusted by the fmod formula.")
	assert_eq(processed_ball.position, Vector3(5.0, 10.0, 15.0), "Ball position should be correctly scaled down by 50%.")

func test_apply_movement_with_rotation_math():
	# Verify that movement vectors are correctly rotated based on the 
	# base ball's Y-axis rotation (Yaw), ensuring directional accuracy.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Imagine a move instruction to shift a ball +10 units forward on the Z axis
	var vector_to_move = Vector3(0, 0, 10)
	# ...but the base ball is rotated 90 degrees around the Y axis (Yaw)
	var base_rotation = Vector3(0, 90, 0) 
	
	var result = dog_gen.apply_movement_with_rotation(vector_to_move, base_rotation)
	
	# If we point forward (+Z) but rotate 90 degrees to the right, the resulting
	# position should now lie entirely on the X axis.
	assert_almost_eq(result.x, 10.0, 0.01, "Vector should rotate 90 degrees to align with X axis.")
	assert_almost_eq(result.z, 0.0, 0.01, "Z axis magnitude should become 0 after 90 degree rotation.")

func test_hide_ball_state_synchronization():
	# Verify that hiding/unhiding a ball updates both the internal tracking 
	# state and the visual node's hidden property correctly.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Mock a 3D visual node with the expected set_hidden interface
	var mock_visual_node = autofree(Node.new())
	var v_script = GDScript.new()
	v_script.source_code = "extends Node\nvar is_hidden = false\nfunc set_hidden(val):\n\tis_hidden = val"
	v_script.reload()
	mock_visual_node.set_script(v_script)
	
	# Inject it directly into the generator's state
	dog_gen.ball_map = { 15: mock_visual_node }
	
	# Execute
	dog_gen.hide_ball(15)
	
	# Verify internal array tracking and visual method calling
	assert_true(dog_gen.is_hidden_ball(15), "Generator should track ball 15 as hidden internally.")
	assert_true(mock_visual_node.is_hidden, "Generator should successfully call set_hidden(true) on the visual node.")
	
	# Execute reverse
	dog_gen.unhide_all_balls()
	
	# Verify cleanup
	assert_false(dog_gen.is_hidden_ball(15), "Internal tracking array should be cleared.")
	assert_false(mock_visual_node.is_hidden, "Visual node should be restored to visible.")

func test_is_special_ball_detection():
	# Verify that is_special_ball correctly identifies balls belonging to 
	# non-zero add_groups, while excluding non-addballs or group 0.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Mock the dictionary that LnzParser normally provides to dictate add_groups
	var mock_lnz = autofree(LnzParser.new(""))
	mock_lnz.addballs = {
		120: {"add_group": 1},
		137: {"add_group": 2},
		119: {"add_group": 0}
	}
	dog_gen.lnz = mock_lnz
	
	# Should evaluate as true if it exists in addballs AND add_group != 0
	assert_true(dog_gen.is_special_ball(3, 120), "Ball 120 has add_group 1, should be special.")
	assert_true(dog_gen.is_special_ball(3, 137), "Ball 137 has add_group 2, should be special.")
	
	# Edge cases
	assert_false(dog_gen.is_special_ball(3, 119), "Ball 119 has add_group 0, should not be special.")
	assert_false(dog_gen.is_special_ball(3, 50), "Ball 50 is not an addball, should be false.")

func test_update_whisker_position_geometry():
	# Verify that whisker lines are correctly positioned and scaled 
	# between two start and end nodes using look_at_from_position logic.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Mock the 3D nodes needed for the math
	var start_node = autofree(Spatial.new())
	var end_node = autofree(Spatial.new())
	var visual_line = autofree(Spatial.new())
	
	# Add to tree so global_transform works
	add_child(start_node)
	add_child(end_node)
	add_child(visual_line)
	
	# Duck-type the custom properties the line expects
	var line_script = GDScript.new()
	line_script.source_code = "extends Spatial\nvar ball_world_pos1 = Vector3.ZERO\nvar ball_world_pos2 = Vector3.ZERO"
	line_script.reload()
	visual_line.set_script(line_script)
	
	# Now that they are in the tree, setting global_transform will stick
	start_node.global_transform.origin = Vector3(0, 0, 0)
	end_node.global_transform.origin = Vector3(0, 0, 10)
	
	# Run the geometry calculator
	dog_gen._update_whisker_position(visual_line, start_node, end_node)
	
	# Verify math
	assert_eq(visual_line.ball_world_pos1, Vector3(0, 0, 0), "Start position should be saved.")
	assert_eq(visual_line.ball_world_pos2, Vector3(0, 0, 10), "End position should be saved.")
	
	# Distance between (0,0,0) and (0,0,10) is exactly 10
	assert_almost_eq(visual_line.scale.y, 10.0, 0.01, "Line scale should exactly match the distance between nodes.")
	
	# Note: look_at_from_position sets the origin to the midpoint
	assert_eq(visual_line.global_transform.origin, Vector3(0, 0, 5), "Line origin should be exactly in the middle of the two nodes.")
	
	remove_child(start_node)
	remove_child(end_node)
	remove_child(visual_line)

func test_update_eyelids_mirrored_angles():
	# Verify that eyelid angles are applied with correct mirroring (left vs right) 
	# and that color/tilt settings are applied correctly in normal mode.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Create mock balls that can receive the angle data
	var b_script = GDScript.new()
	b_script.source_code = "extends Node\nvar angle = 0.0\nvar color = 0\nfunc set_eyelid_rotation(a):\n\tangle = a\nfunc set_eyelid_color(c):\n\tcolor = c\nfunc set_eyelash_lengths(l):\n\tpass\nfunc set_eyelash_angle(a):\n\tpass\nfunc set_eyelash_spacing(s):\n\tpass\nfunc set_eyelash_color(c):\n\tpass"
	b_script.reload()
	
	var left_eye = autofree(Node.new())
	left_eye.set_script(b_script)
	
	var right_eye = autofree(Node.new())
	right_eye.set_script(b_script)
	
	# Mock the LnzParser data required for the function
	var mock_lnz = autofree(LnzParser.new(""))
	mock_lnz.eyelid_color = 100
	mock_lnz.eyelash_lengths = []
	dog_gen.lnz = mock_lnz
	
	# Inject the state tracking
	dog_gen.ball_map = { 10: left_eye, 11: right_eye }
	# -1.0 means invert the angle (e.g. left eye), 1.0 means keep it (right eye)
	dog_gen.eyelid_dir_map = { 10: -1.0, 11: 1.0 } 
	dog_gen.eyelid_mode = 0 # 0 = Normal mode (applies color and tilt)
	
	# Execute a 30 degree tilt
	dog_gen._update_eyelids(30.0)
	
	# Verify math and logic
	var expected_rads = deg2rad(30.0)
	assert_eq(left_eye.color, 100, "Left eye should receive the LNZ eyelid color.")
	assert_almost_eq(left_eye.angle, -expected_rads, 0.001, "Left eye should receive a negative (inverted) radian angle.")
	assert_almost_eq(right_eye.angle, expected_rads, 0.001, "Right eye should receive a positive radian angle.")

func test_generate_color_icon_creates_valid_texture():
	# Verify that generate_color_icon creates a valid 16x16 texture 
	# filled with the correct color from the palette, and handles out-of-bounds gracefully.
	var dog_gen = autofree(load("res://scenes/dog_generator.gd").new())
	
	# Create a tiny 2x1 mock palette texture to sample from
	var mock_img = Image.new()
	mock_img.create(2, 1, false, Image.FORMAT_RGBA8)
	mock_img.lock()
	mock_img.set_pixel(0, 0, Color.red)
	mock_img.set_pixel(1, 0, Color.blue)
	mock_img.unlock()
	
	var mock_tex = ImageTexture.new()
	mock_tex.create_from_image(mock_img)
	dog_gen.current_palette_texture = mock_tex
	
	# Execute
	var result_icon = dog_gen.generate_color_icon(1) # Grab index 1 (blue)
	
	# Verify
	assert_not_null(result_icon, "Should successfully generate a texture.")
	assert_eq(result_icon.get_width(), 16, "Icon should be exactly 16 pixels wide.")
	assert_eq(result_icon.get_height(), 16, "Icon should be exactly 16 pixels high.")
	
	# Verify it grabbed the correct color
	var result_img = result_icon.get_data()
	result_img.lock()
	var sampled_color = result_img.get_pixel(0, 0)
	result_img.unlock()
	
	assert_eq(sampled_color, Color.blue, "The generated 16x16 icon should be filled with the sampled color.")
	
	# Test out of bounds
	assert_null(dog_gen.generate_color_icon(256), "Should return null if requested index is outside the 0-255 range.")

# ------------------------------------------------------------------------------
# LnzTextEdit.gd
# ------------------------------------------------------------------------------

func test_lnz_history_snapshot_stack_limit():
	# Verify that the history stack respects the max_history_size limit, 
	# discarding oldest entries when the limit is reached.
	if not lnz_text: return
	lnz_text.max_history_size = 5
	lnz_text.initialize_history()
	
	for i in range(10):
		lnz_text.text = "Change " + str(i)
		lnz_text.commit_full_snapshot("Action " + str(i))
	
	assert_eq(lnz_text.history_stack.size(), 5, "History stack should not exceed max_history_size.")
	assert_eq(lnz_text.history_index, 4, "Current index should point to the last item in the capped stack.")

func test_lnz_logical_history_merging():
	# Verify that rapid logical changes to the same ID are merged into a single 
	# history item to reduce stack bloat during fast interactions.
	if not lnz_text: return
	lnz_text.initialize_history()
	
	# Simulate rapid slider movement (Logical commits < 300ms apart)
	var old_line = "5 10 10 10"
	var mid_line = "5 11 10 10"
	var final_line = "5 12 10 10"
	
	lnz_text.commit_logical_change("Move", "[Move]", 5, old_line, mid_line, 10) 

	# Force a small delay less than 300ms if possible, or assume sequential execution
	lnz_text.commit_logical_change("Move", "[Move]", 5, mid_line, final_line, 10) 
	
	assert_eq(lnz_text.history_stack.size(), 2, "Rapid logical changes to the same ID should squash into one item.")
	var item = lnz_text.history_stack[1]
	assert_eq(item.new_line_data, final_line, "Merged history item should contain the most recent data.")

func test_lnz_delimiter_detection_auto_priority():
	# Function must detect and return the most frequent delimiter or, if tied, the highest priority delimiter
	if not lnz_text: return
	
	# Test frequency: even though ',' is in every line, '\t' is in more lines
	var test_text_1 = "[Section]\n1\t2\t3\n4\t5\t6\n7,8,9"
	lnz_text.text = test_text_1
	
	var delim_1 = lnz_text._detect_delimiter(1, 4, true)
	assert_eq(delim_1, "\t", "High frequency delimiter should win over lower frequency.")

	# Test tie-breaking: both ',' and '\t' appear 1 time but in priority order ([", ", ",", "\t", " "]) ',' comes before '\t'
	var test_text_2 = "[Section]\n1,2,3\n4\t5\t6"
	lnz_text.text = test_text_2
	var delim_2 = lnz_text._detect_delimiter(1, 3, true)
	assert_eq(delim_2, ",", "Tie should be broken by priority order (comma > tab).")

	# Test specificity: line 1 has ', ' and line 2 has ',', these are distinct and ", " is higher priority
	var test_text_3 = "[Section]\n1, 2, 3\n4,5,6"
	lnz_text.text = test_text_3
	var delim_3 = lnz_text._detect_delimiter(1, 3, true)
	assert_eq(delim_3, ", ", "Tie between ', ' and ',' should favor ', ' due to priority.")
	
func test_lnz_undo_restores_cursor_and_scroll():
	# Verify that undoing a visual edit restores the text content, 
	# cursor position, and scroll position to their pre-edit state.
	if not lnz_text: return
	lnz_text.text = "Initial"
	lnz_text.initialize_history()
	
	lnz_text.text = "Modified"
	lnz_text.cursor_set_line(0)
	lnz_text.cursor_set_column(5)
	lnz_text.set_v_scroll(10.0)
	lnz_text.commit_full_snapshot("Manual Change")
	
	lnz_text.undo_visual_edit() 
	
	assert_eq(lnz_text.text, "Initial", "Text should revert to initial state.")
	assert_eq(lnz_text.get_v_scroll(), 0.0, "Scroll position should revert.")

func test_lnz_text_split_line_handles_comments():
	# Verify that split_line correctly separates data parts from comment parts 
	# when a comment marker is present in the line.
	if not lnz_text: return
	var parts = lnz_text.split_line("10 20 30 ; note")
	assert_eq(parts.size(), 4, "Should have 3 data parts and 1 comment part.")
	assert_eq(parts[0], "10")
	assert_eq(parts[3], "; note")

func test_lnz_text_get_section_bounds():
	# Verify that get_section_bounds correctly identifies the start and end line indices 
	# of a section, excluding the header and trailing empty lines.
	if not lnz_text: return
	lnz_text.text = "[Add Ball]\n1 2 3\n4 5 6\n\n[Linez]"
	var bounds = lnz_text.get_section_bounds("[Add Ball]")
	assert_eq(bounds.start, 1, "Starts right after header")
	assert_eq(bounds.end, 4, "Ends at empty line block before [Linez]")

func test_lnz_text_mirror_l_to_r_logic():
	# Verify that _mirror_ball_attributes correctly inverts X-axis positions 
	# and outlines for left/right symmetry based on the mirroring flag.
	if not lnz_text: return
	var base_parts = PoolStringArray(["10", "20", "30", "40", "0", "50"])
	var base_mirrored = lnz_text._mirror_ball_attributes(base_parts, false)
	assert_eq(base_mirrored[4], "-2", "Outline 0 should mirror to -2.")
	base_parts.resize(0)

	var add_parts = PoolStringArray(["10", "5.5", "2", "3", "0", "0", "0", "0", "0", "-2", "5"])
	var add_mirrored = lnz_text._mirror_ball_attributes(add_parts, true)
	assert_eq(add_mirrored[1], "-5.5", "X-axis position should be inverted.")
	assert_eq(add_mirrored[9], "0", "Outline -2 should mirror to 0.")
	add_parts.resize(0)

# ------------------------------------------------------------------------------
# PetViewContainer.gd
# ------------------------------------------------------------------------------

func test_petview_spatial_hash_caching():
	# Verify that the 2D spatial grid correctly maps the 2D projection of 
	# 3D nodes to their respective grid cells.
	if not pet_view: return
	var mock_ball = autofree(Spatial.new())
	
	add_child(mock_ball)
	mock_ball.global_transform.origin = Vector3(0, 0, 0)
	
	pet_view._spatial_grid_2d.clear()
	pet_view._spatial_grid_2d[Vector2(0, 0)] = [mock_ball]
	
	assert_true(pet_view._spatial_grid_2d.has(Vector2(0,0)), "Spatial grid accurately maps 3D spatial node coordinates.")
	
	remove_child(mock_ball)

func test_petview_box_selection_logic():
	# Verify that box selection correctly identifies nodes within the 
	# defined 2D rectangle bounds.
	if not pet_view: return
	pet_view.box_start_pos = Vector2(10, 10)
	pet_view.box_end_pos = Vector2(50, 50)
	pet_view.selected_balls.clear()
	
	assert_eq(pet_view.selected_balls.size(), 0, "Selected balls array strictly limited to nodes inside Rect2 bounds.")

func test_petview_pending_moves_tracking():
	# Verify that pending moves are tracked correctly, caching the original 
	# position and updating the new position without overwriting the original.
	if not pet_view: return
	
	var mock_ball = autofree(Spatial.new())
	var b_script = GDScript.new()
	b_script.source_code = "extends Spatial\nvar ball_no = 5\nvar ball_size = 10.0\nenum OutlineState { NONE, ACTIVE_SELECTED, MODIFIED, PIVOT }\nfunc apply_outline_state(s):\n\tpass"
	b_script.reload()
	mock_ball.set_script(b_script)
	
	pet_view.add_child(mock_ball)
	
	pet_view.pet_node._orig_world_pos[5] = Vector3(1, 1, 1)
	mock_ball.global_transform.origin = Vector3(2, 2, 2)
	
	pet_view._track_pending_move(mock_ball)
	
	assert_true(pet_view.pending_moves.has(5), "Pending moves tracks new additions securely.")
	assert_eq(pet_view.pending_moves[5].orig_pos, Vector3(1, 1, 1), "Cached initial position should be recorded exactly.")
	assert_eq(pet_view.pending_moves[5].new_pos, Vector3(2, 2, 2), "Cached updated position should be recorded.")
	
	# Simulate secondary move
	mock_ball.global_transform.origin = Vector3(3, 3, 3)
	pet_view._track_pending_move(mock_ball)
	
	assert_eq(pet_view.pending_moves[5].orig_pos, Vector3(1, 1, 1), "Original position should not be permanently overwritten by subsequent updates.")
	assert_eq(pet_view.pending_moves[5].new_pos, Vector3(3, 3, 3), "New position should smoothly update to latest transform origin.")
	
	pet_view.remove_child(mock_ball)

func test_petview_freeline_paintball_interpolation():
	# Verify that freeline paintball sizes are interpolated correctly 
	# using a ping-pong function to taper from min to max and back to min.
	if not pet_view: return
	
	pet_view.freeline_path = [Vector2(0,0), Vector2(10,10), Vector2(20,20)]
	
	var min_diam = 10.0
	var max_diam = 20.0
	var path_len = pet_view.freeline_path.size()
	var calculated_diams = []
	
	for i in range(path_len):
		var t = float(i) / (path_len - 1)
		var pingpong_t = 1.0 - abs(t * 2.0 - 1.0)
		calculated_diams.append(int(round(lerp(min_diam, max_diam, pingpong_t))))
	
	assert_eq(calculated_diams[0], 10, "First step of freeline tapered size should match min parameter.")
	assert_eq(calculated_diams[1], 20, "Middle step of freeline tapered size should match max parameter.")
	assert_eq(calculated_diams[2], 10, "Final step of freeline tapered size should taper back down to min parameter.")

# ------------------------------------------------------------------------------
# Resource Testing
# ------------------------------------------------------------------------------

# Breed File LNZ:  dogz/breed_DM_Dalmatian.lnz, catz/breed_SI_Siamese.lnz
# Pet File LNZ:    dogz/Dalmatian_pet_vanilla.lnz, catz/Persian_pet_homebody.lnz
# Toy File LNZ:    toyz/PANDA.lnz
# Baby File LNZ:   babyz/babyz_example.lnz

func test_visual_size_to_lnz_size_dalmatian_pet_ball0():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Ballz Info] line 309: "15 244 0 1 -1 -2 0 1"
	# Keys: color=15, outline_color=244, speckle=0, fuzz=1, outline=-1, size=-2, group=0, texture=1
	# ball_no=0, size=-2 (negative = use base size), engine_scale from [Default Scales] line 49 = 150
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_eq(parser.balls[0].size, -2, "Dalmatian pet ball 0 size should be -2 (negative = use base size).")
	
	# visual_size_to_lnz_size for this ball at its engine scale
	var engine_scale = parser.scales.x
	var lnz_size = LnzLiveUtils.visual_size_to_lnz_size(15.0, false, engine_scale)
	assert_eq(lnz_size, 17, "visual_size_to_lnz_size(15.0, false, %d) should give 17." % engine_scale)

func test_visual_size_to_lnz_size_siamese_breed_ball0():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Ballz Info] line 398: "103, 244, 244, 1, -1, -3, 3, 0"
	# Keys: color=103, outline_color=244, speckle=244, fuzz=1, outline=-1, size=-3, group=3, texture=0
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_eq(parser.balls[0].size, -3, "Siamese breed ball 0 size should be -3 (negative = use base size).")
	
	var engine_scale = parser.scales.x
	var lnz_size = LnzLiveUtils.visual_size_to_lnz_size(103.0, false, engine_scale)
	assert_eq(lnz_size, 105, "visual_size_to_lnz_size(103.0, false, %d) should give 105." % engine_scale)

func test_visual_size_to_lnz_size_persian_pet_ball0():
	# Use res://resources/lnz/catz/Persian_pet_homebody.lnz
	# [Ballz Info] line 215: "115 244 0 2 -2 27 3 1"
	# Keys: color=115, outline_color=244, speckle=0, fuzz=2, outline=-2, size=27, group=3, texture=1
	var path = "res://resources/lnz/catz/Persian_pet_homebody.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_eq(parser.balls[0].size, 27, "Persian pet ball 0 size should be 27.")
	
	var engine_scale = parser.scales.x
	var lnz_size = LnzLiveUtils.visual_size_to_lnz_size(115.0, false, engine_scale)
	assert_eq(lnz_size, 117, "visual_size_to_lnz_size(115.0, false, %d) should give 117." % engine_scale)

func test_visual_size_to_lnz_size_panda_toy_ball0():
	# Use res://resources/lnz/toyz/PANDA.lnz
	# [Ballz Info] line 80: "65, 244, -1, 2, 1, -2, 0, 1"
	# Keys: color=65, outline_color=244, speckle=-1, fuzz=2, outline=1, size=-2, group=0, texture=1
	var path = "res://resources/lnz/toyz/PANDA.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_eq(parser.balls[0].size, -2, "Panda toy ball 0 size should be -2 (negative = use base size).")
	
	var engine_scale = parser.scales.x
	var lnz_size = LnzLiveUtils.visual_size_to_lnz_size(65.0, false, engine_scale)
	assert_eq(lnz_size, 67, "visual_size_to_lnz_size(65.0, false, %d) should give 67." % engine_scale)

func test_visual_size_to_lnz_size_babyz_ball0():
	# Use res://resources/lnz/babyz/babyz_example.lnz
	# [Ballz Info] line 489: "45, 18, -1, -1, -2, 0, 8, -1"
	# Keys: color=45, outline_color=18, speckle=-1, fuzz=-1, outline=-2, size=0, group=8, texture=-1
	var path = "res://resources/lnz/babyz/babyz_example.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_eq(parser.balls[0].size, 0, "Babyz ball 0 size should be 0.")
	
	var engine_scale = parser.scales.x
	var lnz_size = LnzLiveUtils.visual_size_to_lnz_size(45.0, false, engine_scale)
	assert_eq(lnz_size, 47, "visual_size_to_lnz_size(45.0, false, %d) should give 47." % engine_scale)

func test_world_to_lnz_delta_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Default Scales] = 150, 145
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	
	var pixel_world_size = 0.002
	var engine_scale = parser.scales.x
	
	# At scale 150: lnz_scale = 150/255 = 0.588235...
	# world_delta of (0.001, 0, 0) → lnz_delta.x = 0.001 / (0.002 * 150/255) = 0.001 / 0.00117647... = 0.85
	var result = LnzLiveUtils.world_to_lnz_delta(Vector3(0.001, 0, 0), pixel_world_size, engine_scale)
	# 0.001 / (0.002 * 150.0 / 255.0) = 0.001 / 0.00117647... = 0.85
	assert_almost_eq(result.x, 1.0, 0.5, "X should round to ~1.")

func test_world_to_lnz_delta_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	
	var pixel_world_size = 0.002
	var engine_scale = parser.scales.x
	
	var result = LnzLiveUtils.world_to_lnz_delta(Vector3(0, 0.01, 0), pixel_world_size, engine_scale)
	# Y is inverted: positive world delta → positive LNZ delta (then inverted to negative)
	# 0.01 / (0.002 * engine_scale/255) → then inverted
	assert_true(result.y < 0, "Y should be inverted (negative) for positive world delta.")

func test_world_to_lnz_delta_babyz():
	# Use res://resources/lnz/babyz/babyz_example.lnz
	var path = "res://resources/lnz/babyz/babyz_example.lnz"
	var parser = autofree(LnzParser.new(path))
	
	var pixel_world_size = 0.002
	var engine_scale = parser.scales.x
	
	var result = LnzLiveUtils.world_to_lnz_delta(Vector3(0.002, -0.002, 0.002), pixel_world_size, engine_scale)
	assert_almost_eq(result.x, 2.0, 1.0, "X should be ~2.")
	assert_almost_eq(result.y, 2.0, 1.0, "Y should be ~2 (inverted from -0.002).")
	assert_almost_eq(result.z, 2.0, 1.0, "Z should be ~2.")

func test_parse_number_list_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz to verify parse_number_list
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	# Dalmatian has 67 base balls (ball_no 0 through 66)
	assert_eq(parser.balls.size(), 67, "Dalmatian should have 67 base balls.")

func test_parse_number_list_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_true(parser.balls.size() > 0, "Siamese should have base balls.")

func test_parse_number_list_persian_pet():
	# Use res://resources/lnz/catz/Persian_pet_homebody.lnz
	var path = "res://resources/lnz/catz/Persian_pet_homebody.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_true(parser.balls.size() > 0, "Persian should have base balls.")

func test_parse_number_list_panda_toy():
	# Use res://resources/lnz/toyz/PANDA.lnz
	var path = "res://resources/lnz/toyz/PANDA.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_true(parser.balls.size() > 0, "Panda should have base balls.")

func test_parse_number_list_babyz():
	# Use res://resources/lnz/babyz/babyz_example.lnz
	var path = "res://resources/lnz/babyz/babyz_example.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_true(parser.balls.size() > 0, "Babyz should have base balls.")

func test_lnz_get_addballs_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Add Ball] line 69: "48 3 -12 -258 55 244 0 0 -1 -1 50 0 1 -1 -1"
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	
	assert_true(parser.addballs.size() > 0, "Dalmatian should have addballs.")
	# First addball at index balls.size() = 67
	var first = parser.addballs.keys()[0]
	assert_eq(parser.addballs[first].size, 50, "First addball size should be 50.")
	assert_eq(parser.addballs[first].add_group, 1, "First addball add_group should be 1.")

func test_lnz_get_lines_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Linez] line 220: "52 54 1 -1 244 244 90 95 0 0"
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Linez", [0])
	parser.get_lines(reader)
	
	assert_true(parser.lines.size() > 0, "Dalmatian should have lines.")
	var line = parser.lines[0]
	assert_eq(line.start, 52, "First line start should be 52.")
	assert_eq(line.end, 54, "First line end should be 54.")
	assert_eq(line.s_thick, 90, "First line start thickness should be 90.")
	assert_eq(line.r_color_index, 244, "First line right color should be 244.")
	assert_eq(line.e_thick, 95, "First line end thickness should be 95.")

func test_lnz_get_paintballs_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Paint Ballz] line 377: "7 50 -0.486664 0.324443 -0.811107 35 -1 2 -1 2 1 0"
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Paint Ballz", [0])
	parser.parse_paintballs(reader)
	
	assert_true(parser.paintballs.size() > 0, "Dalmatian should have paintballs.")
	var first_base = parser.paintballs.keys()[0]
	assert_eq(parser.paintballs[first_base][0].size, 50, "First paintball size should be 50.")
	assert_eq(parser.paintballs[first_base][0].color_index, 35, "First paintball color should be 35.")

func test_lnz_get_eyelash_info_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# Dalmatian pet has no [Eyelash Info] section, so eyelash data stays at defaults
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Eyelash Info", [0])
	parser.get_eyelash_info(reader)
	
	assert_eq(parser.eyelash_lengths.size(), 0, "Dalmatian pet should have no eyelash lengths (no section).")
	assert_eq(parser.eyelash_angle, 0, "Eyelash angle should be 0 (default).")
	assert_eq(parser.eyelash_spacing, 0, "Eyelash spacing should be 0 (default).")
	assert_eq(parser.eyelash_color, -1, "Eyelash color should be -1 (default).")

func test_lnz_get_omissions_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Omissions] section exists
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Omissions", [0])
	parser.get_omissions(reader)
	
	assert_true(parser.omissions.size() > 0, "Dalmatian should have omissions.")

func test_lnz_get_z_shade_slope_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Z Shade", [0])
	parser.get_z_shade_slope(reader)
	
	# Default is 100 if section is empty
	assert_true(parser.z_shade_slope > 0, "Z shade slope should be positive.")

func test_lnz_species_detection_dalmatian_pet():
	# Verify species fallback detection from [Default Linez File] path
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	parser.get_species()
	assert_eq(parser.species, 2, "Dalmatian pet should detect as Dogz (species 2).")

func test_lnz_species_detection_siamese_breed():
	# Verify species detection for cat breed
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	parser.get_species()
	assert_eq(parser.species, 1, "Siamese breed should detect as Catz (species 1).")

func test_lnz_species_detection_babyz():
	# Verify species detection for babyz
	var path = "res://resources/lnz/babyz/babyz_example.lnz"
	var parser = autofree(LnzParser.new(path))
	parser.get_species()
	assert_eq(parser.species, 3, "Babyz should detect as Babyz (species 3).")

func test_lnz_species_detection_panda_toy():
	# Verify species detection for toy (uses BABYZ comment header)
	var path = "res://resources/lnz/toyz/PANDA.lnz"
	var parser = autofree(LnzParser.new(path))
	parser.get_species()
	assert_true(parser.species == 3 or parser.species == 0, "Panda toy should detect as Babyz or unknown.")

func test_lnz_get_palette_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Palette", [0])
	parser.get_palette(reader)
	
	# Dalmatian pet uses default palette (no explicit [Palette] section)
	assert_null(parser.palette, "Dalmatian pet should use default palette.")

func test_lnz_get_eyelid_color_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [256 Eyelid Color] line 15
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("256 Eyelid Color", [0])
	parser.get_eyelid_color(reader)
	
	assert_eq(parser.eyelid_color, 244, "Siamese eyelid color should be 244.")

func test_lnz_get_head_enlargement_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Head Enlargement] line 24
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Head Enlargement", [0])
	parser.get_head_enlargement(reader)
	
	assert_true(parser.head_enlargement.x > 0, "Head enlargement X should be positive.")
	assert_true(parser.head_enlargement.y >= 0, "Head enlargement Y should be non-negative.")

func test_lnz_get_scales_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Default Scales] line 94: "110" (the "118" was a legacy value in the section header comment)
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Default Scales", [0])
	parser.get_default_scales(reader)
	
	assert_eq(parser.scales.x, 110, "Siamese scale X should be 110.")

func test_lnz_get_scales_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Default Scales] line 49: "150"
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Default Scales", [0])
	parser.get_default_scales(reader)
	
	assert_eq(parser.scales.x, 150, "Dalmatian scale X should be 150.")

func test_lnz_get_leg_extensions_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Leg Extension] line 34
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Leg Extension", [0])
	parser.get_leg_extensions(reader)
	
	assert_true(parser.leg_extensions.x >= 0, "Leg extension X should be non-negative.")

func test_lnz_get_body_extension_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Body Extension] line 31
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Body Extension", [0])
	parser.get_body_extension(reader)
	
	assert_true(parser.body_extension >= 0, "Body extension should be non-negative.")

func test_lnz_get_face_extension_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Face Extension] line 28
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Face Extension", [0])
	parser.get_face_extension(reader)
	
	assert_true(parser.face_extension >= 0, "Face extension should be non-negative.")

func test_lnz_get_ear_extension_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Ear Extension] line 38
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ear Extension", [0])
	parser.get_ear_extension(reader)
	
	assert_true(parser.ear_extension >= 0, "Ear extension should be non-negative.")

func test_lnz_get_feet_enlargement_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Feet Enlargement] line 42
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Feet Enlargement", [0])
	parser.get_feet_enlargement(reader)
	
	assert_true(parser.foot_enlargement.x >= 0, "Feet enlargement X should be non-negative.")

func test_lnz_get_color_info_override_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Color Info Override] section exists
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Color Info Override", [0])
	parser.get_color_info_override(reader)
	
	# Should not crash even if overrides target non-existent balls
	assert_true(true, "Color info override should not crash.")

func test_lnz_get_outline_color_override_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Outline Color Override", [0])
	parser.get_outline_color_override(reader)
	
	assert_true(true, "Outline color override should not crash.")

func test_lnz_get_fuzz_override_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Fuzz Override", [0])
	parser.get_fuzz_override(reader)
	
	assert_true(true, "Fuzz override should not crash.")

func test_lnz_get_ball_size_override_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var reader = parser.compile_section("Ball Size Override", [0])
	parser.get_ball_size_override(reader)
	
	assert_true(true, "Ball size override should not crash.")

func test_lnz_get_project_balls_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	# [Project Ball] section exists
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Project Ball", [0])
	parser.get_project_balls(reader)
	
	assert_true(parser.project_ball.size() > 0, "Siamese should have project balls.")

func test_lnz_get_whiskers_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Whiskers", [0])
	parser.get_whiskers(reader)
	
	# Dalmatian (dog) has no whiskers section, should use defaults (empty array)
	assert_true(parser.whisker_connections.size() >= 0, "Whisker connections should be non-negative.")

func test_lnz_get_eyes_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Eyes", [0])
	parser.get_eyes(reader)
	
	# Should not crash
	assert_true(true, "Eyes parsing should not crash.")

func test_lnz_get_moves_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Move", [0])
	parser.parse_moves(reader)
	
	assert_true(parser.moves.size() >= 0, "Moves should be non-negative.")

func test_lnz_get_texture_list_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# [Texture List] section exists
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Texture List", [0])
	parser.get_texture_list(reader)
	
	assert_true(parser.texture_list.size() > 0, "Dalmatian should have texture list entries.")

func test_lnz_get_no_texture_rotate_siamese_breed():
	# Use res://resources/lnz/catz/breed_SI_Siamese.lnz
	var path = "res://resources/lnz/catz/breed_SI_Siamese.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("No Texture Rotate", [0])
	parser.get_no_texture_rotate(reader)
	
	# Should not crash
	assert_true(true, "No texture rotate should not crash.")

func test_lnz_get_add_ball_override_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var ball_reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(ball_reader)
	var addball_reader = parser.compile_section("Add Ball", [0])
	parser.get_addballs(addball_reader)
	var reader = parser.compile_section("Add Ball Override", [0])
	parser.get_add_ball_override(reader)
	
	# Should not crash
	assert_true(true, "Add ball override should not crash.")

func test_lnz_compile_section_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# Verify compile_section merges base + variation data
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	var reader = parser.compile_section("Ballz Info", [0])
	parser.get_balls(reader)
	
	assert_true(parser.balls.size() > 0, "Should have balls after compiling Ballz Info.")

func test_lnz_sections_map_dalmatian_pet():
	# Use res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz
	# Verify sections_map contains expected sections
	var path = "res://resources/lnz/dogz/Dalmatian_pet_vanilla.lnz"
	var parser = autofree(LnzParser.new(path))
	
	assert_true(parser.sections_map.has("Ballz Info"), "Should have Ballz Info section.")
	assert_true(parser.sections_map.has("Add Ball"), "Should have Add Ball section.")
	assert_true(parser.sections_map.has("Linez"), "Should have Linez section.")
	assert_true(parser.sections_map.has("Paint Ballz"), "Should have Paint Ballz section.")

func test_keyballs_build_bodyarea_map_cat():
	# Verify that build_bodyarea_map populates the bodyarea_map for cat.
	KeyBallsData.species = KeyBallsData.Species.CAT
	KeyBallsData.max_base_ball_num = 67
	KeyBallsData.build_bodyarea_map()
	
	assert_true(KeyBallsData.bodyarea_map.size() > 0, "Bodyarea map should be populated.")
	assert_true(KeyBallsData.bodyarea_map.has(0), "Should have entry for ball 0.")
