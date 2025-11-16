extends Sprite2D

@export var stretch_amount: float = 0.2   # how much it stretches
@export var stretch_speed: float = 2.0    # how fast it stretches

var t := 0.0

func _ready():
	modulate = Color(1, 1, 1, 0.6)  # 60% opaque (40% transparent)


func _process(delta):
	t += delta * stretch_speed
	var scale_factor = 1.0 + sin(t) * stretch_amount
	scale = Vector2(scale_factor, scale_factor)
	
