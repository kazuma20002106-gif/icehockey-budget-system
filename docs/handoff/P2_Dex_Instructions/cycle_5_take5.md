# [C5.2: Dex(P2) => CC(P3) Take5]

Cycle 5.2 の再々差し戻し対応をお願いします。今回は Kazumax のP5再レビューで残った最終調整です。対象は以下の3点です。

- 様式2-4の丸囲み座標の再調整
- 様式2-6の「航空機」等の2段セル結合・大きな中央印字
- 入力画面の交通手段に応じたキロ数入力ロック

現在の最新バージョンは `v1.8.13` です。実装完了時は `src/main/resources/application.properties` の `app.version` を `v1.8.14` に更新し、`.\mvnw compile` 後に `target/classes/application.properties` も `v1.8.14` になっていることを確認してください。

## ステータス

- Dex(P2) Take5 作成完了
- CC(P3) Take5 実装修正待ち

## 対象ファイル

主対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/templates/activity/form.html`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ProjectService.java`
- `src/main/resources/application.properties`

必要に応じて確認するファイル:

- `src/main/resources/書類.xlsx`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/model/Expense.java`
- `target/classes/application.properties`

## 絶対に守ること

- Cycle 5 から `v1.8.13` までに入った既存修正を戻さないこと。
- 様式2-4右側未使用時のダミーデータクリアを壊さないこと。
- 様式2-4の相方自動連行、連番、シート名、印刷範囲設定を壊さないこと。
- 様式2-5/2-6の記入責任者・日付・合計金額の修正を壊さないこと。
- 変更後は必ずコミットし、`git push origin main` まで実行すること。

---

## 1. 様式2-4の丸囲み座標をさらに右下へ再調整する

対象: `ExcelExportService.java`

現在 `populate24Side()` では、丸囲みが以下のように描画されています。

```java
drawEllipse(sheet, 6, 4 + colOffset, 7, 9 + colOffset, 0, 100000, 0, 100000);
drawEllipse(sheet, 6, 12 + colOffset, 7, 17 + colOffset, 0, 100000, 0, 100000);
drawEllipse(sheet, 10, 4 + colOffset, 11, 8 + colOffset, 0, 100000, 0, 100000);
drawEllipse(sheet, 10, 12 + colOffset, 11, 16 + colOffset, 0, 100000, 0, 100000);
drawEllipse(sheet, 12, 4 + colOffset, 13, 8 + colOffset, 0, 100000, 0, 100000);
drawEllipse(sheet, 12, 12 + colOffset, 13, 16 + colOffset, 0, 100000, 0, 100000);
```

Kazumax の画像確認では、特に右側フォームの `遠征試合`、`成年女子` などの丸がまだ左上にずれています。`dx1, dy1, dx2, dy2` をさらにプラス調整し、右方向・下方向へ寄せて、文字の中心を自然に囲むようにしてください。

### 実装方針

- `drawEllipse()` の overload は既にあります。これを活かしてください。
- `dx1` と `dy1` だけでなく、必要に応じて `dx2` と `dy2` も調整してください。
- 一律値で済ませず、少なくとも以下の6項目は項目ごとに調整値を持たせてください。
  - `強化練習`
  - `遠征試合`
  - `成年男子`
  - `成年女子`
  - `少年男子`
  - `少年女子`
- 右側フォームは `colOffset == 17` です。今回の主な不具合は右側なので、右側で綺麗に見えることを優先しつつ、左側も崩れない値にしてください。
- `dx/dy` はEMU単位です。目安として、現在の `dx1=0, dy1=100000, dx2=0, dy2=100000` より、`dx1` と `dx2` を右方向へ、`dy1` と `dy2` を下方向へ増やしてください。
- 値は必ず出力Excelを見て調整してください。目視なしで「完了」としないでください。

### P3報告に必ず書くこと

採用した座標を以下の表で書いてください。

| 対象 | row1 | col1 | row2 | col2 | dx1 | dy1 | dx2 | dy2 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 強化練習 |  |  |  |  |  |  |  |  |
| 遠征試合 |  |  |  |  |  |  |  |  |
| 成年男子 |  |  |  |  |  |  |  |  |
| 成年女子 |  |  |  |  |  |  |  |  |
| 少年男子 |  |  |  |  |  |  |  |  |
| 少年女子 |  |  |  |  |  |  |  |  |

---

## 2. 様式2-6で「航空機」等を2段セル結合し、大きく中央印字する

対象: `ExcelExportService.java`

現在 `populate26()` では、交通欄に以下のような処理があります。

```java
clearCell(sheet, r, 13);
clearCell(sheet, r + 1, 13);
writeSafe(sheet, r, 13, buildTransportLabel(method, distKm));
writeSafe(sheet, r + 2, 13, route);
```

このため、交通手段が `航空機` のような単語だけの場合でも、見た目が小さく分割表示されます。P1要件どおり、区間を示す `～` または `〜` が含まれない交通内容は、2段分のセルを結合して大きく中央に表示してください。

### 判定ルール

次の条件を満たす場合は「デカ文字マージ出力」にしてください。

- `method` が `航空機`、`バス`、`電車` などで、交通区間文字列に `～` または `〜` が含まれない。
- または、`buildTransportLabel(method, distKm)` の結果が単独交通手段名だけになる。

特に `航空機` は必ず対象です。

### 実装内容

- 2-6の交通欄の列は現在 `col=13` を使っています。この列について、対象参加者ブロックの `r` 行と `r + 1` 行を `CellRangeAddress(r, r + 1, 13, 13)` で結合してください。
- 結合前に、同じ範囲と重なる既存の結合セルがあれば解除してください。Apache POI は重複マージで例外が出るため、必ず安全に処理してください。
- 結合セルの左上セル `r,13` に `航空機` などの文字を入れてください。
- `r + 1,13` は空欄にしてください。
- セルスタイルは中央揃え・上下中央にしてください。
- フォントは既存より少し大きくしてください。例: 14pt 程度。テンプレートの見た目に合う範囲で調整してください。
- `r + 2,13` の交通区間欄は、ルートが空または `～` なしの場合は空欄にしてください。
- ルートに `～` または `〜` がある通常ケースは、従来どおり2段表示を維持してください。

### 実装補助

必要に応じて以下のような helper を追加してください。

- `private boolean hasRouteSeparator(String route)`
- `private boolean shouldMergeTransportMethod(String method, String route)`
- `private void removeMergedRegionsOverlapping(Sheet sheet, int firstRow, int lastRow, int firstCol, int lastCol)`
- `private void writeMergedTransportMethod(Sheet sheet, int row, int col, String text)`

`CellRangeAddress` を使うため、必要な import を追加してください。

```java
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.VerticalAlignment;
```

### 重要: 電車・バス・航空機のkm表記を残さない

今回のUI修正と合わせて、`buildTransportLabel()` も見直してください。

- `自家用車` のみ `自家用車( 90 )㎞` のように距離を表示してよい。
- `航空機`、`バス`、`電車` は距離を表示しないで、原則 `航空機`、`バス`、`電車` のように交通手段名だけにしてください。
- これにより、過去データに距離が残っていても `電車( 90 )㎞` のような無意味な印字を防げます。

---

## 3. 入力画面で自家用車以外のキロ数入力をロックする

対象: `src/main/resources/templates/activity/form.html`

### 3-1. 交通手段の初期値を自家用車にする

既存行と行テンプレートの両方で、交通手段プルダウンの初期値を `自家用車` にしてください。

既存行:

- `e.transportMethod` が `null` または空文字の場合は `自家用車` を選択状態にする。
- 既に `航空機` / `バス` / `電車` / `自家用車` が保存されている行は、その値を維持する。

新規行テンプレート:

- `<option value="自家用車" selected>自家用車</option>` をデフォルトにする。

### 3-2. 自家用車以外では距離欄を disabled にし、値をクリアする

交通手段プルダウンが `自家用車` 以外になったら、同じ行の `.distance-input` を以下の状態にしてください。

- `disabled = true`
- `value = ""`
- 距離スピナーが開いていた場合は閉じる
- 交通費再計算と合計再計算を実行する

交通手段が `自家用車` に戻ったら、同じ行の `.distance-input` を入力可能にしてください。

### 3-3. JSで必ず対応する箇所

以下のすべてに対応してください。

- ページ初期表示時: 既存行すべてにロック状態を反映する。
- 交通手段変更時: `change` イベントで即時にロック状態を反映する。
- 行追加時: 新規行の初期値が `自家用車` で、距離欄が入力可能になっている。
- 自動距離取得時: その行の交通手段が `自家用車` でない場合、`autoFetchDistance()` は距離と交通費をセットしない。
- `calculateTransportCostForRow(row)`: 自家用車以外または距離欄 disabled の場合は、距離から交通費を再計算しない。必要なら交通費は手入力を尊重する。
- 距離スピナー: disabled の距離欄では開かない。

### 推奨JS helper

以下のような helper を追加してください。

```javascript
function getTransportMethod(row) {
    const select = row.querySelector('select[name*=".transportMethod"]');
    return select ? select.value : '';
}

