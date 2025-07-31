extends RigidBody2D

@export var spring_strength: float = 1000.0
@export var damping: float = 200.0
@export var max_reach: float = 60.0
@export var dead_zone: float = 10.0

@export var spawn_position: Vector2 = Vector2(100, 100)

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

const OFFSET_MULTIPLIER   = 400.0
const CAMERA_LERP_SPEED   = 4.0
const MAX_FORCE           = 30000.0
const CHARGE_RATE         = 1000000.0

var charge_force := 0.0
var is_charging := false

func _ready():
	loop_timer.one_shot = true
	loop_timer.timeout.connect(_on_loop_timeout)
	call_deferred("_attach_shotgun")

func _attach_shotgun():
	get_parent().add_child(shotgun_object)
	shotgun_object.global_position = global_position
	var joint = shotgun_object.get_node("PinJoint2D")
	joint.node_a = shotgun_object.get_path()
	joint.node_b = self.get_path()

func _physics_process(delta: float) -> void:
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
				body.apply_central_force(-force * 2)

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
	var vp = get_viewport().get_visible_rect().size
	var offset = (mpos - global_position) / vp * OFFSET_MULTIPLIER
	camera.offset = camera.offset.lerp(-offset, delta * CAMERA_LERP_SPEED)

func _on_grab_area_body_entered(b: Node2D) -> void:
	touching_surface = true

func _on_grab_area_body_exited(b: Node2D) -> void:
	touching_surface = false

func _on_loop_timeout():
	perform_loop()

func perform_loop():
	# stop timer so we only loop once
	if not loop_timer.is_stopped():
		loop_timer.stop()

	# 1) spawn corpse clone
	var c = CloneScene.instantiate()
	get_tree().current_scene.add_child(c)
	c.global_position = global_position

	# 2) sync pose & set collisions
	var parts = {
		"Body":          body,
		"Body/shoulder": shoulder,
		"upperarm":      upper_arm,
		"forearm":       forearm,
		"hand":          hand,
		"head":          head
	}
	for path in parts.keys():
		var src = parts[path]
		var dst = c.get_node(path)
		dst.global_position = src.global_position
		dst.global_rotation = src.global_rotation
		if dst is RigidBody2D:
			dst.collision_layer = 1 << 4   # corpse on layer 5
			dst.collision_mask  = 1 << 0   # collide only with player
			dst.sleeping        = true

	# 3) clone the shotgun onto the corpse
	var sg = ShotgunScene.instantiate()
	c.add_child(sg)
	sg.global_position = shotgun_object.global_position
	var joint = sg.get_node("PinJoint2D")
	joint.node_a = sg.get_path()
	joint.node_b = c.get_path()

	# 4) wake corpses after a short delay
	await get_tree().create_timer(0.1).timeout
	for path in parts.keys():
		var dst = c.get_node(path)
		if dst is RigidBody2D:
			dst.sleeping = false

	# 5) reset player & shotgun position
	global_position  = spawn_position
	linear_velocity  = Vector2.ZERO
	angular_velocity = 0.0
	shotgun_object.global_position = global_position
