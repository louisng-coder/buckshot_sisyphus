extends RigidBody2D

var actual_direction: Vector2 = Vector2.RIGHT  # Define it as a member variable

func _physics_process(delta):
	actual_direction = transform.x.normalized()  # Update it every frame
	var aim_dir = (get_global_mouse_position() - global_position).normalized()

	if Input.is_action_pressed("aim"):
	# Rotate the vector by 0 degrees (π/4 radians)
		var angle_offset = PI  # 0 degrees in radians
		var rotated_dir = aim_dir.rotated(angle_offset)
		var target_angle = rotated_dir.angle()
		var angle_diff = wrapf(target_angle - rotation, -PI, PI)
		var rotation_speed = 10.0
		angular_velocity = angle_diff * rotation_speed
