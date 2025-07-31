extends RigidBody2D

# Settings to control how stretchy and responsive the arm is
@export var spring_strength: float = 1000.0  # How strongly the hand is pulled
@export var damping: float = 200.0           # How much to slow it down (resistance)
@export var max_reach: float = 60.0          # How far the arm can stretch
@export var dead_zone: float = 10.0          # Minimum distance before it starts moving

# Automatically find the shoulder and body when the game starts
@onready var shoulder = get_parent().get_node("Body/shoulder")
@onready var body = get_parent().get_node("Body")



# This function runs every frame to update the hand's position
func _physics_process(delta: float) -> void:

	if not Input.is_action_pressed("grab"):
		# Do nothing if the "grab" button isn't being held
		return

	# Get the position of the mouse in the game world
	var mouse_pos = get_global_mouse_position()

	# Step 1: Find the direction and distance from the shoulder to the mouse
	var direction_vector = mouse_pos - shoulder.global_position
	var distance = direction_vector.length()

	# Step 2: If the mouse is too close to the shoulder, don't move the hand
	if distance < dead_zone:
		return

	# Step 3: If the mouse is too far, limit how far the hand can reach
	if distance > max_reach:
		direction_vector = direction_vector.normalized() * max_reach

	# Step 4: Figure out where the hand *should* be, based on that direction
	var target_position = shoulder.global_position + direction_vector

	# Step 5: Figure out how far the hand is from where it should be
	var to_target = target_position - global_position

	# Step 6: Pull the hand toward the target using a spring-like force,
	# and also slow it down using damping
	var spring_force = to_target * spring_strength
	var damping_force = -linear_velocity * damping

	# Step 7: Apply both forces to the hand to move it realistically
	apply_central_force(spring_force + damping_force)
	
	# Update debug values in GlobalVariables
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
	if touching_surface and Input.is_action_pressed("grab"):
		var crawl_force = -spring_force
		body.apply_central_force(crawl_force)
	# Test: Rotate the cane to align with the arm vector


var cane_scene = preload("res://scenes/cane.tscn")

func _ready():
	pass
	var cane = cane_scene.instantiate()
	call_deferred("_attach_cane", cane)

func _attach_cane(cane):
	get_parent().add_child(cane)
	cane.global_position = global_position + Vector2(0, 0)

	var joint = cane.get_node("PinJoint2D")
	joint.node_a = cane.get_path()
	joint.node_b = self.get_path()



var touching_surface = false

func _on_grab_area_body_entered(body: Node2D) -> void:
	touching_surface = true


func _on_grab_area_body_exited(body: Node2D) -> void:
	touching_surface = false
