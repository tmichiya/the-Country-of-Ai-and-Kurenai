extends Node2D
signal attack_finished

@onready var hit_box: Area2D = $Hitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var player : CharacterBody2D = get_parent() as CharacterBody2D
@export var damage: int = 5

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack_parry":
		player.set_hurtbox_monitor(true)
		attack_finished.emit()
		queue_free()

func _ready() -> void:
	# rotation = global_position.angle_to_point(get_global_mouse_position())
	animation_player.play("attack_parry")
	animation_player.animation_finished.connect(_on_animation_finished)

	player.set_hurtbox_monitor(false) # パリィ中はプレイヤーの当たり判定を無効化する

	get_parent().get_parent().get_node("PaintLayer").paint_fan(get_parent().global_position, get_parent().get_direction(), deg_to_rad(110), 20, 2)
