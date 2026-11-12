class_name HakuboFormLook
extends Resource
## 薄暮の形態ごとの見た目。res://data/hakubo_form_look_*.tres にして、インスペクタだけで調整する。

## 体が黒く染まる度合い（0〜1）
@export_range(0.0, 1.0) var corruption: float = 0.0

@export_group("片目")
@export var eye_enabled: bool = false
## 目の光の強さ（PointLight2D の energy）
@export var eye_energy: float = 0.0
## 脈打つ幅（0 で一定、1 で消えるところまで揺れる）
@export_range(0.0, 1.0) var eye_pulse: float = 0.3
## 目の動きに赤い残光を引くか
@export var eye_trail: bool = false

@export_group("体のまわり")
## 体から出る光（Visual/PointLight2D）の色
@export var light_color: Color = Color.WHITE
## 黒い滴りの量（0 で出さない、1 で最大）
@export_range(0.0, 1.0) var drip_particles: float = 0.0
## ダッシュ中に残像を出すか
@export var afterimage_on_dash: bool = false
## 数秒に一度、体が 1px ずれるか
@export var glitch: bool = false
## 足元の影の大きさ（1 で元のまま）
@export var shadow_scale: float = 1.0
## 足元の影の濃さ（1 で元のまま。1 より大きくすると濃くなる）
@export var shadow_alpha: float = 1.0
