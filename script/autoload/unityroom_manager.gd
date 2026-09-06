extends Node

func _ready() -> void:
    var client = UnityroomClient.new("cEBBOMkzVRXYtkQkQsF4Z7j3rWiyqDQ17Fnjtw/2mPWiRh55pebPBBdgWAEAg8qwZVK8mWACNPHOt/jeUwucOA==")
    add_child(client)

    client.score_uploaded.connect(_on_score_uploaded)

    client.send_score(1, randi() % 1000)  # スコアボードID, スコア

# コールバック関数
func _on_score_uploaded(success: bool, response: UnityroomClient.Response) -> void:
    if success:
        # 成功時の処理
        var res := response as UnityroomClient.ScoreUploadResponse
        print("スコア更新: %i" % res.score_updated)
    else:
        # 成功時の処理
        var err := response as UnityroomClient.ErrorResponse
        print("エラー: " + err.message)