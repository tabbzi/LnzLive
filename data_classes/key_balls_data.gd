extends Node
## key_balls_data.gd
## A data repository for species-specific ball information
## This script contains hardcoded data that defines key ball groups
## for different game species (Catz, Dogz, Babyz) and provides data for
## symmetry mapping, standard projection values, and body area assignments
## NOTE: figure out where KeyBallsData gets defined because apparently
## this cannot be called `class_name KeyBallsData`...

var bodyarea_map: Dictionary = {}

var legs_dog: Array = [
	[7, 31, 9, 10, 11, 13, 23, 33, 34, 35, 37, 47], # front legs 
	[40, 16, 0, 12, 20, 21, 22, 24, 36, 44, 45, 46], # back legs
]
var legs_cat: Array = [ 
	[12, 13, 16, 17, 18, 19, 20, 21, 22, 23, 63, 64], # front
	[0, 1, 32, 33, 34, 35, 41, 42, 49, 50, 51, 52, 53, 54] # back
]
var legs_bab: Array = [ 
	[30, 31, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 88, 89, 90, 91, 92, 93, 94, 95, 98, 99, 100, 101, 116, 117], # front
	[0, 1, 2, 3, 5, 6, 59, 60, 61, 62, 64, 65, 66, 67, 71, 72, 102, 103, 104, 105, 106, 107] # back
]

var body_ext_dog: Array = [ 49, 0, 12, 16, 20, 21, 22, 24, 36, 44, 45, 46, 43, 19, 40, 57, 58, 59, 60, 61, 62 ]
var body_ext_cat: Array = [ 2, 3, 0, 1, 32, 33, 34, 35, 41, 42, 49, 50, 51, 52, 53, 54, 25, 26, 43, 44, 45, 46, 47, 48 ]
var body_ext_bab: Array = [ 87, 0, 1, 2, 3, 4, 5, 6, 10, 11, 32, 33, 34, 59, 60, 61, 62, 64, 65, 66, 67, 70, 71, 72, 81, 87, 94, 95, 102, 103, 104, 105, 106, 107 ]

var face_ext_dog: Array = [ 51, 53, 55, 56, 63, 64, 17, 41, 15, 39 ]
var face_ext_cat: Array = [ 7, 30, 31, 37, 40, 57, 58, 59, 60, 61, 62, 29 ]
var face_ext_bab: Array = [ 7, 84, 82, 83, 85, 86, 8, 9, 79, 80, 12, 13, 14, 15, 109, 110, 111, 112, 113, 114, 115 ]

var head_ext_dog: Array = [ 52, 1, 2, 3, 4, 5, 6, 8, 14, 15, 17, 25, 26, 27, 28, 29, 30, 32, 38, 39, 41, 51, 53, 55, 56, 63, 64 ]
var head_ext_cat: Array = [ 24, 4, 5, 7, 8, 9, 10, 11, 14, 15, 27, 28, 29, 30, 31, 37, 40, 55, 56, 57, 58, 59, 60, 61, 62 ]
var head_ext_bab: Array = [ 7, 8, 9, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 63, 68, 69, 73, 74, 75, 76, 77, 78, 79, 80, 82, 83, 84, 85, 86, 96, 97, 108, 109, 110, 111, 112, 113, 114, 115 ]

var foot_ext_dog: Array = [ 
	[ 12, 20, 21, 22 ],
	[ 13, 9, 10, 11 ],
	[ 36, 44, 45, 46 ],
	[ 37, 33, 34, 35 ]
]
var foot_ext_cat: Array = [
	[ 22, 16, 17, 18 ],
	[ 23, 19, 20, 21 ],
	[ 41, 34, 49, 50, 51 ],
	[ 42, 35, 52, 53, 54 ]
]
var foot_ext_bab: Array = [
	[ 88, 90, 92, 98, 100, 47, 49, 51, 53, 55, 57 ],
	[ 89, 91, 93, 99, 101, 48, 50, 52, 54, 56, 58 ],
	[ 59, 61, 66, 5, 2, 102, 104, 106 ],
	[ 60, 62, 67, 6, 3, 103, 105, 107 ]
]

var ear_ext_dog: Dictionary = { 4: [5, 6], 28: [29, 30] }
var ear_ext_cat: Dictionary = { 8: [9], 10: [11]  }
var ear_ext_bab: Dictionary = { 28: [16, 18, 20, 22, 24, 26], 29: [17, 19, 21, 23, 25, 27]}

var eyes_dog: Dictionary = {14: 8, 38: 32} # iris = eye
var eyes_cat: Dictionary = { 27: 14, 28: 15}
var eyes_bab: Dictionary = { 68: 35, 69: 36 }

var nose_dog: Array = [17, 41, 55]
var nose_cat: Array = [37]
var nose_bab: Array = [84, 82, 83, 86, 85]

var eyebrow_bab: Array = [37, 38, 39, 40, 41, 42] # excluding eyebrows 37 to 42 too

var tail_dog: Array = [57, 58, 59, 60, 61, 62 ]
var tail_cat: Array = [43, 44, 45, 46, 47, 48 ]
var tail_bab: Array = []

var tongue_dog: Array = [63, 64]
var tongue_cat: Array = [55, 56]
var tongue_bab: Array = [108]

var belly_cat: int = 2
var belly_dog: int = 48
var belly_bab: int = 4

