extends Node2D

const VOID := 0
const NONE := 1
const AI := 2
const KURENAI := 3

# --- インスペクタで割り当てる ---
@export var overlay_sprite: Sprite2D      # 塗りを描画するSprite2D（PaintOverlay）
@export var terrain_sprite: Sprite2D      # 表示している地形PNG（Stage）＝塗り領域の基準
@export var base_paint_mask: Texture2D    # 塗れる領域マスク（不透明＝塗れる）

var grid_w: int
var grid_h: int
var grid: PackedByteArray
var base_grid: PackedByteArray

var terrain_size: Vector2                 # 地形テクスチャのピクセルサイズ

var paint_image: Image
var paint_texture: ImageTexture
var dirty := false

func reset() -> void:
	for i in range(grid.size()):
		if grid[i] != VOID:
			grid[i] = NONE
	paint_image.fill(Color(0, 0, 0, 0))
	dirty = true

func setup() -> void:
	if base_paint_mask == null:
		push_error("paint_grid: base_paint_mask が未設定です")
		return
	if terrain_sprite == null or terrain_sprite.texture == null:
		push_error("paint_grid: terrain_sprite（地形スプライト）が未設定です")
		return

	var img := base_paint_mask.get_image()
	grid_w = img.get_width()
	grid_h = img.get_height()
	grid = PackedByteArray()
	grid.resize(grid_w * grid_h)
	grid.fill(VOID)

	for y in range(grid_h):
		for x in range(grid_w):
			# マスクが不透明な所＝塗れる領域(NONE)、透明はVOID
			if img.get_pixel(x, y).a >= 0.5:
				grid[y * grid_w + x] = NONE

	base_grid = grid.duplicate()
	terrain_size = terrain_sprite.texture.get_size()

	_init_visual()
	_place_overlay()

# ワールド座標 → マスク格子(col,row)
# 地形スプライトのローカル空間に変換するので、PaintLayerのscaleや地形の位置・centeredを自動で吸収する
func _col_row(world_pos: Vector2) -> Vector2i:
	var t: Vector2 = terrain_sprite.to_local(world_pos)   # 地形テクスチャのピクセル座標（centeredなら中心が原点）
	if terrain_sprite.centered:
		t += terrain_size * 0.5                           # 左上を原点に補正
	var col: int = int(t.x / terrain_size.x * grid_w)
	var row: int = int(t.y / terrain_size.y * grid_h)
	return Vector2i(col, row)

func get_color_owner_at(world_pos: Vector2) -> int:
	var cr: Vector2i = _col_row(world_pos)
	if cr.x < 0 or cr.x >= grid_w or cr.y < 0 or cr.y >= grid_h:
		return VOID
	return grid[cr.y * grid_w + cr.x]

func get_color_owner_position(world_pos: Vector2) -> Vector2:
	var cr: Vector2i = _col_row(world_pos)
	if cr.x < 0 or cr.x >= grid_w or cr.y < 0 or cr.y >= grid_h:
		return Vector2(-1, -1)
	return Vector2(cr.x, cr.y)

func _init_visual() -> void:
	paint_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	paint_image.fill(Color(0, 0, 0, 0))
	paint_texture = ImageTexture.create_from_image(paint_image)

# overlay を terrain とピッタリ同じ位置・大きさに合わせる（両者は同じ親＝PaintLayerの子である前提）
func _place_overlay() -> void:
	if overlay_sprite == null:
		push_error("paint_grid: overlay_sprite が未設定です")
		return
	overlay_sprite.texture = paint_texture
	overlay_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay_sprite.centered = terrain_sprite.centered
	# terrain と overlay の親が違っても（terrain=World直下, overlay=PaintLayerの子 等）
	# ワールド上でピッタリ重なるよう、global（ワールド基準）で合わせる。
	# ローカルの position/scale をコピーすると、PaintLayer 側の scale/position が二重に効いてズレる。
	overlay_sprite.global_position = terrain_sprite.global_position
	overlay_sprite.global_rotation = terrain_sprite.global_rotation
	# grid_w×grid_h のテクスチャを、地形テクスチャの表示サイズ（ワールド）まで引き伸ばす
	overlay_sprite.global_scale = terrain_sprite.global_scale * (terrain_size / Vector2(grid_w, grid_h))

func _color_for(color_owner: int) -> Color:
	match color_owner:
		AI:
			return Color(0.235, 0.435, 0.910, 0.85)
		KURENAI:
			return Color(1.0, 0.24, 0.33, 0.85)
		_:
			return Color(0, 0, 0, 0)

func paint(world_pos: Vector2, radius: float, color_owner: int) -> void:
	var c = _col_row(world_pos)
	var r_cells = radius
	var span = int(ceil(r_cells))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			if dx * dx + dy * dy > r_cells * r_cells:
				continue

			var col = c.x + dx
			var row = c.y + dy
			if col < 0 or row < 0 or col >= grid_w or row >= grid_h:
				continue
			var idx = row * grid_w + col
			if grid[idx] == VOID:
				continue
			grid[idx] = color_owner
			paint_image.set_pixel(col, row, _color_for(color_owner))
	dirty = true

func get_paint_coverage(color_owner: int, radius: float, world_pos: Vector2) -> float:
	var grid_pos: Vector2i = get_color_owner_position(world_pos)
	var count = 0
	var cells = 0
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var col = grid_pos.x + dx
			var row = grid_pos.y + dy
			if col < 0 or row < 0 or col >= grid_w or row >= grid_h:
				continue
			var idx = row * grid_w + col
			if grid[idx] == color_owner:
				count += 1
			if grid[idx] != VOID:
				cells += 1
	return float(count) / float(cells) if cells > 0 else 0.0

# for debug
func reset_grid() -> void:
	grid = base_grid.duplicate()
	paint_image.fill(Color(0, 0, 0, 0))
	dirty = true

# メインの塗関数
func paint_blob(world_pos: Vector2, radius: float, color_owner: int, direction: Vector2) -> void:
	paint(world_pos, radius, color_owner)
	for i in range(3):
		var new_radius = radius * randf_range(0.1, 0.3)
		var offset = Vector2.from_angle(rad_to_deg(randf() * 360)) * radius * randf_range(1.0, 1.5)
		paint(world_pos + offset, new_radius, color_owner)
		await get_tree().create_timer(randf_range(0.03, 0.05), true, false, true).timeout
	return

func paint_band(from: Vector2, to: Vector2, width: float, color_owner: int) -> void:
	var dir = (to - from).normalized()
	var length = (to - from).length()
	var steps = int(length / (width * 0.4))
	for i in range(steps + 1):
		var t = i / float(steps)
		var pos = lerp(from, to, t)
		paint_blob(pos, width * 0.5, color_owner, dir)

func paint_fan(origin: Vector2, angle_rad: float, spread_rad: float, radius: float, color_owner: int) -> void:
	var steps_a = rad_to_deg(spread_rad) / 4  # 角度方向の分割
	var blob_r = max(radius * 0.25, 15)   # 1つのblobの大きさ
	for i in range(steps_a + 1):
		var t = i / float(steps_a)
		var a = angle_rad - spread_rad * 0.5 + spread_rad * t
		var dir = Vector2(cos(a), sin(a))
		# 要から外周まで、距離方向にも並べる
		var d = blob_r
		while d <= radius:
			paint_blob(origin + dir * d, blob_r, color_owner, dir)
			d += blob_r

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_reset_grid"):
		reset_grid()

func _ready() -> void:
	setup()

func _process(_delta: float) -> void:
	if dirty:
		paint_texture.update(paint_image)
		dirty = false
