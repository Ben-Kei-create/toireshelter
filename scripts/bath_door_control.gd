extends Node
## 浴室のドアの開け閉め（ドライバーで直したあと）。開いたドアの扉の判定（door_area）が受ける。
## 開いているときは「ドアを閉める」、閉まっているときは「ドアを開ける」。鍵はもうかからない。
## 実際の開閉は room.gd の toggle_door。

var room: Node


func get_prompt(_id: String) -> String:
	if room.door_busy:
		return ""
	return "bath_door_close" if room.door_swung else "bath_door_open"


func interact(_id: String) -> String:
	room.toggle_door()
	return ""
