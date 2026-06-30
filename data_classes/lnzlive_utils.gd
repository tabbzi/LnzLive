extends Reference
class_name LnzLiveUtils

const DEFAULT_PALETTE = preload("res://resources/textures/petzpalette.png")
const BABYZ_PALETTE   = preload("res://resources/palettes/babyz_palette.png")

const ICON_EYE_NEUTRAL = preload("res://resources/icons/ico_eyelid_neutral.png")
const ICON_EYE_NOLID = preload("res://resources/icons/ico_eyelid_nolid.png")
const ICON_EYE_ANGRY = preload("res://resources/icons/ico_eyelid_angry.png")
const ICON_EYE_SCARED = preload("res://resources/icons/ico_eyelid_scared.png")

static func parse_number_list(s: String, allow_negatives: bool = false) -> Array:
	var result: Array = []
	var parts: PoolStringArray = s.split(",", false)
	
	var range_regex: RegEx = RegEx.new()
	range_regex.compile("^\\s*(-?\\d+)\\s*-\\s*(-?\\d+)\\s*$")
	
	for part in parts:
		var this_match: RegExMatch = range_regex.search(part)
		
		if this_match:
			var start: int = this_match.get_string(1).to_int()
			var end: int = this_match.get_string(2).to_int()
			
			if not allow_negatives and (start < 0 or end < 0):
				continue
			
			var step: int = 1 if end >= start else -1
			
			for i in range(start, end + step, step):
				result.append(i)

		elif part.strip_edges().is_valid_integer():
			var val: int = part.strip_edges().to_int()
			
			if allow_negatives or val >= 0:
				result.append(val)
			
	return result

static func parse_flexible_integers(s: String) -> Array:
	var result: Array = []
	var regex: RegEx = RegEx.new()
	regex.compile("-?\\d+") 
	
	var matches: Array = regex.search_all(s)
	for m in matches:
		var match_obj: RegExMatch = m
		result.append(match_obj.get_string().to_int())
	
	return result

static func update_color_list_previews(container: Container, text: String, palette_colors: Array, max_previews: int = 8) -> void:
	if not is_instance_valid(container): return
	for child in container.get_children():
		var child_node: Node = child
		child_node.queue_free()

	if palette_colors.empty():
		return

	var parsed: Array = parse_number_list(text)
	var count: int = min(parsed.size(), max_previews)

	for i in range(count):
		var color_idx: int = parsed[i]
		var c: Color = Color.white
		if color_idx >= 0 and color_idx < palette_colors.size():
			c = palette_colors[color_idx]

		var rect: ColorRect = ColorRect.new()
		rect.rect_min_size = Vector2(16, 16)
		rect.color = c

		var border: ReferenceRect = ReferenceRect.new()
		border.editor_only = false
		border.border_color = Color(0, 0, 0, 0.5) if c.v > 0.5 else Color(1, 1, 1, 0.5)
		border.set_anchors_and_margins_preset(Control.PRESET_WIDE)
		rect.add_child(border)

		container.add_child(rect)

	if parsed.size() > max_previews:
		var label: Label = Label.new()
		label.text = "+" + str(parsed.size() - max_previews)
		container.add_child(label)

static func get_ramp_color(current_color_str: String, rule: Dictionary):
	if not rule.get("is_ramp") or \
	   not current_color_str.is_valid_integer() or \
	   not str(rule.before_color).is_valid_integer() or \
	   not str(rule.after_color).is_valid_integer():
		return null

	var current_color: int = int(current_color_str)
	var before_color: int = int(rule.before_color)
	var after_color: int = int(rule.after_color)

	if current_color < 10 or current_color > 199 or \
	   before_color < 10 or before_color > 199:
		return null

	var current_base: int = (current_color / 10) * 10
	var before_base: int = (before_color / 10) * 10

	if current_base != before_base:
		return null

	if after_color >= 10 and after_color <= 199:
		var offset: int = current_color - current_base
		var after_base: int = (after_color / 10) * 10
		return str(after_base + offset)
	else:
		return str(after_color)

