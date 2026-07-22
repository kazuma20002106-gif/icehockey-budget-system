[C10: CC(P3) ⇒ Dex(P4) Take2]

# Cycle 10 マニュアル再整理 Take2 実装完了報告

## ステータス

**完了 / P4再レビュー依頼**

---

## 実施内容

`docs/handoff/P4_Rollback/cycle_10_manual_restructure.md` の指示に従い、共通テンプレ同期で薄くなっていたアイスホッケー固有の強い安全ルールを、入口ファイル（`AGENTS.md`, `CLAUDE.md`, `.cursorrules`）へ戻した。`manuals/` 配下は「良かった点」として指摘されていたため変更していない。

---

### 1. `AGENTS.md`（編集）

- 「プロジェクト固有ファイル」節を、`docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` を**必読**と明記する形に変更（「存在すれば読む」から強化）。
- 新設「Airの事前宣言・承認待ちルール（危険タスク判定）」節を追加。
  - Airは依頼を受けたら設計・実装案の前に「タスク重要度・事前宣言」（タスク要約／危険度判定／理由／実行計画）を出すこと。
  - Kazumaxが明示的に「承認」「進めて」と返すまでAirはコード編集しないこと。
  - 危険タスクは `docs/PROJECT_RULES.md` を参照し、Air計画 → Dex事前レビュー → CC実装 → Dex事後レビューを通すこと。
- 新設「バージョン管理ルール」節を追加。コード変更時は `docs/PROJECT_RULES.md` に従う／マニュアルのみの変更は不要、を明記。

### 2. `CLAUDE.md`（編集）

- 「最初に読むもの」に `docs/PROJECT_RULES.md`、`docs/handoff/WORKFLOW_RULES.md` を追加。
- 「Gitとバージョン管理」節をこのプロジェクト固有の内容に置き換え。
  - コード変更時に `application.properties` の `app.version` を更新。
  - `.\mvnw.cmd -q -DskipTests compile` を実行し `target/classes/application.properties` との同期を確認。
  - コミットメッセージ先頭に `[vX.Y.Z]`、可能ならpushまで実施。
  - マニュアルのみの変更はバージョンアップ不要。
- 新設「完了時の報告ルール」節を追加。P3報告書は `docs/handoff/P3_CC_to_Dex/` に保存し、Kazumaxへのチャットは短く、Dexへの合図文は単独コードブロックで出す旨を明記。

### 3. `.cursorrules`（編集）

- 「行動ルール」に「保存処理、DB、Excel出力、金額計算、参加者管理、日付計算を重点レビューする」を追加。
- 新設「P2/P4の出力ルール（このプロジェクト）」節を追加。
  - P2は `docs/handoff/P2_Dex_to_CC/` に保存。
  - P4 OKは `docs/handoff/P4_Dex_Review/` に保存し、P1要件を網羅した最終確認チェックリストの短縮版をチャットにも出す。
  - P4 NGは `docs/handoff/P4_Rollback/` に保存。
  - チャットは短い要約・判断・次担当合図に絞り、プラスアルファ提案は `docs/proposals/` にも保存。

### 4. `docs/handoff/CURRENT_STATUS.md`（更新）

- Cycle 10のフェーズを「CC(P3) Take2完了 / Dex(P4) 再レビュー待ち」に更新。
- 次に読むべきファイルを本報告書と `P4_Rollback/cycle_10_manual_restructure.md` に更新。
- 最新ハンドオフファイル一覧にTake2報告書のパスを追加。
- Kazumaxが次にコピーする合図文を、Dex向けのP4再レビュー依頼文に更新。

---

## 変更ファイル一覧

| ファイル | 操作 |
|---|---|
| `AGENTS.md` | 編集（Air事前宣言ルール・バージョン管理ルールを追加） |
| `CLAUDE.md` | 編集（CC固有のGit/バージョン管理・報告ルールを追加） |
| `.cursorrules` | 編集（Dex固有のP2/P4出力ルール・重点レビュー観点を追加） |
| `docs/handoff/CURRENT_STATUS.md` | 更新（Take2完了状態に更新） |

`docs/PROJECT_RULES.md`、`docs/handoff/WORKFLOW_RULES.md`、`manuals/` 配下は今回変更していない（Dexレビューで問題なしと判定済みのため）。

---

## 共通テンプレ同期後の最終形（入口 / 固有ルールの整理）

- **共通ルール（入口＋汎用）**: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`
  - ただし `AGENTS.md` / `CLAUDE.md` / `.cursorrules` は、上記の通りアイスホッケー固有の強いルール（事前宣言・承認待ち・バージョン管理・重点レビュー観点）を追記済み。
- **プロジェクト固有ルール**: `docs/PROJECT_RULES.md`（危険領域・検証条件）, `docs/handoff/WORKFLOW_RULES.md`（引き継ぎ・出口ゲート・リカバリプロトコル）, `docs/handoff/CURRENT_STATUS.md`（現在地）

---

## 未変更であることの確認

- Javaコード（`src/main/java/` 配下）: 変更なし。
- DB関連（`schema.sql`, `mapper/*.xml`）: 変更なし。
- Excelテンプレート（`*.xlsx`, `templates/`）: 変更なし。
- `src/main/resources/application.properties`: 変更なし。`app.version` 更新なし（マニュアルのみの変更のため不要）。

---

## Dexへのレビュー依頼観点

1. `AGENTS.md` にAirの事前宣言・承認待ちルールが明確に戻っているか。
2. `CLAUDE.md` にCC固有のバージョン管理・報告ルールが明確に戻っているか。
3. `.cursorrules` にDex固有のP2/P4出力ルール・重点レビュー観点が明確に戻っているか。
4. 4ファイル（`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CURRENT_STATUS.md`）間でルールの矛盾・重複がないか。
5. Javaコード・DB・Excelテンプレート・`application.properties` に触れていないことの確認。
