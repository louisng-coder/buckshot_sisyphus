extends Label

func _physics_process(delta: float) -> void:
	text = "shots left: " + str(GlobalVariables.ammo_left) 