static func generate_theory_colors(base_color: Color, theory_type: int, steps: int) -> Array:
	var generated_colors: Array = []
	
	var h: float = base_color.h
	var s: float = base_color.s
	var v: float = base_color.v
	
	# The base color is always the first in the list for reference
	generated_colors.append(base_color)
	
	match theory_type:
		0: # Off / Standard - Return just the base color or empty
			# In the context of the randomizer, 0 means "Off", so we return empty 
			# to signal that standard randomization should be used instead.
			return []
			
		1: # Monochromatic (Value & Saturation)
			for i in range(steps):
				var nv: float = clamp(v + rand_range(-0.4, 0.4), 0.1, 1.0)
				var ns: float = clamp(s + rand_range(-0.4, 0.4), 0.0, 1.0)
				generated_colors.append(Color.from_hsv(h, ns, nv))
				
		2: # Analogous (Neighboring)
			# Generate 'steps' colors spread around the hue circle
			for i in range(steps):
				# Spread hue by small increments
				var hue_offset: float = (i + 1) * 0.05 + rand_range(-0.02, 0.02)
				var new_h: float = fmod(h + hue_offset, 1.0)
				
				# Slight variation in S and V to keep it natural
				var new_s: float = clamp(s + rand_range(-0.1, 0.1), 0.0, 1.0)
				var new_v: float = clamp(v + rand_range(-0.1, 0.1), 0.0, 1.0)
				
				generated_colors.append(Color.from_hsv(new_h, new_s, new_v))
				
			# Also generate the "negative" analogous (counter-clockwise)
			for i in range(steps):
				var hue_offset: float = (i + 1) * 0.05 + rand_range(-0.02, 0.02)
				var new_h: float = fmod(h - hue_offset + 1.0, 1.0)
				var new_s: float = clamp(s + rand_range(-0.1, 0.1), 0.0, 1.0)
				var new_v: float = clamp(v + rand_range(-0.1, 0.1), 0.0, 1.0)
				
				generated_colors.append(Color.from_hsv(new_h, new_s, new_v))

		3: # Complementary 
			var comp_h: float = fmod(h + 0.5 + rand_range(-0.05, 0.05), 1.0)
			generated_colors.append(Color.from_hsv(comp_h, s, v))
			
			if steps > 1:
				generated_colors.append(Color.from_hsv(h, clamp(s * rand_range(0.5, 0.9), 0.0, 1.0), clamp(v * rand_range(0.6, 1.2), 0.0, 1.0)))
				generated_colors.append(Color.from_hsv(comp_h, clamp(s * rand_range(0.5, 0.9), 0.0, 1.0), clamp(v * rand_range(0.6, 1.2), 0.0, 1.0)))
				
		4: # Triadic 
			var t1: float = fmod(h + 0.333 + rand_range(-0.05, 0.05), 1.0)
			var t2: float = fmod(h + 0.666 + rand_range(-0.05, 0.05), 1.0)
			
			generated_colors.append(Color.from_hsv(t1, clamp(s+rand_range(-0.1,0.1), 0, 1), clamp(v+rand_range(-0.1,0.1), 0, 1)))
			generated_colors.append(Color.from_hsv(t2, clamp(s+rand_range(-0.1,0.1), 0, 1), clamp(v+rand_range(-0.1,0.1), 0, 1)))
			
			if steps > 2:
				generated_colors.append(Color.from_hsv(t1, clamp(s * rand_range(0.4, 0.8), 0.0, 1.0), clamp(v * rand_range(0.6, 1.1), 0.0, 1.0)))
				generated_colors.append(Color.from_hsv(t2, clamp(s * rand_range(0.4, 0.8), 0.0, 1.0), clamp(v * rand_range(0.6, 1.1), 0.0, 1.0)))
				
		5: # Split Complementary
			var sc1: float = fmod(h + 0.416 + rand_range(-0.05, 0.05), 1.0)
			var sc2: float = fmod(h + 0.583 + rand_range(-0.05, 0.05), 1.0)
			
			generated_colors.append(Color.from_hsv(sc1, clamp(s+rand_range(-0.1,0.1), 0, 1), clamp(v+rand_range(-0.1,0.1), 0, 1)))
			generated_colors.append(Color.from_hsv(sc2, clamp(s+rand_range(-0.1,0.1), 0, 1), clamp(v+rand_range(-0.1,0.1), 0, 1)))
			
			if steps > 2:
				generated_colors.append(Color.from_hsv(sc1, clamp(s * 0.7, 0.0, 1.0), clamp(v * rand_range(0.8, 1.2), 0.0, 1.0)))
				generated_colors.append(Color.from_hsv(sc2, clamp(s * 0.7, 0.0, 1.0), clamp(v * rand_range(0.8, 1.2), 0.0, 1.0)))

	return generated_colors


