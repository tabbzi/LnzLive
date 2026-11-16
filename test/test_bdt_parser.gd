extends "res://addons/gut/test.gd"

const Parser = preload("res://data_classes/bdt_parser.gd")
const Header = preload("res://data_classes/bhd_parser.gd")

func test_signed_read_boundaries():
	var path: String = "user://bdt_signed_test.bin"
	var file: File = File.new()
	assert_eq(file.open(path, File.WRITE), OK)
	for value in [0, 127, 128, 255]:
		file.store_8(value)
	for value in [0, 32767, 32768, 65535]:
		file.store_16(value)
	file.close()
	assert_eq(file.open(path, File.READ), OK)
	for value in [0, 127, -128, -1]:
		assert_eq(Parser._read_s8(file), value)
	for value in [0, 32767, -32768, -1]:
		assert_eq(Parser._read_s16(file), value)
	assert_eq(file.get_position(), 12)
	file.close()
	Directory.new().remove(path)

func test_bundled_species_animation_frames():
	for species in ["DOG", "CAT", "BABY"]:
		var header = Header.new("res://resources/animations/" + species + ".bhd")
		var offsets: Array = header.get_frame_offsets_for(0)
		assert_gt(offsets.size(), 0, species)
		var parser = Parser.new(species + "0.bdt", offsets, header.num_balls)
		assert_eq(parser.frames.size(), offsets.size(), species)
		var file: File = File.new()
		assert_eq(file.open("res://resources/animations/" + species + "0.bdt", File.READ), OK)
		var stream: StreamPeerBuffer = StreamPeerBuffer.new()
		stream.big_endian = false
		stream.data_array = file.get_buffer(file.get_len())
		file.close()
		# StreamPeerBuffer has stock signed reads; compare every ball in the
		# first and last frames against that independent binary decoder.
		for frame in [0, offsets.size() - 1]:
			stream.seek(offsets[frame] + 12)
			var tag: int = stream.get_u16()
			assert_eq(parser.frames[frame].size(), header.num_balls)
			for ball in parser.frames[frame]:
				var position: Vector3 = Vector3(stream.get_16(), stream.get_16(), stream.get_16())
				var rotation: Vector3 = Vector3(stream.get_8(), stream.get_8(), stream.get_8())
				stream.get_8()
				assert_eq(ball.tag, tag)
				assert_eq(ball.position, position)
				assert_eq(ball.rotation, rotation)
