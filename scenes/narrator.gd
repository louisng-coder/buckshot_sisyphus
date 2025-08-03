extends RichTextLabel

@export var flag_path: NodePath
@export var player_path: NodePath
@export var black_fade_path: NodePath
@onready var typewriter_sound = $Click

var flag: Node2D
var player: Node2D
var black_fade: ColorRect

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
	"Can't loop back when you're at spawn :(",
	"You can't loop back there!",
	"You'll collide with your past self if you do that!"
]

func _ready():
	flag = get_node(flag_path)
	player = get_node(player_path).get_node("hand")
	black_fade = get_node(black_fade_path)
	randomize()

	# start with no fade
	black_fade.modulate.a = 0.0

	# ensure this UI still processes when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	black_fade.process_mode = Node.PROCESS_MODE_ALWAYS

	# default text color is black; we'll override to white for the ending
	add_theme_color_override("default_color", Color.BLACK)

func _process(delta):
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
		await say_typewriter("Come on, just touch the flag already!", hold_per_char)
	elif dist > 200 and is_near_flag:
		is_near_flag = false
		if not exit_check_running:
			_check_exit_zone()

func _check_exit_zone() -> void:
	exit_check_running = true
	await get_tree().create_timer(5.0).timeout
	if player.global_position.distance_to(flag.global_position) > 200 and not is_typing:
		await say_typewriter("Aww, such a shame, you were sooooo close.", hold_per_char)
	exit_check_running = false

func say_typewriter(sentence: String, delay: float) -> void:
	narration_interrupted = false
	is_typing = true
	text = ""
	
	for c in sentence:
		if narration_interrupted:
			is_typing = false
			text = ""
			return
		
		text += c

		# Play typewriter sound with random pitch if not a space
		if c != " " and typewriter_sound:
			typewriter_sound.pitch_scale = randf_range(0.95, 1.05)
			typewriter_sound.play()

		await get_tree().create_timer(delay).timeout

	var hold_time = base_hold + sentence.length() * hold_per_char
	var timer = get_tree().create_timer(hold_time)
	await timer.timeout
	
	text = ""
	is_typing = false


	if narration_interrupted:
		text = ""
		is_typing = false
		return

	text = ""
	is_typing = false

func _start_ending() -> void:
	get_tree().paused = true

	add_theme_color_override("default_color", Color.WHITE)

	await _fade_in_black(1.5)

	var final_lines = [
		"Congratulations.",
		"You've reached the floating flag on Mount Scratch",
		"And now... what?",
		"You win?",
		"...Just like last time.",
		"...Just like next time.",
		"Now do it all again, Buckshot Sisyphus."
	]
	for line in final_lines:
		await say_typewriter(line, hold_per_char)

	await say_typewriter("Press R to loop again if you think it's not pointless.", hold_per_char)

	while not Input.is_action_just_pressed("restart"):
		await get_tree().process_frame

	GlobalVariables.finished_game = false  # Prevent ending from retriggering
	get_tree().paused = false  # Resume game
	get_tree().reload_current_scene()


func _fade_in_black(duration: float) -> void:
	var elapsed = 0.0
	while elapsed < duration:
		elapsed += get_process_delta_time()
		black_fade.modulate.a = clamp(elapsed / duration, 0.0, 1.0)
		await get_tree().process_frame


func _on_fall_area_body_entered(body: Node2D) -> void:
	
