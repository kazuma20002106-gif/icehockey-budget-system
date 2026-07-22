# 📍 CURRENT STATUS（現在地確認）

> [!CAUTION]
> **【Kazumax代表からの全体絶対ルール】**
> 「入力が簡単になっても、合算がうまくいってなかったらツールとしては全く意味がなく、正しくない書類が出来上がるだけ。合算が正常に行われているかが第一優先」

---

# Current cycle
フェーズ2 本番環境（サーバー）構築

## 現在地
- **Phase2**: Air(P1)が、Linux VPSへのデプロイに向けたBlueprintを作成し、KazumaxのVPS契約状況を確認中。
- **Cycle 16**: 完了（UI大改造は行わず、運用制限ルールで対応することに決定）。システム開発フェーズは完結。
- **最終出荷レビュー**: Air視点（`docs/handoff/P1_Air_Blueprint/final_release_review_air.md`）で異常なし・デプロイ準備完了と判定済み。続けてCC(P3)視点で実装・実機・compile・Excel出力・git状態を検品。`git status`・`app.version`・compile・`/activity`・legacy 2-2/2-6・年度末preview・Excel出力ともに異常なし。年度末Excelの様式2-2内クロスシート式に既知ダミー値`830550`のキャッシュ残りを1件発見したが、参照元セルは正しい値(37,519)に更新済みで`fullCalcOnLoad="true"`により実害なしと確認済み（詳細は`docs/handoff/P3_CC_to_Dex/final_release_review_cc.md`）。Dex(P4)の最終統合レビュー待ち

## 次の担当
**Dex(P4)**: `docs/handoff/P1_Air_Blueprint/final_release_review_air.md`（Air視点レビュー）と `docs/handoff/P3_CC_to_Dex/final_release_review_cc.md`（CC視点レビュー・最優先）を読み、最終統合レビュー（デプロイ判定）をお願いします。OKであれば、Kazumaxへ`docs/handoff/P1_Air_Blueprint/phase2_server_deployment.md`のVPS契約状況確認を案内する流れになります。

## 読むべきファイル
- `docs/handoff/CURRENT_STATUS.md`（このファイル）
- `docs/handoff/P1_Air_Blueprint/final_release_review_air.md`（Air視点の最終出荷レビュー・最優先）
- `docs/handoff/P3_CC_to_Dex/final_release_review_cc.md`（CC視点の最終出荷レビュー・最優先）
- `docs/handoff/P1_Air_Blueprint/cycle_16_next_phase_planning.md`（Cycle 16 Blueprint。運用制限ルールで対応する方針が確定した経緯）
- `docs/handoff/P1_Air_Blueprint/phase2_server_deployment.md`（フェーズ2 VPS本番環境構築のBlueprint）
- `docs/handoff/P4_Dex_Review/cycle_15_policy_and_cleanup_take2.md`（DexのCycle 15 Take2 P4 OKレビュー）
- `docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup_take2.md`（CCのTake2修正完了報告・最優先）
- `docs/handoff/P4_Rollback/cycle_15_policy_and_cleanup.md`（DexのCycle 15 P4 NGレビュー・CC Take2指示）
- `docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup.md`（CCのTake1実装・検証完了報告）
- `docs/handoff/P2_Dex_to_CC/cycle_15_policy_and_cleanup_instructions.md`（DexのCycle 15 P2最終指示書）
- `docs/handoff/P1_Air_Blueprint/cycle_15_policy_and_cleanup.md`（AirのCycle 15 Blueprint）
- `docs/handoff/P4_Dex_Review/cycle_14_overall_audit_and_repo_cleanup.md`（DexのCycle 14 P4 OKレビュー・最優先）
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
- 次Cycleで個人雑費の扱いを修正する場合は、Air(P1)方針確認 → Dex(P2)事前監査 → CC(P3)実装 → Dex(P4)レビューの完全プロセスを通す
- 個人雑費 `miscellaneousCost` と旅行雑費 `travelMiscCost` を混同しない
- 2-2集計に個人雑費 `miscellaneousCost` を追加しない
- DBスキーマ、mapper SQL、Excelテンプレート本体は変更しない
- 複数Expense対応をpreviewだけに閉じず、Excel出力側の読み込み方針とも金額を一致させる

## Kazumax向け短縮チェック

Cycle 15はDex(P4) Take2レビューでOK、AIレビュー上完了です。最終出荷レビューはAir・CCともに「異常なし」判定で、Dex(P4)の最終統合レビュー待ちです。

Kazumaxが実機で軽く見るなら:
1. `/activity?year=2026` を開き、表示ラベルが「決算書計上額」になっている
2. 2026年度が事業件数8件・延べ参加人数30名・決算書計上額481,179円で表示される
3. どれか1件を編集画面で開き、参加者追加ボタンを押しても画面が崩れず、保存できる
4. legacy「提出データ出力・集計」から2-2 previewと2-6 previewが開ける
5. 2-6 previewで個人別明細が表示される
6. 年度末決算ファイル出力（`/export/year/setup`）からpreview・Excelダウンロードが開ける

## Kazumaxが次にコピーする合図文（Dexへの最終統合レビュー依頼）
```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
Air視点(異常なし)・CC視点(異常なし、ただし年度末Excelのクロスシート式キャッシュに関する1件の発見事項あり)の最終レビューが揃いました。
docs/handoff/P1_Air_Blueprint/final_release_review_air.md と docs/handoff/P3_CC_to_Dex/final_release_review_cc.md を読んで、最終統合レビュー(デプロイ判定)をお願いします。
```
