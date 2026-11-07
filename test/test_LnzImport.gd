extends GutTest

const Importer = preload("res://data_classes/lnz_importer.gd")
const LNZ = "[Ballz Info]\r\n0, 0, 0, 1\r\n"

func _put(bytes: PoolByteArray, offset: int, value: int, width: int = 4) -> PoolByteArray:
	for i in range(width): bytes[offset + i] = (value >> (i * 8)) & 255
	return bytes

func _string(bytes: PoolByteArray, offset: int, text: String) -> PoolByteArray:
	var encoded: PoolByteArray = text.to_ascii()
	for i in range(encoded.size()): bytes[offset + i] = encoded[i]
	return bytes

func _pet(adult: String = LNZ, juvenile: String = LNZ) -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	var pos: int = 816 + 17 + 1 + 24 + 8 + 1 + 32 + 2400 + 36 + 4 + 6 + 12 + 4
	bytes.resize(pos + 17)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _put(bytes, 0x318, 0x0acb0002)
	bytes = _string(bytes, 816, "p.f.magicpetzIII")
	bytes = _string(bytes, pos, "p.f.magicpetzIII")
	for text in [adult, juvenile]:
		bytes.append_array(text.to_ascii())
		bytes.append_array(PoolByteArray([0, 0xaa, 0xcc, 0xbb, 3]))
	return bytes

func _breed() -> PoolByteArray:
	var bytes: PoolByteArray = PoolByteArray()
	bytes.resize(1024)
	for i in range(bytes.size()): bytes[i] = 0
	bytes = _put(bytes, 0, 0x5a4d, 2)
	bytes = _put(bytes, 0x3c, 64)
	bytes = _put(bytes, 64, 0x4550)
	bytes = _put(bytes, 70, 1, 2)
	bytes = _put(bytes, 84, 224, 2)
	bytes = _put(bytes, 88, 0x10b, 2)
	bytes = _put(bytes, 180, 16)
	bytes = _put(bytes, 200, 0x1000)
	bytes = _put(bytes, 204, 512)
	bytes = _put(bytes, 324, 0x1000)
	bytes = _put(bytes, 328, 512)
	bytes = _put(bytes, 332, 512)
	# Type LNZ -> name AD -> language 1033 -> resource data.
	bytes = _put(bytes, 524, 1, 2)
	bytes = _put(bytes, 528, 0x80000080)
	bytes = _put(bytes, 532, 0x80000020)
	bytes = _put(bytes, 556, 1, 2)
	bytes = _put(bytes, 560, 0x80000090)
	bytes = _put(bytes, 564, 0x80000040)
	bytes = _put(bytes, 590, 1, 2)
	bytes = _put(bytes, 592, 1033)
	bytes = _put(bytes, 596, 0x60)
	bytes = _put(bytes, 608, 0x1100)
	bytes = _put(bytes, 612, LNZ.length())
	bytes = _put(bytes, 640, 3, 2)
	for i in range(3): bytes = _put(bytes, 642 + i * 2, "LNZ".ord_at(i), 2)
	bytes = _put(bytes, 656, 2, 2)
	bytes = _put(bytes, 658, 65, 2)
	bytes = _put(bytes, 660, 68, 2)
	return _string(bytes, 768, LNZ)

func test_pet_caches_and_empty_caches():
	var importer = Importer.new()
	var entries: Array = importer.extract(_pet(), true)
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].text, LNZ)
	assert_eq(entries[1].name, "Juvenile")
	entries = importer.extract(_pet("", LNZ), true)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].name, "Juvenile")
	assert_eq(importer.extract(_pet("", ""), true).size(), 0)
	assert_ne(importer.error, "")

func test_breed_resources():
	var importer = Importer.new()
	var entries: Array = importer.extract(_breed(), false)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].text, LNZ)
	assert_eq(entries[0].name, "AD (1033)")

func test_truncation_and_invalid_resources():
	var importer = Importer.new()
	var pet: PoolByteArray = _pet()
	pet.resize(pet.size() - 1)
	assert_eq(importer.extract(pet, true).size(), 0)
	var breed: PoolByteArray = _breed()
	breed = _put(breed, 608, 0x999999)
	assert_eq(importer.extract(breed, false).size(), 0)
	assert_ne(importer.error, "")
	breed = _breed()
	breed = _put(breed, 596, 0x80000000)
	assert_eq(importer.extract(breed, false).size(), 0)
	assert_ne(importer.error, "")
	assert_eq(importer.extract(PoolByteArray(), true).size(), 0)
	assert_eq(importer.extract(PoolByteArray(), false).size(), 0)

func test_pet_saved_color_arrays_and_invalid_terminator():
	var original: PoolByteArray = _pet()
	var count_offset: int = 816 + 17 + 1 + 24 + 8 + 1 + 32 + 2400 + 36 + 4 + 6
	var bytes: PoolByteArray = original.subarray(0, count_offset + 3)
	bytes = _put(bytes, count_offset, 3)
	bytes.append_array(PoolByteArray([8, 9, 10]))
	bytes.append_array(original.subarray(count_offset + 4, original.size() - 1))
	var importer = Importer.new()
	assert_eq(importer.extract(bytes, true).size(), 2)
	bytes[bytes.size() - 1] = 0
	assert_eq(importer.extract(bytes, true).size(), 0)

func test_every_breed_truncation_is_rejected():
	var bytes: PoolByteArray = _breed()
	var importer = Importer.new()
	for size in range(bytes.size()):
		var truncated: PoolByteArray = bytes.subarray(0, size - 1) if size > 0 else PoolByteArray()
		assert_eq(importer.extract(truncated, false).size(), 0, "size " + str(size))
