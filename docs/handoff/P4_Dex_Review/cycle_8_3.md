# Cycle 8.3 Dex DIFFレビュー（P4）

## レビュー結果

**NG（差し戻し）**

CCの実装は大部分の方向性は合っています。特に一覧検索、年度まとめExcelへの検索条件引き継ぎ、2-4/2-5/2-6一括出力の新しい並び順・シート名、宿泊費readonly化、旅行雑費UIは概ねP2に沿っています。

ただし、危険タスクとしては未解消のリスクが残っています。

## 修正必須

### 1. 2-2-1旅行雑費セルが「推定」のまま実装されている

P2では、旅行雑費の出力セルはテンプレートを確認し、根拠を残すことを要求しました。
しかしP3では以下の通り「推定」「目視確認が必要」と報告されています。

- `row=19 (0-indexed) = R20`
- 根拠: 既存セル割当パターンからの推定
- P3に「要目視確認」と明記

金額計算・決算書出力に関わるため、推定のまま実装完了扱いにはできません。

### 2. 事業名による補助金区分判定がExcel内部タイトルに残っている

シート名では `budgetTypeId` helperが使われていますが、`ExcelExportService#populate26` に以下の判定が残っています。

```java
if ("トップチーム".equals(project.getName())) { ... }
else if ("ふるさと".equals(project.getName())) { ... }
```

今回の背景は「事業名からの補助金区分誤判定」なので、Excel内部のタイトルでも `project.getName()` による補助金区分判定を残すべきではありません。

また `populate24Side` のタイトルも固定で `①選手強化費` になっており、補助金区分が2/3の活動で帳票内部表示がズレる可能性があります。

### 3. 複数選択の単体様式出力に新シート名・グループ化ルールが未適用

`buildCombinedWorkbook` 側は改善されていますが、`ExportController#/download` から直接呼ばれる以下の経路は別です。

- `exportForm24(projectIds, ...)`
- `exportForm25(projectIds, ...)`
- `exportForm26(projectIds, ...)`

特に `exportForm24` の複数ID出力は、まだ単純に2件ずつペアリングしており、`budgetTypeId + targetCategory` グループ化が適用されません。
`exportMultiSheet` 経由の2-5/2-6も、シート名が事業名ベースのままです。

ユーザーが「様式2-4のみ」「様式2-5のみ」「様式2-6のみ」を複数選択で出す導線があるため、ここも同じ仕様に揃える必要があります。

## Dex環境での検証結果

- `git show HEAD` で対象コミット `4ea8b10` を確認。
- ソース検索で `getBudgetType()` の誤使用はなし。
- `ProjectMapper.findFiltered` の呼び出し箇所はController側2箇所とMapper定義で整合。
- `mvnw.cmd -q -DskipTests compile` はDex環境では Maven Wrapper 起動エラーで再現確認できず。
  - エラー: `Cannot index into a null array. Cannot start maven from wrapper`
  - CCのP3では compile Exit 0 と報告あり。

## 良かった点

- `Project#getBudgetType()` を使わず、`budgetTypeId` helperにした判断は正しい。
- 一覧検索と年度まとめExcel出力の条件引き継ぎは実装されている。
- 宿泊費欄は `readonly` で、`disabled` ではないため送信値は保持される。
- 旅行雑費UIの保存項目名 `summary.travelMiscCost` / `summary.travelMiscDays` は維持されている。

## 判定

危険タスクのため、上記3点を修正してから再レビューが必要です。

