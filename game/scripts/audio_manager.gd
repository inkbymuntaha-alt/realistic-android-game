extends Node
## Audio buses (Music / SFX / Ambient) driven by Settings. Audio is never required to play.
## Real audio assets must be original or properly licensed; none are bundled yet (see ROADMAP).

func _ready() -> void:
	for bus_name in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	Settings.changed.connect(apply_settings)
	apply_settings()

func apply_settings() -> void:
	_set_bus("Music", Settings.music_volume)
	_set_bus("SFX", Settings.sfx_volume)
	_set_bus("Ambient", Settings.ambient_volume)
	AudioServer.set_bus_mute(0, Settings.muted)

func _set_bus(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
