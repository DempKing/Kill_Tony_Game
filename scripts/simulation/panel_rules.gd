class_name PanelRules
extends RefCounted
## Phase 5: returning to Kill Tony as a panel guest. You react to bucket
## comics' minutes, contribute to their interviews, and can scout openers.
## Reactions and contributions are judged in context: roasting a cocky comic
## kills, roasting a fragile one makes the room turn on you.

const REACTIONS: Array = ["laugh", "polite", "stone"]
const REACTION_LABELS: Dictionary = {"laugh": "Laugh big", "polite": "Polite smile", "stone": "Stone face"}


## Generates tonight's comics. Stored by the caller before anything is shown.
static func generate(s: GameState, db: ContentDB, count: int = 3) -> Array:
	var r := s.rng("bucket")
	var pc: Dictionary = db.panel_comics
	var personas: Array = (pc.get("personas", {}) as Dictionary).keys()
	var bits: Array = (pc.get("bits", []) as Array).duplicate()
	var styles: Array = pc.get("styles", ["observational"])
	var out: Array = []
	for i in range(count):
		var first: Array = db.bucket_names.get("first", ["Sam"])
		var last: Array = db.bucket_names.get("last", ["Lee"])
		var bi := r.randi_range(0, bits.size() - 1)
		var c := {
			"id": "panel_%d_%d" % [s.day, i],
			"name": "%s %s" % [first[r.randi_range(0, first.size() - 1)], last[r.randi_range(0, last.size() - 1)]],
			"persona": str(personas[r.randi_range(0, personas.size() - 1)]),
			"style": str(styles[r.randi_range(0, styles.size() - 1)]),
			"quality": r.randi_range(20, 92),
			"bit": str(bits[bi]),
			"color": Color.from_hsv(r.randf(), 0.45, 0.8).to_html(false),
		}
		bits.remove_at(bi)
		out.append(c)
	return out


static func crowd_reaction(quality: int) -> String:
	if quality >= 75:
		return "The room explodes. The band hits a sting on its own."
	if quality >= 55:
		return "Solid laughs. A couple of real ones."
	if quality >= 40:
		return "Scattered laughs, one loud guy in the back carrying it."
	return "Silence. Somebody coughs. The bucket looks very full."


## Reacting honestly reads as credible; overselling a dud reads as fake.
static func score_reaction(comic: Dictionary, reaction: String) -> Dictionary:
	var q: int = int(comic["quality"])
	var v := 0.0
	var txt := ""
	match reaction:
		"laugh":
			v = 6.0 if q >= 65 else (1.0 if q >= 45 else -4.0)
			txt = "You're genuinely laughing." if q >= 65 else ("You laugh along. It's generous." if q >= 45 else "Your big laugh rings out alone. The crowd notices.")
		"polite":
			v = 2.0 if q >= 40 and q < 65 else 0.0
			txt = "A polite smile. Safe."
		"stone":
			v = 3.0 if q < 40 else (-1.0 if q < 65 else -5.0)
			txt = "Your stone face matches the room." if q < 40 else ("Stone face. A little cold." if q < 65 else "You don't crack. People think you're jealous.")
	return {"value": v, "text": txt}


## Interview contribution by tone, judged against the comic's persona and set.
static func score_contribution(s: GameState, db: ContentDB, comic: Dictionary, tone: String, tones_used: Array) -> Dictionary:
	var persona: Dictionary = db.panel_comics.get("personas", {}).get(str(comic["persona"]), {})
	var v := float(persona.get("tones", {}).get(tone, 0))
	var q: int = int(comic["quality"])
	if tone == "roast" and q >= 75:
		v -= 3.0  # Roasting someone who just killed looks petty.
	if tone == "support" and q < 35 and str(comic["persona"]) == "cocky":
		v -= 3.0
	v += StatsRules.skill(s, "crowd_work") / 20.0
	v -= tones_used.count(tone) * 4.0
	v += s.rng("performance").randf_range(-2.0, 2.0)
	var txt := "Huge laugh from the room. The host points at you." if v >= 7.0 else ("Good laugh. The comic laughs too." if v >= 3.0 else ("It lands flat." if v >= -1.0 else "Groans. The host steers away from you."))
	return {"value": v, "text": txt}


static func can_scout(comic: Dictionary) -> bool:
	return int(comic["quality"]) >= 68


## Adds a scouted comic to your opener candidates (once).
static func scout(s: GameState, comic: Dictionary) -> Dictionary:
	for o in s.discovered_openers:
		if str(o["id"]) == str(comic["id"]):
			return o
	var q: int = int(comic["quality"])
	var o := {
		"id": str(comic["id"]), "name": str(comic["name"]), "npc": "", "fee": 40 + q, "reliability": 50 + q / 3,
		"style": str(comic["style"]), "potential": "high" if q >= 80 else "medium", "from_panel": true, "breakout_shows": 5,
		"desc": "You spotted them on Kill Tony: %s." % comic["bit"],
	}
	s.discovered_openers.append(o)
	return o


## Resolves the night exactly once.
static func resolve(s: GameState, db: ContentDB, day: int, total: float) -> Array:
	if not RewardRules.claim(s, "panel_%d" % day):
		return []
	var out: Array = []
	s.stats["panel_sets"] = int(s.stats.get("panel_sets", 0)) + 1
	var fame := maxf(0.5, total * 0.25)
	s.fame += fame
	out.append("Being on the panel puts you in front of the whole audience: fame +%.1f." % fame)
	if total >= 15.0:
		Relationships.change(s, "partner_host", {"respect": 6, "chemistry": 5})
		Relationships.change(s, "partner_redban", {"respect": 4})
		s.reputation += 2.0
		out.append("The host loved having you. You'll be asked back.")
		s.flags["panel_invite_again"] = true
	elif total < 0.0:
		Relationships.change(s, "partner_host", {"respect": -4})
		out.append("It wasn't your night on the panel. Nobody's mentioning a return visit.")
	else:
		Relationships.change(s, "partner_host", {"respect": 2})
		out.append("A solid night on the panel.")
	return out