# NOTE: needs to be updated to reflect min and max possible for ballz typically set across original P.F. Magic breeds
var projection_standards: Dictionary = {
	"cat": [
		{"fixed_ball": 41, "project_ball": 34, "min_projection": 25, "max_projection": 75, "comment": "legs soleL to knuckleL"},
		{"fixed_ball": 42, "project_ball": 35, "min_projection": 25, "max_projection": 75, "comment": "legs soleR to knuckleR"},
		{"fixed_ball": 0, "project_ball": 41, "min_projection": 50, "max_projection": 125, "comment": "legs ankleL to soleL"},
		{"fixed_ball": 1, "project_ball": 42, "min_projection": 50, "max_projection": 125, "comment": "legs ankleR to soleR"},
		{"fixed_ball": 63, "project_ball": 22, "min_projection": 0, "max_projection": 125, "comment": "legs wristL to handL"},
		{"fixed_ball": 64, "project_ball": 23, "min_projection": 0, "max_projection": 125, "comment": "legs wristR to handR"},
		{"fixed_ball": 2, "project_ball": 6, "min_projection": 75, "max_projection": 100, "comment": "body belly to chest"},
		{"fixed_ball": 12, "project_ball": 63, "min_projection": 50, "max_projection": 125, "comment": "legs elbowL to wristL"},
		{"fixed_ball": 13, "project_ball": 64, "min_projection": 50, "max_projection": 125, "comment": "legs elbowR to wristR"},
		{"fixed_ball": 30, "project_ball": 57, "min_projection": 125, "max_projection": 150, "comment": "face jowlL to whiskerL1"},
		{"fixed_ball": 43, "project_ball": 44, "min_projection": 50, "max_projection": 150, "comment": "tail tail1 to tail2"},
		{"fixed_ball": 30, "project_ball": 58, "min_projection": 125, "max_projection": 150, "comment": "face jowlL to whiskerL2"},
		{"fixed_ball": 44, "project_ball": 45, "min_projection": 50, "max_projection": 150, "comment": "tail tail2 to tail3"},
		{"fixed_ball": 30, "project_ball": 59, "min_projection": 125, "max_projection": 150, "comment": "face jowlL to whiskerL3"},
		{"fixed_ball": 45, "project_ball": 46, "min_projection": 50, "max_projection": 150, "comment": "tail tail3 to tail4"},
		{"fixed_ball": 31, "project_ball": 60, "min_projection": 125, "max_projection": 150, "comment": "face jowlR to whiskerR1"},
		{"fixed_ball": 46, "project_ball": 47, "min_projection": 50, "max_projection": 150, "comment": "tail tail4 to tail5"},
		{"fixed_ball": 47, "project_ball": 48, "min_projection": 50, "max_projection": 150, "comment": "tail tail5 to tail6"},
		{"fixed_ball": 31, "project_ball": 61, "min_projection": 125, "max_projection": 150, "comment": "face jowlR to whiskerR2"},
		{"fixed_ball": 31, "project_ball": 62, "min_projection": 125, "max_projection": 150, "comment": "face jowlR to whiskerR3"}
	],
	"dog": [
		{"fixed_ball": 8, "project_ball": 1, "min_projection": 25, "max_projection": 125, "comment": "eyebrows"},
		{"fixed_ball": 8, "project_ball": 2, "min_projection": 0, "max_projection": 150, "comment": "eyebrows"},
		{"fixed_ball": 8, "project_ball": 3, "min_projection": 25, "max_projection": 125, "comment": "eyebrows"},
		{"fixed_ball": 32, "project_ball": 1, "min_projection": 25, "max_projection": 125, "comment": "eyebrows"},
		{"fixed_ball": 32, "project_ball": 25, "min_projection": 25, "max_projection": 125, "comment": "eyebrows"},
		{"fixed_ball": 49, "project_ball": 57, "min_projection": 0, "max_projection": 150, "comment": "tail butt to tail1"},
		{"fixed_ball": 32, "project_ball": 26, "min_projection": 0, "max_projection": 150, "comment": "eyebrows"},
		{"fixed_ball": 32, "project_ball": 27, "min_projection": 25, "max_projection": 125, "comment": "eyebrows"},
		{"fixed_ball": 8, "project_ball": 25, "min_projection": 25, "max_projection": 125, "comment": "eyebrows"},
		{"fixed_ball": 63, "project_ball": 64, "min_projection": 50, "max_projection": 125, "comment": "tongue tongue1 to tongue2"},
		{"fixed_ball": 51, "project_ball": 64, "min_projection": 75, "max_projection": 100, "comment": "tongue chin to tongue2"},
		{"fixed_ball": 57, "project_ball": 58, "min_projection": 0, "max_projection": 200, "comment": "tail tail1 to tail2"},
		{"fixed_ball": 19, "project_ball": 16, "min_projection": 50, "max_projection": 125, "comment": "legs hipL to kneeL"},
		{"fixed_ball": 48, "project_ball": 50, "min_projection": 50, "max_projection": 125, "comment": "body belly to chest"},
		{"fixed_ball": 52, "project_ball": 6, "min_projection": 25, "max_projection": 150, "comment": "ears head to earL3"},
		{"fixed_ball": 58, "project_ball": 59, "min_projection": 0, "max_projection": 225, "comment": "tail tail2 to tail3"},
		{"fixed_ball": 60, "project_ball": 61, "min_projection": 0, "max_projection": 200, "comment": "tail tail4 to tail5"},
		{"fixed_ball": 52, "project_ball": 30, "min_projection": 25, "max_projection": 150, "comment": "ears head to earR3"},
		{"fixed_ball": 59, "project_ball": 60, "min_projection": 0, "max_projection": 225, "comment": "tail tail3 to tail4"},
		{"fixed_ball": 61, "project_ball": 62, "min_projection": 0, "max_projection": 225, "comment": "tail tail5 to tail6"},
		{"fixed_ball": 56, "project_ball": 63, "min_projection": 50, "max_projection": 75, "comment": "tongue snout to tongue1"},
		{"fixed_ball": 52, "project_ball": 63, "min_projection": 125, "max_projection": 150, "comment": "tongue head to tongue1"},
		{"fixed_ball": 53, "project_ball": 63, "min_projection": 25, "max_projection": 125, "comment": "tongue jaw to tongue1"},
		{"fixed_ball": 43, "project_ball": 40, "min_projection": 75, "max_projection": 100, "comment": "legs hipR to kneeR"},
		{"fixed_ball": 55, "project_ball": 51, "min_projection": 25, "max_projection": 150, "comment": "face nose_bottom to chin"},
		{"fixed_ball": 0, "project_ball": 12, "min_projection": 50, "max_projection": 175, "comment": "legs ankleL to footL"},
		{"fixed_ball": 23, "project_ball": 7, "min_projection": 75, "max_projection": 100, "comment": "legs wristL to elbowL"},
		{"fixed_ball": 16, "project_ball": 0, "min_projection": 75, "max_projection": 100, "comment": "legs kneeL to ankleL"},
		{"fixed_ball": 24, "project_ball": 36, "min_projection": 50, "max_projection": 175, "comment": "feet ankleR to footR"},
		{"fixed_ball": 47, "project_ball": 31, "min_projection": 75, "max_projection": 100, "comment": "legs wristR to elbowR"},
		{"fixed_ball": 23, "project_ball": 13, "min_projection": 25, "max_projection": 175, "comment": "feet wristL to handL"},
		{"fixed_ball": 40, "project_ball": 24, "min_projection": 75, "max_projection": 100, "comment": "legs kneeR to ankleR"},
		{"fixed_ball": 47, "project_ball": 37, "min_projection": 25, "max_projection": 175, "comment": "feet wristR to handR"}
	],
	"bab": [
		{"fixed_ball": 4, "project_ball": 63, "min_projection": 80, "max_projection": 100, "comment": "bellyhead"}
	]
}

