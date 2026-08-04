# CURRENT STATUS

## Cycle 22 Take2 P4待ち: 初見利用者ガイド・ツールチップ修正完了（2026-08-04）

- **Take2修正内容**: P4差し戻し4点を修正。(1)活動一覧「出力」ボタンの閉じタグ・表示文字欠落を復元、(2)`交通費単価`/`旅行雑費`/`主な出発地点`のヘルプbuttonをlabel外へ分離、(3)ガイド5カードのinline flex/max-widthを削除しBootstrap標準の`row-cols-2 row-cols-md-5`へ置換、(4)操作ユーザーヘルプの`d-none d-sm-inline-block`を削除し360pxでも表示、狭幅では横あふれ時に折り返すCSSを追加。
- **検証**: `mvnw -q -DskipTests compile`成功、`mvnw -q test`成功（13件、exit 0）。禁止ファイル差分なし、`app.version=v2.6.2`維持。
- **未実施事項**: 360px/PC幅での実画面確認は、CC環境のブラウザプレビューツールの接続失敗（ポート競合起因）が再発したため今回も未実施。詳細は `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take2.md` を参照。
- **次担当**: Dex(P4)。上記Take2報告を読みDIFFレビューし、OK/NGを判定する。実画面確認（360px/PC幅）はDexまたはKazumaxでの実施を検討すること。
- **完全不動規約**: DB、保存、金額、Excel、Mapper、既存URL、hidden input、POST先、`app.version` は変更禁止（維持確認済み）。

## Current Cycle

- Cycle 22: 初見利用者向けガイド・ツールチップ統合改善 (P4 Take2レビュー待ち)

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take2.md` を読み、4点の修正が受入確認を満たすかレビューし、OK（`docs/handoff/P4_Dex_Review/`）またはNG（`docs/handoff/P4_Rollback/`）を判定すること。

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P4_Rollback/cycle_22_first_use_guide_and_tooltips.md`
8. `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips_take2.md`

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更の完全禁止（本Cycle要件による）
- `app.version` の変更禁止

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
