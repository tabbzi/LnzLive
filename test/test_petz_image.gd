extends "res://addons/gut/test.gd"

const Loader = preload("res://scripts/petz_image.gd")
const Importer = preload("res://addons/petz_texture/importer.gd")

func _bmp(top_down: bool = false) -> PoolByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.big_endian = false
	stream.put_u16(0x4d42)
	stream.put_u32(1086)
	stream.put_u32(0)
	stream.put_u32(1078)
	stream.put_u32(40)
	stream.put_u32(3)
	stream.put_32(-2 if top_down else 2)
	stream.put_u16(1)
	stream.put_u16(8)
	stream.put_u32(0)
	stream.put_u32(8)
	for _i in range(4):
		stream.put_u32(0)
	for i in range(256):
		stream.put_u8(i)
		stream.put_u8(i)
		stream.put_u8(i)
		stream.put_u8(0)
	for i in [1, 2, 3, 99, 4, 5, 6, 99]:
		stream.put_u8(i)
	return stream.data_array

func test_rows_padding_and_top_down():
	for top_down in [false, true]:
		var image: Image = Image.new()
		assert_eq(Loader.load_bmp(image, _bmp(top_down), false, true), OK)
		assert_eq(image.get_format(), Image.FORMAT_R8)
		var expected: PoolByteArray = PoolByteArray([1, 2, 3, 4, 5, 6] if top_down else [4, 5, 6, 1, 2, 3])
		assert_eq(image.get_data(), expected)

func test_thumbnail_uses_bmp_colors():
	var image: Image = Image.new()
	assert_eq(Loader.load_bmp(image, _bmp()), OK)
	image.lock()
	assert_almost_eq(image.get_pixel(0, 0).r, 4.0 / 255, 0.0001)
	assert_eq(image.get_pixel(0, 0).a, 1.0)
	image.unlock()

func test_rejects_truncation_compression_and_bad_indices():
	var bytes: PoolByteArray = _bmp()
	bytes.resize(bytes.size() - 1)
	assert_eq(Loader.load_bmp(Image.new(), bytes), ERR_FILE_CORRUPT)
	bytes = _bmp()
	bytes[30] = 1
	assert_eq(Loader.load_bmp(Image.new(), bytes), ERR_UNAVAILABLE)
	bytes = _bmp()
	bytes[46] = 2
	assert_eq(Loader.load_bmp(Image.new(), bytes), ERR_FILE_CORRUPT)

func test_duplicate_palette_indices_survive():
	var file: File = File.new()
	assert_eq(file.open("res://resources/textures/petzpalette.png", File.READ), OK)
	var palette: Image = Image.new()
	assert_eq(palette.load_png_from_buffer(file.get_buffer(file.get_len())), OK)
	file.close()
	palette.lock()
	var bytes: PoolByteArray = _bmp()
	for i in range(256):
		var color: Color = palette.get_pixel(i, 0)
		bytes[54 + i * 4] = int(round(color.b * 255))
		bytes[55 + i * 4] = int(round(color.g * 255))
		bytes[56 + i * 4] = int(round(color.r * 255))
	palette.unlock()
	var image: Image = Image.new()
	assert_eq(Loader.load_bmp(image, bytes, true, true), OK)
	assert_eq(image.get_data(), PoolByteArray([4, 5, 6, 1, 2, 3]))
	# A deliberately foreign palette color must map to its exact Petz match.
	for channel in range(3):
		bytes[54 + 4 * 4 + channel] = bytes[54 + 100 * 4 + channel]
	assert_eq(Loader.load_bmp(image, bytes, true, true), OK)
	assert_eq(image.get_data()[0], 100)

func test_stream_texture_round_trip():
	var image: Image = Image.new()
	assert_eq(Loader.load_bmp(image, _bmp(), false, true), OK)
	var path: String = "user://petz_image_test.stex"
	assert_eq(Importer.save_texture(image, path), OK)
	var texture: StreamTexture = StreamTexture.new()
	assert_eq(texture.load(path), OK)
	assert_eq(texture.get_width(), 3)
	assert_eq(texture.get_height(), 2)
	assert_eq(texture.flags, Texture.FLAG_REPEAT)
	Directory.new().remove(path)
