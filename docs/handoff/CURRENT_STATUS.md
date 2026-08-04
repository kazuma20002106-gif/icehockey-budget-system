# CURRENT STATUS

## Cycle 22 Take3 P4待ち: 360pxヘッダー横あふれ修正完了（2026-08-04）

- **Take3修正内容**: `？使い方`・操作ユーザーヘルプ・操作ユーザーdropdownの3要素を1つの`header-right-group`にまとめ、狭い幅では`flex-basis:100%`で独立した行へ強制折り返し。操作ユーザーdropdownのbuttonに`text-truncate`+`max-width:150px`を追加し、長い氏名でも横あふれしないようにした。
- **検証**: `mvnw -q -DskipTests compile`成功、`mvnw -q test`成功（13件、exit 0）。禁止ファイル差分なし、`app.version=v2.6.2`維持。ユーザー切替POST・hidden input・`/users/new`等のリンクは無変更。
- **未実施事項**: 360px/PC幅での実画面確認は、CC環境のブラウザプレビューが`ERR_CONNECTION_REFUSED`で接続できず、Take3も未実施（`read_network_requests`で確認済み）。詳細は `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take3.md` を参照。
- **次担当**: Dex(P4)。上記Take3報告を読みDIFFレビューし、実機で360px幅の操作ユーザーdropdown見切れが解消したかを重点確認してOK/NGを判定する。
- **完全不動規約**: DB、保存、金額、Excel、Mapper、既存URL、hidden input、POST先、`app.version` は変更禁止（維持確認済み）。

## Current Cycle

- Cycle 22: 初見利用者向けガイド・ツールチップ統合改善 (P4 Take3レビュー待ち)

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take3.md` を読み、360px幅で操作ユーザーdropdownの見切れが解消したかを実機確認し、OK（`docs/handoff/P4_Dex_Review/`）またはNG（`docs/handoff/P4_Rollback/`）を判定すること。

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P4_Rollback/cycle_22_first_use_guide_and_tooltips_take2.md`
8. `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take3.md`

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更の完全禁止（本Cycle要件による）
- `app.version` の変更禁止

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
