# [C5.3: Dex(P2) => CC(P3)] 丸問題のテンプレートハック化

Cycle 5.3 のP1差し戻し対応をお願いします。

今回の目的は、様式2-4の丸囲みをPOIで新規描画する方式から、テンプレート `src/main/resources/書類.xlsx` に配置済みの丸図形を使う方式へ切り替えることです。
Air/Kazumax側で、丸が正しい位置に入ったテンプレートが `書類.xlsx` として配備済みです。

## ステータス

- Air(P1) 作成済み: `docs/handoff/P1_Air_to_Dex/cycle_5_3_ellipse_template_hack.md`
- Dex(P2) 作成完了
- CC(P3) 実装修正待ち

## 対象ファイル

主対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/application.properties`

テンプレート確認対象:

- `src/main/resources/書類.xlsx`

報告書作成先:

- `docs/handoff/P3_CC_to_Dex/cycle_5_3_ellipse_template_hack.md`

## 現在の最新状態

- 最新コミット: `be5db33`
- 現在バージョン: `app.version=v1.8.21`
- 今回完了時バージョン: `app.version=v1.8.22`

## 絶対に守ること

- `drawEllipseAtCenter()` / `drawEllipse()` / `createSimpleShape()` で丸を描く方式を完全に廃止すること。
- `clearExistingShapes(newSheet)` を様式2-4のクローン直後に呼ばないこと。現在のこの処理は、テンプレート上に配置済みの正しい丸まで全削除してしまう。
- 様式2-4の丸以外の印字処理を壊さないこと。
- 様式2-4右側未使用時のダミーデータクリアを壊さないこと。
- 様式2-6の `maxSlots=10` と交通手段欄 `N:S x 3行` 結合統一を戻さないこと。
- 変更後は必ずコミットし、`git push origin main` まで実行すること。

## 実装方針

### 1. 丸を描くコードを削除する

対象: `ExcelExportService.java`

現在 `populate24Side()` には、以下のような描画処理があります。

```java
drawEllipseAtCenter(sheet, 8.33 + colOffset, 9.23, 3.0, 1.97);
drawEllipseAtCenter(sheet, 14.83 + colOffset, 9.23, 2.5, 1.97);
drawEllipseAtCenter(sheet, 7.0 + colOffset, 11.55, 2.5, 1.55);
drawEllipseAtCenter(sheet, 14.33 + colOffset, 11.55, 2.5, 1.55);
drawEllipseAtCenter(sheet, 6.33 + colOffset, 13.55, 2.0, 1.55);
drawEllipseAtCenter(sheet, 14.33 + colOffset, 13.55, 2.0, 1.55);
```

この方式を廃止してください。

削除対象:

- `COL_EMU`
- `ROW_EMU`
- `drawEllipseAtCenter(...)`
- `drawEllipse(Sheet sheet, int row1, int col1, int row2, int col2)`
- `drawEllipse(Sheet sheet, int row1, int col1, int row2, int col2, int dx1, int dy1, int dx2, int dy2)`
- `drawing.createSimpleShape(anchor)` による丸描画処理

P1のNG実装例どおり、POIで新しい丸を作らないでください。

### 2. 2-4クローン直後の全図形削除をやめる

現在、様式2-4をクローンした直後に以下を呼んでいます。

```java
clearExistingShapes(newSheet);
```

この呼び出しは削除してください。
テンプレート上の正しい丸を活かす方式に変わったため、全図形削除は今回の要件と正反対です。

`clearExistingShapes()` メソッド自体も、様式2-4で使わなくなるなら削除して構いません。
残す場合でも、今回の様式2-4出力経路では呼ばないでください。

### 3. 左右フォームごとに不要なテンプレート丸だけ削除する

テンプレート `書類.xlsx` の様式2-4には、左フォーム6個・右フォーム6個、合計12個の丸が配置済みです。

出力時は以下の状態にしてください。

- 左フォームに事業が入る場合: 左フォームの事業名丸1個、種別丸1個だけ残す。
- 右フォームに事業が入る場合: 右フォームの事業名丸1個、種別丸1個だけ残す。
- 右フォームが未使用の場合: 右フォームの丸6個はすべて削除する。
- 左フォームが未使用の場合: 左フォームの丸6個はすべて削除する。

実装は、`populate24Side()` と `clearSide24()` の流れに合わせ、以下のようなhelperを追加するのが安全です。

```java
private void pruneTemplateEllipses24Side(Sheet sheet, int colOffset, Project project) {
    // project == null の場合、その側の6個を全部削除する。
    // project != null の場合、project.getName() と project.getTargetCategory() に対応する2個だけ残す。
}
```

呼び出し例:

```java
populate24Side(newSheet, id1, 0);          // 左側の文字・金額を出力
pruneTemplateEllipses24Side(newSheet, 0, projectMapper.findById(id1));

