extends Sprite2D

@export var flap_angle_deg: float = 5.0        # How much it rotates downward
@export var flap_speed: float = 1.0             # Speed of flapping

var base_rotation := 0.0

func _ready():
	base_rotation = rotation_degrees

func _process(delta):
	# Flap animation using a smooth sinus function
	var flap = sin(Time.get_ticks_msec() / 1000.0 * flap_speed) * flap_angle_deg

	rotation_degrees = base_rotation + flap
