extends Node
## Player settings: audio levels, haptics, reduced motion, graphics quality.
## Persisted to user://settings.cfg. Works fully offline.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High"]

var music_volume := 0.6
var sfx_volume := 0.8
var ambient_volume := 0.6
var vibration := true
var reduced_motion := false
var quality := 1  # index into QUALITY_NAMES
var muted := false

func _ready() -> void:
	load_settings()

func load_settings(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return  # first run or corrupt file: keep defaults
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	ambient_volume = clampf(float(cfg.get_value("audio", "ambient", ambient_volume)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", muted))
	vibration = bool(cfg.get_value("access", "vibration", vibration))
	reduced_motion = bool(cfg.get_value("access", "reduced_motion", reduced_motion))
	quality = clampi(int(cfg.get_value("graphics", "quality", quality)), 0, QUALITY_NAMES.size() - 1)
	changed.emit()

func save_settings(path: String = PATH) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ambient", ambient_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("access", "vibration", vibration)
	cfg.set_value("access", "reduced_motion", reduced_motion)
	cfg.set_value("graphics", "quality", quality)
	return cfg.save(path) == OK
