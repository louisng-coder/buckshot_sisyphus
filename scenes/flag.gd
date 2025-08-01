extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Body":
		end_game()

func end_game():
	# Replace this with your actual game-ending logic
	print("Game Over")
	get_tree().quit()
