# CURRENT STATUS

> [!CAUTION]
> **Kazumax代表からの全体絶対ルール**
> 入力が簡単になっても、合算が正しくなければツールとして意味がない。合算が正常に行われているかを第一優先にする。

## Current Cycle

- Cycle 19: 入力・出力ページの役割分離と印刷状態導線整理

## 現在地

- Cycle 18: P4 OK。Kazumax確認を経て完了扱い
- Cycle 19: Air(P1) によるBlueprint（要件と12の必須受入確認・不可触領域設計）の構築が完了。
- Air(P1): 完了（`docs/handoff/P1_Air_Blueprint/cycle_19_input_output_role_separation.md` に保管済み）
- Dex(P2): 事前監査完了。Air案の旧年度まとめ説明、旅行雑費固定表現、暗黙印刷フィルタ、hidden/query保持を補正し、CC向け最終指示書を作成済み
- CC(P3): 実装・検証・CCクルー3観点セルフレビュー完了。app.version=v2.5.1。`docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation.md` に報告書を保存済み
- Dex(P4): commit `466ad9d` をレビューし、通常preview往復で6検索条件が失われるP1要件漏れを確認。Take2差し戻し
- CC(P3) Take2: `/export/preview`往復での6条件（year/budgetTypeId/month/targetCategory/projectName/printedStatus）保持を修正。app.version=v2.5.2。CCクルー3観点セルフレビュー完了。`docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation_take2.md` に報告書を保存済み

## 次の担当

- **Dex(P4) Take2レビュー**: `docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation_take2.md` を読んでDIFFレビューする。6条件のpreview往復、日本語URL、金額・Excel不可触領域、既存URLを重点確認

## 今回読むべきファイル

1. `AGENTS.md`
2. `manuals/STARTUP_CHECKLIST.md`
3. `docs/PROJECT_RULES.md`
4. `docs/handoff/WORKFLOW_RULES.md`
5. `manuals/AI_TEAM_WORKFLOW.md`
6. `manuals/WORKFLOW_RULES.md`
7. `docs/handoff/P1_Air_Blueprint/cycle_19_input_output_role_separation.md`
8. `docs/handoff/cycle_19_kazumax_to_air_requirements.md`
9. `docs/handoff/P2_Dex_to_CC/cycle_19_input_output_role_separation_instructions.md`
10. `docs/handoff/P3_CC_to_Dex/cycle_19_input_output_role_separation.md`
11. `docs/handoff/P4_Rollback/cycle_19_input_output_role_separation.md`

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
