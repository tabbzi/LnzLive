extends WindowDialog
## ExportClothes.gd
## Handles the UI and logic for exporting CLZ data

onready var species_label: Label = $VBoxContainer/SettingsGrid/SpeciesValue
onready var kind_option: OptionButton = $VBoxContainer/SettingsGrid/KindOption
onready var base_container: Control = $VBoxContainer/SettingsGrid/BaseContainer
onready var dog_base_input = $VBoxContainer/SettingsGrid/BaseContainer/DogBaseInput
onready var cat_base_input = $VBoxContainer/SettingsGrid/BaseContainer/CatBaseInput
onready var baby_base_input = $VBoxContainer/SettingsGrid/BaseContainer/BabyBaseInput
onready var dog_label: Label = $VBoxContainer/SettingsGrid/BaseContainer/DogLabel
onready var cat_label: Label = $VBoxContainer/SettingsGrid/BaseContainer/CatLabel
onready var baby_label: Label = $VBoxContainer/SettingsGrid/BaseContainer/BabyLabel
onready var text_edit: TextEdit = $VBoxContainer/TextEdit

var dog_generator: Node = null
var current_species: int = 0

const KIND_PETZ: Array = ["Shirt", "Pant", "Sock_FrontL", "Sock_FrontR", "Sock_BackL", "Sock_BackR", "Tail", "Hat", "Hat2", "EarringL", "EarringR", "NoseThing", "NoseThing2", "Glasses"]
const KIND_BABYZ: Array = ["Diaper", "Coveralls", "Jumper", "Onesie", "Pants", "Shirt", "Socks", "Hat", "Hat2", "NoseThing", "NoseThing2", "Glasses", "EarringL", "EarringR", "Tail"]

func _ready() -> void:
	if get_tree().root.has_node("Root/PetRoot/Node"):
		dog_generator = get_tree().root.get_node("Root/PetRoot/Node")
	elif get_tree().root.has_node("Root/PetRoot"):
		dog_generator = get_tree().root.get_node("Root/PetRoot")

func open(target_ball_no: int = -1) -> void:
	popup_centered()
	initialize_data(target_ball_no)

func initialize_data(target_ball_no: int) -> void:
	if not dog_generator:
		return

	var lnz = dog_generator.lnz
	if not lnz:
		return

	current_species = lnz.get("species")

	var species_text: String = KeyBallsData.get_species_display_name(current_species)
	species_label.text = species_text

	kind_option.clear()
	var options: Array = KIND_PETZ
	if current_species == KeyBallsData.Species.BABY:
		options = KIND_BABYZ

	for opt in options:
		kind_option.add_item(opt)

	kind_option.select(0)

	_setup_base_inputs(target_ball_no)

func _setup_base_inputs(target_ball_no: int) -> void:
	# Reset visibility
	dog_label.visible = false
	dog_base_input.visible = false
	cat_label.visible = false
	cat_base_input.visible = false
	baby_label.visible = false
	baby_base_input.visible = false

	# Reset text
	dog_base_input.text = ""
	cat_base_input.text = ""
	baby_base_input.text = ""

	if current_species == KeyBallsData.Species.BABY:
		baby_label.visible = true
		baby_base_input.visible = true
		if target_ball_no != -1:
			baby_base_input.text = str(target_ball_no)
			var defs = KeyBallsData.get_ball_definitions(current_species)
			if defs.has(target_ball_no):
				baby_label.text = "Base (" + defs[target_ball_no].name + "):"
	else:
		dog_label.visible = true
		dog_base_input.visible = true
		cat_label.visible = true
		cat_base_input.visible = true

		if target_ball_no != -1:
			var dog_ball: int = -1
			var cat_ball: int = -1

			if current_species == KeyBallsData.Species.DOG:
				dog_ball = target_ball_no
				var cat_defs = KeyBallsData.get_ball_definitions(KeyBallsData.Species.CAT)
				cat_ball = _find_equivalent_ball(target_ball_no, KeyBallsData.get_ball_definitions(KeyBallsData.Species.DOG), cat_defs)
			elif current_species == KeyBallsData.Species.CAT:
				cat_ball = target_ball_no
				var dog_defs = KeyBallsData.get_ball_definitions(KeyBallsData.Species.DOG)
				dog_ball = _find_equivalent_ball(target_ball_no, KeyBallsData.get_ball_definitions(KeyBallsData.Species.CAT), dog_defs)

			if dog_ball != -1:
				dog_base_input.text = str(dog_ball)
			if cat_ball != -1:
				cat_base_input.text = str(cat_ball)

func _find_equivalent_ball(src_ball: int, src_defs: Dictionary, dest_defs: Dictionary) -> int:
	if src_defs.has(src_ball):
		var name: String = src_defs[src_ball].name
		for k in dest_defs:
			if dest_defs[k].name == name:
				return k
	return -1

func _on_GenerateButton_pressed() -> void:
	generate_clz()

func _on_CopyButton_pressed() -> void:
	OS.set_clipboard(text_edit.text)

