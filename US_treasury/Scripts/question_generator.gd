extends Control

signal dragon_health_changed(new_health: int)
signal player_health_changed(new_health: int)

var _next_attack_is_fireball: bool = false
var _attack_used_for_current_question: bool = false

var _dragon_health: int = 100
var _player_health: int = 100

# Battle control
var _battle_over: bool = false
var _dragon_dead_handled: bool = false
var _player_dead_handled: bool = false
var _player_pending_death: bool = false
var _dragon_pending_death: bool = false
var _next_question_timer: SceneTreeTimer

@export var questions_path: String = "res://data/generated_questions_state_51.json"
@export var dragon_head_path: NodePath
@export var player_path: NodePath

@onready var question_label: Label = $TextureRect/MarginContainer/VBoxContainer/Question
@onready var option_l_label: Label = $TextureRect/MarginContainer/VBoxContainer/HBoxContainer/"Option L"
@onready var option_r_label: Label = $TextureRect/MarginContainer/VBoxContainer/HBoxContainer/"Option R"

@onready var dragon_head: Node = null
@onready var player: Node2D = null
@onready var player_anim: AnimationPlayer = null

var question: String = ""
var optionL: String = ""
var optionR: String = ""
var correctOption: String = ""

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _questions: Array = []

var swipe_start: Vector2 = Vector2.ZERO
var swipe_end: Vector2 = Vector2.ZERO
var swipe_min_dist: float = 30.0

var _player_center: Vector2 = Vector2.ZERO
var _player_center_set: bool = false


func _ready() -> void:
	_rng.randomize()

	# DRAGON HEAD
	if dragon_head_path != NodePath(""):
		dragon_head = get_node_or_null(dragon_head_path)
	if dragon_head == null:
		dragon_head = get_node_or_null("../Dragon Head")
	print("Dragon head found? ", dragon_head)

	# PLAYER
	if player_path != NodePath(""):
		player = get_node_or_null(player_path) as Node2D
	if player == null:
		player = get_node_or_null("../CharacterBody2D") as Node2D
	print("Player found? ", player)

	if player != null:
		_player_center = player.global_position
		_player_center_set = true

		player_anim = player.get_node_or_null("AnimationPlayer") as AnimationPlayer

	_load_all_questions()
	_pick_random_question()
	_display_current_question()

	dragon_health_changed.emit(_dragon_health)
	player_health_changed.emit(_player_health)


# ================= JSON LOAD =================
func _load_all_questions() -> void:
	var text: String = FileAccess.get_file_as_string(questions_path)
	if text.is_empty():
		push_error("Could not load JSON: " + questions_path)
		return

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON")
		return

	var root: Dictionary = parsed
	var qv: Variant = root.get("questions", [])
	if qv is Array:
		_questions = qv as Array
	else:
		_questions = []


# ================= PICK QUESTION =================
func _pick_random_question() -> void:
	if _questions.is_empty():
		return

	var idx: int = _rng.randi_range(0, _questions.size() - 1)
	var q: Dictionary = _questions[idx]

	question = str(q.get("question"))

	var opts_var: Variant = q.get("options", [])
	var opts: Array = []
	if opts_var is Array:
		opts = opts_var as Array

	correctOption = str(q.get("answer"))

	var wrong: String = ""
	for o in opts:
		if str(o) != correctOption:
			wrong = str(o)
			break
	if wrong == "":
		wrong = correctOption

	if _rng.randi_range(0, 1) == 0:
		optionL = correctOption
		optionR = wrong
	else:
		optionL = wrong
		optionR = correctOption


func _display_current_question() -> void:
	_reset_highlight()
	question_label.text = question
	option_l_label.text = optionL
	option_r_label.text = optionR
	_attack_used_for_current_question = false


# ================= INPUT =================
func _input(event: InputEvent) -> void:
	if _battle_over:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			swipe_start = mb.position
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			swipe_end = mb.position
			_process_swipe()


func _process_swipe() -> void:
	var delta: Vector2 = swipe_end - swipe_start
	if delta.length() < swipe_min_dist:
		return

	if abs(delta.x) > abs(delta.y):
		_on_swipe("left" if delta.x < 0.0 else "right")


