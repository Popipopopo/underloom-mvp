extends Node2D

## CE1 式六边形迷雾地图(MVP,placeholder 图形)。
## 地块:起点/空地/采集/遭遇/下层入口。点相邻格移动,揭开迷雾,触发内容。
## 地图状态存 GameState(跨场景常驻,进战斗再回来不丢)。

const WORKSHOP := "res://scenes/world/workshop.tscn"
const BATTLE := "res://scenes/world/battle.tscn"
const HEX_SIZE := 48.0
const MAP_RADIUS := 2
const SITE_SCENE := "res://scenes/ui/SiteScreen.tscn"

const TYPE_COLOR := {
	"start":   Color(0.35, 0.45, 0.6),
	"empty":   Color(0.2, 0.22, 0.28),
	"gather":  Color(0.3, 0.55, 0.35),
	"encounter": Color(0.6, 0.28, 0.3),
	"exit":    Color(0.75, 0.6, 0.25),
}
const FOG_COLOR := Color(0.12, 0.12, 0.15)
const TYPE_ICON := {
	"start": "家", "empty": "", "gather": "✿采", "encounter": "⚔敌", "exit": "▼下层",
}

var _font: Font
var _msg_lbl: Label
var _top_lbl: Label

# hover 路线预览(CE1 式:鼠标悬停显示虚线+天数,点击直接走)
var _hover_path: Array = []
var _hover_lbl: Label

func _ready() -> void:
	_font = ThemeDB.fallback_font
	if not GameState.expedition_active:
		_generate_map()
	# 战斗返回后:标记遭遇格已用
	if GameState.pending_encounter != "":
		if GameState.expedition_map.has(GameState.pending_encounter):
			GameState.expedition_map[GameState.pending_encounter]["used"] = true
			GameState.expedition_map[GameState.pending_encounter]["type"] = "empty"
		GameState.pending_encounter = ""
	_build_ui()
	queue_redraw()

# ── 地图生成 ──────────────────────────────────────────────────────────────────
func _generate_map() -> void:
	var coords := _all_coords()
	var map := {}
	for c in coords:
		map[_key(c)] = {"type": "empty", "revealed": false, "used": false}

	map[_key(Vector2i.ZERO)]["type"] = "start"
	_reveal_around(map, Vector2i.ZERO)

	var pool := coords.duplicate()
	pool.erase(Vector2i.ZERO)
	pool.sort_custom(func(a, b): return _hex_dist(a) > _hex_dist(b))
	# 最远处 = 下层入口
	map[_key(pool[0])]["type"] = "exit"
	# 中间随机撒采集/遭遇
	var rest := pool.slice(1)
	rest.shuffle()
	# 采集点带环境类型:环境决定采什么(菌毯→真菌 / 碎石→矿物 / 草丛→植物 / 巢穴→魔物)
	var envs := ["fungus", "mineral", "plant", "beast"]
	envs.shuffle()
	for i in min(3, rest.size()):
		map[_key(rest[i])]["type"] = "gather"
		map[_key(rest[i])]["env"] = envs[i % envs.size()]
	for i in range(3, min(5, rest.size())):
		map[_key(rest[i])]["type"] = "encounter"

	GameState.expedition_map = map
	GameState.expedition_player = Vector2i.ZERO
	GameState.expedition_active = true

func _all_coords() -> Array:
	var out: Array = []
	for q in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for r in range(-MAP_RADIUS, MAP_RADIUS + 1):
			if abs(q + r) <= MAP_RADIUS:
				out.append(Vector2i(q, r))
	return out

func _reveal_around(map: Dictionary, c: Vector2i) -> void:
	map[_key(c)]["revealed"] = true
	for n in _neighbors(c):
		if map.has(_key(n)):
			map[_key(n)]["revealed"] = true

