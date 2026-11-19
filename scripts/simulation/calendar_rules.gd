class_name CalendarRules
extends RefCounted
## Seven-day weeks, four blocks per day. Day 0 is the arrival day.

const BLOCK_NAMES: Array = ["Morning", "Afternoon", "Evening", "Late Night"]
const DAY_NAMES: Array = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAY_SHORT: Array = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const BLOCKS_PER_DAY: int = 4
const START_WEEKDAY: int = 2  # The player arrives on a Wednesday.
const MONDAY: int = 0
const THURSDAY: int = 3


static func weekday(day: int) -> int:
	return (START_WEEKDAY + day) % 7


static func day_name(day: int) -> String:
	return DAY_NAMES[weekday(day)]


static func day_short(day: int) -> String:
	return DAY_SHORT[weekday(day)]


static func block_name(block: int) -> String:
	return BLOCK_NAMES[clampi(block, 0, 3)]


static func slot(day: int, block: int) -> int:
	return day * BLOCKS_PER_DAY + block


static func slot_day(s: int) -> int:
	return s / BLOCKS_PER_DAY


static func slot_block(s: int) -> int:
	return s % BLOCKS_PER_DAY


static func week_number(day: int) -> int:
	return day / 7 + 1


## First day >= from_day that falls on the given weekday.
static func next_weekday(from_day: int, wd: int) -> int:
	var d := from_day
	while weekday(d) != wd:
		d += 1
	return d


static func describe(day: int, block: int) -> String:
	return "%s (Day %d) · %s" % [day_name(day), day + 1, block_name(block)]


static func describe_slot(day: int, block: int) -> String:
	return "%s Day %d, %s" % [day_short(day), day + 1, block_name(block)]
