extends Control

signal repair_done(amount)

@export var target_lifetime: float = 0.65         # seconds before target expires/moves
@export var repair_percent_per_hit: float = 5.0   # % of max health per hit
@export var target_click_size: Vector2 = Vector2(70, 70)  # forced click-area size

var hits: int = 0
var target_timer: float = 0.0
var active: bool = false

@onready var target = $Target
@onready var exit_button = $ExitButton
@onready var hits_label = get_node_or_null("HitsLabel")

func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	target.gui_input.connect(_on_target_clicked)

	# Force this panel to fill the viewport regardless of anchor/layout timing.
	# This is what was making size read as (0,0) -> target stuck at (0,0).
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	# Force the target itself to a fixed, non-zero clickable size so it
	# can't collapse to (0,0) either, regardless of what's in the scene.
	target.custom_minimum_size = target_click_size
	target.size = target_click_size

	# Kill the default focus outline and force text color to stay yellow
	# in every state (normal/hover/pressed/focus) instead of flashing white
	target.focus_mode = Control.FOCUS_NONE
	var yellow = Color(1.0, 0.9, 0.1)
	var black = Color(0.0, 0.0, 0.0)
	target.add_theme_color_override("font_color", yellow)
	target.add_theme_color_override("font_hover_color", black)
	target.add_theme_color_override("font_pressed_color", yellow)
	target.add_theme_color_override("font_focus_color", yellow)

	# Kill every state's background StyleBox so hovering/pressing never
	# paints a black (or any) background over your button art
	var empty_style = StyleBoxEmpty.new()
	target.add_theme_stylebox_override("normal", empty_style)
	target.add_theme_stylebox_override("hover", empty_style)
	target.add_theme_stylebox_override("pressed", empty_style)
	target.add_theme_stylebox_override("focus", empty_style)
	target.add_theme_stylebox_override("disabled", empty_style)

	hide()

func start_minigame() -> void:
	hits = 0
	active = true
	target_timer = 0.0
	_update_label()
	# Wait one frame so Godot finishes computing our real viewport size
	# before we try to place the target inside it.
	await get_tree().process_frame
	move_target()

func move_target() -> void:
	var box_size = get_viewport_rect().size
	var target_size = target.size
	var max_x = max(box_size.x - target_size.x, 0.0)
	var max_y = max(box_size.y - target_size.y, 0.0)
	var x = randf_range(0.0, max_x)
	var y = randf_range(0.0, max_y)
	target.position = Vector2(x, y)
	target_timer = target_lifetime
	target.show()

func _on_target_clicked(_event: InputEvent) -> void:
	if not active:
		return
	if _event is InputEventMouseButton and _event.pressed and _event.button_index == MOUSE_BUTTON_LEFT:
		hits += 1
		_update_label()
		_apply_hit_repair()
		move_target()

func _apply_hit_repair() -> void:
	get_parent().get_parent().apply_repair(repair_percent_per_hit)
	repair_done.emit(repair_percent_per_hit)

func _update_label() -> void:
	if hits_label:
		hits_label.text = "Hits: %d" % hits

func _process(delta: float) -> void:
	if not active:
		return
	# Engine.time_scale slows the whole world for the bullet-time effect,
	# but the minigame itself should still feel fast/real-time to the
	# player, so we undo that scaling here.
	var real_delta = delta / max(Engine.time_scale, 0.0001)
	target_timer -= real_delta
	if target_timer <= 0.0:
		# Too slow — target jumps to a new spot immediately
		move_target()

func _on_exit_pressed() -> void:
	active = false
	target.show()
	get_parent().get_parent().close_repair()
