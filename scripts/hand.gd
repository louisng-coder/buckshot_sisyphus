extends RigidBody2D

@export var spring_strength: float = 1000.0
@export var damping: float = 200.0
@export var max_reach: float = 60.0
@export var dead_zone: float = 10.0

@onready var shoulder = get_parent().get_node("Body/shoulder")
@onready var body = get_parent().get_node("Body")
@onready var camera = get_parent().get_node("Body/Camera2D")

var shotgun = preload("res://scenes/shotgun.tscn")
var shotgun_object = shotgun.instantiate()

var touching_surface = false

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

	if Input.is_action_just_pressed("shoot"):
		var recoil_strength = 30000.0
		var gun_direction = shotgun_object.actual_direction
		body.apply_impulse(-recoil_strength * gun_direction)

func _on_grab_area_body_entered(body: Node2D) -> void:
	touching_surface = true

func _on_grab_area_body_exited(body: Node2D) -> void:
	touching_surface = false
