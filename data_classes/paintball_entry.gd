## paintball_entry.gd
## A data class that holds a single paintball before committed to PaintballGroup
## Modeled after approach designed by Ziv for OpenPetz (thank you!)

extends Reference

var local_origin: Vector3 = Vector3.ZERO
var pb_normal: Vector3 = Vector3.ZERO
var ball_size: int = 1
var color_index: int = 0
var outline_color_index: int = 0
var outline: int = -1
var fuzz_amount: int = 0
var z_add: float = 0.0
var has_texture: bool = false
var texture: Texture
var texture_size: Vector2 = Vector2(256, 256)
var transparent_color: int = 0
var tile_texture: bool = true
var highlight: bool = false
var group: int = -1
var uid: int = -1
var paint_layer_id: int = -1
