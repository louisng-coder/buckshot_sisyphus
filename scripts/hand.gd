extends RigidBody2D

@export var spring_strength: float = 1000.0
@export var damping: float = 200.0
@export var max_reach: float = 100.0
@export var dead_zone: float = 10.0
@export_range(0.1, 10.0, 0.1) var min_zoom := 0.5
@export_range(0.1, 10.0, 0.1) var max_zoom := 2.0
@export var zoom_step := 0.1
@export var max_shots := 2
var remaining_shots := max_shots



@onready var player_root = get_parent()
@onready var shoulder   = player_root.get_node("Body/shoulder")
@onready var body       = player_root.get_node("Body")
@onready var upper_arm  = player_root.get_node("upperarm")
@onready var forearm    = player_root.get_node("forearm")
@onready var hand       = player_root.get_node("hand")
@onready var head       = player_root.get_node("head")
@onready var camera     = player_root.get_node("Body/Camera2D")

# --- Objective Camera Lerp Variables ---
var show_objective := true
var objective_target := Vector2(1000, -1000)
var objective_lerp_speed := 2.0
var objective_timer := 0.0
var delay_after_focus := 1

var CloneScene   = preload("res://scenes/clone.tscn")
var ShotgunScene = preload("res://scenes/shotgun.tscn")
var shotgun_object: RigidBody2D

var touching_surface = false
var clones := []

const OFFSET_MULTIPLIER = 400.0
const CAMERA_LERP_SPEED = 4.0
const MAX_FORCE         = 90000.0
const CHARGE_RATE       = 300000.0

var charge_force := 0.0
var is_charging := false

# store original poses for reset
var original_positions = {}
var original_rotations = {}

func _ready():
	# attach shotgun
	shotgun_object = ShotgunScene.instantiate() as RigidBody2D
	call_deferred("_attach_shotgun")

	# record original poses
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
	if linear_velocity.length() > 5000 and not GlobalVariables.in_spawn_area:
		perform_loop()
		remaining_shots = max_shots
	GlobalVariables.ammo_left = remaining_shots
	#Objective camera focus before gameplay
	if show_objective:
		# Skip on any mouse button click
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			show_objective = false
			camera.offset = Vector2.ZERO
			camera.global_position = global_position
			return

	# Continue lerping toward objective
		camera.global_position = camera.global_position.lerp(objective_target, delta * objective_lerp_speed)
		if camera.global_position.distance_to(objective_target) < 1.0:
			objective_timer += delta
			if objective_timer >= delay_after_focus:
				show_objective = false
				camera.offset = Vector2.ZERO
				camera.global_position = global_position
		return


	# update UI bars
	GlobalVariables.bar_value = charge_force / MAX_FORCE

	# revert last corpse
	if Input.is_action_just_pressed("revert") and clones.size() > 0:
		var clone = clones.pop_back()
		clone.queue_free()

	# movement spring + damping
	apply_central_force(-linear_velocity * damping * 0.2)

	# grab movement
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
				body.apply_central_force(-force * 1.2) 


# — Shotgun charge + recoil (no mouse aim) —
	if Input.is_action_pressed("shoot"):
		if remaining_shots > 0:
			is_charging = true
			charge_force = clamp(charge_force + CHARGE_RATE * delta, 0, MAX_FORCE)
			Engine.time_scale = 0.03
		else:
			pass
			# Play empty click (once)
		if not is_charging:
				#$EmptyClickSound.play()
			is_charging = true  # prevent spamming sound
	elif Input.is_action_just_released("shoot") and is_charging:
		Engine.time_scale = 1
		is_charging = false
		if remaining_shots > 0:
			var dir = shotgun_object.actual_direction.normalized()
			body.apply_impulse(-dir * charge_force)
			charge_force = 0.0
			remaining_shots -= 1
	
		# always shoot opposite the hand-to-shoulder vector
		var dir = (hand.global_position - shoulder.global_position).normalized()
		body.apply_impulse(dir * charge_force)
		charge_force = 0.0


	# manual loop: only if not in spawn area
	if Input.is_action_just_pressed("loop") and not GlobalVariables.in_spawn_area:
		perform_loop()
		remaining_shots = 2

	# camera follow lerp during gameplay
	if Input.is_action_pressed("look"):
		var mpos2 = get_global_mouse_position()
		var vp   = get_viewport().get_visible_rect().size
		var target_offset = (mpos2 - global_position) / vp * OFFSET_MULTIPLIER
		camera.offset = camera.offset.lerp(target_offset, delta * CAMERA_LERP_SPEED)
	else:
		camera.offset = camera.offset.lerp(Vector2(0,0), delta * CAMERA_LERP_SPEED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_change_zoom(-zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_change_zoom( zoom_step)

func _change_zoom(delta_zoom: float) -> void:
	# camera.zoom is a Vector2: we’ll change both axes the same amount
	var z = camera.zoom.x + delta_zoom
	z = clamp(z, min_zoom, max_zoom)
	camera.zoom = Vector2(z, z)


var surface_touch_count := 0

func _on_grab_area_body_entered(b: Node2D) -> void:
	surface_touch_count += 1
	touching_surface = surface_touch_count > 0

func _on_grab_area_body_exited(b: Node2D) -> void:
	surface_touch_count = max(surface_touch_count - 1, 0)
	touching_surface = surface_touch_count > 0

func perform_loop():
	# spawn corpse clone
	var c = CloneScene.instantiate()
	get_tree().current_scene.add_child(c)
	c.global_position = hand.global_position
	clones.append(c)

	# apply tints
	var base_brightness := 1.0
	var decrement := 0.05
	var count := clones.size()
	for idx in count:
		var corpse = clones[idx]
		# invert index so 0 → newest, count-1 → oldest
		var inv = count - 1 - idx
		var strength = max(base_brightness - inv * decrement, 0.0)
		var tint = Color(strength, strength, strength)
		for child in corpse.get_children():
			if child is CanvasItem:
				child.modulate = tint
			for sub in child.get_children():
				if sub is CanvasItem:
					sub.modulate = tint


	# sync & freeze each part on the clone
	var part_paths = ["Body", "Body/shoulder", "upperarm", "forearm", "hand", "head"]
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

	# clone and freeze the shotgun on corpse
	var sg = ShotgunScene.instantiate() as RigidBody2D
	c.get_node("hand").add_child(sg)
	sg.global_transform = shotgun_object.global_transform
	if sg is RigidBody2D:
		sg.freeze = true
		sg.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		sg.collision_layer = 1 | 2 | 3 | 4
		sg.collision_mask  = 1 | 2 | 3 | 4

	# reset live parts to original pose
	for part in [body, shoulder, upper_arm, forearm, hand, head]:
		part.global_position = original_positions[part]
		part.global_rotation = original_rotations[part]
		if part is RigidBody2D:
			part.linear_velocity  = Vector2.ZERO
			part.angular_velocity = 0.0

	# snap shotgun back
	shotgun_object.global_position = hand.global_position
	shotgun_object.global_rotation = hand.global_rotation
