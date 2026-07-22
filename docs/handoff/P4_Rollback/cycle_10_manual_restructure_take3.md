[C10: Dex(P4) => CC(P3) Take4]

# Cycle 10 マニュアル再整理 Take3 差し戻し指示

## 判定

**NG / CC Take4対応待ち**

Take3では作業単位の分離は改善されましたが、入口ファイル3点の中身が弱くなっています。Take4では「Cycle 11相当の差分を整理する」のではなく、Cycle 10の本題である入口マニュアルの復元に集中してください。

---

## CCへの修正指示

### 1. `AGENTS.md` にアイスホッケー固有の強い入口ルールを戻す

最低限、以下を戻してください。

- `docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` は、このプロジェクトでは必読であること。
- Airは新しい依頼を受けたら、設計や実装案の前に「タスク重要度・事前宣言」を出すこと。
- Kazumaxが明示的に「承認」「進めて」と返すまで、Airはコード編集しないこと。
- 危険タスクは `docs/PROJECT_RULES.md` を参照し、Air計画 → Dex事前レビュー → CC実装 → Dex事後レビューの完全プロセスを通すこと。
- コードまたはユーザー可視の挙動を変える場合、バージョン更新は `docs/PROJECT_RULES.md` に従うこと。
- マニュアル・ドキュメントのみの変更ではバージョンアップ不要であること。

### 2. `CLAUDE.md` にCC固有の読み込み・検証・報告ルールを戻す

最低限、以下を戻してください。

- 最初に読むものに `docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` を含める。
- コード変更時は `src/main/resources/application.properties` の `app.version` を更新する。
- コード変更時は `.\mvnw.cmd -q -DskipTests compile` を実行する。
- `target/classes/application.properties` の `app.version` が同期していることを確認する。
- コミットメッセージ先頭に `[vX.Y.Z]` を付ける。
- マニュアル・ドキュメントのみの変更ではバージョンアップ不要。
- P3報告書は `docs/handoff/P3_CC_to_Dex/` に保存する。
- Kazumaxへの合図文は単独コードブロックで出す。

### 3. `.cursorrules` にDex固有のP2/P4出力ルールと重点レビュー観点を戻す

最低限、以下を戻してください。

- P2は `docs/handoff/P2_Dex_to_CC/` に保存する。
- P4 OKは `docs/handoff/P4_Dex_Review/` に保存する。
- P4 NGは `docs/handoff/P4_Rollback/` に保存する。
- チャットは短い要約、判断、次担当合図に絞る。
- プラスアルファ提案は `docs/proposals/` にも保存する。
- 保存処理、DB、Excel出力、金額計算、参加者管理、日付計算を重点レビューする。

### 4. Take4ではCycle 11相当の差分に触れない

以下はCycle 10 Take4の修正対象外です。

- `mvnw.cmd`
- `docs/PROJECT_RULES.md`
- `docs/handoff/WORKFLOW_RULES.md` の `git status --short` 出口ゲート追記

既に差分として残っていること自体は把握済みです。Take4では新たに触らず、Cycle 10 P4 OK後にCycle 11として別レビューへ回してください。

### 5. P3報告を実ファイルと一致させる

`docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take4.md` を作成し、実際に変更したファイルだけを列挙してください。

「Take2から変更なし」といった表現は、実ファイルと差分を確認した上で使ってください。

### 6. `CURRENT_STATUS.md` をTake4完了状態に更新する

Take4完了時は、次に読むべきファイルに以下を入れてください。

- `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take4.md`
- `docs/handoff/P4_Dex_Review/cycle_10_manual_restructure_take3.md`
- `docs/handoff/P4_Rollback/cycle_10_manual_restructure_take3.md`

---

## Dexへの次回レビュー依頼文

Take4完了後、Kazumaxへ渡す合図文は単独コードブロックで出してください。

```text
CCのCycle 10 Take4修正が終わったよ。最新のファイルを読んで、Cycle 10マニュアル再整理のDIFFレビュー（P4）をして！
```
