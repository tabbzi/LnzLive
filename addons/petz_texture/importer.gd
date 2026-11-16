tool
extends EditorImportPlugin

func get_importer_name():
	return "PetzTexture"

func get_priority():
	return 2.0

func get_visible_name():
	return "Petz Texture"

func get_recognized_extensions():
	return ["bmp"]

func get_save_extension():
	return "stex"

func get_resource_type():
	return "StreamTexture"

func get_preset_count():
	return 0

func get_import_options(_preset):
	return []

func import(source_file, save_path, _options, _platform_variants, _gen_files):
	var image: Image = Image.new()
	var err: int = preload("res://scripts/petz_image.gd").load_image(image, source_file, true, true)
	if err != OK:
		return err
	return save_texture(image, save_path + ".stex")

static func save_texture(image: Image, path: String) -> int:
	# Godot 3's uncompressed StreamTexture format preserves every palette index.
	var file: File = File.new()
	var err: int = file.open(path, File.WRITE)
	if err != OK:
		return err
	file.store_string("GDST")
	file.store_16(image.get_width())
	file.store_16(0)
	file.store_16(image.get_height())
	file.store_16(0)
	file.store_32(Texture.FLAG_REPEAT)
	file.store_32(image.get_format())
	file.store_buffer(image.get_data())
	file.close()
	return OK
