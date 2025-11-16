extends Area2D

@export var flame_scene: PackedScene       # assign flame.tscn in the inspector
@export var flame_offset: Vector2 = Vector2(0, 2)   # adjust to come out of the mouth

# --- SETTINGS: only smash behavior, not timing ---
@export var smash_speed: float = 250.0
@export var return_speed_multiplier: float = 2.0
@export var corner_padding: float = 0.0          # padding from screen corners
@export var max_smash_distance: float = 80.0     # max distance from start
@export var neck_width: float = 20.0             # visual neck thickness

@onready var _head_sprite: Node2D = $Sprite2D if has_node("Sprite2D") else self
@onready var _neck_poly: Polygon2D = $NeckPolygon if has_node("NeckPolygon") else null
@onready var _neck_base_node: Node2D = $NeckBase if has_node("NeckBase") else null

var _start_pos: Vector2
var _target_pos: Vector2
var _smash_active: bool = false
var _smash_returning: bool = false

var _neck_base_global: Vector2 = Vector2.ZERO


func _ready() -> void:
	_start_pos = global_position

	if _neck_base_node:
		_neck_base_global = _neck_base_node.global_position

	if _neck_poly:
		_neck_poly.uv = PackedVector2Array([
			Vector2(0, 0),
			Vector2(0, 1),
			Vector2(1, 1),
			Vector2(1, 0),
		])

	_update_neck()


# ================= PUBLIC API =================
# dir is "left" or "right"
func start_smash(dir: String) -> void:
	if _smash_active:
		return

	_start_pos = global_position
	var raw_target: Vector2 = _compute_target_for_dir(dir, _start_pos)
	_target_pos = _cap_target_distance(_start_pos, raw_target, max_smash_distance)

	_smash_active = true
	_smash_returning = false


# ================= MOTION =================
func _physics_process(delta: float) -> void:
	if _smash_active:
		var speed: float = smash_speed if not _smash_returning else smash_speed * return_speed_multiplier
		var target: Vector2 = _target_pos if not _smash_returning else _start_pos

		# optional safety: clamp by max_smash_distance
		if not _smash_returning and max_smash_distance > 0.0:
			var dist_from_start: float = (global_position - _start_pos).length()
			if dist_from_start >= max_smash_distance:
				_start_return()

		if _step_toward(target, speed * delta):
			if not _smash_returning:
				_start_return()
			else:
				_finish_return()

	_update_neck()


func _start_return() -> void:
	_smash_returning = true


func _finish_return() -> void:
	_smash_active = false
	_smash_returning = false
	global_position = _start_pos


# ================= NECK VISUAL =================
func _update_neck() -> void:
	if _neck_poly == null:
		return

	if _neck_base_global == Vector2.ZERO and _neck_base_node == null:
		return

	var a_global: Vector2 = _neck_base_global
	if _neck_base_node != null:
		a_global = _neck_base_node.global_position

	var b_global: Vector2 = _head_sprite.global_position
	var dir: Vector2 = b_global - a_global
	if dir.length() == 0.0:
		return
	dir = dir.normalized()

	var half_width: float = neck_width * 0.5
	var perp: Vector2 = dir.orthogonal() * half_width

	var p0: Vector2 = a_global + perp
	var p1: Vector2 = a_global - perp
	var p2: Vector2 = b_global - perp
	var p3: Vector2 = b_global + perp

	var parent: Node = _neck_poly.get_parent()
	p0 = parent.to_local(p0)
	p1 = parent.to_local(p1)
	p2 = parent.to_local(p2)
	p3 = parent.to_local(p3)

	_neck_poly.polygon = PackedVector2Array([p0, p1, p2, p3])


# ================= HELPERS =================
func _compute_target_for_dir(dir: String, from_pos: Vector2) -> Vector2:
	var vp: Vector2 = get_viewport_rect().size
	var pad: float = clampf(corner_padding, 0.0, minf(vp.x, vp.y) * 0.5)
	match dir:
		"left":
			return Vector2(pad, vp.y - pad)
		"right":
			return Vector2(vp.x - pad, vp.y - pad)
		_:
			return from_pos


func _cap_target_distance(from: Vector2, to: Vector2, maxd: float) -> Vector2:
	if maxd <= 0.0:
		return to
	var v: Vector2 = to - from
	var d: float = v.length()
	if d <= maxd:
		return to
	return from + v * (maxd / max(d, 0.00001))


func _step_toward(to: Vector2, max_step: float) -> bool:
	var d: Vector2 = to - global_position
	var dist: float = d.length()
	if dist <= max_step or is_equal_approx(dist, 0.0):
		global_position = to
		return true
	global_position += d / max(dist, 0.00001) * max_step
	return false
	
func start_fireball(dir: String) -> void:
	if flame_scene == null:
		print("ERROR: flame_scene not assigned on Dragon Head!")
		return

	# Instance the fireball scene
	var flame = flame_scene.instantiate()

	# Add it to the same parent as the dragon head
	var parent := get_parent()
	if parent:
		parent.add_child(flame)
	else:
		add_child(flame)

	# Spawn position (dragon head position + offset)
	if flame is Node2D:
		flame.global_position = self.global_position + flame_offset
	else:
		flame.position = self.position + flame_offset

	print("🔥 Fireball launched to follow player!")


	
