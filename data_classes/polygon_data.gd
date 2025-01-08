extends Resource
class_name PolyData

var ball1: int
var ball2: int
var ball3: int
var ball4: int
var color: int
var l_edge_color: int = -1
var r_edge_color: int = -1
var fuzz: int = 0
var texture_id: int = -1

func _init(ball1: int, ball2: int, ball3: int, ball4: int, color: int, l_edge_color: int, r_edge_color: int, fuzz: int, texture_id: int):
	self.ball1 = ball1
	self.ball2 = ball2
	self.ball3 = ball3
	self.ball4 = ball4
	self.color = color
	self.l_edge_color = l_edge_color
	self.r_edge_color = r_edge_color
	self.fuzz = fuzz
	self.texture_id = texture_id
