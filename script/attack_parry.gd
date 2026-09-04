extends Node2D
signal attack_finished

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player : CharacterBody2D = get_parent() as CharacterBody2D
@export var damage: int = 5

# 1回のパリィ入力で成立させられるのは1発だけ。
# 成立済みかどうかのフラグで、これは同期的に立てる。
var is_consumed: bool = false

# 白暮の攻撃側から同期的に呼ばれる。最初の1回だけ true を返す。
#
# なぜ「パリィ側が当たりを検知して queue_free する」だけでは足りないか:
#   - queue_free() も set_deferred() もフレーム末にしか効かない
#   - 同一物理フレーム内で複数の攻撃判定(例: 唐竹の子9個)が重なると、
#     全部が「まだグループ parry に居るエリア」を見てしまい多重成立する
#   - 2つの Area2D のどちらの area_entered が先に飛ぶかは保証されない
# 攻撃側から同期的に問い合わせてもらうことで、順序に依存せず必ず1回に絞れる。
func try_consume() -> bool:
	if is_consumed:
		return false
	is_consumed = true
	_finish()
	return true

func _finish() -> void:
	# remove_from_group は即時反映されるので、同フレームの後続判定もここで弾ける
	if hit_box.is_in_group("parry"):
		hit_box.remove_from_group("parry")
	hit_box.set_deferred("monitoring", false)
	hit_box.set_deferred("monitorable", false)

	AudioManager.play_se("parry")

	player.mana_component.restore(70.0) # パリィ成功時にマナを回復する

	player.set_hurtbox_monitor(true)
	attack_finished.emit()
	queue_free()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_parry":
		player.set_hurtbox_monitor(true)
		attack_finished.emit()
		queue_free()

# 白暮の攻撃判定はすべて Area2D なので body_entered ではなく area_entered。
#
# ここでは「検知したことをログに出すだけ」で、絶対にパリィを消費しない。
# パリィと攻撃はどちらも Area2D なので接触時に両方向の area_entered が飛ぶが、
# どちらが先に呼ばれるかは保証されない。ここで try_consume() を呼んでしまうと、
# パリィ側が先だったフレームでは _finish() の remove_from_group("parry") が
# 即時に効いてしまい、後から飛んでくる攻撃側の判定がパリィを見失う。
# 結果 parried.emit されず、ヒットストップやフラッシュが丸ごと出なくなる。
# 成立と消費は攻撃側の _try_consume_parry() → try_consume() に一本化する。
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hakubo_attack"):
		return

func _ready() -> void:
	# rotation = global_position.angle_to_point(get_global_mouse_position())
	animation_player.play("attack_parry")
	animation_player.animation_finished.connect(_on_animation_finished)

	hit_box.area_entered.connect(_on_hitbox_area_entered)

	player.set_hurtbox_monitor(false) # パリィ中はプレイヤーの当たり判定を無効化する

	get_parent().get_parent().get_node("PaintLayer").paint_fan(get_parent().global_position, get_parent().get_direction(), deg_to_rad(110), 20, 2)
