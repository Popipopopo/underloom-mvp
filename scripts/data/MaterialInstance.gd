class_name MaterialInstance
extends RefCounted

## 一份已采集定型的材料。
## v1.1 原设计：roll 发生在采集那一刻，入包后元素固定——
## 合成阶段不再有任何 roll。参考炼金工房：每份素材是独立卡片。

static var _next_uid: int = 1

var uid: int = 0
var base_id: String = ""
var elements: Array = []   # 定型元素，如 ["土", "土", "风"]

func base() -> CraftingMaterial:
	return MaterialDB.get_material(base_id)

func display_name() -> String:
	var mat := base()
	return mat.display_name if mat != null else base_id

## 采集 roll：保底元素必出 1 个，其余每单位以 richness 概率出现。
## richness 由采集区域丰度决定（低层贫瘠、高层丰饶），
## 节点地图接入前调用方传固定值即可。
static func roll_from(mat: CraftingMaterial, richness: float = 0.5) -> MaterialInstance:
	var inst := MaterialInstance.new()
	inst.uid = _next_uid
	_next_uid += 1
	inst.base_id = mat.id
	inst.elements.append(mat.default_element)
	for el in mat.elements_max.keys():
		var max_units: int = int(mat.elements_max[el])
		var already: int = 1 if el == mat.default_element else 0
		for _u in range(already, max_units):
			if randf() < richness:
				inst.elements.append(el)
	return inst
