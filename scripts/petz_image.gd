tool
extends Reference

# Stock Godot 3 replacement for the fork's extended Image.load().
# Kept independent of LnzLiveUtils so editor imports need no imported resources.
static func load_image(image: Image, path: String, force_palette: bool = false, indexed: bool = false) -> int:
	if path.get_extension().to_lower() != "bmp":
		return image.load(path)
	var file: File = File.new()
	var err: int = file.open(path, File.READ)
	if err != OK:
		return err
	var bytes: PoolByteArray = file.get_buffer(file.get_len())
	file.close()
	return load_bmp(image, bytes, force_palette, indexed)

static func _u16(bytes: PoolByteArray, offset: int) -> int:
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8)

static func _u32(bytes: PoolByteArray, offset: int) -> int:
	return _u16(bytes, offset) | (_u16(bytes, offset + 2) << 16)

static func load_bmp(image: Image, bytes: PoolByteArray, force_palette: bool = false, indexed: bool = false) -> int:
	if bytes.size() < 54 or bytes[0] != 66 or bytes[1] != 77:
		return ERR_FILE_CORRUPT
	var header: int = _u32(bytes, 14)
	var offset: int = _u32(bytes, 10)
	if header < 40 or header > bytes.size() - 14:
		return ERR_FILE_CORRUPT
	var width: int = _u32(bytes, 18)
	var height: int = _u32(bytes, 22)
	if height & 0x80000000:
		height -= 0x100000000
	var bottom_up: bool = height > 0
	height = abs(height)
	var bpp: int = _u16(bytes, 28)
	if _u16(bytes, 26) != 1 or width <= 0 or width > 65535 or height <= 0 or height > 65535:
		return ERR_FILE_CORRUPT
	if _u32(bytes, 30) != 0 or not bpp in [1, 4, 8, 24, 32] or (indexed and bpp != 8):
		return ERR_UNAVAILABLE
	var stride: int = int((width * bpp + 31) / 32) * 4
	if offset < 14 + header or offset > bytes.size() or height > int((bytes.size() - offset) / stride):
		return ERR_FILE_CORRUPT
	var palette: Array = []
	var mapping: Array = []
	if bpp <= 8:
		var count: int = _u32(bytes, 46)
		if count == 0:
			count = 1 << bpp
		if count > (1 << bpp) or 14 + header + count * 4 > offset:
			return ERR_FILE_CORRUPT
		for i in range(count):
			var pos: int = 14 + header + i * 4
			palette.append(Color(bytes[pos + 2] / 255.0, bytes[pos + 1] / 255.0, bytes[pos] / 255.0))
			mapping.append(i)
		if force_palette:
			var target: Image = Image.new()
			var err: int = _load_palette(target)
			if err != OK:
				return err
			if target.get_width() < 256 or target.get_height() < 1:
				return ERR_FILE_CORRUPT
			target.lock()
			var colors: Array = []
			for i in range(256):
				colors.append(_linear(target.get_pixel(i, 0)))
			for i in range(count):
				var source: Color = _linear(palette[i])
				var best: int = i
				var distance: float = _distance(source, colors[i])
				# Start at the original index to preserve duplicate palette entries.
				for step in range(1, 256):
					if distance == 0.0:
						break
					var candidate: int = (i + step) % 256
					var diff: float = _distance(source, colors[candidate])
					if diff < distance:
						distance = diff
						best = candidate
				mapping[i] = best
				palette[i] = target.get_pixel(best, 0)
			target.unlock()
	var channels: int = 1 if indexed else 4
	var pixels: PoolByteArray = PoolByteArray()
	pixels.resize(width * height * channels)
	for y in range(height):
		var row: int = offset + (height - 1 - y if bottom_up else y) * stride
		for x in range(width):
			var dest: int = (y * width + x) * channels
			if bpp <= 8:
				var bit: int = x * bpp
				var index: int = (int(bytes[row + int(bit / 8)]) >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
				if index >= palette.size():
					return ERR_FILE_CORRUPT
				if indexed:
					pixels[dest] = mapping[index]
				else:
					var color: Color = palette[index]
					pixels[dest] = int(round(color.r * 255))
					pixels[dest + 1] = int(round(color.g * 255))
					pixels[dest + 2] = int(round(color.b * 255))
					pixels[dest + 3] = 255
			else:
				var pos: int = row + x * int(bpp / 8)
				pixels[dest] = bytes[pos + 2]
				pixels[dest + 1] = bytes[pos + 1]
				pixels[dest + 2] = bytes[pos]
				pixels[dest + 3] = bytes[pos + 3] if bpp == 32 else 255
	image.create_from_data(width, height, false, Image.FORMAT_R8 if indexed else Image.FORMAT_RGBA8, pixels)
	return OK

static func _distance(a: Color, b: Color) -> float:
	return abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b)

static func _linear(color: Color) -> Color:
	return Color(_linear_channel(color.r), _linear_channel(color.g), _linear_channel(color.b))

static func _linear_channel(value: float) -> float:
	return value / 12.92 if value < 0.04045 else pow((value + 0.055) / 1.055, 2.4)

static func _load_palette(image: Image) -> int:
	# Read source bytes during import; exported builds use the imported texture.
	var file: File = File.new()
	if file.open("res://resources/textures/petzpalette.png", File.READ) == OK:
		var bytes: PoolByteArray = file.get_buffer(file.get_len())
		file.close()
		return image.load_png_from_buffer(bytes)
	var texture = load("res://resources/textures/petzpalette.png")
	if not texture is Texture:
		return ERR_CANT_OPEN
	var source: Image = texture.get_data()
	if source == null or source.empty():
		return ERR_CANT_OPEN
	image.copy_from(source)
	return OK
