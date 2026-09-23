class_name BattleTimer
extends Node

## 戦闘中だけ進む秒数カウンタ。
##
## 【責務】時間を数えることだけ。
## 「いつ始まるか」「その値をどう使うか」は一切知らない。
## 呼ぶ側（battle_manager）が start / stop を告げる（Tell, Don't Ask）。
## 逆にこちらから battle_manager.battle_active を覗きに行くと参照が双方向になり、
## どちらが真実か分からなくなる。薄暮の killing_count と同じ切り分け方。
##
## 【ポーズ対応を if 文で書かない】
## このノードの process_mode は INHERIT（既定）のまま親にぶら下げる。すると
##   ・get_tree().paused = true（ポーズメニュー）→ PAUSABLE として止まる
##   ・boss_stage.set_active(false)（焚火にいる間）→ DISABLED として止まる
## の両方が「何も書かずに」満たされる。時間管理でいちばん漏れやすいのが
## この2つなので、フラグではなくツリーの仕組みに担わせるのが安全。

signal ticked(elapsed: float)

## 1フレームで積める上限（秒）。
##
## 実時計で測る以上、「_process が呼ばれなかった時間」が復帰後の1フレームに
## まとめて乗る。これはポーズ、部屋の切り替え、そして
## ブラウザのタブを裏に回したとき（Web 版では必ず起きる）に発生する。
## 上限を置いて、その飛びを一撃で吸収する。
## 0.25 秒は「4fps でもフレーム時間として妥当」の目安。
## これを超える遅延は計測から落ちるが、落ちるのは常にプレイヤーに有利な方向なので、
## 「実際より遅く記録される」事故が起きないという意味で安全側に倒れている。
const MAX_STEP_SECONDS := 0.25

var elapsed: float = 0.0

var _running: bool = false
var _paused: bool = false
## 前回 _process を通った実時刻（マイクロ秒）。
var _last_usec: int = 0

func _ready() -> void:
	_last_usec = Time.get_ticks_usec()

func start() -> void:
	elapsed = 0.0
	_paused = false
	_running = true
	_last_usec = Time.get_ticks_usec()

## 計測を止めて、その回のタイムを返す。
## 二重に止めても最後の値を返すので、呼び出し側にガードを書かせない。
func stop() -> float:
	_running = false
	return elapsed

func reset() -> void:
	_running = false
	_paused = false
	elapsed = 0.0
	_last_usec = Time.get_ticks_usec()

## 戦闘中に会話を挟むようになったとき用（薄暮の中間撃破セリフなど）。
## 今は未使用でよいが、後付けだと計測点を探し直すことになるので口だけ開けておく。
func set_paused(value: bool) -> void:
	_paused = value

## まだ決着していない計測が走っているか。
## 「中断（決着せずに部屋を離れた）」を検出するのに使う。
## stop() 後も elapsed は最後の値を保持するので、
## elapsed > 0 では中断と決着済みを区別できない。走行フラグで見ること。
func is_running() -> bool:
	return _running

func _process(_delta: float) -> void:
	# 【delta を使わない】
	#
	# delta は Engine.time_scale の影響を受ける。このゲームはパリィ成功時に
	# hakubo.parried() が Effects.slowmotion(0, 0.12) ＝ time_scale を 0 にする
	# ヒットストップを掛ける。
	#
	# ここで「delta ÷ time_scale で実時間に戻す」をやると、
	# time_scale が変わったフレームで必ず破綻する。
	# そのフレームの delta は変更前（1.0 基準の約 0.0167 秒）で確定しているのに、
	# 除数は変更後（0）を読むため、0除算ガードの 0.0001 で割ることになり、
	# 1フレームで 160 秒ほどが一気に加算される。
	# ＝「パリィするとタイムが1分進む」バグの正体。
	#
	# delta と time_scale は「同じ瞬間の値」である保証がない。
	# ならば両方を捨てて実時計を直接読めばよい。time_scale と完全に無関係になる。
	var now := Time.get_ticks_usec()
	var step := float(now - _last_usec) / 1000000.0
	# 【基準は数えていない間も進める】
	# ここを if の内側に入れると、計測していない間の時間が
	# 再開した最初の1フレームにまとめて乗る。
	_last_usec = now

	if not _running or _paused:
		return

	elapsed += minf(step, MAX_STEP_SECONDS)
	ticked.emit(elapsed)
