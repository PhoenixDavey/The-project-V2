extends Control

signal repair_done(amount)

<<<<<<< HEAD
@export var target_lifetime: float = 0.65         # seconds before target expires/moves
@export var repair_percent_per_hit: float = 2.5   # % of max health per hit
@export var target_click_size: Vector2 = Vector2(70, 70)  # forced click-area size
=======
@export var targets_to_hit: int = 5       # hits needed to fully repair
@export var target_lifetime: float = 1.5  # seconds before target moves
@export var repair_per_hit: float = 25.0
>>>>>>> parent of 38971be (v2.2)

var hits: int = 0
var target_timer: float = 0.0
var active: bool = false

@onready var target = $Target
@onready var hits_label = $HitsLabel
@onready var exit_button = $ExitButton

func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	target.gui_input.connect(_on_target_clicked)
	hide()

func start_minigame() -> void:
	hits = 0
	active = true
	target_timer = 0.0
	hits_label.text = "Hits: 0 / %d" % targets_to_hit
	move_target()

func move_target() -> void:
	var margin = 60
	var x = randf_range(margin, size.x - margin)
	var y = randf_range(margin, size.y - margin)
	target.position = Vector2(x, y)
	target_timer = target_lifetime

func _on_target_clicked(_event: InputEvent) -> void:
	if not active:
		return
	if _event is InputEventMouseButton and _event.pressed and _event.button_index == MOUSE_BUTTON_LEFT:
		hits += 1
		hits_label.text = "Hits: %d / %d" % [hits, targets_to_hit]
		if hits >= targets_to_hit:
			finish_minigame()
		else:
			move_target()

func _on_exit_pressed() -> void:
	active = false
	get_parent().get_parent().close_repair()

func finish_minigame() -> void:
	active = false
	get_parent().get_parent().apply_repair(repair_per_hit)
	get_parent().get_parent().close_repair()

func _process(delta: float) -> void:
	if not active:
		return
	# Engine.time_scale slows the whole world for the bullet-time effect,
	# but the minigame itself should still feel fast/real-time to the
	# player, so we undo that scaling here.
	var real_delta = delta / max(Engine.time_scale, 0.0001)
	target_timer -= real_delta
	if target_timer <= 0.0:
		move_target()
