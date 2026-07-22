[C13: Dex(P2) => CC(P3)]

# Cycle 13 旅行雑費の画面表示合算漏れ・legacy preview複数Expense過小集計 事前監査 / CC向け実装指示書

## 判定

**条件付きOK。CCはこの指示書を最優先として実装してください。**

Air(P1)の `docs/handoff/P1_Air_Blueprint/cycle_13_travel_misc_preview_totals.md` は大枠妥当です。
ただし、Dex事前監査で以下2点を補正します。

1. `pd.miscSum` に個人雑費と事業サマリ旅行雑費を混ぜる案は採用しない。
2. 複数Expenseバグを直すなら、`ExportController.preview()` だけでは不足。`ExcelExportService.getLoadedParticipants(...)` 側にも `exList.get(0)` があり、previewだけ直すと画面とExcelがズレる可能性がある。

このファイルとAir草案が矛盾する場合は、**このDex P2指示書を優先**してください。

---

## サブレビュー利用記録

サブレビュー利用判断: 使用。

理由:
- 金額計算、legacy画面、Excel出力、テンプレート表示、Cycle 12年度末導線の境界が同時に絡むため、サブレビュー推奨案件。
- デクスクルーA（金額・DB/複数Expense・Excel整合）とデクスクルーB（UI/テンプレート・回帰）を起動し、Dex本体で結果を統合した。

統合した観点:
- デクスクルーA: 金額・DB/複数Expense・Excel整合を確認。
- デクスクルーB: legacy `/export` プレビューUI、2-4表示、Cycle 12年度末プレビューとの境界を確認。
- 過去のデクスクルー金額網羅性確認: 旅行雑費漏れは `ActivityController` と `ExportController` の同系統2箇所。`exList.get(0)` はDB構造上バグ確定。
- Dex本体のUI観点: 2-4プレビューで個人雑費と事業サマリ旅行雑費を混ぜると誤読リスクがあるため、モデル属性名と表示ラベルを分ける。

Dex最終判断:
- Air草案は「実装可能」だが、UI属性名とExcelExportService境界を補強してCCへ渡す。

---

## CCが最初に読むファイル

- `docs/handoff/P1_Air_Blueprint/cycle_13_travel_misc_preview_totals.md`
- `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`
- `docs/proposals/CC_activity_list_travel_misc_total_bug.md`
- このファイル
- `docs/PROJECT_RULES.md`

---

## 今回やること

### 1. `/activity` 活動一覧の支出合計に旅行雑費を含める

対象:
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`

修正:
- `list(...)` の `expenseTotal` に、事業サマリ側の旅行雑費を加算する。
- 式は単一事業文脈のExcel計算と合わせる。

```java
travelMisc = nz(sum.getTravelMiscCost()) * parts.size() * nz(sum.getTravelMiscDays())
```

注意:
- 参加者ごとの `Expense` ループは現状すでに全件ループしているため、ここは壊さない。
- `long` で集計する。`int` 合計を増やさない。
- `sum` の各getterはnullの可能性を考え、既存の `nz(...)` を使う。

---

### 2. legacy `/export` の様式2-2プレビューに旅行雑費を含める

対象:
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/resources/templates/export/preview.html`

修正:
- `exportType == "2-2"` 分岐に `totalTravelMisc` を追加する。
- 各事業ごとに `ProjectSummaryExpense.travelMiscCost * participants.size() * travelMiscDays` を加算する。
- `grandTotal` に `totalTravelMisc` を含める。
- `model.addAttribute("totalTravelMisc", totalTravelMisc)` を追加する。
- `preview.html` の様式2-2表に「旅行雑費」行を追加する。

表示位置:
- 「宿泊費」の次、またはExcel様式2-2の費目順に近い位置に置く。
- `総合計` より前に置く。

注意:
- `totalRental` など既存summary費目もnull安全にする。
- 合計型は `long` 推奨。少なくとも新規加算で `int` オーバーフローリスクを増やさない。

---

### 3. 複数Expenseを先頭1件だけで集計しない

対象:
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`

背景:
- `schema.sql` の `expenses.project_participant_id` にはUNIQUE制約がない。
- `ExpenseMapper.findByProjectParticipantId(...)` は `List<Expense>` を返す。
- よって `exList.get(0)` のみを見る実装は、2件目以降の交通費・宿泊費・個人雑費を落とす。

必須修正:
- `ExportController.preview()` の `exportType == "2-2"` 分岐で、交通費・宿泊費を `exList` 全件から合算する。
- `ExportController.preview()` の `exportType != "2-2"` 分岐で、`transportSum` / `accommodationSum` を `exList` 全件から合算する。
- 2-6プレビュー表示用の `part.expense` は、複数Expenseがある場合も数値だけは合算された表示用Expenseを使う。日付・交通手段・区間などの非数値情報は先頭1件を踏襲してよいが、その挙動をP3報告に明記する。

Excel側:
- `ExcelExportService.getLoadedParticipants(...)` は現在 `exList.get(0)` を使っている。
- 複数Expenseの数値合算をCycle 13の修正対象に含める。
- 既存の2-4/2-6/2-2/年度末出力が `getLoadedParticipants(...)` を共有しているため、ここを直す場合は通常の1Expenseデータで出力値が変わらないことを必ず確認する。

推奨実装:
- `Expense` の表示用集約ヘルパーを作る。
- 数値項目は全件合算:
  - `transportCost`
  - `accommodationCost`
  - `miscellaneousCost`
- 非数値項目は先頭1件の値を踏襲:
  - `expenseDate`
  - `transportMethod`
  - `transportRoute`
  - `transportDistanceKm`
  - `receiptDate`
- `exList` が空なら `null` のままにする。

---

### 4. 2-4プレビューの旅行雑費表示は独立属性にする

対象:
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/resources/templates/export/preview.html`