var symmetry_mode_hide_balls_cat: Array = [0, 4, 8, 9, 12, 14, 16, 17, 18, 22, 25, 27, 30, 32, 34, 38, 41, 49, 50, 51, 57, 58, 59, 63]
var symmetry_mode_hide_balls_dog: Array = []
var symmetry_mode_hide_balls_bab: Array = []

var symmetry_mode_right_balls_cat: Array = [1, 5, 10, 11, 13, 15, 19, 20, 21, 23, 26, 28, 31, 33, 35, 39, 42, 52, 53, 54, 60, 61, 62, 64]
var symmetry_mode_right_balls_dog: Array = []
var symmetry_mode_right_balls_bab: Array = []

var species: int = 0
var max_base_ball_num: int = 0

enum Species { CAT = 1, DOG = 2, BABY = 3 }

func _ready() -> void:
	for n in range(0, 24):
		symmetry_mode_hide_balls_dog.append(n)
	for n in range(24, 48):
		symmetry_mode_right_balls_dog.append(n)

	build_move_groups()
	
	# bodyarea values
	# 8 = head-related
	# 1 = body-related 

	# [0] Default 
	# [1] Body Balls  
	# [2] Right Leg Balls  
	# [3] Left Leg Balls  
	# [4] Right Hand Balls  
	# [5] Left Hand Balls  
	# [6] Right Foot Balls  
	# [7] Left Foot Balls  
	# [8] Head Balls  
	# [9] Right Arm Balls  
	# [10] Left Arm Balls  
	# [11] Right Ear Balls  
	# [12] Left Ear Balls  
	# [13] Tail Balls  
	# [14] Whisker Balls  
	# [15] Jowlz Balls  
	# [16] Tongue stuff  
	# [17] Right Brow Balls  
	# [18] Left Brow Balls  
	# [19] Extra Balls  
	# [20] Extra Head Balls 


# Catz
# 0 - game chooses
# 1 - torso; basic bodyarea #
# 2 - right-back leg
# 3 - left-back leg
# 4 - right fingers
# 5 - left fingers
# 6 - right-back foot
# 7 - left-back foot
# 8 - head
# 9 - front-right arm
# 10 - front-left arm; both shoulders
# 11 - right ear
# 12 - left ear
# 13 - tail
# 14 - whiskers
# 15 - face
# 16 - tongue

# Dogz
# 0 - game chooses
# 1 - torso; basic body area #
# 2 - right-back leg
# 3 - left-back leg
# 4 - right fingers
# 5 - left fingers
# 6 - right-back foot
# 7 - left-back foot
# 8 - head
# 9 - front-right arm
# 10 - front-left arm
# 11 - right ear
# 12 - left ear
# 13 - tail
# 14 - n/a as #
# 15 - face
# 16 - tongue
# 17 - right eyebrow
# 18 - left eyebrow


func build_bodyarea_map() -> void:
	bodyarea_map.clear()
	if species == Species.DOG:
		_build_bodyarea_map_dog()
	elif species == Species.CAT:
		_build_bodyarea_map_cat()
	elif species == Species.BABY:
		_build_bodyarea_map_baby()

	if typeof(max_base_ball_num) == TYPE_INT:
		for i in range(0, max_base_ball_num + 1):
			if not bodyarea_map.has(i):
				bodyarea_map[i] = 1

func _build_bodyarea_map_dog() -> void:
	# Default all balls to 0 (game chooses) 
	if typeof(max_base_ball_num) == TYPE_INT:
		for i in range(0, max_base_ball_num + 1):
			bodyarea_map[i] = 0

	var sym: Dictionary = dog_body_part_symmetry

	for b in move_groups_dog["Body"] + body_ext_dog: 
		bodyarea_map[b] = 1

	for b in sym.BackPaws.Legs.right: bodyarea_map[b] = 2
	for b in sym.BackPaws.Legs.left: bodyarea_map[b] = 3

	for b in sym.FrontPaws.Fingers.right: bodyarea_map[b] = 4
	for b in sym.FrontPaws.Fingers.left: bodyarea_map[b] = 5

	for b in sym.BackPaws.Feet.right + sym.BackPaws.Toes.right: bodyarea_map[b] = 6
	for b in sym.BackPaws.Feet.left + sym.BackPaws.Toes.left: bodyarea_map[b] = 7

	for b in move_groups_dog["Head"]: bodyarea_map[b] = 8

	for b in sym.FrontPaws.Arms.right: bodyarea_map[b] = 9
	for b in sym.FrontPaws.Arms.left: bodyarea_map[b] = 10

	for b in sym.Head.Ears.right: bodyarea_map[b] = 11
	for b in sym.Head.Ears.left: bodyarea_map[b] = 12

	for b in tail_dog: bodyarea_map[b] = 13

	for b in sym.Head.Jowls.right + sym.Head.Jowls.left + sym.Head.Nostrils.right + sym.Head.Nostrils.left:
		bodyarea_map[b] = 15

	for b in tongue_dog: bodyarea_map[b] = 16

	for b in sym.Head.Eyebrows.right: bodyarea_map[b] = 17
	for b in sym.Head.Eyebrows.left: bodyarea_map[b] = 18

func _build_bodyarea_map_cat() -> void:
	# Default all balls to 0 (game chooses) 
	if typeof(max_base_ball_num) == TYPE_INT:
		for i in range(0, max_base_ball_num + 1):
			bodyarea_map[i] = 0

	var sym: Dictionary = cat_body_part_symmetry # 

	for b in move_groups_cat["Body"] + body_ext_cat: 
		bodyarea_map[b] = 1

	for b in sym.BackPaws.Legs.right: bodyarea_map[b] = 2
	for b in sym.BackPaws.Legs.left: bodyarea_map[b] = 3

	for b in sym.FrontPaws.Fingers_Knuckles.right: bodyarea_map[b] = 4
	for b in sym.FrontPaws.Fingers_Knuckles.left: bodyarea_map[b] = 5

	for b in sym.BackPaws.Feet.right + sym.BackPaws.Toes.right: bodyarea_map[b] = 6
	for b in sym.BackPaws.Feet.left + sym.BackPaws.Toes.left: bodyarea_map[b] = 7

	for b in move_groups_cat["Head"]: bodyarea_map[b] = 8

	for b in sym.FrontPaws.Arms.right: bodyarea_map[b] = 9

	var arm_left_and_shoulders: Array = sym.FrontPaws.Arms.left + sym.Torso.Shoulders.left + sym.Torso.Shoulders.right
	for b in arm_left_and_shoulders: 
		bodyarea_map[b] = 10

	for b in sym.Head.Ears.right: bodyarea_map[b] = 11
	for b in sym.Head.Ears.left: bodyarea_map[b] = 12

	for b in tail_cat: bodyarea_map[b] = 13

	for b in sym.Head.Whiskers.left + sym.Head.Whiskers.right: bodyarea_map[b] = 14

	for b in sym.Head.Cheeks_Jowls.left + sym.Head.Cheeks_Jowls.right: bodyarea_map[b] = 15

	for b in tongue_cat: bodyarea_map[b] = 16

