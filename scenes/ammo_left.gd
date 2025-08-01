extends Label

func _process(delta: float) -> void:
	text = "Ammo left: " + str(GlobalVariables.ammo_left)
