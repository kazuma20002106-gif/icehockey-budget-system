[Dex ⇒ Air/Kazumax/CC]

# Cycle 13候補: 旅行雑費の画面表示合算漏れ・legacy preview複数Expense過小集計

## 結論

CCの報告 `docs/proposals/CC_activity_list_travel_misc_total_bug.md` は妥当。
Kazumax確認により legacy `/export` は現役導線であり、`schema.sql` 確認により `ExportController.preview()` の `exList.get(0)` は「未確認事項」ではなくバグ確定として扱う。

ただし、金額計算・`src/main/java` 変更を含むため、Cycle 12の対象事業0件リダイレクト修正が完了した後、次サイクルで Air(P1) → Dex(P2) → CC(P3) → Dex(P4) の完全プロセスで扱う。

## Dex独立確認

### 1. `/activity` 活動一覧の支出合計

- 対象: `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- 現状:
  - 参加者ごとの `Expense` は全件ループして交通費・宿泊費・雑費を合算している。
  - `ProjectSummaryExpense` は借用料・需用費・駐車料金・報償費・役務費の5費目だけを合算している。
  - `travelMiscCost * 参加者数 * travelMiscDays` が未加算。
- 結果:
  - 旅行雑費がある事業では、活動一覧の支出合計がExcel出力より少なく表示される。
  - 今回の確認データでは160,000円のズレが報告されている。

### 2. legacy `/export` の `exportType=2-2` プレビュー

- 対象: `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- 現状:
  - `grandTotal` は交通費・宿泊費・借用料・需用費・駐車料金・報償費・役務費で作られている。
  - 旅行雑費が未加算。
  - `src/main/resources/templates/export/preview.html` の様式2-2プレビュー表にも旅行雑費の表示行がない。
- 結果:
  - legacy 2-2プレビュー画面の総合計がExcel出力より少なく表示される。
  - この `/export` 画面は現役導線なので、`/activity` と同等優先度で修正対象に含める。

### 3. `ExportController.preview()` の `exList.get(0)` 問題

- 対象:
  - `ExportController.preview()` の `exportType=2-2` 分岐
  - `ExportController.preview()` の `exportType != 2-2` 分岐
- 現状:
  - 参加者に紐づく `Expense` の先頭1件だけを交通費・宿泊費集計に使っている。
  - `schema.sql` の `expenses.project_participant_id` にはUNIQUE制約がない。
  - `ExpenseMapper.xml` も複数行を返す `List<Expense>` 設計。
- 補足:
  - 通常保存フローは現状1参加者1Expenseを作る動きだが、DB/mapper上は複数Expenseを排除していない。
- 結果:
  - 1参加者に複数Expenseがある場合、2件目以降の交通費・宿泊費がプレビュー集計から漏れる。

## デクスクルー確認結果

今回は金額表示・既存導線・横断確認が絡むため、デクスクルーを使った。

- 旅行雑費の合算漏れは実在する。
- 同系統の「ProjectSummaryExpense 5費目合計から旅行雑費だけ抜け」箇所は、`ActivityController` と `ExportController` の2箇所に絞れる。
- `ExcelExportService` 側の様式2-2/年度末出力は旅行雑費を含めており、Excel出力自体は今回の主修正対象ではない。
- `exList.get(0)` は複数Expense時に過小集計になり得る。DB構造上も複数Expenseを否定できない。

## 次サイクルでの推奨スコープ

### 必須修正

1. `ActivityController.list(...)`
   - 活動一覧の事業別支出合計とページ下部合計に旅行雑費を含める。
   - 計算式は単一事業文脈のExcelExportServiceと揃える。
   - 推奨式: `travelMiscCost * parts.size() * travelMiscDays`

2. `ExportController.preview(...)` の `exportType=2-2`
   - 旅行雑費を合算し、`grandTotal` に含める。
   - モデルに `totalTravelMisc` などを追加し、テンプレート側にも「旅行雑費」行を表示する。
   - 交通費・宿泊費は `exList.get(0)` ではなく、全Expense合算にする。

3. `ExportController.preview(...)` の `exportType != 2-2`
   - `transportSum` / `accommodationSum` を全Expense合算にする。
   - 様式2-6プレビューの参加者明細は、画面上1行表示のまま先頭1件を表示するのか、複数Expenseを合算した表示用Expenseを作るのかをAir(P1)で決める。
   - 少なくとも集計値は全Expenseを含める。

### 原則触らない範囲

- Excel出力の主計算は今回の確認では正しいため、原則として変更しない。
- 既にOK済みのCycle 12年度末一括出力UI・Excel処理は、回帰確認対象に留める。
- DBスキーマにUNIQUE制約を追加して複数Expenseを禁止する方向は、既存データを壊す可能性があるため今回は採用しない。

## 検証条件

最低限、以下を確認する。

1. `mvn -q -DskipTests compile`
2. `/activity` で旅行雑費がある年度を表示し、支出合計がExcel様式2-2の合計と一致すること。
3. legacy `/export` の `exportType=2-2` プレビューで旅行雑費行が表示され、総合計がExcelダウンロード結果と一致すること。
4. 1参加者に複数Expenseを持つテストデータで、legacy `/export` プレビューの交通費・宿泊費合計が全件分を含むこと。
5. Cycle 12で追加した `/export/year/setup` → preview → download が壊れていないこと。
6. 実装時はバージョンを更新すること。

## 注意点

- 画面表示だけのバグに見えるが、ユーザーは画面表示を見て確認するため、金額の信頼性に直結する。
- `/export` は古い画面ではなく現役導線。年度末一括出力とは別に守る。
- `miscellaneousCost` と `travelMiscCost` は別物。参加者ごとの雑費と、事業サマリ側の旅行雑費を混同しない。
- `parts.size()` は参加者数ベース。監督・選手数だけを使う別文脈の式と混ぜない。

## Airへの起票トリガー案

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Airへ：
Cycle 13候補として、旅行雑費の画面表示合算漏れと legacy `/export` プレビューの複数Expense過小集計を起票してください。
docs/proposals/CC_activity_list_travel_misc_total_bug.md と docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md を読み、危険度高（金額・既存導線・src/main/java変更）としてAir計画を作ってください。

重要:
- legacy `/export` は現役導線です。
- `expenses.project_participant_id` にUNIQUE制約はなく、`ExportController.preview()` の `exList.get(0)` はバグ確定です。
- Excel出力自体は現状正しいため、原則として画面表示・legacy previewの修正に絞ってください。
- 必要ならエアクルーを使って「画面表示」「DB/複数Expense」「回帰検証」を分けて確認してください。

結果は docs/handoff/P1_Air_Blueprint/cycle_13_travel_misc_preview_totals.md に保存してください。
```
