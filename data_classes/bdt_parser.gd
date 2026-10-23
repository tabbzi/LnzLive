extends Reference
class_name BdtParser
## bdt_parser.gd
## A parser for `.bdt` animation files
## This class reads binary `.bdt` files, which contain animation frame data for
## models and extracts position and rotation for each ball for specified frames

var frames = []

const MAX_FRAME_INDEXES: int = 10000
const MAX_BALLS_PER_FRAME: int = 256
const HEADER_SKIP_BYTES: int = 12  # 6 * get_16()

func _init(filename: String, frame_indexes: Array, balls_num: int):
	frames = []

	if frame_indexes.size() > MAX_FRAME_INDEXES:
		print("[ERROR] BdtParser: too many frame_indexes: ", frame_indexes.size())
		return

	if balls_num < 0 or balls_num > MAX_BALLS_PER_FRAME:
		print("[ERROR] BdtParser: invalid balls_num: ", balls_num)
		return

	var file = File.new()
	var full_path = "res://resources/animations/" + filename
	var open_err = file.open(full_path, File.READ)
	if open_err != OK:
		print("[ERROR] BdtParser: failed to open file: ", full_path, " error: ", open_err)
		return

	var file_len = file.get_len()
	if file_len < HEADER_SKIP_BYTES:
		print("[ERROR] BdtParser: file too small: ", full_path, " (", file_len, " bytes)")
		file.close()
		return

	for frame_offset in frame_indexes:
		if frame_offset < 0 or frame_offset >= file_len:
			print("[WARNING] BdtParser: frame_offset out of bounds: ", frame_offset, " (file size: ", file_len, ")")
			continue

		file.seek(frame_offset)
		if file.eof_reached():
			print("[WARNING] BdtParser: EOF at frame_offset ", frame_offset)
			break

		# Skip 6 * 16-bit header values (12 bytes)
		var header_bytes_read = 0
		var header_valid = true
		for i in 6:
			if file.eof_reached():
				header_valid = false
				break
			file.get_16()
			header_bytes_read += 2

		if not header_valid:
			print("[WARNING] BdtParser: EOF reading header at frame ", frame_offset)
			break

		if file.eof_reached():
			print("[WARNING] BdtParser: EOF after header at frame ", frame_offset)
			break

		var tag = file.get_16()
		if file.eof_reached():
			print("[WARNING] BdtParser: EOF reading tag at frame ", frame_offset)
			break

		var balls = []
		for ball in balls_num:
			var x = file.get_s16()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading ball x at frame ", frame_offset, " ball ", ball)
				break
			var y = file.get_s16()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading ball y at frame ", frame_offset, " ball ", ball)
				break
			var z = file.get_s16()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading ball z at frame ", frame_offset, " ball ", ball)
				break
			var rot1 = file.get_s8()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading rot1 at frame ", frame_offset, " ball ", ball)
				break
			var rot2 = file.get_s8()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading rot2 at frame ", frame_offset, " ball ", ball)
				break
			var rot3 = file.get_s8()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading rot3 at frame ", frame_offset, " ball ", ball)
				break
			var _tag3 = file.get_s8()
			if file.eof_reached():
				print("[WARNING] BdtParser: EOF reading tag3 at frame ", frame_offset, " ball ", ball)
				break

			balls.append(
				{
					tag = tag,
					position = Vector3(x, y, z),
					rotation = Vector3(rot1, rot2, rot3)
				}
			)

		if balls.size() == balls_num:
			frames.append(balls)
		else:
			print("[WARNING] BdtParser: incomplete frame at offset ", frame_offset, " (got ", balls.size(), " of ", balls_num, " balls)")

	file.close()
