extends Node
class_name GerenciadorArtefatos

# Os identificadores abaixo sao os mesmos usados pelos sprites,
# pelo portao e pelo coletavel original.
static var coletados: Array[String] = []

const MODO_TESTE_CINCO_ARTEFATOS: bool = false
const ARTEFATO_DA_FASE: Dictionary = {
	1: "escaravelho",
	2: "calice",
	3: "ankh",
	4: "mascara",
	5: "lapislazulidofarao"
}

const TODOS: Array[String] = [
	"escaravelho",
	"lapislazulidofarao",
	"mascara",
	"ankh",
	"calice"
]

const NOMES: Dictionary = {
	"escaravelho": "Escaravelho Sagrado",
	"lapislazulidofarao": "Lápis-Lazúli do Faraó",
	"mascara": "Máscara do Guardião",
	"ankh": "Ankh da Vida",
	"calice": "Cálice Cerimonial"
}

# Ficam numa SEGUNDA PAGINA do pergaminho.
# O texto educativo original permanece intacto.
# Nao sao fatos historicos: sao sensacoes do personagem.
const PRESSAGIOS: Dictionary = {
	"escaravelho": (
		"Algo parece diferente.\n\n"
		+ "Quando você guarda o escaravelho, uma vibração percorre a pedra sob seus pés. "
		+ "Dura menos de um segundo. Talvez você tenha imaginado."
	),
	"calice": (
		"O silêncio parece pesado demais.\n\n"
		+ "O cálice está inexplicavelmente frio. Em algum lugar muito abaixo das ruínas, "
		+ "você sente que algo deixou de resistir."
	),
	"ankh": (
		"Três relíquias. Três sensações estranhas.\n\n"
		+ "Você começa a suspeitar que essas peças não foram escondidas para impedir "
		+ "que alguém as encontrasse. Talvez devessem permanecer onde estavam."
	),
	"mascara": (
		"Por um instante, você tem a sensação de estar sendo observado.\n\n"
		+ "Já não parece uma aventura em busca de tesouros. "
		+ "Você pensa em deixar a última relíquia para trás... mas continua."
	),
	"lapislazulidofarao": (
		"A última pedra pulsa na sua mão.\n\n"
		+ "As outras quatro parecem responder. Então, tudo fica estranhamente quieto.\n\n"
		+ "Você deveria ter parado antes de reunir as cinco."
	)
}

# API original usada pelo ritual para mostrar as animacoes das reliquias.
static var sprite_frames_artefatos: SpriteFrames = null
static var escala_visual_artefato: Vector2 = Vector2.ONE
static var offset_visual_artefato: Vector2 = Vector2.ZERO
static var visual_centered: bool = true

# Estado da historia entre as cenas.
static var portao_aberto: bool = false
static var selo_rompido: bool = false
static var pressagios_lidos: Array[String] = []

static func registrar_visual_artefatos(
	frames: SpriteFrames,
	escala: Vector2,
	centered: bool,
	offset: Vector2
) -> void:
	if frames == null:
		return
	sprite_frames_artefatos = frames
	escala_visual_artefato = escala
	visual_centered = centered
	offset_visual_artefato = offset


static func _numero_fase_atual() -> int:
	var loop: MainLoop = Engine.get_main_loop()
	if not loop is SceneTree:
		return 0
	var cena: Node = (loop as SceneTree).current_scene
	if not is_instance_valid(cena):
		return 0
	var nome: String = cena.scene_file_path.get_file().get_basename().to_lower().replace("_", "")
	if nome.is_empty():
		nome = cena.name.to_lower().replace("_", "")
	for numero: int in range(1, 6):
		if nome == "level" + str(numero):
			return numero
	return 0

static func coletar_artefato(tipo: String) -> void:
	if tipo not in TODOS:
		push_warning("Artefato invalido: " + tipo)
		return
	var fase: int = _numero_fase_atual()
	if fase in ARTEFATO_DA_FASE and ARTEFATO_DA_FASE[fase] != tipo:
		push_warning("[ARTEFATOS] A fase " + str(fase) + " nao entrega: " + tipo)
		return
	if tipo in coletados:
		return
	coletados.append(tipo)
	print("[ARTEFATOS] Coletado: ", tipo)
	print("[ARTEFATOS] Progresso: ", coletados.size(), "/", TODOS.size())
	print("[ARTEFATOS] Atualmente: ", coletados)

static func possui_artefato(tipo: String) -> bool:
	return tipo in coletados

static func tem_todos_artefatos() -> bool:
	for tipo in TODOS:
		if tipo not in coletados:
			return false
	return true

static func quantidade_coletada() -> int:
	return coletados.size()

static func artefatos_faltando() -> Array[String]:
	var faltando: Array[String] = []
	for tipo in TODOS:
		if tipo not in coletados:
			faltando.append(tipo)
	return faltando

static func nome_artefato(tipo: String) -> String:
	return str(NOMES.get(tipo, tipo))

static func pressagio_artefato(tipo: String) -> String:
	return str(PRESSAGIOS.get(tipo, ""))

static func ultimo_artefato_coletado() -> String:
	if coletados.is_empty():
		return ""
	return coletados[coletados.size() - 1]

static func marcar_pressagio_lido(tipo: String) -> void:
	if tipo in TODOS and tipo not in pressagios_lidos:
		pressagios_lidos.append(tipo)

static func registrar_abertura_portao() -> void:
	if not tem_todos_artefatos():
		push_warning("[ARTEFATOS] Portao aberto sem as cinco reliquias.")
		return
	portao_aberto = true
	selo_rompido = true
	print("[ARTEFATOS] O selo foi rompido. Algo desperta sob a piramide.")

static func limpar_artefatos() -> void:
	coletados.clear()
	pressagios_lidos.clear()
	portao_aberto = false
	selo_rompido = false
	print("[ARTEFATOS] Progresso resetado.")