func _build_bodyarea_map_baby() -> void:
	for b in head_ext_bab + face_ext_bab + tongue_bab:
		bodyarea_map[b] = 8
	for b in eyes_bab.keys() + eyes_bab.values() + nose_bab:
		bodyarea_map[b] = 8
	for base in ear_ext_bab:
		bodyarea_map[base] = 8
		for b in ear_ext_bab[base]:
			bodyarea_map[b] = 8
	for b in tail_bab + body_ext_bab:
		bodyarea_map[b] = 1
	for group in legs_bab + foot_ext_bab:
		for b in group:
			bodyarea_map[b] = 1
	for b in symmetry_mode_right_balls_bab + symmetry_mode_hide_balls_bab:
		if not bodyarea_map.has(b):
			bodyarea_map[b] = 1

# // --- For CATZ ---

var cat_body_part_symmetry: Dictionary = {
	"Head": {
		"Eyes": { "left": [14, 27], "right": [15, 28] }, 
		"Ears": { "left": [8, 9], "right": [10, 11] }, 
		"Cheeks_Jowls": { "left": [4, 30], "right": [5, 31] },
		"Whiskers": { "left": [57, 58, 59], "right": [60, 61, 62] }, 
		"Head_Top_Sides": { "left": [87, 88], "right": [89] }
	},
	"Torso": {
		"Shoulders": { "left": [38], "right": [39] },
		"Hips": { "left": [25], "right": [26] }
	},
	"FrontPaws": {
		"Arms": { "left": [12, 63], "right": [13, 64] }, 
		"Hands": { "left": [22], "right": [23] },
		"Fingers_Knuckles": { "left": [16, 17, 18, 34], "right": [19, 20, 21, 35] }
	},
	"BackPaws": {
		"Legs": { "left": [32, 0], "right": [33, 1] }, 
		"Feet": { "left": [41], "right": [42] }, 
		"Toes": { "left": [49, 50, 51], "right": [52, 53, 54] }
	}
};

# // --- For DOGZ ---

var dog_body_part_symmetry: Dictionary = {
	"Head": {
		"Eyes": { "left": [8, 14], "right": [32, 38] }, 
		"Ears": { "left": [4, 5, 6], "right": [28, 29, 30] }, 
		"Eyebrows": { "left": [1, 2, 3], "right": [25, 26, 27] },
		"Jowls": { "left": [15], "right": [39] },
		"Nostrils": { "left": [17], "right": [41] },
		"Whiskers": { "left": [], "right": [] }
	},
	"Torso": {
		"Shoulders": { "left": [18], "right": [42] },
		"Hips": { "left": [19], "right": [43] }
	},
	"FrontPaws": {
		"Arms": { "left": [7, 23], "right": [31, 47] }, 
		"Hands": { "left": [13], "right": [37] },
		"Fingers": { "left": [9, 10, 11], "right": [33, 34, 35] }
	},
	"BackPaws": {
		"Legs": { "left": [16, 0], "right": [40, 24] },
		"Feet": { "left": [12], "right": [36] },
		"Toes": { "left": [20, 21, 22], "right": [44, 45, 46] }
	}
};

# // --- For BABYZ ---

var baby_body_part_symmetry: Dictionary = {
	"Head": {
		"Eyes": { "left": [35, 68], "right": [36, 69] }, 
		"Eyebrows": { "left": [37, 39, 41, 43, 45], "right": [38, 40, 42, 44, 46] }, 
		"Ears": { "left": [16, 18, 20, 22, 24, 26, 28], "right": [17, 19, 21, 23, 25, 27, 29] },
		"Face_Sides": { "left": [8, 96], "right": [9, 97] }, 
		"Mouth": { "left": [79, 85], "right": [80, 86] }
	},
	"Torso": {
		"Chest": { "left": [10], "right": [11] },
		"Shoulders": { "left": [94], "right": [95] },
		"Hips": { "left": [66], "right": [67] }
	},
	"Hands": {
		"Arms": { "left": [30, 116], "right": [31, 117] },
		"Palms": { "left": [88, 90, 92], "right": [89, 91, 93] },
		"Fingers_Thumbs": { "left": [47, 49, 51, 53, 55, 57, 98, 100], "right": [48, 50, 52, 54, 56, 58, 99, 101] }
	},
	"Feet": {
		"Legs": { "left": [71, 0], "right": [72, 1] },
		"Soles": { "left": [2, 64], "right": [3, 65] },
		"Toes": { "left": [5, 102, 104, 106], "right": [6, 103, 105, 107] }
	}
};

func get_mirrored_ball(ball_no: int, symmetry_dict: Dictionary) -> int:
	for main_part in symmetry_dict:
		for sub_part in symmetry_dict[main_part]:
			var part_info: Dictionary = symmetry_dict[main_part][sub_part]
			if part_info.has("left") and part_info.has("right"):
				if ball_no in part_info.left:
					var index: int = part_info.left.find(ball_no)
					if index != -1 and index < part_info.right.size():
						return part_info.right[index]
				elif ball_no in part_info.right:
					var index: int = part_info.right.find(ball_no)
					if index != -1 and index < part_info.left.size():
						return part_info.left[index]
	return -1 # No mirror found

