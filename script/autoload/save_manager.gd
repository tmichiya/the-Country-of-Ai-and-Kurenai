extends Node

signal save_started
signal save_finished

class GameData:
	var game_version: String
	var loop_count: int
	var wave_times: Array[float]
	var easy_mode: bool
	var current_stage: GameManager.Stage
	var readed_conversations: Dictionary = {}

	func _init(_game_version: String, _loop_count: int, _wave_times: Array[float], _easy_mode: bool, _current_stage: GameManager.Stage, _readed_conversations: Dictionary = {}) -> void:
		game_version = _game_version
		loop_count = _loop_count
		wave_times = _wave_times
		easy_mode = _easy_mode
		current_stage = _current_stage
		readed_conversations = _readed_conversations

var default_game_data: GameData = GameData.new(
	ProjectSettings.get_setting("application/config/version"),
	0,
	[0.0, 0.0, 0.0],
	false,
	GameManager.Stage.OPENING,
	{}
)

##  GameManager から呼ばれることを想定
func save_game(game_data: GameData) -> void:
	print("[SaveManager]: Saving game")
	save_started.emit()
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_to_dictionary(game_data), "\n"))
		file.close()

		save_finished.emit()
		print("[SaveManager]: Game saved successfully.")
	else:
		push_error("Failed to open save file for writing.")
		print("[SaveManager]: Cannot open save file for writing. Error code: %s" % FileAccess.get_open_error())

# GameData型で返す関数
# 読み取りファイルが存在しない or JSONのパースエラーはnullを返す
func get_save_data() -> GameData:
	var file : FileAccess = FileAccess.open("user://save_data.json", FileAccess.READ)
	if file != null:
		var text = file.get_as_text()
		file.close()

		var json_text = JSON.parse_string(text)
		if json_text != null and json_text is Dictionary:
			print("[SaveManager]: Save data loaded successfully.")

			return _from_dictionary(json_text)
		else:
			print("[SaveManager]: Failed to parse save data JSON. This data may be corrupted or in an unexpected format.")
			return null
	else:
		push_error("Failed to open save file for reading.")
		print("[SaveManager]: Cannot open save file for reading. Error code: %s" % FileAccess.get_open_error())
		return null

func _to_dictionary(game_data: GameData) -> Dictionary:
	return {
		"game_version": game_data.game_version,
		"loop_count": game_data.loop_count,
		"wave_times": game_data.wave_times,
		"easy_mode": game_data.easy_mode,
		"readed_conversations": game_data.readed_conversations,
		"current_stage": game_data.current_stage
	}

func _from_dictionary(data: Dictionary) -> GameData:
	var game_version: String = data.get("game_version", "")
	var loop_count: int = int(data.get("loop_count", 0))
	var wave_times: Array[float]
	wave_times.assign(data.get("wave_times", [0.0, 0.0, 0.0]))
	var easy_mode: bool = data.get("easy_mode", false)
	var current_stage: GameManager.Stage = data.get("current_stage", GameManager.Stage.OPENING)
	var readed_conversations: Dictionary = data.get("readed_conversations", {})

	return GameData.new(
		game_version,
		loop_count,
		wave_times,
		easy_mode,
		current_stage,
		readed_conversations
	)
