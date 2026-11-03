extends Node
class_name GerenciadorArtefatos

static var coletados: Array[String] = []

const TODOS = [
	"escaravelho",
	"lapislazulidofarao",
	"mascara",
	"ankh",
	"calice"
]

static func coletar_artefato(tipo: String) -> void:
	if tipo in TODOS and tipo not in coletados:
		coletados.append(tipo)

static func possui_artefato(tipo: String) -> bool:
	return tipo in coletados

static func tem_todos_artefatos() -> bool:
	for tipo in TODOS:
		if tipo not in coletados:
			return false
	return true
