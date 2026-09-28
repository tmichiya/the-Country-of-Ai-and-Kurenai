class_name BattleTimer
extends Node

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

## 戦闘中に会話を挟むようになったとき用
func set_paused(value: bool) -> void:
	_paused = value

## まだ決着していない計測が走っているか。
func is_running() -> bool:
	return _running

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var step := float(now - _last_usec) / 1000000.0
	_last_usec = now

	if not _running or _paused:
		return

	elapsed += minf(step, MAX_STEP_SECONDS)
	ticked.emit(elapsed)
