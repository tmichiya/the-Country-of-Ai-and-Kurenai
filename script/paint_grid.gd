extends Node2D

const VOID := 0
const NONE := 1
const AI := 2
const KURENAI := 3

const SUBCELL_PER_TILE := 8

@export var tilemap_layer: TileMapLayer
@export var overlay_sprite: Sprite2D

var origin_col: int
var origin_row: int
var grid_w: int
var grid_h: int
var grid: PackedByteArray
var base_grid: PackedByteArray
var subcell_size: Vector2

var paint_image: Image
var paint_texture: ImageTexture
var dirty := false

func setup(layer: TileMapLayer) -> void:
	tilemap_layer = layer
	var tile_size: Vector2i = tilemap_layer.tile_set.tile_size
	subcell_size = Vector2(tile_size.x / float(SUBCELL_PER_TILE), tile_size.y / float(SUBCELL_PER_TILE))

	var used_rect: Rect2i = tilemap_layer.get_used_rect()
	origin_col = used_rect.position.x * SUBCELL_PER_TILE
	origin_row = used_rect.position.y * SUBCELL_PER_TILE
	grid_w = used_rect.size.x * SUBCELL_PER_TILE
	grid_h = used_rect.size.y * SUBCELL_PER_TILE

	grid = PackedByteArray()
	base_grid = PackedByteArray()
	grid.resize(grid_w * grid_h)
	grid.fill(VOID)

	for cell in tilemap_layer.get_used_cells():
		var sc0 = (cell.x - used_rect.position.x) * SUBCELL_PER_TILE
		var sr0 = (cell.y - used_rect.position.y) * SUBCELL_PER_TILE
		for sy in range(SUBCELL_PER_TILE):
			for sx in range(SUBCELL_PER_TILE):
				grid[(sr0 + sy) * grid_w + (sc0 + sx)] = NONE

	base_grid = grid.duplicate()
	_init_visual()

func _col_row(world_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = tilemap_layer.to_local(world_pos)
	var col: int = int(floor(local_pos.x / subcell_size.x)) - origin_col
	var row: int = int(floor(local_pos.y / subcell_size.y)) - origin_row
	return Vector2i(col, row)

func get_owner_at(world_pos: Vector2) -> int:
	var col_row: Vector2i = _col_row(world_pos)
	if col_row.x < 0 or col_row.x >= grid_w or col_row.y < 0 or col_row.y >= grid_h:
		return VOID
	return grid[col_row.y * grid_w + col_row.x]

func get_owner_position(world_pos: Vector2) -> Vector2:
	var col_row: Vector2i = _col_row(world_pos)
	if col_row.x < 0 or col_row.x >= grid_w or col_row.y < 0 or col_row.y >= grid_h:
		return Vector2(-1, -1)
	return Vector2(col_row.x, col_row.y)

func _init_visual() -> void:
	paint_image = Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	paint_image.fill(Color(0, 0, 0, 0))
	paint_texture = ImageTexture.create_from_image(paint_image)

func _color_for(owner: int) -> Color:
	match owner:
		AI:
			return Color(0.235, 0.435, 0.910, 0.85)
		KURENAI:
			return Color(1.0, 0.24, 0.33, 0.85)
		_:
			return Color(0, 0, 0, 0)

func paint(world_pos: Vector2, radius: float, owner: int) -> void:
	var c = _col_row(world_pos)
	var r_cells = radius / subcell_size.x
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
			grid[idx] = owner
			paint_image.set_pixel(col, row, _color_for(owner))
	dirty = true

func attach_overlay(sprite: Sprite2D)	-> void:
	sprite.texture = paint_texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tile_size = tilemap_layer.tile_set.tile_size
	var used_rect = tilemap_layer.get_used_rect()
	sprite.position = tilemap_layer.map_to_local(used_rect.position) - Vector2(tile_size.x, tile_size.y) * 0.5
	sprite.scale = subcell_size

func get_paint_coverage(owner: int, radius: float, world_pos: Vector2) -> float:
	var grid_pos : Vector2i = get_owner_position(world_pos)
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
			if grid[idx] == owner:
				count += 1
			if grid[idx] != VOID:
				cells += 1
	return float(count) / float(cells) if cells > 0 else 0.0

# テスト用クリック塗装 
var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO

# func _unhandled_input(event: InputEvent) -> void:
	# if event is InputEventMouseButton and event.pressed:
	# 	var side = AI if event.button_index == MOUSE_BUTTON_LEFT else KURENAI
	# 	var world_pos = get_global_mouse_position()
	# 	paint_blob(world_pos, 16, side)
	# 	print("painted at ", world_pos, " -> owner now ", get_owner_at(world_pos))

	# if event is InputEventMouseButton:
	# 	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	# 		from_pos = get_global_mouse_position()
	# 	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
	# 		to_pos = get_global_mouse_position()
	# 		paint_band(from_pos, to_pos, 32, AI)
	# 		print("painted band from ", from_pos, " to ", to_pos)

	# if event is InputEventMouseButton:
	# 	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	# 		from_pos = get_global_mouse_position()
	# 	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
	# 		to_pos = get_global_mouse_position()
	# 		paint_fan(from_pos, (to_pos - from_pos).angle(), deg_to_rad(60), (to_pos - from_pos).length(), AI)
	# 		print("painted fan from ", from_pos, " to ", to_pos)

# for debug
func reset_grid() -> void:
	grid = base_grid.duplicate()
	paint_image.fill(Color(0, 0, 0, 0))
	dirty = true

# メインの塗関数
func paint_blob(world_pos: Vector2, radius: float, owner: int, direction: Vector2) -> void:
	paint(world_pos, radius, owner)
	for i in range(randi_range(radius / 10 + 1, radius / 10 + 5)):
		var new_radius = radius * randf_range(0.2, 0.5)
		var dir_offset = direction * randf_range(radius * 0.1, radius)
		var offset = Vector2(randf_range(-radius, radius), randf_range(-radius, radius)) + dir_offset
		if offset.length() + new_radius >= radius:
			paint(world_pos + offset, new_radius, owner)
			if offset.length() - new_radius >= radius:
				paint(world_pos + offset - dir_offset * 0.5, new_radius * 0.8, owner)

func paint_band(from: Vector2, to: Vector2, width: float, owner: int) -> void:
	var dir = (to - from).normalized()
	var length = (to - from).length()
	var steps = int(length / (width * 0.4))
	for i in range(steps + 1):
		var t = i / float(steps)
		var pos = lerp(from, to, t)
		paint_blob(pos, width * 0.5, owner, dir)

func paint_fan(origin: Vector2, angle_rad: float, spread_rad: float, radius: float, owner: int) -> void:
	var steps_a = rad_to_deg(spread_rad) / 4  # 角度方向の分割
	var blob_r = max(radius * 0.25, 15)   # 1つのblobの大きさ
	for i in range(steps_a + 1):
		var t = i / float(steps_a)
		var a = angle_rad - spread_rad * 0.5 + spread_rad * t
		var dir = Vector2(cos(a), sin(a))
		# 要から外周まで、距離方向にも並べる
		var d = blob_r
		while d <= radius:
			paint_blob(origin + dir * d, blob_r, owner, dir)
			d += blob_r * 0.9

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_reset_grid"):
		reset_grid()

func _ready() -> void:
	setup(tilemap_layer)
	attach_overlay(overlay_sprite)




func _process(delta: float) -> void:
	if dirty:
		paint_texture.update(paint_image)
		dirty = false
