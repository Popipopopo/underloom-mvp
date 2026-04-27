class_name BossSlime
extends Slime

# ────────────────────────────────────────────
# MVP boss：放大 + 加血 + 加伤害的史莱姆
# 死亡掉落 ancient_seal，触发结局
# ────────────────────────────────────────────

func _ready() -> void:
	# 这些值在 super._ready() 之前设，因为 Enemy._ready 会读 max_health 等初始化 stats
	max_health = 150
	contact_damage = 35
	move_speed = 40              # 比普通史莱姆慢一点（更有"重量感"）
	loot_table = [
		{"id": "ancient_seal", "chance": 1.0, "count": 1}
	]
	super._ready()
	add_to_group("boss")         # ← 关键！BossArena 靠这个找它
