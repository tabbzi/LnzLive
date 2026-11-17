extends GutTest

# Exercise storage without rebuilding the editor's tree or model.
class ImportTree:
	extends "res://scenes/editor/FileTree.gd"
	var saved_path: String = ""
	var failure: String = ""
	var conflict_dialog: ConfirmationDialog
	func _show_texture_conflicts(dialog: ConfirmationDialog) -> void:
		conflict_dialog = dialog
		add_child(dialog)
	func rescan_textures(_reload_model: bool = false) -> void:
		pass
	func rescan_with_extension(_extension: String, path: String = "") -> void:
		saved_path = path
	func _binary_import_error(message: String) -> void:
		failure = message

func test_shared_textures_are_reused_and_identical_imports_are_silent():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_import_" + str(OS.get_ticks_usec())
	var bytes: PoolByteArray = PoolByteArray([66, 77, 0, 128, 255])
	var source: String = "[Texture List]\r\n\\art\\textures\\AD.BMP 1 256 256\r\n"
	tree._save_binary_lnz(source, "breed", {"Ad.BmP": bytes})
	var texture_path: String = tree.user_file_location.plus_file("textures/Ad.BmP")
	assert_true(tree._texture_bytes_match(texture_path, bytes))
	tree._save_binary_lnz(source, "breed", {"AD.BMP": bytes})
	assert_eq(tree.saved_path, tree.user_file_location.plus_file("breed_2.lnz"))
	assert_null(tree.conflict_dialog, "Identical bytes need no conflict dialog, regardless of filename case.")
	tree._save_binary_lnz(source, "pet")
	assert_eq(LnzLiveUtils.resolve_user_texture("/art/textures/ad.bmp", tree.saved_path), texture_path)
	var file: File = File.new()
	assert_eq(file.open(tree.saved_path, File.READ), OK)
	assert_eq(file.get_buffer(file.get_len()).get_string_from_utf8(), source, "Original LNZ text must remain unchanged.")
	file.close()
	assert_eq(tree.failure, "")
	tree._delete_dir_recursive(tree.user_file_location)
	tree.free()

func test_conflicts_default_to_preserving_existing_and_only_selected_files_replace():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_conflicts_" + str(OS.get_ticks_usec())
	var original: PoolByteArray = _bmp(100)
	var incoming: PoolByteArray = _bmp(101)
	tree._save_binary_lnz("original", "breed", {"Coat.bmp": original, "Eyes.bmp": original})
	var previous_path: String = tree.saved_path
	tree._save_binary_lnz("new", "pet", {"COAT.BMP": incoming, "eyes.bmp": incoming, "new.bmp": incoming})
	assert_eq(tree.saved_path, previous_path, "No writes before confirmation.")
	var dialog: ConfirmationDialog = tree.conflict_dialog
	var rows: VBoxContainer = dialog.get_node("ConflictLayout/ConflictScroll/ConflictRows")
	var choices: Dictionary = {}
	for row in rows.get_children():
		var choice: CheckBox = row.get_child(0)
		assert_false(choice.pressed, "Overwriting must be opt-in.")
		assert_not_null(row.get_child(1).get_child(1).texture, "Current texture thumbnail must load.")
		assert_not_null(row.get_child(2).get_child(1).texture, "Incoming texture thumbnail must load.")
		choices[choice.text.replace("Replace ", "")] = choice
	assert_true(tree._texture_bytes_match(tree.user_file_location.plus_file("textures/Coat.bmp"), original))
	choices["eyes.bmp"].pressed = true
	dialog.emit_signal("confirmed")
	assert_eq(tree.saved_path, tree.user_file_location.plus_file("pet.lnz"))
	assert_true(tree._texture_bytes_match(tree.user_file_location.plus_file("textures/Coat.bmp"), original))
	assert_true(tree._texture_bytes_match(tree.user_file_location.plus_file("textures/Eyes.bmp"), incoming))
	assert_true(tree._texture_bytes_match(tree.user_file_location.plus_file("textures/new.bmp"), incoming))
	assert_false(Directory.new().file_exists(tree.user_file_location.plus_file("textures/eyes.bmp")), "Replace the existing case variant in place.")
	tree._delete_dir_recursive(tree.user_file_location)
	tree.free()

