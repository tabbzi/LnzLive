extends Node
class_name BhdParser

var animation_ranges = []
var num_balls: int
var file_path: String
var frames_offset: int
var ball_sizes = []

func _init(file_path):
	self.file_path = file_path
	print("Initializing BhdParser with file: ", file_path)
	var file = File.new()
	file.open(file_path, File.READ)
	frames_offset = file.get_16()
	print("Frames Offset: ", frames_offset)
	file.get_32()
	num_balls = file.get_16()
	print("Number of Balls: ", num_balls)
	file.seek(file.get_position() + 30)

	if "baby" in file_path.to_lower():
		for i in range(num_balls):
			ball_sizes.append(file.get_16()) 
			print("Ball Size[", i, "]: ", ball_sizes[i])
		file.seek(438)
	else:
		for i in range(num_balls):
			ball_sizes.append(file.get_16())
			print("Ball Size[", i, "]: ", ball_sizes[i])
	
	var animation_count = file.get_16()
	print("Number of Animations: ", animation_count)
	
	for i in range(animation_count):
		var start = 0
		if i > 0:
			start = animation_ranges[i - 1].end
		var end = file.get_16()
		var num_of_offsets = end - start
		animation_ranges.append({num_of_offsets = num_of_offsets, end = end, start = frames_offset + (start * 4), actual_start = start})
		#print("Animation Range[", i, "]: start=", start, ", end=", end, ", num_of_offsets=", num_of_offsets)
	
	file.close()

func get_frame_offsets_for(index: int):
	print("Getting frame offsets for animation index: ", index)
	var result = []

	if index >= animation_ranges.size():
		print("Invalid index: ", index, ". Returning empty result.")
		return result

	var anim_range = animation_ranges[index]
	print("Animation range: ", anim_range)

	var num_of_offsets = anim_range.num_of_offsets
	print("Number of offsets for animation: ", num_of_offsets)

	var file = File.new()
	file.open(file_path, File.READ)

	file.seek(anim_range.start)
	for i in range(num_of_offsets):
		var offset = file.get_32()
		result.append(offset)
		print("Offset[", i, "]: ", offset)

	file.close()
	return result

