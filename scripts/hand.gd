extends RigidBody2D

@export var spring_strength: float = 1000.0
@export var damping: float = 200.0
@export var max_reach: float = 60.0
@export var dead_zone: float = 10.0

@onready var shoulder = get_parent().get_node("Body/shoulder")
@onready var body = get_parent().get_node("Body")
@onready var camera = get_parent().get_node("Body/Camera2D")
@onready var loop_timer = get_parent().get_node("loop_timer")
var shotgun = preload("res://scenes/shotgun.tscn")
var shotgun_object = shotgun.instantiate()

var touching_surface = false

const OFFSET_MULTIPLIER = 400.0
const CAMERA_LERP_SPEED = 4.0
const MAX_FORCE := 90000.0      
const CHARGE_RATE := 1000000.0    

var charge_force := 0.0
var is_charging := false


func _ready():
	call_deferred("_attach_shotgun", shotgun_object)

func _attach_shotgun(shotgun_object):
	get_parent().add_child(shotgun_object)
	shotgun_object.global_position = global_position
	var joint = shotgun_object.get_node("PinJoint2D")
	joint.node_a = shotgun_object.get_path()
	joint.node_b = self.get_path()

func _physics_process(delta: float) -> void:
	var is_grabbing = Input.is_action_pressed("grab")
	var is_aiming = Input.is_action_pressed("aim")

	var damping_force = -linear_velocity * damping * 0.2
	apply_central_force(damping_force)

	if is_grabbing:
		var mouse_pos = get_global_mouse_position()
		var direction_vector = mouse_pos - shoulder.global_position
		var distance = direction_vector.length()

		if distance >= dead_zone:
			if distance > max_reach:
				direction_vector = direction_vector.normalized() * max_reach
			var target_position = shoulder.global_position + direction_vector
			var to_target = target_position - global_position
			var spring_force = to_target * spring_strength
			apply_central_force(spring_force)

			if touching_surface:
				var crawl_force = -spring_force * 2
				body.apply_central_force(crawl_force)

			# Debug info
			GlobalVariables.spring_strength = spring_strength
			GlobalVariables.damping = damping
			GlobalVariables.max_reach = max_reach
			GlobalVariables.dead_zone = dead_zone
			GlobalVariables.touching_surface = touching_surface
			GlobalVariables.mouse_pos = mouse_pos
			GlobalVariables.direction_vector = direction_vector
			GlobalVariables.distance = distance
			GlobalVariables.target_position = target_position
			GlobalVariables.to_target = to_target
			GlobalVariables.spring_force = spring_force.length()
			GlobalVariables.damping_force = damping_force.length()
	

# hold to charge the shotgun blast
	if Input.is_action_pressed("shoot"):
		is_charging = true
		charge_force += CHARGE_RATE * delta
		charge_force = clamp(charge_force, 0, MAX_FORCE)
		Engine.time_scale = 0.03  # slow motion effect
	elif Input.is_action_just_released("shoot") and is_charging:
		is_charging = false
		Engine.time_scale = 1.0  # reset time scale

		var dir = shotgun_object.actual_direction.normalized()
		body.apply_impulse(-dir * charge_force)
		print(charge_force)
		charge_force = 0.0

		
		
		
		
#AAA
	if Input.is_action_just_pressed("loop"):
		if loop_timer.time_left > 0:
			_perform_loop()
	if loop_timer.time_left == 0:
		_perform_loop()
		


	# 1. get mouse and player positions
	var mouse_pos = get_global_mouse_position()
	var player_pos = global_position

	# 2. figure out how big the viewport is
	var vp_size = get_viewport().get_visible_rect().size

	# 3. compute an offset vector in screen-relative space
	var offset_vec = (mouse_pos - player_pos) / (vp_size) * OFFSET_MULTIPLIER

	# 4. lerp your Camera2D.offset toward that
	camera.offset = camera.offset.lerp(-offset_vec, delta * CAMERA_LERP_SPEED)

func _on_grab_area_body_entered(body: Node2D) -> void:
	touching_surface = true

func _on_grab_area_body_exited(body: Node2D) -> void:
	touching_surface = false

func _perform_loop():
	pass

func _on_timer_timeout() -> void:
	pass # Replace with function body.
