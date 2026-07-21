[C12: CC(P3) => Dex(P4) Informational Report]

# Cycle 12 実機確認結果 + 新規発見バグ Dex向け報告

Kazumaxより、Dexにも同じ実機確認を依頼しているとのことなので、CCが実施した内容と発見事項をここに一本化して報告する。Dexの独立確認と突き合わせて判断材料にしてほしい。

## 1. Kazumax最終確認チェックリスト実施結果（CC代行・全項目OK）

対象HEAD: `4649a89`（`docs/handoff/P4_Dex_Review/cycle_12_final_hardening_take2.md` のチェックリストに対応）。ローカルで `.\mvnw.cmd spring-boot:run` 起動、既存MySQLデータを使用。

1. 年度末出力画面(`/export/year/setup` → `/export/year/preview`)でプレビュー表示 → OK
2. 表紙(2-1)/まとめ(2-2)/選手強化・トップ・ふるさと(2-2-1)/変更報告(2-3)タブの内容確認 → OK。「様式2-2の合計と、選手強化・トップ・ふるさと（2-2-1）の合計は一致しています。」の整合メッセージも表示された
3. 提出情報入力→Excelダウンロード → OK（`POST /export/year/download` 成功。サーバーログにApache POIの警告`Cloning sheets with page setup is not yet supported.`のみ、例外なし）
4. 出力Excelの金額合算確認 → **Excel自体は正しい**。ただし確認中に下記2.のバグを発見
5. 予算管理画面の不正カテゴリ拒否 → OK。UIはその年度に実績がある組み合わせのみ表示。Take1のサーバー側検証と合わせ、通常操作での不正保存は発生しない
6. 旧互換ルート`/activity/export/annual`の0件時停止 → OK。データなし年度でリダイレクト＋エラーメッセージを確認

詳細ログは `docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md` を参照。

## 2. 新規発見バグ（Cycle 12スコープ外・2箇所を確認）

Kazumax向け報告時点では1箇所（`ActivityController.java`）のみだったが、報告後にコードベースを横断確認し、**同一パターンの2箇所目**を追加で発見した。

### 共通の根本原因

`ProjectSummaryExpense`（`src/main/java/.../model/ProjectSummaryExpense.java`）には `travelMiscCost`（旅行雑費 単価）と `travelMiscDays`（旅行雑費 日数）というフィールドがある。旅行雑費の実額は `travelMiscCost × 参加人数 × travelMiscDays` で計算する必要があるが、以下2箇所の「画面プレビュー用の合計計算」だけがこの項を含めていない。**Excel書き込み側（POI操作）はどちらも正しく `travelMiscCost` を含めて計算している**ため、実際にダウンロードされるExcelファイルの数値自体は壊れていない。

### 箇所A: `ActivityController.list()`（活動一覧画面 `/activity`）

```java
// src/main/java/.../controller/ActivityController.java 59〜65行付近
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
    // travelMiscCost / travelMiscDays が含まれていない
}
```

実測: 2026年度・8事業で、活動一覧の支出合計表示 **321,179円** に対し、年度末決算プレビュー様式2-2の選手強化費支出合計 **481,179円**。差額160,000円は旅行雑費と完全一致。

### 箇所B: `ExportController.preview()`（既存「🖨️ 提出データ出力・集計」画面 `/export` → `exportType=2-2` プレビュー）

```java
// src/main/java/.../controller/ExportController.java 58〜90行付近
if ("2-2".equals(exportType)) {
    int totalRental = 0, totalSupplies = 0, totalParking = 0, totalCompensation = 0, totalService = 0;
    int totalTransport = 0, totalAccommodation = 0;
    for (int id : projectIds) {
        ProjectSummaryExpense sum = summaryMapper.findByProjectId(id);
        if (sum != null) {
            totalRental += sum.getRentalCost();
            totalSupplies += sum.getSuppliesCost();
            totalParking += sum.getParkingCost();
            totalCompensation += sum.getCompensationCost();
            totalService += sum.getServiceCost();
            // ここも travelMiscCost / travelMiscDays が含まれていない
        }
        ...
    }
    ...
    model.addAttribute("grandTotal", totalRental + totalSupplies + totalParking + totalCompensation + totalService + totalTransport + totalAccommodation);
}
```

