extends HakuboAttack

var target_position: Vector2 = Vector2.ZERO

func get_player_position() -> Vector2:
	if hakubo:
		return hakubo.get_player_position()
	return Vector2.ZERO

var _playing_anim_name: String = ""

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == _playing_anim_name:
		finish_attack()

func _child_is_parried(uv: Vector2) -> void:
	print("child parried")
	parried.emit(uv)

@onready var karatake_child_scene = preload("res://scene/hakubo/attack_super_hyper_karatake_child.tscn")
func shot_karatake_child(angle: float) -> void:
	var karatake_child_instance = karatake_child_scene.instantiate() as Node2D
	var boss = get_parent()
	boss.add_child(karatake_child_instance)
	karatake_child_instance.global_rotation = global_rotation
	karatake_child_instance.rotation += deg_to_rad(angle)
	karatake_child_instance.angle_offset = angle
	karatake_child_instance.paint_layer = paint_layer
	karatake_child_instance.damage = damage

	if boss.has_method("parried"):
		karatake_child_instance.parried.connect(boss.parried.bind(true))
	else:
		karatake_child_instance.parried.connect(_child_is_parried)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	# loop1 or loop2 で攻撃バリエーションの数を変える
	var max_attack_variation = 5
	var current_loop_count = GameManager.get_loop_count()
	if current_loop_count == 2:
		max_attack_variation = 5
	else:
		max_attack_variation = 3
	_playing_anim_name = "attack_hyper_karatake_%d" % (randi() % max_attack_variation + 1)
	if not animation_player.has_animation(_playing_anim_name):
		push_error("Animation not found: %s" % _playing_anim_name)
		finish_attack()
		return
	animation_player.play(_playing_anim_name)
	if animation_rig:
		animation_rig.play_attack_animation(&"attack_super_hyper_karatake", self, Vector2.from_angle(hakubo.direction))

	target_position = get_player_position()

func _process(delta: float) -> void:
	rotation = (target_position - global_position).angle()