func test_cancelling_conflicts_writes_nothing():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_cancel_" + str(OS.get_ticks_usec())
	var original: PoolByteArray = _bmp(100)
	tree._save_binary_lnz("breed", "breed", {"coat.bmp": original})
	var saved_path: String = tree.saved_path
	tree._save_binary_lnz("pet", "pet", {"coat.bmp": _bmp(101), "new.bmp": _bmp(102)})
	assert_not_null(tree.conflict_dialog)
	tree.conflict_dialog.free()
	assert_eq(tree.saved_path, saved_path)
	assert_false(Directory.new().file_exists(tree.user_file_location.plus_file("pet.lnz")))
	assert_false(Directory.new().file_exists(tree.user_file_location.plus_file("textures/new.bmp")))
	assert_true(tree._texture_bytes_match(tree.user_file_location.plus_file("textures/coat.bmp"), original))
	tree._delete_dir_recursive(tree.user_file_location)
	tree.free()

func test_older_scoped_textures_keep_precedence_over_shared_files():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_legacy_" + str(OS.get_ticks_usec())
	tree._save_binary_lnz("breed", "breed", {"coat.bmp": _bmp(100)})
	var scoped: String = LnzLiveUtils.imported_texture_directory(tree.saved_path)
	Directory.new().make_dir_recursive(scoped)
	var file: File = File.new()
	assert_eq(file.open(scoped.plus_file("coat.bmp"), File.WRITE), OK)
	file.store_buffer(_bmp(101))
	file.close()
	assert_eq(LnzLiveUtils.resolve_user_texture("coat.bmp", tree.saved_path), scoped.plus_file("coat.bmp"))
	tree._delete_dir_recursive(tree.user_file_location)
	tree.free()

func _put(bytes: PoolByteArray, offset: int, value: int, width: int = 4) -> PoolByteArray:
	for i in range(width): bytes[offset + i] = (value >> (i * 8)) & 255
	return bytes

func _bmp(index: int) -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	bytes.resize(1082)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _put(bytes, 0, 0x4d42, 2)
	bytes = _put(bytes, 2, bytes.size())
	bytes = _put(bytes, 10, 1078)
	bytes = _put(bytes, 14, 40)
	bytes = _put(bytes, 18, 1)
	bytes = _put(bytes, 22, 1)
	bytes = _put(bytes, 26, 1, 2)
	bytes = _put(bytes, 28, 8, 2)
	bytes = _put(bytes, 34, 4)
	var palette: Array = LnzLiveUtils.extract_palette_from_image(LnzLiveUtils.DEFAULT_PALETTE)
	for i in range(256):
		bytes[54 + i * 4] = int(round(palette[i].b * 255))
		bytes[55 + i * 4] = int(round(palette[i].g * 255))
		bytes[56 + i * 4] = int(round(palette[i].r * 255))
	bytes[1078] = index
	return bytes

func test_renderer_uses_shared_breed_texture_for_later_pet():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_render_" + str(OS.get_ticks_usec())
	tree._save_binary_lnz("breed", "breed", {"SharedCoat.BmP": _bmp(100)})
	tree._save_binary_lnz("pet", "pet")
	var generator = preload("res://scenes/dog_generator.gd").new()
	generator.last_loaded_filepath = tree.saved_path
	var texture: Texture = generator.load_texture("/art/textures/sharedcoat.bmp", null)
	assert_not_null(texture)
	if texture != null:
		assert_eq(Array(texture.get_data().get_data()), [100])
	generator.clear_texture_cache()
	texture = generator.load_texture("sharedcoat.bmp", null)
	assert_not_null(texture, "Shared resources must survive a rebuild.")
	tree._delete_dir_recursive(tree.user_file_location)
	generator.free()
	tree.free()

