
# THE DESERT CHALLENGE
# LEVEL 5 - CORRUPTED LAPIS GUARDIAN V8.1
#
# FIX V8.1:
# - Genuine FULL BLACK flash restored.
# - Flash has a guaranteed visible hold before fading.
# - Flash is above HUD and all other visual layers.
# - Black flash fades to transparent, revealing
#   the permanent darkness from AmbienciaLevel5.
#
# PRESERVED:
# - Slow visible corruption.
# - Artifact requirement.
# - Guardian spawning on the return trip.
# - Second black flash when Guardian spawns.
# - King Necro's world-anchored moving black fog.
# - Smooth fog fade-out when Guardian dies.
# - Arena barriers and death cleanup.
# - All Guardian attacks and half-heart damage.
#
# Attach to corruptionarea Area2D.
# Keep ambiencia_level5.gd and
# voidnecro_guardian.gd unchanged.

extends Area2D

signal corrupcao_iniciada
signal necromante_desapareceu
signal corrupcao_finalizada(novo_inimigo: Node2D)

const GUARDIAN_SCRIPT: Script = preload("res://voidnecro_guardian.gd")
const ID_LAPIS: String = "lapislazulidofarao"

# Well above the ambience and HUD.
const FLASH_LAYER: int = 100000
const FOG_LAYER: int = 1090
const HUD_LAYER: int = 1100

const FOG_COLUMNS: int = 7
const FOG_ROWS: int = 5
const FOG_SPACING: Vector2 = Vector2(365.0, 205.0)

const ASH_COLUMNS: int = 9
const ASH_ROWS: int = 7
const ASH_SPACING: Vector2 = Vector2(150.0, 105.0)


@export_group("Enemy Links")
@export var necromante_normal_path: NodePath
@export var cena_void_necro: PackedScene

@export_group("Return Area")
@export var return_void_spawn_path: NodePath = NodePath("../returnvoidspawn")
@export var exigir_lapis_coletado: bool = true
@export var local_spawn_override: NodePath
@export_range(0.0, 145.0, 5.0) var surgimento_acima: float = 70.0

@export_group("Corruption Cutscene")
@export_range(1.5, 8.0, 0.1) var duracao_corrupcao_visivel: float = 3.2

# Longer, clearly visible BLACK hold.
@export_range(0.20, 0.60, 0.01) var duracao_flash_preto: float = 0.25

@export_range(0.3, 2.5, 0.05) var duracao_fade_de_volta: float = 1.15
@export_range(0.0, 14.0, 0.5) var intensidade_tremor: float = 5.0
@export var bloquear_controle_durante_flash: bool = false
@export_range(3, 30, 1) var particulas_por_pulso: int = 8

@export_group("Guardian Return Flash")
@export_range(0.20, 0.60, 0.01) var segundo_flash_preto: float = 0.25
@export_range(0.3, 2.0, 0.05) var fade_retorno: float = 0.65

@export_group("King Necro Black Fog")
@export var usar_neblina_guardiao: bool = true
@export_range(0.15, 1.0, 0.01) var opacidade_neblina: float = 0.76
@export_range(0.2, 3.0, 0.05) var velocidade_neblina: float = 1.0
@export_range(0.2, 3.0, 0.05) var tempo_aparecer_neblina: float = 0.85
@export_range(0.5, 6.0, 0.1) var tempo_desaparecer_neblina: float = 2.8
@export var mostrar_cinzas_escuras: bool = true

@export_group("Void Guardian Arena Lock")
@export var arena_lock_enabled: bool = true
@export var arena_left_marker: NodePath
@export var arena_right_marker: NodePath
@export_range(100.0, 320.0, 10.0) var arena_left_clearance: float = 130.0
@export_range(280.0, 780.0, 10.0) var arena_right_clearance: float = 430.0
@export_range(350.0, 1200.0, 50.0) var arena_wall_height: float = 800.0
@export_range(8.0, 35.0, 1.0) var arena_wall_width: float = 18.0


var ativado: bool = false
var em_corrupcao: bool = false
var pronto_para_retorno: bool = false
var guardian_spawned: bool = false

var player_detectado: Node2D = null
var necro_original: CharacterBody2D = null
var _necro_parent: Node = null
var _posicao_original_necro: Vector2 = Vector2.ZERO

var _flip_original: bool = false
var _sprite_original: AnimatedSprite2D = null
var _sprite_original_position: Vector2 = Vector2.ZERO
var _sprite_original_scale: Vector2 = Vector2.ONE
var _return_area: Area2D = null

var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_tween: Tween = null

var _stored_camera: Camera2D = null
var _stored_camera_offset: Vector2 = Vector2.ZERO
var _camera_shaking: bool = false

var _corruption_elapsed: float = 0.0
var _corruption_strength: float = 0.0
var _smoke_clock: float = 0.0
var _vein_clock: float = 0.0
var _overlap_check_clock: float = 0.0

var _player_physics_was_running: bool = true
var _player_was_frozen: bool = false

var _arena_holder: Node2D = null
var _arena_left_x: float = 0.0
var _arena_right_x: float = 0.0
var _arena_player_inside: bool = false
var _arena_guardian: CharacterBody2D = null
var _arena_guardian_registered: bool = false
var _arena_guardian_defeated: bool = false
var _arena_left_wall: StaticBody2D = null
var _arena_right_wall: StaticBody2D = null

var _fog_fallback_layer: CanvasLayer = null
var _fog_root: Control = null
var _fog_panels: Array[TextureRect] = []
var _ash_panels: Array[TextureRect] = []

