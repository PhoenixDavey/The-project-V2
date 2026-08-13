extends Node2D
# --- Exported settings ---
@export var move_speed: float = 320.0
@export var segment_follow_speed: float = 10.0
@export var segment_spacing: float = 80.0
@export var rotation_speed: float = 5.0
@export var detect_range: float = 1000.0
@export var growl_min_time: float = 30.0
@export var growl_max_time: float = 60.0

# --- Wall avoidance settings (used for proactive steering) ---
# Set this in the Inspector to include BOTH the Cave system's collision layer
# AND the Submarine's collision layer.
@export var wall_collision_mask: int = 1
@export var wall_check_distance: float = 150.0
@export var wall_avoid_angle: float = 0.7

# --- NEW: what physics layer the monster's OWN body should sit on ---
# Set this to whatever layer number you use for "Monster" (check
# Project Settings -> Layer Names -> 2D Physics if you've named them).
@export var monster_collision_layer: int = 1

# --- Internal ---
var player: Node2D = null
var wander_target: Vector2 = Vector2.ZERO
var warning_label = null
var was_detected: bool = false
var segments: Array[CharacterBody2D] = []

@onready var growl_player: AudioStreamPlayer2D = $Growl
@onready var yell_player: AudioStreamPlayer2D = $Yell
@onready var hearing_area: Area2D = $"Growl/hearing area"
@onready var growl_timer: Timer = Timer.new()
var player_in_hearing_range: bool = false

# sprite node name -> its matching collision node name
# (matches your naming: Front-collision / Back-collision use a dash,
# the Middles don't - update this list if yours differ)
var _segment_defs: Array = [
	["Front", "Front-collision"],
	["Middle1", "Middle1collision"],
	["Middle2", "Middle2collision"],
	["Middle3", "Middle3collision"],
	["Middle4", "Middle4collision"],
	["Middle5", "Middle5collision"],
	["Middle6", "Middle6collision"],
	["Middle7", "Middle7collision"],
	["Middle8", "Middle8collision"],
	["Middle9", "Middle9collision"],
	["Middle10", "Middle10collision"],
	["Back", "Back-collision"],
]

func _ready() -> void:
	_build_segment_bodies()

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	wander_target = segments[0].global_position

	var warning_node = get_tree().current_scene.find_child("Warning", true)
	if warning_node:
		for child in warning_node.get_children():
			if child is Label:
				warning_label = child

	add_child(growl_timer)
	growl_timer.one_shot = true
	growl_timer.timeout.connect(_on_growl_timeout)
	_start_growl_timer()

	if hearing_area:
		hearing_area.body_entered.connect(_on_hearing_area_body_entered)
		hearing_area.body_exited.connect(_on_hearing_area_body_exited)

# --- Builds a CharacterBody2D for each segment at runtime and moves the
# existing sprite + collision shape into it, so you don't have to
# restructure the scene by hand in the editor. ---
func _build_segment_bodies() -> void:
	for pair in _segment_defs:
		var sprite_name: String = pair[0]
		var collision_name: String = pair[1]

		var sprite: Node2D = get_node_or_null(sprite_name)
		var collision: Node2D = get_node_or_null(collision_name)

		if sprite == null:
			push_warning("Sandwich monster: couldn't find sprite node '%s' - skipping." % sprite_name)
			continue

		var body := CharacterBody2D.new()
		body.name = sprite_name + "Body"
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		body.collision_layer = monster_collision_layer
		body.collision_mask = wall_collision_mask
		body.global_position = sprite.global_position
		add_child(body)

		_reparent_keep_global(sprite, body)

		if collision:
			_reparent_keep_global(collision, body)
		else:
			push_warning("Sandwich monster: couldn't find collision node '%s' for '%s'." % [collision_name, sprite_name])

		segments.append(body)

func _reparent_keep_global(node: Node2D, new_parent: Node2D) -> void:
	var gt: Transform2D = node.global_transform
	node.get_parent().remove_child(node)
	new_parent.add_child(node)
	node.global_transform = gt

func _on_hearing_area_body_entered(body: Node2D) -> void:
	if body == player or body.is_in_group("player"):
		player_in_hearing_range = true

func _on_hearing_area_body_exited(body: Node2D) -> void:
	if body == player or body.is_in_group("player"):
		player_in_hearing_range = false

