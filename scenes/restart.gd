extends Sprite2D
func _process(delta: float) -> void:
	if GlobalVariables.choice_started == true:
		show()
	else: 
		hide()
