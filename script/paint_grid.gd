extends Node2D

const VOID := 0
const NONE := 1
const AI := 2
const KURENAI := 3

# --- インスペクタで割り当てる ---
@export var overlay_sprite: Sprite2D      # 塗りを描画するSprite2D（PaintOverlay）
@export var terrain_sprite: Sprite2D      # 表示している地形PNG（Stage）＝塗り領域の基準
@export var base_paint_mask: Texture2D    # 塗れる領域マスク（不透明＝塗れる）

## マスク画像を何分の1に縮めてグリッドにするか（1 = 等倍）。
## 1200x1800 のマスクを 2 にすると 600x900 になり、
##   ・セル数     216万 → 54万（1/4）
##   ・テクスチャ 8.2MB → 2.1MB（1/4）
## になる。塗りの粒はドット単位で見ないと分からない程度しか変わらないのに、
## GPU 転送量と GDScript のループ回数が4分の1になるのでほぼ無料の最適化。
@export_range(1, 8) var grid_downscale: int = 2

## カバレッジ集計用タイルの一辺（セル数）。内部で 2 のべき乗に丸める。
## 小さいほど「円にぴったり収まるタイル」が増えて境界の実測セルが減るが、
## タイル数そのものが増える。8 前後が経験的にバランスが良い。
@export_range(2, 32) var coverage_tile_size: int = 8

## 演出のテンポ（すべて「秒」）。以前は create_timer の待ち時間だったが、
## SceneTreeTimer は最短でも1フレーム待つのでフレームレート依存だった。
## 今はジョブの発火時刻として使うので、FPS が変わっても実時間は一定。
@export var fan_step_interval := 0.016      # 扇の角度ステップ1つあたりの間隔
@export var band_step_interval := 0.016     # 帯のステップ1つあたりの間隔
@export var blob_splash_min := 0.03         # 飛沫が散るまでの間隔（最小）
@export var blob_splash_max := 0.05         # 飛沫が散るまでの間隔（最大）

## 1フレームで処理する塗りジョブ数の上限。
## 極端に重いフレームがあっても、そこで一気に数百発まとめて塗って
## さらにフレームを落とす…という悪循環を切るための安全弁。
## 30FPS でも 64*30 = 1920 発/秒 まで捌けるので、通常は上限に当たらない。
@export var max_jobs_per_frame := 64

var grid_w: int
var grid_h: int
var grid: PackedByteArray
var base_grid: PackedByteArray

var terrain_size: Vector2                 # 地形テクスチャのピクセルサイズ

var paint_image: Image
var paint_texture: ImageTexture
var dirty := false

# マスク画素 → グリッドセルの換算。呼び出し側は今まで通り「マスク画素」で
# radius を渡してよく、内部でここを掛けてセル数に直す。
var _cell_per_px := 1.0

# ---------------------------------------------------------------------------
# 塗りジョブキュー（時間駆動）
#
# 旧実装は「await create_timer(0.001)」でフレームを跨いでいた。
# SceneTreeTimer は process フレームの単位でしか進まないため、
# 実際の待ち時間は max(指定秒, 1フレーム時間) になる。
# → 144FPS なら 7ms、60FPS なら 17ms、30FPS なら 33ms。完全に FPS 依存。
#
# ここでは「いつ・どこに・どれだけ塗るか」を発射時に全部予約しておき、
# _process で delta を積んだ時計と突き合わせて消化する。
# 低 FPS のフレームでは1フレームに複数ジョブがまとめて処理されるだけなので、
# 塗り終わるまでの「実時間」はマシンの速さによらず一定になる。
# ---------------------------------------------------------------------------
var _clock := 0.0
var _jobs: Array[Dictionary] = []
var _jobs_need_sort := false

