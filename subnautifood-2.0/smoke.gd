extends CPUParticles2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Emission
	emitting = true
	amount = 8
	lifetime = 5.0
	explosiveness = 0.0
	randomness = 0.3
	local_coords = false

	texture = _make_soft_circle_texture()

	# Emission shape - small area, not a single point
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 4.0

	# Direction & spread - mostly straight up
	direction = Vector2(0, -1)
	spread = 6.0

	# Velocity - slow rise, water has drag
	initial_velocity_min = 5.0
	initial_velocity_max = 12.0

	# Gravity inverted so smoke floats upward
	gravity = Vector2(0, -25)

	# Damping simulates water resistance slowing it down
	damping_min = 1.0
	damping_max = 2.0

	# Subtle spin + drift only, not a wide fan
	angular_velocity_min = -5.0
	angular_velocity_max = 5.0
	orbit_velocity_min = 0.0
	orbit_velocity_max = 0.03

	# Scale - bigger and more visible
	scale_amount_min = 1.5
	scale_amount_max = 2.5
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.3))
	scale_amount_curve = scale_curve

	# Color - brighter, more opaque so it reads against dark background
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.85, 0.85, 0.85, 0.9))
	gradient.add_point(0.7, Color(0.7, 0.7, 0.7, 0.5))
	gradient.add_point(1.0, Color(0.6, 0.6, 0.6, 0.0))
	color_ramp = gradient


func _make_soft_circle_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius: float = size / 2.0

	for y in size:
		for x in size:
			var dist: float = Vector2(x, y).distance_to(center)
			var alpha: float = clamp(1.0 - (dist / radius), 0.0, 1.0)
			alpha = alpha * alpha
			img.set_pixel(x, y, Color(1, 1, 1, alpha))

	return ImageTexture.create_from_image(img)