# ================= ANSWER LOGIC =================
func _on_swipe(dir: String) -> void:
	if _attack_used_for_current_question or _battle_over:
		return
	_attack_used_for_current_question = true

	var is_left: bool = dir == "left"
	var selected: String = optionL if is_left else optionR
	var is_correct: bool = selected == correctOption

	_highlight_choice(is_left, is_correct)

	var correct_is_left: bool = (optionL == correctOption)
	var wrong_is_left: bool = not correct_is_left
	var smash_dir: String = "left" if wrong_is_left else "right"

	var use_fireball: bool = _next_attack_is_fireball and dragon_head != null and dragon_head.has_method("start_fireball")

	# Player damage on wrong answer
	if not is_correct:
		_player_health -= 20
		if _player_health < 0:
			_player_health = 0
		player_health_changed.emit(_player_health)
		if _player_health == 0:
			_player_pending_death = true
			_battle_over = true  # lock further input/questions

	# Player move
	if not _player_pending_death:
		if is_correct and use_fireball:
			# correct + fireball: don't move yet; slash after delay
			pass
		else:
			_move_player_based_on_answer(is_correct)

	# Dragon attack
	if dragon_head != null:
		if use_fireball:
			dragon_head.start_fireball(smash_dir)
		elif dragon_head.has_method("start_smash"):
			dragon_head.start_smash(smash_dir)

	# Schedule slash + deflect if correct vs fireball and no death pending
	if is_correct and use_fireball and not _player_pending_death and not _dragon_pending_death:
		var t: SceneTreeTimer = get_tree().create_timer(0.5)
		t.timeout.connect(func() -> void:
			_play_player_slash()
			_deflect_all_flames()
		)

	_next_attack_is_fireball = not _next_attack_is_fireball

	# If someone is about to die, let the attack play then trigger death.
	if _player_pending_death:
		var player_death_timer: SceneTreeTimer = get_tree().create_timer(1.0)
		player_death_timer.timeout.connect(func() -> void:
			_on_player_defeated()
		)
	elif not _battle_over and not _dragon_pending_death:
		_next_question_timer = get_tree().create_timer(1.0)
		_next_question_timer.timeout.connect(func() -> void:
			_go_to_next_question()
		)


func _move_player_based_on_answer(is_correct: bool) -> void:
	if not _player_center_set or player == null:
		return

	var correct_is_left: bool = (optionL == correctOption)

	var final_dir: String
	if is_correct:
		final_dir = "left" if correct_is_left else "right"
	else:
		final_dir = "right" if correct_is_left else "left"

	var offset: float = -20.0 if final_dir == "left" else 20.0
	player.global_position = Vector2(_player_center.x + offset, _player_center.y)


# ================= QUESTION FLOW =================
func _go_to_next_question() -> void:
	if _battle_over:
		return
	_pick_random_question()
	_display_current_question()


# ================= HIGHLIGHT =================
func _reset_highlight() -> void:
	_clear_label_glow(option_l_label)
	_clear_label_glow(option_r_label)


func _highlight_choice(is_left: bool, is_correct: bool) -> void:
	_reset_highlight()
	var lbl: Label = option_l_label if is_left else option_r_label
	var color: Color = Color(0.2, 1.0, 0.2) if is_correct else Color(1.0, 0.2, 0.2)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", color)


func _clear_label_glow(label: Label) -> void:
	label.remove_theme_constant_override("outline_size")
	label.remove_theme_color_override("font_outline_color")


# ================= SLASH + DRAGON DAMAGE =================
func _play_player_slash() -> void:
	if player_anim != null and player_anim.has_animation("slash"):
		player_anim.play("slash")

	if _dragon_pending_death or _player_pending_death:
		return

	_dragon_health -= 20
	if _dragon_health < 0:
		_dragon_health = 0

	dragon_health_changed.emit(_dragon_health)

	if _dragon_health == 0:
		_dragon_pending_death = true
		_battle_over = true
		var dragon_death_timer: SceneTreeTimer = get_tree().create_timer(0.8)
		dragon_death_timer.timeout.connect(func() -> void:
			_on_dragon_defeated()
		)


# ================= DRAGON DEATH =================
func _on_dragon_defeated() -> void:
	if _dragon_dead_handled:
		return
	_dragon_dead_handled = true
	_battle_over = true
	_dragon_pending_death = false

	_next_question_timer = null

	if dragon_head != null:
		if dragon_head.has_method("stop_all_attacks"):
			dragon_head.stop_all_attacks()
		dragon_head.set_process(false)
		dragon_head.set_physics_process(false)

	_remove_dragon()


func _remove_dragon() -> void:
	var wings := get_node_or_null("../wings")
	var body := get_node_or_null("../DragonBody")

	if wings != null:
		wings.queue_free()
	if body != null:
		body.queue_free()
	if dragon_head != null:
		dragon_head.queue_free()


# ================= PLAYER DEATH =================
func _on_player_defeated() -> void:
	if _player_dead_handled:
		return
	_player_dead_handled = true
	_player_pending_death = false
	_battle_over = true

	_next_question_timer = null

	# stop dragon attacks
	if dragon_head != null:
		if dragon_head.has_method("stop_all_attacks"):
			dragon_head.stop_all_attacks()
		dragon_head.set_process(false)
		dragon_head.set_physics_process(false)

	# rotate player 90 degrees anticlockwise (−90°) gradually
	if player != null:
		var tw: Tween = get_tree().create_tween()
		tw.tween_property(player, "rotation_degrees", -90.0, 0.5) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)

		if player_anim != null:
			player_anim.stop()


# ================= FLAME DEFLECT =================
func _deflect_all_flames() -> void:
	if player == null:
		return

	var flames: Array = get_tree().get_nodes_in_group("flame")
	for f in flames:
		if f.has_method("deflect_away_from_player"):
			f.deflect_away_from_player(player.global_position)


# ================= OPTIONAL GETTERS =================
func get_dragon_health() -> int:
	return _dragon_health


func get_player_health() -> int:
	return _player_health