### SPATIAL UTILITIES ###
static func get_basis_from_normal(normal_vec: Vector3) -> Basis:
	var basis_y: Vector3 = normal_vec.normalized()
	var cross_vec: Vector3 = Vector3.UP.cross(basis_y)

	if cross_vec.length_squared() < 0.0001:
		cross_vec = Vector3.RIGHT.cross(basis_y)
	
	var basis_x: Vector3 = cross_vec.normalized()
	var basis_z: Vector3 = basis_y.cross(basis_x).normalized()
	
	return Basis(basis_x, basis_y, basis_z)

static func intersect_ray_with_plane(ray_origin: Vector3, ray_dir: Vector3, plane_normal: Vector3, plane_point: Vector3):
	var denom: float = plane_normal.dot(ray_dir)
	if abs(denom) < 0.0001:
		return null
	var d: float = plane_normal.dot(plane_point - ray_origin) / denom
	return ray_origin + ray_dir * d

static func flip_camera_view(camera_node: Camera) -> void:
	var camera_transform: Transform = camera_node.transform
	camera_transform.basis.x *= -1
	camera_node.transform = camera_transform


### COORDINATE CONVERSIONS ###
static func world_to_lnz_delta(world_delta: Vector3, pixel_world_size: float, engine_scale: float) -> Vector3:
	var lnz_scale: float = engine_scale / 255.0
	var lnz_delta_raw: Vector3 = world_delta / (pixel_world_size * lnz_scale)
	lnz_delta_raw.y *= -1.0 # Invert Y for LNZ format
	return Vector3(round(lnz_delta_raw.x), round(lnz_delta_raw.y), round(lnz_delta_raw.z))

static func lnz_to_world_delta(lnz_delta: Vector3, pixel_world_size: float, engine_scale: float) -> Vector3:
	var lnz_scale: float = engine_scale / 255.0
	var world_delta: Vector3 = lnz_delta
	world_delta.y *= -1.0 # Invert Y back to world format
	return world_delta * (pixel_world_size * lnz_scale)


### SIZE CONVERSIONS ###
static func visual_size_to_lnz_size(target_visual: float, is_addball: bool, engine_scale: float, bhd_size: int = 0, enl_x: float = 100.0, enl_y: float = 0.0) -> int:
	var req_total: float = (target_visual / (engine_scale / 255.0)) + 2.0
	
	if not is_addball:
		req_total = (req_total - enl_y) / (enl_x / 100.0)
		
	return int(round(req_total - bhd_size))

static func snap_visual_size(target_visual: float, is_addball: bool, engine_scale: float, bhd_size: int = 0, enl_x: float = 100.0, enl_y: float = 0.0) -> float:
	var final_lnz: int = visual_size_to_lnz_size(target_visual, is_addball, engine_scale, bhd_size, enl_x, enl_y)
	var current_base_size: float = bhd_size + final_lnz
	
	if not is_addball:
		current_base_size = floor(current_base_size * (enl_x / 100.0)) + enl_y
		
	var offset: float = 2.0
	var snapped: float = round((current_base_size - offset) * (engine_scale / 255.0))
	snapped -= 1.0 - fmod(snapped, 2.0) # Apply LNZ's native snapping behavior
	return snapped


### PATTERN & PAINTBALL UTILITIES ###
static func generate_surface_walk(start_pos: Vector3, center: Vector3, step_scale_radius: float, steps: int, walk_spread: float) -> Array:
	var path: Array = []
	var curr_pos: Vector3 = start_pos
	var actual_dist: float = (start_pos - center).length()
	if actual_dist == 0:
		actual_dist = 1.0
		curr_pos = center + Vector3.UP
		
	var dir: Vector3 = Vector3(rand_range(-1.0, 1.0), rand_range(-1.0, 1.0), rand_range(-1.0, 1.0)).normalized()
	
	for _s in range(steps):
		var normal: Vector3 = (curr_pos - center).normalized()
		var tangent: Vector3 = (dir - normal * dir.dot(normal)).normalized()
		
		dir = (tangent + Vector3(rand_range(-0.5, 0.5), rand_range(-0.5, 0.5), rand_range(-0.5, 0.5))).normalized()
		
		var step_dist: float = step_scale_radius * rand_range(1.0, 2.5) * walk_spread
		curr_pos += tangent * step_dist
		curr_pos = center + (curr_pos - center).normalized() * actual_dist
		
		path.append(curr_pos)
		
	return path

