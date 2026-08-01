extends PanelContainer

signal select_balls(ids)

onready var vbox: VBoxContainer = $VBoxContainer
onready var hbox: HBoxContainer = $VBoxContainer/BallRangeHBox
onready var label: Label = $VBoxContainer/BallRangeHBox/BallRangeLabel
onready var edit: LineEdit = $VBoxContainer/BallRangeHBox/BallRangeEdit

func _ready():
	edit.connect("text_changed", self, "_on_AffectedBallz_text_changed")

func _on_AffectedBallz_text_changed(new_text: String) -> void:
	var ids: Array = LnzLiveUtils.parse_number_list(new_text)
	emit_signal("select_balls", ids)
