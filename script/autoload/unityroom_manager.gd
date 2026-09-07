extends Node
## unityroom のスコアランキングへタイムを送る窓口（Autoload: UnityroomManager）。
##
## 【責務】送信すること、および「送ってよいか」の判断だけ。
## 何を送るか（どのタイムか）は呼ぶ側が決める。
## 送信の都合（Web ビルドか / 二重送信か / 失敗時どうするか）を
## ここに閉じ込めておくと、ゲーム側は結果を渡すだけで済む。

## スコアボード番号。ボードを増やしたらここに定数を足す。
## 数字を直接書かないのは、2枚目・3枚目を足したときに
## 「1 ってどのボードだっけ」を探し回らないため。
const BOARD_CLEAR_TIME := 1

var _client: UnityroomClient

## 1プレイにつき1回だけ送る。
## エンディングに複数の入口ができたり、演出の都合で二度呼ばれても平気にしておく。
var _sent: bool = false

func _ready() -> void:
	_client = UnityroomClient.new("cEBBOMkzVRXYtkQkQsF4Z7j3rWiyqDQ17Fnjtw/2mPWiRh55pebPBBdgWAEAg8qwZVK8mWACNPHOt/jeUwucOA==")
	add_child(_client)
	_client.score_uploaded.connect(_on_score_uploaded)

	# 【重要】ここで送らない。
	# 起動しただけでスコアが飛ぶと、タイトル画面を開いた回数ぶん
	# ランキングにゴミが並ぶ。送信は「クリアした」ときだけ。
	# 2周目も送れるよう、周回リセットで送信済みフラグを戻す。
	GameManager.run_reset.connect(_on_run_reset)

func _on_run_reset() -> void:
	_sent = false

## クリアタイムを送る。呼ぶ側は条件を気にせず一度呼べばよい。
func send_clear_time(seconds: float) -> void:
	if _sent:
		return
	if not OS.has_feature("web"):
		# エディタや デスクトップ版の実行でランキングを汚さない。
		# デバッグ中は値がログで見えれば十分。
		print("[unityroom] Web ビルドではないため送信しません: %s" % GameManager.format_time(seconds))
		return

	_sent = true
	# 小数第2位で丸める。表示（format_time）と桁を揃えておかないと、
	# 「画面は 1:23.45 なのにランキングは 83.4000015」というズレが出る。
	_client.send_score(BOARD_CLEAR_TIME, snappedf(seconds, 0.01))

func _on_score_uploaded(success: bool, response: UnityroomClient.Response) -> void:
	if success:
		var res := response as UnityroomClient.ScoreUploadResponse
		print("[unityroom] スコア更新: %s" % res.score_updated)
	else:
		# 【送信失敗でゲームを止めない】
		# ランキングは「あると嬉しい」機能であって進行の必須要素ではない。
		# 通信が不安定な環境でエンディングが見られない、が最悪のケース。
		var err := response as UnityroomClient.ErrorResponse
		push_warning("[unityroom] 送信失敗: " + err.message)
		# 失敗したぶんは送り直せるようにしておく。
		_sent = false