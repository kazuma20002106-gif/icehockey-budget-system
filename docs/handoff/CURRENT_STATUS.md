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
- **Cycle 12全体**: Dex(P4) Take2再レビューOK。`v2.4.3` / `c1db501` として、handoff/proposals自己完結性と `ActivityController.java` のCycle 12A互換ルート取り込みを確認済み。CCがKazumax実機確認チェックリスト6項目を代行実施し、全てOK。ただし確認中にCycle 12スコープ外の既存バグ（活動一覧の支出合計が旅行雑費を含まず過小集計）を発見。Kazumaxの最終ジャッジ待ち

## 次の担当
**Kazumax最終ジャッジ**: `docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md` の実施結果（チェックリスト6項目は全OK）と、新規発見バグの扱いを確認し、Cycle 12を完了として次サイクルへ進めるか判断してください。新規バグの修正は `docs/proposals/CC_activity_list_travel_misc_total_bug.md` を次サイクルの起票候補としてAirへ回す想定です。

## 読むべきファイル
- `docs/handoff/CURRENT_STATUS.md`（このファイル）
- `docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md`（CCによるKazumaxチェックリスト代行実施記録・新規バグ発見あり・最優先）
- `docs/proposals/CC_activity_list_travel_misc_total_bug.md`（新規発見バグの＋α提案。次サイクル起票候補）
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

## Kazumax用メモ（Cycle 12最終確認・実施済み）
```text
CCがKazumax最終確認チェックリスト6項目を代行実施しました。全項目OKです。
docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md を確認してください。

ただし確認中に、Cycle 12のスコープ外の既存バグ（活動一覧の支出合計が旅行雑費を含まず過小集計される。Excel出力自体は正しい）を発見しました。
docs/proposals/CC_activity_list_travel_misc_total_bug.md に詳細と修正方針案があります。

Cycle 12自体を完了とするか、この新規バグ対応を先に行うかはKazumax判断でお願いします。
```
