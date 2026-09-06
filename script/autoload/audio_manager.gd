extends Node
## ゲーム全体の音（BGM / SE）を一元管理する Autoload。
##
## 使い方:
##   Audio.play_se("dash")               … ゲーム内SE（ポーズで止まる / SE バス）
##   Audio.play_ui("decide")             … UI音（ポーズ中も鳴る / UI バス）
##   Audio.play_bgm(Audio.BGM_BOSS)      … クロスフェードで切り替え
##   Audio.stop_bgm(0.5)                 … フェードアウトして停止
##   Audio.set_game_paused(true)         … ポーズ連動（PauseMenu から呼ぶ）
##
## 設計方針:
##   1. 呼び出し側は「ID」しか知らない（パス・音量・ピッチはこのファイルに集約）
##   2. AudioStreamPlayer は起動時にプールして使い回す（毎フレーム new しない）
##   3. BGM は 2 台のプレイヤーを交互に使ってクロスフェード

# ---------------------------------------------------------------- 定数

const BUS_BGM := "BGM"
const BUS_SE := "SE"
const BUS_UI := "UI"

const SE_POOL_SIZE := 12      ## 同時に鳴らせるゲーム内SEの数
const BGM_FADE := 0.8         ## 既定のクロスフェード秒
const SILENT_DB := -60.0      ## 実質無音とみなす dB
const DUCK_DB := -10.0        ## ポーズ中に BGM を下げる量

# --- BGM はパスを定数化（タイプミス防止 & リネーム時の一括修正） ---
const BGM_TITLE := "res://audio/bgm/title.ogg"
const BGM_CAMPFIRE_NIGHT := "res://audio/bgm/campfire_stage_night.ogg"
const BGM_EVENING_NIGHT := "res://audio/bgm/campfire_stage_evening.ogg"
const BGM_PLAYER_DEAD := "res://audio/bgm/player_dead.ogg"
const BGM_BATTLE_STAGE := "res://audio/bgm/battle_stage.ogg"
const BGM_ENDING_STAGE := "res://audio/bgm/ending_stage.ogg"
const BGM_BATTLE_LOOP0 := "res://audio/bgm/battle_loop0.ogg"
const BGM_BATTLE_LOOP1 := "res://audio/bgm/battle_loop1.ogg"
const BGM_BATTLE_LOOP2 := "res://audio/bgm/battle_loop2.ogg"

# --- SE 定義テーブル（ゲーム内音） ---
# path 以外は省略可。pitch はランダム揺らぎの幅（±の割合）
const SE_TABLE := {
	"dash":      {"path": "res://audio/se/dash.wav",      "volume_db": -4.0, "pitch": 0.06},
	"rolling":   {"path": "res://audio/se/rolling.wav",   "volume_db": -4.0, "pitch": 0.06},
	"paint":     {"path": "res://audio/se/paint.wav",     "volume_db": -8.0, "pitch": 0.10},
	"boss_hit":  {"path": "res://audio/se/boss_hit.wav"},
	"win":       {"path": "res://audio/se/win.wav"},
	"lose":      {"path": "res://audio/se/lose.wav"},
	"warp":      {"path": "res://audio/se/warp.wav"},
	"earthquake":      {"path": "res://audio/se/earthquake.wav"},
	"text_blip": {"path": "res://audio/se/text_blip.wav", "volume_db": -12.0, "pitch": 0.12},
	"bird_1":      {"path": "res://audio/se/bird_1.wav"},
	"bird_2":      {"path": "res://audio/se/bird_2.wav"},
	"bird_3":      {"path": "res://audio/se/bird_3.wav"},
	"bird_4":      {"path": "res://audio/se/bird_4.wav"},
	"bird_5":      {"path": "res://audio/se/bird_5.wav"},
	"bird_6":      {"path": "res://audio/se/bird_6.wav"},
	"bird_7":      {"path": "res://audio/se/bird_7.wav"},
	"game_start":      {"path": "res://audio/se/game_start.wav"},
	"button_pressed":      {"path": "res://audio/se/button_pressed.wav"},
	"player_footstep":      {"path": "res://audio/se/player_footstep.wav", "volume_db": -4.0, "pitch": 0.5},
	"hakubo_footstep":      {"path": "res://audio/se/hakubo_footstep.wav", "volume_db": -4.0, "pitch": 0.5},
	"next_chat":      {"path": "res://audio/se/next_chat.wav", "volume_db": -4.0, "pitch": 0.5},
	"player_dead_se":      {"path": "res://audio/se/player_dead_se.wav", "volume_db": 0.0, "pitch": 0.06},
	"damage":      {"path": "res://audio/se/damage.wav", "volume_db": 8.0, "pitch": 0.5},
	"ink_splash_small":      {"path": "res://audio/se/ink_splash_small.wav", "volume_db": -3.0, "pitch": 0.5},
	"ink_splash_large":      {"path": "res://audio/se/ink_splash_large.wav", "volume_db": -3.0, "pitch": 0.5},
	"slash":      {"path": "res://audio/se/slash.wav", "volume_db": 0.0, "pitch": 0.5},
	"parry":      {"path": "res://audio/se/parry.wav", "volume_db": 0.0, "pitch": 0.5},
	"mystery_se":      {"path": "res://audio/se/mystery_se.wav", "volume_db": 0.0, "pitch": 0.5},
	"beam_shot":      {"path": "res://audio/se/beam_shot.wav", "volume_db": 8.0, "pitch": 0.5},
	"beam_charge":      {"path": "res://audio/se/beam_charge.wav", "volume_db": 5.0, "pitch": 0.5},
	"mana_break":      {"path": "res://audio/se/mana_break.wav", "volume_db": 0.0, "pitch": 0.5},
}

