[C13: Dex(P4) => CC(P3) Take2]

# Cycle 13 旅行雑費の画面表示合算漏れ・legacy preview複数Expense集計方式統一 P4レビュー

## 判定

**NG / Take2差し戻し**

金額本体の修正はおおむね指示通りです。

- `/activity` の旅行雑費加算は `travelMiscCost * parts.size() * travelMiscDays` になっている
- legacy `/export` の2-2 previewに `totalTravelMisc` が入り、`grandTotal` に含まれている
- 個人雑費 `miscellaneousCost` は2-2総合計に混ざっていない
- `Expense.aggregate(...)` はpreview側と `ExcelExportService.getLoadedParticipants(...)` の両方で共有されている
- `v2.4.5` の `app.version` は `src/main/resources` と `target/classes` で一致
- Dex環境で `.\mvnw.cmd -q -DskipTests compile` 成功

ただし、P2指示書とP3報告に対して、legacy 2-6 previewの非数値項目表示に小さい不一致が残っています。

---

## サブレビュー利用判断

**使用。**

理由:
- 金額・複数Expense・Excel整合・legacy previewの境界に触るため。
- デクスクルーA（金額・複数Expense・Excel整合）を起動し、Dex本体レビューに統合した。

統合した観点:
- `Expense.aggregate(List<Expense>)` のnull/空リスト/数値合算/非数値踏襲
- `ActivityController.list(...)` の旅行雑費式
- `ExportController.preview(...)` の2-2/2-2以外の集計
- `ExcelExportService.getLoadedParticipants(...)` とpreview側の集計方式一致
- 個人雑費と旅行雑費の混同有無

---

## Finding

### P3: legacy 2-6 previewの期日・受領日がExpense集約結果ではなく事業日を表示している

対象:
- `src/main/resources/templates/export/preview.html`

該当:
- `preview.html:203`
- `preview.html:212`

現状:

```html
<td th:text="${#temporals.format(pd.project.eventDate, 'M/d')}"></td>
...
<td th:text="${#temporals.format(pd.project.eventDate, 'M/d')}"></td>
```

一方、`Expense.aggregate(...)` は以下を先頭1件から踏襲しています。

- `expenseDate`
- `transportMethod`
- `transportRoute`
- `transportDistanceKm`
- `receiptDate`

Excel側の `ExcelExportService.populate26(...)` も、2-6出力では `Expense.expenseDate` / `Expense.receiptDate` を優先し、なければ `project.eventDate` に戻す実装です。

そのため、1参加者に複数Expenseがあり、先頭Expenseの `expenseDate` または `receiptDate` が事業日と違う場合、**2-6 previewとExcelで非数値の日付表示がズレます。**

金額ズレではないため重大度はP3ですが、P2指示書では「2-6プレビュー表示用の `part.expense` は、複数Expenseがある場合も数値だけは合算された表示用Expenseを使う。日付・交通手段・区間などの非数値情報は先頭1件を踏襲してよい」としており、P3報告でも「2-6の期日・受領日は先頭1件を表示」と書かれています。実装と報告内容を一致させるためTake2で直してください。

---

## Take2修正指示

### 1. preview.htmlの2-6期日・受領日をExpense優先にする

対象:
- `src/main/resources/templates/export/preview.html`

修正方針:
- 期日は `part.expense.expenseDate` があればそれを表示し、なければ `pd.project.eventDate` にフォールバックする
- 受領日は `part.expense.receiptDate` があればそれを表示し、なければ `pd.project.eventDate` にフォールバックする
- 交通手段・区間・距離・金額の現行表示は壊さない
- 旅行雑費を2-6の「雑費」列へ混ぜない

実装例:

```html
<td th:text="${part.expense?.expenseDate != null ? #temporals.format(part.expense.expenseDate, 'M/d') : #temporals.format(pd.project.eventDate, 'M/d')}"></td>
...
<td th:text="${part.expense?.receiptDate != null ? #temporals.format(part.expense.receiptDate, 'M/d') : #temporals.format(pd.project.eventDate, 'M/d')}"></td>
```

### 2. P3 Take2報告に明記する

報告先:
- `docs/handoff/P3_CC_to_Dex/cycle_13_travel_misc_preview_totals_take2.md`

必ず書くこと:
- 修正ファイル
- 2-6 previewの期日/受領日がExpense優先、なければ事業日フォールバックになったこと
- `.\mvnw.cmd -q -DskipTests compile` の結果
- `app.version` は、コード/テンプレート修正なので `v2.4.6` へ更新し、`src/main/resources` と `target/classes` の一致を確認すること
- `git status --short` の確認

---

## Dex確認済み

- `git show --stat 9ce6796` でCC報告の変更ファイルと一致
- `git diff --check 9ce6796^ 9ce6796` 問題なし
- `.\mvnw.cmd clean compile` はOneDrive配下の `target` ロックでclean削除に失敗
- `target` がworkspace内であることを確認して手動削除後、`.\mvnw.cmd -q -DskipTests compile` 成功
- `src/main/resources/application.properties` と `target/classes/application.properties` は `app.version=v2.4.5` で一致
- DBスキーマ、mapper SQL、Excelテンプレート本体は変更なし

## 補足

`Expense.aggregate(...)` 内部の数値合算は `int` です。既存モデルの金額フィールドが `Integer` のため今回はブロッカーにはしませんが、将来の全体監査では「金額モデルをlongへ寄せるか」は別途確認候補です。
