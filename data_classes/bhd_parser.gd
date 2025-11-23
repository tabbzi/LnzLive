extends Node
class_name BhdParser
## bhd_parser.gd
## A parser for `.bhd` animation header files
## This class reads binary `.bdt` files, which contain metadata about animations
## for a model, such as number of ballz, animation ranges, and location of frame
## data in corresponding `.bdt` files

var animation_ranges = []
var num_balls: int
var file_path: String
var frames_offset: int
var ball_sizes = []

func _init(file_path):
	self.file_path = file_path
	#print("Initializing BhdParser with file: ", file_path)
	var file = File.new()
	file.open(file_path, File.READ)
	frames_offset = file.get_16()
	#print("Frames Offset: ", frames_offset)
	file.get_32()
	num_balls = file.get_16()
	#print("Number of Balls: ", num_balls)

	if "baby" in file_path.to_lower():
		file.seek(file.get_position() + 30)
		for i in range(num_balls):
			ball_sizes.append(file.get_16()) 
			#print("Ball Size[", i, "]: ", ball_sizes[i])
		file.seek(438)
	elif "dog" in file_path.to_lower() or "cat" in file_path.to_lower():
		file.seek(file.get_position() + 30)
		for i in range(num_balls):
			ball_sizes.append(file.get_16())
			#print("Ball Size[", i, "]: ", ball_sizes[i])
	else:
		var result = _find_ball_info_start_and_size(file, 2000, num_balls)
		var start_offset = result[0]
		if start_offset != -1:
			file.seek(start_offset)
			for i in range(num_balls):
				ball_sizes.append(file.get_16())

			# After reading ball sizes, skip the zero padding to find animation count
			while true:
				var val = file.get_16()
				if val != 0:
					file.seek(file.get_position() - 2) # Back up to read it as count
					break
				if file.eof_reached():
					break
		else:
			# If not found, try standard petz offset 38 as fallback
			file.seek(38)
			for i in range(num_balls):
				ball_sizes.append(file.get_16())

	var animation_count = file.get_16()
	#print("Number of Animations: ", animation_count)
	
	# for i in range(animation_count):
	# 	var start = 0
	# 	if i > 0:
	# 		start = animation_ranges[i - 1].end
	# 	var end = file.get_16()
	# 	var num_of_offsets = end - start
	# 	animation_ranges.append({num_of_offsets = num_of_offsets, end = end, start = frames_offset + (start * 4), actual_start = start})
	# 	#print("Animation Range[", i, "]: start=", start, ", end=", end, ", num_of_offsets=", num_of_offsets)
	
	# Global frame count is inclusive so we need to add +1 for [Head Shot] extraction
	for i in range(animation_count):
		var prev_end = 0
		if i > 0:
			prev_end = animation_ranges[i - 1].end + 1
		var end = file.get_16()
		var num_of_offsets = end - prev_end + 1
		animation_ranges.append({
			num_of_offsets = num_of_offsets,
			end            = end,
			start          = frames_offset + (prev_end * 4),
			actual_start   = prev_end
		})
		#print("Animation Range[", i, "]: start=", start, ", end=", end, ", num_of_offsets=", num_of_offsets)

	file.close()

func get_frame_offsets_for(index: int):
	#print("Getting frame offsets for animation index: ", index)
	var result = []

	if index >= animation_ranges.size():
		#print("Invalid index: ", index, ". Returning empty result.")
		return result

	var anim_range = animation_ranges[index]
	#print("Animation range: ", anim_range)

	var num_of_offsets = anim_range.num_of_offsets
	#print("Number of offsets for animation: ", num_of_offsets)

	var file = File.new()
	file.open(file_path, File.READ)

	file.seek(anim_range.start)
	for i in range(num_of_offsets):
		var offset = file.get_32()
		result.append(offset)
		#print("Offset[", i, "]: ", offset)

	file.close()
	return result

func _find_ball_info_start_and_size(file: File, max_search_area: int, expected_num_balls: int) -> Array:
	var start_pos = 8 # Start searching after header
	file.seek(start_pos)

	# Initialize to track largest valid block found
	# [start_offset, block_size]
	var largest_block: Array = [-1, -1]
	var largest_size: int = -1
	
	# Pre-calculate the expected size in bytes (each ball info is 16-bit, or 2 bytes)
	var required_block_size = expected_num_balls * 2

	# Scan forward for 00 00 followed by non-zero
	while file.get_position() < start_pos + max_search_area:
		var pos = file.get_position()
		if file.eof_reached():
			break

		var val = file.get_16() # Read 2 bytes

		if val == 0:
			# Found a zero. Check if next is non-zero (potential start)
			var next_pos = file.get_position()
			
			if file.eof_reached():
				break

			var next_val = file.get_16() # Peek at the next 2 bytes

			if next_val != 0:
				var potential_start = next_pos
				
				# We found a potential block start: 00 00 [non-zero] ...
				
				var current_ball_count = 0
				file.seek(potential_start) # Move file pointer to the start of non-zero data
				
				# Count how many non-zero 16-bit values follow
				while file.get_position() < start_pos + max_search_area:
					if file.eof_reached():
						break
						
					var block_val = file.get_16()
					
					if block_val == 0:
						# Found the trailing 00 00 (end of block)
						break
					
					current_ball_count += 1
				
				# The block is valid if the count matches the expected number of balls
				if current_ball_count == expected_num_balls:
					var current_size = current_ball_count * 2
					
					if current_size > largest_size:
						largest_size = current_size
						largest_block = [potential_start, current_size]
				
				# Reset file position to continue scanning from where the last successful 16-bit read occurred (next_pos)
				file.seek(next_pos)
			
			else:
				pass
	return largest_block
