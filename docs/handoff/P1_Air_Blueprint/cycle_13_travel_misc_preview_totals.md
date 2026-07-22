[Air(P1) ⇒ Dex(P2) / CC(P3)]

# Cycle 13 Blueprint: 旅行雑費の画面表示合算漏れ・legacy preview複数Expense過小集計修正

エアクルー（A: Java解析、B: UI解析）を動員し、CCからのバグ報告とDexからの起票依頼に基づいて修正スコープを確定させました。

## 1. 修正の目的
既存の金額計算ロジックにおける以下の2つの不具合を解消し、画面上の表示金額（プレビュー、活動一覧）と、実際に出力されるExcel決算書の金額を完全に一致させます。
1. **旅行雑費（事業サマリ側）の合算漏れ**: `ActivityController` の活動一覧、および `ExportController` のlegacyプレビューにおいて、旅行雑費が総合計に含まれていない問題の解消。
2. **複数Expenseデータの欠落**: `ExportController.preview()` において、1人の参加者に紐づくExpenseが複数存在する場合に `exList.get(0)` のみを取得し、2件目以降の旅費が過小集計されるバグの解消。

---

## 2. 修正対象ファイルと実装方針

### 2-1. `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- **対象メソッド**: `list(...)`
- **修正内容**:
  - `expenseTotal` の計算ループにおいて、`ProjectSummaryExpense` の加算処理に `(sum.getTravelMiscCost() * 参加人数 * sum.getTravelMiscDays())` を追加する。
  - ※注意: 個人の `Expense` ループで `exList.get(0)` に依存せず、全件ループして `transportCost`, `accommodationCost`, `miscellaneousCost` を合算する方式に変更する。

### 2-2. `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- **対象メソッド**: `preview(...)`
- **修正内容 (exportType=2-2)**:
  - `grandTotal` に加算するための変数 `totalTravelMisc` を新設。
  - プロジェクトごとのループ内で、`ProjectSummaryExpense` の旅行雑費（単価×人数×日数）を加算。
  - 参加者ごとの `Expense` ループにおいて、**`exList.get(0)` を廃止し、`exList` を全件ループ**して交通費・宿泊費・個人の雑費をすべて合算する。
  - `model.addAttribute("totalTravelMisc", totalTravelMisc)` を追加。
- **修正内容 (exportType != 2-2)**:
  - 各プロジェクトの `pd` (Map) に入れる `miscSum` を新設。
  - こちらも `exList.get(0)` を全件ループ化し、個人の雑費と、事業の旅行雑費を `miscSum` に積算する。

### 2-3. `src/main/resources/templates/export/preview.html`
- **様式2-2 プレビュー表**:
  - 「交通費」「宿泊費」などの並びに、「旅行雑費」の行を新たに追加し、`${totalTravelMisc}` を表示する。
- **様式2-4 プレビュー表**:
  - 既存の「交通費合計」「宿泊費合計」の並びに、「旅行雑費合計」を追加し、`${pd.miscSum}` を表示する。

---

## 3. スコープ外（原則触らない範囲）
- Excel出力の主ロジック（`ExcelExportService`）は現状正しいため変更しない。
- データベースの `schema.sql` への UNIQUE制約追加などは、既存データを破壊する恐れがあるため今回は行わない。
- 既存の保存処理（`ActivityController.save` 等）での物理削除問題については、今回は「画面表示の修正」に絞るためスコープ外とする。

---

## 4. 検証条件（Dex P2/P4向け）
1. `mvn -q -DskipTests compile` が通ること。
2. `/activity`（活動一覧画面）において、旅行雑費が入力されている事業の「支出合計」が、Excel出力時の金額と完全に一致していること。
3. legacy `/export` のプレビューにおいて、「旅行雑費」行が表示され、総合計がExcelと一致すること。
4. DBを直接操作して1人の参加者に2つの `Expense` レコードを入れた場合、プレビューの交通費・宿泊費の合計が「2件分」で計算されること（`exList.get(0)` バグの解消確認）。
5. Cycle 12の「年度末一括出力」が壊れていないこと。
6. バージョン番号を `v2.4.5` などに更新すること。
