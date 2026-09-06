extends Node2D

## プレイヤーが Hitbox に入った/出たを通知する検知コンポーネント。
##
## detect_player_area.gd と同じ「一回きり」の制御（_armed）を持つ。
## ワープ地点のように「1回入ったら遷移が始まる」場所では、遷移の演出中に
## ローリング等で出入りを繰り返すと entered が何度も飛んでしまうため。

signal entered
signal exited

@onready var area2d: Area2D = $Hitbox
@onready var collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D

## 一発屋の制御はこのフラグで行う（monitoring は常時ONのまま）
var _armed: bool = false
## 「落ち着いたら arm する」待ち状態
var _pending_arm: bool = true
## 再アーム要求からの経過物理フレーム数
var _arm_settle: int = 0
## いま重なっているプレイヤーの数（body_entered/body_exited で数える）
var _player_overlaps: int = 0

## 幽霊イベントをやり過ごすのに必要な物理フレーム数。
## 実測では 1 フレームで足りるが、余裕を見て 2 にしてある。
const ARM_SETTLE_FRAMES := 2

func _ready() -> void:
	area2d.body_entered.connect(_on_entered)
	area2d.body_exited.connect(_on_exited)

func _on_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_overlaps += 1
	if not _armed:
		return
	_armed = false
	_pending_arm = false
	entered.emit()

func _on_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_overlaps = maxi(_player_overlaps - 1, 0)
	exited.emit()

## reset_room から呼んで再アームする。
##
## 【なぜ即 arm しないのか】
## 部屋を process_mode = DISABLED にしている間、CollisionObject2D は
## 物理空間から外される（disable_mode の既定が DISABLE_MODE_REMOVE）。
## 再有効化すると「外された時点の座標」で登録し直されるため、
## 同じフレームでプレイヤーを別の場所へ飛ばしていても、
## 直後の1物理フレームだけは古い位置で判定され body_entered が飛んでしまう。
##
## 実測（Godot headless / --fixed-fps 60）:
##   無効化直後                  -> body_exited
##   再有効化＋同フレームで再配置 -> body_entered   ← これが幽霊イベント
##   さらに1物理フレーム後        -> body_exited    ← ここでやっと現実に追いつく
##
## そこで
##   (a) 再アーム要求から最低2物理フレーム待つ（幽霊イベントをやり過ごす）
##   (b) かつ「今プレイヤーが重なっていない」ことが確定している
## の両方が揃って初めて arm する。
##
## 重なり状況は get_overlapping_bodies() ではなく body_entered/body_exited で
## 数える。get_overlapping_bodies() は物理フラッシュ“前”の _physics_process から
## 呼ぶと登録直後は空を返してしまい、幽霊イベントを見逃すため。
##
## 副次的な効果として「エリアの中に立ったまま部屋に入り直しても、
## 一度外に出るまでは発火しない」という、そもそも望ましい挙動になる。
func set_monitoring_active(active: bool) -> void:
	_armed = false
	_pending_arm = active
	_arm_settle = 0

func is_armed() -> bool:
	return _armed

func _physics_process(_delta: float) -> void:
	if not _pending_arm:
		return
	_arm_settle += 1
	if _arm_settle < ARM_SETTLE_FRAMES:
		return
	if _player_overlaps > 0:
		return
	_armed = true
	_pending_arm = false
