[C12B: Dex(P4) => Kazumax / CC(P3)]

# Cycle 12B Take2 予算管理・様式2-3連動 P4再レビュー

## 判定

**OK / 12B完了**

Cycle 12B Take2はP4 OKです。12B（予算管理・様式2-3連動）は完了とし、12C（年度末出力UI・大容量プレビュー）へ進んでよいです。

## Finding P1の再判定

前回Dexが「原本B列に `成年男子セイネンダンシ` のようなふりがなが混ざるため完全一致では一致しない」と判断した点は、**Dex側の確認方法が誤っていました**。

Dexの前回確認は、OOXMLの `sharedStrings.xml` 内にある `<rPh>`（ふりがな/ルビ）要素まで文字列本体として拾っていました。しかし、実際にアプリが使うApache POIの `getStringCellValue()` では、`<rPh>` は文字列本体として返りません。

Dex側でもPOIで再確認した結果:

```text
B25=[成年男子] len=4
B26=[成年女子] len=4
B27=[少年男子] len=4
B28=[少年女子] len=4
B30=[例）少年男子] len=6
B31=[例）少年女子] len=6
B33=[成年男子] len=4
```

したがって、Take1時点の完全一致実装でも現原本では一致していました。CCの反論は正当です。

Take2ではさらに、完全一致を優先しつつ、完全一致が見つからない場合のみ `contains` でフォールバックする実装になっています。これは現原本を壊さず、将来の表記揺れにも少し強くなるため妥当です。

## 確認結果

### 行検索

`src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java` の `findCategoryRow` を確認しました。

- `例）` / `例)` 行は除外される
- 完全一致が最優先される
- 完全一致がない場合のみ部分一致フォールバックされる
- 見つからない場合は `-1` を返し、上位で例外停止する

この構成で、トップチーム例示行を誤って拾うリスクは抑えられています。

### 一時ファイル整理

前回Finding P2で明示した一時ファイルは整理済みです。

- `.claude/launch.json`: 削除され、`docs/proposals/CC_cycle_12b_dev_launch_config.md` へ提案として切り出し
- `analysis_2_3.csv`
- `analysis_formulas.txt`
- `analysis_formulas_utf8.txt`
- `temp_hokusho.xlsx`
- `費用書類_temp.xlsx`

`sheets_preview.txt` / `sheets_preview_utf8.txt` は未追跡で残っていますが、前回Finding P2で列挙した12B由来ファイルではなく、12B以前の解析artifactと見られます。12B本体のOKを止めるブロッカーにはしません。

### ビルド・バージョン

Dex側でも以下を実行し、成功しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

`src/main/resources/application.properties` と `target/classes/application.properties` の `app.version` はどちらも `v2.4.1` で一致しています。

## Kazumax向け短縮チェック

- [x] budget_allocations追加は破壊的DDLなし
- [x] 内示額は `BIGINT` / Java `Long` 系で扱う
- [x] 保存処理は負数・不正値を保存前に止める
- [x] 様式2-3はK/T/ACの対象列だけを使う
- [x] B列検索はPOI実測上の文字列で一致する
- [x] トップチーム例示行は自動書込対象外
- [x] 12Bの一時ファイル混入は解消
- [x] compile成功
- [x] app.version同期確認済み

## 次の担当

**CC(P3)**:

12BはP4 OKです。次は12Cへ進んでください。

最優先で次を読んでください。

`docs/handoff/P2_Dex_to_CC/cycle_12c_preview_ui_instructions.md`

12C完了後は、次へ報告してください。

`docs/handoff/P3_CC_to_Dex/cycle_12c_preview_ui.md`
