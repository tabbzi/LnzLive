extends Reference
class_name BdtParser
## bdt_parser.gd
## A parser for `.bdt` animation files
## This class reads binary `.bdt` files, which contain animation frame data for
## models and extracts position and rotation for each ball for specified frames

var frames = []

func _init(filename: String, frame_indexes: Array, balls_num: int):
	var file = File.new()
	file.open("res://resources/animations/"+filename, File.READ)
	for frame_offset in frame_indexes:
		file.seek(frame_offset)
		for i in 6:
			var _spec = file.get_16()
		var tag = file.get_16()
		var balls = []
		for ball in balls_num:
			var x = _read_s16(file)
			var y = _read_s16(file)
			var z = _read_s16(file)
			var rot1 = _read_s8(file)
			var rot2 = _read_s8(file)
			var rot3 = _read_s8(file)
			var _tag3 = _read_s8(file)
			balls.append(
				{
					tag = tag,
					position = Vector3(x, y, z),
					rotation = Vector3(rot1, rot2, rot3)
				}
			)
		frames.append(balls)
	file.close()

# Stock Godot File exposes unsigned reads only. BDT coordinates and rotations
# use two's-complement signed integers; preserve the full negative ranges.
static func _read_s16(file: File) -> int:
	var value: int = file.get_16()
	return value - 65536 if value >= 32768 else value

static func _read_s8(file: File) -> int:
	var value: int = file.get_8()
	return value - 256 if value >= 128 else value
