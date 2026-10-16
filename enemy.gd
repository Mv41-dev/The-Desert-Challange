extends CharacterBody2D

# IA simples com patrulha, deteccao, perseguicao e combate por quadros da animacao.
enum Estado { PARADO, PATRULHANDO, PERSEGUINDO, ATACANDO, FERIDO, MORTO }

const GRAVITY: float = 980.0
const MAX_FALL_SPEED: float = 650.0

@export_range(0.0, 300.0, 5.0) var speed: float = 60.0
@export_range(1, 20, 1) var vida: int = 2
@export_range(1, 10, 1) var dano: int = 1
@export_range(0.2, 5.0, 0.05) var intervalo_dano: float = 1.1
@export_range(15.0, 70.0, 1.0) var alcance_ataque: float = 29.0
@export var patrulhar: bool = false
@export_range(15.0, 300.0, 5.0) var distancia_patrulha: float = 100.0
@export var perseguir_jogador: bool = true
@export_range(0, 10, 1) var quadro_do_golpe: int = 2

var player: Node2D = null
var estado: Estado = Estado.PARADO
var posicao_inicial: Vector2
var direcao_patrulha: float = -1.0
var direcao_olhar: float = -1.0
var tempo_ate_atacar: float = 0.0
var ja_aplicou_golpe: bool = false
var morto: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var floor_check: RayCast2D = $FloorCheck


func _ready() -> void:
	add_to_group("inimigo")
	remove_from_group("player")
	posicao_inicial = global_position
	estado = Estado.PATRULHANDO if patrulhar else Estado.PARADO
	sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	sprite.frame_changed.connect(_quando_trocar_quadro)
	_animar_movimento()


func _physics_process(delta: float) -> void:
	if estado == Estado.MORTO:
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0
	tempo_ate_atacar = maxf(tempo_ate_atacar - delta, 0.0)

	if estado == Estado.ATACANDO or estado == Estado.FERIDO:
		if estado == Estado.ATACANDO:
			velocity.x = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		return

	var jogador_valido: bool = perseguir_jogador and is_instance_valid(player) and player.is_in_group("player")
	if jogador_valido:
		# Nao tenta morder o jogador em uma plataforma distante na vertical.
		var diferenca: Vector2 = player.global_position - global_position
		if absf(diferenca.y) <= 36.0 and absf(diferenca.x) <= alcance_ataque:
			velocity.x = 0.0
			_virar(diferenca.x)
			if tempo_ate_atacar <= 0.0:
				_iniciar_ataque()
			else:
				estado = Estado.PARADO
				_animar_movimento()
		else:
			estado = Estado.PERSEGUINDO
			var direcao: float = signf(diferenca.x)
			velocity.x = direcao * speed if absf(diferenca.y) <= 65.0 else 0.0
			_virar(direcao)
			_evitar_borda(direcao)
			_animar_movimento()
	elif patrulhar:
		estado = Estado.PATRULHANDO
		if absf(global_position.x - posicao_inicial.x) >= distancia_patrulha:
			direcao_patrulha = -1.0 if global_position.x > posicao_inicial.x else 1.0
		velocity.x = direcao_patrulha * speed
		_virar(direcao_patrulha)
		_evitar_borda(direcao_patrulha)
		_animar_movimento()
	else:
		estado = Estado.PARADO
		velocity.x = 0.0
		_animar_movimento()

	move_and_slide()
	if is_on_wall() and estado == Estado.PATRULHANDO:
		direcao_patrulha *= -1.0


func _evitar_borda(direcao: float) -> void:
	if direcao == 0.0 or not is_on_floor():
		return
	floor_check.position.x = 22.0 * direcao
	floor_check.force_raycast_update()
	if not floor_check.is_colliding():
		velocity.x = 0.0
		if estado == Estado.PATRULHANDO:
			direcao_patrulha *= -1.0


func _virar(direcao: float) -> void:
	if direcao == 0.0:
		return
	direcao_olhar = direcao
	# Cobra e hiena nos sprites originais olham para a esquerda.
	sprite.flip_h = direcao > 0.0


func _tocar(nome: StringName) -> void:
	if sprite.sprite_frames.has_animation(nome) and sprite.animation != nome:
		sprite.play(nome)


func _animar_movimento() -> void:
	if absf(velocity.x) > 0.5:
		if sprite.sprite_frames.has_animation("run"):
			_tocar("run")
		else:
			_tocar("walk")
	else:
		_tocar("idle")


func _iniciar_ataque() -> void:
	if estado == Estado.MORTO or estado == Estado.FERIDO or estado == Estado.ATACANDO:
		return
	estado = Estado.ATACANDO
	velocity.x = 0.0
	ja_aplicou_golpe = false
	tempo_ate_atacar = intervalo_dano
	sprite.play("attack")


func _quando_trocar_quadro() -> void:
	if estado != Estado.ATACANDO or sprite.animation != "attack" or ja_aplicou_golpe:
		return
	if sprite.frame >= quadro_do_golpe:
		ja_aplicou_golpe = true
		if is_instance_valid(player) and player.has_method("tomar_dano"):
			var distancia: Vector2 = player.global_position - global_position
			if absf(distancia.x) <= alcance_ataque + 8.0 and absf(distancia.y) <= 36.0:
				player.tomar_dano(dano, global_position)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null


func tomar_dano(quantidade: int, origem: Vector2 = Vector2.ZERO) -> void:
	if morto or quantidade <= 0:
		return
	vida = maxi(vida - quantidade, 0)
	if vida == 0:
		morrer()
	else:
		estado = Estado.FERIDO
		if origem != Vector2.ZERO:
			velocity.x = 90.0 if global_position.x >= origem.x else -90.0
		else:
			velocity.x = 0.0
		if sprite.sprite_frames.has_animation("hurt"):
			sprite.play("hurt")
		else:
			estado = Estado.PARADO


func morrer() -> void:
	if morto:
		return
	morto = true
	estado = Estado.MORTO
	velocity = Vector2.ZERO
	# Nao bloquear nem acertar o jogador enquanto morre.
	collision_layer = 0
	collision_mask = 0
	detection_area.set_deferred("monitoring", false)
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		queue_free()


func _on_animated_sprite_2d_animation_finished() -> void:
	if estado == Estado.MORTO and sprite.animation == "death":
		queue_free()
	elif estado == Estado.ATACANDO and sprite.animation == "attack":
		estado = Estado.PARADO
		_animar_movimento()
	elif estado == Estado.FERIDO and sprite.animation == "hurt":
		estado = Estado.PARADO
		_animar_movimento()
