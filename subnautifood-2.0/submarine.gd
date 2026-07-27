extends CharacterBody2D

@export var max_speed: float = 300.0
@export var acceleration: float = 150.0
@export var friction: float = 200.0
@export var boost_speed_multiplier: float = 2.2
@export var boost_drain_rate: float = 0.33    # how fast bar drains (per second)
@export var boost_recharge_rate: float = 0.05 # 1/20 = full recharge in 20 seconds

var boost_charge: float = 1.0  # 0.0 to 1.0, starts full
var is_boosting: bool = false

@export var pulse_speed: float = 3.0
var pulse_time: float = 0.0

@onready var boost_bar = $CanvasLayer/Boostbar
@onready var warning: Label = $Warning

func _ready() -> void:
	var dark = get_node("/root/Main/Dark")
	dark.color = Color(0.03, 0.08, 0.40, 1.0)
	$PointLight2D.texture_scale = 2.0
	$PointLight2D.color = Color(0.85, 0.95, 1.0)
	$PointLight2D.energy = 1.2
	$PointLight2D.blend_mode = PointLight2D.BLEND_MODE_ADD
	$CPUParticles2D.emitting = true
	$CPUParticles2D.amount = 8
	$CPUParticles2D.lifetime = 2.0
	$CPUParticles2D.explosiveness = 0.0
	$CPUParticles2D.direction = Vector2(0, -1)
	$CPUParticles2D.spread = 20.0
	$CPUParticles2D.gravity = Vector2(0, -60)
	$CPUParticles2D.initial_velocity_min = 20.0
	$CPUParticles2D.initial_velocity_max = 60.0
	$CPUParticles2D.scale_amount_min = 2.0
	$CPUParticles2D.scale_amount_max = 7.0
	$CPUParticles2D.color = Color(0.75, 0.93, 1.0, 0.6)

func _physics_process(delta: float) -> void:
	pulse_time += delta * pulse_speed
	$PointLight2D.energy = 1.0 + sin(pulse_time) * 0.15

	# Boost logic — hold shift to boost, drains charge, recharges when not held
	is_boosting = Input.is_action_pressed("boost") and boost_charge > 0.0

	if is_boosting:
		boost_charge -= boost_drain_rate * delta
		boost_charge = max(boost_charge, 0.0)
	else:
		boost_charge += boost_recharge_rate * delta
		boost_charge = min(boost_charge, 1.0)

	# Update boost bar
	boost_bar.max_value = 1.0
	boost_bar.value = boost_charge
	if is_boosting:
		boost_bar.modulate = Color(0.2, 0.8, 1.0)   # blue while boosting
	elif boost_charge < 1.0:
		boost_bar.modulate = Color(0.8, 0.3, 0.3)   # red while recharging
	else:
		boost_bar.modulate = Color(0.2, 0.8, 1.0)   # full blue = ready

	# Movement
	var current_max_speed = max_speed * (boost_speed_multiplier if is_boosting else 1.0)

	var direction = Vector2.ZERO
	if Input.is_action_pressed("Ascending"):
		direction.y = -1
	elif Input.is_action_pressed("Descending"):
		direction.y = 1
	if Input.is_action_pressed("Left"):
		direction.x = -1
		$Sprite2D.flip_h = false
	elif Input.is_action_pressed("Right"):
		direction.x = 1
		$Sprite2D.flip_h = true

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * current_max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

func show_warning():
	warning.start_flash()

func hide_warning():
	warning.stop_flash()
