class_name Recipe
extends RefCounted

var id: String = ""
var display_name: String = ""

# Each entry is a tag String that the material placed in that slot must have.
# e.g. ["魔物", "真菌", "矿物"]
var slot_tags: Array[String] = []

## Number of ingredient slots
func slot_count() -> int:
	return slot_tags.size()

## Check whether a CraftingMaterial satisfies the requirement for slot_index
func slot_accepts(slot_index: int, mat: CraftingMaterial) -> bool:
	if slot_index < 0 or slot_index >= slot_tags.size():
		return false
	return mat.has_tag(slot_tags[slot_index])

static func make(p_id: String, p_name: String, p_slot_tags: Array) -> Recipe:
	var r := Recipe.new()
	r.id = p_id
	r.display_name = p_name
	for t in p_slot_tags:
		r.slot_tags.append(str(t))
	return r
