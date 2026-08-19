extends CPUParticles2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Force normal alpha blending so fading particles don't stack into solid blobs
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = mat

	# Emission
	emitting = true
	amount = 8
	lifetime = 10.0
	explosiveness = 0.0
	randomness = 0.3
	local_coords = false

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

	# Scale - grows then shrinks slightly as it dissipates
	scale_amount_min = 0.075
	scale_amount_max = 0.25
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.4, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.7))
	scale_amount_curve = scale_curve

	# Color - fades in quickly, then fully transparent by 1.5 seconds
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.85, 0.85, 0.85, 0.0))
	gradient.add_point(0.06, Color(0.85, 0.85, 0.85, 0.7))
	gradient.add_point(0.3, Color(0.6, 0.6, 0.6, 0.0))
	gradient.add_point(1.0, Color(0.6, 0.6, 0.6, 0.0))
	color_ramp = gradient
