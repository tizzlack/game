# Zustand des aktuellen Runs: Welt/Abschnitt, Karten, Werte, Punkte, Credits.
extends Node

const Data = preload("res://scripts/core/data.gd")

const SECTIONS_PER_WORLD := 4  # 3 normale Abschnitte + Boss
const WORLDS := 3

var active := false
var seed_value := 0
var rng := RandomNumberGenerator.new()
var world := 0
var section := 0
var loop := 0
var heat := 0
var daily := false
var endless := false
var weapon_id := "blaster"
var mutators: Array = []
var cards := {}
var card_order: Array = []
var stats := {}
var hp := 100.0
var score := 0
var credits := 0
var kills := 0
var combo := 0
var best_combo := 0
var time := 0.0
var section_time := 0.0
var section_damage := 0.0
var sections_cleared := 0
var bosses := 0
var revives_left := 0
var free_rerolls := 0
var rerolls_paid := 0
var won := false
var new_achievements: Array = []

func start(opts: Dictionary) -> void:
	active = true
	daily = opts.get("daily", false)
	heat = opts.get("heat", 0)
	weapon_id = opts.get("weapon", "blaster")
	mutators = opts.get("mutators", []).duplicate()
	if daily:
		var day := Save.today()
		seed_value = hash("glowline-daily-" + day)
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		weapon_id = Data.WEAPON_ORDER[r.randi() % 3]
		mutators = [Data.MUTATOR_ORDER[r.randi() % Data.MUTATOR_ORDER.size()]]
		heat = 1
	else:
		seed_value = opts.get("seed", randi())
	rng.seed = seed_value
	world = 0
	section = 0
	loop = 0
	endless = false
	cards = {}
	card_order = []
	score = 0
	credits = 0
	kills = 0
	combo = 0
	best_combo = 0
	time = 0.0
	sections_cleared = 0
	bosses = 0
	won = false
	new_achievements = []
	stats = base_stats()
	hp = stats["max_hp"]
	revives_left = Save.upgrade_level("revive")
	free_rerolls = Save.upgrade_level("reroll")
	rerolls_paid = 0
	for i in Save.upgrade_level("startcard"):
		var pick := roll_cards(1, 0)
		if pick.size() > 0:
			apply_card(pick[0])
	Save.add_stat("runs", 1)
	Save.save_data()

func base_stats() -> Dictionary:
	var s := {
		"dmg_mult": 1.0 + 0.06 * Save.upgrade_level("calib"),
		"rate_mult": 1.0 + 0.05 * Save.upgrade_level("clock"),
		"speed_mult": 1.0,
		"extra_proj": 0, "pierce": 0, "bounce": 0, "explode": 0.0,
		"crit": 0.05, "crit_mult": 2.0, "lifesteal": 0.0,
		"max_hp": 100.0 + 10.0 * Save.upgrade_level("hull"),
		"move_mult": 1.0, "air_jumps": 0,
		"dash_cd_mult": 1.0 - 0.08 * Save.upgrade_level("dashcore"),
		"dash_dmg": 0.0,
		"magnet": 1.0 + 0.15 * Save.upgrade_level("magnet"),
		"credit_mult": 1.0 + 0.08 * Save.upgrade_level("investor"),
		"shield": 0, "chain": 0.0, "homing": false, "combo_window": 2.5,
		"adrenaline": false, "grav_mult": 1.0, "enemy_speed": 1.0, "enemy_count": 1.0,
		"heal_mult": 1.0, "dmg_taken": 1.0,
	}
	for m in mutators:
		s["credit_mult"] += Data.MUTATORS[m]["bonus"]
		match m:
			"lowgrav":
				s["grav_mult"] = 0.62
			"glasscannon":
				s["dmg_mult"] *= 2.0
				s["max_hp"] *= 0.5
			"swarm":
				s["enemy_count"] = 1.6
			"ricochet":
				s["bounce"] += 2
			"turbo":
				s["enemy_speed"] = 1.35
				s["move_mult"] = 1.12
			"famine":
				s["heal_mult"] = 0.0
				s["lifesteal"] += 1.0
	s["credit_mult"] += 0.15 * heat
	return s

func apply_card(id: String) -> void:
	cards[id] = int(cards.get(id, 0)) + 1
	card_order.append(id)
	var s := stats
	match id:
		"overload": s["dmg_mult"] += 0.2
		"rapid": s["rate_mult"] += 0.15
		"velocity":
			s["speed_mult"] += 0.25
			s["dmg_mult"] += 0.1
		"crit": s["crit"] += 0.1
		"armor":
			s["max_hp"] += 25.0
			hp += 25.0
		"sprinter": s["move_mult"] += 0.1
		"phase": s["dash_cd_mult"] *= 0.75
		"magnet": s["magnet"] += 0.5
		"greed": s["credit_mult"] += 0.2
		"combo": s["combo_window"] += 1.0
		"medkit": hp = minf(hp + 40.0, s["max_hp"])
		"twin": s["extra_proj"] += 1
		"pierce": s["pierce"] += 1
		"bounce": s["bounce"] += 1
		"vampire": s["lifesteal"] += 2.0
		"djump": s["air_jumps"] += 1
		"bladedash": s["dash_dmg"] += 30.0
		"adrenaline": s["adrenaline"] = true
		"explosive": s["explode"] += 50.0 if s["explode"] == 0.0 else 20.0
		"shield": s["shield"] += 1
		"chain": s["chain"] += 0.15
		"homing": s["homing"] = true
		"glass":
			s["dmg_mult"] += 0.5
			s["max_hp"] *= 0.7
			hp = minf(hp, s["max_hp"])
	if card_order.size() >= 12:
		achievement("build")

