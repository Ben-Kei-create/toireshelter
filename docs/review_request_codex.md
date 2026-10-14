# Codex へのレビュー依頼（Toiret / コーポヨシミ503号室）

対象ブランチ：`claude/trusting-ramanujan-hy9x4b`（Godot 4.7.2、GL Compatibility、GDScript。シーンは主にコードで組む）。
README.md に機能ごとの経緯がある。まず README 末尾の「2026-10 段階0〜2」の節と `docs/scenario_toilet_v4.md`（決定事項）を読んでください。

## 先にお伝えしておくこと

- 段階2の実装時はテストを保留したが、のちに既存テストも仕様変更に合わせて更新した（床のドライバー廃止、栓とふた、風呂桶は調べるだけ、拾っただけでは手に持たない）。更新が「仕様に合わせた正しい直し」か「テストが甘くなっただけ」か、見てほしい。
- 文言は日本語のみ。町名は「下南澤（シモミナ）」で、実在の地名を入れない方針。
- 実行：`godot --headless --path . --script res://tests/<name>_test.gd`。撮影は `SHOT_DIR=… xvfb-run -a godot --path . --script res://tests/capture_*.gd`。

## 重点的に見てほしいこと（優先順）

1. **詰み（ソフトロック）**：一方向のイベントで進行不能にならないか。
   - 栓の連鎖：十円玉は洗面台（取り戻せる）→浴槽（外せるが所持品には戻らない）。おもり・玉・ドライバー・毛だまりの取り逃し、水を抜いたときの状態、ふたを外したまま入浴剤を入れた場合など。
   - 浴室ユニットが上がった後（`room.gd` の `rise_unit`）に戻れなくなる箇所、はしご・バケツ・ダクトの出入り。
2. **ユニット上昇の仕組み**（`room.gd`）：Room の子ノードを動かす実装と `UNIT_EXCLUDE` の妥当性。動かすべき物・動かしてはいけない物の漏れ、当たり判定（`LAYER_*`）、`rise_offset` を使う絶対座標（`main.gd` の `_up()`）の取りこぼし。
3. **セーブ／ロード**（`progress.gd`）：`snapshot()` と `apply()` の対称性、順序依存（上昇・はしご・持ち物のモデル復元）、`stage2` 欄の欠落時の既定値、旧セーブ（VERSION 1）との互換、`_loading` 中の副作用（メッセージ・発見・ノート）。
4. **停電の明かり**（`room.gd` の `set_power`、`sky_clock.gd` の `ambient_scale`）：GL Compatibility の制約（ライト数・影・パフォーマンス）。浴室の電球「RoomLight」だけが残って上昇する設計に無理がないか。
5. **タイトル／開始の流れ**（`title_screen.gd`、`main.gd` の `_wants_title` `_begin_play`）：環境変数 `TOIRE_TITLE` / `TOIRE_NO_TITLE` / `SHOT_DIR` / `TOIRE_SAVE_TEST` の扱い、SubViewport と独自 World3D の後始末（リーク）、フェードとフライスルー中の入力。
6. **ヒントとランク**（`progress.gd` の `ask_hint` `rank_for` `RANK_TABLE`）：回数制限、時間・ヒントによるランク計算の境界、一時停止中のプレイ時間。
7. **UI**（`hud.gd`）：設定を開いたときの他表示の隠し方（`_set_overlays_hidden`）、ノート（N）、クリア画面、メッセージの文字送りと履歴。
8. **段階2の新規コード**：`sink.gd` / `bathtub.gd` / `towel.gd` / `shower_curtain.gd` の状態遷移（`lid`・`ball`・`soap_soak`・`wet`）、`main.gd` の `use_selected` 分岐、`room.gd` の青い光の切り替え（4回ごと）とちらつき tween、`Label3D` の鏡文字（`scale.x = -1`）の描画が Compatibility で正しいか。
9. **音**（`sfx.gd`）：手続き生成の `voice` / `rumble` の安全性（クリップ、長さ、再生中の多重）。
10. **テストの独立性**：テストが `user://settings.cfg`（eye_height）や `save.json` を汚さないか、`.uid` ファイルの扱い（Godot 4.4 以降の推奨に合わせ、リポジトリに入れる方針。tests/*.uid もコミット済み）、`ObjectDB leaked` の警告。

## 見なくてよいこと

- 画像・テクスチャの見た目の好み、文言の細かな言い回し、ランク時間の数値（暫定）。
- 段階3〜6（松明・暗い部屋・ブレーカー・和室・つかみ取り・吹き矢など）は未実装。

## 返してほしい形

- 重大度（致命／高／中／低）、ファイルと行、再現手順（できれば操作列）、修正案を 1 件ずつ。
- 「仕様どおりで問題なし」と確認できた領域も、短く挙げてください。
