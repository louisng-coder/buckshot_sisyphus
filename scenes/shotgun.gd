extends RigidBody2D

var direction: Vector2 = Vector2.RIGHT  # default value to avoid errors

func _physics_process(delta):
	direction = (get_global_mouse_position() - global_position).normalized()

	if Input.is_action_pressed("aim"):
		var target_angle = direction.angle()
		var angle_diff = wrapf(target_angle - rotation, -PI, PI)
		var rotation_speed = 5.0
		angular_velocity = angle_diff * rotation_speed
