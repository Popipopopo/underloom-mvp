class_name Pickup
extends Area2D

@export var material_id: String = "slime_gel"
@export var material_count: int = 1

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return
	var holder := area.get_parent()
	if holder == null or not holder.is_in_group("player"):
		return
	if RunManager.in_run:
		GameState.add_backpack_material(material_id, material_count)
		print("[Pickup] +%d %s backpack=%d" % [
			material_count,
			material_id,
			GameState.get_backpack_count(material_id),
		])
	else:
		GameState.add_workshop_material(material_id, material_count)
		print("[Pickup] +%d %s workshop=%d" % [
			material_count,
			material_id,
			GameState.get_workshop_count(material_id),
		])
	queue_free()