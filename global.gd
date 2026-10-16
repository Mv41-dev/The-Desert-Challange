extends Node

# Fonte unica da vida: o valor acompanha o jogador ao trocar de fase.
signal vida_alterada(nova_vida: int)
signal jogador_morreu

var vida_maxima: int = 3
var vida_atual: int = 3


func configurar_vida_maxima(valor: int) -> void:
	vida_maxima = maxi(valor, 1)
	vida_atual = clampi(vida_atual, 0, vida_maxima)
	vida_alterada.emit(vida_atual)


func reiniciar_vida() -> void:
	vida_atual = vida_maxima
	vida_alterada.emit(vida_atual)


func tomar_dano(quantidade: int) -> void:
	if quantidade <= 0 or vida_atual <= 0:
		return
	var vida_anterior: int = vida_atual
	vida_atual = maxi(vida_atual - quantidade, 0)
	if vida_atual != vida_anterior:
		vida_alterada.emit(vida_atual)
	if vida_atual == 0:
		jogador_morreu.emit()


func curar(quantidade: int) -> void:
	if quantidade <= 0 or vida_atual <= 0:
		return
	vida_atual = mini(vida_atual + quantidade, vida_maxima)
	vida_alterada.emit(vida_atual)
