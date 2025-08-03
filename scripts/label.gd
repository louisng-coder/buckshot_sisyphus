extends Label

func _physics_process(delta: float) -> void:
	text = "Shells: " + str(GlobalVariables.ammo_left) 
