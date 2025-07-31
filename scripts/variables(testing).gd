extends Label

func _process(delta: float) -> void:
	text = (
		"=== Debug Info ===\n" +
		"Touching Surface: %s\n" % str(GlobalVariables.touching_surface) +
		"Grab Pressed: %s\n" % str(GlobalVariables.grab_pressed) +
		"Mouse Position: %s\n" % str(GlobalVariables.mouse_pos) +
		"Direction Vector: %s\n" % str(GlobalVariables.direction_vector) +
		"Distance: %.2f\n" % GlobalVariables.distance +
		"Target Position: %s\n" % str(GlobalVariables.target_position) +
		"To Target: %s\n" % str(GlobalVariables.to_target) +
		"Spring Force: %.2f\n" % GlobalVariables.spring_force +
		"Damping Force: %.2f\n" % GlobalVariables.damping_force
	)
	add_theme_font_size_override("font_size", 10)
