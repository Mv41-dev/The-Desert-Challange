
extends Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Reset the player normally.
	if body.is_in_group("player"):
		if body.has_method("resetar_para_inicio"):
			body.call_deferred("resetar_para_inicio")
		return

	# Ignore King Necromancer himself.
	if body.is_in_group("king_necromancer"):
		return

	# Kill enemies that fall into the void.
	if body.is_in_group("enemy") or body.is_in_group("inimigo"):
		if body.has_method("is_dead"):
			if body.call("is_dead"):
				return

		if body.has_method("tomar_dano"):
			body.call_deferred("tomar_dano", 999999)
		elif body.has_method("take_damage"):
			body.call_deferred("take_damage", 999999)
		else:
			body.queue_free()