# --- UI 定義テーブル（ポーズ中も鳴らしたい音） ---
const UI_TABLE := {
	"focus":  {"path": "res://audio/ui/focus.wav",  "volume_db": -6.0},
	"decide": {"path": "res://audio/ui/decide.wav"},
	"cancel": {"path": "res://audio/ui/cancel.wav"},
	"pause":  {"path": "res://audio/ui/pause.wav"}, 
}

# ---------------------------------------------------------------- 内部状態

var _se_pool: Array[AudioStreamPlayer] = []
var _se_next := 0
var _ui_player: AudioStreamPlayer

var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_active := 0
var _bgm_path := ""
var _bgm_tween: Tween

var _stream_cache := {}         ## path -> AudioStream（load を繰り返さない）
var _played_this_frame := {}    ## 同一フレームでの同じSEの多重再生を防ぐ

var _bgm_bus := 0
var _bgm_user_db := 0.0         ## 将来の音量設定スライダー用（linear_to_db の結果を入れる）
var _duck_db := 0.0             ## ポーズ中などの一時的な下げ幅
var _bgm_volume_db := -3.0           ## AudioServer.set_bus_volume_db() で設定する最終値

# ---------------------------------------------------------------- 初期化

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# バス名は起動時に一度だけ解決する。以降はこの値を使う。
	var bgm_bus_name := _resolve_bus(BUS_BGM)
	var se_bus_name := _resolve_bus(BUS_SE)
	var ui_bus_name := _resolve_bus(BUS_UI)
	_bgm_bus = AudioServer.get_bus_index(bgm_bus_name)   # Master なら 0

	for i in SE_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = se_bus_name      # ← 定数ではなく解決済みの名前を使う
		add_child(p)
		_se_pool.append(p)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = ui_bus_name
	_ui_player.max_polyphony = 4
	add_child(_ui_player)

	for i in 2:
		var b := AudioStreamPlayer.new()
		b.bus = bgm_bus_name
		b.volume_db = SILENT_DB
		add_child(b)
		_bgm_players.append(b)


func _process(_delta: float) -> void:
	# 毎フレーム頭でリセット。これで「同じSEが同一フレームに5回」→音割れ を防ぐ。
	if not _played_this_frame.is_empty():
		_played_this_frame.clear()

# ---------------------------------------------------------------- SE

## ゲーム内SEを鳴らす。ポーズ中は停止する。
func play_se(id: String) -> void:
	var def: Dictionary = SE_TABLE.get(id, {})
	if def.is_empty():
		push_warning("[Audio] 未定義のSE ID: %s" % id)
		return
	if _played_this_frame.has(id):
		return
	var stream := _get_stream(def["path"])
	if stream == null:
		return
	_played_this_frame[id] = true

	var p := _take_se_player()
	p.stream = stream
	p.volume_db = def.get("volume_db", 0.0)
	var range_ratio: float = def.get("pitch", 0.0)
	p.pitch_scale = 1.0 + randf_range(-range_ratio, range_ratio)
	p.stream_paused = false
	p.play()

