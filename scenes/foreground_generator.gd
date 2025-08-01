
extends Node2D

# Settings
@export var block_count: int = 1000
@export var spawn_area: Rect2 = Rect2(Vector2(-200, -1000), Vector2(3500, 3500))
@export var danger_zones: Array[Rect2] = [
	Rect2(Vector2(0, 0), Vector2(250, 250)),                          # Original
	Rect2(Vector2(1000, -500), Vector2(200, 200))                     # New zone near flag
]
@export var scaffold_every: int = 50           # every N blocks, place a vertical scaffold
@export var bias_strength: float = 0.6         # how strongly we bias spawns toward the flag
var block_scenes: Array[PackedScene] = []
@export var scale_range: Vector2 = Vector2(0.2, 0.3)
@export var rotation_range: Vector2 = Vector2(-10, 10)

const FLAG_POS: Vector2 = Vector2(1000, -500)   # flag location for biasing

func _ready():
	randomize()
	load_block_scenes(GlobalVariables.level)
	if block_scenes.is_empty():
		push_error("No blocks loaded for level: %d" % GlobalVariables.level)
		return

	var placed := 0
	var attempts := 0

	while attempts < block_count * 5 and placed < block_count:
		attempts += 1

		# 1) Scaffold pattern every scaffold_every blocks
		if placed > 0 and placed % scaffold_every == 0:
			_place_scaffold_pattern()
			placed += scaffold_every  # approximate increment
			continue

		# 2) Generate a biased position toward the flag
		var rand_x = lerp(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			FLAG_POS.x,
			bias_strength
		)
		var rand_y = lerp(
			randf_range(spawn_area.position.y, spawn_area.end.y),
			FLAG_POS.y,
			bias_strength
		)
		var pos = Vector2(rand_x, rand_y)

		# 3) Skip danger zone
		var blocked := false
		for zone in danger_zones:
			if zone.has_point(pos):
				blocked = true
				break
		if blocked:
			continue


		# 4) Place a block normally
		_instantiate_block_at(pos)
		placed += 1

	# 5) Place a few choke-gap platforms near the flag
	for i in range(3):
		var cx = randf_range(FLAG_POS.x - 200, FLAG_POS.x + 200)
		var cy = randf_range(FLAG_POS.y + 100, FLAG_POS.y - 300)
		_place_choke_gap(Vector2(cx, cy))

	if placed < block_count:
		push_warning("Placed only %d/%d blocks" % [placed, block_count])

# — Helpers —

func load_block_scenes(level: int):
	var folders = [
		"scratch_blocks", "python_blocks", "cpp_blocks",
		"asm_blocks", "binary_blocks"
	]
	var folder = folders[clamp(level, 0, folders.size() - 1)]
	var path = "res://scenes/%s/" % folder
	block_scenes.clear()
	for i in range(1, 11):
		var scene = ResourceLoader.load(path + "block_%02d.tscn" % i)
		if scene:
			block_scenes.append(scene)
		else:
			push_warning("Missing block: %s" % (path + "block_%02d.tscn" % i))

func _instantiate_block_at(pos: Vector2):
	var block = block_scenes.pick_random().instantiate()
	add_child(block)
	block.global_position = pos
	var s = randf_range(scale_range.x, scale_range.y)
	block.scale = Vector2(s, s)
	block.rotation_degrees = randf_range(rotation_range.x, rotation_range.y)

func _place_scaffold_pattern():
	# vertical ladder of 3–5 blocks
	var size = randi_range(3, 5)
	var base_x = randf_range(spawn_area.position.x + 200, spawn_area.end.x - 200)
	var base_y = randf_range(spawn_area.end.y + 300, spawn_area.end.y + 1000)
	for j in range(size):
		var pos = Vector2(base_x, base_y - j * 70)
		_instantiate_block_at(pos)

func _place_choke_gap(pos: Vector2):
	_instantiate_block_at(pos)
	# force horizontal orientation for clarity
	var b = get_child(get_child_count() - 1)
	if b:
		b.rotation_degrees = 0
