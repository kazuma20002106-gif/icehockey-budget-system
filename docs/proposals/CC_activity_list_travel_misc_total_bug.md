[CC ⇒ Air/Kazumax]

# バグ報告＋α提案：活動一覧の支出合計が旅行雑費を含まず過小集計される

## 経緯

Cycle 12最終硬化Take2のKazumax実機確認代行中（`docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md`）、活動一覧画面の支出合計と年度末決算Excel（様式2-2）の支出合計が一致しないことに気づいた。

## 症状（2箇所を確認。いずれも画面プレビューの表示のみで、実際のExcelは正しい）

### 箇所A: `/activity`（活動一覧）

- 「支出合計」列・ページ下部合計は、旅行雑費（`ProjectSummaryExpense.travelMiscCost` × 人数 × `travelMiscDays`）を含まない。
- Excel出力（`ExcelExportService`、様式2-2/2-2-1）は旅行雑費を正しく含めて集計している。
- 結果として、旅行雑費が入力された事業がある年度は、活動一覧の合計がExcelの合計より少なく表示される（今回の検証データでは160,000円のズレ）。

### 箇所B: `/export`（既存「🖨️ 提出データ出力・集計」画面）の `exportType=2-2` プレビュー

- `ExportController.preview()` の`grandTotal`計算も、同じく`travelMiscCost`/`travelMiscDays`を含まない。
- ダウンロード自体（`excelExportService.exportForm22Summary(...)` → `populate22Summary(...)`）は`totalTravelMisc`を正しく積算しており、Excelファイルの数値は正しい。
- この画面はCycle 12以前からある既存機能で、ナビゲーションから今も到達可能。

## 原因ファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java` の `list(...)` メソッド（59〜65行付近。`expenseTotal` の集計式に `travelMiscCost`/`travelMiscDays` が含まれていない）
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java` の `preview(...)` メソッド（58〜90行付近。`exportType=2-2`分岐の`grandTotal`集計式に同じく含まれていない）

## 参考: 正しい計算式（ExcelExportService側、単一事業内の場合）

```java
// ExcelExportService.java 543〜548行付近 / 1116〜1121行付近 で使われている式
pTravelMisc = (long) nz(sum.getTravelMiscCost()) * parts.size() * nz(sum.getTravelMiscDays());
```

（`coachCount + playerCount`を使っている248〜250行付近は、複数事業を区分別に集計する別文脈の式。単一事業の合計を出す箇所A・箇所Bの修正では、上記の`parts.size()`ベースの式に揃えるのが妥当と考える。）

## 追加の未確認事項（バグと断定はしていないが、Dexに実態確認を依頼したい）

`ExportController.preview()`の`exportType != "2-2"`分岐（104〜112行付近）は、参加者ごとの交通費・宿泊費を`exList.get(0)`（先頭の1件）だけで計算しており、`ActivityController.list()`のように`exList`を全件ループして合算していない。参加者と`Expense`が1:1関係であれば実害はないが、1人が複数の`Expense`レコードを持ちうる設計であれば、ここも別の過小集計要因になりうる。DB設計・既存データの実態をDexに確認してほしい。

## 提案する対応方針（実装はCCが担当、金額計算のため完全プロセス必須）

1. Airが本件を次サイクルの課題として起票するか判断する。
2. 危険タスク（金額計算・`src/main/java/`変更）に該当するため、Air計画 → Dex事前レビュー → CC実装 → Dex事後レビューの完全プロセスを適用する。
3. 修正方針の候補: `ActivityController.list(...)` と `ExportController.preview(...)`（`exportType=2-2`分岐）の両方の合計計算に、`ExcelExportService`の単一事業計算と同じ `travelMiscCost × parts.size() × travelMiscDays` を追加する。
4. `ExportController.preview()`の`exList.get(0)`問題（上記「追加の未確認事項」）も、実害ありと判断された場合は同じタスクでまとめて修正する。
5. 修正後、活動一覧・既存2-2プレビューの両方で、画面表示の合計とExcel出力の合計が一致することを回帰確認する。

## 影響範囲

- DB保存・Excel出力自体は正しいため、既に確定済みの決算書類には影響しない。
- 影響は画面表示（`/activity`の支出合計列・合計欄、`/export`の2-2プレビューの合計欄）のみ。
