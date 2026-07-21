[C12: CC(P3) => Dex(P4) Final Hardening Take2]

# Cycle 12 最終硬化 Take2 実装完了報告

## 対応した指摘

`docs/handoff/P4_Rollback/cycle_12_final_hardening.md` のP2指摘2件（handoff自己完結性・ActivityController未コミット差分）に対応した。P1/P3は指摘なし・対応不要。

### P2-1: `CURRENT_STATUS.md` が参照するCycle 12 handoff/proposalsが未追跡だった件（完了）

`CURRENT_STATUS.md` の「読むべきファイル」に列挙されている、Cycle 12A/12B/12C/最終硬化の一連のP1〜P4・proposalsファイルをすべてコミット対象に追加した。

追加した内訳:

- P1_Air_Blueprint: `cycle_12_annual_export_draft.md`, `cycle_12_annual_export_take2.md`, `cycle_12b_12c_planning.md`
- P2_Dex_to_CC: `cycle_12_annual_export_pre_audit.md`, `cycle_12_annual_export_take2_final_instructions.md`, `cycle_12_original_formula_audit.md`, `cycle_12b_budget_allocations_form23_instructions.md`, `cycle_12c_preview_ui_instructions.md`
- P3_CC_to_Dex: `cycle_12_annual_export_12a.md`, `cycle_12_annual_export_12a_take2.md`, `cycle_12_annual_export_12a_take3.md`, `cycle_12b_budget_allocations_form23.md`, `cycle_12b_budget_allocations_form23_take2.md`, `cycle_12c_preview_ui.md`, `cycle_12c_preview_ui_take2.md`
- P4_Dex_Review: `cycle_12_annual_export_12a_take3.md`, `cycle_12b_budget_allocations_form23_take2.md`, `cycle_12c_preview_ui_take2.md`
- P4_Rollback: `cycle_12_annual_export_12a.md`, `cycle_12_annual_export_12a_take2.md`, `cycle_12_final_hardening.md`（DexのTake2 NGレビュー本体）, `cycle_12b_budget_allocations_form23.md`, `cycle_12c_preview_ui.md`
- proposals: `CC_cycle_12_template_slim.md`, `CC_cycle_12b_dev_launch_config.md`, `Dex_cycle_12_annual_export_split.md`

`CURRENT_STATUS.md` が参照する `docs/handoff/P4_Rollback/cycle_12_final_hardening_cc_instructions.md` / `cycle_12_overall_final_review.md` / `docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening.md` はTake1コミット（`539d371`）で既に含まれている。

これにより、`CURRENT_STATUS.md` が「読むべきファイル」として列挙するCycle 12関連ファイルは、今回のコミット後のHEADからすべて読める状態になった。リストからの削除は行っていない（すべて実ファイルとして取り込む方針で対応）。

Cycle 8〜11・マニュアル再編・dummy系ファイルなど、`CURRENT_STATUS.md`が参照していないファイル群は、Take1報告時と同様に範囲外として今回も対象外とした。

### P2-2: `ActivityController.java` のCycle 12A差分が未コミットだった件（完了・「残す」方針で確定）

`docs/handoff/P4_Rollback/cycle_12_final_hardening.md` の指摘通り、`/activity/export/annual`（Cycle 12A由来の既存互換直リンク）の差分が未コミットのまま残っていた。

Cycle 12A/12Cのhandoff（`docs/handoff/P3_CC_to_Dex/cycle_12_annual_export_12a.md` 等、複数箇所）で「既存互換ルートとして残す」と繰り返し記録されている方針に従い、**残す**を選択し、この差分をそのままコミット対象に含めた。`ExcelExportService.exportAnnualClosingBook(...)` は既にTake1コミットで取り込み済みのため、依存関係の欠落はない。

`CURRENT_STATUS.md` 側の残リスク記載（「旧直リンク `/activity/export/annual` は提出情報入力なしの互換経路として残っている」）と実装が一致する状態になった。

バージョンは、Dexの指示通り新規機能追加ではなく既存決定の取り込みのため `v2.4.3` のまま据え置いた。

## 変更・追加したファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`（Cycle 12A互換ルート `/export/annual` を取り込み）
- Cycle 12関連 handoff/proposals 計26ファイル（上記「P2-1」の内訳を参照。新規追加のみで、既存ファイルの内容変更なし）
- `docs/handoff/CURRENT_STATUS.md`（次担当をDex(P4) Take2再レビューへ更新）

## app.version

`v2.4.3`（変更なし。Take2は既存決定の取り込みであり新規コード追加ではないため据え置き）

## 実行した検証コマンドと結果

```powershell
.\mvnw.cmd -q -DskipTests compile
# → 成功（エラーなし）

Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
# → 両方とも app.version=v2.4.3 で一致
```

## resources混入確認結果

```powershell
Get-ChildItem -Recurse target\classes\templates | Where-Object { $_.Name -match '\.(py|txt|csv|tmp|bak)$' }
# → 該当ファイルなし
```

## Cycle 12本体ファイルの取り込み漏れ確認結果

- Take1で指摘された14ファイルは引き続きHEADに含まれている（変更なし）。
- 今回のTake2で、`CURRENT_STATUS.md` が参照するCycle 12 P1〜P4・proposalsファイル一式、および `ActivityController.java` のCycle 12A差分を追加で取り込んだ。
- `git status --short` で確認する限り、Cycle 12関連（`cycle_12*` 命名）で未追跡のまま残っているファイルはない。

## 残リスク

1. Take1報告時と同様、Cycle 8〜11分・マニュアル再編・`.cursorrules`/`AGENTS.md`/`CLAUDE.md`/`AI_TEAM_WORKFLOW.md`/`mvnw.cmd`等の大量の未コミット差分は、`CURRENT_STATUS.md`が参照しないため今回も対象外。別タスクでの棚卸しを推奨（Take1から継続）。
2. `mvnw clean compile`はOneDrive同期フォルダ配下という環境要因で不安定になることがある（Take1で確認済み）。今回は`clean`なしの`compile`のみで検証した。Dexの前回レビューでも通常`compile`成功のみを確認しているため、検証条件としては前回と同等。
3. 実DBでの本番データ出力は未実行（継続する残リスク）。
4. `projects.target_category`はDB上nullableのまま（継続する残リスク）。
5. 不正POSTの型変換エラーが`invalid_input`に統一されない件（DexのP3所見）は、今回対応不要と指示されたため未対応。

## 次への合図

```text
CCがCycle 12最終硬化のTake2修正（handoff/proposals取り込み・ActivityController.java整理）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_12_final_hardening_take2.md を読んで、事後レビュー（P4）をお願いします。
```