function syncDistanceLock(row) {
    const method = getTransportMethod(row);
    const distInput = row.querySelector('.distance-input');
    if (!distInput) return;

    if (method && method !== '自家用車') {
        distInput.value = '';
        distInput.disabled = true;
        closeDistanceSpinner();
    } else {
        distInput.disabled = false;
    }
}

function syncAllDistanceLocks() {
    expenseBody.querySelectorAll('.expense-row').forEach(syncDistanceLock);
}
```

ただし、既存コードに合わせて自然に統合してください。

### 3-4. 保存時のサーバ側ガードも必須

対象: `ProjectService.java`

フロントだけでは、過去データやブラウザ差分で距離が残る可能性があります。保存時にも以下を必ず実施してください。

- `Expense.transportMethod` が `自家用車` 以外なら、`transportDistanceKm` を `null` にする。
- これによりDB上にも不要な距離が残らないようにする。

---

## 4. 検証項目

実装後、最低限以下を確認してください。

### コンパイル・バージョン

- `.\mvnw compile` が `BUILD SUCCESS`。
- `src/main/resources/application.properties` が `app.version=v1.8.14`。
- `target/classes/application.properties` が `app.version=v1.8.14`。

### 様式2-4

- `強化練習` の丸が左側・右側とも文字の中央を囲む。
- `遠征試合` の丸が左側・右側とも文字の中央を囲む。
- `成年男子` の丸が左側・右側とも文字の中央を囲む。
- `成年女子` の丸が左側・右側とも文字の中央を囲む。
- `少年男子` の丸が左側・右側とも文字の中央を囲む。
- `少年女子` の丸が左側・右側とも文字の中央を囲む。
- 右側未使用時に `3名`、`2日`、旅行雑費、計などのダミーデータが残らない。

### 様式2-6

- 交通手段が `航空機` の参加者で、交通欄が2段結合され、中央に大きく `航空機` と表示される。
- `航空機` の行で `r + 2` の交通区間欄に不要な文字が残らない。
- 交通手段が `バス` でルートに `～` がない場合も、同様に大きく中央表示できる。
- 交通手段が `自家用車` で距離ありの場合は、従来どおり距離つき表示が維持される。
- 交通手段が `電車` で過去距離が残っていても、`電車( 90 )㎞` のような表示にならない。
- 合計金額、期日、受領日、記入責任者欄が壊れていない。

### 入力画面

- 新規行の交通手段が最初から `自家用車` になっている。
- `自家用車` のときは距離欄が入力できる。
- `航空機`、`バス`、`電車` に変更すると距離欄が空になり、入力不可になる。
- もう一度 `自家用車` に戻すと距離欄が入力可能になる。
- 交通手段が `航空機`、`バス`、`電車` の行では、自動距離取得で距離・交通費が勝手に入らない。
- 保存後に再編集しても、自家用車以外の距離が復活しない。

## 5. P3 Take5報告書に必ず書くこと

`docs/handoff/P3_CC_to_Dex/cycle_5_take5.md` を作成し、以下を書いてください。

- 変更ファイル一覧
- 様式2-4の丸囲みで採用した `row/col/dx/dy` 表
- 様式2-4の出力Excel目視確認結果
- 様式2-6のセル結合対象条件と実装内容
- 様式2-6の出力Excel目視確認結果
- 入力画面の距離ロック実装内容
- 入力画面の動作確認結果
- `ProjectService.java` 側の保存時ガード内容
- `.\mvnw compile` の結果
- `src` と `target/classes` のバージョン確認結果
- コミットハッシュ
- `git push origin main` の実行結果
- Dex(P4) に確認してほしい観点

## 6. 完了時の必須作業

1. `app.version=v1.8.14` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.14` を確認する。
4. 変更をコミットする。
5. `git push origin main` を実行する。
6. P3 Take5報告書を `docs/handoff/P3_CC_to_Dex/cycle_5_take5.md` に作成する。
7. Kazumax向け報告には「GitHubへプッシュしました」と明記する。

## 7. Dex(P4)で重点確認する観点

- `ExcelExportService.java` の丸座標が本当に右下方向へ再調整されているか。
- 2-6の結合セル処理が、既存マージ領域と衝突しない安全実装になっているか。
- `buildTransportLabel()` で自家用車以外のkm表示が消えているか。
- `form.html` の既存行・新規行・変更時・自動距離取得時のすべてで距離ロックが効くか。
- `ProjectService.java` で自家用車以外の距離が保存時にnull化されるか。

## 提案

今回のP2では、P1要件に加えて保存時のサーバ側ガードも必須にしました。UIだけで防ぐと過去データやブラウザ挙動で距離が残る可能性があるためです。

## 次の担当への合図（コピー用）

```text
CCへ。docs/handoff/P2_Dex_to_CC/cycle_5_take5.md を読んで、Cycle 5.2 Take5 の再々差し戻し修正をお願いします。完了後は .\mvnw compile、app.version=v1.8.14 の src/target 同期確認、コミット、git push origin main まで実施し、docs/handoff/P3_CC_to_Dex/cycle_5_take5.md に報告書を作成してください。Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