var _fog_power: float = 0.0
var _fog_wanted: bool = false
var _fog_time: float = 0.0

var _hud_original_layers: Dictionary = {}


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if name.to_lower() == "returnvoidspawn":
		monitoring = true
		set_process(false)
		set_physics_process(false)
		return

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_find_return_area()
	_create_flash_layer()

	set_process(false)
	set_physics_process(true)

	print("CORRUPTION V8.1: full black flash ready.")


func _find_return_area() -> void:
	if not return_void_spawn_path.is_empty():
		_return_area = get_node_or_null(
			return_void_spawn_path
		) as Area2D

	if _return_area == null and get_parent() != null:
		_return_area = get_parent().get_node_or_null(
			"returnvoidspawn"
		) as Area2D

	if _return_area == null and get_tree().current_scene != null:
		_return_area = get_tree().current_scene.find_child(
			"returnvoidspawn", true, false
		) as Area2D

	if _return_area == null:
		push_warning("CORRUPTION: returnvoidspawn not found.")
		return

	_return_area.monitoring = true

	if not _return_area.body_entered.is_connected(
		_on_return_area_body_entered
	):
		_return_area.body_entered.connect(
			_on_return_area_body_entered
		)


func _on_body_entered(body: Node2D) -> void:
	if ativado or not body.is_in_group(&"player"):
		return

	var candidate: Node = get_node_or_null(
		necromante_normal_path
	)

	if not (candidate is CharacterBody2D):
		push_warning(
			"CORRUPTION: Necromancer path must point to CharacterBody2D."
		)
		return

	if cena_void_necro == null:
		push_warning("CORRUPTION: Assign voidnecro.tscn.")
		return

	ativado = true
	player_detectado = body
	necro_original = candidate as CharacterBody2D

	_necro_parent = necro_original.get_parent()
	_posicao_original_necro = necro_original.global_position
	_sprite_original = _get_necro_sprite(necro_original)

	if is_instance_valid(_sprite_original):
		_flip_original = _sprite_original.flip_h
		_sprite_original_position = _sprite_original.position
		_sprite_original_scale = _sprite_original.scale

	_start_corruption()


# ============================================================
# CORRUPTION CUTSCENE
# ============================================================

func _start_corruption() -> void:
	em_corrupcao = true
	corrupcao_iniciada.emit()

	if is_instance_valid(necro_original):
		necro_original.velocity = Vector2.ZERO
		necro_original.process_mode = Node.PROCESS_MODE_DISABLED
		_disable_collisions(necro_original)

	if is_instance_valid(_sprite_original):
		_sprite_original.stop()

	_stored_camera = get_viewport().get_camera_2d()

	if is_instance_valid(_stored_camera):
		_stored_camera_offset = _stored_camera.offset

	_camera_shaking = true
	_corruption_elapsed = 0.0
	_corruption_strength = 0.0
	_smoke_clock = 0.0
	_vein_clock = 0.0

	set_process(true)

	await get_tree().create_timer(
		duracao_corrupcao_visivel
	).timeout

	if not is_inside_tree():
		return

	em_corrupcao = false
	_camera_shaking = false
	_restore_camera()

	if is_instance_valid(_sprite_original):
		_sprite_original.position = _sprite_original_position

	# V8.1: INSTANT, COMPLETELY BLACK.
	_freeze_player_for_flash()
	_show_full_black()

	# Wait for the black image to actually render,
	# then keep it completely opaque.
	await _hold_full_black(duracao_flash_preto)

	if not is_inside_tree():
		return

	# The Necromancer disappears while the screen is black.
	_emit_black_motes(
		_posicao_original_necro,
		particulas_por_pulso + 18
	)

	if is_instance_valid(necro_original):
		necro_original.queue_free()

	necro_original = null
	_sprite_original = null

	necromante_desapareceu.emit()

	# Let AmbienciaLevel5 handle permanent darkness.
	_activate_ambience_corruption()

	# The black screen now fades away.
	await _fade_out_full_black(
		duracao_fade_de_volta
	)

	if not is_inside_tree():
		return

	_unfreeze_player_after_flash()

	pronto_para_retorno = true
	set_process(true)

	print("CORRUPTION V8.1: full black flash completed.")

	_try_return_overlap()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if em_corrupcao:
		_corruption_elapsed += delta

		_corruption_strength = clampf(
			_corruption_elapsed /
			maxf(0.01, duracao_corrupcao_visivel),
			0.0, 1.0
		)

		_update_corruption_visual(delta)

		if _camera_shaking and is_instance_valid(_stored_camera):
			var intensity: float = intensidade_tremor * (
				0.18 + _corruption_strength * 0.82
			)

			_stored_camera.offset = (
				_stored_camera_offset +
				Vector2(
					randf_range(-intensity, intensity),
					randf_range(-intensity, intensity)
				)
			)

		return

	if pronto_para_retorno and not guardian_spawned:
		_overlap_check_clock += delta

		if _overlap_check_clock >= 0.20:
			_overlap_check_clock = 0.0
			_try_return_overlap()

	elif guardian_spawned and not _arena_guardian_defeated:
		if _guardian_is_defeated():
			_on_guardian_defeated()
		else:
			_keep_fighters_inside_arena()

	else:
		set_process(false)


func _physics_process(delta: float) -> void:
	if name.to_lower() == "returnvoidspawn":
		return

	if guardian_spawned and not _arena_guardian_defeated:
		if _guardian_is_defeated():
			_on_guardian_defeated()

	_update_guardian_fog(delta)


