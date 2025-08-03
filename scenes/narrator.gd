extends RichTextLabel

@export var flag_path: NodePath
@export var player_path: NodePath
@onready var typewriter_sound = $Click
@onready var fade = get_parent().get_node("fade")
@onready var jazz = get_parent().get_parent().get_parent().get_node("Music")
var flag: Node2D
var player: Node2D

var teleport_triggered = false
var is_near_flag = false
var is_typing = false
var exit_check_running = false
var ending_started = false
var narration_interrupted := false

# timing
var base_hold = 1
var hold_per_char = 0.01

# spawn-area lines
var looping_at_spawn = [
	"Owen didn’t even code what happens if you try to loop here.",
	"He didn't actually know how to prevent clipping so sadly, you can't loop near the flag.",
	"Pretty sure you'd crash into your past self if you did that."
]

var falling_down_forever = [
	"Owen apparently forgot to make the ground, though Shift loops you back.",
	"Falling forever’s cool and all, but you can press Shift to loop back to spawn.",
	"Pretty easy to fall off a floating for loop in the sky, isn't it? Loop back with Shift"
]

var near_flag = ["Quite surprised at how close you are.",
"Come on! You can do it!",
"You're close!"]

var trying_shoot_no_ammo = ["You can't shoot without ammo!",
"You need to press Shift to loop back in time to regain ammo!"]


func _ready():
	

	get_parent().get_node("ColorRect").hide()
	flag = get_node(flag_path)
	player = get_node(player_path).get_node("hand")
	randomize()

	# ensure this UI still processes when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# default text color is black; we'll override to white for the ending
	add_theme_color_override("default_color", Color.BLACK)
	
	await say_typewriter("Owen doodled you in Scratch during programming class, then never finished the project.", 0.05)
	await say_typewriter("Now you’re climbing with his crappy shotgun in his mess of floating blocks to click the Stop button.", 0.05)


func _process(delta):
	if GlobalVariables.trying_shoot_no_ammo and GlobalVariables.finished_game == false and not is_typing:
		var idx = randi() % trying_shoot_no_ammo.size()
		await say_typewriter(trying_shoot_no_ammo[idx], hold_per_char)
		GlobalVariables.trying_shoot_no_ammo = false
	if GlobalVariables.gravity_flipped and GlobalVariables.finished_game == false and not is_typing:
		await say_typewriter("Turns out the shortcut flips gravity instead. Whoops.",  hold_per_char)
	if GlobalVariables.finished_game and not ending_started:
		ending_started = true
		narration_interrupted = true
		_start_ending()
		return

	if Input.is_action_just_pressed("loop") and GlobalVariables.in_spawn_area and not is_typing:
		var idx = randi() % looping_at_spawn.size()
		await say_typewriter(looping_at_spawn[idx], hold_per_char)

	var dist = player.global_position.distance_to(flag.global_position)
	if dist <= 200 and not is_typing and not is_near_flag:
		is_near_flag = true
		var idx = randi() % near_flag.size()
		await say_typewriter(near_flag[idx], hold_per_char)
	elif dist > 200 and is_near_flag:
		is_near_flag = false
		if not exit_check_running:
			_check_exit_zone()
	if GlobalVariables.ending == "delete":
		GlobalVariables.ending = ""
		GlobalVariables.choice_started = false

		await say_typewriter("Oh... Alright. I’ll stop everything. Just give me a second...", 0.01)

		# Ensure ColorRect is visible and starts fully transparent
		fade.visible = true
		fade.color.a = 0.0

		# Fade to black over 2 seconds, ignoring time_scale
		var fade_duration := 2.0
		var start_time := Time.get_ticks_usec()
		while true:
			var elapsed := float(Time.get_ticks_usec() - start_time) / 1_000_000.0
			var t: float = clamp(elapsed / fade_duration, 0.0, 1)
			fade.color = Color(0, 0, 0, t)
			print(fade)
			await get_tree().process_frame
			if t >= 1.0:
				break
		add_theme_color_override("default_color", Color.WHITE)
		await say_typewriter("It should start now. It's been nice knowing you.", 0.05)
		# Pause briefly before quitting (still ignoring time_scale)
		var wait_start := Time.get_ticks_usec()
		var wait_duration := 1.5
		while Time.get_ticks_usec() < wait_start + int(wait_duration * 1_000_000):
			await get_tree().process_frame

		get_tree().quit()
		
	if GlobalVariables.ending == "restart":
		GlobalVariables.ending = ""
		GlobalVariables.choice_started = false

		await say_typewriter("So... back to the loop, huh?", 0.05)
		await say_typewriter("Figured you'd pick that one.", 0.05)
		await say_typewriter("I won't remember anything, you know?", 0.05)
		await say_typewriter("...Good luck, I guess.", 0.05)
		# Ensure ColorRect is visible and starts fully transparent
		fade.visible = true
		fade.color.a = 0.0

		# Fade to black over 2 seconds, ignoring time_scale
		var fade_duration := 2.0
		var start_time := Time.get_ticks_usec()
		while true:
			var elapsed := float(Time.get_ticks_usec() - start_time) / 1_000_000.0
			var t: float = clamp(elapsed / fade_duration, 0.0, 1)
			fade.color = Color(0, 0, 0, t)
			print(fade)
			await get_tree().process_frame
			if t >= 1.0:
				break
		add_theme_color_override("default_color", Color.WHITE)
		await say_typewriter("Resetting the world now...", 0.05)
		# Pause briefly before quitting (still ignoring time_scale)
		var wait_start := Time.get_ticks_usec()
		var wait_duration := 1.5
		while Time.get_ticks_usec() < wait_start + int(wait_duration * 1_000_000):
			await get_tree().process_frame

		await get_tree().create_timer(0.2, true, true, true).timeout
		GlobalVariables.finished_game = false
		GlobalVariables.finished_once = true
		Engine.time_scale = 1
		get_tree().reload_current_scene()
		


		

