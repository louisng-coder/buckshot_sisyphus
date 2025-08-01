extends Node2D

@export var block_count: int = 30

# Define a rectangle where blocks *can* spawn:
@export var spawn_area: Rect2 = Rect2(Vector2(0, 250), Vector2(1000, -1500))

# Define a rectangle where blocks *must not* spawn:
@export var danger_zone: Rect2 = Rect2(Vector2(0, 0), Vector2(250, 250))
@export var size: float
var block_scenes: Array[PackedScene] = []
@export var scale_range: Vector2 = Vector2(0.2, 0.3)  # min and max scale
@export var rotation_range: Vector2 = Vector2(-10, 10)  # in degrees



func _ready():
	randomize()
	load_block_scenes(GlobalVariables.level)

	if block_scenes.is_empty():
		push_error("No block scenes loaded for level: %s" % GlobalVariables.level)
		return

	var placed := 0
	var attempts := 0

	while attempts < block_count * 5 and placed < block_count:
		attempts += 1

		# pick a random position inside spawn_area
		var x = randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x)
		var y = randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		var new_position = Vector2(x, y)

		# skip if inside danger_zone
		if danger_zone.has_point(new_position):
			continue

		# spawn a random block
		var scene := block_scenes[randi() % block_scenes.size()]
		var b = scene.instantiate()
		add_child(b)
		b.global_position = new_position
		b.scale = Vector2(size, size)

		placed += 1
		
		# Random scale between scale_range.x and scale_range.y
		var scale_val = randf_range(scale_range.x, scale_range.y)
		b.scale = Vector2(scale_val, scale_val)  # Uniform scaling (X and Y same)

		# Random rotation in degrees between rotation_range.x and rotation_range.y
		b.rotation_degrees = randf_range(rotation_range.x, rotation_range.y)


	if placed < block_count:
		push_warning("Only placed %d/%d blocks (too many in danger zone?)" % [placed, block_count])


func load_block_scenes(level: int):
	var level_names = [
		"scratch_blocks",
		"python_blocks",
		"cpp_blocks",
		"asm_blocks",
		"binary_blocks"
	]
	var folder_name = "scratch_blocks"
	if level >= 0 and level < level_names.size():
		folder_name = level_names[level]

	var folder_path = "res://scenes/%s/" % folder_name
	block_scenes.clear()

	for i in range(1, 11):
		var idx = "%02d" % i
		var path = folder_path + "block_" + idx + ".tscn"
		var scene = ResourceLoader.load(path)
		if scene is PackedScene:
			block_scenes.append(scene)
		else:
			push_warning("Failed to load block scene: " + path)