func _update_corruption_visual(delta: float) -> void:
	if is_instance_valid(_sprite_original):
		var progress: float = _corruption_strength

		var shadow: float = lerpf(
			1.0, 0.025, pow(progress, 1.35)
		)

		var shiver: float = sin(
			_corruption_elapsed * (13.0 + progress * 16.0)
		) * (1.2 + progress * 4.2)

		_sprite_original.position = (
			_sprite_original_position +
			Vector2(
				shiver,
				sin(_corruption_elapsed * 20.0) *
				progress * 2.4
			)
		)

		_sprite_original.scale = _sprite_original_scale * (
			1.0 + 0.035 * progress +
			0.025 * progress *
			sin(_corruption_elapsed * 13.0)
		)

		_sprite_original.modulate = Color(
			shadow,
			shadow * 0.91,
			shadow * 0.96,
			1.0
		)

	_smoke_clock += delta
	_vein_clock += delta

	var smoke_interval: float = lerpf(
		0.18, 0.06, _corruption_strength
	)

	if _smoke_clock >= smoke_interval:
		_smoke_clock = 0.0

		_emit_black_motes(
			_posicao_original_necro,
			particulas_por_pulso +
			int(_corruption_strength * 13.0)
		)

	if _vein_clock >= 0.36:
		_vein_clock = 0.0

		_emit_corruption_veins(
			_posicao_original_necro,
			2 + int(_corruption_strength * 5.0)
		)


# ============================================================
# LEVEL 5 PERMANENT DARKNESS
# ============================================================

func _activate_ambience_corruption() -> void:
	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	var ambience: Node = scene.find_child(
		"AmbienciaLevel5", true, false
	)

	if is_instance_valid(ambience):
		if ambience.has_method(
			&"_ativar_escuridao_corrompida"
		):
			ambience.call(
				&"_ativar_escuridao_corrompida"
			)


# ============================================================
# V8.1 FULL BLACK FLASH
#
# Completely separate from permanent environmental darkness.
# The flash covers the WHOLE screen, even the HUD.
#
# Black is held before the fade starts.
# ============================================================

func _create_flash_layer() -> void:
	if (
		is_instance_valid(_flash_layer)
		and is_instance_valid(_flash_rect)
	):
		return

	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "RealFullBlackFlashV81"
	_flash_layer.layer = FLASH_LAYER
	_flash_layer.follow_viewport_enabled = false
	_flash_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().root.add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "OpaqueBlackCover"
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_flash_layer.add_child(_flash_rect)

	# Full viewport coverage, independent of camera position.
	_flash_rect.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_flash_rect.position = Vector2.ZERO
	_flash_rect.size = get_viewport().get_visible_rect().size
	_flash_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash_rect.modulate = Color.WHITE
	_flash_rect.self_modulate = Color.WHITE

	_flash_rect.visible = true
	_flash_layer.visible = false

	if not get_viewport().size_changed.is_connected(
		_on_viewport_resized
	):
		get_viewport().size_changed.connect(
			_on_viewport_resized
		)


func _show_full_black() -> void:
	_create_flash_layer()

	if _flash_tween != null:
		if _flash_tween.is_running():
			_flash_tween.kill()

	# Force it to the absolute topmost layer.
	_flash_layer.layer = FLASH_LAYER
	_flash_layer.visible = true

	_flash_rect.visible = true
	_flash_rect.position = Vector2.ZERO
	_flash_rect.size = get_viewport().get_visible_rect().size
	_flash_rect.modulate = Color.WHITE
	_flash_rect.self_modulate = Color.WHITE

	# Set full opacity directly on the ColorRect.
	_flash_rect.color = Color.BLACK

	print("CORRUPTION: FULL BLACK SCREEN ON.")


func _hold_full_black(seconds: float) -> void:
	# Wait until Godot has actually drawn one black frame.
	await RenderingServer.frame_post_draw

	if not is_inside_tree():
		return

	# Keep the screen fully black for a perceptible duration.
	if is_instance_valid(_flash_rect):
		_flash_rect.color = Color.BLACK

	await get_tree().create_timer(
		maxf(0.25, seconds)
	).timeout


