class_name CraftingMaterial
extends RefCounted

var id: String = ""
var display_name: String = ""
# tag list e.g. ["真菌", "食材"]
var tags: Array[String] = []
# element → max units  e.g. {"风": 2, "土": 1}
var elements_max: Dictionary = {}
# guaranteed element (at least 1 unit always rolls)
var default_element: String = ""
# level 1-40
var lv: int = 1

static func make(
	p_id: String,
	p_name: String,
	p_tags: Array,
	p_elements_max: Dictionary,
	p_default_element: String,
	p_lv: int
) -> CraftingMaterial:
	var m := CraftingMaterial.new()
	m.id = p_id
	m.display_name = p_name
	for t in p_tags:
		m.tags.append(str(t))
	m.elements_max = p_elements_max.duplicate()
	m.default_element = p_default_element
	m.lv = p_lv
	return m

func has_tag(t: String) -> bool:
	return tags.has(t)

## Return a summary string for UI display
func summary() -> String:
	var el_parts: Array[String] = []
	for k in elements_max.keys():
		el_parts.append("%s×%d" % [k, elements_max[k]])
	return "Lv%d  [%s]  元素:%s  保底:%s" % [lv, ", ".join(tags), ", ".join(el_parts), default_element]
