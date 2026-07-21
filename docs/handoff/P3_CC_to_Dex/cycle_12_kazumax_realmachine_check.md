[C12: CC(P3) => Kazumax Realmachine Check Result]

# Cycle 12 Kazumax最終確認 実施記録

`docs/handoff/P4_Dex_Review/cycle_12_final_hardening_take2.md` の「Kazumax最終確認チェックリスト」を、CCが代行してブラウザで実機確認した記録。

対象: HEAD `c1db501`（Take2）。`.\mvnw.cmd spring-boot:run` でローカル起動（ポート8080、MySQL既存データ使用）。

## チェックリスト結果

1. **年度末出力画面から、年度・条件を選んでプレビューが表示されること** → OK。2026年度・全区分で `/export/year/setup` → `/export/year/preview` へ遷移し、プレビュー表示された。
2. **プレビューのタブで様式2-1 / 2-2 / 2-2-1 / 2-3 / 2-4 / 2-5 / 2-6相当の内容を確認できること** → OK（2-1/2-2/2-2-1×3/2-3のみタブとして存在。2-4/2-5/2-6は本プレビューUIの対象外で、既存の個別Excel出力経路が別途担う設計。これはDexの `cycle_12_overall_final_review.md` のOK確認記載と一致しており、想定通り）。
3. **提出日・団体名・代表者名を入力してExcel出力できること** → OK。「この内容でExcelをダウンロード」を実行し、`POST /export/year/download` が完了。サーバーログにApache POIの警告（`Cloning sheets with page setup is not yet supported.`）はあるが、これは既知の軽微な仕様上の警告でエラーではない。例外・500エラーなし。
4. **出力Excelの金額合算が、画面で入力した事業・予算内示・活動実績と大きくズレていないこと** → **Excel自体は正しい**。プレビュー内で「様式2-2の合計と、選手強化・トップ・ふるさと（2-2-1）の合計は一致しています。」と表示され、内訳（交通費/宿泊費/旅行雑費/駐車料金/借用料/報償費/需用費/役務費）の突合も一致した。

   ただし確認の過程で、**Cycle 12のスコープ外の既存バグ**を発見した。詳細は下記「新規発見（Cycle 12スコープ外）」を参照。

5. **予算管理画面で、不正な年度/カテゴリの保存が通常操作では起きないこと** → OK。`/budget-allocations?year=2026` を開くと、その年度に実績がある `(補助金区分, 対象区分)` の組み合わせのみが行として表示される（今回は「選手強化費×成年男子」「選手強化費×成年女子」の2行のみ）。UIから任意のカテゴリを選ぶ手段はなく、Take1で追加したサーバー側検証（`BudgetAllocationController.save()`）と合わせて通常操作での不正保存は発生しない。
6. **旧互換ルート `/activity/export/annual` を使う必要がある場合、0件時に出力を止めること** → OK。`/activity/export/annual?year=2099`（データなし年度）へアクセスすると、Excelを生成せず `/activity?year=2099&error=no_data_for_annual_export` へリダイレクトされ、「選択した年度・条件に該当する事業がないため、年度末決算ファイルを出力できませんでした。」と表示された。

## 新規発見（Cycle 12スコープ外）: 活動一覧の支出合計が旅行雑費を含まず過小集計される

チェックリスト4番の確認中に、活動一覧画面（`/activity`）の「支出合計」列・合計欄と、年度末決算ファイルの様式2-2「支出合計」に差額が出ていることに気づいた。

- 活動一覧画面（2026年度・全8件）の支出合計: **321,179円**
- 年度末決算プレビュー 様式2-2「選手強化費」支出合計: **481,179円**
- 差額: **160,000円** = プレビュー内の「旅行雑費」の額と完全一致

### 原因（コード確認済み）

`src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java` の `list(...)`（59〜65行付近）で、1事業あたりの `expenseTotal` を次のように計算している。

```java
long expenseTotal = 0;
for (ProjectParticipant part : parts) {
    List<Expense> exList = expenseMapper.findByProjectParticipantId(part.getId());
    for (Expense e : exList) {
        expenseTotal += nz(e.getTransportCost()) + nz(e.getAccommodationCost()) + nz(e.getMiscellaneousCost());
    }
}
ProjectSummaryExpense sum = summaryMapper.findByProjectId(p.getId());
if (sum != null) {
    expenseTotal += nz(sum.getRentalCost()) + nz(sum.getSuppliesCost()) + nz(sum.getParkingCost())
            + nz(sum.getCompensationCost()) + nz(sum.getServiceCost());
}
```

`ProjectSummaryExpense`（`src/main/java/.../model/ProjectSummaryExpense.java`）には `travelMiscCost`（旅行雑費 単価）と `travelMiscDays`（旅行雑費 日数）というフィールドがあるが、上記の合算式には含まれていない。

一方、`ExcelExportService.java`（248〜250行付近）では、様式2-2/2-2-1の集計時に次の計算式で旅行雑費を正しく含めている。

```java
int travelMiscCostVal = (summary != null) ? nz(summary.getTravelMiscCost()) : 0;
int travelMiscDaysVal = (summary != null) ? nz(summary.getTravelMiscDays()) : 0;
int travelMiscTotal = travelMiscCostVal * (coachCount + playerCount) * travelMiscDaysVal;
```

つまり、**Excel出力側（様式2-2/2-2-1）の合算は正しい**。バグがあるのは**活動一覧画面（`/activity`）の表示側**で、旅行雑費が入力された事業については、画面の「支出合計」列・ページ下部の合計が実際より少なく表示される。

### 影響

- 金額計算そのもの（DB保存・Excel出力）は壊れていない。実害は「画面表示の過小集計」に限られる。
- ただし、担当者が活動一覧の合計とExcel出力の合計を突き合わせて検算する運用の場合、両者が一致せず「Excelの方が間違っているのでは」と誤解される可能性がある。Kazumaxの「合算が正常に行われているかが第一優先」という絶対方針に照らすと、画面表示側の過小集計も看過できない事項と判断し、ここで報告する。
- このバグはCycle 12で変更したファイルには含まれておらず、旅行雑費フィールド（`travelMiscCost`/`travelMiscDays`）が導入された時点（Cycle 12より前）から存在していたとみられる。Cycle 12の実装・検証範囲には含まれていない。

### 今回とった対応

`src/main/java/` は危険エリア（`docs/PROJECT_RULES.md` 危険ファイル・危険エリア一覧）であり、金額計算ロジックの変更はAir計画→Dex事前レビュー→CC実装→Dex事後レビューの完全プロセスが必要なため、**今回はコードを変更せず、発見事実の報告のみ**とした。

修正案は `docs/proposals/CC_activity_list_travel_misc_total_bug.md` に記載した。次サイクルの起票候補としてAirの判断を仰ぐことを推奨する。

## 結論

Cycle 12最終硬化Take2自体（handoff自己完結性・ActivityControllerのCycle 12A互換ルート整理・予算保存検証）の6項目チェックリストは、上記の通りすべてOK。

ただし、確認中に見つかった「活動一覧の支出合計が旅行雑費を含まず過小集計される」問題は、Cycle 12の変更範囲外の既存バグであり、Cycle 12自体の完了可否とは別に、Kazumax判断で次サイクルの対応要否を決めていただきたい。
