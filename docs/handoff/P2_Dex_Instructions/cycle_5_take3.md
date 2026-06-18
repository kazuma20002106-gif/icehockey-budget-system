# [C5: Dex(P2) => CC(P3) Take3]

Cycle 5 の追加修正をお願いします。Kazumax のP5テストで、様式2-4の丸囲み座標ズレと、右側フォーム未使用時のダミーデータ残りが見つかりました。今回は既存のCycle 5実装を壊さず、様式2-4の2点だけを集中修正してください。

現在の最新バージョンは `v1.8.11` です。実装完了時は `src/main/resources/application.properties` の `app.version` を `v1.8.12` に更新し、`.\mvnw compile` 後に `target/classes/application.properties` も `v1.8.12` になっていることを確認してください。

## ステータス

- Dex(P2) Take3 作成完了
- CC(P3) Take3 実装修正待ち

## 対象ファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/application.properties`

必要に応じて、検証用の一時コードやデバッグログを使って構いません。ただし、不要な一時ファイルやデバッグ出力はコミット前に消してください。

## 事前注意

- 既存のCycle 5実装済み項目（プレビュー導線、令和表記、2-5、2-6、電話番号補完、月別フィルター）は戻さないでください。
- テンプレート座標は必ず `src/main/resources/書類.xlsx` の様式2-4原本を確認して決めてください。
- `drawEllipse()` の座標は、左側フォームと右側フォームの両方でズレないようにしてください。
- `clearSide24()` はテンプレート右側のダミーデータを残さないことが目的です。既存の左側データや記入責任者欄を消さないよう、右側エリアだけを安全にクリアしてください。

## 実装要件

### 1. 様式2-4の丸囲み座標を修正する

対象: `ExcelExportService.java`

現在、`populate24Side()` から以下のように丸囲みを描画しています。

```java
drawEllipse(sheet, 6, 4 + colOffset, 7, 9 + colOffset);   // 強化練習
drawEllipse(sheet, 6, 12 + colOffset, 7, 17 + colOffset);  // 遠征試合
drawEllipse(sheet, 10, 4 + colOffset, 11, 8 + colOffset);  // 成年男子
drawEllipse(sheet, 10, 12 + colOffset, 11, 16 + colOffset); // 成年女子
drawEllipse(sheet, 11, 4 + colOffset, 12, 8 + colOffset);  // 少年男子
drawEllipse(sheet, 11, 12 + colOffset, 12, 16 + colOffset); // 少年女子
```

P5テストでは、特に `成年女子` などの丸が左上にズレています。文字を綺麗に囲むように調整してください。

実装方針:

- `drawEllipse()` に `dx1`, `dy1`, `dx2`, `dy2` を指定できる overload または helper を追加してください。
- `XSSFClientAnchor` は `createAnchor(dx1, dy1, dx2, dy2, col1, row1, col2, row2)` の `dx/dy` でセル内オフセット調整できます。
- 左上にズレている場合は、左上アンカーを少し右下へ、右下アンカーも必要に応じて右下へ広げてください。
- すべての丸を一律で動かすと別の項目がズレる可能性があります。項目ごとに調整値を持てる形を推奨します。

推奨実装例:

```java
private void drawEllipse(Sheet sheet, int row1, int col1, int row2, int col2) {
    drawEllipse(sheet, row1, col1, row2, col2, 0, 0, 0, 0);
}

private void drawEllipse(Sheet sheet, int row1, int col1, int row2, int col2,
                         int dx1, int dy1, int dx2, int dy2) {
    if (sheet instanceof org.apache.poi.xssf.usermodel.XSSFSheet) {
        org.apache.poi.xssf.usermodel.XSSFSheet xssfSheet = (org.apache.poi.xssf.usermodel.XSSFSheet) sheet;
        org.apache.poi.xssf.usermodel.XSSFDrawing drawing = xssfSheet.createDrawingPatriarch();
        org.apache.poi.xssf.usermodel.XSSFClientAnchor anchor =
                drawing.createAnchor(dx1, dy1, dx2, dy2, col1, row1, col2, row2);
        org.apache.poi.xssf.usermodel.XSSFSimpleShape shape = drawing.createSimpleShape(anchor);
        shape.setShapeType(org.apache.poi.ss.usermodel.ShapeTypes.ELLIPSE);
        shape.setLineStyleColor(0, 0, 0);
        shape.setLineWidth(1.5);
        shape.setNoFill(true);
    }
}
```

注意:

- `dx/dy` はEMU単位です。値を大きくしすぎると逆方向にズレます。小さく試して、出力Excelで目視確認してください。
- 右側フォームは `colOffset == 17` でも同じ見た目になるようにしてください。
- P3報告書には、最終的に採用した各丸の `row/col` と `dx/dy` を表で書いてください。

確認対象:

