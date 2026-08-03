# CURRENT STATUS

## Cycle 21 Take2（2026-08-03）

- **事故と復旧:** CCの実機確認中に`projects.id=1`が誤更新されたが、Dexセカンドオピニオンの条件付きSQLをKazumax承認後に1回実行し、`name`/`schedule_content`/`project_outcome`を復元済み。関連テーブル・他プロジェクトへの影響なしを確認。詳細は`docs/handoff/INCIDENT_cycle21_take2_project1_data_loss.md`。
- **P1-1/P1-2修正:** `ProjectService.saveProject()`でprojects本体insert/updateと参加者/Expense保存を単一トランザクションに統合（P1-1）。`updatePrintedStatusAtomic()`に更新件数チェックを追加（P1-2）。テスト14件成功。app.version=v2.6.1。
- **次担当:** Dex(P4) Take2レビュー。`docs/handoff/P3_CC_to_Dex/cycle_21_comprehensive_safety_and_ui_take2.md`を確認。

> [!CAUTION]
> **Kazumax代表からの全体絶対ルール**
> 入力が簡単になっても、合算が正しくなければツールとして意味がない。合算が正常に行われているかを第一優先にする。

## Current Cycle

- Cycle 21: 総合改修（安全性増強・感動UI/UX・原本クリーン化）

## 現在地

- Cycle 20: P4 OK（commit `9668648`, v2.5.4）。年度末Excel完全性修正および936円残存解消が完了。
- Cycle 21: Air(P1) による設計指示書（Blueprint）の作成が完了し、Kazumaxの承認に基づき総合改修サイクルがスタート。
- Air(P1): 完了（`docs/handoff/P1_Air_Blueprint/cycle_21_comprehensive_safety_and_ui_optimization.md` に保管済み）
- Dex(P2): 事前監査完了。`書類.xlsx`クリーン化・ワンタッチ切替UIはDexが不採用と判断し範囲外に。複数Expense保存ガード・既存DB対応の冪等UNIQUE移行・印刷状態更新の全件ロールバックをCC必須条件として固定し、`docs/handoff/P2_Dex_to_CC/cycle_21_comprehensive_safety_and_ui_instructions.md`を作成済み
- CC(P3): A)複数Expense保存ガード（editForm/save、破壊的処理より前に配置）B)expenses.project_participant_idへの一意制約（新規DB用CREATE TABLE＋既存DB向け冪等マイグレーション）C)`ProjectService.updatePrintedStatusAtomic`による印刷状態一括更新の`@Transactional`化（全件存在確認→全件更新の二段階、不正ID混在で全件ロールバック）D)UI調整を実装。app.version=v2.6.0。テスト8/8成功。実機でID1のみ印刷済み→復元、不正ID混在時のロールバックをHTTP/DB照合で確認。CCクルー3観点セルフレビュー完了（指摘なし）。`docs/handoff/P3_CC_to_Dex/cycle_21_comprehensive_safety_and_ui.md`に報告書を保存済み

## 次の担当

- **Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_21_comprehensive_safety_and_ui.md`を読んでDIFFレビューする。保存ガードが破壊的処理より前か、既存DB移行の冪等性、一括更新の全件ロールバック、通常/legacy出力・年度末Excel・金額への不干渉を重点確認

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P4_Rollback/cycle_19_input_output_role_separation_take2.md`（第6〜7章: 実測値・Cycle 20必須範囲）
8. `docs/proposals/backlog_ui_ux.md`（第3章: 年度末Excel監査の実測所見）
9. `docs/handoff/P4_Dex_Review/cycle_19_input_output_role_separation_take3.md`（Cycle 19完了記録）
10. `docs/handoff/cycle_20_kazumax_to_air_requirements.md`（Kazumax確定要件）
11. `docs/handoff/P1_Air_Blueprint/cycle_20_annual_excel_integrity.md`（Air試作品の設計記録）
12. `docs/handoff/P2_Dex_to_CC/cycle_20_annual_excel_integrity_instructions.md`（CC向け最終指示書）

## Cycle 19 重要ルール

- 活動一覧は入力・編集中心、出力画面は対象選択・プレビュー・Excel出力・印刷状態管理中心にする。
- Excelダウンロードだけで自動的に印刷済みにしない。実印刷後に利用者が明示操作する。
- 年度末一括出力は様式2-1〜2-6を従来どおり含み、対象条件と合計を変えない。
- 個人雑費の画面注記は削除候補だが、DB値・既存値保持・様式2-6・原本Excel欄は削除しない。
- 旧出力URL・legacy `/export` は即時削除しない。
- Air(P1) -> Dex(P2) -> CC(P3) -> Dex(P4) の完全プロセスを通す。

## Stop Conditions

- `git reset --hard` / `git restore .` / `git clean` の自動実行の禁止
- `git add .` の自動実行の禁止
- 作業中の他AI/ユーザー差分を勝手に見落として戻さないこと
- 金額計算、Excel出力、DB、mapper、schemaに触る変更は、Air(P1) -> Dex(P2) -> CC(P3) -> Dex(P4) の完全プロセスを通す

## 履歴アーカイブ
- 古い進捗や過去サイクルの読み物一覧は `docs/handoff/STATUS_ARCHIVE.md` を参照
- 各サイクルの正式記録は `docs/handoff/P1_Air_Blueprint/`, `docs/handoff/P2_Dex_to_CC/`, `docs/handoff/P3_CC_to_Dex/`, `docs/handoff/P4_Dex_Review/`, `docs/handoff/P4_Rollback/` に保存済み
