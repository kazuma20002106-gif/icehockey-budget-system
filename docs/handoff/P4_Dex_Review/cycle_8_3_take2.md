# Cycle 8.3 Take2 Dex DIFFレビュー（P4）

## レビュー結果

**OK**

Take1で差し戻した3件は、Take2で解消されています。

## Take1差し戻し3件の確認結果

### 1. 2-2-1旅行雑費セルの推定問題

**OK**

CCのP3で、`書類.xlsx` 実読により `R20C4 = "③ 旅行雑費"` と確認済み。
Dex側でも内蔵Python + openpyxlで対象テンプレートを読み、以下を確認しました。

```text
sheet index 3: 様式２－２－１　事業別決算書（選手強化費）
R20 C4 = '③ 旅行雑費'
R20 C10 = 114600
```

実装箇所:

```java
writeSafeNumeric(sheet22, 19, 9, totalTravelMisc);
```

0-indexed row=19 / col=9 は、Excel上の R20 / J列であり、P2の意図と一致します。

### 2. Excel内部タイトルの補助金区分判定

**OK**

`populate26` のタイトルは `project.getName()` 判定から `budgetTypeId` ベースに変更されています。

```java
String title = budgetTypeLabel(project.getBudgetTypeId()) + "　　領収書１";
```

`populate24Side` の固定文言 `①選手強化費` も、`budgetTypeId` ベースに変更されています。

```java
String budgetPart = (btId != null && btId >= 1 && btId <= 3)
        ? circledNumber(btId) + budgetTypeLabel(btId)
        : budgetTypeLabel(btId);
```

`rg "project\\.getName\\(\\)" ExcelExportService.java` の残存は `pruneTemplateEllipses24Side` の図形削除用途のみで、補助金区分判定ではないため許容します。

### 3. 複数選択の単体様式出力

**OK**

以下の経路に新シート名・ソート・グループ化が適用されています。

- `exportForm24` 単独/複数
- `exportForm25` via `exportMultiSheet("2-5", ...)`
- `exportForm26` via `exportMultiSheet("2-6", ...)`
- `exportAllFormsForProjects`
- `exportYearlySummary`

`exportForm24` 複数IDでは、`budgetTypeId + targetCategory` ごとにグループ化し、グループ内で2件ずつペアリングする実装になっています。

`exportMultiSheet` も `prefix + "_" + budgetTypeLabel + "_" + targetCategory + "_" + circledNumber` 形式に変更されています。

## Dex環境での検証

- 対象コミット: `8ec91c8 [v2.2.1] Cycle 8.3 Take2`
- `R20 = ③ 旅行雑費` を openpyxl で直接確認。
- `project.getName()` による補助金区分判定が残っていないことを確認。
- `application.properties` の `app.version=v2.2.1` を確認。
- `mvnw.cmd -q -DskipTests compile` はDex環境では Maven Wrapper 起動問題により実行不可。
  - CCのP3では `Exit: 0` と報告あり。
  - Dexは静的レビューとテンプレート読み取り確認まで実施。

## Kazumax向け最終確認チェックリスト

実機で以下を確認してください。

1. 活動一覧で「年度 → 月 → 補助金区分 → 種別 → 事業名」の絞り込みが動く。
2. 絞り込み後の「年度まとめExcel出力」が、一覧と同じ対象だけを出力する。
3. 複数事業の一括Excelで、シート順が `2-4全て → 2-5全て → 2-6全て` になっている。
4. 2-4は同じ補助金区分 + 同じ種別だけで左右ペアになる。
5. 2-4単独出力は左側に対象、右側は空欄になる。
6. 2-2-1決算書の旅行雑費が `単価 × 人数 × 日数` でJ列の旅行雑費行に出る。
7. 補助金区分2/3の活動で、2-4/2-6の内部タイトルが選手強化費固定にならない。
8. 宿泊費単価0のまま編集保存しても、既存宿泊費が勝手に0円上書きされない。
9. 様式2-6の宿泊費欄はreadonly表示だが、保存値は維持される。
10. 旅行雑費UIの人数・合計が、参加者追加/削除/氏名入力に連動する。

## 判定

Cycle 8.3 Take2は **レビューOK** です。

