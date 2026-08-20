extends Node2D

# --- Exported settings ---
@export var move_speed: float = 60.0
@export var segment_follow_speed: float = 1000.0
@export var segment_spacing: float = 75.0
@export var rotation_speed: float = 1.0
@export var turn_smoothing: float = 0.5

# --- Boundary (huge, mostly just a safety net) ---
@export var bounds_min: Vector2 = Vector2(-2000, -2000)
@export var bounds_max: Vector2 = Vector2(2000, 2000)

# --- Internal ---
var wander_target: Vector2 = Vector2.ZERO
var current_heading: float = 0.0
var segments: Array[Node2D] = []
var was_outside: bool = false

func _ready() -> void:
	segments = [self]

	var numbered: Array = []
	var back_node: Node2D = null
	var parent = get_parent()

	for child in parent.get_children():
		if not (child is Node2D):
			continue
		if child.name == "SandwichMonsterback":
			back_node = child
		elif child.name.begins_with("SandwichMonster") and child.name != self.name:
			var num_str = child.name.trim_prefix("SandwichMonster")
			if num_str.is_valid_int():
				numbered.append([int(num_str), child])

	numbered.sort_custom(func(a, b): return a[0] < b[0])
	for pair in numbered:
		segments.append(pair[1])

	if back_node:
		segments.append(back_node)

	wander_target = segments[0].global_position
	current_heading = segments[0].rotation

func _physics_process(delta: float) -> void:
	if segments.is_empty():
		return

	_wander(delta)
	_follow_chain(delta)

func _wander(delta: float) -> void:
	var front: Node2D = segments[0]
	var pos = front.global_position

	var is_outside: bool = pos.x < bounds_min.x or pos.x > bounds_max.x or pos.y < bounds_min.y or pos.y > bounds_max.y

	# only re-snap the instant it crosses the border, not every frame while outside
	if is_outside and not was_outside:
		wander_target = (bounds_min + bounds_max) / 2.0
	elif not is_outside and pos.distance_to(wander_target) < 20.0:
		var spread = randf_range(-0.6, 0.6)
		var new_dir = Vector2.RIGHT.rotated(current_heading + spread)
		wander_target = pos + new_dir * randf_range(150, 300)

	was_outside = is_outside

	var direction: Vector2 = wander_target - pos
	if direction.length() > 4.0:
		var target_angle = direction.angle()
		current_heading = lerp_angle(current_heading, target_angle, turn_smoothing * delta)

		var move_vec = Vector2.RIGHT.rotated(current_heading) * move_speed * delta
		if move_vec.length() > direction.length():
			move_vec = move_vec.normalized() * direction.length()
		front.global_position += move_vec
		front.rotation = current_heading

func _follow_chain(delta: float) -> void:
	for i in range(1, segments.size()):
		var leader: Node2D = segments[i - 1]
		var follower: Node2D = segments[i]
		var to_leader: Vector2 = leader.global_position - follower.global_position
		var dist: float = to_leader.length()
		var effective_spacing: float = segment_spacing * follower.global_scale.x
		var desired_pos: Vector2 = leader.global_position - to_leader.normalized() * effective_spacing
		follower.global_position = follower.global_position.lerp(
			desired_pos,
			clamp(segment_follow_speed * delta, 0.0, 1.0)
		)
		if dist > 1.0:
			follower.rotation = lerp_angle(follower.rotation, to_leader.angle(), rotation_speed * delta)
