extends Node

class GameData:
	var game_version: String
	var loop_count: int
	var wave_times: Array[float]
	var easy_mode: bool

	func _init(_game_version: String, _loop_count: int, _wave_times: Array[float], _easy_mode: bool) -> void:
		game_version = _game_version
		loop_count = _loop_count
		wave_times = _wave_times
		easy_mode = _easy_mode

func save_game(game_data: GameData) -> void:
	print("[SaveManager]: Saving game")
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(game_data, "\n"))
		file.close()

		print("[SaveManager]: Game saved successfully.")
	else:
		push_error("Failed to open save file for writing.")
		print("[SaveManager]: Cannot open save file for writing. Error code: %s" % FileAccess.get_open_error())