# ---------------------------------------------------------------------------
# カバレッジ集計（タイルサマリ）
#
# グリッドを T×T のタイルに区切り、タイルごとに
#   _tile_paintable … VOID でないセル数（塗れる床の数。一生変わらない）
#   _tile_ai / _tile_kurenai … その色に塗られているセル数
# を持つ。塗るときに増減させるだけなので追加コストは1セルあたり数命令。
#
# get_paint_coverage() は「円にまるごと収まるタイル」を集計値1回の読み出しで
# 済ませ、円の境界にかかるセルだけを実測する。
# 計算量が O(r²) から O(r²/T² + r·T) に落ちる（r はセル単位の半径）。
# ---------------------------------------------------------------------------
var _tile_size := 8
var _tile_shift := 3
var _tiles_w: int
var _tiles_h: int
var _tile_paintable: PackedInt32Array
var _tile_ai: PackedInt32Array
var _tile_kurenai: PackedInt32Array

## グリッドが書き換わるたびに増える版数。カバレッジのメモ化キーに使う。
var _grid_version := 0
var _cov_cache: Dictionary = {}
var _cov_cache_version := -1


func _ready() -> void:
	setup()


func setup() -> void:
	if base_paint_mask == null:
		push_error("paint_grid: base_paint_mask が未設定です")
		return
	if terrain_sprite == null or terrain_sprite.texture == null:
		push_error("paint_grid: terrain_sprite（地形スプライト）が未設定です")
		return

	# 【重要】get_image() は ImageTexture の場合“内部の Image そのもの”を返す。
	# そのまま resize/convert すると元のテクスチャを破壊してしまい、
	# 2回目の setup() でさらに縮む…という事故になる。必ず複製してから触る。
	var img: Image = base_paint_mask.get_image().duplicate(true)

	# インポート設定によっては VRAM 圧縮フォーマットで返ってくる。
	# その状態では resize も get_pixel も使えないので、まず RGBA8 に正規化する。
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var src_w := img.get_width()
	var src_h := img.get_height()

	grid_w = maxi(1, src_w / grid_downscale)
	grid_h = maxi(1, src_h / grid_downscale)
	_cell_per_px = float(grid_w) / float(src_w)

	if grid_w != src_w or grid_h != src_h:
		# NEAREST を使うのは、マスクの alpha を「塗れる/塗れない」の二値として
		# 扱いたいから。線形補間すると境界に中間 alpha が生まれて判定がぶれる。
		img.resize(grid_w, grid_h, Image.INTERPOLATE_NEAREST)

	grid = PackedByteArray()
	grid.resize(grid_w * grid_h)
	grid.fill(VOID)

	# get_pixel() は1ピクセルごとにエンジン呼び出し＋Color生成が入る。
	# 上で RGBA8 に揃えてあるので、生バイト列の alpha を直接見るほうが桁違いに速い。
	# （等倍 1200x1800 のときの 216万回ループが、起動時に体感できるほど遅かった箇所）
	var mask_data := img.get_data()
	var n := grid_w * grid_h
	for i in range(n):
		if mask_data[i * 4 + 3] >= 128:
			grid[i] = NONE

	base_grid = grid.duplicate()
	terrain_size = terrain_sprite.texture.get_size()

	_build_tiles()
	_init_visual()
	_place_overlay()


## タイルサマリを作る。塗れるセル数（_tile_paintable）は VOID が増減しない限り
## 不変なので、ここで一度だけ数えれば以後まったく触らなくてよい。
func _build_tiles() -> void:
	# タイル一辺を 2 のべき乗に丸める（ビットシフトで割り算を消すため）
	_tile_shift = 1
	while (1 << (_tile_shift + 1)) <= coverage_tile_size:
		_tile_shift += 1
	_tile_size = 1 << _tile_shift

	_tiles_w = (grid_w + _tile_size - 1) >> _tile_shift
	_tiles_h = (grid_h + _tile_size - 1) >> _tile_shift
	var count := _tiles_w * _tiles_h

	_tile_paintable = PackedInt32Array()
	_tile_paintable.resize(count)
	_tile_ai = PackedInt32Array()
	_tile_ai.resize(count)
	_tile_kurenai = PackedInt32Array()
	_tile_kurenai.resize(count)

	for row in range(grid_h):
		var base := row * grid_w
		var trow := (row >> _tile_shift) * _tiles_w
		for col in range(grid_w):
			if grid[base + col] != VOID:
				var t := trow + (col >> _tile_shift)
				_tile_paintable[t] += 1

	_clear_owner_tiles()


