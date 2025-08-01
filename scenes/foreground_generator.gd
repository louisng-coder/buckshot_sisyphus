extends Node2D

# Settings
@export var block_count: int = 30           # Total blocks to spawn
@export var spawn_area: Rect2 = Rect2(Vector2(0, 250), Vector2(1000, -1500))  # Valid spawn region
@export var danger_zone: Rect2 = Rect2(Vector2(0, 0), Vector2(250, 250))      # Block-free zone
var block_scenes: Array[PackedScene] = []   # Stores block templates
@export var scale_range: Vector2 = Vector2(0.2, 0.3)      # Min/max block size
@export var rotation_range: Vector2 = Vector2(-10, 10)    # Min/max rotation (degrees)

func _ready():
	randomize()
	load_block_scenes(GlobalVariables.level)  # Load blocks for current level
	
	if block_scenes.is_empty():
		push_error("No blocks loaded for level: " + GlobalVariables.level)
		return

	var placed := 0     # Successfully spawned blocks
	var attempts := 0   # Total tries
	
	# Attempt to place blocks
	while attempts < block_count * 5 and placed < block_count:
		attempts += 1
		# Generate random position
		var pos = Vector2(
			randf_range(spawn_area.position.x, spawn_area.end.x),
			randf_range(spawn_area.position.y, spawn_area.end.y)
		)
		
		# Skip positions in danger zone
		if danger_zone.has_point(pos):
			continue
		
		# Create random block
		var block = block_scenes.pick_random().instantiate()
		add_child(block)
		block.global_position = pos
		
		# Apply random scale and rotation
		var scale_val = randf_range(scale_range.x, scale_range.y)
		block.scale = Vector2(scale_val, scale_val)
		block.rotation_degrees = randf_range(rotation_range.x, rotation_range.y)
		
		placed += 1
	
	# Warn if failed to place all blocks
	if placed < block_count:
		push_warning("Placed only %d/%d blocks" % [placed, block_count])

# Load block assets based on current level
func load_block_scenes(level: int):
	# Level-to-folder mapping
	var folders = [
		"scratch_blocks", "python_blocks", "cpp_blocks", 
		"asm_blocks", "binary_blocks"
	]
	var folder = folders[clamp(level, 0, folders.size() - 1)]
	var path = "res://scenes/%s/" % folder
	
	# Load 10 block templates (block_01.tscn to block_10.tscn)
	block_scenes.clear()
	for i in range(1, 11):
		var scene = ResourceLoader.load(path + "block_%02d.tscn" % i)
		if scene:
			block_scenes.append(scene)
		else:
			push_warning("Missing block: " + path + "block_%02d.tscn" % i)
