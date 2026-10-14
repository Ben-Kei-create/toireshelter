extends RefCounted
## エンドロールの文字。ルートごとに、最後の一枚だけ変わる。
## 作った人の名前などは、ここを書き換える（制作者の行）。

const TITLE := "コーポヨシミ　503号室"


static func lines(route: String) -> Array:
	var l: Array = [
		["title", TITLE],
		["head", "脱出ゲーム"],
		["space", ""],
		["space", ""],
		["head", "企画・開発"],
		["text", "Ben-Kei-create"],
		["space", ""],
		["head", "出演"],
		["text", "あなた"],
		["text", "十円玉"],
		["text", "固形せっけん"],
		["text", "鉛のおもり"],
		["text", "入浴剤の玉"],
		["text", "毛だまり"],
		["text", "ユブロマン"],
		["text", "風呂桶"],
		["text", "予備のトイレットペーパー"],
		["text", "壁の裏の鏡文字"],
		["space", ""],
		["head", "特別出演"],
		["text", "神の声"],
		["text", "隣の 504 号室・505 号室"],
		["text", "エレベーター（5 → 1）"],
		["space", ""],
		["head", "舞台"],
		["text", "コーポヨシミ　5 階"],
		["text", "503 号室　ユニットバス"],
		["text", "下南澤"],
		["space", ""],
		["head", "協力"],
		["text", "ベランダの手すり"],
		["text", "ボロボロのはしご"],
		["text", "レンガのアーチと、鉄の門"],
		["text", "郵便受けのみなさん"],
		["space", ""],
		["space", ""],
		["head", "ご遊戯、ありがとうございました"],
		["space", ""],
		["space", ""],
	]
	if route == "true":
		l.append(["text", "水に流して、おしまい。"])
	else:
		l.append(["text", "おしまい。"])
	l.append(["space", ""])
	l.append(["space", ""])
	l.append(["space", ""])
	return l
