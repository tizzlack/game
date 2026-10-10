# Alle Spieldaten an einem Ort: Waffen, Werkstatt-Upgrades, Run-Karten, Erfolge, Skins, Modifikatoren.
# Texte stehen in loc.gd unter den Schlüsseln "weapon_<id>", "card_<id>", "card_<id>_d" usw.
extends RefCounted

const WEAPON_ORDER := ["blaster", "scatter", "pulse", "rail", "rocket"]

const WEAPONS := {
	"blaster": {"cost": 0, "dmg": 10.0, "rate": 7.0, "speed": 1500.0, "spread": 2.0, "count": 1, "life": 0.9,
		"pierce": 0, "explode": 0.0, "color": Color(0.4, 0.85, 1.0), "sfx": "shoot_blaster", "width": 3.0, "length": 42.0, "shake": 0.0, "carve": 7.0},
	"scatter": {"cost": 600, "dmg": 6.5, "rate": 1.9, "speed": 1300.0, "spread": 13.0, "count": 6, "life": 0.34,
		"pierce": 0, "explode": 0.0, "color": Color(1.0, 0.78, 0.3), "sfx": "shoot_scatter", "width": 2.6, "length": 18.0, "shake": 0.18, "carve": 5.0},
	"pulse": {"cost": 900, "dmg": 4.6, "rate": 15.0, "speed": 1650.0, "spread": 6.0, "count": 1, "life": 0.7,
		"pierce": 0, "explode": 0.0, "color": Color(0.55, 1.0, 0.5), "sfx": "shoot_pulse", "width": 2.4, "length": 28.0, "shake": 0.0, "carve": 4.5},
	"rail": {"cost": 1500, "dmg": 44.0, "rate": 1.25, "speed": 4200.0, "spread": 0.0, "count": 1, "life": 0.45,
		"pierce": 6, "explode": 0.0, "color": Color(1.0, 0.45, 1.0), "sfx": "shoot_rail", "width": 4.0, "length": 90.0, "shake": 0.25, "carve": 12.0},
	"rocket": {"cost": 2200, "dmg": 24.0, "rate": 1.15, "speed": 850.0, "spread": 1.0, "count": 1, "life": 1.6,
		"pierce": 0, "explode": 95.0, "color": Color(1.0, 0.55, 0.2), "sfx": "shoot_rocket", "width": 5.0, "length": 22.0, "shake": 0.15, "carve": 0.0},
}

# Dauerhafte Upgrades aus der Werkstatt. Preis = base * 1.55^Stufe
const META_ORDER := ["hull", "calib", "clock", "dashcore", "magnet", "investor", "reroll", "startcard", "choice", "revive"]
const META := {
	"hull": {"base": 80, "max": 10},
	"calib": {"base": 120, "max": 10},
	"clock": {"base": 120, "max": 10},
	"dashcore": {"base": 100, "max": 5},
	"magnet": {"base": 60, "max": 5},
	"investor": {"base": 150, "max": 10},
	"reroll": {"base": 300, "max": 3},
	"startcard": {"base": 400, "max": 3},
	"choice": {"base": 1500, "max": 1},
	"revive": {"base": 2000, "max": 1},
}

# Run-Karten. rarity: 0 normal, 1 selten, 2 episch. max = maximale Stapel.
const CARDS := {
	"overload": {"rarity": 0, "max": 10},
	"rapid": {"rarity": 0, "max": 10},
	"velocity": {"rarity": 0, "max": 5},
	"crit": {"rarity": 0, "max": 5},
	"armor": {"rarity": 0, "max": 10},
	"sprinter": {"rarity": 0, "max": 3},
	"phase": {"rarity": 0, "max": 3},
	"magnet": {"rarity": 0, "max": 3},
	"greed": {"rarity": 0, "max": 5},
	"combo": {"rarity": 0, "max": 3},
	"medkit": {"rarity": 0, "max": 99},
	"twin": {"rarity": 1, "max": 3},
	"pierce": {"rarity": 1, "max": 3},
	"bounce": {"rarity": 1, "max": 3},
	"vampire": {"rarity": 1, "max": 5},
	"djump": {"rarity": 1, "max": 2},
	"bladedash": {"rarity": 1, "max": 3},
	"adrenaline": {"rarity": 1, "max": 1},
	"explosive": {"rarity": 2, "max": 3},
	"shield": {"rarity": 2, "max": 3},
	"chain": {"rarity": 2, "max": 3},
	"homing": {"rarity": 2, "max": 1},
	"glass": {"rarity": 2, "max": 1},
}

const RARITY_COLORS := [Color(0.55, 0.9, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.75, 0.25)]
const RARITY_WEIGHTS := [70.0, 24.0, 8.0]

