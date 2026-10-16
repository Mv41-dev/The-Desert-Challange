extends Node2D

@export_file("*.tscn") var next_scene_path: String = "res://level_1.tscn"
@onready var progress_bar: ProgressBar = $ProgressBar
var _progress: Array[float] = []
var _finished: bool = false


func _ready() -> void:
	if not ResourceLoader.exists(next_scene_path):
		push_error("Carregamento: cena não encontrada: " + next_scene_path)
		set_process(false)
		return
	var resultado: Error = ResourceLoader.load_threaded_request(next_scene_path)
	if resultado != OK:
		push_error("Carregamento: erro ao iniciar leitura da cena.")
		set_process(false)


func _process(_delta: float) -> void:
	if _finished:
		return
	match ResourceLoader.load_threaded_get_status(next_scene_path, _progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not _progress.is_empty():
				progress_bar.value = 100.0 * _progress[0]
		ResourceLoader.THREAD_LOAD_LOADED:
			_finished = true
			progress_bar.value = 100.0
			var cena: PackedScene = ResourceLoader.load_threaded_get(next_scene_path) as PackedScene
			if cena != null:
				get_tree().change_scene_to_packed.call_deferred(cena)
			else:
				push_error("Carregamento: recurso não é uma cena válida.")
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_finished = true
			push_error("Carregamento: falha ao carregar " + next_scene_path)
