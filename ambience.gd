# Menacing Skeleton Level 3: FIGHT-ONLY parallax dimming, Godot 4.x.
# Attach to the Node2D named "ambience" inside level_3.
# NO separate ColorRect or CanvasModulate. Only parallax artwork is dimmed.
# The parallax is normal before aggro and gradually returns after boss death.
extends Node2D
class_name MenacingLevel3Ambience

@export_group("Background Only")
@export var parallax_path: NodePath = NodePath("../ParallaxBackground")
@export_range(0.05, 1.0, 0.01) var fight_background_brightness: float = 0.36
@export_range(0.1, 10.0, 0.1) var fight_fade_in_seconds: float = 1.70
@export_range(0.1, 10.0, 0.1) var death_fade_out_seconds: float = 2.0
@export var enabled: bool = true

var _parallax: Node = null
var _boss: Node = null
var _original_modulates: Dictionary = {}
var _brightness: float = 1.0
var _rescan_timer: float = 0.0


func _ready() -> void:
	# No darkening before the fight. Only this script's child backgrounds
	# are affected; it does not use a full-screen black overlay.
	_brightness = 1.0
	_discover_background()
	_find_level3_boss()
	set_process(true)


func _discover_background() -> void:
	var chosen: Node = get_node_or_null(parallax_path)
	if not is_instance_valid(chosen):
		var root: Node = get_tree().current_scene
		if is_instance_valid(root):
			chosen = root.find_child("ParallaxBackground", true, false)
	if chosen == _parallax and not _original_modulates.is_empty():
		return
	_parallax = chosen
	if not is_instance_valid(_parallax):
		push_warning("Menacing ambience: can't find ParallaxBackground. Check parallax_path.")
		return
	_collect_drawables(_parallax)


func _collect_drawables(node: Node) -> void:
	# Modulate leaf CanvasItems, not a parent AND its children, to prevent
	# a double-darkening multiplication.
	var has_drawable_child: bool = false
	for child: Node in node.get_children():
		if child is CanvasItem:
			has_drawable_child = true
			_collect_drawables(child)
	if node is CanvasItem and not has_drawable_child:
		var item: CanvasItem = node as CanvasItem
		if not _original_modulates.has(item):
			_original_modulates[item] = item.modulate


func _find_level3_boss() -> void:
	if is_instance_valid(_boss):
		return
	for candidate: Node in get_tree().get_nodes_in_group(&"menacing_skeleton"):
		# The boss itself sets this flag; summoned/ordinary skeletons do not.
		if bool(candidate.get("is_level3_arena_boss")):
			_boss = candidate
			return


func _boss_fight_active() -> bool:
	if not is_instance_valid(_boss):
		return false
	if not bool(_boss.get("is_level3_arena_boss")):
		return false
	# _begin_fight() sets engaged=true, and _die() sets it back to false.
	# Unlike the fog controller's 'active' state, this reflects combat ONLY.
	return bool(_boss.get("engaged")) and int(_boss.get("mode")) != 6


func _process(delta: float) -> void:
	_rescan_timer -= delta
	if _rescan_timer <= 0.0:
		_rescan_timer = 0.25
		if not is_instance_valid(_parallax) or _original_modulates.is_empty():
			_discover_background()
		if not is_instance_valid(_boss):
			_find_level3_boss()

	# Do NOT inspect the fog warning: dash/slash warnings never darken the
	# background. There is only one fade when the actual boss fight begins.
	var target: float = 1.0
	if enabled and _boss_fight_active():
		target = fight_background_brightness

	var speed: float = (
		(1.0 - fight_background_brightness) / maxf(0.1, fight_fade_in_seconds)
		if target < _brightness else
		(1.0 - fight_background_brightness) / maxf(0.1, death_fade_out_seconds)
	)
	_brightness = move_toward(_brightness, target, speed * delta)
	for item: CanvasItem in _original_modulates.keys():
		if not is_instance_valid(item):
			_original_modulates.erase(item)
			continue
		var original: Color = _original_modulates[item]
		item.modulate = Color(
			original.r * _brightness,
			original.g * _brightness,
			original.b * _brightness,
			original.a
		)


func _exit_tree() -> void:
	for item: CanvasItem in _original_modulates.keys():
		if is_instance_valid(item):
			item.modulate = _original_modulates[item]
