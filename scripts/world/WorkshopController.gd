extends Node2D

const CRAFTING_SCENE := "res://scenes/ui/CraftingScreen.tscn"

@onready var start_gate: Area2D = $StartGate
var _craft_bench: Area2D

var _craft_ui_layer: CanvasLayer = null


func _ready() -> void:
	_craft_bench = get_node_or_null("CraftBench") as Area2D
	start_gate.body_entered.connect(_on_start_gate_body_entered)
	if _craft_bench != null:
		_craft_bench.body_entered.connect(_on_craft_bench_body_entered)
	else:
		push_error("workshop.tscn is missing a child Area2D named CraftBench.")
	_setup_camera_limits()


func _setup_camera_limits() -> void:
	var cam: Camera2D = get_node_or_null("Player/Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = -460
	cam.limit_right = 388
	cam.limit_bottom = 310
	# limit_top 保持默认（不限制，露出灰色 OK）


func _on_start_gate_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	RunManager.start_run()
	call_deferred("_deferred_enter_combat")


func _deferred_enter_combat() -> void:
	get_tree().change_scene_to_file("res://scenes/world/test_combat.tscn")


func _on_craft_bench_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if _craft_ui_layer != null and is_instance_valid(_craft_ui_layer):
		return
	var ps: PackedScene = load(CRAFTING_SCENE)
	if ps == null:
		push_warning("Missing %s" % CRAFTING_SCENE)
		return
	var root: Control = ps.instantiate()
	_craft_ui_layer = CanvasLayer.new()
	_craft_ui_layer.layer = 30
	_craft_ui_layer.add_child(root)
	add_child(_craft_ui_layer)
	if root.has_signal("closed"):
		root.closed.connect(_on_crafting_closed)


func _on_crafting_closed() -> void:
	if _craft_ui_layer != null and is_instance_valid(_craft_ui_layer):
		_craft_ui_layer.queue_free()
	_craft_ui_layer = null
