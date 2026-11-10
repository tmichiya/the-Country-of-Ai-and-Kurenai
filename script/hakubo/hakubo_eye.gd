class_name HakuboEye
extends Node2D
## 薄暮の片目の赤い光。体のスプライトは clip_children で子を切り抜くので子にはせず、
## スプライトの隣に置いて、その姿勢（位置・回転・拡大）を毎フレーム写す。
## 目の位置は「アニメ名 → フレームごとのピクセル位置」の表で持つ。表に無いアニメ（up_*）では隠す。

const WALK_BOB := [-3, -4, -3, 0, 1, -3, -4, -3, 0, 1]

@export var sprite: AnimatedSprite2D
## アニメ名ごと・フレームごとの目のピクセル位置（スプライト中心からの、ピクセルの左上の座標）
@export var offsets: Dictionary[StringName, PackedVector2Array] = {
	&"down_idle": PackedVector2Array([Vector2(1, -13)]),
	&"right_idle": PackedVector2Array([Vector2(2, -13)]),
	&"left_idle": PackedVector2Array([Vector2(-3, -13)]),
	&"down_walk": _walk_offsets(Vector2(1, -13)),
	&"right_walk": _walk_offsets(Vector2(2, -13)),
	&"left_walk": _walk_offsets(Vector2(-3, -13)),
}
## 脈打つ速さ（1 秒あたりの回数）
@export var pulse_speed: float = 0.6
## 目の点そのものの色
@export var dot_color: Color = Color(1.0, 0.12, 0.2, 1.0)

## 光の強さ。Tween で動かせるようプロパティにしてある。
var energy: float = 0.0
## 脈打つ幅（0 で一定）
var pulse: float = 0.3
var trail: bool = false

@onready var _pivot: Node2D = $Pivot
@onready var _dot: Sprite2D = $Pivot/Dot
@onready var _light: PointLight2D = $Pivot/Light
@onready var _trail: GPUParticles2D = $Pivot/Trail

var _has_offset: bool = false
var _time: float = 0.0


func _ready() -> void:
	_dot.modulate = dot_color
	sprite.frame_changed.connect(_update_offset)
	sprite.animation_changed.connect(_update_offset)
	_update_offset()


## 形態の見た目を受け取る。energy だけは呼ぶ側が Tween で動かすこともある（0 になると消える）。
func set_look(eye_enabled: bool, eye_energy: float, eye_pulse: float, eye_trail: bool) -> void:
	energy = eye_energy if eye_enabled else 0.0
	pulse = eye_pulse
	trail = eye_trail


func _process(delta: float) -> void:
	# 死亡アニメの回転や被弾の伸び縮みにも、体と一緒についていく
	transform = sprite.transform
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * pulse_speed * TAU)
	var k := 1.0 - pulse * wave
	_light.energy = energy * k
	_dot.modulate.a = clampf(0.5 + 0.5 * k, 0.0, 1.0) * clampf(energy * 2.0, 0.0, 1.0)
	visible = _has_offset and energy > 0.01
	_trail.emitting = visible and trail


## 今のアニメとフレームから目の位置を決める。
func _update_offset() -> void:
	var table: PackedVector2Array = offsets.get(sprite.animation, PackedVector2Array())
	_has_offset = not table.is_empty()
	if not _has_offset:
		return
	var p := table[clampi(sprite.frame, 0, table.size() - 1)]
	# ピクセルの左上の座標なので、点の中心は +0.5
	_pivot.position = p + Vector2(0.5, 0.5)


## 歩きアニメ 10 フレームぶんの、上下の弾みを足した位置を作る。
static func _walk_offsets(base: Vector2) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for dy in WALK_BOB:
		arr.append(base + Vector2(0, dy))
	return arr
