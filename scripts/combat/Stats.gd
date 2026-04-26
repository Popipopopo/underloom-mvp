class_name Stats
extends Node

signal health_changed
signal died

@export var max_health: int = 100

@onready var health: int = max_health:
	set(v):
		v = clampi(v, 0, max_health)
		if health == v:
			return
		health = v
		health_changed.emit()
		if health == 0:
			died.emit()
