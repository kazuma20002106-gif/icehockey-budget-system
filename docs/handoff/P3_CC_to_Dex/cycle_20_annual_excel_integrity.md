[C20: CC(P3) ⇒ Dex(P4)]

# Cycle 20 年度末Excel完全性修正 CC実装報告

## 1. Air試作品の扱い（採用・修正・不採用）

Dex(P2)指示（`docs/handoff/P2_Dex_to_CC/cycle_20_annual_excel_integrity_instructions.md`）に従い、Air試作品（未承認・未コミット差分として `src/main/java/.../service/ExcelExportService.java` に存在していたもの）を全面採用せず、以下のとおり項目ごとに採用/修正/不採用を判断した。

| Air試作の内容 | 判断 | 理由 |
|---|---|---|
| 2-2-1（3シート）年度書込（H2/H3にrYear） | **採用** | Dex P2要件どおり。座標・和暦変換とも正しい |
| 2-3 K25:K28/T25:T28/AC25/K33/T33/AC33の事前クリア | **採用** | 上部1〜23行の不可侵エリアに触れず、下部自動書込範囲のみを対象にしており安全 |
| populate25: 参加者ありの行にも`clearCellRangeValues(r,r,1,9)`を追加 | **不採用（削除）** | Dexが「参加者ありの行/ブロックを一括blank化する実装は固定値・式・帳票ラベルが不変と証明できるまで採用禁止」と明記。占有行は元のまま書込むだけで十分と判断し、元の実装（クリアなし）へ戻した |
| populate25: 空き行のクリアを`clearCell`個別3列から`clearCellRangeValues(col1〜9)`へ拡張 | **採用（修正のうえ）** | 空きスロットは「空欄であることが仕様化されたセル」に該当し、Dexが許容する範囲。ただし対象は空き行のみに限定し、占有行には一切適用しない |
| populate26: 占有ブロックに`clearCellRangeValues(r,r+2,2,33)`（B:AH全域）を追加 | **不採用（狭い実装へ差し替え）** | 占有ブロックの広範囲blank化はDexが明示的に禁止。実際に書込む列(2,9,19,23,27,31)だけを対象にした`clearColumnsAcrossRows`ヘルパーへ差し替え、書込対象外の列(3-8,10-18,20-22,24-26,28-30,32,33等)には一切触れないようにした |
| populate26: 空きブロックに`clearCellRangeValues(r,r+2,2,33)`を追加 | **不採用（同上へ差し替え）** | 同上。占有ブロックと同じ狭い`clearColumnsAcrossRows`へ統一し、書込列以外を保護した |
| writeSplitTransportText: 結合解除後にN:S列を値クリアしてから再結合 | **採用（無修正）** | Dexが候補として明示した方式そのもの。結合裏の残留ダミー値を狙い撃ちで駆逐でき、書込列(N:S)以外に触れないため安全 |
| `evaluateFormulasAndRecalculate`を全出力パス（buildCombinedWorkbook, exportForm22Summary, exportMultiSheet, exportForm24, buildAnnualClosingWorkbook）に追加 | **不採用（年度末公式出力のみへ縮小）** | Dexが「年度末公式出力と直接関係がない通常様式別出力へ無差別に評価処理を追加しない」と明記。`buildAnnualClosingWorkbook`（年度末公式出力）1箇所のみに残し、他4箇所からは呼び出しを削除した |
| `evaluateFormulasAndRecalculate`内でtry-catchし例外をwarningログのみで握りつぶす | **不採用（例外伝播へ変更）** | Dexが「例外を握りつぶして成功扱いにしない」と明記。try-catchを削除し、`evaluator.evaluateAll()`の例外はそのまま呼び出し元へ伝播させ、評価不能な式があれば年度末出力自体を失敗させる構造にした |
| テストで`.gemini`配下の外部固定パスへExcelを書き出す（`testExportAllAndGenerateAuditFilesForP4`） | **不採用（削除）** | Dexが外部固定パスへの検証ファイル出力を明示的に禁止。テストは全面書き直し、出力は常にメモリ（ByteArrayOutputStream）に限定した |

## 2. 実装内容

対象: `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`、`src/test/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportServiceTest.java`

