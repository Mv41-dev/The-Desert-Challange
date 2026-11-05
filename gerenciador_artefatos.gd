extends Node
class_name GerenciadorArtefatos


# =====================================================
# ARTEFATOS COLETADOS
# =====================================================

static var coletados: Array[String] = []


# =====================================================
# TODOS OS ARTEFATOS NECESSARIOS
# =====================================================

const TODOS: Array[String] = [
	"escaravelho",
	"lapislazulidofarao",
	"mascara",
	"ankh",
	"calice"
]


# =====================================================
# NOMES EXIBIDOS
# =====================================================

const NOMES: Dictionary = {
	"escaravelho": "Escaravelho Sagrado",
	"lapislazulidofarao": "Lápis-Lazúli do Faraó",
	"mascara": "Máscara do Guardião",
	"ankh": "Ankh da Vida",
	"calice": "Cálice Cerimonial"
}


# =====================================================
# DADOS VISUAIS
#
# Usados pelo ritual do portao.
# O artefato coletavel registra seus SpriteFrames aqui.
# =====================================================

static var sprite_frames_artefatos: SpriteFrames = null

static var escala_visual_artefato: Vector2 = Vector2.ONE

static var offset_visual_artefato: Vector2 = Vector2.ZERO

static var visual_centered: bool = true


# =====================================================
# REGISTRAR VISUAL
# =====================================================

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


# =====================================================
# COLETAR ARTEFATO
# =====================================================

static func coletar_artefato(
	tipo: String
) -> void:
	# Ignora qualquer nome invalido.
	if tipo not in TODOS:
		push_warning(
			"Artefato invalido: "
			+ tipo
		)

		return


	# Nao duplica artefatos.
	if tipo in coletados:
		return


	coletados.append(
		tipo
	)


	print(
		"[ARTEFATOS] Coletado: ",
		tipo
	)


	print(
		"[ARTEFATOS] Progresso: ",
		coletados.size(),
		"/",
		TODOS.size()
	)


	print(
		"[ARTEFATOS] Atualmente: ",
		coletados
	)


# =====================================================
# POSSUI ARTEFATO
# =====================================================

static func possui_artefato(
	tipo: String
) -> bool:
	return tipo in coletados


# =====================================================
# POSSUI TODOS
# =====================================================

static func tem_todos_artefatos() -> bool:
	for tipo in TODOS:
		if tipo not in coletados:
			return false

	return true


# =====================================================
# QUANTIDADE COLETADA
# =====================================================

static func quantidade_coletada() -> int:
	return coletados.size()


# =====================================================
# ARTEFATOS FALTANDO
# =====================================================

static func artefatos_faltando() -> Array[String]:
	var faltando: Array[String] = []


	for tipo in TODOS:
		if tipo not in coletados:
			faltando.append(
				tipo
			)


	return faltando


# =====================================================
# NOME BONITO DO ARTEFATO
# =====================================================

static func nome_artefato(
	tipo: String
) -> String:
	return str(
		NOMES.get(
			tipo,
			tipo
		)
	)


# =====================================================
# RESET
#
# Use somente se quiser iniciar uma campanha nova
# ou resetar o progresso dos artefatos.
# =====================================================

static func limpar_artefatos() -> void:
	coletados.clear()


	print(
		"[ARTEFATOS] Progresso resetado."
	)
