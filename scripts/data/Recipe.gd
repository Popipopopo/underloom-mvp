class_name Recipe
extends RefCounted

# id / display
var id: String = ""
var display_name: String = ""

# "main" / "support"
var core_type: String = "main"

# main
var attack_pattern: String = "bullet"   # bullet / ball / chain / arrow
var max_ammo: int = 30
var base_charge: float = 0.3

# support (MVP: fixed value from recipe, pools only gate what you can put in)
var support_effect: String = "amp"      # WandController match strings
var support_value: float = 0.2

# e.g. ["damage","damage","range"]
var slots: Array = []

# factory from dict for RecipeDB
static func from_dict(d: Dictionary) -> Recipe:
	var r := Recipe.new()
	r.id = str(d.get("id", ""))
	r.display_name = str(d.get("display_name", r.id))
	r.core_type = str(d.get("core_type", "main"))
	r.attack_pattern = str(d.get("attack_pattern", "bullet"))
	r.max_ammo = int(d.get("max_ammo", 30))
	r.base_charge = float(d.get("base_charge", 0.3))
	r.support_effect = str(d.get("support_effect", "amp"))
	r.support_value = float(d.get("support_value", 0.2))
	var sl = d.get("slots", [])
	r.slots = sl.duplicate() if sl is Array else []
	return r
