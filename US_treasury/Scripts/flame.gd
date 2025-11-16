extends Area2D

@export var speed: float = 80.0		# base speed toward player
@export var lifetime: float = 1.0	# seconds before despawn

var velocity: Vector2 = Vector2.ZERO
var deflected: bool = false

@onready var player: Node2D = get_tree().get_first_node_in_group("player")


func _ready() -> void:
	# initial aim toward player
	if player:
		velocity = (player.global_position - global_position).normalized() * speed

	# auto-despawn
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not deflected:
		if player and is_instance_valid(player):
			var dir := (player.global_position - global_position).normalized()
			velocity = dir * speed

	position += velocity * delta


func _on_flame_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# TODO: damage player if not deflected, or whatever you want
		queue_free()


# Called from the question Control script when the player slashes correctly
func deflect_away_from_player(player_pos: Vector2) -> void:
	deflected = true

	# direction from player to flame (away from player)
	var dir := (global_position - player_pos).normalized()

	# 3x original speed
	velocity = dir * speed
