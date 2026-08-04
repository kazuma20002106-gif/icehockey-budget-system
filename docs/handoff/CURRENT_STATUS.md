# CURRENT STATUS

## Cycle 22 P4待ち: 初見利用者ガイド・ツールチップ実装完了（2026-08-04）

- **目的**: Docker配布前の最終UX改善。初見利用者が迷わず安全に作業できる `？ 使い方`（`/guide`）と、要所のツールチップ・常時注意文を追加する。
- **P3実装結果**: `docs/handoff/P2_Dex_to_CC/cycle_22_first_use_guide_and_tooltips_instructions.md` の許可範囲どおり実装完了。`/guide`新設（GET専用、Service/Repository/Mapper不使用）、layout.htmlへのツールチップ共通初期化統一、P1確定文言のツールチップ・常時注意文を各画面へ追加。DB・保存・金額・Excel・Mapper・既存URL・`app.version`(v2.6.2のまま)への差分なし。
- **検証**: `mvnw -q -DskipTests compile` 成功、`mvnw -q test` 成功（既存12件+新規GuideControllerTest 1件、DB不要スライステスト）。**実UI画面でのブラウザ確認はKazumax判断により今回未実施**（ローカルポート競合のトラブルのため）。詳細は `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips.md` を参照。
- **次担当**: Dex(P4)。上記P3報告を読みDIFFレビューし、OK/NGを判定する。実UI確認が未実施のため、狭い幅到達性・tooltip動作はコードレビューで重点確認するか、Kazumaxの実機確認を軽い確認として依頼すること。
- **完全不動規約**: DB、保存処理、金額計算、Excelロジック・帳票セル・式、Mapper、既存URL（`DO NOT DELETE /export` 等）、`app.version` は変更禁止（維持確認済み）。
- **配布について**: Docker化・配布は全機能の最終検証後の別工程。本Cycleでは行わない。

## Current Cycle

- Cycle 22: 初見利用者向けガイド・ツールチップ統合改善 (P4レビュー待ち)

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips.md` を読み、差分が許可範囲内か、`/guide`がGET専用か、tooltip二重初期化がないか等をレビューし、OK（`docs/handoff/P4_Dex_Review/`）またはNG（`docs/handoff/P4_Rollback/`）を判定すること。

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P2_Dex_to_CC/cycle_22_first_use_guide_and_tooltips_instructions.md`
8. `docs/handoff/P3_CC_to_Dex/cycle_22_first_use_guide_and_tooltips.md`

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更の完全禁止（本Cycle要件による）
- `app.version` の変更禁止

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