if (id2 != null) {
    populate24Side(newSheet, id2, 17);     // 右側の文字・金額を出力
    pruneTemplateEllipses24Side(newSheet, 17, projectMapper.findById(id2));
} else {
    clearSide24(newSheet, 17);
    pruneTemplateEllipses24Side(newSheet, 17, null);
}
```

既存構造に自然に統合できるなら、`populate24Side()` の末尾で `project` を使って処理しても構いません。
ただし、左側処理中に右側の丸を消さないよう、必ず `colOffset` で処理範囲を片側に限定してください。

### 4. 図形判定はアンカー座標で行う

対象は `XSSFDrawing#getShapes()` で取得できる `XSSFSimpleShape` のうち、様式2-4のテンプレート丸です。
`shape.getAnchor()` を `XSSFClientAnchor` として扱い、`getRow1()` / `getCol1()` で判定してください。

テンプレート上の実測アンカーは以下です。

| 側 | 項目 | row1 | col1 | 備考 |
|---|---|---:|---:|---|
| 左 | 強化練習 | 7 | 5 | 事業名 |
| 左 | 遠征試合 | 7 | 12 | 事業名 |
| 左 | 成年男子 | 10 | 5 | 種別 |
| 左 | 成年女子 | 10 | 12 | 種別 |
| 左 | 少年男子 | 11 | 5 | 種別 |
| 左 | 少年女子 | 11 | 12 | 種別 |
| 右 | 強化練習 | 7 | 22 | 事業名 |
| 右 | 遠征試合 | 7 | 29 | 事業名 |
| 右 | 成年男子 | 10 | 22 | 種別 |
| 右 | 成年女子 | 10 | 29 | 種別 |
| 右 | 少年男子 | 11 | 22 | 種別 |
| 右 | 少年女子 | 11 | 29 | 種別 |

`colOffset` は左側が `0`、右側が `17` です。
そのため、`localCol = anchor.getCol1() - colOffset` とすると、左右どちらも同じ判定に寄せられます。

推奨判定:

```java
private String classifyTemplateEllipse24(int row1, int localCol) {
    if (row1 == 7 && localCol >= 4 && localCol <= 7) return "PROJECT:強化練習";
    if (row1 == 7 && localCol >= 11 && localCol <= 14) return "PROJECT:遠征試合";
    if (row1 == 10 && localCol >= 4 && localCol <= 7) return "CATEGORY:成年男子";
    if (row1 == 10 && localCol >= 11 && localCol <= 14) return "CATEGORY:成年女子";
    if (row1 == 11 && localCol >= 4 && localCol <= 7) return "CATEGORY:少年男子";
    if (row1 == 11 && localCol >= 11 && localCol <= 14) return "CATEGORY:少年女子";
    return null;
}
```

片側の対象範囲は `colOffset == 0` なら `col1=4..17` 程度、`colOffset == 17` なら `col1=21..34` 程度で判定してください。
この範囲外の図形には触らないでください。

### 5. removeShapeはコピーしたリストに対して行う

`drawing.getShapes()` を直接拡張forで回しながら削除すると、実装によっては並行変更の事故が起きます。
一度コピーしてから削除してください。

例:

```java
XSSFDrawing drawing = xssfSheet.getDrawingPatriarch();
if (drawing == null) return;

List<XSSFShape> shapes = new ArrayList<>(drawing.getShapes());
for (XSSFShape shape : shapes) {
    if (!(shape instanceof XSSFSimpleShape)) continue;
    if (!(shape.getAnchor() instanceof XSSFClientAnchor)) continue;

    XSSFClientAnchor anchor = (XSSFClientAnchor) shape.getAnchor();
    int row1 = anchor.getRow1();
    int col1 = anchor.getCol1();

    // 片側範囲外なら触らない
    // テンプレート丸でなければ触らない
    // 残すべき丸でなければ drawing.removeShape(shape)
}
```

必要なimport例:

```java
import java.util.ArrayList;
import java.util.List;
import org.apache.poi.xssf.usermodel.XSSFClientAnchor;
import org.apache.poi.xssf.usermodel.XSSFDrawing;
import org.apache.poi.xssf.usermodel.XSSFShape;
import org.apache.poi.xssf.usermodel.XSSFSheet;
import org.apache.poi.xssf.usermodel.XSSFSimpleShape;
```

