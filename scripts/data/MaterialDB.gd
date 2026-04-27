class_name MaterialDB
extends Node

const _MATERIALS := {
	"firefly_crystal": {
		"name": "Firefly Crystal",
		"desc": "A warm crystal dust for damage pool",
		"tier": 1,
		"slot_type": "damage",
		"contribution": 10,
		"element": ""
	},
	"bolt_shard": {
		"name": "Bolt Shard",
		"desc": "An electric shard with high damage contribution",
		"tier": 2,
		"slot_type": "damage",
		"contribution": 25,
		"element": ""
	},
	"spread_powder": {
		"name": "Spread Powder",
		"desc": "Powder that increases spell spread/range",
		"tier": 1,
		"slot_type": "range",
		"contribution": 10,
		"element": ""
	},
	"mirror_shard": {
		"name": "Mirror Shard",
		"desc": "A reflective shard for special pool",
		"tier": 2,
		"slot_type": "special",
		"contribution": 15,
		"element": ""
	},
	"fire_essence": {
		"name": "Fire Essence",
		"desc": "Condensed elemental fire core",
		"tier": 2,
		"slot_type": "element",
		"contribution": 0,
		"element": "fire"
	},
	"slime_gel": {
		"name": "Slime Gel",
		"desc": "Low-tier sticky material from slime",
		"tier": 1,
		"slot_type": "range",
		"contribution": 8,
		"element": ""
	},
	"mana_dust": {
		"name": "Mana Dust",
		"desc": "Basic mana residue in caves",
		"tier": 1,
		"slot_type": "damage",
		"contribution": 5,
		"element": ""
	},
	"ancient_seal": {
		"name": "Ancient Seal",
		"desc": "Sealed essence dropped by the gatekeeper boss. Picking it up ends the demo.",
		"tier": 3,
		"slot_type": "special",
		"contribution": 40,
		"element": ""
	}
}

static func get_contribution(id: String) -> int:
	return int(get_data(id).get("contribution", 0))


static func has(id: String) -> bool:
	return _MATERIALS.has(id)

static func get_data(id: String) -> Dictionary:
	if not _MATERIALS.has(id):
		return {}
	return _MATERIALS[id].duplicate(true)

static func make_material(id: String) -> CraftingMaterial:
	var d := get_data(id)
	if d.is_empty():
		return null
	return CraftingMaterial.make(
		id,
		d["name"],
		d["desc"],
		d["tier"],
		d["slot_type"],
		d["contribution"],
		d["element"]
	)

static func get_all_ids() -> Array:
	return _MATERIALS.keys()