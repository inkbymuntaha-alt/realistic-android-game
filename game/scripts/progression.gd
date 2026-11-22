extends Node
## Levels, personal bests, unlocks. Fair progression: no energy, streaks or timers.

const LEVELS := [
	{"id": 1, "pieces": 6, "target": 0.6, "wind": 0.0},
	{"id": 2, "pieces": 7, "target": 0.8, "wind": 0.0},
	{"id": 3, "pieces": 8, "target": 1.0, "wind": 0.0},
	{"id": 4, "pieces": 8, "target": 1.1, "wind": 0.4},
	{"id": 5, "pieces": 9, "target": 1.3, "wind": 0.6},
	{"id": 6, "pieces": 10, "target": 1.5, "wind": 0.8},
]

func level(id: int) -> Dictionary:
	return LEVELS[clampi(id - 1, 0, LEVELS.size() - 1)]

func is_unlocked(id: int) -> bool:
	return id <= int(Save.data.get("unlocked_level", 1))

## Returns true if the level target was reached (and unlocks the next level).
func submit_result(id: int, height: float) -> bool:
	var key := str(id)
	var bests: Dictionary = Save.data["best_heights"]
	if height > float(bests.get(key, 0.0)):
		bests[key] = snappedf(height, 0.01)
	var passed := height >= float(level(id)["target"])
	if passed and id >= int(Save.data["unlocked_level"]) and id < LEVELS.size():
		Save.data["unlocked_level"] = id + 1
	Save.save_game()
	return passed

## Same daily puzzle for everyone on a date; missing a day costs nothing.
static func daily_seed(date: Dictionary) -> int:
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])
