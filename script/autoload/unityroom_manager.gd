extends Node

const BOARD_CLEAR_TIME := 1
const BOARD_CLEAR_TIME_EASY_MODE := 2

var _client: UnityroomClient

## 1プレイにつき1回だけ送る。
var _sent: bool = false

func _ready() -> void:
	_client = UnityroomClient.new("cEBBOMkzVRXYtkQkQsF4Z7j3rWiyqDQ17Fnjtw/2mPWiRh55pebPBBdgWAEAg8qwZVK8mWACNPHOt/jeUwucOA==")
	add_child(_client)
	_client.score_uploaded.connect(_on_score_uploaded)

	GameManager.run_reset.connect(_on_run_reset)

func _on_run_reset() -> void:
	_sent = false

## クリアタイムを送る。呼ぶ側は条件を気にせず一度呼べばよい。
func send_clear_time(seconds: float) -> void:
	if _sent:
		return
	if not OS.has_feature("web"):
		print("[unityroom] Web ビルドではないため送信しません: %s" % GameManager.format_time(seconds))
		return

	_sent = true
	if GameManager.easy_mode:
		_client.send_score(BOARD_CLEAR_TIME_EASY_MODE, snappedf(seconds, 0.01))
	else:
		_client.send_score(BOARD_CLEAR_TIME, snappedf(seconds, 0.01))

func _on_score_uploaded(success: bool, response: UnityroomClient.Response) -> void:
	if success:
		var res := response as UnityroomClient.ScoreUploadResponse
		print("[unityroom] スコア更新: %s" % res.score_updated)
	else:
		var err := response as UnityroomClient.ErrorResponse
		push_warning("[unityroom] 送信失敗: " + err.message)
		_sent = false