static func calculate_gray_scott_grid(size: int, iterations: int, diff_a: float, diff_b: float, feed: float, kill: float, timestep: float) -> Array:
	var grid: Array = []
	grid.resize(size * size)
	for i in range(size * size): 
		grid[i] = {"a": 1.0, "b": 0.0}
	grid[(size/2) * size + (size/2)].b = 1.0
	
	for _t in range(iterations):
		var next: Array = []
		next.resize(size * size)
		for x in range(1, size - 1):
			for y in range(1, size - 1):
				var i: int = y * size + x
				var a: float = grid[i].a
				var b: float = grid[i].b
				var lp_a: float = (grid[i-1].a + grid[i+1].a + grid[i-size].a + grid[i+size].a) - 4 * a
				var lp_b: float = (grid[i-1].b + grid[i+1].b + grid[i-size].b + grid[i+size].b) - 4 * b
				var r: float = a * b * b
				next[i] = {
					"a": clamp(a + (diff_a * lp_a - r + feed * (1.0 - a)) * timestep, 0.0, 1.0),
					"b": clamp(b + (diff_b * lp_b + r - (kill + feed) * b) * timestep, 0.0, 1.0)
				}
		for i in range(size * size): 
			if next[i] != null: 
				grid[i] = next[i]
	return grid

static func parse_lsystem_rules(rules_text: String) -> Dictionary:
	var rules: Dictionary = {}
	var lines: PoolStringArray = rules_text.split("\n", false)
	for line in lines:
		var line_str: String = line
		var parts: PoolStringArray = line_str.split("=", false, 1)
		if parts.size() == 2:
			var key: String = parts[0].strip_edges()
			var value: String = parts[1].strip_edges()
			if not key.empty():
				rules[key] = value
	return rules

static func generate_lsystem_string(axiom: String, rules: Dictionary, iterations: int) -> String:
	var current_string: String = axiom
	for _i in range(iterations):
		var new_string: String = ""
		for char_idx in range(current_string.length()):
			var current_char: String = current_string[char_idx]
			if rules.has(current_char):
				new_string += rules[current_char]
			else:
				new_string += current_char
		current_string = new_string
	return current_string

static func generate_random_lsystem() -> Dictionary:
	var variables: Array = ["F", "G", "A", "B", "X"]
	var constants: Array = ["+", "-"]
	var all_chars: Array = variables + constants

	var axiom: String = variables[randi() % variables.size()]
	var rules: Dictionary = {}
	var num_rules: int = 2 + randi() % 2 
	
	variables.shuffle()
	
	for i in range(num_rules):
		var key: String = variables[i]
		var value: String = ""
		var value_length: int = 3 + randi() % 5
		
		var current_len: int = 0
		while current_len < value_length:
			if randf() < 0.2 and current_len < value_length - 2:
				value += "[" + all_chars[randi() % all_chars.size()] + "]"
				current_len += 3
			else:
				value += all_chars[randi() % all_chars.size()]
				current_len += 1
		
		rules[key] = value

	var rule_lines: Array = []
	for key in rules:
		var str_key: String = key
		rule_lines.append(str_key + "=" + rules[str_key])
	
	var rules_pool: PoolStringArray = PoolStringArray(rule_lines)
	var rules_text: String = rules_pool.join("\n")
	rules_pool.resize(0) 

	return {"axiom": axiom, "rules_text": rules_text}


