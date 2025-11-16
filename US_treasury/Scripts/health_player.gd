extends ProgressBar

@export var controller_path: NodePath	# drag your question_generator node here

@onready var controller: Node = null


func _ready() -> void:
	# Find the question controller (question_generator.gd)
	if controller_path != NodePath(""):
		controller = get_node_or_null(controller_path)

	if controller == null:
		push_error("PlayerHealthBar: controller not found, set controller_path!")
		return

	# Initialize bar values
	min_value = 0
	max_value = 100
	value = 100

	# Connect to the controller's signal
	if controller.has_signal("player_health_changed"):
		controller.player_health_changed.connect(_on_player_health_changed)
	else:
		push_error("PlayerHealthBar: controller missing signal 'player_health_changed'")


func _on_player_health_changed(new_health: int) -> void:
	value = new_health
