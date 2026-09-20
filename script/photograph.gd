extends Node2D

@onready var center_container : CenterContainer = $CenterContainer

@export var player : CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 4:3のゲーム画面をウィンドウ中央に置くため、CenterContainer を実ウィンドウサイズに合わせる。
	# これで中央寄せがレイアウトで完結し、描画位置と入力(マウス)判定の矩形が一致する。
	get_viewport().size_changed.connect(_fit_center_container)
	_fit_center_container()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	player.mana_component.restore(100)

func _fit_center_container() -> void:
	# CenterContainer をウィンドウ全体に広げる（親が Node2D でアンカーが効かないためコードで設定）。
	# CenterContainer が中の 480x360 の箱を正しく中央に配置する。
	center_container.position = Vector2.ZERO
	center_container.size = get_viewport_rect().size
