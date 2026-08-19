extends Node2D

# --- Exported settings ---
@export var move_speed: float = 60.0
@export var segment_follow_speed: float = 10.0
@export var segment_spacing: float = 80.0
@export var rotation_speed: float = 5.0

# --- Internal ---
var wander_target: Vector2 = Vector2.ZERO
var segments: Array[Node2D] = []

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
			# extract the trailing number, e.g. "SandwichMonster12" -> 12
			var num_str = child.name.trim_prefix("SandwichMonster")
			if num_str.is_valid_int():
				numbered.append([int(num_str), child])

	numbered.sort_custom(func(a, b): return a[0] < b[0])
	for pair in numbered:
		segments.append(pair[1])

	if back_node:
		segments.append(back_node)

	wander_target = segments[0].global_position

func _physics_process(delta: float) -> void:
	if segments.is_empty():
		return

	_wander(delta)
	_follow_chain(delta)

func _wander(delta: float) -> void:
	var front: Node2D = segments[0]
	if front.global_position.distance_to(wander_target) < 20.0:
		var forward = Vector2.RIGHT.rotated(front.rotation)
		var spread = randf_range(-0.8, 0.8)
		var new_dir = forward.rotated(spread)
		wander_target = front.global_position + new_dir * randf_range(200, 400)

	var direction: Vector2 = wander_target - front.global_position
	if direction.length() > 4.0:
		var move_dir = direction.normalized()
		var move_vec = move_dir * move_speed * delta
		if move_vec.length() > direction.length():
			move_vec = move_vec.normalized() * direction.length()
		front.global_position += move_vec
		front.rotation = lerp_angle(front.rotation, move_dir.angle(), rotation_speed * 0.5 * delta)

func _follow_chain(delta: float) -> void:
	for i in range(1, segments.size()):
		var leader: Node2D = segments[i - 1]
		var follower: Node2D = segments[i]
		var to_leader: Vector2 = leader.global_position - follower.global_position
		var dist: float = to_leader.length()
		var desired_pos: Vector2 = leader.global_position - to_leader.normalized() * segment_spacing
		follower.global_position = follower.global_position.lerp(
			desired_pos,
			clamp(segment_follow_speed * delta, 0.0, 1.0)
		)
		if dist > 1.0:
			follower.rotation = lerp_angle(follower.rotation, to_leader.angle(), rotation_speed * delta)