func card_available(id: String) -> bool:
	if int(cards.get(id, 0)) >= Data.CARDS[id]["max"]:
		return false
	if id == "medkit" and hp > stats["max_hp"] * 0.7:
		return false
	return true

# Zieht n verschiedene Karten, gewichtet nach Seltenheit. min_rarity für Boss-Belohnungen.
func roll_cards(n: int, min_rarity: int = 0) -> Array:
	var pool: Array = []
	var weights: Array = []
	for id in Data.CARDS.keys():
		var r: int = Data.CARDS[id]["rarity"]
		if r < min_rarity or not card_available(id):
			continue
		pool.append(id)
		weights.append(Data.RARITY_WEIGHTS[r])
	var out: Array = []
	while out.size() < n and pool.size() > 0:
		var total := 0.0
		for w in weights:
			total += w
		var pick := rng.randf() * total
		var idx := 0
		while idx < weights.size() - 1 and pick > weights[idx]:
			pick -= weights[idx]
			idx += 1
		out.append(pool[idx])
		pool.remove_at(idx)
		weights.remove_at(idx)
	return out

func card_choices() -> int:
	return 3 + Save.upgrade_level("choice")

func reroll_cost() -> int:
	return 0 if free_rerolls > 0 else 30 * (rerolls_paid + 1)

func difficulty() -> float:
	return world + loop * 3.0 + section * 0.35 + heat * 0.6

func is_boss() -> bool:
	return section == SECTIONS_PER_WORLD - 1

func palette_index() -> int:
	return 3 if loop > 0 and world == 1 else world

func section_seed() -> int:
	return hash([seed_value, world, section, loop])

func label() -> String:
	var t := "%d-%d" % [world + 1, section + 1]
	if loop > 0:
		t = "L%d %s" % [loop + 1, t]
	return t

# Nach geschafftem Abschnitt. Gibt true zurück, wenn der Run gewonnen ist (Ende von Welt 3).
func advance() -> bool:
	sections_cleared += 1
	free_rerolls = Save.upgrade_level("reroll")
	section += 1
	if section >= SECTIONS_PER_WORLD:
		section = 0
		world += 1
		if world == 1:
			achievement("world_1")
		elif world == 2:
			achievement("world_2")
		if world >= WORLDS:
			world = 0
			loop += 1
			if loop == 1 and not endless:
				return true
			achievement("loop")
	return false

func start_endless() -> void:
	endless = true
	world = 0
	section = 0

func add_score(v: int) -> void:
	score += v

func add_kill(base_score: int) -> int:
	kills += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	if combo >= 15:
		achievement("combo_15")
	if combo >= 40:
		achievement("combo_40")
	var mult := combo_mult()
	var v := int(round(base_score * mult * (1.0 + heat * 0.2)))
	score += v
	if kills == 1:
		achievement("first_blood")
	return v

func combo_mult() -> float:
	return 1.0 + minf(combo, 50) * 0.1

func achievement(id: String) -> void:
	if Save.unlock_achievement(id):
		new_achievements.append(id)

# Run beenden: Credits gutschreiben, Statistik speichern. Gibt Zusammenfassung zurück.
func finish(victory: bool) -> Dictionary:
	if not active:
		return {}
	active = false
	won = victory
	var bonus := 0
	if victory:
		bonus = int(credits * 0.25)
	var total := credits + bonus
	Save.add_bank(total)
	Save.add_stat("kills", kills)
	Save.add_stat("play_time", time)
	Save.add_stat("bosses", bosses)
	Save.max_stat("best_combo", best_combo)
	if victory:
		Save.add_stat("wins", 1)
		Save.max_stat("best_heat_won", heat)
		achievement("win")
		if heat >= 3:
			achievement("heat_3")
	else:
		Save.add_stat("deaths", 1)
	if loop > 0:
		Save.max_stat("loops", loop)
	var total_kills: int = Save.stat("kills")
	if total_kills >= 100:
		achievement("kills_100")
	if total_kills >= 1000:
		achievement("kills_1000")
	var is_best := Save.max_stat("best_score", score)
	var daily_best := false
	if daily:
		daily_best = Save.record_daily(score)
		SteamService.upload_score("daily_" + Save.today(), score)
	SteamService.upload_score("highscore", score)
	Save.save_data()
	return {"victory": victory, "score": score, "kills": kills, "best_combo": best_combo, "time": time,
		"credits": credits, "bonus": bonus, "total": total, "best": is_best, "daily_best": daily_best,
		"achievements": new_achievements.duplicate(), "label": label(), "loop": loop}