func generate_clz() -> void:
	if not dog_generator or not dog_generator.lnz:
		text_edit.text = "Error: No file loaded"
		return

	var lnz = dog_generator.lnz

	var dog_base: int = -1
	var cat_base: int = -1
	var baby_base: int = -1
	var target_base: int = -1

	if current_species == KeyBallsData.Species.BABY:
		if baby_base_input.text.is_valid_integer():
			baby_base = int(baby_base_input.text)
			target_base = baby_base
	else:
		if dog_base_input.text.is_valid_integer():
			dog_base = int(dog_base_input.text)
		if cat_base_input.text.is_valid_integer():
			cat_base = int(cat_base_input.text)

		if current_species == KeyBallsData.Species.DOG:
			target_base = dog_base
		else:
			target_base = cat_base

	if target_base == -1:
		text_edit.text = "Error: Invalid Base Ball"
		return

	# 1. Collect [Add Ball] entries
	# Filter for addballs based on target_base
	var relevant_addballs: Array = []
	var old_to_new_idx: Dictionary = {} # original ball_no -> new index (1, 2, 3...)
	var next_idx: int = 1

	# Iterate all addballs in LNZ
	var sorted_keys: Array = lnz.addballs.keys()
	sorted_keys.sort()

	for k in sorted_keys:
		if lnz.omissions.has(k):
			continue
		var ab = lnz.addballs[k]
		if ab.base == target_base:
			relevant_addballs.append(ab)
			old_to_new_idx[k] = next_idx
			next_idx += 1

	sorted_keys.resize(0)

	# 2. Collect [Linez] entries
	var relevant_lines: Array = []
	for line in lnz.lines:
		# Check if start/end are in our relevant addballs
		# The prompt says: "involving those Addballz (NOT involving the base ball)"
		# So both start and end must be in old_to_new_idx
		if old_to_new_idx.has(line.start) and old_to_new_idx.has(line.end):
			relevant_lines.append(line)

	# 3. [Default Scalez]
	var pet_scale: float = lnz.scales.x
	var ball_scale: float = lnz.scales.y

	# 4. [Texture List]
	var texture_entries: Array = []
	for tex in lnz.texture_list:
		# Format: filename \t transparent_color (if present)
		var line: String = tex.filename
		if tex.transparent_color != null: # Assuming explicit null check if missing
			# Actually LnzParser defaults?
			# LnzParser stores transparent_color string.
			if tex.transparent_color != "":
				line += "\t" + str(tex.transparent_color)
				if tex.texture_size != null:
					line += "\t" + str(int(tex.texture_size.x)) + "\t" + str(int(tex.texture_size.y))
		texture_entries.append(line)

	# 5. BaseBallSize
	var base_ball_size: int = 60
	#if dog_generator.bhd and target_base < dog_generator.bhd.ball_sizes.size():
	#	base_ball_size = dog_generator.bhd.ball_sizes[target_base]

	# Construct Output
	var output: String = ""

	# Header
	output += "[Add Clothing]\n"
	output += kind_option.text + "\n"
	for t in texture_entries:
		output += t + "\n"
	output += "end\n"

	# Scales line
	output += "; petScale\tballScale\tbaseBallSize\tnumPetBalls\tnumPetLines\n"
	output += str(pet_scale) + "\t" + str(ball_scale) + "\t" + str(base_ball_size) + "\n"

	# Anchor Block
	output += ";bBall\tx\ty\tz\tcolor\toutCol\tfuzz\tcolGroup\toutType\tsize\ttexture\n"

	if current_species == KeyBallsData.Species.BABY:
		output += str(baby_base) + "\t0,0,0\t83\t83\t0\t0\t-1\t0\t0\n"
	else:
		output += "#2.A ; Dog\n"
		output += "-" + str(dog_base) + "\t0,0,0\t71\t35\t1\t0\t-1\t0\t0\n"
		output += "#1 ; Cat\n"
		output += "-" + str(cat_base) + "\t0,0,0\t71\t35\t1\t0\t-1\t0\t0\n"
		output += "##\n"

	# [Add Ball]
	for ab in relevant_addballs:
		var new_base: int = 0 # all attached to base ball 0 in CLZ
		var line_str: String = str(new_base) + "\t"
		line_str += str(int(ab.position.x)) + "," + str(int(ab.position.y)) + "," + str(int(ab.position.z)) + "\t"
		line_str += str(ab.color_index) + "\t"
		line_str += str(ab.outline_color_index) + "\t"
		line_str += str(ab.fuzz) + "\t"
		line_str += str(ab.group) + "\t"
		line_str += str(ab.outline) + "\t"
		line_str += str(ab.size) + "\t"
		line_str += str(ab.texture_id)
		output += line_str + "\n"

	output += "end\n"

	# [Linez]
	output += ";start\tend\tfuzz\tcol\tlfCol\trtCol\tsThck\teThick\tfulloutline\tdrawOrder\n"
	for l in relevant_lines:
		var new_start: int = old_to_new_idx[l.start]
		var new_end: int = old_to_new_idx[l.end]

		var line_str: String = str(new_start) + "\t" + str(new_end) + "\t"
		line_str += str(l.fuzz) + "\t"
		line_str += str(l.color_index) + "\t"
		line_str += str(l.l_color_index) + "\t"
		line_str += str(l.r_color_index) + "\t"
		line_str += str(l.s_thick) + "\t"
		line_str += str(l.e_thick)
		# handle fullOutline and lineOrder when we eventually add to Linez data and rendering
		output += line_str + "\n"

	output += "end"

	text_edit.text = output
