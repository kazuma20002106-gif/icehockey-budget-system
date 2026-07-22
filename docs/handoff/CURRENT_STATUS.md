# 📍 CURRENT STATUS（現在地確認）

> [!CAUTION]
> **【Kazumax代表からの全体絶対ルール】**
> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類が出来上がるだけ。合算が正常に行われているかが第一優先」

---

# Current cycle
Cycle 14 全体バグ監査およびリポジトリ健全化

## 現在地
- **14**: Air(P1) がバグ監査・リポジトリ健全化の修正計画(Blueprint)を起票完了
- **14**: Dex(P2) がデクスクルーAを使って観点漏れを事前監査し、CC(P3)向け最終指示書を作成済み。`docs/handoff/P2_Dex_to_CC/cycle_14_overall_audit_instructions.md`
- **14**: CC(P3)が監査・健全化を完了。`git status`未追跡77件+変更11件(計88件)を精査し、62件をコミット(`d3a992e`)・16件を個別削除・3件を保留(判断待ち)まで削減。JDBC一時ヘルパーで複数Expense実データ検証(ケースA〜E)を実施し全てOK。新規発見事項1件（`/activity`合計と様式2-2系合計が個人雑費ありの場合に構造的不一致）を`docs/proposals/CC_cycle_14_audit_findings.md`に報告。コード変更なしのため`app.version`は`v2.4.6`のまま。Dex(P4)レビュー待ち