# Erfolge: id -> Steam-API-Name
const ACHIEVEMENTS := {
	"first_blood": "ACH_FIRST_BLOOD",
	"kills_100": "ACH_KILLS_100",
	"kills_1000": "ACH_KILLS_1000",
	"combo_15": "ACH_COMBO_15",
	"combo_40": "ACH_COMBO_40",
	"world_1": "ACH_WORLD_1",
	"world_2": "ACH_WORLD_2",
	"win": "ACH_WIN",
	"heat_3": "ACH_HEAT_3",
	"loop": "ACH_LOOP",
	"daily": "ACH_DAILY",
	"untouched": "ACH_UNTOUCHED",
	"rich": "ACH_RICH",
	"arsenal": "ACH_ARSENAL",
	"build": "ACH_BUILD",
	"boss_fast": "ACH_BOSS_FAST",
}
const ACH_ORDER := ["first_blood", "kills_100", "kills_1000", "combo_15", "combo_40", "world_1", "world_2", "win",
	"heat_3", "loop", "daily", "untouched", "rich", "arsenal", "build", "boss_fast"]

# Skins: Leuchtfarbe der Spielfigur, freigeschaltet durch Erfolge
const SKIN_ORDER := ["frost", "mint", "ember", "violet", "gold", "crimson", "prism"]
const SKINS := {
	"frost": {"color": Color(0.75, 0.9, 1.0), "ach": ""},
	"mint": {"color": Color(0.5, 1.0, 0.75), "ach": "kills_100"},
	"ember": {"color": Color(1.0, 0.6, 0.3), "ach": "world_1"},
	"violet": {"color": Color(0.8, 0.55, 1.0), "ach": "daily"},
	"gold": {"color": Color(1.0, 0.85, 0.35), "ach": "win"},
	"crimson": {"color": Color(1.0, 0.35, 0.4), "ach": "heat_3"},
	"prism": {"color": Color(1.0, 1.0, 1.0), "ach": "loop"},
}

# Modifikatoren: verändern den Run, geben Credit-Bonus
const MUTATOR_ORDER := ["lowgrav", "glasscannon", "swarm", "ricochet", "turbo", "famine"]
const MUTATORS := {
	"lowgrav": {"bonus": 0.10},
	"glasscannon": {"bonus": 0.30},
	"swarm": {"bonus": 0.40},
	"ricochet": {"bonus": 0.0},
	"turbo": {"bonus": 0.25},
	"famine": {"bonus": 0.30},
}

const MAX_HEAT := 5

# Farbwelten. Index 3 = Endlos-Modus.
const PALETTES := [
	{"name": "world_0", "sky_top": Color(0.0, 0.0, 0.0), "sky_bottom": Color(0.005, 0.005, 0.02), "ground": Color(0.9, 0.97, 1.0),
		"fill": Color(0.0, 0.0, 0.006), "ledge": Color(0.4, 1.0, 0.65), "building": Color(0.4, 1.0, 0.7), "window": Color(1.0, 0.62, 0.25),
		"ember": Color(1.0, 0.45, 0.3), "star": Color(0.75, 0.85, 1.0), "enemy": Color(1.0, 0.25, 0.38), "accent": Color(0.3, 0.8, 1.0)},
	{"name": "world_1", "sky_top": Color(0.02, 0.01, 0.0), "sky_bottom": Color(0.07, 0.035, 0.012), "ground": Color(1.0, 0.95, 0.88),
		"fill": Color(0.035, 0.018, 0.006), "ledge": Color(0.45, 1.0, 0.8), "building": Color(1.0, 0.8, 0.5), "window": Color(1.0, 0.75, 0.3),
		"ember": Color(1.0, 0.6, 0.25), "star": Color(1.0, 0.8, 0.6), "enemy": Color(1.0, 0.3, 0.3), "accent": Color(1.0, 0.7, 0.3)},
	{"name": "world_2", "sky_top": Color(0.0, 0.01, 0.005), "sky_bottom": Color(0.02, 0.0, 0.03), "ground": Color(0.75, 1.0, 0.75),
		"fill": Color(0.0, 0.012, 0.004), "ledge": Color(0.9, 0.55, 1.0), "building": Color(0.6, 1.0, 0.45), "window": Color(0.85, 0.45, 1.0),
		"ember": Color(0.6, 1.0, 0.4), "star": Color(0.7, 1.0, 0.8), "enemy": Color(1.0, 0.3, 0.65), "accent": Color(0.6, 1.0, 0.4)},
	{"name": "world_3", "sky_top": Color(0.01, 0.0, 0.015), "sky_bottom": Color(0.035, 0.0, 0.045), "ground": Color(1.0, 0.75, 1.0),
		"fill": Color(0.012, 0.0, 0.016), "ledge": Color(0.4, 0.9, 1.0), "building": Color(1.0, 0.5, 0.9), "window": Color(0.4, 0.9, 1.0),
		"ember": Color(1.0, 0.4, 0.9), "star": Color(1.0, 0.8, 1.0), "enemy": Color(1.0, 0.85, 0.3), "accent": Color(1.0, 0.45, 1.0)},
]

static func meta_cost(id: String, level: int) -> int:
	return int(round(META[id]["base"] * pow(1.55, level) / 10.0) * 10)
