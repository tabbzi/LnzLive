extends GutTest

const Importer = preload("res://data_classes/lnz_importer.gd")
const LNZ = "[Ballz Info]\r\n0, 0, 0, 1\r\n"
const TEST_DIR = "user://test_import_tmp"

var tree: ImportTree

# Exercise storage without rebuilding editor tree or model
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

func before_each():
	var dir: Directory = Directory.new()
	if dir.dir_exists(TEST_DIR):
		_delete_dir_recursive(dir, TEST_DIR)
	tree = ImportTree.new()
	tree.user_file_location = TEST_DIR
	autofree(tree)

func after_each():
	var dir: Directory = Directory.new()
	if dir.dir_exists(TEST_DIR):
		_delete_dir_recursive(dir, TEST_DIR)

func _delete_dir_recursive(dir: Directory, path: String) -> void:
	if dir.open(path) == OK:
		dir.list_dir_begin(true, true)
		var entry: String = dir.get_next()
		while not entry.empty():
			var full: String = path.plus_file(entry)
			if dir.current_is_dir():
				_delete_dir_recursive(dir, full)
			else:
				dir.remove(full)
			entry = dir.get_next()
		dir.list_dir_end()
		dir.remove(path)

func _put(bytes: PoolByteArray, offset: int, value: int, width: int = 4) -> PoolByteArray:
	for i in range(width): bytes[offset + i] = (value >> (i * 8)) & 255
	return bytes

func _string(bytes: PoolByteArray, offset: int, text: String) -> PoolByteArray:
	var encoded: PoolByteArray = text.to_ascii()
	for i in range(encoded.size()): bytes[offset + i] = encoded[i]
	return bytes

func _bmp(index: int, width: int = 1, height: int = 1) -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	var row_size: int = int((width + 3) / 4) * 4
	var pixel_offset: int = 54 + 4 * 256
	bytes.resize(pixel_offset + row_size * height)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _put(bytes, 0, 0x4d42, 2)
	bytes = _put(bytes, 2, bytes.size())
	bytes = _put(bytes, 10, pixel_offset)
	bytes = _put(bytes, 14, 40)
	bytes = _put(bytes, 18, width, 4)
	bytes = _put(bytes, 22, height, 4)
	bytes = _put(bytes, 26, 1, 2)
	bytes = _put(bytes, 28, 8, 2)
	bytes = _put(bytes, 34, row_size * height)
	var palette: Array = LnzLiveUtils.extract_palette_from_image(LnzLiveUtils.DEFAULT_PALETTE)
	for i in range(256):
		bytes[54 + i * 4] = int(round(palette[i].b * 255))
		bytes[55 + i * 4] = int(round(palette[i].g * 255))
		bytes[56 + i * 4] = int(round(palette[i].r * 255))
	for i in range(row_size * height):
		bytes[pixel_offset + i] = index
	return bytes

func _pet(adult: String = LNZ, juvenile: String = LNZ, version: int = 0x0acb0002) -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	var header: int = 816 if version == 0x0acb0002 else 800
	var pos: int = header + 17 + 1 + 24 + 8 + 1 + 32 + 2400 + 36 + 4 + 6 + 12 + 4
	bytes.resize(pos + 17)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _put(bytes, 0x318, version)
	bytes = _string(bytes, header, "p.f.magicpetzIII")
	bytes = _string(bytes, pos, "p.f.magicpetzIII")
	for text in [adult, juvenile]:
		bytes.append_array(text.to_ascii())
		bytes.append_array(PoolByteArray([0, 0xaa, 0xcc, 0xbb, 3]))
	return bytes

func _baby(adult: String = LNZ, juvenile: String = LNZ) -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	bytes.resize(0x1B10)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _string(bytes, 0x435, "pfmagic")
	for text in [adult, juvenile]:
		bytes.append_array(text.to_ascii())
		bytes.append_array(PoolByteArray([0, 0xaa, 0xcc, 0xbb, 3]))
	return bytes

