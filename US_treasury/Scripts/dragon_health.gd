extends ProgressBar

@export var controller_path: NodePath	# node with question_generator.gd

@onready var controller: Node = null


func _ready() -> void:
	# Get the controller node (question generator)
	if controller_path != NodePath(""):
		controller = get_node_or_null(controller_path)

	if controller == null:
		print("DragonHealth: controller not found, set controller_path in Inspector")

	# Set bar range
	min_value = 0
	max_value = 100
	value = 100	# initial health


func _process(delta: float) -> void:
	if controller != null and controller.has_method("get_dragon_health"):
		value = controller.get_dragon_health()
