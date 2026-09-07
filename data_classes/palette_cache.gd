extends Node
## palette_cache.gd
## Global singleton for palette color lookup optimization
## Provides palette index lookups via a quantized RGB bucket table
## Rebuilds automatically when the palette content changes

const LOOKUP_TABLE_SIZE: int = 32768

var _palette_cache_key: String = ""
var _palette_lookup_table: Array = []


func rebuild_palette_lookup_table(palette_colors: Array) -> void:
	if palette_colors.empty():
		_palette_cache_key = ""
		_palette_lookup_table.clear()
		return
	
	var key: String = ""
	for i in range(min(256, palette_colors.size())):
		var c: Color = palette_colors[i]
		key += str(int(c.r * 255), int(c.g * 255), int(c.b * 255))
	
	if key == _palette_cache_key:
		return
	
	_palette_cache_key = key
	
	_palette_lookup_table.resize(LOOKUP_TABLE_SIZE)
	for i in range(LOOKUP_TABLE_SIZE):
		_palette_lookup_table[i] = -1
	
	for palette_idx in range(1, palette_colors.size()):
		var c: Color = palette_colors[palette_idx]
		var r: int = int(clamp(c.r * 31, 0, 31))
		var g: int = int(clamp(c.g * 31, 0, 31))
		var b: int = int(clamp(c.b * 31, 0, 31))
		
		var bucket: int = (r * 1024) + (g * 32) + b
		_palette_lookup_table[bucket] = palette_idx


func get_palette_index_fast(palette_colors: Array, target_color: Color) -> int:
	if palette_colors.empty():
		return 1
	
	var r: int = int(clamp(target_color.r * 31, 0, 31))
	var g: int = int(clamp(target_color.g * 31, 0, 31))
	var b: int = int(clamp(target_color.b * 31, 0, 31))
	var bucket: int = (r * 1024) + (g * 32) + b
	
	var cached_idx: int = _palette_lookup_table[bucket] if bucket < _palette_lookup_table.size() else -1
	if cached_idx >= 0:
		return cached_idx
	
	return _fallback_get_closest_palette_index(palette_colors, target_color)


func _fallback_get_closest_palette_index(palette_colors: Array, target_color: Color) -> int:
	var best_index: int = -1
	var min_dist: float = INF
	for i in range(palette_colors.size()):
		if i == 0:
			continue
		var c: Color = palette_colors[i]
		var dist: float = pow(c.r - target_color.r, 2) + pow(c.g - target_color.g, 2) + pow(c.b - target_color.b, 2)
		if dist < min_dist:
			min_dist = dist
			best_index = i
	if best_index == -1:
		return 1
	return best_index