- `populateAnnual221`: `fiscalYear`引数を追加し、2-2-1の3シートすべてに正しい和暦年度を書込む。
- `populateForm23`: 下部自動書込セクション（K25:K28, T25:T28, AC25, K33, T33, AC33）を書込前に事前クリア。上部1〜23行は無変更。
- `populate25`: 参加者ありの行は無変更（クリア処理なし）。参加者なしの空き行だけ、`clearCellRangeValues`でcol1〜9を全消去してから既存の宿泊対象クリアと同じ結果になるよう統一。
- `populate26`: 占有・空き両ブロックとも、実際に書込む列(2,9,19,23,27,31)だけを新設の`clearColumnsAcrossRows`ヘルパーで3行分(r〜r+2)クリアしてから書込む。それ以外の列には一切触れない。
- `writeSplitTransportText`: 結合解除直後にN:S列(13-18)を値クリアしてから再結合する処理を追加。
- `evaluateFormulasAndRecalculate`: `buildAnnualClosingWorkbook`（年度末公式出力）のみから呼び出す。例外は握りつぶさず伝播させる。
- 新設ヘルパー: `clearCellRangeValues`（連続範囲の値クリア）、`clearColumnsAcrossRows`（指定列だけを複数行にわたって値クリア）。いずれも`cell.setBlank()`のみを呼び、`CellStyle`（罫線・背景色・フォント）は変更しない。

## 3. 実行コマンドと検証方法

### 3.1 静的確認

```
.\mvnw.cmd -q -DskipTests compile
```
成功。

```
grep -n "app.version" src/main/resources/application.properties target/classes/application.properties
```
両方 `v2.5.4` で一致。

```
git diff --stat -- src/main/resources/mapper/ src/main/resources/schema.sql "src/main/resources/*.xlsx"
```
無差分（DB/mapper/schema/原本xlsxは無変更）。

### 3.2 自動テスト

`src/test/java/.../ExcelExportServiceTest.java` を全面書き直し（外部固定パス書き出しを廃止し、メモリ上のみで検証）。

```
.\mvnw.cmd -q test
```

結果: `ExcelExportServiceTest` 2/2成功、`BudgetSystemApplicationTests` 1/1成功、失敗・エラー0件。

- `annualClosingBook_2026_writesFiscalYearAndClearsForm23Dummies`: 空projectIdsで2-2-1年度セル(H2/H3=8)、2-3のK33/T33/AC33クリア、上部不可侵エリア保持、数式エラー0件を確認。
- `annualClosingBook_realData_hasNoFormulaErrorsAndPreservesLegitimateValues`: 実DB全件で数式エラー0件、2-6の空きスロット主要列に残留値がないことを確認。

### 3.3 実ブラウザ・実HTTPでの年度末Excel実生成検証

MySQL稼働下でアプリを起動（ポート8091）し、`POST /export/year/download`で2026年度公式Excelを実際にダウンロード。openpyxl（`data_only=True`＝非再計算ビューア相当）でセル値を検証した。

| 検証項目 | 結果 |
|---|---|
| シート数 | **27**（期待どおり） |
| 2-4/2-5/2-6シート数 | 2-4: 5枚 / 2-5: 8枚 / 2-6: 8枚（期待どおり） |
| SHEET_22 H2 | 8.0（令和8年度） |
| SHEET_22_1_TOP H3 | 8.0 |
| SHEET_22_1_FURUSATO H3 | 8.0 |
| SHEET_23 K25/T25 | 0.0 / 303058.0 |
| SHEET_23 K26/T26 | 0.0 / 14510.0 |
| SHEET_23 K27,K28 | 空（None） |
| SHEET_23 AC25（訓練セクション総額） | **317568.0**（Dex回帰基準と完全一致） |
| SHEET_23 K33/T33 | **None/None**（原本ダミー値605,000/750,239が消去されたことを確認） |
| SHEET_23 AC33 | 0.0（2026年度はふるさと支援0件のため） |
| SHEET_23 上部行4（B列） | 変更なし（不可侵エリア保護確認） |
| 様式2-5 参加者名前数（8シート合計） | **44名**（Dex回帰基準と一致） |
| 様式2-6 費用あり人数（8シート合計） | **10名**（Dex回帰基準と一致） |
| 様式2-6 交通費合計 | **21,828円**（Dex回帰基準と一致） |
| 様式2-6 宿泊費合計 | **91,300円**（Dex回帰基準と一致） |
| ワークブック全体の値`936`残存件数 | **0件**（旧監査168件から完全に解消） |
| 数式エラー文字列（#REF!等）件数 | **0件** |

