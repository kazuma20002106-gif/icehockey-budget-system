# Cycle 8.3 差し戻し指示（Dex → CC）

## 結論

Cycle 8.3 Take1は差し戻しです。

実装の方向性は概ね合っていますが、危険タスクとして修正必須が3件あります。
コードを戻す必要はありません。現状実装をベースに追加修正してください。

## 修正必須1: 2-2-1旅行雑費セルを推定のままにしない

現在:

- `populate22Summary` で `writeSafeNumeric(sheet22, 19, 9, totalTravelMisc)` を追加。
- ただしP3で「R20は推定」「目視確認が必要」と報告している。

修正:

1. `書類.xlsx` の `SHEET_22` を実際に読み、旅行雑費の行がどこか確認してください。
2. 可能ならコードまたは一時確認結果で、該当行のラベル文字列を確認してください。
3. 正しい0-indexed rowへ `totalTravelMisc` を出力してください。
4. P3に「推定」ではなく、確認したセル・行番号・根拠を書いてください。

もしテンプレート上で旅行雑費行を特定できない場合は、勝手に推定出力せず、実装を止めてP3に未確定として報告してください。

## 修正必須2: Excel内部タイトルの補助金区分を事業名で判定しない

現在 `ExcelExportService#populate26` に以下が残っています。

```java
if ("トップチーム".equals(project.getName())) { ... }
else if ("ふるさと".equals(project.getName())) { ... }
```

修正:

1. `project.getName()` ではなく `project.getBudgetTypeId()` からタイトルを決めてください。
2. 既存の `budgetTypeLabel(Integer budgetTypeId)` を活用してください。
3. `populate24Side` のタイトル固定 `①選手強化費` も、補助金区分に応じてズレないよう修正してください。
4. 事業名から補助金区分を推測するコードが残っていないことを `rg "project.getName\\(\\)" ExcelExportService.java` 等で確認してください。

注意:

- `pruneTemplateEllipses24Side` の `PROJECT:` 判定など、帳票テンプレート上の図形削除用途で事業名を使う箇所は、補助金区分判定ではないため残してよいです。
- 問題は「補助金区分や帳票タイトルを事業名で決めること」です。

## 修正必須3: 複数選択の単体様式出力にもルールを揃える

現在 `buildCombinedWorkbook` 側は改善されていますが、以下の直接出力経路は別実装です。

- `exportForm24(projectIds, ...)`
- `exportForm25(projectIds, ...)`
- `exportForm26(projectIds, ...)`

修正:

1. `exportForm24` で `projectIds.size() > 1` の場合も、`budgetTypeId + targetCategory` グループ内でペアリングしてください。
2. `exportForm25` / `exportForm26` の複数シート名も `[様式]_[補助金区分]_[種別]_[連番]` に寄せてください。
3. `ExportController#/download` から「様式2-4のみ」「2-5のみ」「2-6のみ」を複数選択した場合でも、今回のシート名・グループ化仕様から外れないようにしてください。

## 検証

最低限、以下を実施してください。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

加えて、P3に以下を書いてください。

- 2-2-1旅行雑費セルの確認結果。
- 事業名で補助金区分を判定するコードが残っていない確認結果。
- 複数選択の `2-4のみ / 2-5のみ / 2-6のみ / all` の出力仕様が揃ったか。

