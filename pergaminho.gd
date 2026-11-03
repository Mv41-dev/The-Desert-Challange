
extends Area2D

@export_group("Tamanho do Pergaminho")
@export_range(0.5, 0.95, 0.01) var largura_tela: float = 0.86
@export_range(0.3, 0.85, 0.01) var altura_tela: float = 0.58
@export_range(0.0, 1.0, 0.01) var escurecimento: float = 0.60

@export_group("Texto")
@export var letras_por_segundo: float = 38.0

@onready var sprite_original: AnimatedSprite2D = $AnimatedSprite2D
@onready var colisao: CollisionShape2D = $CollisionShape2D

enum Estado {
	ABRINDO,
	ESCREVENDO,
	PRONTO,
	FECHANDO
}

var estado: Estado = Estado.ABRINDO
var artefato_id: String = ""

var pausa_anterior: bool = false
var pausa_aplicada: bool = false

var camada: CanvasLayer
var raiz_ui: Control
var fundo: ColorRect
var sprite_tela: AnimatedSprite2D
var texto: RichTextLabel
var aviso: Label

var tempo_letras: float = 0.0
var total_letras: int = 0

const DADOS: Dictionary = {
	"escaravelho": {
		"titulo": "Escaravelho de Khepri",
		"descricao": "No Egito Antigo, escaravelhos eram usados como amuletos de proteção e renascimento. Khepri, deus associado ao sol nascente, simbolizava a renovação diária da vida.",
		"dica": "* Talvez este símbolo abra algo esquecido nas areias..."
	},

	"calice": {
		"titulo": "Cálice de Lótus",
		"descricao": "Encontrado na tumba de Tutancâmon, o Cálice de Lótus é um objeto de alabastro. A flor de lótus representava o renascimento e a renovação da vida no Egito Antigo.",
		"dica": "* Talvez este cálice tenha outra finalidade..."
	},

	"ankh": {
		"titulo": "Ankh da Vida",
		"descricao": "O Ankh era um dos principais símbolos do Egito Antigo. Representava a vida e aparecia frequentemente nas mãos dos deuses em pinturas e relevos religiosos.",
		"dica": "* Uma antiga porta talvez reconheça este símbolo..."
	},

	"mascara": {
		"titulo": "Máscara Funerária",
		"descricao": "Máscaras funerárias cobriam os rostos de algumas múmias egípcias. Estavam associadas à identidade do falecido e às crenças sobre a vida após a morte.",
		"dica": "* Talvez os mortos ainda guardem algum segredo..."
	},

	"lapislazulidofarao": {
		"titulo": "Lápis-Lazúli dos Faraós",
		"descricao": "O lápis-lazúli era uma pedra muito valorizada pelos egípcios. Importada de regiões distantes, era usada em joias, amuletos e objetos religiosos.",
		"dica": "* Esta parece ser a última peça de algo maior..."
	}
}


func configurar_por_artefato(id: String) -> void:
	artefato_id = id


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Impede que o pergaminho abra sozinho.
	if artefato_id.is_empty():
		queue_free()
		return

	# Sem hitbox durante toda a interface.
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

	if colisao:
		colisao.set_deferred("disabled", true)

	sprite_original.hide()

	if not _criar_interface():
		queue_free()
		return

	pausa_anterior = get_tree().paused
	pausa_aplicada = true
	get_tree().paused = true

	estado = Estado.ABRINDO
	sprite_tela.play("abrindo")


func _criar_interface() -> bool:
	var tamanho_tela: Vector2 = get_viewport_rect().size
	var centro: Vector2 = tamanho_tela * 0.5

	camada = CanvasLayer.new()
	camada.layer = 100
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)

	raiz_ui = Control.new()
	raiz_ui.size = tamanho_tela
	raiz_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(raiz_ui)

	# Escurecimento do fundo.
	fundo = ColorRect.new()
	fundo.size = tamanho_tela
	fundo.color = Color(
		0.02, 0.015, 0.03, 0.0
	)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz_ui.add_child(fundo)

	var fade_fundo: Tween = create_tween()
	fade_fundo.tween_property(
		fundo,
		"color:a",
		escurecimento,
		0.35
	)

	# Sprite do pergaminho.
	if not sprite_original.sprite_frames.has_animation(
		"abrindo"
	):
		push_error("Animacao 'abrindo' nao encontrada!")
		return false

	var frames: SpriteFrames = (
		sprite_original.sprite_frames.duplicate(true)
		as SpriteFrames
	)

	frames.set_animation_loop("abrindo", false)

	var ultimo_frame: int = (
		frames.get_frame_count("abrindo") - 1
	)

	if ultimo_frame < 0:
		return false

	var textura: Texture2D = (
		frames.get_frame_texture(
			"abrindo", ultimo_frame
		)
	)

	if textura == null:
		return false

	sprite_tela = AnimatedSprite2D.new()
	sprite_tela.sprite_frames = frames
	sprite_tela.animation = "abrindo"
	sprite_tela.centered = true
	sprite_tela.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	raiz_ui.add_child(sprite_tela)

	# Mede somente os pixels visiveis.
	# Isso evita que margens transparentes
	# diminuam o tamanho do pergaminho.
	var tamanho_textura: Vector2 = textura.get_size()

	var area_visivel: Rect2i = Rect2i(
		Vector2i.ZERO,
		Vector2i(tamanho_textura)
	)

	var imagem: Image = textura.get_image()

	if imagem != null:
		var area_usada: Rect2i = imagem.get_used_rect()

		if area_usada.size.x > 0 and area_usada.size.y > 0:
			area_visivel = area_usada

	var tamanho_visivel: Vector2 = Vector2(
		area_visivel.size
	)

	# Tamanho REAL desejado na tela.
	var largura_final: float = (
		tamanho_tela.x * largura_tela
	)

	var altura_final: float = (
		tamanho_tela.y * altura_tela
	)

	# Escala horizontal e vertical separadas.
	# Permite um pergaminho largo e alto,
	# com espaco suficiente para o texto.
	sprite_tela.scale = Vector2(
		largura_final / maxf(tamanho_visivel.x, 1.0),
		altura_final / maxf(tamanho_visivel.y, 1.0)
	)

	# Centraliza a ARTE visivel, nao as
	# margens transparentes da textura.
	var centro_visivel: Vector2 = (
		Vector2(area_visivel.position)
		+ tamanho_visivel * 0.5
	)

	var deslocamento: Vector2 = (
		centro_visivel
		- tamanho_textura * 0.5
	)

	sprite_tela.position = (
		centro - deslocamento * sprite_tela.scale
	)

	# Texto dentro da parte central de papel.
	texto = RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.scroll_active = false
	texto.fit_content = false
	texto.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Margens deixam os rolos laterais livres.
	texto.size = Vector2(
		largura_final * 0.64,
		altura_final * 0.66
	)

	texto.position = Vector2(
		centro.x - texto.size.x * 0.5,
		centro.y - texto.size.y * 0.5
	)

	texto.add_theme_color_override(
		"default_color",
		Color(0.19, 0.12, 0.075)
	)

	raiz_ui.add_child(texto)

	_configurar_texto()

	texto.visible_characters = 0
	texto.hide()

	# Instrucao fora do pergaminho.
	aviso = Label.new()
	aviso.text = (
		"E / ENTER / ESPAÇO ou clique para fechar"
	)

	aviso.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	aviso.size = Vector2(
		tamanho_tela.x * 0.85,
		30.0
	)

	aviso.position = Vector2(
		centro.x - aviso.size.x * 0.5,
		centro.y + altura_final * 0.5 + 15.0
	)

	aviso.add_theme_font_size_override(
		"font_size", 16
	)

	aviso.add_theme_color_override(
		"font_color",
		Color(0.96, 0.88, 0.70)
	)

	raiz_ui.add_child(aviso)
	aviso.hide()

	sprite_tela.animation_finished.connect(
		_ao_terminar_animacao
	)

	return true


