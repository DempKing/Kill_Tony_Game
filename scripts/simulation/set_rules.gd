class_name SetRules
extends RefCounted
## Setlists: ordered joke ids. Analysis covers duration vs. slot, familiarity,
## audience exposure and callback ordering.

const KT_MINUTE_ID := "kt_minute"
const DEFAULT_ID := "main_set"
const TOUR_ID := "tour_set"


static func ensure_defaults(s: GameState) -> void:
	if not s.setlists.has(DEFAULT_ID):
		s.setlists[DEFAULT_ID] = {"name": "Open mic set", "jokes": []}
	if not s.setlists.has(TOUR_ID):
		s.setlists[TOUR_ID] = {"name": "Road set (your best material)", "jokes": []}
	if not s.setlists.has(KT_MINUTE_ID):
		s.setlists[KT_MINUTE_ID] = {"name": "Prepared minute (Kill Tony)", "jokes": [], "protected": true}


static func jokes_in(s: GameState, setlist_id: String) -> Array:
	var out: Array = []
	for jid in s.setlists.get(setlist_id, {}).get("jokes", []):
		if s.jokes.has(str(jid)):
			out.append(str(jid))
	return out


static func save_setlist(s: GameState, setlist_id: String, name: String, joke_ids: Array) -> void:
	var clean: Array = []
	for j in joke_ids:
		if s.jokes.has(str(j)) and not clean.has(str(j)):
			clean.append(str(j))
	var entry: Dictionary = s.setlists.get(setlist_id, {})
	entry["name"] = name if name != "" else str(entry.get("name", "Set"))
	entry["jokes"] = clean
	s.setlists[setlist_id] = entry


## Returns warnings and totals. `venue` may be empty for a generic analysis.
static func analyze(s: GameState, db: ContentDB, joke_ids: Array, slot_seconds: int, venue_id: String = "") -> Dictionary:
	var total := 0
	var core_total := 0
	var fam_sum := 0.0
	var exposure_total := 0
	var warnings: Array = []
	var seen_families: Array = []
	var rows: Array = []
	for jid in joke_ids:
		var joke: Dictionary = s.jokes.get(str(jid), {})
		if joke.is_empty():
			continue
		var parts := JokeRules.parts_of(joke)
		var secs := JokeRules.seconds_of_parts(db, parts)
		var core := JokeRules.seconds_of_parts(db, parts, false)
		total += secs
		core_total += core
		fam_sum += float(joke.get("familiarity", 0))
		var exp_n: int = int(joke.get("exposure", {}).get(venue_id, 0)) if venue_id != "" else 0
		exposure_total += exp_n
		var st := JokeRules.status_of(db, joke)
		if st != "coherent":
			warnings.append("\"%s\" is %s." % [joke["title"], str(JokeRules.STATUS_LABEL.get(st, st)).to_lower()])
		var cb: String = str(parts.get("callback", ""))
		if cb != "":
			var ref: String = str(db.component(cb).get("callback_ref", ""))
			if ref != "" and not seen_families.has(ref):
				warnings.append("\"%s\" has a callback, but the joke it calls back to doesn't come earlier." % joke["title"])
		seen_families.append(JokeRules.family_of(db, joke))
		rows.append({"id": str(jid), "title": joke["title"], "seconds": secs, "core_seconds": core, "familiarity": int(joke.get("familiarity", 0)), "exposure": exp_n, "status": st})
	var count := rows.size()
	if count == 0:
		warnings.append("This set is empty.")
	if slot_seconds > 0:
		if core_total > slot_seconds:
			warnings.append("Even without tags, this runs %ds over the %ds slot. You'll get the light." % [core_total - slot_seconds, slot_seconds])
		elif total > slot_seconds:
			warnings.append("With every tag and act-out this runs %ds long. Skip extras on stage or trim." % (total - slot_seconds))
		elif count > 0 and total < int(slot_seconds * 0.5):
			warnings.append("This only fills %ds of a %ds slot." % [total, slot_seconds])
	var avg_fam := fam_sum / float(count) if count > 0 else 0.0
	if count > 0 and avg_fam < 20.0:
		warnings.append("You barely know this material. Rehearse first.")
	if exposure_total > 0:
		warnings.append("This room has already heard some of these jokes.")
	return {
		"seconds": total,
		"core_seconds": core_total,
		"slot_seconds": slot_seconds,
		"avg_familiarity": avg_fam,
		"exposure": exposure_total,
		"count": count,
		"rows": rows,
		"warnings": warnings,
		"opener": rows[0]["title"] if count > 0 else "",
		"closer": rows[count - 1]["title"] if count > 0 else "",
	}
