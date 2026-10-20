extends CharacterBody2D

# J = golpe leve/rapido; K = golpe pesado/alcance maior.
# Edite os quadros no AnimatedSprite2D da cena Player.tscn.
signal vida_alterada(vida_atual: int, vida_maxima: int)

enum Estado { NORMAL, ATAQUE, FERIDO, MORTO }
enum TipoGolpe { LEVE, FORTE }

const SPEED: float = 200.0
const JUMP_FORCE: float = -300.0
const GRAVITY: float = 980.0
const MAX_FALL_SPEED: float = 650.0

@export_range(1, 20, 1) var vida_maxima: int = 3
@export_range(1, 10, 1) var dano_leve: int = 1
@export_range(1, 10, 1) var dano_forte: int = 2
@export_range(0.2, 3.0, 0.05) var tempo_invulneravel: float = 0.85
@export_range(0.0, 500.0, 10.0) var forca_recuo: float = 145.0

var vida: int = 3
var estado: Estado = Estado.NORMAL
var golpe_atual: TipoGolpe = TipoGolpe.LEVE
var golpe_em_fila: int = -1
var olhando_direita: bool = true
var tempo_invulneravel_restante: float = 0.0
var atingidos_no_golpe: Array[Node2D] = []

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area_j: Area2D = $AttackAreaJ
@onready var attack_area_k: Area2D = $AttackAreaK


func _ready() -> void:
	add_to_group("player")
	Global.configurar_vida_maxima(vida_maxima)
	if Global.vida_atual <= 0:
		Global.reiniciar_vida()
	vida = Global.vida_atual
	vida_alterada.emit(vida, vida_maxima)
	attack_area_j.monitoring = true
	attack_area_k.monitoring = true
	atualizar_areas_ataque()
	anim.animation_finished.connect(_ao_terminar_animacao)
	_tocar(&"idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if tempo_invulneravel_restante > 0.0:
		tempo_invulneravel_restante = maxf(tempo_invulneravel_restante - delta, 0.0)
		anim.modulate.a = 0.4 if fmod(tempo_invulneravel_restante, 0.16) < 0.08 else 1.0
	else:
		anim.modulate.a = 1.0

	if estado == Estado.MORTO:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 3.0)
		move_and_slide()
		return

	if estado == Estado.FERIDO:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 3.0)
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE

	var direcao: float = Input.get_axis("left", "right")
	if estado == Estado.NORMAL:
		velocity.x = direcao * SPEED
		if absf(direcao) > 0.01:
			_virar(direcao)
	else:
		# Durante o ataque o personagem não patina no solo.
		velocity.x = direcao * (SPEED * 0.30 if golpe_atual == TipoGolpe.LEVE else 0.0)

	if Input.is_action_just_pressed("attack_quick"):
		solicitar_ataque(TipoGolpe.LEVE)
	elif Input.is_action_just_pressed("attack_heavy"):
		solicitar_ataque(TipoGolpe.FORTE)

	move_and_slide()

	if estado == Estado.ATAQUE:
		_verificar_acertos()
	elif estado == Estado.NORMAL:
		_atualizar_animacao_movimento(direcao)


func _virar(direcao: float) -> void:
	olhando_direita = direcao > 0.0
	anim.flip_h = not olhando_direita
	atualizar_areas_ataque()


func atualizar_areas_ataque() -> void:
	# Em cada lado as caixas ficam a frente da espada, sem acertar pelas costas.
	attack_area_j.position = Vector2(29.0 if olhando_direita else -11.0, 14.0)
	attack_area_k.position = Vector2(37.0 if olhando_direita else -19.0, 13.0)


func _atualizar_animacao_movimento(direcao: float) -> void:
	if not is_on_floor():
		_tocar(&"jump" if velocity.y < 0.0 else &"fall")
	elif absf(direcao) > 0.01:
		_tocar(&"run")
	else:
		_tocar(&"idle")


func _tocar(nome: StringName) -> void:
	if anim.sprite_frames.has_animation(nome) and (anim.animation != nome or not anim.is_playing()):
		anim.play(nome)


func solicitar_ataque(tipo: TipoGolpe) -> void:
	if estado == Estado.NORMAL:
		_iniciar_ataque(tipo)
	elif estado == Estado.ATAQUE and anim.frame >= 2:
		# Permite a sequência J -> K / K -> J, sem interromper o golpe atual.
		golpe_em_fila = int(tipo)


func _iniciar_ataque(tipo: TipoGolpe) -> void:
	estado = Estado.ATAQUE
	golpe_atual = tipo
	golpe_em_fila = -1
	atingidos_no_golpe.clear()
	atualizar_areas_ataque()
	anim.play(&"attack_quick" if tipo == TipoGolpe.LEVE else &"attack_heavy")


func _verificar_acertos() -> void:
	var frame: int = anim.frame
	var ativo: bool = false
	var area: Area2D = attack_area_j
	var dano: int = dano_leve

	if golpe_atual == TipoGolpe.LEVE:
		ativo = frame >= 2 and frame <= 3
	else:
		ativo = frame >= 3 and frame <= 5
		area = attack_area_k
		dano = dano_forte

	if not ativo:
		return

	for corpo in area.get_overlapping_bodies():
		if not is_instance_valid(corpo) or not corpo.is_in_group("inimigo"):
			continue
		if corpo.has_method("tomar_dano") and not atingidos_no_golpe.has(corpo):
			atingidos_no_golpe.append(corpo)
			corpo.tomar_dano(dano, global_position)


func tomar_dano(quantidade: int, origem: Vector2 = Vector2.ZERO) -> void:
	if quantidade <= 0 or estado == Estado.MORTO or tempo_invulneravel_restante > 0.0:
		return
	tempo_invulneravel_restante = tempo_invulneravel
	golpe_em_fila = -1
	Global.tomar_dano(quantidade)
	vida = Global.vida_atual
	vida_alterada.emit(vida, vida_maxima)
	if vida <= 0:
		morrer()
		return

	estado = Estado.FERIDO
	atingidos_no_golpe.clear()
	var lado: float = -1.0 if olhando_direita else 1.0
	if origem != Vector2.ZERO:
		lado = 1.0 if global_position.x >= origem.x else -1.0
	velocity.x = lado * forca_recuo
	velocity.y = minf(velocity.y, -100.0)
	anim.play(&"hurt")


func morrer() -> void:
	if estado == Estado.MORTO:
		return
	estado = Estado.MORTO
	golpe_em_fila = -1
	atingidos_no_golpe.clear()
	velocity.x = 0.0
	anim.modulate.a = 1.0
	anim.play(&"death")


func _ao_terminar_animacao() -> void:
	match estado:
		Estado.ATAQUE:
			if anim.animation == &"attack_quick" or anim.animation == &"attack_heavy":
				estado = Estado.NORMAL
				if golpe_em_fila != -1:
					var proximo: TipoGolpe = TipoGolpe.FORTE if golpe_em_fila == int(TipoGolpe.FORTE) else TipoGolpe.LEVE
					_iniciar_ataque(proximo)
		Estado.FERIDO:
			if anim.animation == &"hurt":
				estado = Estado.NORMAL
		Estado.MORTO:
			if anim.animation == &"death":
				Global.reiniciar_vida()
				get_tree().call_deferred("reload_current_scene")