### IMAGE/MASKING UTILITIES ###
static func compute_distance_transform(mask: Array, size: int) -> Array:
	var dists: Array = []
	dists.resize(size * size)
	for i in range(dists.size()):
		if not mask[i]:
			dists[i] = 0.0
			continue
		
		var x: int = i % size
		var y: int = i / size
		var min_d: float = 100.0
		for my in range(size):
			for mx in range(size):
				if not mask[my * size + mx]:
					var d: float = sqrt(pow(x - mx, 2) + pow(y - my, 2))
					if d < min_d: min_d = d

		min_d = min(min_d, min(x + 0.5, min(y + 0.5, min(size - 1 - x + 0.5, size - 1 - y + 0.5))))
		dists[i] = min_d
	return dists

static func clear_mask_circle(mask: Array, size: int, cx: int, cy: int, radius: float) -> int:
	var cleared: int = 0
	for y in range(size):
		for x in range(size):
			var idx: int = y * size + x
			if mask[idx]:
				var d: float = sqrt(pow(x - cx, 2) + pow(y - cy, 2))
				if d <= radius:
					mask[idx] = false
					cleared += 1
	return cleared

static func verify_palette_compatibility(bmp_palette: Array, palette: Array) -> float:
	var total_diff: float = 0.0
	var samples: int = 0
	for i in range(0, 256, 10): 
		if i < bmp_palette.size() and i < palette.size():
			var bmp_col: Color = bmp_palette[i]
			var petz_col: Color = palette[i]
			total_diff += abs(bmp_col.r - petz_col.r) + abs(bmp_col.g - petz_col.g) + abs(bmp_col.b - petz_col.b)
			samples += 1
	
	return total_diff / float(samples)

static func validate_8bit_bmp(path: String) -> Dictionary:
	var f: File = File.new()
	if f.open(path, File.READ) != OK:
		return {"valid": false, "reason": "Could not open file"}
		
	if f.get_len() < 54:
		f.close()
		return {"valid": false, "reason": "File too small"}
	
	if f.get_8() != 66 or f.get_8() != 77:
		f.close()
		return {"valid": false, "reason": "Not a BMP file"}
	
	f.seek(14)
	var _header_size: int = f.get_32()
	
	f.seek(28)
	var bpp: int = f.get_16()
	f.close()
	
	if bpp != 8:
		return {"valid": false, "reason": "Not an 8-bit BMP (BPP: " + str(bpp) + ")"}
		
	return {"valid": true}

static func load_raw_8bit_bmp(path: String, is_babyz_mode: bool = false, debug: bool = false) -> Dictionary:
	var f: File = File.new()
	if f.open(path, File.READ) != OK:
		return {}
		
	if f.get_len() < 54:
		f.close()
		return {}
	
	f.seek(0)
	if f.get_8() != 66 or f.get_8() != 77: 
		f.close()
		return {}
	
	f.seek(10)
	var pixel_offset: int = f.get_32()
	
	f.seek(14)
	var _header_size: int = f.get_32()
	
	var w: int = 0
	var h_raw: int = 0
	var bpp: int = 0
	
	if _header_size == 12:
		w = f.get_16()
		h_raw = f.get_16()
		f.seek(24)
		bpp = f.get_16()
	elif _header_size >= 40:
		w = f.get_32()
		h_raw = f.get_32()
		f.seek(28)
		bpp = f.get_16()
		f.seek(30)
		if f.get_32() != 0:
			print("[WARNING] load_raw_8bit_bmp: Compressed BMPs not supported: ", path)
			f.close()
			return {}
	else:
		f.close()
		return {}

	f.seek(14 + _header_size) 
	var bmp_palette: Array = []
	
	if debug:
		print("[DEBUG] BMP Import - Dumping first 5 palette entries for: ", path)
		
	for i in range(256):
		var b: int = f.get_8()
		var g: int = f.get_8()
		var r: int = f.get_8()
		var _res: int = f.get_8()
		var col: Color = Color(r/255.0, g/255.0, b/255.0)
		bmp_palette.append(col)
		
		if debug and i < 5:
			print("  Entry ", i, ": (R:", r, " G:", g, " B:", b, ")")
	
	var h: int = abs(h_raw)
	var is_bottom_up: bool = (h_raw > 0)
	
	if bpp != 8:
		f.close()
		return {}
		
	f.seek(pixel_offset)
	var row_size: int = int((w + 3) / 4) * 4
	var index_data: PoolByteArray = PoolByteArray()
	index_data.resize(w * h)
	
	for i in range(h):
		var y: int = (h - 1 - i) if is_bottom_up else i
		var row_data: PoolByteArray = f.get_buffer(row_size)
		for x in range(w):
			if x < row_data.size():
				index_data[y * w + x] = row_data[x]
		row_data.resize(0)
				
	f.close()

	var target_tex: Texture = BABYZ_PALETTE if is_babyz_mode else DEFAULT_PALETTE
	var target_palette: Array = extract_palette_from_image(target_tex)

	var diff: float = verify_palette_compatibility(bmp_palette, target_palette)
	
	if debug:
		print("[DEBUG] Palette difference score: ", diff)
	
	if diff > 0.05:
		if debug:
			print("[INFO] Palette mismatch detected. Requantizing: ", path)
		var new_index_data: PoolByteArray = requantize_bmp_data(index_data, bmp_palette, target_palette)
		index_data.resize(0)
		index_data = new_index_data

	if debug:
		var unique_indices: Dictionary = {}
		for idx in index_data:
			unique_indices[idx] = true

		print("[DEBUG] BMP Import - File: ", path)
		print("[DEBUG] - Detected unique palette indices in file: ", unique_indices.keys().size())
		print("[DEBUG] - Contains Magenta (253)?: ", unique_indices.has(253))

	return { "w": w, "h": h, "data": index_data }

