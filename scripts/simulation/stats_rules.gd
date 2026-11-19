class_name StatsRules
extends RefCounted
## Cash, energy, stress, confidence and skills. Every cash change goes through
## the ledger so finances can be reviewed and tested.


static func add_cash(s: GameState, amount: int, reason: String) -> void:
	if amount == 0:
		return
	s.cash += amount
	s.ledger.append({"day": s.day, "block": s.block, "amount": amount, "reason": reason, "balance": s.cash})
	while s.ledger.size() > 400:
		s.ledger.pop_front()


## Charges only when affordable. Returns false (and changes nothing) otherwise.
static func charge(s: GameState, amount: int, reason: String) -> bool:
	if amount <= 0:
		return true
	if s.cash < amount:
		return false
	add_cash(s, -amount, reason)
	return true


static func change_energy(s: GameState, delta: int) -> void:
	s.energy = clampi(s.energy + delta, 0, 100)


static func change_stress(s: GameState, delta: int) -> void:
	s.stress = clampi(s.stress + delta, 0, 100)


static func change_confidence(s: GameState, delta: int) -> void:
	s.confidence = clampi(s.confidence + delta, 0, 100)


static func add_skill(s: GameState, skill: String, amount: float) -> void:
	s.skills[skill] = clampf(float(s.skills.get(skill, 0.0)) + amount, 0.0, 100.0)


static func skill(s: GameState, name: String) -> float:
	return float(s.skills.get(name, 0.0))


## Generic effect processor shared by shift events, world events and dialogue.
## Supported keys: cash, pay, tips, energy, stress, confidence, rep, fame,
## reliability (needs job_id), skill{}, rel{}, unlock[], flag{}.
static func apply_effects(s: GameState, db: ContentDB, fx: Dictionary, job_id: String = "", reason: String = "event") -> Array:
	var notes: Array = []
	if fx.has("cash"):
		var amt: int = int(fx["cash"])
		if amt < 0:
			amt = -mini(-amt, s.cash)  # never below zero from an event
		add_cash(s, amt, reason)
		if amt != 0:
			notes.append("%s$%d" % ["+" if amt > 0 else "-", absi(amt)])
	if fx.has("energy"):
		change_energy(s, int(fx["energy"]))
	if fx.has("stress"):
		change_stress(s, int(fx["stress"]))
	if fx.has("confidence"):
		change_confidence(s, int(fx["confidence"]))
	if fx.has("rep"):
		s.reputation = maxf(0.0, s.reputation + float(fx["rep"]))
	if fx.has("fame"):
		s.fame = maxf(0.0, s.fame + float(fx["fame"]))
	if fx.has("reliability") and job_id != "" and s.jobs.has(job_id):
		var j: Dictionary = s.jobs[job_id]
		j["reliability"] = clampi(int(j.get("reliability", 0)) + int(fx["reliability"]), 0, 100)
	for sk in fx.get("skill", {}):
		add_skill(s, str(sk), float(fx["skill"][sk]))
	for npc in fx.get("rel", {}):
		Relationships.change(s, str(npc), fx["rel"][npc])
	for cid in fx.get("unlock", []):
		if JokeRules.unlock_component(s, db, str(cid)):
			notes.append("New material: \"%s\"" % str(db.component(str(cid)).get("text", cid)))
	for k in fx.get("flag", {}):
		s.flags[str(k)] = fx["flag"][k]
	return notes