- 事業名: `強化練習`
- 事業名: `遠征試合`
- 種別: `成年男子`
- 種別: `成年女子`
- 種別: `少年男子`
- 種別: `少年女子`
- 左側フォーム
- 右側フォーム

### 2. 様式2-4の右側未使用時にダミーデータを完全消去する

対象: `ExcelExportService.java`

現在の `clearSide24(sheet, 17)` は主要セルだけを消していますが、P5テストで以下のような右側ダミーデータが残っています。

- 旅行雑費
- 計の金額
- 参加人員 `4名` など
- その他、テンプレート右側に最初から入っている文字・数値

右側を使わない場合は、右側フォームを完全な白紙状態にしてください。

対象ケース:

- `exportForm24()` で `projectIds.size() == 1` かつ対象活動が年度内で奇数回目のため、右側が空欄になるケース。
- 複数ID出力で最後の1件が左側だけに入り、右側 `id2 == null` になるケース。
- `buildCombinedWorkbook()` で様式2-4を作るときに右側 `id2 == null` になるケース。

修正方針:

- `clearSide24(Sheet sheet, int colOffset)` を拡張し、右側エリアの入力セルをすべてクリアしてください。
- 右側フォームの範囲は概ね `colOffset == 17` の列17〜33付近ですが、必ず `書類.xlsx` の様式2-4を確認してください。
- 少なくとも現在の処理に加えて、以下を確認・クリア対象に含めてください。
  - 参加人員の周辺セル
  - 交通費、宿泊費、旅行雑費
  - 駐車料、借用料、需用費、役務費、報償費
  - 計
  - 日程及び内容
  - 事業の成果
  - 会場、宿舎名、期日
  - 右側に残るテンプレート由来のダミー文字/数値
- `clearCell()` で書式は維持し、値だけ消してください。必要な数値欄で完全空欄より `0` が妥当な場合は、P3報告で理由を書いてください。

実装上の注意:

- `clearSide24(sheet, 17)` の指導者数/選手数セルは現在 `6 + 17` / `12 + 17` を消していますが、P5で `4名` が残っているため、実際の表示セルが別列または結合セルの左上セルでない可能性があります。テンプレートの結合セル情報を確認し、結合セルは左上セルをクリアしてください。
- 右側の「様式の固定ラベル」まで消す必要はありません。消すべきなのは入力値・ダミー値です。
- 左側フォーム、年度見出し、記入責任者欄は消さないでください。

### 3. 出力Excelで必ず目視確認する

実装後、最低限以下のExcelを出力して確認してください。

- 年度内で奇数回目の活動1件を `2-4` 単体出力し、右側が白紙であること。
- 年度内で偶数回目の活動1件を `2-4` 単体出力し、左に前回活動、右に対象活動が出ること。
- 複数活動で最後が奇数件になる出力を行い、最後のシート右側が白紙であること。
- `強化練習` / `遠征試合` / `成年男子` / `成年女子` / `少年男子` / `少年女子` の丸が、左右フォームとも文字を綺麗に囲んでいること。

## 検証項目

実装後、最低限以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS`。
- `src/main/resources/application.properties` と `target/classes/application.properties` がどちらも `app.version=v1.8.12`。
- 様式2-4の丸囲みが左上にズレず、対象文字を綺麗に囲む。
- 様式2-4の右側未使用時に、旅行雑費・計・参加人員などのダミーデータが残らない。
- Cycle 5で完了済みのプレビュー導線、令和表記、2-5、2-6、電話番号補完、月別フィルターが壊れていない。

## 完了時の必須作業

1. `app.version=v1.8.12` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.12` を確認する。
4. 変更をコミットする。
5. `git push origin main` を実行する。
6. P3 Take3 報告書を `docs/handoff/P3_CC_to_Dex/cycle_5_take3.md` に作成する。
7. Kazumax向け報告には「GitHubへプッシュしました」と明記する。

## P3 Take3 報告書に必ず書くこと

- 変更ファイル一覧
- 丸囲み座標の修正内容
- 採用した `row/col/dx/dy` の表
- `clearSide24()` で追加クリアしたセル一覧
- 出力Excelの目視確認結果
- `.\mvnw compile` の結果
- `src` と `target/classes` のバージョン確認結果
- コミットハッシュ
- `git push origin main` の実行結果
- Dex(P4) に確認してほしい観点

## 提案

なし。

## 次の担当への合図（コピー用）

```text
CCへ。docs/handoff/P2_Dex_to_CC/cycle_5_take3.md を読んで、Cycle 5 Take3 の追加修正をお願いします。完了後は .\mvnw compile、app.version=v1.8.12 の src/target 同期確認、コミット、git push origin main まで実施し、docs/handoff/P3_CC_to_Dex/cycle_5_take3.md に報告書を作成してください。Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