### 3.4 DB非更新の確認

- 生成前: projects=9件, is_printed=1の件数=0件, project_participants=46件, expenses=45件。
- 生成後（自動テスト実行後・年度末Excel実HTTP生成後の両方）: 上記すべて完全一致（変化なし）。読み取りのみで更新SQLは一切発行していない。

### 3.5 通常出力・legacy出力の疎通確認

- `POST /export/download`（exportType=all, 2-4/2-5/2-6まとめ）: 200 OK
- `POST /export/download`（exportType=2-2, 単体様式2-2）: 200 OK
- `GET /activity/export/year`（legacy旧年度まとめ）: 200 OK

いずれも今回の変更（evaluateFormulasAndRecalculate呼び出し削除、populate25/26のクリア範囲変更）後も正常に動作することを確認した。

## 4. 未解決の例外・既知の残課題

- `evaluateFormulasAndRecalculate`の`evaluator.evaluateAll()`は、今回の実データ（2026年度全件を含む年度末公式出力）を対象にした検証では例外を発生させなかった。将来、POIが評価できない数式（外部参照・複雑な配列式等）が原本テンプレートへ追加された場合、年度末出力そのものが例外で失敗する設計になっている点をDex/Kazumaxへ申し送りする。
- CCクルーCの指摘: 今回の2026年度実データには、正当なDB由来の値が偶然「936円」となるケースが存在しなかったため、「正当な936円は残り、空欄の936だけが消える」という区別が実データで検証できていない（値936の残存が0件という結果のみ確認）。次サイクル以降、936円相当のDB値を含むケースでの回帰確認を推奨する。

## 5. CCクルー3観点の補助レビュー結果

CCクルー利用: **必須**（Dex指示どおり実施）。

- **CCクルーA（金額・セル座標・正当値936保持担当）**: 「問題なし」。populate25/26のクリア範囲が書込列に限定されていること、populateForm23の不可侵エリア保護、2-2-1年度セル座標、long/double集計パターンの維持を確認。
- **CCクルーB（2-5/2-6の結合・空き行・書式/式の回帰担当）**: 「問題なし」。writeSplitTransportTextの結合解除→クリア→再結合の順序、populate25/26のクリア対象範囲、`setBlank()`がCellStyleを破壊しないことを確認。
- **CCクルーC（公式年度末の27シート・数式キャッシュ・DB非更新担当）**: 「問題なし」（軽微な指摘1件）。`evaluateFormulasAndRecalculate`の呼び出しが年度末公式出力1箇所に限定されていること、例外の非握りつぶし、DB書込みコードの不存在、compile/version同期を確認。指摘: 今回の実データでは正当な936円ケースを検証できていない点を次サイクルへの申し送りとして記録（本報告4章に反映済み）。

3クルーとも重大な指摘なし。採用/不採用判断: CCクルーCの指摘は「次サイクルで回帰確認を推奨」という残課題であり、Cycle 20の完了を妨げるものではないと判断し、本報告書に記録のうえ対応不要とした。

## 6. compile/version

```
app.version: src/main/resources/application.properties = v2.5.4
             target/classes/application.properties     = v2.5.4
```
同期確認済み。コード変更（ExcelExportService.java, テスト）を伴うためバージョンアップ実施。

## 7. commit / push

後述（本報告書保存後にcommit・push、hashを追記）。

## 8. 最終git status

Cycle 20対象外の差分（`.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/WORKFLOW_RULES.md`, `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`, 各種`docs/handoff/`・`docs/proposals/`の未追跡ファイル、Dex監査用`tmp/cycle19_xlsx_audit/`、本セッションの実機確認用`.claude/launch.json`）は他AI（Air/Dex）による既存差分・監査artifactと判断し、一切触れていない・commitに含めない。年度末Excel実検証で生成したファイル（`annual_2026.xlsx`等）はリポジトリ外の一時スクラッチ領域にのみ保存し、追跡対象にしていない。