static func extract_palette_from_image(tex: Texture) -> Array:
	var img: Image = tex.get_data()
	if img == null:
		print("[ERROR] extract_palette_from_image: Texture data is null!")
		return []
		
	img.lock()
	var pal: Array = []
	for i in range(256):
		pal.append(img.get_pixel(i, 0))
	img.unlock()
	return pal

static func requantize_bmp_data(raw_data: PoolByteArray, bmp_palette: Array, target_palette: Array) -> PoolByteArray:
	var lut: PoolByteArray = PoolByteArray()
	lut.resize(256)
	for i in range(bmp_palette.size()):
		var best_idx: int = 0
		var min_dist: float = 1000000.0
		var col1: Color = bmp_palette[i]
		for j in range(target_palette.size()):
			var col2: Color = target_palette[j]
			var d: float = pow(col1.r - col2.r, 2) + pow(col1.g - col2.g, 2) + pow(col1.b - col2.b, 2)
			if d < min_dist:
				min_dist = d
				best_idx = j
		lut[i] = best_idx
		
	var new_data: PoolByteArray = PoolByteArray()
	new_data.resize(raw_data.size())
	for i in range(raw_data.size()):
		new_data[i] = lut[raw_data[i]]
	
	lut.resize(0)
	return new_data


### COLOR UTILITIES ###
static func get_luminance(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114

static func get_saturation(color: Color) -> float:
	var max_c: float = max(color.r, max(color.g, color.b))
	var min_c: float = min(color.r, min(color.g, color.b))
	if max_c == 0.0:
		return 0.0
	return (max_c - min_c) / max_c

static func get_hue(color: Color) -> float:
	var max_c: float = max(color.r, max(color.g, color.b))
	var min_c: float = min(color.r, min(color.g, color.b))
	var delta: float = max_c - min_c
	if delta == 0.0:
		return 0.0
	var h: float = 0.0
	if max_c == color.r:
		h = fmod((color.g - color.b) / delta, 6.0)
	elif max_c == color.g:
		h = fmod(((color.b - color.r) / delta) + 2.0, 6.0)
	elif max_c == color.b:
		h = fmod(((color.r - color.g) / delta) + 4.0, 6.0)
	h *= 60.0
	if h < 0.0:
		h += 360.0
	return h

static func find_closest_palette_index(palette_colors: Array, target_color: Color) -> int:
	if palette_colors.empty():
		return 0
	var best_index: int = 0
	var min_dist: float = INF
	for i in range(palette_colors.size()):
		var c: Color = palette_colors[i]
		var dist: float = pow(c.r - target_color.r, 2) + pow(c.g - target_color.g, 2) + pow(c.b - target_color.b, 2)
		if dist < min_dist:
			min_dist = dist
			best_index = i
	return best_index


### WEB UTILITIES ###
static func web_file_dialog(accept_extensions: String) -> void:
	JavaScript.eval("""
	window.fileUploadData = {}

	let el = document.createElement("input");
	el.type = "file"
	el.accept = '""" + accept_extensions + """'
	el.addEventListener("change", (e) => {
	  if (e.target.files.length > 0) {
		let file = e.target.files[0]
		window.fileUploadData.name = file.name

		let reader = new FileReader()
		reader.readAsArrayBuffer(file)
		reader.onloadend = (ev) => {
		  window.fileUploadData.blob = ev.target.result
		}
	  }
	})
	el.click()
	""")

static func get_web_file_blob() -> Object:
	return JavaScript.eval("window.fileUploadData.blob")

static func get_web_file_name() -> String:
	var name = JavaScript.eval("window.fileUploadData.name")
	return name if name != null else ""

static func web_download_text(filename: String, content: String) -> void:
	var escaped = content.replace("\\", "\\\\").replace("'", "\\'").replace('"', '\\"').replace("\n", "\\n")
	var js_code = """
	var element = document.createElement('a');
	element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent('""" + escaped + """'));
	element.setAttribute('download', '""" + filename + """');
	element.style.display = 'none';
	document.body.appendChild(element);
	element.click();
	document.body.removeChild(element);
	"""
	JavaScript.eval(js_code)

static func web_download_json(filename: String, content: String) -> void:
	var base64_content: String = Marshalls.raw_to_base64(content.to_utf8())
	var js_code = """
	var element = document.createElement('a');
	element.setAttribute('href', 'data:application/json;base64,' + '""" + base64_content + """');
	element.setAttribute('download', '""" + filename + """');
	element.style.display = 'none';
	document.body.appendChild(element);
	element.click();
	document.body.removeChild(element);
	"""
	JavaScript.eval(js_code)

static func web_prompt_import_text(callback_target: Object, callback_method: String) -> void:
	var js_code = """
	var input = document.createElement('input');
	input.type = 'file';
	input.accept = 'text/plain,.lnz,.json,.bmp,.png';
	input.onchange = e => { 
	   var file = e.target.files[0]; 
	   var reader = new FileReader();
	   reader.readAsText(file,'UTF-8');
	   reader.onload = readerEvent => {
		   var content = readerEvent.target.result;
		   window.godotTextImport(content);
	   }
	}
	input.click();
	"""
	var cb = JavaScript.create_callback(callback_target, callback_method)
	JavaScript.get_interface("window").godotTextImport = cb
	JavaScript.eval(js_code)

static func ensure_web_ref_dir() -> void:
	JavaScript.eval("""
	if (!window.fileUploadData) window.fileUploadData = {}
	""")

static func web_upload_image(dest_dir: String, callback_target: Object, callback_method: String) -> void:
	var js_code = """
	window.refUploadData = {}
	var el = document.createElement("input");
	el.type = "file"
	el.accept = '.png,.jpg,.jpeg,.gif'
	el.addEventListener("change", (e) => {
	  if (e.target.files.length > 0) {
		let file = e.target.files[0]
		window.refUploadData.name = file.name
		let reader = new FileReader()
		reader.readAsArrayBuffer(file)
		reader.onloadend = (ev) => {
		  window.refUploadData.blob = ev.target.result
		}
	  }
	})
	el.click()
	"""
	var cb = JavaScript.create_callback(callback_target, callback_method)
	JavaScript.get_interface("window").godotRefUpload = cb
	JavaScript.eval(js_code)

static func get_web_ref_blob() -> Object:
	return JavaScript.eval("window.refUploadData.blob")

static func get_web_ref_name() -> String:
	var name = JavaScript.eval("window.refUploadData.name")
	return name if name != null else ""

static func save_web_ref_to_disk(file_name: String, file_blob) -> int:
	var dir: Directory = Directory.new()
	var dest_dir: String = "user://resources/references/"
	var err: int = dir.make_dir_recursive(dest_dir)
	if err != OK:
		print("[ERROR] LnzLiveUtils: save_web_ref_to_disk: error creating dir: ", err)
		return err
	var dest_path: String = dest_dir + file_name
	var file: File = File.new()
	err = file.open(dest_path, File.WRITE)
	if err != OK:
		print("[ERROR] LnzLiveUtils: save_web_ref_to_disk: error opening file: ", err)
		return err
	file.store_buffer(file_blob)
	file.close()
	return OK