var cat_ball_definitions: Dictionary = {
	0: { "name": "ankleL", "pair": 1 },
	1: { "name": "ankleR", "pair": 0 },
	2: { "name": "belly", "pair": -1 },
	3: { "name": "butt", "pair": -1 },
	4: { "name": "cheekL", "pair": 5 },
	5: { "name": "cheekR", "pair": 4 },
	6: { "name": "chest", "pair": -1 },
	7: { "name": "chin", "pair": -1 },
	8: { "name": "earL1", "pair": 10 },
	9: { "name": "earL2", "pair": 11 },
	10: { "name": "earR1", "pair": 8 },
	11: { "name": "earR2", "pair": 9 },
	12: { "name": "elbowL", "pair": 13 },
	13: { "name": "elbowR", "pair": 12 },
	14: { "name": "eyeL", "pair": 15 },
	15: { "name": "eyeR", "pair": 14 },
	16: { "name": "fingerL1", "pair": 19 },
	17: { "name": "fingerL2", "pair": 20 },
	18: { "name": "fingerL3", "pair": 21 },
	19: { "name": "fingerR1", "pair": 16 },
	20: { "name": "fingerR2", "pair": 17 },
	21: { "name": "fingerR3", "pair": 18 },
	22: { "name": "handL", "pair": 23 },
	23: { "name": "handR", "pair": 22 },
	24: { "name": "head", "pair": -1 },
	25: { "name": "hipL", "pair": 26 },
	26: { "name": "hipR", "pair": 25 },
	27: { "name": "irisL", "pair": 28 },
	28: { "name": "irisR", "pair": 27 },
	29: { "name": "jaw", "pair": -1 },
	30: { "name": "jowlL", "pair": 31 },
	31: { "name": "jowlR", "pair": 30 },
	32: { "name": "kneeL", "pair": 33 },
	33: { "name": "kneeR", "pair": 32 },
	34: { "name": "knuckleL", "pair": 35 },
	35: { "name": "knuckleR", "pair": 34 },
	36: { "name": "neck", "pair": -1 },
	37: { "name": "nose", "pair": -1 },
	38: { "name": "shoulderL", "pair": 39 },
	39: { "name": "shoulderR", "pair": 38 },
	40: { "name": "snout", "pair": -1 },
	41: { "name": "soleL", "pair": 42 },
	42: { "name": "soleR", "pair": 41 },
	43: { "name": "tail1", "pair": -1 },
	44: { "name": "tail2", "pair": -1 },
	45: { "name": "tail3", "pair": -1 },
	46: { "name": "tail4", "pair": -1 },
	47: { "name": "tail5", "pair": -1 },
	48: { "name": "tail6", "pair": -1 },
	49: { "name": "toeL1", "pair": 52 },
	50: { "name": "toeL2", "pair": 53 },
	51: { "name": "toeL3", "pair": 54 },
	52: { "name": "toeR1", "pair": 49 },
	53: { "name": "toeR2", "pair": 50 },
	54: { "name": "toeR3", "pair": 51 },
	55: { "name": "tongue1", "pair": -1 },
	56: { "name": "tongue2", "pair": -1 },
	57: { "name": "whiskerL1", "pair": 60 },
	58: { "name": "whiskerL2", "pair": 61 },
	59: { "name": "whiskerL3", "pair": 62 },
	60: { "name": "whiskerR1", "pair": 57 },
	61: { "name": "whiskerR2", "pair": 58 },
	62: { "name": "whiskerR3", "pair": 59 },
	63: { "name": "wristL", "pair": 64 },
	64: { "name": "wristR", "pair": 63 },
	65: { "name": "zorient", "pair": -1 },
	66: { "name": "ztrans", "pair": -1 },
	# utility
	67: { "name": "mount align ball", "pair": -1 },
	68: { "name": "steal captured toy align ball", "pair": -1 },
	69: { "name": "steal toy standing align ball", "pair": -1 },
	70: { "name": "dig align ball", "pair": -1 },
	71: { "name": "fill in hole align ball", "pair": -1 },
	72: { "name": "rest on pillow align ball", "pair": -1 },
	73: { "name": "drop object at point align ball", "pair": -1 },
	74: { "name": "utility ball", "pair": -1 },
	75: { "name": "utility ball", "pair": -1 },
	76: { "name": "utility ball", "pair": -1 },
	# breed-specific
	77: { "name": "nose_extra", "pair": -1 },
	78: { "name": "nose_extra", "pair": -1 },
	79: { "name": "nose_extra", "pair": -1 },
	80: { "name": "head_ears_region", "pair": -1 },
	81: { "name": "head_ears_region", "pair": -1 },
	82: { "name": "head_ears_region", "pair": -1 },
	85: { "name": "head_ears_region", "pair": -1 },
	86: { "name": "head_ears_region", "pair": -1 },
	87: { "name": "head_left_top_side", "pair": 89 },
	88: { "name": "head_ears_region", "pair": -1 },
	89: { "name": "head_right_top_side", "pair": 87 },
	90: { "name": "ears", "pair": -1 },
	91: { "name": "ears", "pair": -1 },
	92: { "name": "fangs_or_ruff", "pair": -1 },
	93: { "name": "fangs_or_ruff", "pair": -1 }
}

