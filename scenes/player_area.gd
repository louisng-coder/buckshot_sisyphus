extends Area2D

var overlap_count := 0

func _on_body_entered(body: Node2D) -> void:
	overlap_count += 1
	GlobalVariables.in_spawn_area = overlap_count > 0

func _on_body_exited(body: Node2D) -> void:
	overlap_count = max(overlap_count - 1, 0)
	GlobalVariables.in_spawn_area = overlap_count > 0
	
