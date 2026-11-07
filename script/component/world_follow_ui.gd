class_name WorldFollowUI
extends Node2D
## ワールド上のこの位置に、子の Control を「画面の解像度で」貼り付ける。
##
## ゲーム画面は 480×360 の SubViewport に描いてから拡大している。その中に Label を置くと、
## 文字は 480×360 の粗い画素に焼かれ、さらにカメラの 1.75 倍が掛かってつぶれる。
## そこで実行時に子の Control を SubViewport の外（シーンの一番上）の CanvasLayer へ移し、
## 毎フレーム位置だけ追いかける（会話の吹き出し Dialogue と同じ考え方）。
## エディタ上では今までどおりワールドの中で配置・確認できる。
##
## 注意: 移した中身は SubViewport の CanvasModulate・ライトの影響を受けない（会話の吹き出しと同じ）。

const VIEW_SIZE := Vector2(480, 360)

## 中身のどこをこのノードの位置に合わせるか（0〜1）。(0.5, 1) なら下辺の中央。
@export var pivot: Vector2 = Vector2(0.5, 0.5)
## 会話（1）より上・暗転（10）より下に描く。
@export var layer: int = 1

var _layer: CanvasLayer
var _frame: Control
var _content: Control


func _ready() -> void:
	for child in get_children():
		if child is Control:
			_content = child
			break
	if _content == null:
		push_warning("WorldFollowUI: 子に Control がありません (%s)" % get_path())
		return
	# 親たちの _ready が終わる前にツリーの別の場所へ add_child するとエラーになるので、1 フレーム後に移す。
	# （持ち主の @onready は移す前に中身を参照できる）
	_move_to_screen.call_deferred()


func get_content() -> Control:
	return _content


func _move_to_screen() -> void:
	if not is_inside_tree() or not is_instance_valid(_content):
		return
	_layer = CanvasLayer.new()
	_layer.name = "WorldFollowUI_" + name
	_layer.layer = layer
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_frame)
	# 文字の解像度は「その Control が属する Viewport」で決まる。
	# SubViewport の外に置かないと、画面に描いても 480×360 の粗さのままになる。
	get_tree().current_scene.add_child(_layer)
	_content.reparent(_frame, false)
	_follow()


func _exit_tree() -> void:
	# 中身はシーンの一番上にいるので、この基準点が消えるときに自分で片付ける
	if is_instance_valid(_layer):
		_layer.queue_free()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if not is_instance_valid(_layer):
		return
	_layer.visible = is_visible_in_tree()
	# SubViewport（480×360）は画面の中央に置かれているので、枠も同じ場所に合わせる
	_frame.position = ((get_tree().root.get_visible_rect().size - VIEW_SIZE) * 0.5).round()
	var on_view := get_viewport().get_canvas_transform() * global_position
	_content.position = (on_view - _content.size * pivot).round()
