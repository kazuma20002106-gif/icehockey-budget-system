# [C5.3: CC(P3) => Dex(P4)] 丸問題テンプレートハック化 実装完了報告

## 変更ファイル一覧

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/application.properties`（v1.8.21 → v1.8.22）

## 削除した旧描画コード一覧

| 削除対象 | 内容 |
|---|---|
| `COL_EMU` 定数 | 列幅EMU計算用定数 |
| `ROW_EMU` 定数 | 行高さEMU計算用定数 |
| `drawEllipseAtCenter(...)` | float座標ヘルパー |
| `drawEllipse(sheet, row1, col1, row2, col2)` | 4引数オーバーロード |
| `drawEllipse(sheet, row1, col1, row2, col2, dx1, dy1, dx2, dy2)` | 8引数・createSimpleShape使用の本体 |
| `populate24Side()` 内の全drawEllipseAtCenter呼び出し（6行分） | 事業名・種別の丸描画 |

## `clearExistingShapes(newSheet)` の扱い

`clearExistingShapes()` メソッドを完全削除した。
以下の3箇所にあった呼び出しをすべて除去：
- `exportForm24()` 単一プロジェクト分岐（cloneSheet直後）
- `exportForm24()` 複数プロジェクト分岐（cloneSheet直後）
- `buildCombinedWorkbook()` 様式2-4ループ内（cloneSheet直後）

## 追加したテンプレート丸削除helperの概要

### `classifyTemplateEllipse24(int row1, int localCol)`
アンカーのrow1とlocalCol（colOffset補正後）からテンプレート丸の種類を返す。

### `pruneTemplateEllipses24Side(Sheet sheet, int colOffset, Project project)`
CTDrawing低レベルAPIで片側のTwoCellAnchorを後ろから走査し、不要なテンプレート丸を削除する。

**注意**: `XSSFDrawing.removeShape()` はこのPOIバージョンに存在しないため、`drawing.getCTDrawing().removeTwoCellAnchor(i)` を使用した。

## 使用したアンカー判定表（P2指示書どおり）

| 側 | 項目 | row1 | col1(左) | col1(右) | localCol範囲 | 備考 |
|---|---|---:|---:|---:|---|---|
| 左/右 | 強化練習 | 7 | 5 | 22 | 4〜7 | PROJECT |
| 左/右 | 遠征試合 | 7 | 12 | 29 | 11〜14 | PROJECT |
| 左/右 | 成年男子 | 10 | 5 | 22 | 4〜7 | CATEGORY |
| 左/右 | 成年女子 | 10 | 12 | 29 | 11〜14 | CATEGORY |
| 左/右 | 少年男子 | 11 | 5 | 22 | 4〜7 | CATEGORY |
| 左/右 | 少年女子 | 11 | 12 | 29 | 11〜14 | CATEGORY |

colMinはcolOffset+4、colMaxはcolOffset+17で片側範囲を限定。

## 各フォームの確認結果

### 左側フォーム
- `populate24Side(sheet, id1, 0)` の後、`pruneTemplateEllipses24Side(sheet, 0, project)` を呼ぶ
- `keepProject = "PROJECT:" + project.getName()` と `keepCategory = "CATEGORY:" + project.getTargetCategory()` の2個だけ残る
- 左側の丸削除時はcol1が4〜17の範囲のみ操作するため、右側の丸には触らない

### 右側フォーム
- `populate24Side(sheet, id2, 17)` の後、`pruneTemplateEllipses24Side(sheet, 17, project)` を呼ぶ
- colOffset=17のため、colMinは21、colMaxは34。左側の丸（col1=4〜17）には触らない

### 空欄側（projectがnull）
- `pruneTemplateEllipses24Side(sheet, colOffset, null)` では `keepProject=null`、`keepCategory=null`
- 片側の全6個のテンプレート丸を削除する

## 様式2-4通常印字の退行確認

`populate24Side()` から丸描画コードのみ削除。期日・会場・宿舎・参加人数・金額・日程・成果・記入責任者の印字処理は一切変更なし。

## 様式2-6の退行確認

`populate26()` および `writeMergedTransportText()` は変更なし。`maxSlots=10` と交通欄N:S×3行ブロック結合統一は維持。

## コンパイル結果

```
[INFO] BUILD SUCCESS
[INFO] Total time:  26.153 s
[INFO] Finished at: 2026-06-15T13:37:38+09:00
```

コンパイルエラーなし。

## バージョン確認

- `src/main/resources/application.properties`: `app.version=v1.8.22` ✓
- `target/classes/application.properties`: `app.version=v1.8.22` ✓

## コミット・プッシュ

（コミット後にハッシュを記入）

## Dex(P4)への重点確認観点

- `drawEllipseAtCenter` / `drawEllipse` / `createSimpleShape` が消えているか（ExcelExportService.java全体）
- `clearExistingShapes(newSheet)` の呼び出しが3箇所すべて消えているか
- `pruneTemplateEllipses24Side` が左右両方のクローンシートに対して呼ばれているか
- `colOffset=0/17` で片側範囲を正しく分離しているか
- 空欄側（null）で6個全削除になるか
- 様式2-4の既存印字（期日等）が退行していないか
- 様式2-6の交通欄修正が退行していないか
- CTDrawing直接操作（`removeTwoCellAnchor`）がPOI動作上問題ないか実Excel出力で確認

## 実装上の注意点（次回向け）

`XSSFDrawing.removeShape(XSSFShape)` はこのPOIバージョン（Spring Boot 4 のデフォルト）に存在しない。
`drawing.getCTDrawing().removeTwoCellAnchor(i)` で代替した。Dexが次回P2を書く際は「removeShape()ではなくCTDrawing経由」とP2に明記すること。