var dog_ball_definitions: Dictionary = {
	0: { "name": "ankleL", "pair": 24 },
	1: { "name": "eyebrowL1", "pair": 25 },
	2: { "name": "eyebrowL2", "pair": 26 },
	3: { "name": "eyebrowL3", "pair": 27 },
	4: { "name": "earL1", "pair": 28 },
	5: { "name": "earL2", "pair": 29 },
	6: { "name": "earL3", "pair": 30 },
	7: { "name": "elbowL", "pair": 31 },
	8: { "name": "eyeL", "pair": 32 },
	9: { "name": "fingerL1", "pair": 33 },
	10: { "name": "fingerL2", "pair": 34 },
	11: { "name": "fingerL3", "pair": 35 },
	12: { "name": "footL", "pair": 36 },
	13: { "name": "handL", "pair": 37 },
	14: { "name": "irisL", "pair": 38 },
	15: { "name": "jowlL", "pair": 39 },
	16: { "name": "kneeL", "pair": 40 },
	17: { "name": "nostrilL", "pair": 41 },
	18: { "name": "shoulderL", "pair": 42 },
	19: { "name": "hipL", "pair": 43 },
	20: { "name": "toeL1", "pair": 44 },
	21: { "name": "toeL2", "pair": 45 },
	22: { "name": "toeL3", "pair": 46 },
	23: { "name": "wristL", "pair": 47 },
	24: { "name": "ankleR", "pair": 0 },
	25: { "name": "eyebrowR1", "pair": 1 },
	26: { "name": "eyebrowR2", "pair": 2 },
	27: { "name": "eyebrowR3", "pair": 3 },
	28: { "name": "earR1", "pair": 4 },
	29: { "name": "earR2", "pair": 5 },
	30: { "name": "earR3", "pair": 6 },
	31: { "name": "elbowR", "pair": 7 },
	32: { "name": "eyeR", "pair": 8 },
	33: { "name": "fingerR1", "pair": 9 },
	34: { "name": "fingerR2", "pair": 10 },
	35: { "name": "fingerR3", "pair": 11 },
	36: { "name": "footR", "pair": 12 },
	37: { "name": "handR", "pair": 13 },
	38: { "name": "irisR", "pair": 14 },
	39: { "name": "jowlR", "pair": 15 },
	40: { "name": "kneeR", "pair": 16 },
	41: { "name": "nostrilR", "pair": 17 },
	42: { "name": "shoulderR", "pair": 18 },
	43: { "name": "hipR", "pair": 19 },
	44: { "name": "toeR1", "pair": 20 },
	45: { "name": "toeR2", "pair": 21 },
	46: { "name": "toeR3", "pair": 22 },
	47: { "name": "wristR", "pair": 23 },
	48: { "name": "belly", "pair": -1 },
	49: { "name": "butt", "pair": -1 },
	50: { "name": "chest", "pair": -1 },
	51: { "name": "chin", "pair": -1 },
	52: { "name": "head", "pair": -1 },
	53: { "name": "jaw", "pair": -1 },
	54: { "name": "neck", "pair": -1 },
	55: { "name": "nose_bottom", "pair": -1 },
	56: { "name": "snout", "pair": -1 },
	57: { "name": "tail1", "pair": -1 },
	58: { "name": "tail2", "pair": -1 },
	59: { "name": "tail3", "pair": -1 },
	60: { "name": "tail4", "pair": -1 },
	61: { "name": "tail5", "pair": -1 },
	62: { "name": "tail6", "pair": -1 },
	63: { "name": "tongue1", "pair": -1 },
	64: { "name": "tongue2", "pair": -1 },
	65: { "name": "ztrans", "pair": -1 },
	66: { "name": "zorient", "pair": -1 },
	# utility
	67: { "name": "mount align ball", "pair": -1 },
	68: { "name": "steal captured toy align ball", "pair": -1 },
	69: { "name": "steal toy standing align ball", "pair": -1 },
	70: { "name": "dig align ball", "pair": -1 },
	71: { "name": "fill in hole align ball", "pair": -1 },
	72: { "name": "rest on pillow align ball", "pair": -1 },
	73: { "name": "drop object at point align ball", "pair": -1 },
	74: { "name": "utility ball", "pair": -1 },
	75: { "name": "utility ball", "pair": -1 },
	76: { "name": "utility ball", "pair": -1 },
	# breed-specific
	77: { "name": "ear_top_L_spot", "pair": 80 },
	78: { "name": "ear_sec_top_R_spot", "pair": 79 },
	79: { "name": "ear_sec_top_L_spot", "pair": 78 },
	80: { "name": "ear_top_R_spot", "pair": 77 },
	81: { "name": "ear_third_top_R_spot", "pair": 82 },
	82: { "name": "ear_third_top_L_spot", "pair": 81 },
	83: { "name": "tail_extra", "pair": -1 },
	84: { "name": "tail_extra", "pair": -1 },
	85: { "name": "tail_extra", "pair": -1 },
	86: { "name": "tail_extra", "pair": -1 },
	87: { "name": "tail_extra", "pair": -1 },
	88: { "name": "tongue_or_chin", "pair": -1 },
	89: { "name": "test_cover_jowls", "pair": -1 },
	90: { "name": "test_cover_jowls", "pair": -1 },
	91: { "name": "cheek_jowls", "pair": -1 },
	92: { "name": "cheek_jowls", "pair": -1 },
	93: { "name": "inside_mouth_L", "pair": 94 },
	94: { "name": "inside_mouth_R", "pair": 93 }
}

var bab_ball_definitions: Dictionary = {
	0: { "name": "ankleL"},
	1: { "name": "ankleR"},
	2: { "name": "archL"},
	3: { "name": "archR"},
	4: { "name": "belly"},
	5: { "name": "bigtoeL"},
	6: { "name": "bigtoeR"},
	7: { "name": "bridge"},
	8: { "name": "cheekL"},
	9: { "name": "cheekR"},
	10: { "name": "chestL"},
	11: { "name": "chestR"},
	12: { "name": "chin1"},
	13: { "name": "chin2"},
	14: { "name": "chin3"},
	15: { "name": "chin4"},
	16: { "name": "ear1L"},
	17: { "name": "ear1R"},
	18: { "name": "ear2L"},
	19: { "name": "ear2R"},
	20: { "name": "ear3L"},
	21: { "name": "ear3R"},
	22: { "name": "ear4L"},
	23: { "name": "ear4R"},
	24: { "name": "ear5L"},
	25: { "name": "ear5R"},
	26: { "name": "ear6L"},
	27: { "name": "ear6R"},
	28: { "name": "earcenterL"},
	29: { "name": "earcenterR"},
	30: { "name": "elbowL"},
	31: { "name": "elbowR"},
	32: { "name": "extra1"},
	33: { "name": "extra2"},
	34: { "name": "extra3"},
	35: { "name": "eyeL"},
	36: { "name": "eyeR"},
	37: { "name": "eyebrow1L"},
	38: { "name": "eyebrow1R"},
	39: { "name": "eyebrow2L"},
	40: { "name": "eyebrow2R"},
	41: { "name": "eyebrow3L"},
	42: { "name": "eyebrow3R"},
	43: { "name": "eyebrow4L"},
	44: { "name": "eyebrow4R"},
	45: { "name": "eyebrow5L"},
	46: { "name": "eyebrow5R"},
	47: { "name": "finger_index1L"},
	48: { "name": "finger_index1R"},
	49: { "name": "finger_index2L"},
	50: { "name": "finger_index2R"},
	51: { "name": "finger_middle1L"},
	52: { "name": "finger_middle1R"},
	53: { "name": "finger_middle2L"},
	54: { "name": "finger_middle2R"},
	55: { "name": "finger_pinky1L"},
	56: { "name": "finger_pinky1R"},
	57: { "name": "finger_pinky2L"},
	58: { "name": "finger_pinky2R"},
	59: { "name": "football1L"},
	60: { "name": "football1R"},
	61: { "name": "football2L"},
	62: { "name": "football2R"},
	63: { "name": "head"},
	64: { "name": "heelL"},
	65: { "name": "heelR"},
	66: { "name": "hipL"},
	67: { "name": "hipR"},
	68: { "name": "irisL"},
	69: { "name": "irisR"},
	70: { "name": "jock"},
	71: { "name": "kneeL"},
	72: { "name": "kneeR"},
	73: { "name": "lowerLip1"},
	74: { "name": "lowerLip2"},
	75: { "name": "lowerLip3"},
	76: { "name": "lowerLip4"},
	77: { "name": "lowerLip5"},
	78: { "name": "lowerLip6"},
	79: { "name": "mouthTopL"},
	80: { "name": "mouthTopR"},
	81: { "name": "neck"},
	82: { "name": "nose1"},
	83: { "name": "nose2"},
	84: { "name": "nosemiddle"},
	85: { "name": "nostrilL"},
	86: { "name": "nostrilR"},
	87: { "name": "origin"},
	88: { "name": "palm1L"},
	89: { "name": "palm1R"},
	90: { "name": "palm2L"},
	91: { "name": "palm2R"},
	92: { "name": "palm3L"},
	93: { "name": "palm3R"},
	94: { "name": "shoulderL"},
	95: { "name": "shoulderR"},
	96: { "name": "templeL"},
	97: { "name": "templeR"},
	98: { "name": "thumb1L"},
	99: { "name": "thumb1R"},
	100: { "name": "thumb2L"},
	101: { "name": "thumb2R"},
	102: { "name": "toe_indexL"},
	103: { "name": "toe_indexR"},
	104: { "name": "toe_middleL"},
	105: { "name": "toe_middleR"},
	106: { "name": "toe_pinkyL"},
	107: { "name": "toe_pinkyR"},
	108: { "name": "tongue1"},
	109: { "name": "underchin"},
	110: { "name": "upperLip1"},
	111: { "name": "upperLip2"},
	112: { "name": "upperLip3"},
	113: { "name": "upperLip4"},
	114: { "name": "upperLip5"},
	115: { "name": "upperLip6"},
	116: { "name": "wristL"},
	117: { "name": "wristR"},
	118: { "name": "zorient"},
	119: { "name": "ztrans" }
}