func _start_growl_timer() -> void:
	growl_timer.start(randf_range(growl_min_time, growl_max_time))

func _on_growl_timeout() -> void:
	if growl_player and player_in_hearing_range:
		growl_player.play()
	_start_growl_timer()

func _physics_process(delta: float) -> void:
	if segments.is_empty() or player == null:
		return
	var dist = segments[0].global_position.distance_to(player.global_position)
	var is_detected: bool = dist <= detect_range
	if is_detected:
		_move_front(delta)
		if warning_label:
			warning_label.show_warning()
	else:
		_wander(delta)
		if warning_label:
			warning_label.hide_warning()

	if is_detected and not was_detected:
		if yell_player:
			yell_player.play()
	was_detected = is_detected

	_follow_chain(delta)

# --- raycast used only to proactively STEER the front segment before it gets close ---
func _avoid_walls(from_pos: Vector2, desired_dir: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		from_pos,
		from_pos + desired_dir.normalized() * wall_check_distance
	)
	query.collision_mask = wall_collision_mask
	var result = space_state.intersect_ray(query)

	if result:
		var left_dir = desired_dir.rotated(-wall_avoid_angle)
		var right_dir = desired_dir.rotated(wall_avoid_angle)

		var left_query = PhysicsRayQueryParameters2D.create(
			from_pos, from_pos + left_dir.normalized() * wall_check_distance
		)
		left_query.collision_mask = wall_collision_mask
		var left_hit = space_state.intersect_ray(left_query)

		var right_query = PhysicsRayQueryParameters2D.create(
			from_pos, from_pos + right_dir.normalized() * wall_check_distance
		)
		right_query.collision_mask = wall_collision_mask
		var right_hit = space_state.intersect_ray(right_query)

		if not right_hit:
			return right_dir.normalized()
		elif not left_hit:
			return left_dir.normalized()
		else:
			return desired_dir.bounce(result.normal).normalized()

	return desired_dir.normalized()

func _move_front(delta: float) -> void:
	var front: CharacterBody2D = segments[0]
	var direction: Vector2 = (player.global_position - front.global_position)
	if direction.length() > 4.0:
		var move_dir = _avoid_walls(front.global_position, direction.normalized())
		var speed = move_speed
		if direction.length() < speed * delta:
			speed = direction.length() / delta
		front.velocity = move_dir * speed
		front.move_and_slide()
		front.rotation = lerp_angle(front.rotation, move_dir.angle(), rotation_speed * delta)

func _wander(delta: float) -> void:
	var front: CharacterBody2D = segments[0]
	if front.global_position.distance_to(wander_target) < 20.0:
		var forward = Vector2.RIGHT.rotated(front.rotation)
		var spread = randf_range(-0.8, 0.8)
		var new_dir = forward.rotated(spread)
		wander_target = front.global_position + new_dir * randf_range(200, 400)

	var direction: Vector2 = wander_target - front.global_position
	if direction.length() > 4.0:
		var move_dir = _avoid_walls(front.global_position, direction.normalized())

		if move_dir.angle_to(direction.normalized()) > 0.1 or move_dir.angle_to(direction.normalized()) < -0.1:
			wander_target = front.global_position + move_dir * randf_range(150, 300)

		var speed = move_speed
		if direction.length() < speed * delta:
			speed = direction.length() / delta
		front.velocity = move_dir * speed
		front.move_and_slide()
		front.rotation = lerp_angle(front.rotation, move_dir.angle(), rotation_speed * 0.5 * delta)

func _follow_chain(delta: float) -> void:
	for i in range(1, segments.size()):
		var leader: CharacterBody2D = segments[i - 1]
		var follower: CharacterBody2D = segments[i]
		var to_leader: Vector2 = leader.global_position - follower.global_position
		var dist: float = to_leader.length()
		var desired_pos: Vector2 = leader.global_position - to_leader.normalized() * segment_spacing
		var to_desired: Vector2 = desired_pos - follower.global_position

		if delta > 0.0:
			var t: float = clamp(segment_follow_speed * delta, 0.0, 1.0)
			follower.velocity = (to_desired * t) / delta
			follower.move_and_slide()

		if dist > 1.0:
			follower.rotation = lerp_angle(follower.rotation, to_leader.angle(), rotation_speed * delta)