Air草案の `pd.miscSum` はそのまま採用しない。

理由:
- `Expense.miscellaneousCost` は個人別の雑費。
- `ProjectSummaryExpense.travelMiscCost` は事業サマリ側の旅行雑費。
- 画面上で混ぜると、何の金額か分かりにくくなる。

修正:
- `pd.put("travelMiscTotal", travelMiscTotal)` のように独立した属性名にする。
- 2-4プレビュー表には「旅行雑費合計（事業サマリ）」など、個人雑費と混同しないラベルで表示する。
- `transportSum` / `accommodationSum` と同じ行、または次行に表示する。

注意:
- 2-6プレビューの「雑費」は個人別 `miscellaneousCost` のまま。
- 2-6の「雑費」列を旅行雑費に置き換えない。

---

## 今回やらないこと

- `schema.sql` にUNIQUE制約を追加しない。
- `ExpenseMapper` の返り値をList以外に変えない。
- 編集フォーム全体を複数Expense対応UIに作り替えない。
- `ActivityController.editForm(...)` の複数Expense編集問題は、別提案として扱う。
- 公式テンプレートExcelのセル座標や外部リンク処理を変更しない。
- Cycle 12で完成した `/export/year/setup`、`/export/year/preview`、`/export/year/download` の導線仕様を変えない。

---

## 検証条件

### 必須

1. `.\mvnw.cmd clean compile`
2. `src/main/resources/application.properties` の `app.version` を `v2.4.5` へ更新
3. compile後、`target/classes/application.properties` も `v2.4.5` であることを確認
4. `git status --short` で未追跡・無関係ファイル混入を確認

### 画面確認

1. `/activity` の支出合計に旅行雑費が含まれること。
2. `/activity` のページ下部「支出合計」も各行合計と一致すること。
3. `/export` から `exportType=2-2` のプレビューを開き、「旅行雑費」行が表示されること。
4. legacy 2-2プレビューの総合計が、同じ選択事業のExcelダウンロード結果と一致すること。
5. `exportType=2-4` または `all` のプレビューで、「旅行雑費合計（事業サマリ）」が個人雑費と混同しない形で表示されること。
6. `exportType=2-6` の雑費列が、旅行雑費に置き換わっていないこと。

### 複数Expense確認

可能であれば開発DBで、1人の参加者に複数Expenseを持つテストデータを用意し、以下を確認する。

1. legacy 2-2プレビューの交通費・宿泊費・総合計が全Expense分を含むこと。
2. legacy 2-2 Excelダウンロードも同じ金額になること。
3. 2-4プレビューの交通費合計・宿泊費合計が全Expense分を含むこと。
4. 2-4 Excelダウンロードも同じ金額になること。
5. 2-6プレビューとExcelの個人別数値が、合算表示方針と一致すること。

テストデータを直接DBに入れる場合:
- 本番・本物データで行わない。
- 実施したSQL、対象ID、戻し方をP3報告に記録する。
- 直接DB検証ができない場合は、その理由をP3報告に明記し、少なくとも静的確認と通常データでの画面/Excel一致確認を行う。

### Cycle 12回帰

1. `/export/year/setup` が開くこと。
2. `/export/year/preview` が開くこと。
3. `/export/year/download` がxlsxを返すこと。
4. 対象事業0件時のnoDataリダイレクトで、日本語を含む提出情報が保持されること。

---

## P3報告書

完了報告は以下へ保存してください。

`docs/handoff/P3_CC_to_Dex/cycle_13_travel_misc_preview_totals.md`

P3報告に必ず書くこと:
- 変更ファイル一覧
- 旅行雑費の計算式
- 複数Expenseをどのように合算したか
- 2-6プレビュー/Excelで非数値項目をどう扱ったか
- 検証結果
- `app.version` の更新確認
- commit/pushした場合はcommit hash

---

## CC向け短縮メモ

中学生向けに言うと、今回やることは「画面に出ている合計金額を、Excelと同じ正しい合計にそろえる作業」です。

旅行雑費は「個人の雑費」ではなく「事業全体にかかる旅行雑費」なので、名前を混ぜないでください。
複数Expenseは、先頭1件だけ見ず、金額だけ全部足してください。
