extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Body":
		end_game()

func end_game():
	GlobalVariables.finished_game = true
	call_deferred("_trigger_ending")
