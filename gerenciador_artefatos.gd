
extends Node
class_name GerenciadorArtefatos

# THE DESERT CHALLENGE
# TEST MODE: all five artifacts count as collected.
#
# Set to false after testing to restore normal gameplay.
const MODO_TESTE_CINCO_ARTEFATOS: bool = true

static var coletados: Array[String] = []

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

const PRESSAGIOS: Dictionary = {
	"escaravelho": (
		"Algo parece diferente.\n\n"
		+ "Quando você guarda o escaravelho, uma vibração "
		+ "percorre a pedra sob seus pés. Dura menos de um "
		+ "segundo. Talvez você tenha imaginado."
	),
	"calice": (
		"O silêncio parece pesado demais.\n\n"
		+ "O cálice está inexplicavelmente frio. Em algum "
		+ "lugar muito abaixo das ruínas, você sente que "
		+ "algo deixou de resistir."
	),
	"ankh": (
		"Três relíquias. Três sensações estranhas.\n\n"
		+ "Você começa a suspeitar que essas peças não "
		+ "foram escondidas para impedir que alguém as "
		+ "encontrasse. Talvez devessem permanecer onde estavam."
	),
	"mascara": (
		"Por um instante, você tem a sensação de estar "
		+ "sendo observado.\n\n"
		+ "Já não parece uma aventura em busca de tesouros. "
		+ "Você pensa em deixar a última relíquia para trás... "
		+ "mas continua."
	),
	"lapislazulidofarao": (
		"Você ainda se lembra do Necromancer.\n\n"
		+ "A escuridão se espalhou pelo corpo dele, "
		+ "devorou sua forma e o fez desaparecer. "
		+ "Não houve grito. Nem corpo. Apenas o vazio.\n\n"
		+ "Agora, o lápis-lazúli pulsa em sua mão. "
		+ "As outras quatro relíquias respondem, uma após a outra.\n\n"
		+ "Você reuniu as cinco.\n\n"
		+ "Mas já não tem certeza de que elas foram "
		+ "feitas para abrir alguma coisa.\n\n"
		+ "Talvez tenham sido feitas para mantê-la fechada."
	)
}

# Original visual registration API.
static var sprite_frames_artefatos: SpriteFrames = null
static var escala_visual_artefato: Vector2 = Vector2.ONE
static var offset_visual_artefato: Vector2 = Vector2.ZERO
static var visual_centered: bool = true

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


static func coletar_artefato(tipo: String) -> void:
	if tipo not in TODOS:
		push_warning("Artefato invalido: " + tipo)
		return

	if tipo in coletados:
		return

	coletados.append(tipo)

	print("[ARTEFATOS] Coletado: ", tipo)
	print(
		"[ARTEFATOS] Progresso: ",
		quantidade_coletada(),
		"/",
		TODOS.size()
	)


static func possui_artefato(tipo: String) -> bool:
	if MODO_TESTE_CINCO_ARTEFATOS:
		return tipo in TODOS

	return tipo in coletados


static func tem_todos_artefatos() -> bool:
	if MODO_TESTE_CINCO_ARTEFATOS:
		return true

	for tipo in TODOS:
		if tipo not in coletados:
			return false

	return true


static func quantidade_coletada() -> int:
	if MODO_TESTE_CINCO_ARTEFATOS:
		return TODOS.size()

	return coletados.size()


static func artefatos_faltando() -> Array[String]:
	var faltando: Array[String] = []

	if MODO_TESTE_CINCO_ARTEFATOS:
		return faltando

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
		if MODO_TESTE_CINCO_ARTEFATOS:
			return "lapislazulidofarao"

		return ""

	return coletados[coletados.size() - 1]


static func marcar_pressagio_lido(tipo: String) -> void:
	if tipo in TODOS and tipo not in pressagios_lidos:
		pressagios_lidos.append(tipo)


static func registrar_abertura_portao() -> void:
	if not tem_todos_artefatos():
		push_warning(
			"[ARTEFATOS] Portao aberto sem as cinco reliquias."
		)
		return

	portao_aberto = true
	selo_rompido = true

	print(
		"[ARTEFATOS] O selo foi rompido. "
		+ "As cinco relíquias libertaram a passagem... "
		+ "e algo que dormia além dela."
	)


static func limpar_artefatos() -> void:
	coletados.clear()
	pressagios_lidos.clear()

	portao_aberto = false
	selo_rompido = false

	print("[ARTEFATOS] Progresso resetado.")
