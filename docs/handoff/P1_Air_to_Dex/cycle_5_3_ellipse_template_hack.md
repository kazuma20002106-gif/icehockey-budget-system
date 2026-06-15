# Cycle 5.3 P1 実装仕様書 (丸位置の抜本的解決: テンプレートハック)

## 【対象】
- ExcelExportService.java (様式2-4の出力処理全般)
- src/main/resources/書類.xlsx (※更新済み)

## 【現状の問題】
- CCが drawEllipseAtCenter を用いてプログラムで丸を描画しようとしたが、エクセルの列幅が不均等なため、完璧な位置への描画が困難（ズレる）。

## 【修正後のOK状態】
- ExcelExportService.java から、丸を新規描画するコード (drawEllipseAtCenter や drawEllipse 等) を完全に削除する。
- 代わりに、「原本（テンプレート）上に既に描かれている丸図形の中から、**選ばれなかった項目の丸を消去する（Delete）**」処理に変更する。
- ※マエストロが 費用書類.xlsx に完璧な位置で全ての丸を描き込み、それを私が 書類.xlsx として resources に上書き配備済みです。

## 【絶対に壊してはいけない既存仕様】
- 丸囲み以外の印字（日付や金額、スケジュール等）の処理。

## 【対象セル・範囲（分かる場合）】
- 様式2-4のヘッダー部分（事業名：D7:T9、種別：D11:T13）に配置された図形(Shape)。
- CCは各図形の Anchor (row, col) を読み取り、「この図形は col=8 あたりにあるから強化練習だな」と判定して消去ロジックを組むこと。

## 【NG実装例】
- NG: これまで通り createSimpleShape で丸を描こうとする。
- OK: sheet.getDrawingPatriarch().getShapes() を回して、不要なものを emoveShape() する。

## 【Dex/Kazumaxの最終確認が必要な項目】
- 全ての選択パターン（強化合宿、遠征試合、各種別）でエクセルを出力し、正しい丸だけが残り、他の丸が消えているかをKazumaxが目視確認する。
