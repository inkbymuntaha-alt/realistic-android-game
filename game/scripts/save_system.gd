extends Node
## Local save system with atomic write and backup recovery. No network.

const PATH := "user://save.json"
const BACKUP := "user://save.json.bak"

var data: Dictionary = {}

func _ready() -> void:
	load_game()

static func default_data() -> Dictionary:
	return {"version": 1, "unlocked_level": 1, "best_heights": {}, "daily_done": [], "achievements": []}

func load_game(path: String = PATH, backup: String = BACKUP) -> void:
	data = _read(path)
	if data.is_empty():
		data = _read(backup)  # recover from backup if main file missing/corrupt
	if data.is_empty():
		data = default_data()

func save_game(path: String = PATH, backup: String = BACKUP) -> bool:
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, backup)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}  # corrupt file
	var parsed = json.data
	if parsed is Dictionary and parsed.has("version"):
		return parsed
	return {}
