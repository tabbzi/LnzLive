extends LinkButton

func _ready():
	connect("pressed", self, "_on_GuideLinkButton_pressed")

func _on_GuideLinkButton_pressed():
	OS.shell_open("https://github.com/tabbzi/LnzLive/blob/master/GUIDE.md")