# ── 渲染 ──────────────────────────────────────────────────────────────────────
func _draw() -> void:
	var origin := get_viewport_rect().size / 2.0
	for key in GameState.expedition_map:
		var cell: Dictionary = GameState.expedition_map[key]
		var pos := _hex_to_pixel(_unkey(key)) + origin
		if not cell["revealed"]:
			_draw_hex(pos, FOG_COLOR, "?")
		else:
			_draw_hex(pos, TYPE_COLOR.get(cell["type"], FOG_COLOR), _cell_icon(cell))
	# hover 路线虚线 + 终点标记
	if _hover_path.size() >= 2:
		for i in range(_hover_path.size() - 1):
			var a: Vector2 = _hex_to_pixel(_hover_path[i]) + origin
			var b: Vector2 = _hex_to_pixel(_hover_path[i + 1]) + origin
			draw_dashed_line(a, b, Color(1.0, 0.9, 0.5, 0.9), 3.0, 10.0)
		var endp: Vector2 = _hex_to_pixel(_hover_path[_hover_path.size() - 1]) + origin
		draw_circle(endp, 11, Color(1.0, 0.9, 0.5, 0.35))
	# 玩家
	var ppos := _hex_to_pixel(GameState.expedition_player) + origin
	draw_circle(ppos, 12, Color(1, 1, 1))
	draw_circle(ppos, 8, Color(0.2, 0.6, 1.0))

## 采集点按环境显示不同图标,其余按类型
func _cell_icon(cell: Dictionary) -> String:
	if cell["type"] == "gather":
		match str(cell.get("env", "")):
			"fungus": return "🍄"
			"mineral": return "⛏"
			"plant": return "🌿"
			"beast": return "👹"
		return "✿"
	return str(TYPE_ICON.get(cell["type"], ""))

func _draw_hex(center: Vector2, color: Color, label: String) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var ang := deg_to_rad(60.0 * i - 30.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * HEX_SIZE)
	draw_colored_polygon(pts, color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.5, 0.5, 0.6), 2.0)
	if label != "":
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
		draw_string(_font, center - Vector2(w / 2.0, -5), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(0.95, 0.95, 1.0))

# ── UI 覆盖层 ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_top_lbl = Label.new()
	_top_lbl.position = Vector2(20, 16)
	_top_lbl.add_theme_font_size_override("font_size", 15)
	layer.add_child(_top_lbl)

	_msg_lbl = Label.new()
	_msg_lbl.position = Vector2(20, 44)
	_msg_lbl.add_theme_font_size_override("font_size", 14)
	_msg_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	layer.add_child(_msg_lbl)

	_hover_lbl = Label.new()
	_hover_lbl.add_theme_font_size_override("font_size", 15)
	_hover_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_hover_lbl.visible = false
	layer.add_child(_hover_lbl)

	var back := Button.new()
	back.text = "返回工作室"
	back.position = Vector2(20, 76)
	back.custom_minimum_size = Vector2(140, 36)
	back.pressed.connect(_return_workshop)
	layer.add_child(back)

	var hint := Label.new()
	hint.text = "鼠标移到目标格看路线,点击出发 · 找到 ▼下层 或 背包满就回工作室"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20, get_viewport_rect().size.y - 32)
	layer.add_child(hint)

	_update_top()

func _update_top() -> void:
	_top_lbl.text = "地下 -%d 层    第 %d 天    背包 %d/%d" % [
		GameState.expedition_layer, GameState.day, GameState.backpack_items.size(), GameState.BACKPACK_CAP]

func _flash(msg: String) -> void:
	_msg_lbl.text = msg

