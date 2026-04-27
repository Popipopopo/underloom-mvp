extends Node

var in_run: bool = false

func start_run() -> void:
	in_run = true
	print("[RunManager] Run started (backpack is for this outing; not cleared here)")

func end_victory() -> void:
	in_run = false
	print("[RunManager] Run ended: victory")

func end_defeat() -> void:
	in_run = false
	print("[RunManager] Run ended: defeat")
