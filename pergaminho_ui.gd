extends CanvasLayer

@onready var painel: Control = $Painel
@onready var titulo_label: Label = $Painel/Titulo
@onready var texto_label: RichTextLabel = $Painel/TextoEducativo
@onready var instrucao_label: Label = $Painel/InstrucaoFechar

var pode_fechar: bool = false
var pagina_pressagio: bool = false
var tipo_do_artefato: String = ""
var conteudo_educativo: String = ""
var _ja_finalizando: bool = false

func _ready() -> void:
	# Mantem a pagina original e todas as suas referencias.
	process_mode = Node.PROCESS_MODE_ALWAYS
	painel.visible = true
	instrucao_label.text = "Pressione E ou Y/△ para continuar"
	await get_tree().create_timer(0.2, true).timeout
	if is_inside_tree():
		pode_fechar = true

func configurar(novo_titulo: String, novo_conteudo: String) -> void:
	# A historia educativa nao e apagada, resumida nem substituida.
	titulo_label.text = novo_titulo
	conteudo_educativo = novo_conteudo
	texto_label.text = conteudo_educativo
	pagina_pressagio = false
	tipo_do_artefato = _descobrir_tipo(novo_titulo)
	instrucao_label.text = "Pressione E ou Y/△ para continuar"

func _descobrir_tipo(titulo: String) -> String:
	# Preferencia ao nome do pergaminho; o ultimo coletado e
	# fallback caso o titulo use uma variacao abreviada.
	var titulo_minusculo: String = titulo.to_lower()
	for tipo: String in GerenciadorArtefatos.TODOS:
		var nome: String = GerenciadorArtefatos.nome_artefato(tipo).to_lower()
		if titulo_minusculo.contains(nome) or titulo_minusculo.contains(tipo):
			return tipo
	return GerenciadorArtefatos.ultimo_artefato_coletado()

func _input(event: InputEvent) -> void:
	if not pode_fechar or _ja_finalizando:
		return
	if not InputMap.has_action("fechar_pergaminho"):
		return
	if not event.is_action_pressed("fechar_pergaminho"):
		return
	if event is InputEventKey and (event as InputEventKey).is_echo():
		return
	pode_fechar = false
	get_viewport().set_input_as_handled()
	fechar_pergaminho()

func fechar_pergaminho() -> void:
	if _ja_finalizando:
		return

	# Na primeira confirmacao, mostra o pressagio na MESMA interface.
	# O conteudo educativo original ja foi apresentado por completo.
	if not pagina_pressagio:
		var aviso: String = GerenciadorArtefatos.pressagio_artefato(tipo_do_artefato)
		if not aviso.is_empty():
			pagina_pressagio = true
			titulo_label.text = "..."
			texto_label.text = aviso
			texto_label.scroll_to_line(0)
			instrucao_label.text = "Pressione E ou Y/△ para fechar"
			# Impede que o mesmo aperto pule as duas paginas.
			await get_tree().create_timer(0.25, true).timeout
			if is_inside_tree():
				pode_fechar = true
			return

	_ja_finalizando = true
	if pagina_pressagio:
		GerenciadorArtefatos.marcar_pressagio_lido(tipo_do_artefato)
	get_tree().paused = false
	queue_free()
