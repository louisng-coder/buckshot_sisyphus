extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Body":
		end_game()

func end_game():
	GlobalVariables.finished_game = true

func _ready():
	monitoring = false
	await get_tree().create_timer(5).timeout  # wait half a second
	monitoring = true
