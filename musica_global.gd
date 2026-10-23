
extends Node

var musica: AudioStreamPlayer

var lista_musicas: Array[AudioStream] = [
	preload("res://Músicas/bg_music.ogg"),
	preload("res://Músicas/bg_music2.ogg"),
	preload("res://Músicas/bg_music3.ogg"),
	preload("res://Músicas/bg_music4.ogg"),
	preload("res://Músicas/bg_music5.ogg"),
]

var indice_musica: int = 0


func _ready() -> void:
	musica = AudioStreamPlayer.new()
	musica.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"

	add_child(musica)

	# Detecta quando a música termina
	musica.finished.connect(_ao_terminar_musica)

	tocar_proxima()


func _process(_delta: float) -> void:
	# Avança a música ao pressionar o botão configurado
	if Input.is_action_just_pressed("next_music"):
		proxima_musica()


func tocar_proxima() -> void:
	if lista_musicas.is_empty():
		return

	musica.stream = lista_musicas[indice_musica]

	# Desativa o loop individual para passar à próxima música
	if musica.stream is AudioStreamOggVorbis:
		(musica.stream as AudioStreamOggVorbis).loop = false

	musica.play()


func proxima_musica() -> void:
	if lista_musicas.is_empty():
		return

	indice_musica = (indice_musica + 1) % lista_musicas.size()
	tocar_proxima()


func _ao_terminar_musica() -> void:
	proxima_musica()


func tocar() -> void:
	if not musica.playing:
		musica.play()


func parar() -> void:
	musica.stop()


func pausar() -> void:
	musica.stream_paused = true


func continuar() -> void:
	musica.stream_paused = false


func definir_volume(volume_db: float) -> void:
	musica.volume_db = clampf(volume_db, -80.0, 12.0)
