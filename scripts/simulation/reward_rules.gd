class_name RewardRules
extends RefCounted
## Exactly-once resolution for rewards and payments. Every reward or payment
## has a stable claim id; claim() returns true only the first time.


static func claim(s: GameState, claim_id: String) -> bool:
	if s.claimed.has(claim_id):
		return false
	s.claimed[claim_id] = s.day
	return true


static func is_claimed(s: GameState, claim_id: String) -> bool:
	return s.claimed.has(claim_id)


static func grant_book(s: GameState, book_id: String) -> void:
	if not s.books.has(book_id):
		s.books.append(book_id)
	# The original journal is never removed; it stays as a sentimental item.
	if not s.books.has("starter_journal"):
		s.books.push_front("starter_journal")


## Pays a booking exactly once.
static func pay_booking(s: GameState, commitment_id: String, amount: int, reason: String) -> bool:
	if amount <= 0:
		return claim(s, "pay_" + commitment_id)
	if not claim(s, "pay_" + commitment_id):
		return false
	StatsRules.add_cash(s, amount, reason)
	return true