func test_binary_import_renders_selected_lnz_and_applies_texture_edits():
	var editor: Node = load("res://scenes/editor/editor.tscn").instance()
	editor.name = "Root"
	get_tree().root.add_child(editor)
	yield(get_tree(), "idle_frame")
	var tree: Tree = editor.get_node("SceneRoot/HSplitContainer/VBoxContainer/SidebarTabs/FileTree/Tree")
	var text_editor: TextEdit = editor.get_node("SceneRoot/HSplitContainer/HSplitContainer/TextPanelContainer/VBoxContainer/LnzTextEdit")
	var generator: Node = editor.get_node("PetRoot/Node")
	tree.user_file_location = "user://test_binary_editor_" + str(OS.get_ticks_usec())
	# Breed texture lists can mix short stock entries with embedded entries.
	var source: String = "[Species]\r\n2\r\n[Texture List]\r\n"
	source += "\\art\\textures\\hair11.bmp 1\r\n\\art\\textures\\hair10.bmp 1\r\n\\art\\textures\\hair11.bmp 1\r\n"
	source += "\\art\\textures\\BANANA.bmp 2 256 256\r\n[Ballz Info]\r\n10, 45, -1, 0, -1, 0, 4, 3\r\n"
	var header: BhdParser = BhdParser.new("res://resources/animations/DOG.bhd")
	for _i in range(1, header.num_balls): source += "10, 45, -1, 0, -1, 0, 4, 3\r\n"
	tree._save_binary_lnz(source, "breed", {"BANANA.bmp": _bmp(206)})
	var expected_path: String = tree.user_file_location.plus_file("breed.lnz")
	assert_eq(text_editor.filepath, expected_path)
	assert_eq(generator.last_loaded_filepath, expected_path, "Import must render the newly loaded LNZ without requiring Apply Changes.")
	if generator.last_loaded_filepath == expected_path:
		assert_eq(generator.lnz.texture_list.size(), 4, "Short texture entries must retain their indices.")
		assert_eq(generator.lnz.balls[0].texture_id, 3)
		var ball: Spatial = generator.ball_map[0]
		var material: ShaderMaterial = ball.get_node("MeshInstance").material_override
		assert_true(material.get_shader_param("has_texture"))
		var texture: Texture = material.get_shader_param("ball_texture")
		assert_eq(Array(texture.get_data().get_data()), [206])
		text_editor.text = text_editor.text.replace("BANANA.bmp", "hair10.bmp")
		text_editor._on_ApplyChangesButton_pressed()
		assert_eq(generator.lnz.texture_list[3].filename, "hair10.bmp")
		assert_true(generator.ball_map[0].texture is AtlasTexture, "Applying an edit must replace the embedded texture with the stock texture.")
	tree._delete_dir_recursive(tree.user_file_location)
	editor.queue_free()
	yield(get_tree(), "idle_frame")

func test_embedded_texture_indices_survive_gpu_red_channel_sampling():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_gpu_" + str(OS.get_ticks_usec())
	var bytes: PoolByteArray = _put(_bmp(160), 18, 4)
	var expected: Array = [160, 206, 211, 253]
	for x in range(4): bytes[1078 + x] = expected[x]
	tree._save_binary_lnz("[Texture List]\n\\art\\textures\\BANANA.bmp 2 256 256\n", "breed", {"BANANA.bmp": bytes})
	var generator = preload("res://scenes/dog_generator.gd").new()
	generator.last_loaded_filepath = tree.saved_path
	var texture: Texture = generator.load_texture("\\art\\textures\\BANANA.bmp", null)
	# Check what the shader samples, rather than the CPU copy of the image.
	var viewport: Viewport = Viewport.new()
	viewport.size = Vector2(64, 16)
	viewport.usage = Viewport.USAGE_2D
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	get_tree().root.add_child(viewport)
	var rect: ColorRect = ColorRect.new()
	rect.rect_size = viewport.size
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D index_texture; void fragment() { float value = texture(index_texture, UV).r; COLOR = vec4(value, value, value, 1.0); }"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_param("index_texture", texture)
	rect.material = material
	viewport.add_child(rect)
	yield(VisualServer, "frame_post_draw")
	yield(VisualServer, "frame_post_draw")
	var rendered: Image = viewport.get_texture().get_data()
	rendered.lock()
	var sampled: Array = []
	for x in range(4): sampled.append(int(round(rendered.get_pixel(x * 16 + 8, 8).r * 255)))
	rendered.unlock()
	assert_eq(sampled, expected, "GPU red-channel sampling must preserve the embedded BMP's exact palette indices.")
	viewport.queue_free()
	tree._delete_dir_recursive(tree.user_file_location)
	generator.free()
	tree.free()
	yield(get_tree(), "idle_frame")
