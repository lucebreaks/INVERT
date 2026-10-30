extends MeshInstance3D

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("respawn"):
		body.respawn()
