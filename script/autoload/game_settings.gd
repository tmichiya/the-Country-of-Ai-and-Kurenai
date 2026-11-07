extends Node
## プレイヤーの設定（今は音量だけ）を user://settings.cfg に保存する。
## 進行状況のセーブ（save_data.json）とは別のファイルなので、「はじめから」で消えない。

const PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const DEFAULT_VOLUME := 1.0

var bgm_volume: float = DEFAULT_VOLUME
var se_volume: float = DEFAULT_VOLUME


func _ready() -> void:
	load_settings()
	AudioManager.set_bgm_volume_linear(bgm_volume)
	AudioManager.set_se_volume_linear(se_volume)


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bgm_volume_linear(bgm_volume)


func set_se_volume(value: float) -> void:
	se_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_se_volume_linear(se_volume)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err == ERR_FILE_NOT_FOUND:
		return
	if err != OK:
		push_warning("[GameSettings] 設定ファイルを読めませんでした（%s）。既定値を使います。" % error_string(err))
		return
	bgm_volume = clampf(float(cfg.get_value(SECTION_AUDIO, "bgm_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	se_volume = clampf(float(cfg.get_value(SECTION_AUDIO, "se_volume", DEFAULT_VOLUME)), 0.0, 1.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_AUDIO, "bgm_volume", bgm_volume)
	cfg.set_value(SECTION_AUDIO, "se_volume", se_volume)
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("[GameSettings] 設定を保存できませんでした（%s）。" % error_string(err))