func _breed() -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	bytes.resize(1024)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _put(bytes, 0, 0x5a4d, 2)
	bytes = _put(bytes, 0x3c, 64)
	bytes = _put(bytes, 64, 0x4550)
	bytes = _put(bytes, 70, 1, 2)
	bytes = _put(bytes, 84, 224, 2)
	bytes = _put(bytes, 88, 0x10b, 2)
	bytes = _put(bytes, 180, 16)
	bytes = _put(bytes, 200, 0x1000)
	bytes = _put(bytes, 204, 512)
	bytes = _put(bytes, 324, 0x1000)
	bytes = _put(bytes, 328, 512)
	bytes = _put(bytes, 332, 512)
	bytes = _put(bytes, 524, 1, 2)
	bytes = _put(bytes, 528, 0x80000080)
	bytes = _put(bytes, 532, 0x80000020)
	bytes = _put(bytes, 556, 1, 2)
	bytes = _put(bytes, 560, 0x80000090)
	bytes = _put(bytes, 564, 0x80000040)
	bytes = _put(bytes, 590, 1, 2)
	bytes = _put(bytes, 592, 1033)
	bytes = _put(bytes, 596, 0x60)
	bytes = _put(bytes, 608, 0x1100)
	bytes = _put(bytes, 612, LNZ.length())
	bytes = _put(bytes, 640, 3, 2)
	for i in range(3): bytes = _put(bytes, 642 + i * 2, "LNZ".ord_at(i), 2)
	bytes = _put(bytes, 656, 2, 2)
	bytes = _put(bytes, 658, 65, 2)
	bytes = _put(bytes, 660, 68, 2)
	return _string(bytes, 768, LNZ)

func _breed_with_texture() -> PoolByteArray:
	var bytes: PoolByteArray = _breed()
	bytes = _put(bytes, 524, 2, 2)
	bytes = _put(bytes, 536, 0x80000098)
	bytes = _put(bytes, 540, 0x800000a0)
	bytes = _put(bytes, 664, 3, 2)
	for i in range(3): bytes = _put(bytes, 666 + i * 2, "BMP".ord_at(i), 2)
	bytes = _put(bytes, 684, 1, 2)
	bytes = _put(bytes, 688, 0x80000090)
	bytes = _put(bytes, 692, 0x800000c0)
	bytes = _put(bytes, 718, 1, 2)
	bytes = _put(bytes, 720, 1033)
	bytes = _put(bytes, 724, 0xe0)
	bytes = _put(bytes, 736, 0x1180)
	bytes = _put(bytes, 740, 6)
	for i in range(6): bytes[896 + i] = [66, 77, 0, 128, 254, 255][i]
	return bytes

func test_pet_and_babyz_extraction():
	var importer = Importer.new()
	var pet: PoolByteArray = _string(_pet(), 0x202, "C:\\Petz\\Resource\\Dogz\\CustomBreed.dog")
	var entries: Array = importer.extract(pet, true)
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].text, LNZ)
	assert_eq(entries[1].name, "Juvenile")
	assert_eq(importer.breed_file, "CustomBreed.dog")

	# Non-empty PetSavedColorInfo array + invalid terminator rejection
	var count_offset: int = 816 + 17 + 1 + 24 + 8 + 1 + 32 + 2400 + 36 + 4 + 6
	var with_colors: PoolByteArray = pet.subarray(0, count_offset + 3)
	with_colors = _put(with_colors, count_offset, 3)
	with_colors.append_array(PoolByteArray([8, 9, 10]))
	with_colors.append_array(pet.subarray(count_offset + 4, pet.size() - 1))
	assert_eq(importer.extract(with_colors, true).size(), 2)
	with_colors[with_colors.size() - 1] = 0
	assert_true(importer.extract(with_colors, true).empty())

	# Version 0x0acb0001 (800-byte header) + empty Adult cache skipped
	entries = importer.extract(_pet("", LNZ, 0x0acb0001), true)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].name, "Juvenile")

	# Babyz (.baby) extraction
	entries = importer.extract(_baby(), true)
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].text, LNZ)
	assert_true(importer.is_babyz)
	assert_eq(importer.breed_file, "")

func test_breed_extraction_and_corrupt_rejection():
	var importer = Importer.new()
	var entries: Array = importer.extract(_breed_with_texture(), false)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].name, "AD (1033)")
	assert_eq(entries[0].text, LNZ)
	assert_eq(Array(importer.textures.get("AD.bmp", [])), [66, 77, 0, 128, 254, 255])

	var bad_inputs: Array = [
		[PoolByteArray(), false],
		[_breed().subarray(0, 500), false],
		[_put(_breed(), 608, 0x999999), false],
		[_put(_breed(), 596, 0x80000000), false],
		[_pet("", ""), true]
	]
	for item in bad_inputs:
		assert_true(importer.extract(item[0], item[1]).empty())
		assert_true(importer.textures.empty())
		assert_ne(importer.error, "")

