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
- **Cycle 12全体**: Dex(P4)全体レビューで機能面はおおむねOK。最終ゲート指摘（未追跡ファイル・clean compile未完了・予算保存検証強化）を受け、CC(P3)が最終硬化を実施済み（`v2.4.3`）。Dex(P4)の事後レビュー待ち

## 次の担当
**Dex(P4)**: `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md` を読み、CCの最終硬化（予算保存検証強化・バージョン更新・clean compile代替検証・未追跡ファイル取り込み確認）を事後レビューしてください。

## 読むべきファイル
- `docs/handoff/CURRENT_STATUS.md`（このファイル）
- `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md`（CCの最終硬化 完了報告・最優先）
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

## Kazumaxが次にコピーする合図文（CCへのCycle 12最終硬化依頼）
```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

CCへ：
DexがCycle 12全体レビューを行い、機能面はおおむねOKでしたが、最終ゲートとして未追跡ファイル・clean compile未完了・予算保存検証強化の指摘が出ました。
docs/handoff/P4_Rollback/cycle_12_final_hardening_cc_instructions.md を読んで、必要な最終硬化を実施してください。
```