func get_ball_id_by_name(target_name: String) -> int:
	var defs: Dictionary = {}
	match species:
		Species.CAT: defs = cat_ball_definitions
		Species.DOG: defs = dog_ball_definitions
		Species.BABY: defs = bab_ball_definitions
	
	for id in defs:
		if defs[id].get("name") == target_name:
			return id
	return -1

# Move Groups
# (can't just use the ext groups cuz that is for extension sections and missing some ballz; can't use the symmetry def b/c that misses center ballz)
var move_groups_dog: Dictionary = {}
var move_groups_cat: Dictionary = {}
var move_groups_bab: Dictionary = {}

func build_move_groups() -> void:
	var dog_torso: Array = [18, 42, 19, 43, 50, 48, 49, 54]
	
	move_groups_dog = {
		"Head": head_ext_dog.duplicate(),
		"Body": dog_torso, 
		"Legs": _flatten(legs_dog),
		"Tail": tail_dog.duplicate(),
		"Ears": _flatten_dict(ear_ext_dog),
		"Eyes": eyes_dog.values() + eyes_dog.keys()
	}
	move_groups_dog["Head"].append_array(tongue_dog)

	var cat_torso: Array = [38, 39, 25, 26, 6, 2, 3, 36]
	
	move_groups_cat = {
		"Head": head_ext_cat.duplicate(),
		"Body": cat_torso,
		"Legs": _flatten(legs_cat),
		"Tail": tail_cat.duplicate(),
		"Ears": _flatten_dict(ear_ext_cat),
		"Eyes": eyes_cat.values() + eyes_cat.keys()
	}
	move_groups_cat["Head"].append_array(tongue_cat)

	var bab_torso: Array = [94, 95, 66, 67, 10, 11, 4, 70, 81]
	
	move_groups_bab = {
		"Head": head_ext_bab.duplicate(),
		"Body": bab_torso,
		"Legs": _flatten(legs_bab),
		"Tail": [],
		"Ears": _flatten_dict(ear_ext_bab),
		"Eyes": eyes_bab.values() + eyes_bab.keys()
	}
	move_groups_bab["Head"].append_array(tongue_bab)

func _init() -> void:
	build_move_groups()

func _flatten(array_of_arrays: Array) -> Array:
	var flat: Array = []
	for group in array_of_arrays:
		flat.append_array(group)
	return flat

func _flatten_dict(dict_of_arrays: Dictionary) -> Array:
	var flat: Array = []
	for key in dict_of_arrays:
		flat.append(key)
		flat.append_array(dict_of_arrays[key])
	return flat

func get_group_balls(group_name: String) -> Array:
	var result: Array = []
	
	match species:
		Species.DOG:
			if move_groups_dog.has(group_name):
				result = move_groups_dog[group_name]
		Species.CAT:
			if move_groups_cat.has(group_name):
				result = move_groups_cat[group_name]
		Species.BABY:
			if move_groups_bab.has(group_name):
				result = move_groups_bab[group_name]
				
	return result

### SPECIES GETTERS ###

func get_legs(s: int) -> Array:
	match s:
		Species.DOG: return legs_dog
		Species.CAT: return legs_cat
		Species.BABY: return legs_bab
	return []

func get_body_ext(s: int) -> Array:
	match s:
		Species.DOG: return body_ext_dog
		Species.CAT: return body_ext_cat
		Species.BABY: return body_ext_bab
	return []

func get_face_ext(s: int) -> Array:
	match s:
		Species.DOG: return face_ext_dog
		Species.CAT: return face_ext_cat
		Species.BABY: return face_ext_bab
	return []

func get_head_ext(s: int) -> Array:
	match s:
		Species.DOG: return head_ext_dog
		Species.CAT: return head_ext_cat
		Species.BABY: return head_ext_bab
	return []

func get_foot_ext(s: int) -> Array:
	match s:
		Species.DOG: return foot_ext_dog
		Species.CAT: return foot_ext_cat
		Species.BABY: return foot_ext_bab
	return []

func get_ear_ext(s: int) -> Dictionary:
	match s:
		Species.DOG: return ear_ext_dog
		Species.CAT: return ear_ext_cat
		Species.BABY: return ear_ext_bab
	return {}

func get_eyes(s: int) -> Dictionary:
	match s:
		Species.DOG: return eyes_dog
		Species.CAT: return eyes_cat
		Species.BABY: return eyes_bab
	return {}

func get_nose(s: int) -> Array:
	match s:
		Species.DOG: return nose_dog
		Species.CAT: return nose_cat
		Species.BABY: return nose_bab
	return []

func get_eyebrow_bab() -> Array:
	return eyebrow_bab

func get_tail(s: int) -> Array:
	match s:
		Species.DOG: return tail_dog
		Species.CAT: return tail_cat
		Species.BABY: return tail_bab
	return []