func test_storage_reuse_and_sidecar_files():
	var bytes: PoolByteArray = _bmp(255)
	var source: String = "[Texture List]\r\n\\art\\textures\\AD.BMP 1 256 256\r\n"
	var entries: Array = [{"name": "Adult", "text": source}, {"name": "Juvenile", "text": source}]
	tree._save_binary_lnz(entries, "breed", {"Ad.BmP": bytes}, "", false, "/games/breed.dog")
	var texture_path: String = TEST_DIR.plus_file("textures/Ad.BmP")
	assert_true(tree._texture_bytes_match(texture_path, bytes))

	# Verify Adult, Juvenile (_child.lnz), and JSON sidecar written
	var dir: Directory = Directory.new()
	assert_true(dir.file_exists(TEST_DIR.plus_file("breed/breed.lnz")))
	assert_true(dir.file_exists(TEST_DIR.plus_file("breed/breed_child.lnz")))
	var sidecar: File = File.new()
	assert_eq(sidecar.open(TEST_DIR.plus_file("breed/breed.json"), File.READ), OK)
	sidecar.seek(0)
	var json_text: String = sidecar.get_as_text()
	sidecar.close()
	var parsed: JSONParseResult = JSON.parse(json_text)
	assert_eq(parsed.error, OK, "Sidecar JSON must parse successfully: " + json_text)
	assert_eq(parsed.result.get("source_path", ""), "/games/breed.dog")
	assert_eq(parsed.result.get("files", []), ["breed.lnz", "breed_child.lnz"])

	# Identical texture bytes with different case trigger no conflict dialog and increment LNZ suffix
	tree._save_binary_lnz([{"name": "Adult", "text": source}], "breed", {"AD.BMP": bytes}, "", false, "test.breed")
	assert_eq(tree.saved_path, TEST_DIR.plus_file("breed/breed_2.lnz"))
	assert_null(tree.conflict_dialog)

	# Later pet import resolves shared texture; scoped legacy textures still take precedence
	tree._save_binary_lnz([{"name": "Adult", "text": source}], "pet", {}, "", false, "test.pet")
	assert_eq(LnzLiveUtils.resolve_user_texture("/art/textures/ad.bmp", tree.saved_path).to_lower(), texture_path.to_lower())
	var scoped: String = LnzLiveUtils.imported_texture_directory(tree.saved_path)
	dir.make_dir_recursive(scoped)
	var scoped_file: File = File.new()
	assert_eq(scoped_file.open(scoped.plus_file("ad.bmp"), File.WRITE), OK)
	scoped_file.store_buffer(_bmp(101))
	scoped_file.close()
	assert_eq(LnzLiveUtils.resolve_user_texture("ad.bmp", tree.saved_path), scoped.plus_file("ad.bmp"))