## 次の担当
**Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md`（CCの監査・健全化完了報告・最優先）を読み、事後レビューをお願いします。`docs/proposals/CC_cycle_14_audit_findings.md`（個人雑費と様式2-2系合計の不一致）の対応方針判断もあわせてお願いします。

## 読むべきファイル
- `docs/handoff/CURRENT_STATUS.md`（このファイル）
- `docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md`（CCの監査・健全化完了報告・最優先）
- `docs/proposals/CC_cycle_14_audit_findings.md`（新規発見事項：個人雑費と様式2-2系合計の不一致・対応方針の選択肢）
- `docs/handoff/P2_Dex_to_CC/cycle_14_overall_audit_instructions.md`（DexのCycle 14 P2最終指示書）
- `docs/handoff/P1_Air_Blueprint/cycle_14_overall_audit_planning.md`（AirのCycle 14 Blueprint）
- `docs/handoff/P4_Dex_Review/cycle_13_travel_misc_preview_totals_take2.md`（DexのCycle 13 Take2 P4 OKレビュー・最優先）
- `docs/handoff/P3_CC_to_Dex/cycle_13_travel_misc_preview_totals_take2.md`（CCのTake2修正完了報告・最優先）
- `docs/handoff/P4_Rollback/cycle_13_travel_misc_preview_totals.md`（DexのCycle 13 P4 NGレビュー・CC Take2指示）
- `docs/handoff/P3_CC_to_Dex/cycle_13_travel_misc_preview_totals.md`（CCのCycle 13 Take1実装完了報告）
- `docs/handoff/P2_Dex_to_CC/cycle_13_travel_misc_preview_totals_instructions.md`（DexのCycle 13 P2最終指示書）
- `docs/handoff/P1_Air_Blueprint/cycle_13_travel_misc_preview_totals.md`（AirのCycle 13 Blueprint）
- `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`（Dexによる旅行雑費バグの独立確認・Cycle 13起票案）
- `docs/proposals/CC_activity_list_travel_misc_total_bug.md`（新規発見バグ2箇所の＋α提案）
- `docs/proposals/Dex_cycle_13_multiple_expense_edit_ui_followup.md`（Cycle 13後の複数Expense編集UIフォロー提案）
- `docs/handoff/P4_Dex_Review/cycle_12_practical_check_take3.md`（DexのTake3 P4 OKレビュー）
- `docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md`（CCのTake3修正完了報告・最優先）
- `docs/handoff/P4_Rollback/cycle_12_practical_check.md`（Dexの実機自動確認NGレポート・元指示）
- `docs/handoff/P3_CC_to_Dex/cycle_12_realmachine_check_and_bug_report_for_dex.md`（CCによるDex向け一本化報告）
- `docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md`（CCによるKazumaxチェックリスト代行実施記録）
- `docs/handoff/P4_Dex_Review/cycle_12_final_hardening_take2.md`（DexのCycle 12最終硬化 Take2 P4 OKレビュー）
- `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening_take2.md`（CCのTake2修正 完了報告）
- `docs/handoff/P4_Rollback/cycle_12_final_hardening.md`（DexのCycle 12最終硬化 P4 NGレビュー・Take2で対応済み）
- `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md`（CCの最終硬化 Take1完了報告）
- `docs/handoff/P4_Rollback/cycle_12_final_hardening_cc_instructions.md`（DexのCC向け最終硬化指示）
- `docs/handoff/P4_Rollback/cycle_12_overall_final_review.md`（DexのCycle 12全体レビュー。最終ゲート指摘あり）
- `docs/handoff/P4_Dex_Review/cycle_12c_preview_ui_take2.md`（Dexの12C Take2 P4 OKレビュー）
- `docs/handoff/P3_CC_to_Dex/cycle_12c_preview_ui_take2.md`（CCの12C Take2修正完了報告）
- `docs/handoff/P4_Rollback/cycle_12c_preview_ui.md`（Dexの12C P4 NGレビュー・Take2で対応済み）
- `docs/handoff/P3_CC_to_Dex/cycle_12c_preview_ui.md`（CCの12C Take1実装完了報告）
- `docs/handoff/P4_Dex_Review/cycle_12b_budget_allocations_form23_take2.md`（Dexの12B Take2 P4 OKレビュー）
- `docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23_take2.md`（CCの12B Take2修正完了報告。Finding P1への反論根拠を含む）
- `docs/handoff/P4_Rollback/cycle_12b_budget_allocations_form23.md`（Dexの12B P4 NGレビュー）
- `docs/proposals/CC_cycle_12b_dev_launch_config.md`（CCからの＋α提案：開発用起動設定）
- `docs/handoff/P3_CC_to_Dex/cycle_12b_budget_allocations_form23.md`（CCの12B Take1実装完了報告）
- `docs/handoff/P4_Dex_Review/cycle_12_annual_export_12a_take3.md`（Dexの12A Take3 P4 OKレビュー）
- `docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a_take3.md`（CCの12A Take3修正完了報告）
- `docs/handoff/P4_Rollback/cycle_12_annual_export_12a_take2.md`（Dexの12A Take2 P4 NGレビュー・Take3で対応済み）
- `docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a_take2.md`（CCの12A Take2修正完了報告）
- `docs/handoff/P4_Rollback/cycle_12_annual_export_12a.md`（Dexの12A P4 NGレビュー・Take2で対応済み）
- `docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a.md`（CCの12A Take1実装完了報告）
- `docs/proposals/CC_cycle_12_template_slim.md`（CCからの＋α提案：未使用シート整理）
- `docs/handoff/P1_Air_Blueprint/cycle_12b_12c_planning.md`（Airが作成した12B/12C草案）
- `docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_pre_audit.md`（Dexの事前監査結果）
- `docs/handoff/P2_Dex_to_CC/cycle_12_original_formula_audit.md`（本物原本Excelの数式参照監査）
- `docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_take2_final_instructions.md`（DexのCC向け最終指示書）
- `docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md`（Dexの12B向け強化済み最終指示書）
- `docs/handoff/P2_Dex_to_CC/cycle_12c_preview_ui_instructions.md`（Dexの12C向け強化済み予約指示書）
- `docs/proposals/Dex_cycle_12_annual_export_split.md`（Dexの分割提案）

## 現在のStop Conditions / 禁止事項
- `git reset --hard` / `git restore .` / `git clean` の自動実行
- `git add .` の自動実行
- 自動ロールバック
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作
- 金額計算・Excel出力が含まれるため、**Dex(P2)の事前監査なしでCC(P3)へ直行することの禁止**
- Cycle 14は `docs/handoff/P2_Dex_to_CC/cycle_14_overall_audit_instructions.md` の範囲だけ実行する
- Cycle 14は監査とリポジトリ健全化が主目的。バグを見つけても無断で金額/Excel/DB/保存処理を修正しない
- 個人雑費 `miscellaneousCost` と旅行雑費 `travelMiscCost` を混同しない
- 2-2集計に個人雑費 `miscellaneousCost` を追加しない
- DBスキーマ、mapper SQL、Excelテンプレート本体は変更しない
- 複数Expense対応をpreviewだけに閉じず、Excel出力側の読み込み方針とも金額を一致させる

## Kazumaxが次にコピーする合図文（Dexへの Cycle 14 事後レビュー依頼）
```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
CCがCycle 14（全体バグ監査およびリポジトリ健全化）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md を読んで、事後レビュー（P4）をお願いします。

発見事項が1件あります。/activity一覧の支出合計と様式2-2系の総合計が、個人雑費がある場合に構造的に一致しません。
docs/proposals/CC_cycle_14_audit_findings.md に詳細と対応方針の選択肢をまとめました。バグ修正はせず報告のみです。

保留対象が3件あります（ルート直下のAI_TEAM_WORKFLOW.md、app_run_latest.pid、docs/manual_legacy/配下7ファイル）。P3報告書の分類表を確認してください。
```
