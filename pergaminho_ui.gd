
extends CanvasLayer

@onready var painel: Control = $Painel
@onready var titulo_label: Label = $Painel/Titulo
@onready var texto_label: RichTextLabel = $Painel/TextoEducativo
@onready var instrucao_label: Label = $Painel/InstrucaoFechar

var pode_fechar := false


func _ready() -> void:
	# A interface continua funcionando mesmo com o jogo pausado.
	process_mode = Node.PROCESS_MODE_ALWAYS

	painel.visible = true
	instrucao_label.text = "Pressione E ou Y/△ para continuar"

	# Pequeno atraso para evitar fechar a interface
	# com a mesma tecla que possa ter sido usada antes.
	await get_tree().create_timer(0.2).timeout
	pode_fechar = true


func configurar(novo_titulo: String, novo_conteudo: String) -> void:
	titulo_label.text = novo_titulo
	texto_label.text = novo_conteudo


func _input(event: InputEvent) -> void:
	if not pode_fechar:
		return

	if InputMap.has_action("fechar_pergaminho"):
		if event.is_action_pressed("fechar_pergaminho") and not event.is_echo():
			fechar_pergaminho()
			get_viewport().set_input_as_handled()


func fechar_pergaminho() -> void:
	# Retoma o jogo antes de remover a interface.
	get_tree().paused = false
	queue_free()