func _check_exit_zone() -> void:
	exit_check_running = true
	await get_tree().create_timer(5, true, true, true).timeout
	if player.global_position.distance_to(flag.global_position) > 200 and not is_typing and GlobalVariables.finished_game == false:
		await say_typewriter("Don't worry, failing is part of it. Probably.", hold_per_char)
	exit_check_running = false

# typewriter with hold
func say_typewriter(sentence: String, delay: float) -> void:
	narration_interrupted = false
	is_typing = true
	text = ""

	# clear old text at start
	# build text char by char
	for c in sentence:
		if narration_interrupted:
			is_typing = false
			text = ""
			return

		text += c

		if c != " " and typewriter_sound:
			typewriter_sound.pitch_scale = randf_range(0.95, 1.05)
			typewriter_sound.play()

		# wait unscaled real-time
		var target_time = Time.get_ticks_msec() + int(delay * 1000)
		while Time.get_ticks_msec() < target_time:
			await get_tree().process_frame

	# hold full sentence
	await say_hold(sentence)
	text = ""
	is_typing = false

# helper to hold the full sentence on screen
func say_hold(sentence: String) -> void:
	var hold_time = base_hold + sentence.length() * hold_per_char
	print(hold_time)
	var target = Time.get_ticks_msec() + int(hold_time * 1000)
	while Time.get_ticks_msec() < target:
		await get_tree().process_frame

func _start_ending() -> void:
	jazz.bus = "Muffled"
	jazz.pitch_scale = 1
	Engine.time_scale = 0.001
	get_parent().get_node("ColorRect").show()
	await get_tree().create_timer(2.0, true, true, true).timeout
	var final_lines = [
		"...Wait. You actually made it here by climbing?",
		"You’re telling me you *shotgunned* and used your clones across floating Scratch blocks instead of using the shortcut?",
		"Oh man.",
		"I *might* have forgotten to mention there were shortcuts.",
		"Like you could've used Shift + B + Alt + Ctrl to teleport here instantly. Classic debugging shortcut.",
		"Sorry about that.",
		"But hey... you made it anyway. That counts for something, right?",
		"So now you’ve got options.",
		"I can delete everything. Wipe it clean. No loops. No shotgun. No me.",
		"Or you can reset it. Start from scratch. Literally.",
		"You don't even need to reach the stop button, just do whatever if I reset",
		"I dropped two scripts next to you. Click whichever feels right.",
	]

	
	for line in final_lines:
		await say_typewriter(line, 0.01)
	
	GlobalVariables.choice_started = true

func _on_fall_area_body_entered(body: Node2D) -> void:
	if body.name == "Body" and GlobalVariables.finished_game == false and not is_typing:
		var idx = randi() % falling_down_forever.size()
		await say_typewriter(falling_down_forever[idx], hold_per_char)
