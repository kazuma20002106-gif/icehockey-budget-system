# [C8.3: CC(P3)] Cycle 8.3 実装報告書

作成日: 2026-06-25
作成者: CC (Claude Code)
バージョン: v2.2.0
参照P2: `docs/handoff/P2_Dex_to_CC/cycle_8_3.md`

---

## 1. 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|----------|----------|------|
| `src/main/java/.../mapper/ProjectMapper.java` | 修正 | `findFiltered` に `targetCategory`・`projectName` パラメータ追加 |
| `src/main/resources/mapper/ProjectMapper.xml` | 修正 | `target_category =` / `name LIKE CONCAT(...)` のWHERE条件追加 |
| `src/main/java/.../controller/ActivityController.java` | 修正 | `list`・`exportYear` に `targetCategory`・`projectName` 追加、model属性追加 |
| `src/main/java/.../service/ExcelExportService.java` | 修正 | 補助金区分ラベルhelper・種別ソートhelper・シート名sanitize helper・circledNumber追加、`buildCombinedWorkbook` ソート/グループ化/シート名再設計、`exportForm24` 単独出力を左側固定化、`populate22Summary` 旅行雑費集計追加 |
| `src/main/resources/templates/activity/list.html` | 修正 | 絞り込みに種別・事業名追加（年度→月→補助金区分→種別→事業名順）、Excel出力リンクにパラメータ引き継ぎ |
| `src/main/resources/templates/activity/form.html` | 修正 | 宿泊設定input-group化（単価×泊数）・accommodationCost readonly化・旅行雑費フル計算式UI・tfoot2行分割 |
| `src/main/resources/application.properties` | バージョン更新 | v2.1.14 → v2.2.0 |

---

## 2. `Project#getBudgetType()` を使わない補助金区分名取得

Air草案の `project.getBudgetType().getName()` はコンパイルエラーになるため、P2指示に従い `ExcelExportService` 内に `budgetTypeLabel(Integer budgetTypeId)` private helperを追加しました。

```java
private String budgetTypeLabel(Integer budgetTypeId) {
    if (budgetTypeId == null) return "不明";
    switch (budgetTypeId) {
        case 1: return "選手強化費";
        case 2: return "トップチーム活用事業";
        case 3: return "ふるさと選手活動支援";
        default: return "区分" + budgetTypeId;
    }
}
```

`ActivityController#budgetLabel` と同じ対応（case 1/2/3）で実装しています。

---

## 3. 様式2-2-1 旅行雑費の出力セル・行番号根拠

### 実装した計算式

```java
totalTravelMisc += nz(sum.getTravelMiscCost()) * parts.size() * nz(sum.getTravelMiscDays());
```

### 出力先セル: **row=19 (0-indexed) = R20 (1-indexed), col=9 (J列)**

**根拠（推定）**: 既存 `populate22Summary` のセル割当パターン：

| row(0-indexed) | Excel行 | 科目 |
|---|---|---|
| 15 | R16 | 交通費 |
| 17 | R18 | 宿泊費 |
| **19** | **R20** | **旅行雑費（今回追加）** |
| 21 | R22 | 駐車料金 |
| 23 | R24 | 借用料 |
| 25 | R26 | 報償費 |
| 27 | R28 | 需用費 |
| 29 | R30 | 役務費 |

交通費→宿泊費→?→駐車料金と2行おきに並ぶパターンから、R20が旅行雑費行と推定しました。

**⚠️ 要目視確認**: `書類.xlsx` の様式2-2-1 で旅行雑費が実際にR20（Excel上の行番号20）にあることを Kazumax または Dex が確認してください。もし違う行であれば `populate22Summary` の `writeSafeNumeric(sheet22, 19, 9, totalTravelMisc)` の `19` を正しい行番号(0-indexed)に修正する必要があります。

---

## 4. コンパイル結果

```
.\mvnw.cmd -q -DskipTests compile
Exit: 0
```

`target/classes/application.properties` の `app.version=v2.2.0` も確認済みです。

---

## 5. 実装詳細

### 5.1 Excelシート名・グループ化（buildCombinedWorkbook）

ソート順:
1. `budgetTypeId` 昇順
2. 種別順（成年男子→成年女子→少年男子→少年女子→その他）
3. 活動日昇順
4. ID昇順

グループキー: `budgetTypeId + "_" + targetCategory`

シート名形式: `2-4_[補助金区分]_[種別]_[①②③]`（例: `2-4_選手強化費_成年男子_①`）

Excelシート名禁止文字（`/\?*[]:`)は `_` に置換。31文字制限は `uniqueName` の28文字切り詰めで対応（最長ケースで約22文字）。

出力順: 2-4全て → 2-5全て → 2-6全てをworbook cloneの順序で制御。

### 5.2 様式2-4 単独出力

旧: 奇数番=左、偶数番=右（相方自動連行）
新: **常に左=対象、右=空欄**

### 5.3 宿泊費UI

- 基本情報セクション: `[単価]円 × [泊数]泊` の input-group で統合
- ※単価は1泊分・最大3泊 を表示
- `accommodationRate` を 個人別支出 ヘッダーから 基本情報 へ移動
- 様式2-6の宿泊費セルを `readonly` に変更（`disabled` は不使用）

### 5.4 旅行雑費UI

```
[単価]円 × [日数]日 × [人数]人 = [合計]円
```

- 人数は名簿の有効行数に自動連動（`updateCounts()` → `updateTravelMiscTotal()`)
- `name` 属性は `summary.travelMiscCost` / `summary.travelMiscDays` を維持
- 合計表示はJS計算のみ（保存項目なし）

### 5.5 tfoot 総合計レイアウト

2行構成に変更:
- 1行目: 交通費合計 / 宿泊費合計（既存ID維持）
- 2行目: 総合計 `fs-5` で大きく表示（既存 `grandTotal` ID維持）

---

## 6. 未確認事項

- **旅行雑費セル（R20）の目視確認が必要**（上記3参照）
- Excel出力の動作確認（シート名・ソート順・2-4ペアリング）は、アプリ起動後に実施が必要

---

## 7. Stop Conditions 遵守確認

- `git reset --hard` / `git restore .` / `git clean` の自動実行: **なし**
- 実 Claude 自動起動: **なし**
- DBスキーマ変更: **なし**
- 無関係なリファクタ: **なし**
