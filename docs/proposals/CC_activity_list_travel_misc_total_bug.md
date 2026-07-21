[CC ⇒ Air/Kazumax]

# バグ報告＋α提案：活動一覧の支出合計が旅行雑費を含まず過小集計される

## 経緯

Cycle 12最終硬化Take2のKazumax実機確認代行中（`docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md`）、活動一覧画面の支出合計と年度末決算Excel（様式2-2）の支出合計が一致しないことに気づいた。

## 症状

- `/activity`（活動一覧）の「支出合計」列・ページ下部合計は、旅行雑費（`ProjectSummaryExpense.travelMiscCost` × 人数 × `travelMiscDays`）を含まない。
- Excel出力（`ExcelExportService`、様式2-2/2-2-1）は旅行雑費を正しく含めて集計している。
- 結果として、旅行雑費が入力された事業がある年度は、活動一覧の合計がExcelの合計より少なく表示される（今回の検証データでは160,000円のズレ）。

## 原因ファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java` の `list(...)` メソッド（`expenseTotal` の集計式に `travelMiscCost`/`travelMiscDays` が含まれていない）

## 参考: 正しい計算式（ExcelExportService側）

```java
int travelMiscCostVal = (summary != null) ? nz(summary.getTravelMiscCost()) : 0;
int travelMiscDaysVal = (summary != null) ? nz(summary.getTravelMiscDays()) : 0;
int travelMiscTotal = travelMiscCostVal * (coachCount + playerCount) * travelMiscDaysVal;
```

## 提案する対応方針（実装はCCが担当、金額計算のため完全プロセス必須）

1. Airが本件を次サイクルの課題として起票するか判断する。
2. 危険タスク（金額計算・`src/main/java/`変更）に該当するため、Air計画 → Dex事前レビュー → CC実装 → Dex事後レビューの完全プロセスを適用する。
3. 修正方針の候補: `ActivityController.list(...)` の `expenseTotal` 計算に、`ExcelExportService` と同じ `travelMiscCost × (人数) × travelMiscDays` を追加する。「人数」の定義（コーチ含むか等）を `ExcelExportService` の `coachCount + playerCount` と揃える必要がある。
4. 修正後、活動一覧の合計とExcel出力の合計が一致することを回帰確認する。

## 影響範囲

- DB保存・Excel出力自体は正しいため、既に確定済みの決算書類には影響しない。
- 影響は画面表示（`/activity`の支出合計列・合計欄）のみ。
