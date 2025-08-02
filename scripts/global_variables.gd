extends Node
var spring_strength: float =  0 
var damping: float = 0   
var max_reach: float = 0     
var dead_zone: float = 0
var shoulder = null
	# Get the position of the mouse in the game world
var mouse_pos: Vector2 = Vector2(0,0) 
var direction_vector: Vector2 = Vector2(0,0) 
var distance: float = 0
var target_position: Vector2 = Vector2(0,0)
var to_target: Vector2 = Vector2(0,0)
var spring_force: float = 0
var damping_force: float = 0
var touching_surface: bool = false
var grab_pressed: bool = false
var bar_value
var timer_value
var in_spawn_area = false
var level = 0
var ammo_left
var finished_game = false
