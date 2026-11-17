extends GutTest

# Exercise storage without rebuilding the editor's tree or model.
class ImportTree:
	extends "res://scenes/editor/FileTree.gd"
	var saved_path: String = ""
	var failure: String = ""
	func rescan_textures(_reload_model: bool = false) -> void:
		pass
	func rescan_with_extension(_extension: String, path: String = "") -> void:
		saved_path = path
	func _binary_import_error(message: String) -> void:
		failure = message

func test_embedded_textures_persist_without_overwriting_existing_imports():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_import_" + str(OS.get_ticks_usec())
	var bytes: PoolByteArray = PoolByteArray([66, 77, 0, 128, 255])
	var source: String = "[Texture List]\r\n\\art\\textures\\AD.BMP 1 256 256\r\n"
	var paths: Array = []
	var texture_dirs: Array = []
	for i in range(2):
		bytes[4] = 254 + i
		tree._save_binary_lnz(source, "sample", {"Ad.BmP": bytes})
		assert_eq(tree.failure, "")
		var file: File = File.new()
		assert_eq(file.open(tree.saved_path, File.READ), OK)
		var text: String = file.get_buffer(file.get_len()).get_string_from_utf8()
		file.close()
		assert_eq(text, source, "Import must preserve every byte of the LNZ, including paths.")
		var texture_dir: String = LnzLiveUtils.imported_texture_directory(tree.saved_path)
		texture_dirs.append(texture_dir)
		var texture_path: String = texture_dir.plus_file("Ad.BmP")
		assert_eq(LnzLiveUtils.resolve_user_texture("\\art\\textures\\AD.BMP", tree.saved_path), texture_path)
		assert_eq(LnzLiveUtils.resolve_user_texture("/art/textures/ad.bmp", tree.saved_path), texture_path)
		assert_eq(file.open(texture_path, File.READ), OK)
		assert_eq(Array(file.get_buffer(file.get_len())), Array(bytes))
		file.close()
		paths.append(tree.saved_path)
		paths.append(texture_path)
	# Both imports must remain available independently.
	assert_ne(paths[0], paths[2])
	var dir: Directory = Directory.new()
	for path in paths:
		assert_true(dir.file_exists(path))
		dir.remove(path)
	for texture_dir in texture_dirs: dir.remove(texture_dir)
	dir.remove(tree.user_file_location.plus_file("textures"))
	dir.remove(tree.user_file_location)
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

func test_renderer_resolves_original_paths_before_stock_atlas_and_scopes_cache():
	var tree = ImportTree.new()
	tree.user_file_location = "user://test_binary_render_" + str(OS.get_ticks_usec())
	var generator = preload("res://scenes/dog_generator.gd").new()
	# A stock atlas entry with the same name must lose to an embedded resource.
	var stock_image: Image = Image.new()
	stock_image.create(1, 1, false, Image.FORMAT_L8)
	stock_image.fill(Color(0, 0, 0))
	var stock_texture: ImageTexture = ImageTexture.new()
	stock_texture.create_from_image(stock_image, 0)
	generator._atlas_manifest = {"sharedcoat": {"petz_atlas": "test.png", "x": 0, "y": 0, "w": 1, "h": 1}}
	generator._atlas_textures = {"res://resources/texture_atlas/test.png": stock_texture}
	var paths: Array = []
	var source: String = "[Texture List]\r\n\\art\\textures\\sharedcoat.bmp 1 256 256\r\n"
	for i in range(2):
		tree._save_binary_lnz(source, "sample", {"SharedCoat.BmP": _bmp(100 + i)})
		assert_eq(tree.failure, "")
		paths.append(tree.saved_path)
		generator.last_loaded_filepath = tree.saved_path
		var parser = LnzParser.new(tree.saved_path)
		parser.get_texture_list(parser.compile_section("Texture List", [0]))
		assert_eq(parser.texture_list[0].filename, "sharedcoat.bmp")
		var texture: Texture = generator.load_texture_from_list(0, parser.texture_list)
		assert_not_null(texture)
		assert_false(texture is AtlasTexture, "Embedded BMP must take precedence over stock atlas.")
		var image: Image = texture.get_data()
		assert_eq(image.get_width(), 1)
		assert_eq(Array(image.get_data()), [100 + i], "Renderer must receive this import's palette indices.")
		var ball: Spatial = generator.ball_scene.instance()
		get_tree().root.add_child(ball)
		var ball_data = BallData.new(10, Vector3.ZERO, 0)
		ball_data.texture_id = 0
		generator.apply_visual_properties(ball, ball_data, parser.texture_list, LnzLiveUtils.DEFAULT_PALETTE)
		var material: ShaderMaterial = ball.get_node("MeshInstance").material_override
		assert_eq(material.get_shader_param("ball_texture"), texture, "Imported image must reach the ball shader.")
		assert_true(material.get_shader_param("has_texture"))
		assert_false(material.get_shader_param("is_atlas"))
		ball.free()
	# Reloading an earlier import must not reuse the other breed's texture.
	generator.last_loaded_filepath = paths[0]
	var first: Texture = generator.load_texture("/art/textures/sharedcoat.bmp", null)
	assert_eq(Array(first.get_data().get_data()), [100])
	generator.clear_texture_cache()
	first = generator.load_texture("/art/textures/sharedcoat.bmp", null)
	assert_eq(Array(first.get_data().get_data()), [100], "Rebuilding must resolve persisted resources.")
	generator.last_loaded_filepath = ""
	assert_true(generator.load_texture("sharedcoat.bmp", null) is AtlasTexture, "Unrelated models retain stock textures.")
	var dir: Directory = Directory.new()
	for path in paths:
		var texture_dir: String = LnzLiveUtils.imported_texture_directory(path)
		dir.remove(texture_dir.plus_file("SharedCoat.BmP"))
		dir.remove(texture_dir)
		dir.remove(path)
	dir.remove(tree.user_file_location.plus_file("textures"))
	dir.remove(tree.user_file_location)
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
