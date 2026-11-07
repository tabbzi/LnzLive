extends Reference
# Read-only extraction of cached pet text and PE32 breed LNZ resources.
# All binary reads are bounded; invalid input never reaches the text editor.
var data: PoolByteArray
var error: String = ""
var sections: Array = []
var resource_base: int = 0
var resource_size: int = 0

func _require(offset: int, count: int) -> bool:
	if offset < 0 or count < 0 or offset > data.size() - count:
		error = "Truncated or invalid file."
		return false
	return true

func _u16(offset: int) -> int:
	if not _require(offset, 2): return 0
	return int(data[offset]) | (int(data[offset + 1]) << 8)

func _u32(offset: int) -> int:
	if not _require(offset, 4): return 0
	return _u16(offset) | (_u16(offset + 2) << 16)

func _text(offset: int, count: int) -> String:
	if not _require(offset, count) or count == 0: return ""
	# Petz text is byte-oriented. Preserve non-ASCII comments as Latin-1.
	var result: String = ""
	for i in range(offset, offset + count):
		if data[i] == 0: break
		result += char(data[i])
	return result

func extract(bytes: PoolByteArray, pet: bool) -> Array:
	data = bytes
	error = ""
	sections = []
	var result: Array = _pet() if pet else _breed()
	if not error.empty(): return []
	if result.empty():
		error = "No cached LNZ found. Import the pet's breed file instead." if pet else "No embedded LNZ resources found in this breed file."
	return result

func _pet() -> Array:
	if not _require(0, 800): return []
	var version: int = _u32(0x318)
	if version != 0x0acb0002 and version != 0x0acb0001:
		error = "Unsupported pet version (Petz 3–5 cached LNZ required)."
		return []
	var header: int = 816 if version == 0x0acb0002 else 800
	var tag: String = "p.f.magicpetzIII"
	if _text(header, 17) != tag:
		error = "Invalid pet stream signature."
		return []
	# PetzInfoPOD, followed by PetSavedColorInfo's three counted arrays.
	var pos: int = header + 17 + 1 + 24 + 8 + 1 + 32 + 2400 + 36 + 4 + 6
	for stride in [1, 4, 4]:
		var count: int = _u32(pos)
		pos += 4
		if not error.empty() or not _require(pos, count * stride): return []
		pos += count * stride
	pos += 4
	if _text(pos, 17) != tag:
		error = "Invalid pet LNZ signature."
		return []
	pos += 17
	var result: Array = []
	for label in ["Adult", "Juvenile"]:
		var start: int = pos
		while pos < data.size() and data[pos] != 0:
			pos += 1
		if not _require(pos, 5): return []
		if _u32(pos + 1) != 0x03bbccaa:
			error = "Invalid pet LNZ cache terminator."
			return []
		if pos > start:
			result.append({"name": label, "text": _text(start, pos - start)})
		pos += 5
	return result

func _rva(rva: int, count: int) -> int:
	for section in sections:
		var delta: int = rva - section.rva
		if delta >= 0 and delta <= section.size and count <= section.size - delta:
			var offset: int = section.offset + delta
			if _require(offset, count): return offset
	error = "Resource points outside the file."
	return -1

func _resource(offset: int, count: int) -> bool:
	if offset < 0 or offset > resource_size - count:
		error = "Invalid resource directory."
		return false
	return _require(resource_base + offset, count)

func _name(value: int) -> String:
	if (value & 0x80000000) == 0: return str(value)
	var offset: int = value & 0x7fffffff
	if not _resource(offset, 2): return ""
	var count: int = _u16(resource_base + offset)
	if not _resource(offset + 2, count * 2): return ""
	var result: String = ""
	for i in range(count): result += char(_u16(resource_base + offset + 2 + i * 2))
	return result

func _directory(offset: int, depth: int, label: String, result: Array) -> void:
	if not _resource(offset, 16): return
	var base: int = resource_base + offset
	var count: int = _u16(base + 12) + _u16(base + 14)
	if not _resource(offset + 16, count * 8): return
	for i in range(count):
		var entry: int = base + 16 + i * 8
		var name: String = _name(_u32(entry))
		var child: int = _u32(entry + 4)
		if depth == 0 and name.to_upper() != "LNZ": continue
		var next_label: String = name if depth == 1 else label
		if child & 0x80000000:
			if depth >= 2:
				error = "Invalid resource directory depth."
				return
			_directory(child & 0x7fffffff, depth + 1, next_label, result)
		elif depth == 2:
			if not _resource(child, 16): return
			var size: int = _u32(resource_base + child + 4)
			var start: int = _rva(_u32(resource_base + child), size)
			if start < 0: return
			var text: String = _text(start, size)
			if not text.strip_edges().empty():
				result.append({"name": label + " (" + name + ")", "text": text})
		if not error.empty(): return

func _breed() -> Array:
	if not _require(0, 64): return []
	if _u16(0) != 0x5a4d:
		error = "Breed file is not a Windows PE resource file."
		return []
	var pe: int = _u32(0x3c)
	if not _require(pe, 24): return []
	if _u32(pe) != 0x4550:
		error = "Invalid PE signature."
		return []
	var optional: int = pe + 24
	var optional_size: int = _u16(pe + 20)
	if optional_size < 120:
		error = "Missing PE resource data directory."
		return []
	if not _require(optional, optional_size): return []
	if _u16(optional) != 0x10b:
		error = "Only PE32 breed files are supported."
		return []
	if _u32(optional + 92) < 3:
		error = "Missing PE resource data directory."
		return []
	var table: int = optional + optional_size
	var count: int = _u16(pe + 6)
	if not _require(table, count * 40): return []
	for i in range(count):
		var entry: int = table + i * 40
		sections.append({"rva": _u32(entry + 12), "size": _u32(entry + 16), "offset": _u32(entry + 20)})
	resource_size = _u32(optional + 116)
	resource_base = _rva(_u32(optional + 112), resource_size)
	if resource_base < 0: return []
	var result: Array = []
	_directory(0, 0, "", result)
	return result