この画面はナビゲーションの「🖨️ 提出データ出力・集計」（`/export`）から今も到達可能な、Cycle 12より前からある既存機能。ダウンロード自体は `excelExportService.exportForm22Summary(...)` を呼んでおり、その実装（`populate22Summary`、523〜601行付近）は `catTravelMisc` / `totalTravelMisc` を正しく積算してExcelに書き込んでいる（601行目 `writeSafeNumeric(sheet22, 19, 9, totalTravelMisc)`）。つまりここも**プレビュー画面の表示だけが過小集計**で、実際のExcelは正しい。

### 網羅性の確認方法

`src/main/java/` 全体を対象に、`getRentalCost()` `getSuppliesCost()` `getParkingCost()` `getCompensationCost()` `getServiceCost()` `getTravelMiscCost()` `getTravelMiscDays()` の呼び出し箇所を横断grepし、上記2箇所以外に「旅行雑費抜きの5費目合計」パターンが存在しないことを確認した。`ExcelExportService.java`側の全箇所（218〜222行、248〜250行、543〜548行、1116〜1121行）はいずれも `travelMiscCost`/`travelMiscDays` を含めて計算している。

ただし、これはCCの1回のgrep結果であり、**Dex側でも同じ観点（`ProjectSummaryExpense`の各費目フィールドを使っている箇所の網羅性）を独立に再確認してほしい**（依頼事項1）。

### 追加の未確認事項（バグと断定はしていない）

`ExportController.preview()` の`else`分岐（`exportType != "2-2"` のプレビュー、104〜112行付近）では、参加者ごとの交通費・宿泊費合計を次のように計算している。

```java
List<Expense> exList = expenseMapper.findByProjectParticipantId(part.getId());
if (!exList.isEmpty()) {
    Expense ex = exList.get(0);  // 先頭の1件だけを使っている
    transportSum += ex.getTransportCost();
    accommodationSum += ex.getAccommodationCost();
}
```

一方、`ActivityController.list()`は同じ`exList`を**全件ループして合算**している（`for (Expense e : exList) { ... }`）。もし1人の参加者が複数の`Expense`レコードを持ちうる設計なら、この`exList.get(0)`は2件目以降を無視する過小集計になる。参加者と`Expense`の関係が実質1:1しかありえない設計であれば実害はない。**この関係性の実態と、実害の有無をDexに判断してほしい**（依頼事項2）。

## 3. 提案する修正方針（詳細は `docs/proposals/CC_activity_list_travel_misc_total_bug.md`）

1. `ActivityController.list()` と `ExportController.preview()`（`exportType=2-2`分岐）の両方に、`ExcelExportService`と同じ計算式 `travelMiscCost × 参加人数 × travelMiscDays` を追加する。
2. 「参加人数」は`ExcelExportService`の単一事業内での計算（543〜548行、1116〜1121行）が`parts.size()`／`participants.size()`を使っているのと揃える。
3. 金額計算ロジックの変更のため、`docs/PROJECT_RULES.md`の危険タスクプロセス（Air計画→Dex事前レビュー→CC実装→Dex事後レビュー）を適用する。

## 4. CCからDexへの依頼事項（まとめ）

1. 「箇所A・箇所Bの根本原因＝旅行雑費の合算漏れ」という判定と、grepによる網羅性確認結果を独立に再確認してほしい。
2. `ExportController.preview()`の`exList.get(0)`問題（上記「追加の未確認事項」）について、参加者-Expenseの関係が1:1前提で問題ないか、DB設計・既存データを見て判断してほしい。
3. legacy `/export`画面（様式2-2/2-4/2-5/2-6の個別選択出力）が、Cycle 12で追加された「年度末決算ファイル出力」と役割がどう違うか、今も現役の導線として維持すべきかを確認してほしい（Kazumaxへの確認が必要ならその旨まとめてほしい）。
4. 修正のタイミングについて、Cycle 12を先に完了として次サイクルで扱うか、Cycle 12の一部として先に片付けるべき緊急度かを判断してほしい。CCとしては、Excel出力自体は正しく実害が「画面表示のみ」に限定されているため、Cycle 12は完了扱いとし、本件は次サイクルの課題として起票する方が安全と考えるが、最終判断はDex/Kazumaxに委ねる。

## 参照ファイル

- `docs/handoff/P3_CC_to_Dex/cycle_12_kazumax_realmachine_check.md`（チェックリスト詳細ログ）
- `docs/proposals/CC_activity_list_travel_misc_total_bug.md`（修正提案。今回の箇所B・exList.get(0)所見を反映して更新予定）
- `docs/handoff/P4_Dex_Review/cycle_12_final_hardening_take2.md`（元のKazumax最終確認チェックリスト）
