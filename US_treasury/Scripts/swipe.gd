extends Node   # or Control / Node2D, matching the node type

var swipe_start: Vector2 = Vector2.ZERO
var swipe_end: Vector2 = Vector2.ZERO
var swipe_min_dist: float = 80.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			swipe_start = mb.position
	if event is InputEventMouseButton:
		var mr := event as InputEventMouseButton
		if mr.button_index == MOUSE_BUTTON_LEFT and not mr.pressed:
			swipe_end = mr.position
			_process_swipe()

func _process_swipe() -> void:
	var delta := swipe_end - swipe_start
	if delta.length() < swipe_min_dist:
		return
	if abs(delta.x) > abs(delta.y):
		if delta.x < 0:
			print("SWIPE LEFT")
			_on_swipe_left()
		else:
			print("SWIPE RIGHT")
			_on_swipe_right()

func _on_swipe_left() -> void:
	print("→ LEFT OPTION SELECTED")

func _on_swipe_right() -> void:
	print("→ RIGHT OPTION SELECTED")