func test_texture_conflict_resolution_and_cancel():
	var original: PoolByteArray = _bmp(100)
	var incoming: PoolByteArray = _bmp(101)
	tree._save_binary_lnz([{"name": "Adult", "text": "adult"}], "breed", {"Coat.bmp": original, "Eyes.bmp": original}, "", false, "test.breed")
	var previous_path: String = tree.saved_path

	# Cancel writes nothing and preserves original texture
	tree._save_binary_lnz([{"name": "Adult", "text": "pet"}], "pet", {"Coat.bmp": incoming, "new.bmp": incoming}, "", false, "test.pet")
	assert_not_null(tree.conflict_dialog)
	tree.conflict_dialog.free()
	tree.conflict_dialog = null
	assert_eq(tree.saved_path, previous_path)
	assert_false(Directory.new().file_exists(TEST_DIR.plus_file("pet/pet.lnz")))
	assert_false(Directory.new().file_exists(TEST_DIR.plus_file("textures/new.bmp")))

	# Selective opt-in overwrite replaces existing case variant in place
	tree._save_binary_lnz([{"name": "Adult", "text": "new"}], "pet", {"COAT.BMP": incoming, "eyes.bmp": incoming, "new.bmp": incoming}, "", false, "test.pet")
	var dialog: ConfirmationDialog = tree.conflict_dialog
	var rows: VBoxContainer = dialog.get_node("ConflictLayout/ConflictScroll/ConflictRows")
	var choices: Dictionary = {}
	for row in rows.get_children():
		var choice: CheckBox = row.get_child(0)
		assert_false(choice.pressed)
		choices[choice.text.replace("Replace ", "")] = choice
	choices["eyes.bmp"].pressed = true
	dialog.emit_signal("confirmed")
	assert_eq(tree.saved_path, TEST_DIR.plus_file("pet/pet.lnz"))
	assert_true(tree._texture_bytes_match(TEST_DIR.plus_file("textures/Coat.bmp"), original))
	assert_true(tree._texture_bytes_match(TEST_DIR.plus_file("textures/Eyes.bmp"), incoming))
	assert_true(tree._texture_bytes_match(TEST_DIR.plus_file("textures/new.bmp"), incoming))
	var dir: Directory = Directory.new()
	assert_eq(dir.open(TEST_DIR.plus_file("textures")), OK)
	dir.list_dir_begin(true, true)
	var entries_list: Array = []
	var entry: String = dir.get_next()
	while not entry.empty():
		if not dir.current_is_dir(): entries_list.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	assert_true("Eyes.bmp" in entries_list)
	assert_false("eyes.bmp" in entries_list)

func test_renderer_and_gpu_red_channel_sampling():
	var bytes: PoolByteArray = _bmp(160, 4, 1)
	var expected: Array = [160, 206, 211, 253]
	for x in range(4): bytes[1078 + x] = expected[x]
	tree._save_binary_lnz([{"name": "Adult", "text": "[Texture List]\n\\art\\textures\\BANANA.bmp 2 256 256\n"}], "breed", {"BANANA.bmp": bytes}, "", false, "test.breed")
	var generator = preload("res://scenes/dog_generator.gd").new()
	autofree(generator)
	generator.last_loaded_filepath = tree.saved_path
	var texture: Texture = generator.load_texture("\\art\\textures\\BANANA.bmp", null)
	assert_not_null(texture)
	generator.clear_texture_cache()
	texture = generator.load_texture("banana.bmp", null)
	assert_not_null(texture, "Shared resources must survive a cache clear.")

	var viewport: Viewport = Viewport.new()
	autofree(viewport)
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
	assert_eq(sampled, expected, "GPU red-channel sampling must preserve exact palette indices.")

func test_babyz_sidecar_and_no_textures():
	# Verify is_babyz = true skips texture extraction and writes PET_BABYZ file_type.
	var baby_source: String = "[Species]\r\n2\r\n"
	tree._save_binary_lnz([{"name": "Adult", "text": baby_source}], "MyBaby", {"Coat.bmp": _bmp(42)}, "", true, "/games/MyBaby.baby")
	# No textures should be written for Babyz imports.
	assert_false(Directory.new().file_exists(TEST_DIR.plus_file("textures/Coat.bmp")), "Babyz must not write textures.")
	# Subfolder created with basename of source file.
	var dir: Directory = Directory.new()
	assert_true(dir.dir_exists(TEST_DIR.plus_file("MyBaby")), "Subfolder must be created.")
	# Sidecar JSON records PET_BABYZ file_type and empty breed_file.
	var sidecar_path: String = TEST_DIR.plus_file("MyBaby/MyBaby.json")
	assert_true(Directory.new().file_exists(sidecar_path), "Sidecar must exist at " + sidecar_path)
	var sidecar: File = File.new()
	assert_eq(sidecar.open(sidecar_path, File.READ), OK)
	sidecar.seek(0)
	var json_text: String = sidecar.get_as_text()
	sidecar.close()
	assert_false(json_text.empty(), "Sidecar must not be empty: " + sidecar_path)
	var parsed: JSONParseResult = JSON.parse(json_text)
	assert_eq(parsed.error, OK, "Sidecar JSON must parse successfully: '" + json_text + "'")
	assert_true(typeof(parsed.result) != TYPE_NIL, "JSON result must not be null: '" + json_text + "'")
	assert_eq(parsed.result.get("file_type", ""), "PET_BABYZ")
	assert_eq(parsed.result.get("breed_file", ""), "")
	assert_true(parsed.result.get("source_path", "").ends_with("MyBaby.baby"))
