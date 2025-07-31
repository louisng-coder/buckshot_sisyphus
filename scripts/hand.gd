extends RigidBody2D

@export var spring_strength: float = 1000.0
@export var damping: float = 200.0
@export var max_reach: float = 60.0
@export var dead_zone: float = 10.0

@export var spawn_position: Vector2 = Vector2(100, 100)
@onready var player_root = get_parent()
@onready var shoulder   = get_parent().get_node("Body/shoulder")
@onready var body       = get_parent().get_node("Body")
@onready var upper_arm  = get_parent().get_node("upperarm")
@onready var forearm    = get_parent().get_node("forearm")
@onready var hand       = get_parent().get_node("hand")
@onready var head       = get_parent().get_node("head")
@onready var camera     = get_parent().get_node("Body/Camera2D")
@onready var loop_timer = get_parent().get_node("loop_timer") as Timer

var CloneScene   = preload("res://scenes/clone.tscn")
var ShotgunScene = preload("res://scenes/shotgun.tscn")
var shotgun_object = ShotgunScene.instantiate()

var touching_surface = false
var clones := []

const OFFSET_MULTIPLIER   = 400.0
const CAMERA_LERP_SPEED   = 4.0
const MAX_FORCE		   = 90000.0
const CHARGE_RATE		 = 300000.0

var charge_force := 0.0
var is_charging := false

# store original poses
var original_positions = {}
var original_rotations = {}

func _ready():
	# 1) connect timer
	loop_timer.one_shot = true
	loop_timer.timeout.connect(_on_loop_timeout)
	# 2) attach shotgun
	call_deferred("_attach_shotgun")
	# 3) record each part's original global position & rotation
	for part in [body, shoulder, upper_arm, forearm, hand, head]:
		original_positions[part] = part.global_position
		original_rotations[part] = part.global_rotation

func _attach_shotgun():
	player_root.add_child(shotgun_object)
	shotgun_object.global_position = hand.global_position
	var joint = shotgun_object.get_node("PinJoint2D")
	joint.node_a = shotgun_object.get_path()
	joint.node_b = hand.get_path()

func _physics_process(delta: float) -> void:
	# bar
	GlobalVariables.bar_value = charge_force / MAX_FORCE
	GlobalVariables.timer_value = loop_timer.time_left
	
	if Input.is_action_just_pressed("revert") and clones.size() > 0:
		var clone = clones.pop_back()
		clone.queue_free()

	# — Movement spring + damping —
	apply_central_force(-linear_velocity * damping * 0.2)

	if Input.is_action_pressed("grab"):
		var mpos = get_global_mouse_position()
		var dir = mpos - shoulder.global_position
		var dist = dir.length()
		if dist >= dead_zone:
			if dist > max_reach:
				dir = dir.normalized() * max_reach
			var target = shoulder.global_position + dir
			var force = (target - global_position) * spring_strength
			apply_central_force(force)
			if touching_surface:
				body.apply_central_force(-force )

	# — Shotgun charge + recoil —
	if Input.is_action_pressed("shoot"):
		is_charging = true
		charge_force = clamp(charge_force + CHARGE_RATE * delta, 0, MAX_FORCE)
		Engine.time_scale = 0.03
	elif Input.is_action_just_released("shoot") and is_charging:
		is_charging = false
		Engine.time_scale = 1.0
		var dir = shotgun_object.actual_direction.normalized()
		body.apply_impulse(-dir * charge_force)
		charge_force = 0.0
		loop_timer.start(5.0)

	# — Manual loop —
	if Input.is_action_just_pressed("loop") and loop_timer.time_left > 0:
		perform_loop()

	# — Camera lerp —
	var mpos = get_global_mouse_position()
	var vp   = get_viewport().get_visible_rect().size
	var offset = (mpos - global_position) / vp * OFFSET_MULTIPLIER
	camera.offset = camera.offset.lerp(-offset, delta * CAMERA_LERP_SPEED)