### 6. 選択値との対応

残す丸は以下の2種類です。

事業名:

- `project.getName()` が `強化練習` の場合、`PROJECT:強化練習` を残す。
- `project.getName()` が `遠征試合` の場合、`PROJECT:遠征試合` を残す。

種別:

- `project.getTargetCategory()` が `成年男子` の場合、`CATEGORY:成年男子` を残す。
- `project.getTargetCategory()` が `成年女子` の場合、`CATEGORY:成年女子` を残す。
- `project.getTargetCategory()` が `少年男子` の場合、`CATEGORY:少年男子` を残す。
- `project.getTargetCategory()` が `少年女子` の場合、`CATEGORY:少年女子` を残す。

`project == null` の空欄側では、片側6個のテンプレート丸をすべて削除してください。

### 7. 様式2-5の図形には触らない

OpenXML確認では、`drawing2.xml` は様式2-5側の吹き出し図形です。
今回の対象は様式2-4の丸だけです。
様式2-5/2-6の図形、セル、結合、印字は触らないでください。

## 検証項目

最低限、以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS`。
- `src/main/resources/application.properties` が `app.version=v1.8.22`。
- `target/classes/application.properties` も `app.version=v1.8.22`。
- `ExcelExportService.java` に `drawEllipseAtCenter` が残っていない。
- `ExcelExportService.java` に `createSimpleShape` による丸描画が残っていない。
- 様式2-4のクローン直後に `clearExistingShapes(newSheet)` を呼んでいない。
- 左側フォームで `強化練習` + `成年男子` を出力したとき、その2個だけ丸が残る。
- 左側フォームで `遠征試合` + `少年女子` を出力したとき、その2個だけ丸が残る。
- 右側フォームでも同じ判定で正しい2個だけ丸が残る。
- 右側未使用時、右側の丸6個がすべて消える。
- 左右2活動出力時、左の丸削除処理が右側の丸を消していない。
- 丸位置がテンプレート由来の位置になっており、POIで新規描画した丸が重複していない。
- 様式2-4の期日、会場、宿舎、参加人数、金額、日程、成果、記入責任者が従来どおり印字される。
- 様式2-6の `maxSlots=10` と交通手段欄 `N:S x 3行` 結合が退行していない。

## P3報告書に必ず書くこと

`docs/handoff/P3_CC_to_Dex/cycle_5_3_ellipse_template_hack.md` を作成し、以下を書いてください。

- 変更ファイル一覧
- 削除した旧描画コード一覧
- `clearExistingShapes(newSheet)` をどう扱ったか
- 追加したテンプレート丸削除helperの概要
- 使用したアンカー判定表
- 左側フォームの確認結果
- 右側フォームの確認結果
- 空欄側の丸が消えることの確認結果
- 様式2-4の通常印字が退行していないこと
- 様式2-6が退行していないこと
- `.\mvnw compile` の結果
- `src` と `target/classes` のバージョン確認結果
- コミットハッシュ
- `git push origin main` の実行結果
- Dex(P4) に重点確認してほしい観点

## 完了時の必須作業

1. `app.version=v1.8.22` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.22` を確認する。
4. 可能なら実Excelを出力して、左右フォームの丸が正しく残ることを目視確認する。
5. 変更をコミットする。
6. `git push origin main` を実行する。
7. P3報告書を `docs/handoff/P3_CC_to_Dex/cycle_5_3_ellipse_template_hack.md` に作成する。
8. Kazumax向け報告には「GitHubへプッシュしました」と明記する。

## Dex(P4)で重点確認する観点

- `drawEllipseAtCenter` / `drawEllipse` / `createSimpleShape` が消えているか。
- `clearExistingShapes(newSheet)` でテンプレート丸を全削除していないか。
- アンカー分類が左側・右側の両方に対応しているか。
- 空欄側の丸が残らないか。
- 選択された事業名丸と種別丸だけが残るか。
- 様式2-4の既存印字処理と様式2-6の交通欄修正が退行していないか。

## 次の担当への合図（コピー用）

```text
CCへ。docs/handoff/P2_Dex_to_CC/cycle_5_3_ellipse_template_hack.md を読んで、Cycle 5.3の丸問題テンプレートハック化を実装してください。完了後は .\mvnw compile、app.version=v1.8.22 の src/target 同期確認、実Excelで左右フォームの丸確認、コミット、git push origin main まで実施し、docs/handoff/P3_CC_to_Dex/cycle_5_3_ellipse_template_hack.md に報告書を作成してください。Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