# ── 输入 / 移动 ───────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	var origin := get_viewport_rect().size / 2.0
	if event is InputEventMouseMotion:
		_update_hover(_pixel_to_hex(event.position - origin), event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _hover_path.is_empty():
			_walk_hover()

## 鼠标悬停:实时算到该格的路线,画虚线 + 跟随鼠标显示天数
func _update_hover(target: Vector2i, mouse_pos: Vector2) -> void:
	if not GameState.expedition_map.has(_key(target)) or target == GameState.expedition_player:
		_hover_path = []
		_hover_lbl.visible = false
		queue_redraw()
		return
	var path := _find_path(GameState.expedition_player, target)
	_hover_path = path
	if path.is_empty():
		_hover_lbl.visible = false
	else:
		_hover_lbl.text = "%d 天" % (path.size() - 1)
		_hover_lbl.position = mouse_pos + Vector2(16, 6)
		_hover_lbl.visible = true
	queue_redraw()

## 点击:沿 hover 路线走到底(每格 +1 天、揭雾),到目的地才触发内容
func _walk_hover() -> void:
	var dest: Vector2i = _hover_path[_hover_path.size() - 1]
	for i in range(1, _hover_path.size()):
		var step: Vector2i = _hover_path[i]
		GameState.expedition_player = step
		GameState.day += 1
		_reveal_around(GameState.expedition_map, step)
	_hover_path = []
	_hover_lbl.visible = false
	_update_top()
	queue_redraw()
	_trigger(dest)

## BFS 寻路(当前地形均一,每格 1 天;多地形后改加权)
func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return []
	var frontier: Array = [from]
	var came: Dictionary = {_key(from): from}
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == to:
			break
		for n in _neighbors(cur):
			if GameState.expedition_map.has(_key(n)) and not came.has(_key(n)):
				came[_key(n)] = cur
				frontier.append(n)
	if not came.has(_key(to)):
		return []
	var path: Array = [to]
	var cur2: Vector2i = to
	while cur2 != from:
		cur2 = came[_key(cur2)]
		path.push_front(cur2)
	return path

func _trigger(c: Vector2i) -> void:
	var cell: Dictionary = GameState.expedition_map[_key(c)]
	match cell["type"]:
		"gather":
			_open_site(c, "gather")
		"encounter":
			GameState.pending_encounter = _key(c)
			get_tree().change_scene_to_file(BATTLE)
		"exit":
			_flash("找到下层入口!(MVP:结束本次远征)")
			_return_workshop()
		_:
			_flash("")

func _open_site(c: Vector2i, type: String) -> void:
	var ps: PackedScene = load(SITE_SCENE)
	if ps == null:
		return
	var root: Control = ps.instantiate()
	var cell: Dictionary = GameState.expedition_map[_key(c)]
	root.setup(type, str(cell.get("env", "")))
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.add_child(root)
	add_child(layer)
	root.closed.connect(_on_site_closed.bind(c, layer))

func _on_site_closed(c: Vector2i, layer: CanvasLayer) -> void:
	if is_instance_valid(layer):
		layer.queue_free()
	# 探索过 → 标记已用,变空地
	if GameState.expedition_map.has(_key(c)):
		GameState.expedition_map[_key(c)]["used"] = true
		GameState.expedition_map[_key(c)]["type"] = "empty"
	_update_top()
	queue_redraw()

func _return_workshop() -> void:
	GameState.end_expedition()
	get_tree().change_scene_to_file(WORKSHOP)

# ── 六边形数学(pointy-top axial)──────────────────────────────────────────────
func _key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]

func _unkey(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _neighbors(c: Vector2i) -> Array:
	var dirs := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	return dirs.map(func(d): return c + d)

func _hex_dist(c: Vector2i) -> int:
	return int((abs(c.x) + abs(c.y) + abs(c.x + c.y)) / 2.0)

func _hex_to_pixel(c: Vector2i) -> Vector2:
	return Vector2(
		HEX_SIZE * sqrt(3.0) * (c.x + c.y / 2.0),
		HEX_SIZE * 1.5 * c.y)

func _pixel_to_hex(p: Vector2) -> Vector2i:
	var q := (sqrt(3.0) / 3.0 * p.x - 1.0 / 3.0 * p.y) / HEX_SIZE
	var r := (2.0 / 3.0 * p.y) / HEX_SIZE
	return _axial_round(q, r)

func _axial_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: float = roundf(q)
	var rr: float = roundf(r)
	var rs: float = roundf(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
