class_name Hitbox
extends Area2D

# 这个 Hitbox 命中后造成多少伤害。每个使用 Hitbox 的实体（敌人/子弹）
# 在 _ready 里设置自己的值，挨打方在 hurt 信号回调里读这个字段。
@export var damage_amount: int = 10

signal hit(hurtbox)

func _init() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(hurtbox: Hurtbox) -> void:
	hit.emit(hurtbox)
	hurtbox.hurt.emit(self)
