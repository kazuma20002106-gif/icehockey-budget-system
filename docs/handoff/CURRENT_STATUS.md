# 📍 CURRENT STATUS（現在地確認）

> [!CAUTION]
> **【Kazumax代表からの全体絶対ルール】**
> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類が出来上がるだけ。合算が正常に行われているかが第一優先」

---

# Current cycle
Cycle 12 年度末決算ファイル一括出力（全様式対応）

## 現在地
- **12A**: Dex(P4) Take3再レビューOK。年度末決算ファイル一括出力の土台は完了
- **12B**: Dex(P4) Take2再レビューOK。予算管理・様式2-3連動は完了
- **12C**: Dex(P4) Take2再レビューOK。年度末出力UI・タブプレビューは完了
- **Cycle 12全体**: `v2.4.4`。年度末出力専用フロー `/export/year/preview` / `/export/year/download` の対象事業0件時リダイレクト不具合（日本語提出情報を含む`Location`ヘッダがTomcatに削除される問題）を、CC(P3)がTake3で修正済み。Dex(P4)の再レビュー待ち
- **Cycle 13候補**: CCが別途発見した旅行雑費の画面表示バグは、Dexとデクスクルーで独立確認済み。legacy `/export` は現役導線であり、`expenses.project_participant_id` にUNIQUE制約がないため `ExportController.preview()` の `exList.get(0)` はバグ確定。詳細は `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`（AirへのCycle 13起票トリガー案あり。Cycle 12のTake3完了・Dex再レビュー後に着手）

## 次の担当
**Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md`（CCのTake3修正完了報告）を読み、`ExportController.noDataRedirectUrl(...)`のpercent-encoding対応を再レビューしてください。OKであれば、`docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`のAir起票トリガーをKazumaxへ案内する流れになります。

## 読むべきファイル
- `docs/handoff/CURRENT_STATUS.md`（このファイル）
- `docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md`（CCのTake3修正完了報告・最優先）
- `docs/handoff/P4_Rollback/cycle_12_practical_check.md`（Dexの実機自動確認NGレポート・元指示）
- `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`（Dexによる旅行雑費バグの独立確認・Cycle 13起票案）
- `docs/handoff/P3_CC_to_Dex/cycle_12_realmachine_check_and_bug_report_for_dex.md`（CCによるDex向け一本化報告）
- `docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md`（CCによるKazumaxチェックリスト代行実施記録）
- `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`（Dexとデクスクルーによる旅行雑費・legacy previewバグ確認。次サイクル起票候補）
- `docs/proposals/CC_activity_list_travel_misc_total_bug.md`（新規発見バグ2箇所の＋α提案。次サイクル起票候補）
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
- 自動ロールバック
- Kazumaxの明示承認なしの外部モデル/API呼び出し・課金発生操作
- 金額計算・Excel出力が含まれるため、**Dex(P2)の事前監査なしでCC(P3)へ直行することの禁止**
- CCは `docs/handoff/P2_Dex_to_CC/cycle_12_annual_export_take2_final_instructions.md` に書かれたCycle 12Aの範囲だけ実装する
- 12AのDex(P4) OKが出るまで、12Bのコード・DB・テンプレート・HTMLを変更しない
- 12Bは `docs/handoff/P2_Dex_to_CC/cycle_12b_budget_allocations_form23_instructions.md` の範囲だけ実装する
- 12BのDex(P4) OKが出るまで、12C（大容量プレビューUI、タブ化、出力前確認モーダル、preview-yearly API）は実装しない
- 12Cは開始時に `docs/handoff/P2_Dex_to_CC/cycle_12c_preview_ui_instructions.md` を最優先で読む
- 本物原本にはトップチーム用2-2-1シートが存在する。今回はKazumax判断により出力対象に含める
- 2-2の直値セル、2-1セル座標、外部リンクはDex最終指示書の内容を優先し、推測で実装しない

## Kazumaxが次にコピーする合図文（Dexへの Take3 事後レビュー依頼）
```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
CCがCycle 12実機自動確認のTake3修正（noDataRedirectUrlのpercent-encoding対応）を完了しました。v2.4.4です。
docs/handoff/P3_CC_to_Dex/cycle_12_practical_check_take3.md を読んで、事後レビュー（P4）をお願いします。
OKであれば、あなたが作成した docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md のAir起票トリガーへ進める想定です。
```
