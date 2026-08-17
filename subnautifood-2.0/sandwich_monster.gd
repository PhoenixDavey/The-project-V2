extends Node2D

# --- Exported settings ---
@export var move_speed: float = 320.0
@export var segment_follow_speed: float = 10.0
@export var segment_spacing: float = 80.0
@export var rotation_speed: float = 5.0
@export var detect_range: float = 1000.0
@export var growl_min_time: float = 30.0
@export var growl_max_time: float = 60.0

# --- Wall avoidance settings ---
@export var wall_collision_mask: int = 1       # match this to the Cave layer's physics layer
@export var wall_check_distance: float = 150.0 # how far ahead the monster "sees" a wall
@export var wall_avoid_angle: float = 0.7      # radians, how sharply it steers away (~40°)

# --- Attack / retreat settings ---
@export var attack_damage_percent: float = 50.0
@export var attack_range: float = 70.0   # how close "Front" needs to be to count as a hit
@export var retreat_time: float = 7.5    # attack cooldown set to 7.5 seconds

var is_retreating: bool = false
var retreat_timer: float = 0.0

# --- Internal ---
var player: Node2D = null
var wander_target: Vector2 = Vector2.ZERO
var warning_label = null
var was_detected: bool = false

@onready var segments: Array[Node2D] = [
	$Front,
	$Middle1,
	$Middle2,
	$Middle3,
	$Middle4,
	$Middle5,
	$Middle6,
	$Middle7,
	$Middle8,
	$Middle9,
	$Middle10,
	$Back,
]
@onready var growl_player: AudioStreamPlayer2D = $Growl
@onready var yell_player: AudioStreamPlayer2D = $Yell
@onready var hearing_area: Area2D = $"Growl/hearing area"
@onready var growl_timer: Timer = Timer.new()
var player_in_hearing_range: bool = false

func _ready() -> void:
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

	# Handle 7.5-second attack cooldown without disappearing
	if is_retreating:
		retreat_timer -= delta
		if retreat_timer <= 0.0:
			_end_retreat()
		else:
			_wander(delta)
			_follow_chain(delta)
			if warning_label:
				warning_label.hide_warning()
			return

	var dist = segments[0].global_position.distance_to(player.global_position)
	var is_detected: bool = dist <= detect_range
	if is_detected:
		_move_front(delta)
		if warning_label:
			warning_label.show_warning()
		if dist <= attack_range:
			_attack_player()
			return
	else:
		_wander(delta)
		if warning_label:
			warning_label.hide_warning()

	if is_detected and not was_detected:
		if yell_player:
			yell_player.play()
	was_detected = is_detected

	_follow_chain(delta)

func _attack_player() -> void:
	if player.has_method("take_damage"):
		player.take_damage(player.max_health * (attack_damage_percent / 100.0))
	_start_retreat()

func _start_retreat() -> void:
	is_retreating = true
	retreat_timer = retreat_time
	if warning_label:
		warning_label.hide_warning()
	was_detected = false
	
	# Pick a wander target leading away from the player
	if player:
		var away_dir = (segments[0].global_position - player.global_position).normalized()
		wander_target = segments[0].global_position + away_dir * 300.0

func _end_retreat() -> void:
	is_retreating = false

# --- Raycasts ahead and steers the direction away from walls ---
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
	var front: Node2D = segments[0]
	var direction: Vector2 = (player.global_position - front.global_position)
	if direction.length() > 4.0:
		var move_dir = _avoid_walls(front.global_position, direction.normalized())
		var move_vec = move_dir * move_speed * delta
		if move_vec.length() > direction.length():
			move_vec = move_vec.normalized() * direction.length()
		front.global_position += move_vec
		front.rotation = lerp_angle(front.rotation, move_dir.angle(), rotation_speed * delta)

func _wander(delta: float) -> void:
	var front: Node2D = segments[0]
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