func _configurar_texto() -> void:
	var dados: Dictionary = DADOS.get(
		artefato_id, {}
	)

	var titulo: String = str(
		dados.get("titulo", "Relíquia Misteriosa")
	)

	var descricao: String = str(
		dados.get(
			"descricao",
			"Uma antiga relíquia do deserto."
		)
	)

	var dica: String = str(
		dados.get(
			"dica",
			"* Talvez possa ser usada em algum lugar..."
		)
	)

	# Titulo, texto historico e segredo.
	texto.text = (
		"[center]"
		+ "[font_size=23][b]"
		+ titulo
		+ "[/b][/font_size]\n\n"
		+ "[font_size=17]"
		+ descricao
		+ "[/font_size]\n\n"
		+ "[font_size=15][i]"
		+ dica
		+ "[/i][/font_size]"
		+ "[/center]"
	)

	total_letras = texto.get_total_character_count()


func _ao_terminar_animacao() -> void:
	match estado:
		Estado.ABRINDO:
			# Para no ultimo frame.
			sprite_tela.stop()

			sprite_tela.frame = (
				sprite_tela.sprite_frames.get_frame_count(
					"abrindo"
				) - 1
			)

			texto.show()
			texto.visible_characters = 0

			tempo_letras = 0.0
			estado = Estado.ESCREVENDO

		Estado.FECHANDO:
			_encerrar()


func _process(delta: float) -> void:
	if estado != Estado.ESCREVENDO:
		return

	tempo_letras += (
		delta * letras_por_segundo
	)

	var quantidade: int = int(tempo_letras)

	if quantidade > 0:
		tempo_letras -= float(quantidade)

		texto.visible_characters = mini(
			texto.visible_characters + quantidade,
			total_letras
		)

	if texto.visible_characters >= total_letras:
		estado = Estado.PRONTO
		aviso.show()


func _input(event: InputEvent) -> void:
	if estado != Estado.ESCREVENDO \
	and estado != Estado.PRONTO:
		return

	var confirmar: bool = false

	if event is InputEventKey:
		if event.pressed and not event.echo:
			confirmar = event.keycode in [
				KEY_E,
				KEY_ENTER,
				KEY_KP_ENTER,
				KEY_SPACE
			]

	elif event is InputEventMouseButton:
		if event.pressed:
			confirmar = (
				event.button_index == MOUSE_BUTTON_LEFT
			)

	if not confirmar:
		return

	get_viewport().set_input_as_handled()

	# Primeiro aperto: completa o texto.
	if estado == Estado.ESCREVENDO:
		texto.visible_characters = total_letras
		estado = Estado.PRONTO
		aviso.show()
		return

	# Segundo aperto: fecha o pergaminho.
	if estado == Estado.PRONTO:
		_fechar_pergaminho()


func _fechar_pergaminho() -> void:
	if estado != Estado.PRONTO:
		return

	estado = Estado.FECHANDO

	texto.hide()
	aviso.hide()

	# Fade out do fundo.
	var fade_fundo: Tween = create_tween()
	fade_fundo.tween_property(
		fundo,
		"color:a",
		0.0,
		0.35
	)

	# Abertura ao contrario = fechamento.
	sprite_tela.play_backwards("abrindo")


func _encerrar() -> void:
	if pausa_aplicada:
		get_tree().paused = pausa_anterior
		pausa_aplicada = false

	queue_free()


func _exit_tree() -> void:
	if pausa_aplicada:
		get_tree().paused = pausa_anterior
		pausa_aplicada = false
