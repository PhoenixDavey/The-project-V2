extends Area2D

var warning_label = null
var detection_range = 500.0  # adjust this to match your collision shape size

func _ready():
	var warning_node = get_parent().find_child("Warning", true)
	if warning_node:
		warning_label = warning_node.find_child("Warning label", false)
	if warning_label == null:
		push_warning("Warning label not found!")

func _process(_delta):
	var sandwich = get_tree().get_first_node_in_group("sandwich")
	if sandwich == null:
		sandwich = get_tree().current_scene.find_child("Sandwich monster", true)
	
	print("Sandwich found: ", sandwich)
	if sandwich:
		var dist = global_position.distance_to(sandwich.global_position)
		print("Distance: ", dist, " | Range: ", detection_range)
	
	# ... rest of code
