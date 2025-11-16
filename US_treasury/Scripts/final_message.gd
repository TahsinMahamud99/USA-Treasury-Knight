extends Label

@export var question_generator_path: NodePath

@onready var question_generator: Node = get_node_or_null(question_generator_path)

var _state: int = 0          # 0 = none, 1 = victory, 2 = defeat
var _pulse_time: float = 0.0


func _ready() -> void:
	visible = false
	text = ""
	scale = Vector2.ONE
	

func _process(delta: float) -> void:
	# If no reference, nothing to do
	if question_generator == null:
		return
	
	# Ensure methods exist
	if not question_generator.has_method("get_dragon_health"):
		return
	if not question_generator.has_method("get_player_health"):
		return

	# Fetch health values
	var dragon_hp: int = question_generator.get_dragon_health()
	var player_hp: int = question_generator.get_player_health()

	# Check victory / defeat once
	if dragon_hp <= 0 and _state != 1:
		_show_victory()
	elif player_hp <= 0 and _state != 2:
		_show_defeat()

	# Pulse animation only for victory
	if _state == 1:
		_pulse_time += delta * 4.0
		var s: float = 1.0 + 0.1 * sin(_pulse_time)
		scale = Vector2(s, s)
	else:
		scale = Vector2.ONE


# -----------------------
#   SHOW MESSAGES
# -----------------------

func _show_victory() -> void:
	_state = 1
	text = "Congratulations! You have defeated the dragon!"
	add_theme_color_override("font_color", Color(1, 1, 0)) # yellow
	visible = true


func _show_defeat() -> void:
	_state = 2
	text = "You have fallen, hero"
	add_theme_color_override("font_color", Color(1, 0, 0)) # red
	visible = true