func _clear_owner_tiles() -> void:
	_tile_ai.fill(0)
	_tile_kurenai.fill(0)
	_bump_version()

func _bump_version() -> void:
	_grid_version += 1


func _init_visual() -> void:
	paint_image = Image.create_empty(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	paint_image.fill(Color(0, 0, 0, 0))
	paint_texture = ImageTexture.create_from_image(paint_image)


# overlay を terrain とピッタリ同じ位置・大きさに合わせる
func _place_overlay() -> void:
	if overlay_sprite == null:
		push_error("paint_grid: overlay_sprite が未設定です")
		return
	overlay_sprite.texture = paint_texture
	overlay_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay_sprite.centered = terrain_sprite.centered
	overlay_sprite.global_position = terrain_sprite.global_position
	overlay_sprite.global_rotation = terrain_sprite.global_rotation
	# grid_w×grid_h のテクスチャを、地形テクスチャの表示サイズ（ワールド）まで引き伸ばす
	overlay_sprite.global_scale = terrain_sprite.global_scale * (terrain_size / Vector2(grid_w, grid_h))


# ===========================================================================
# 毎フレームの進行
# ===========================================================================

func _process(delta: float) -> void:
	_clock += delta
	_run_due_jobs()
	_handle_debug_input()
	if dirty:
		paint_texture.update(paint_image)
		dirty = false


func _run_due_jobs() -> void:
	if _jobs.is_empty():
		return

	if _jobs_need_sort:
		_jobs.sort_custom(func(a, b): return a["t"] < b["t"])
		_jobs_need_sort = false

	var done := 0
	while done < _jobs.size() and done < max_jobs_per_frame and _jobs[done]["t"] <= _clock:
		var j: Dictionary = _jobs[done]
		_paint_cells(j["pos"], j["r"], j["owner"])
		done += 1

	if done > 0:
		_jobs = _jobs.slice(done)


func _schedule(delay: float, world_pos: Vector2, radius_px: float, color_owner: int) -> void:
	# 遅延ゼロのぶんはその場で塗る。
	# 旧実装も「最初の1発は await の手前なので即時」だったので、
	# こうしておくと発射の瞬間の手応えが1フレームぶんもズレない。
	if delay <= 0.0:
		_paint_cells(world_pos, radius_px, color_owner)
		return
	_jobs.append({
		"t": _clock + maxf(delay, 0.0),
		"pos": world_pos,
		"r": radius_px,
		"owner": color_owner,
	})
	_jobs_need_sort = true


# 1発の飛沫（本体1つ＋あとから散る3つ）を delay 秒後から順に予約する
func _schedule_blob(delay: float, world_pos: Vector2, radius_px: float, color_owner: int) -> void:
	_schedule(delay, world_pos, radius_px, color_owner)
	var t := delay
	for i in range(3):
		t += randf_range(blob_splash_min, blob_splash_max)
		var sub_r := radius_px * randf_range(0.1, 0.3)
		# 旧コードは Vector2.from_angle(rad_to_deg(randf() * 360)) だった。
		# from_angle はラジアンを取るのに、度に直したうえで更に rad_to_deg を
		# 掛けていたので 0〜20626 rad という無意味な角度になっていた。
		var offset := Vector2.from_angle(randf() * TAU) * radius_px * randf_range(1.0, 1.5)
		_schedule(t, world_pos + offset, sub_r, color_owner)


func clear_jobs() -> void:
	_jobs.clear()
	_jobs_need_sort = false


# ===========================================================================
# 座標変換
# ===========================================================================

# ワールド座標 → グリッド(col,row)
func _col_row(world_pos: Vector2) -> Vector2i:
	var t: Vector2 = terrain_sprite.to_local(world_pos)
	if terrain_sprite.centered:
		t += terrain_size * 0.5
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


func _color_for(color_owner: int) -> Color:
	match color_owner:
		AI:
			return Color(0.235, 0.435, 0.910, 0.85)
		KURENAI:
			return Color(1.0, 0.24, 0.33, 0.85)
		_:
			return Color(0, 0, 0, 0)


# ===========================================================================
# 実際にセルを塗る（同期・即時）
# ===========================================================================

func _paint_cells(world_pos: Vector2, radius_px: float, color_owner: int) -> void:
	var c := _col_row(world_pos)
	var r: float = maxf(radius_px * _cell_per_px, 0.5)
	var span := int(ceil(r))
	var r2 := r * r
	var col_color := _color_for(color_owner)
	# 「この色になったら AI 側か紅側か」をループの外で1回だけ判定しておく
	var to_ai := color_owner == AI
	var to_kurenai := color_owner == KURENAI
	var changed := false

	for dy in range(-span, span + 1):
		var row := c.y + dy
		if row < 0 or row >= grid_h:
			continue
		# 円の内側になる dx の範囲を先に閉じた式で求める。
		# 旧コードは外接正方形を全部なめて dx*dx+dy*dy を毎回比較していたが、
		# 行ごとに範囲を出せば「外れるセル」を訪れる必要が一切ない（約 21% 削減）。
		# 行が円から完全に外れている場合はスキップする。
		# maxf(..., 0.0) で 0 に丸めてしまうと、円の外なのに中心の1セルだけ
		# 塗ってしまい、円形がわずかに歪む（旧実装と1〜2セルずれる原因だった）。
		var inner := r2 - float(dy * dy)
		if inner < 0.0:
			continue
		var half := int(floor(sqrt(inner)))
		var x0: int = maxi(c.x - half, 0)
		var x1: int = mini(c.x + half, grid_w - 1)
		var base := row * grid_w
		var trow := (row >> _tile_shift) * _tiles_w
		for col in range(x0, x1 + 1):
			var idx := base + col
			var prev := grid[idx]
			# VOID は塗れない。すでに同じ色なら書き込む意味がない
			# （set_pixel を丸ごと省けるので、重ね塗りが多いほど効く）。
			if prev == VOID or prev == color_owner:
				continue
			grid[idx] = color_owner
			# タイル集計を O(1) で更新する
			var t := trow + (col >> _tile_shift)
			if prev == AI:
				_tile_ai[t] -= 1
			elif prev == KURENAI:
				_tile_kurenai[t] -= 1
			if to_ai:
				_tile_ai[t] += 1
			elif to_kurenai:
				_tile_kurenai[t] += 1
			paint_image.set_pixel(col, row, col_color)
			changed = true

	if changed:
		dirty = true
		_bump_version()


# ===========================================================================
# 公開API（呼び出し側のシグネチャは従来どおり。await は不要になった）
# ===========================================================================

func paint(world_pos: Vector2, radius: float, color_owner: int) -> void:
	_paint_cells(world_pos, radius, color_owner)


func paint_blob(world_pos: Vector2, radius: float, color_owner: int, _direction: Vector2 = Vector2.ZERO) -> void:
	_schedule_blob(0.0, world_pos, radius, color_owner)


func paint_band(from: Vector2, to: Vector2, width: float, color_owner: int) -> void:
	var length := (to - from).length()
	# 旧コードは steps が 0 になると t = 0/0 で NaN になっていた
	var steps: int = maxi(1, int(length / (width * 0.4)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_schedule_blob(band_step_interval * i, from.lerp(to, t), width * 0.5, color_owner)


func paint_fan(origin: Vector2, angle_rad: float, spread_rad: float, radius: float, color_owner: int) -> void:
	var steps_a: int = maxi(1, int(rad_to_deg(spread_rad) / 4.0))
	var blob_r: float = maxf(radius * 0.25, 15.0)
	for i in range(steps_a + 1):
		var t := float(i) / float(steps_a)
		var a := angle_rad + spread_rad * 0.5 - spread_rad * t
		var dir := Vector2.from_angle(a)
		var delay := fan_step_interval * i
		var d := blob_r
		while d <= radius:
			_schedule_blob(delay, origin + dir * d, blob_r, color_owner)
			d += blob_r


# ===========================================================================
# カバレッジ判定
# ===========================================================================

## world_pos を中心とした半径 radius（マスク画素）の円のうち、
## 「塗れる床」に対して color_owner の色が占める割合を返す。
##
## AI の思考は1〜3秒に1回しか回らないが、そのたびに数万セルを走査していたので
## 低スペック機では目に見えるスパイクになっていた。ここでは
##   1) 同じ版数・同じ中心・同じ半径ならメモ化した結果を返す
##   2) 円にまるごと収まるタイルはタイル集計を1回読むだけで済ませる
## の2段構えで潰している。結果は従来と完全に一致する（近似ではない）。
func get_paint_coverage(color_owner: int, radius: float, world_pos: Vector2) -> float:
	var c := _col_row(world_pos)
	var r: float = maxf(radius * _cell_per_px, 0.5)

	if _cov_cache_version != _grid_version:
		_cov_cache.clear()
		_cov_cache_version = _grid_version
	# 半径は量子化せずそのままキーに含める（近い半径を取り違えないため）
	var key := "%d:%.6f:%d:%d" % [color_owner, r, c.x, c.y]
	if _cov_cache.has(key):
		return _cov_cache[key]

	var result := _coverage_scan(color_owner, r, c)
	_cov_cache[key] = result
	return result


func _coverage_scan(color_owner: int, r: float, c: Vector2i) -> float:
	var r2 := r * r
	var span := int(ceil(r))
	var y_start: int = maxi(c.y - span, 0)
	var y_end: int = mini(c.y + span, grid_h - 1)
	if y_start > y_end:
		return 0.0

	# タイル集計が使えるのは「タイルの縦幅がまるごと走査範囲に入っている」ときだけ。
	# 端のタイル行は普通に1セルずつ数える。
	var owner_tiles: PackedInt32Array = _tile_ai if color_owner == AI else _tile_kurenai
	var use_tiles := color_owner == AI or color_owner == KURENAI

	var owner_count := 0
	var cells := 0
	var T := _tile_size

	var ty := y_start >> _tile_shift
	var ty_last := y_end >> _tile_shift
	while ty <= ty_last:
		var tile_y0 := ty << _tile_shift
		var tile_y1 := tile_y0 + T - 1
		var y0: int = maxi(tile_y0, y_start)
		var y1: int = mini(tile_y1, y_end)

		var txa := 0
		var txb := -1
		# タイル行がグリッドと走査範囲の両方に丸ごと収まっているときだけ集計を使う
		if use_tiles and y0 == tile_y0 and y1 == tile_y1 and tile_y1 < grid_h:
			var dy_max: int = maxi(absi(tile_y0 - c.y), absi(tile_y1 - c.y))
			var inner := r2 - float(dy_max * dy_max)
			if inner >= 0.0:
				var hw := int(floor(sqrt(inner)))
				# tx*T >= c.x - hw  かつ  tx*T + T - 1 <= c.x + hw
				txa = _ceil_shift(c.x - hw, _tile_shift)
				txb = (c.x + hw - T + 1) >> _tile_shift
				txa = maxi(txa, 0)
				txb = mini(txb, (grid_w >> _tile_shift) - 1)

		if txb >= txa:
			var trow := ty * _tiles_w
			for tx in range(txa, txb + 1):
				var t := trow + tx
				cells += _tile_paintable[t]
				owner_count += owner_tiles[t]
			# タイルで数えた x 範囲の外側（円の縁）だけ実測する
			var covered_x0 := txa << _tile_shift
			var covered_x1 := ((txb + 1) << _tile_shift) - 1
			for y in range(y0, y1 + 1):
				var dy := y - c.y
				var inner_row := r2 - float(dy * dy)
				if inner_row < 0.0:
					continue
				var half := int(floor(sqrt(inner_row)))
				var rx0: int = maxi(c.x - half, 0)
				var rx1: int = mini(c.x + half, grid_w - 1)
				var base := y * grid_w
				var res_l := _count_span(base, rx0, mini(rx1, covered_x0 - 1), color_owner)
				cells += res_l.x
				owner_count += res_l.y
				var res_r := _count_span(base, maxi(rx0, covered_x1 + 1), rx1, color_owner)
				cells += res_r.x
				owner_count += res_r.y
		else:
			for y in range(y0, y1 + 1):
				var dy2 := y - c.y
				var inner2 := r2 - float(dy2 * dy2)
				if inner2 < 0.0:
					continue
				var half2 := int(floor(sqrt(inner2)))
				var res := _count_span(y * grid_w, maxi(c.x - half2, 0), mini(c.x + half2, grid_w - 1), color_owner)
				cells += res.x
				owner_count += res.y

		ty += 1

	return float(owner_count) / float(cells) if cells > 0 else 0.0


## 1行ぶんの [x0, x1] を数える。戻り値 x = 塗れるセル数, y = color_owner のセル数。
func _count_span(base: int, x0: int, x1: int, color_owner: int) -> Vector2i:
	var cells := 0
	var owned := 0
	for col in range(x0, x1 + 1):
		var v := grid[base + col]
		if v == VOID:
			continue
		cells += 1
		if v == color_owner:
			owned += 1
	return Vector2i(cells, owned)


## ceil(a / 2^shift) を整数のまま求める（負数でも正しく切り上げる）
func _ceil_shift(a: int, shift: int) -> int:
	return -((-a) >> shift)


# ===========================================================================
# リセット
# ===========================================================================

func reset() -> void:
	clear_jobs()
	for i in range(grid.size()):
		if grid[i] != VOID:
			grid[i] = NONE
	paint_image.fill(Color(0, 0, 0, 0))
	_clear_owner_tiles()
	dirty = true


# for debug
func reset_grid() -> void:
	clear_jobs()
	grid = base_grid.duplicate()
	paint_image.fill(Color(0, 0, 0, 0))
	_clear_owner_tiles()
	dirty = true

## 【なぜ _input ではなくポーリングか】
## このノードは SubViewport の中にいるため、_input / _unhandled_input は
## 確実には届かない。player.gd をポーリングに統一したのと同じ理由。
## SubViewport 内のノードでは Input シングルトンを直接見ること。
func _handle_debug_input() -> void:
	if not Input.is_action_just_pressed("debug"):
		return
	debug_fill_all(KURENAI)

## デバッグ用：VOID 以外の全セルを指定色で塗り潰す。
##
## キー入力の検知と「塗り潰す」処理を分けておくと、
## デバッグパネルのボタンや別のキーからも同じ動作を呼べるようになる。
func debug_fill_all(color: int) -> void:
	# 予約中の塗りジョブを先に捨てる。
	# 残っていると直後に消化されて、一瞬だけ塗り替わって元に戻るように見える。
	clear_jobs()

	for i in grid.size():
		if grid[i] == VOID:
			continue
		grid[i] = color

		# 【index → 座標】i = y * grid_w + x なので、
		#   x（横）= 余り、y（縦）= 商。
		# 元コードは商を col、余りを row と取り違えたうえで
		# set_pixel(x, y) に (y, x) の順で渡していた。
		var x := i % grid_w
		@warning_ignore("integer_division")
		var y := i / grid_w
		paint_image.set_pixel(x, y, _color_for(color))

	dirty = true
		
