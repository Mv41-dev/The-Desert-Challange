extends Node

var musica: AudioStreamPlayer


func _ready() -> void:
	musica = AudioStreamPlayer.new()
	musica.stream = preload("res://bg_music.ogg")
	# AudioStreamOggVorbis carrega o arquivo comprimido e faz loop sem criar novos players.
	if musica.stream is AudioStreamOggVorbis:
		(musica.stream as AudioStreamOggVorbis).loop = true
	musica.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	add_child(musica)
	musica.play()


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