func get_tongue(s: int) -> Array:
	match s:
		Species.DOG: return tongue_dog
		Species.CAT: return tongue_cat
		Species.BABY: return tongue_bab
	return []

func get_belly(s: int) -> int:
	match s:
		Species.DOG: return belly_dog
		Species.CAT: return belly_cat
		Species.BABY: return belly_bab
	return -1

func get_move_groups(s: int) -> Dictionary:
	match s:
		Species.DOG: return move_groups_dog
		Species.CAT: return move_groups_cat
		Species.BABY: return move_groups_bab
	return {}

func get_extensions(s: int) -> Dictionary:
	var ext: Dictionary = {}
	match s:
		Species.DOG:
			ext = {
				legs = legs_dog,
				body_ext = body_ext_dog,
				face_ext = face_ext_dog,
				head_ext = head_ext_dog,
				foot_ext = foot_ext_dog,
				ear_ext = ear_ext_dog
			}
		Species.CAT:
			var h = head_ext_cat.duplicate()
			for e in eyes_cat:
				h.erase(e)
			ext = {
				legs = legs_cat,
				body_ext = body_ext_cat,
				face_ext = face_ext_cat,
				head_ext = h,
				foot_ext = foot_ext_cat,
				ear_ext = ear_ext_cat
			}
		Species.BABY:
			ext = {
				legs = legs_bab,
				body_ext = body_ext_bab,
				face_ext = face_ext_bab,
				head_ext = head_ext_bab,
				foot_ext = foot_ext_bab,
				ear_ext = ear_ext_bab
			}
	return ext

func get_symmetry_dict(s: int) -> Dictionary:
	match s:
		Species.DOG: return dog_body_part_symmetry
		Species.CAT: return cat_body_part_symmetry
		Species.BABY: return baby_body_part_symmetry
	return {}

func get_mirror_sides(s: int) -> Dictionary:
	var result: Dictionary = {"left": [], "right": []}
	match s:
		Species.CAT:
			result = {"left": symmetry_mode_hide_balls_cat, "right": symmetry_mode_right_balls_cat}
		Species.DOG:
			result = {"left": symmetry_mode_hide_balls_dog, "right": symmetry_mode_right_balls_dog}
		Species.BABY:
			result = {"left": symmetry_mode_hide_balls_bab, "right": symmetry_mode_right_balls_bab}
	return result

func get_ball_definitions(s: int) -> Dictionary:
	match s:
		Species.DOG: return dog_ball_definitions
		Species.CAT: return cat_ball_definitions
		Species.BABY: return bab_ball_definitions
	return {}

func get_projection_key(s: int) -> String:
	match s:
		Species.DOG: return "dog"
		Species.CAT: return "cat"
		Species.BABY: return "bab"
	return ""

func get_recolor_exclusions(s: int, intended_part: String = "") -> Array:
	var excluded: Array = []
	match s:
		Species.CAT:
			for b in move_groups_cat["Eyes"]: excluded.append(b)
			if intended_part != "NOSE":
				for n in nose_cat: excluded.append(n)
			if intended_part != "TONGUE":
				for t in tongue_cat: excluded.append(t)
			for w in cat_body_part_symmetry["Head"]["Whiskers"]["left"]: excluded.append(w)
			for w in cat_body_part_symmetry["Head"]["Whiskers"]["right"]: excluded.append(w)
		Species.DOG:
			for b in move_groups_dog["Eyes"]: excluded.append(b)
			if intended_part != "NOSE":
				for n in nose_dog: excluded.append(n)
			if intended_part != "TONGUE":
				for t in tongue_dog: excluded.append(t)
		Species.BABY:
			for b in move_groups_bab["Eyes"]: excluded.append(b)
			if intended_part != "TONGUE":
				for t in tongue_bab: excluded.append(t)
			for e in eyebrow_bab: excluded.append(e)
	return excluded

func get_recolor_targets(s: int, action: String) -> Array:
	var result: Array = []
	match s:
		Species.DOG, Species.CAT, Species.BABY:
			match action:
				"LEGS":
					var legs = get_legs(s)
					result.append_array(legs[0])
					result.append_array(legs[1])
					var foot = get_foot_ext(s)
					for f in foot:
						for v in f:
							result.erase(v)
				"TAIL":
					result.append_array(get_tail(s))
				"HEAD":
					result.append_array(get_head_ext(s))
				"SNOUT":
					result.append_array(get_face_ext(s))
				"EARS":
					var ear = get_ear_ext(s)
					for k in ear:
						result.append(k)
						result.append_array(ear[k])
				"PAWS":
					var foot = get_foot_ext(s)
					for f in foot:
						result.append_array(f)
				"NOSE":
					result.append_array(get_nose(s))
				"TONGUE":
					result.append_array(get_tongue(s))
	return result

func get_fuzz_exclusions(s: int) -> Array:
	var excluded: Array = []
	match s:
		Species.CAT:
			for b in move_groups_cat["Eyes"]: excluded.append(b)
			for t in tongue_cat: excluded.append(t)
			for w in cat_body_part_symmetry["Head"]["Whiskers"]["left"]: excluded.append(w)
			for w in cat_body_part_symmetry["Head"]["Whiskers"]["right"]: excluded.append(w)
		Species.DOG:
			for b in move_groups_dog["Eyes"]: excluded.append(b)
			for t in tongue_dog: excluded.append(t)
		Species.BABY:
			for b in move_groups_bab["Eyes"]: excluded.append(b)
			for t in tongue_bab: excluded.append(t)
	return excluded

func get_default_whisker_connections(s: int) -> Array:
	if s != Species.CAT:
		return []
	var connections: Array = []
	var jowlL: int = get_ball_id_by_name("jowlL")
	var jowlR: int = get_ball_id_by_name("jowlR")
	if jowlL == -1 or jowlR == -1:
		return []
	var whiskers: Dictionary = cat_body_part_symmetry.Head.Whiskers
	for w in whiskers.left:
		connections.append({"start": w, "end": jowlL})
	for w in whiskers.right:
		connections.append({"start": w, "end": jowlR})
	return connections

func get_species_display_name(s: int) -> String:
	match s:
		Species.CAT: return "Catz"
		Species.DOG: return "Dogz"
		Species.BABY: return "Babyz"
	return "Petz"

func get_belly_ball_id(s: int) -> int:
	match s:
		Species.DOG: return belly_dog
		Species.CAT: return belly_cat
		Species.BABY: return belly_bab
	return -1

func is_known_species(s: int) -> bool:
	return s == Species.CAT or s == Species.DOG or s == Species.BABY