func _fade_out_full_black(duration: float) -> void:
	if not is_instance_valid(_flash_rect):
		return

	# Start from fully black regardless of previous state.
	_flash_rect.color = Color.BLACK

	if _flash_tween != null:
		if _flash_tween.is_running():
			_flash_tween.kill()

	_flash_tween = create_tween()

	# Fade only AFTER the opaque-black hold is finished.
	_flash_tween.tween_property(
		_flash_rect,
		"color:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)

	await _flash_tween.finished

	if not is_inside_tree():
		return

	_flash_layer.visible = false

	print("CORRUPTION: full black faded out.")


func _on_viewport_resized() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size

	if is_instance_valid(_flash_rect):
		_flash_rect.position = Vector2.ZERO
		_flash_rect.size = size

	if is_instance_valid(_fog_root):
		_fog_root.size = size


# ============================================================
# RETURN SENSOR
# ============================================================

func _on_return_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_try_spawn_on_return(body)


func _try_return_overlap() -> void:
	if not is_instance_valid(_return_area):
		return

	for body: Node2D in _return_area.get_overlapping_bodies():
		if body.is_in_group(&"player"):
			_try_spawn_on_return(body)
			return


func _try_spawn_on_return(body: Node2D) -> void:
	if not ativado or not pronto_para_retorno or guardian_spawned:
		return

	if not body.is_in_group(&"player"):
		return

	if exigir_lapis_coletado:
		if not GerenciadorArtefatos.possui_artefato(ID_LAPIS):
			return

	guardian_spawned = true
	player_detectado = body

	_spawn_guardian_on_return()


# ============================================================
# SECOND BLACK FLASH AND GUARDIAN SPAWN
# ============================================================

func _spawn_guardian_on_return() -> void:
	_freeze_player_for_flash()

	# Real instant blackout again.
	_show_full_black()

	await _hold_full_black(segundo_flash_preto)

	if not is_inside_tree():
		return

	var spawn_position: Vector2 = (
		_get_return_spawn_position() +
		Vector2(0.0, -surgimento_acima)
	)

	var spawned: Node = cena_void_necro.instantiate()

	if not (spawned is CharacterBody2D):
		push_error(
			"CORRUPTION: voidnecro.tscn needs CharacterBody2D root."
		)

		if spawned != null:
			spawned.free()

		await _fade_out_full_black(fade_retorno)
		_unfreeze_player_after_flash()

		guardian_spawned = false
		return

	var guardian: CharacterBody2D = (
		spawned as CharacterBody2D
	)

	guardian.set_script(GUARDIAN_SCRIPT)
	guardian.set_meta(&"void_necro_generated", true)
	guardian.set_meta(&"relic_guardian_special", true)

	var host: Node = (
		_necro_parent
		if is_instance_valid(_necro_parent)
		else get_tree().current_scene
	)

	host.add_child(guardian)
	guardian.global_position = spawn_position

	_arena_guardian = guardian
	_arena_guardian_registered = true
	_arena_guardian_defeated = false

	if arena_lock_enabled:
		_create_guardian_arena(guardian)

		guardian.global_position.x = clampf(
			guardian.global_position.x,
			_arena_left_x + 55.0,
			_arena_right_x - 55.0
		)

	if guardian.has_signal(&"health_changed"):
		guardian.connect(
			&"health_changed",
			Callable(self, "_on_guardian_health_changed")
		)

	guardian.tree_exiting.connect(
		_on_guardian_removed
	)

	var new_sprite: AnimatedSprite2D = (
		_get_necro_sprite(guardian)
	)

	if is_instance_valid(new_sprite):
		new_sprite.flip_h = _flip_original

	if guardian.has_method(&"_begin_spawn_warning"):
		guardian.call(
			&"_begin_spawn_warning",
			guardian.global_position
		)

	# Fog begins building during the blackout.
	_begin_guardian_fog()

	await _fade_out_full_black(fade_retorno)

	if not is_inside_tree():
		return

	_unfreeze_player_after_flash()

	pronto_para_retorno = false
	set_process(arena_lock_enabled)

	corrupcao_finalizada.emit(guardian)

	print("CORRUPTION V8.1: Guardian spawned.")


# ============================================================
# KING NECRO BLACK FOG
# ============================================================

func _begin_guardian_fog() -> void:
	if not usar_neblina_guardiao:
		return

	_create_guardian_fog()

	_fog_wanted = true
	_fog_power = 0.0
	_fog_time = 0.0

	if is_instance_valid(_fog_root):
		_fog_root.visible = true


func _end_guardian_fog() -> void:
	# Fade out instead of disappearing instantly.
	_fog_wanted = false


func _create_guardian_fog() -> void:
	if is_instance_valid(_fog_root):
		return

	_keep_hud_above_darkness()

	_fog_fallback_layer = CanvasLayer.new()
	_fog_fallback_layer.name = "GuardianBlackFogFallback"
	_fog_fallback_layer.layer = FOG_LAYER
	_fog_fallback_layer.follow_viewport_enabled = false

	get_tree().root.add_child(_fog_fallback_layer)

	_fog_root = Control.new()
	_fog_root.name = "KingStyleWorldBlackFog"
	_fog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_root.position = Vector2.ZERO
	_fog_root.size = get_viewport_rect().size
	_fog_root.visible = false

	_fog_fallback_layer.add_child(_fog_root)

	_try_attach_fog_to_hud()

	var fog_texture: Texture2D = _make_king_black_fog_texture()

	for i: int in range(FOG_COLUMNS * FOG_ROWS):
		var bank: TextureRect = TextureRect.new()
		bank.name = "BlackMist_" + str(i)
		bank.texture = fog_texture
		bank.stretch_mode = TextureRect.STRETCH_SCALE
		bank.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		bank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bank.visible = false

		_fog_root.add_child(bank)
		_fog_panels.append(bank)

	if mostrar_cinzas_escuras:
		var ash_texture: Texture2D = (
			_make_black_ash_texture(20)
		)

		for i: int in range(ASH_COLUMNS * ASH_ROWS):
			var ash: TextureRect = TextureRect.new()
			ash.name = "BlackAsh_" + str(i)
			ash.texture = ash_texture
			ash.stretch_mode = TextureRect.STRETCH_SCALE
			ash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			ash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ash.visible = false

			_fog_root.add_child(ash)
			_ash_panels.append(ash)


func _try_attach_fog_to_hud() -> void:
	if not is_instance_valid(_fog_root):
		return

	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	var hud: CanvasLayer = scene.find_child(
		"HUD", true, false
	) as CanvasLayer

	if not is_instance_valid(hud):
		return

	if not _hud_original_layers.has(hud):
		_hud_original_layers[hud] = hud.layer

	hud.layer = maxi(hud.layer, HUD_LAYER)

	if _fog_root.get_parent() != hud:
		_fog_root.reparent(hud, false)

	hud.move_child(_fog_root, 0)
	_fog_root.position = Vector2.ZERO


func _keep_hud_above_darkness() -> void:
	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	for node: Node in scene.find_children(
		"*", "CanvasLayer", true, false
	):
		if not (node is CanvasLayer):
			continue

		var layer: CanvasLayer = node as CanvasLayer
		var lower_name: String = String(
			layer.name
		).to_lower()

		var is_hud: bool = (
			lower_name == "hud"
			or lower_name == "playerhud"
			or lower_name == "healthhud"
			or lower_name == "hearts"
			or lower_name.begins_with("hud")
			or lower_name.ends_with("hud")
		)

		if is_hud:
			if not _hud_original_layers.has(layer):
				_hud_original_layers[layer] = layer.layer

			layer.layer = maxi(layer.layer, HUD_LAYER)


func _fog_seed(cx: int, cy: int, salt: float) -> float:
	return fposmod(
		sin(
			float(cx) * 127.1 +
			float(cy) * 311.7 +
			salt
		) * 43758.5453,
		1.0
	)


func _update_guardian_fog(delta: float) -> void:
	if not is_instance_valid(_fog_root):
		return

	var target_power: float = (
		1.0 if _fog_wanted else 0.0
	)

	var fade_time: float = (
		tempo_aparecer_neblina
		if _fog_wanted
		else tempo_desaparecer_neblina
	)

	_fog_power = move_toward(
		_fog_power,
		target_power,
		delta / maxf(0.01, fade_time)
	)

	if _fog_power <= 0.001 and not _fog_wanted:
		_fog_power = 0.0
		_fog_root.visible = false
		return

	_fog_root.visible = true
	_fog_root.size = get_viewport_rect().size

	_fog_time += delta * velocidade_neblina

	_draw_world_black_fog()
	_draw_black_ash()


func _draw_world_black_fog() -> void:
	if not is_instance_valid(_fog_root):
		return

	var screen: Vector2 = get_viewport_rect().size

	var world_to_screen: Transform2D = (
		get_viewport().get_canvas_transform()
	)

	var screen_to_world: Transform2D = (
		world_to_screen.affine_inverse()
	)

	var world_center: Vector2 = (
		screen_to_world * (screen * 0.5)
	)

	var zoom_x: float = maxf(
		0.15, world_to_screen.x.length()
	)

	var zoom_y: float = maxf(
		0.15, world_to_screen.y.length()
	)

	var grid_x: int = floori(
		world_center.x / FOG_SPACING.x
	)

	var grid_y: int = floori(
		world_center.y / FOG_SPACING.y
	)

	for i: int in range(_fog_panels.size()):
		var bank: TextureRect = _fog_panels[i]

		var cx: int = grid_x + i % FOG_COLUMNS - 3

		var cy: int = (
			grid_y +
			floori(float(i) / float(FOG_COLUMNS)) - 2
		)

		var seeded: float = _fog_seed(cx, cy, 17.0)

		bank.visible = seeded > 0.18

		if not bank.visible:
			continue

		var jitter: Vector2 = Vector2(
			(_fog_seed(cx, cy, 31.0) - 0.5) * 190.0,
			(_fog_seed(cx, cy, 67.0) - 0.5) * 95.0
		)

		var drift: Vector2 = Vector2(
			sin(
				_fog_time * (0.39 + 0.11 * seeded) +
				seeded * TAU
			) * 68.0 +
			sin(
				_fog_time * 0.17 + seeded * 4.3
			) * 27.0,

			cos(
				_fog_time * (0.25 + 0.08 * seeded) +
				seeded * TAU
			) * 24.0 +
			sin(
				_fog_time * 0.31 + seeded * 2.0
			) * 11.0
		)

		var world_position: Vector2 = (
			Vector2(
				float(cx) * FOG_SPACING.x,
				float(cy) * FOG_SPACING.y
			) +
			jitter +
			drift
		)

		var pixel_center: Vector2 = (
			world_to_screen * world_position
		)

		var world_width: float = 480.0 + seeded * 90.0
		var world_height: float = 175.0 + seeded * 45.0

		var breathing: float = (
			1.0 +
			0.045 * sin(
				_fog_time * 0.43 + seeded * TAU
			)
		)

		bank.size = Vector2(
			world_width * zoom_x,
			world_height * zoom_y
		) * breathing

		bank.position = pixel_center - bank.size * 0.5

		bank.modulate = Color(
			1.0, 1.0, 1.0,
			opacidade_neblina *
			_fog_power *
			(0.84 + 0.16 * seeded)
		)


func _draw_black_ash() -> void:
	if _ash_panels.is_empty():
		return

	var screen: Vector2 = get_viewport_rect().size

	var world_to_screen: Transform2D = (
		get_viewport().get_canvas_transform()
	)

	var world_center: Vector2 = (
		world_to_screen.affine_inverse() *
		(screen * 0.5)
	)

	var zoom_x: float = maxf(
		0.15, world_to_screen.x.length()
	)

	var zoom_y: float = maxf(
		0.15, world_to_screen.y.length()
	)

	var grid_x: int = floori(
		world_center.x / ASH_SPACING.x
	)

	var grid_y: int = floori(
		world_center.y / ASH_SPACING.y
	)

	for i: int in range(_ash_panels.size()):
		var ash: TextureRect = _ash_panels[i]

		var cx: int = grid_x + i % ASH_COLUMNS - 4

		var cy: int = (
			grid_y +
			floori(float(i) / float(ASH_COLUMNS)) - 3
		)

		var seeded: float = _fog_seed(cx, cy, 109.0)

		ash.visible = seeded > 0.24

		if not ash.visible:
			continue

		var jitter: Vector2 = Vector2(
			(_fog_seed(cx, cy, 119.0) - 0.5) * 115.0,
			(_fog_seed(cx, cy, 127.0) - 0.5) * 75.0
		)

		var movement: Vector2 = Vector2(
			sin(
				_fog_time * (0.48 + 0.14 * seeded) +
				seeded * TAU
			) * 18.0,

			48.0 -
			fposmod(
				_fog_time * (11.0 + 10.0 * seeded) +
				seeded * 85.0,
				96.0
			)
		)

		var world_position: Vector2 = (
			Vector2(
				float(cx) * ASH_SPACING.x,
				float(cy) * ASH_SPACING.y
			) +
			jitter +
			movement
		)

		var pixel_center: Vector2 = (
			world_to_screen * world_position
		)

		var diameter: float = 3.5 + seeded * 3.3

		ash.size = Vector2(
			diameter * zoom_x,
			diameter * zoom_y
		)

		ash.position = pixel_center - ash.size * 0.5

		ash.modulate = Color(
			1.0, 1.0, 1.0,
			0.46 * _fog_power *
			(0.83 + 0.17 * seeded)
		)


# ============================================================
# KING NECRO FOG TEXTURES
# ============================================================

func _make_king_black_fog_texture() -> Texture2D:
	var width: int = 256
	var height: int = 128

	var image_data: Image = Image.create(
		width, height, false, Image.FORMAT_RGBA8
	)

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 72011
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.023
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

	for y: int in range(height):
		var fy: float = (
			(float(y) + 0.5) / float(height)
		)

		var vert_mask: float = (
			1.0 - smoothstep(
				0.17, 0.50,
				absf(fy - 0.50)
			)
		)

		for x: int in range(width):
			var fx: float = (
				(float(x) + 0.5) / float(width)
			)

			var side_mask: float = (
				smoothstep(0.0, 0.15, fx) *
				(1.0 - smoothstep(0.85, 1.0, fx))
			)

			var n: float = noise.get_noise_2d(
				float(x), float(y)
			)

			var density: float = smoothstep(
				-0.33, 0.24, n
			)

			var streak: float = (
				0.13 + 0.87 * pow(density, 0.72)
			)

			var ribbons: float = (
				0.86 +
				0.14 * sin(
					fy * 30.0 + n * 2.9 + fx * 6.0
				)
			)

			var alpha: float = clampf(
				vert_mask * side_mask *
				streak * ribbons * 1.28,
				0.0, 1.0
			)

			image_data.set_pixel(
				x, y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	return ImageTexture.create_from_image(image_data)


func _make_black_ash_texture(
	size_pixels: int
) -> Texture2D:
	var image_data: Image = Image.create(
		size_pixels, size_pixels,
		false, Image.FORMAT_RGBA8
	)

	var radius: float = float(size_pixels) * 0.5

	for y: int in range(size_pixels):
		for x: int in range(size_pixels):
			var distance: float = (
				Vector2(
					float(x) - radius,
					float(y) - radius
				).length() / radius
			)

			var alpha: float = pow(
				1.0 - smoothstep(
					0.0, 1.0, distance
				),
				2.0
			)

			image_data.set_pixel(
				x, y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	return ImageTexture.create_from_image(image_data)


# ============================================================
# ARENA LOCK
# ============================================================

func _create_guardian_arena(
	_guardian: CharacterBody2D
) -> void:
	_clear_guardian_arena()

	if not is_instance_valid(player_detectado):
		return

	var player_x: float = player_detectado.global_position.x

	var left_anchor: Node2D = get_node_or_null(
		arena_left_marker
	) as Node2D

	var right_anchor: Node2D = get_node_or_null(
		arena_right_marker
	) as Node2D

	_arena_left_x = player_x - arena_left_clearance

	_arena_right_x = maxf(
		player_x + arena_right_clearance,
		_posicao_original_necro.x + 150.0
	)

	if is_instance_valid(left_anchor):
		_arena_left_x = left_anchor.global_position.x

	if is_instance_valid(right_anchor):
		_arena_right_x = right_anchor.global_position.x

	if _arena_left_x > _arena_right_x:
		var temp: float = _arena_left_x
		_arena_left_x = _arena_right_x
		_arena_right_x = temp

	if _arena_right_x - _arena_left_x < 230.0:
		_arena_left_x = player_x - 130.0
		_arena_right_x = player_x + 310.0

	_arena_left_x = minf(
		_arena_left_x, player_x - 60.0
	)

	_arena_right_x = maxf(
		_arena_right_x, player_x + 60.0
	)

	_arena_holder = Node2D.new()
	_arena_holder.name = "LapisGuardianVoidSealV3"

	get_tree().current_scene.add_child(_arena_holder)

	var center_y: float = (
		player_detectado.global_position.y - 80.0
	)

	_arena_left_wall = _create_void_wall(
		_arena_left_x,
		center_y,
		"LeftVoidSeal"
	)

	_arena_right_wall = _create_void_wall(
		_arena_right_x,
		center_y,
		"RightVoidSeal"
	)

	_arena_player_inside = true


func _create_void_wall(
	x: float,
	y: float,
	wall_name: String
) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.name = wall_name

	var collision_layers: int = 1

	if player_detectado is CollisionObject2D:
		collision_layers = (
			player_detectado as CollisionObject2D
		).collision_mask

	wall.collision_layer = collision_layers
	wall.collision_mask = 0

	_arena_holder.add_child(wall)
	wall.global_position = Vector2(x, y)

	var collider: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()

	rectangle.size = Vector2(
		arena_wall_width,
		arena_wall_height
	)

	collider.shape = rectangle
	wall.add_child(collider)

	var glow: Line2D = Line2D.new()
	glow.name = "SealingLight"
	glow.width = arena_wall_width + 14.0
	glow.default_color = Color(0.54, 0.58, 0.69, 0.20)

	glow.points = PackedVector2Array([
		Vector2(0, -arena_wall_height * 0.5),
		Vector2(0, arena_wall_height * 0.5)
	])

	wall.add_child(glow)

	var core: Line2D = Line2D.new()
	core.name = "BlackCore"
	core.width = arena_wall_width
	core.default_color = Color(0.002, 0.002, 0.007, 0.97)
	core.points = glow.points

	wall.add_child(core)

	var vein: Line2D = Line2D.new()
	vein.width = 1.7
	vein.default_color = Color(0.82, 0.83, 0.94, 0.70)
	vein.points = glow.points

	wall.add_child(vein)

	var oscillate: Tween = wall.create_tween()
	oscillate.set_loops()

	oscillate.tween_property(
		glow, "modulate:a", 0.45, 0.70
	)

	oscillate.tween_property(
		glow, "modulate:a", 1.0, 0.70
	)

	return wall


func _keep_fighters_inside_arena() -> void:
	if not _arena_player_inside:
		return

	if is_instance_valid(player_detectado):
		var x: float = player_detectado.global_position.x

		var safe_x: float = clampf(
			x,
			_arena_left_x + 22.0,
			_arena_right_x - 22.0
		)

		if not is_equal_approx(x, safe_x):
			player_detectado.global_position.x = safe_x

			if player_detectado is CharacterBody2D:
				(player_detectado as CharacterBody2D).velocity.x = 0.0

	if is_instance_valid(_arena_guardian):
		var gx: float = _arena_guardian.global_position.x

		var safe_gx: float = clampf(
			gx,
			_arena_left_x + 25.0,
			_arena_right_x - 25.0
		)

		if not is_equal_approx(gx, safe_gx):
			_arena_guardian.global_position.x = safe_gx


# ============================================================
# GUARDIAN DEATH
# ============================================================

func _guardian_is_defeated() -> bool:
	if not guardian_spawned or not _arena_guardian_registered:
		return false

	if not is_instance_valid(_arena_guardian):
		return true

	if _arena_guardian.is_queued_for_deletion():
		return true

	if _arena_guardian.has_method(&"is_dead"):
		if bool(_arena_guardian.call(&"is_dead")):
			return true

	var health: Variant = _arena_guardian.get("hp")

	if health is int or health is float:
		if float(health) <= 0.0:
			return true

	var enemy_script: Script = (
		_arena_guardian.get_script() as Script
	)

	while enemy_script != null:
		var constants: Dictionary = (
			enemy_script.get_script_constant_map()
		)

		var states: Variant = constants.get("State")

		if states is Dictionary and states.has("DEAD"):
			var current_state: Variant = (
				_arena_guardian.get("state")
			)

			if current_state != null:
				if int(current_state) == int(states["DEAD"]):
					return true

		enemy_script = enemy_script.get_base_script()

	return false


func _on_guardian_health_changed(
	current_hp: int,
	_maximum_hp: int
) -> void:
	if current_hp <= 0:
		_on_guardian_defeated()


func _on_guardian_removed() -> void:
	if not is_inside_tree():
		return

	if guardian_spawned and not _arena_guardian_defeated:
		_on_guardian_defeated()


func _on_guardian_defeated() -> void:
	if _arena_guardian_defeated:
		return

	_arena_guardian_defeated = true
	_arena_player_inside = false

	_clear_guardian_arena()

	# Fog fades out smoothly.
	_end_guardian_fog()

	# AmbienciaLevel5 keeps the permanent darkness.
	print("GUARDIAN V8.1: defeated; barriers removed.")
	print("GUARDIAN V8.1: fog fading out.")

	set_process(false)


func _clear_guardian_arena() -> void:
	if is_instance_valid(_arena_holder):
		_disable_arena_seal(_arena_holder)
		_arena_holder.queue_free()

	_arena_holder = null
	_arena_left_wall = null
	_arena_right_wall = null

	_remove_leftover_arena_seals()


func _disable_arena_seal(node: Node) -> void:
	if not is_instance_valid(node):
		return

	if node is CollisionObject2D:
		var body: CollisionObject2D = node as CollisionObject2D
		body.set_deferred("collision_layer", 0)
		body.set_deferred("collision_mask", 0)

	if node is CollisionShape2D:
		(node as CollisionShape2D).set_deferred(
			"disabled", true
		)

	if node is CanvasItem:
		(node as CanvasItem).visible = false

	for child: Node in node.get_children():
		_disable_arena_seal(child)


func _remove_leftover_arena_seals() -> void:
	var scene: Node = get_tree().current_scene

	if not is_instance_valid(scene):
		return

	var seal_names: Array[String] = [
		"LapisGuardianVoidSealV3",
		"LeftVoidSeal",
		"RightVoidSeal"
	]

	for seal_name: String in seal_names:
		var matching: Array[Node] = scene.find_children(
			seal_name, "", true, false
		)

		for seal: Node in matching:
			if not is_instance_valid(seal):
				continue

			_disable_arena_seal(seal)

			if not seal.is_queued_for_deletion():
				seal.queue_free()


# ============================================================
# SPAWN AND PLAYER HELPERS
# ============================================================

func _get_return_spawn_position() -> Vector2:
	if not local_spawn_override.is_empty():
		var override_node: Node2D = get_node_or_null(
			local_spawn_override
		) as Node2D

		if is_instance_valid(override_node):
			return override_node.global_position

	if is_instance_valid(_return_area):
		var shape: CollisionShape2D = (
			_return_area.get_node_or_null("CollisionShape2D")
			as CollisionShape2D
		)

		if is_instance_valid(shape):
			return shape.global_position

		return _return_area.global_position

	return _posicao_original_necro


func _freeze_player_for_flash() -> void:
	if not bloquear_controle_durante_flash:
		return

	if not is_instance_valid(player_detectado):
		return

	if _player_was_frozen:
		return

	_player_physics_was_running = (
		player_detectado.is_physics_processing()
	)

	if player_detectado is CharacterBody2D:
		(player_detectado as CharacterBody2D).velocity = Vector2.ZERO

	player_detectado.set_physics_process(false)
	_player_was_frozen = true


func _unfreeze_player_after_flash() -> void:
	if not _player_was_frozen:
		return

	if is_instance_valid(player_detectado):
		player_detectado.set_physics_process(
			_player_physics_was_running
		)

	_player_was_frozen = false


func _restore_camera() -> void:
	if is_instance_valid(_stored_camera):
		_stored_camera.offset = _stored_camera_offset


func _get_necro_sprite(enemy: Node) -> AnimatedSprite2D:
	if enemy is AnimatedSprite2D:
		return enemy as AnimatedSprite2D

	var direct: AnimatedSprite2D = (
		enemy.get_node_or_null("AnimatedSprite2D")
		as AnimatedSprite2D
	)

	if direct != null:
		return direct

	for child: Node in enemy.get_children():
		var candidate: AnimatedSprite2D = (
			_get_necro_sprite(child)
		)

		if candidate != null:
			return candidate

	return null


func _disable_collisions(root: Node) -> void:
	if root is CollisionShape2D:
		(root as CollisionShape2D).set_deferred(
			"disabled", true
		)

	if root is Area2D:
		(root as Area2D).set_deferred(
			"monitoring", false
		)

	for child: Node in root.get_children():
		_disable_collisions(child)


# ============================================================
# CORRUPTION PARTICLES
# ============================================================

func _emit_black_motes(at: Vector2, amount: int) -> void:
	var host: Node = get_tree().current_scene

	if host == null:
		return

	for i: int in range(amount):
		var mote: Polygon2D = Polygon2D.new()
		var radius: float = randf_range(1.6, 4.4)

		mote.polygon = PackedVector2Array([
			Vector2(-radius, -radius),
			Vector2(radius, -radius),
			Vector2(radius, radius),
			Vector2(-radius, radius)
		])

		mote.color = Color(
			0.0, 0.0, 0.0,
			randf_range(0.72, 0.96)
		)

		mote.z_index = 100
		host.add_child(mote)

		mote.global_position = at + Vector2(
			randf_range(-19.0, 19.0),
			randf_range(-28.0, 13.0)
		)

		var endpoint: Vector2 = (
			mote.global_position +
			Vector2(
				randf_range(-42.0, 42.0),
				randf_range(-76.0, -12.0)
			)
		)

		var duration: float = randf_range(0.35, 0.92)

		var tween: Tween = mote.create_tween()
		tween.set_parallel(true)

		tween.tween_property(
			mote,
			"global_position",
			endpoint,
			duration
		)

		tween.tween_property(
			mote,
			"modulate:a",
			0.0,
			duration
		)

		tween.set_parallel(false)
		tween.tween_callback(mote.queue_free)


func _emit_corruption_veins(at: Vector2, amount: int) -> void:
	var host: Node = get_tree().current_scene

	if host == null:
		return

	for i: int in range(amount):
		var vein: Line2D = Line2D.new()
		vein.width = randf_range(1.5, 4.0)

		vein.default_color = Color(
			0.015, 0.005, 0.025,
			randf_range(0.63, 0.95)
		)

		vein.z_index = 110

		var offset: Vector2 = Vector2(
			randf_range(-8.0, 8.0),
			randf_range(-16.0, 10.0)
		)

		vein.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(
				randf_range(-9.0, 9.0),
				-randf_range(4.0, 16.0)
			),
			Vector2(
				randf_range(-23.0, 23.0),
				-randf_range(18.0, 42.0)
			)
		])

		host.add_child(vein)
		vein.global_position = at + offset

		var tween: Tween = vein.create_tween()

		tween.tween_property(
			vein,
			"modulate:a",
			0.0,
			0.33
		)

		tween.tween_callback(vein.queue_free)


# ============================================================
# EXIT CLEANUP
# ============================================================

func _exit_tree() -> void:
	_clear_guardian_arena()
	_restore_camera()
	_unfreeze_player_after_flash()

	for hud_node: Node in _hud_original_layers.keys():
		if is_instance_valid(hud_node):
			if hud_node is CanvasLayer:
				(hud_node as CanvasLayer).layer = int(
					_hud_original_layers[hud_node]
				)

	_hud_original_layers.clear()

	if get_viewport().size_changed.is_connected(
		_on_viewport_resized
	):
		get_viewport().size_changed.disconnect(
			_on_viewport_resized
		)

	if _flash_tween != null:
		if _flash_tween.is_running():
			_flash_tween.kill()

	if is_instance_valid(_fog_root):
		_fog_root.queue_free()

	if is_instance_valid(_fog_fallback_layer):
		_fog_fallback_layer.queue_free()

	if is_instance_valid(_flash_layer):
		_flash_layer.queue_free()