var surface_touch_count := 0

func _on_grab_area_body_entered(b: Node2D) -> void:
	surface_touch_count += 1
	touching_surface = surface_touch_count > 0

func _on_grab_area_body_exited(b: Node2D) -> void:
	surface_touch_count = max(surface_touch_count - 1, 0)
	touching_surface = surface_touch_count > 0


func _on_loop_timeout():
	perform_loop()
func perform_loop():
	# 0) stop timer (one-shot only)
	if not loop_timer.is_stopped():
		loop_timer.stop()

	# 1) spawn corpse clone
	var c = CloneScene.instantiate()
	get_tree().current_scene.add_child(c)
	c.global_position = hand.global_position
	clones.append(c)
	
	# Apply tints
	var max_clones = 15.0
	for idx in clones.size():
		var corpse = clones[idx]
		# compute strength: 0 at idx=0 (oldest), 1 at idx=max-1 (newest)
		var strength = clamp(float(idx) / (max_clones - 1.0), 0.0, 1.0)
		var tint = Color(strength, strength, strength)  # grayscale: black→white

		# apply tint to every CanvasItem under this corpse
		for child in corpse.get_children():
			if child is CanvasItem:
				child.modulate = tint
			for sub in child.get_children():
				if sub is CanvasItem:
					sub.modulate = tint

	# 2) sync & fully static each part on the clone
	var part_paths = [
		"Body",			 # torso
		"Body/shoulder",	# shoulder
		"upperarm",		 # siblings on player_root
		"forearm",
		"hand",
		"head"
	]
	for path in part_paths:
		var src = player_root.get_node(path)
		var dst = c.get_node(path)
		dst.global_position = src.global_position
		dst.global_rotation = src.global_rotation
		if dst is RigidBody2D:
			dst.freeze = true
			dst.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			dst.collision_layer = 1 | 2 | 3 | 4
			dst.collision_mask  = 1 | 2 | 3 | 4
			var shape = dst.get_node_or_null("CollisionShape2D")
			if shape:
				shape.disabled = false

	# 3) auto-push the corpse up if it overlaps the player
	var space_state = get_world_2d().direct_space_state
	var step_size := 2.0
	var max_attempts := 50
	var attempts := 0
	var overlap := true
	while overlap and attempts < max_attempts:
		overlap = false
		# check every limb for collision with player (layers 1-4)
		for path in part_paths:
			var dst = c.get_node(path)
			if dst is RigidBody2D:
				var shape = dst.get_node_or_null("CollisionShape2D")
				if shape and shape.shape:
					var params = PhysicsShapeQueryParameters2D.new()
					params.shape = shape.shape
					params.transform = dst.get_global_transform()
					params.collision_mask = 1 | 2 | 3 | 4
					var result = space_state.intersect_shape(params, 1)
					if result.size() > 0:
						overlap = true
						break
		if overlap:
			# shift all parts up by step_size
			for path in part_paths:
				c.get_node(path).global_position.y -= step_size
			attempts += 1

	# 4) clone the shotgun under the clone’s hand and freeze it
	var sg = ShotgunScene.instantiate()
	c.get_node("hand").add_child(sg)
	sg.global_position = shotgun_object.global_position
	sg.global_rotation = shotgun_object.global_rotation
	if sg is RigidBody2D:
		sg.freeze = true
		sg.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		sg.collision_layer = 1 | 2 | 3 | 4
		sg.collision_mask  = 1 | 2 | 3 | 4

	# 5) restore every live part back to its original recorded pose
	for part in [body, shoulder, upper_arm, forearm, hand, head]:
		part.global_position = original_positions[part]
		part.global_rotation = original_rotations[part]
		if part is RigidBody2D:
			part.linear_velocity  = Vector2.ZERO
			part.angular_velocity = 0.0

	# 6) snap the live shotgun back into your hand
	shotgun_object.global_position = hand.global_position
	shotgun_object.global_rotation = hand.global_rotation
	
