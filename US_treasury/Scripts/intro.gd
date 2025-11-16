extends Node2D

@export var next_scene_path: String = "res://Scenes/game.tscn"

@onready var dialogue: Node = $dialogue      # child with dialogue.gd
@onready var button: Button = $Button        # child Button

var _dialogue_finished: bool = false


func _ready() -> void:
	# hide button at start
	button.visible = false

	# listen for when the dialogue is done
	if dialogue.has_signal("dialogue_finished"):
		dialogue.dialogue_finished.connect(_on_dialogue_finished)
	else:
		push_warning("Child 'dialogue' has no 'dialogue_finished' signal!")


func _on_dialogue_finished() -> void:
	_dialogue_finished = true
	button.visible = true   # show button once all text is done


func _go_to_game() -> void:
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)


func _on_button_pressed():
		# this is what the Button's 'pressed' signal should call
	if _dialogue_finished:
		_go_to_game()