func stop_all_se() -> void:
	for p in _se_pool:
		p.stop()

## UI音を鳴らす。ポーズ中でも鳴る。
func play_ui(id: String) -> void:
	var def: Dictionary = UI_TABLE.get(id, {})
	if def.is_empty():
		push_warning("[Audio] 未定義のUI音 ID: %s" % id)
		return
	var stream := _get_stream(def["path"])
	if stream == null:
		return
	_ui_player.stream = stream
	_ui_player.volume_db = def.get("volume_db", 0.0)
	_ui_player.play()


## 空いているプレイヤーを探す。全部埋まっていたら一番古いものを奪う。
func _take_se_player() -> AudioStreamPlayer:
	var n := _se_pool.size()
	for i in n:
		var idx := (_se_next + i) % n
		if not _se_pool[idx].playing:
			_se_next = (idx + 1) % n
			return _se_pool[idx]
	var p := _se_pool[_se_next]
	_se_next = (_se_next + 1) % n
	return p

# ---------------------------------------------------------------- BGM

## BGM をクロスフェードで切り替える。同じ曲なら何もしない（部屋の再入場で鳴り直さない）。
func play_bgm(path: String, fade := BGM_FADE, force := false) -> void:
	if path == _bgm_path and not force:
		return
	var stream := _get_stream(path)
	if stream == null:
		return
	_bgm_path = path

	var from := _bgm_players[_bgm_active]
	_bgm_active = 1 - _bgm_active
	var to := _bgm_players[_bgm_active]

	to.stream = stream
	to.volume_db = SILENT_DB
	to.play()

	_start_fade(from, to, fade)


## BGM をフェードアウトして止める。
func stop_bgm(fade := BGM_FADE) -> void:
	if _bgm_path == "":
		return
	_bgm_path = ""
	var from := _bgm_players[_bgm_active]
	_start_fade(from, null, fade)


func _start_fade(from: AudioStreamPlayer, to: AudioStreamPlayer, fade: float) -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if fade <= 0.0:
		if to: to.volume_db = _bgm_volume_db
		from.stop()
		return

	_bgm_tween = create_tween().set_parallel(true)
	if to:
		_bgm_tween.tween_property(to, "volume_db", _bgm_volume_db, fade)
	_bgm_tween.tween_property(from, "volume_db", SILENT_DB, fade)
	_bgm_tween.chain().tween_callback(from.stop)

# ---------------------------------------------------------------- ポーズ連動

## PauseMenu から呼ぶ。ゲーム内SEを止め、BGM を少し下げる（ダッキング）。
func set_game_paused(paused: bool) -> void:
	for p in _se_pool:
		p.stream_paused = paused
	_duck_db = DUCK_DB if paused else 0.0
	_apply_bgm_volume()


## 将来の音量設定用。slider.value（0.0〜1.0）をそのまま渡せる。
func set_bgm_volume_linear(linear: float) -> void:
	_bgm_user_db = linear_to_db(clampf(linear, 0.0, 1.0)) if linear > 0.0 else SILENT_DB
	_apply_bgm_volume()


func _apply_bgm_volume() -> void:
	# 「ユーザー設定 + 一時的な下げ幅」を足して最終値にする。
	# dB は対数なので "足し算 = 音量の掛け算"。ダッキングと設定値が喧嘩しない。
	AudioServer.set_bus_volume_db(_bgm_bus, _bgm_user_db + _duck_db)

# ---------------------------------------------------------------- ユーティリティ

func _get_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("[Audio] 音声ファイルが見つかりません: %s" % path)
		_stream_cache[path] = null   # 毎フレーム警告が出ないようキャッシュしておく
		return null
	var s := load(path) as AudioStream
	_stream_cache[path] = s
	return s

## バスが存在しなければ Master にフォールバックする。
## Web 書き出しでは存在しないバスを指すと JS 側で例外が飛び、
## エンジンごと停止して画面が真っ暗になるため、ここで必ず潰しておく。
func _resolve_bus(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	push_warning("[Audio] オーディオバス '%s' が見つかりません。Master を使用します。" % bus_name)
	return "Master"

# ---------------------------------------------------------------- その他

func play_random_bird_se() -> void:
	var bird_se_ids := ["bird_1", "bird_2", "bird_3", "bird_4", "bird_5", "bird_6", "bird_7"]
	var id : String = bird_se_ids[randi() % bird_se_ids.size()]
	play_se(id)
