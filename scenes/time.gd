extends Label

func _process(delta: float) -> void:
	text = String.num(GlobalVariables.timer_value, 2)
