# [C5: CC(P3) => Dex(P4)]

## ステータス
- CC(P3) 実装完了
- Dex(P4) DIFFレビュー待ち

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `src/main/java/.../service/ExcelExportService.java` | 令和変換helper追加、図形クリア、2-4/2-5/2-6全面修正、相方自動連行 |
| `src/main/java/.../mapper/ProjectMapper.java` | `findFiltered`にmonth引数追加、`findByFiscalYearOrdered`追加 |
| `src/main/resources/mapper/ProjectMapper.xml` | findFiltered月フィルター追加、findByFiscalYearOrdered SQL追加 |
| `src/main/java/.../controller/ActivityController.java` | list/exportYearにmonthパラメータ追加 |
| `src/main/java/.../controller/ExportController.java` | downloadに`all`ケース追加 |
| `src/main/resources/templates/activity/list.html` | 月別フィルター追加、出力ドロップダウン→POST preview導線変更 |
| `src/main/resources/templates/export/preview.html` | `all`タイプをpreview条件に追加 |
| `src/main/resources/templates/users/form.html` | 電話番号placeholder/ヘルプテキスト/JS自動ハイフン化追加 |
| `src/main/resources/static/css/style.css` | `select.form-select { padding-right: 2.75rem }` 追加 |
| `src/main/resources/application.properties` | app.version=v1.8.10 |

## 実装内容の要約

Cycle5の全8タスクを実装。

## 1. プレビュー導線の変更内容

**対象: `activity/list.html`**

「出力」ドロップダウンの各項目を `GET /activity/{id}/export` の直接ダウンロードから `POST /export/preview` へ変更。

- まとめて（2-4〜2-6）: exportType=`all`
- 様式2-4のみ: exportType=`2-4`
- 様式2-5のみ: exportType=`2-5`
- 様式2-6のみ: exportType=`2-6`

各項目は `<form method="post" action="/export/preview">` + `<button type="submit">` で実装。

`ExportController.download()` に `all` ケース追加 → `excelExportService.exportAllFormsForProjects()` を呼ぶ。

`export/preview.html` の表示条件に `exportType == 'all'` を追加し、2-4/2-5と同様のpreview表示を流用。

## 2. Excel各様式の修正内容と確認したセル座標

### テンプレート確認済みセル座標一覧

| 様式 | 項目名 | row (0-based) | col (0-based) | 表示例 |
|---|---|---|---|---|
| 2-4 | 年度見出し | 1 | 0 | 令和7年度　国スポ... |
| 2-4 | 期日（左） | 14 | 3 | 令和7年5月24日(土) |
| 2-4 | 期日（右） | 14 | 20 | 令和7年6月14日(土) |
| 2-4 | 合計（左） | 33 | 3 | 計: 84050 |
| 2-4 | 合計（右） | 33 | 20 | 計: 103290 |
| 2-4 | 記入責任者 | 46 | 0 | 記入責任者氏名（...） |
| 2-5 | 年度数値 | 2 | 2 | 7 |
| 2-5 | 事業実施日 | 5 | 2 | 令和7年5月24日 |
| 2-5 | 宿泊日ヘッダー | 7 | 7 | 5月24日 |
| 2-5 | 記入責任者 | 36 | 0 | 記入責任者氏名（...） |
| 2-6 | 年度数値 | 2 | 9 | 7 |
| 2-6 | 作成者名 | 6 | 28 | 作成者名（　名前　） |
| 2-6 | 交通費合計 | 39 | 19 | 61700 |
| 2-6 | 宿泊費合計 | 39 | 23 | 0 |
| 2-6 | 雑費合計 | 39 | 27 | 0 |
| 2-6 | 旅費合計 | 39 | 37 | 61700 |
| 2-6 | 記入責任者氏名 | 40 | 0 | 記入責任者氏名(...) |
| 2-6 | 記入責任者電話 | 40 | 27 | 電話番号(...) |
| 2-2 | 年度数値 | 1 | 7 | 7 |

## 3. 令和変換・日付フォーマット helper の仕様

```java
private int getReiwaYear(int year) { return year - 2018; }

private String formatJapaneseDate(LocalDate date) {
    // → "令和7年5月24日"
}

private String formatJapaneseDateWithWeekday(LocalDate date) {
    // → "令和7年5月24日(土)"
    // getDayOfWeek().getValue() % 7 で日〜土対応
}

private String formatMonthDay(LocalDate date) {
    // → "5/24"
}
```

- 年度は `project.getFiscalYear()` 優先、null の場合は `eventDate.getYear()` から計算
- date が null の場合は全て空文字を返す

## 4. 様式2-4の相方自動連行システムの判定方法

`exportForm24(projectIds.size() == 1)` の場合のみ適用。

1. `projectMapper.findByFiscalYearOrdered(fiscalYear)` で年度内活動を日付昇順・ID昇順で取得
2. 対象活動の1-based位置 `position` を計算
3. `position % 2 == 1`（奇数）→ 左側に対象、右側をクリア
4. `position % 2 == 0`（偶数）→ 右側に対象、左側に `position-2` インデックスの前活動

複数ID選択時は従来の順次ペアリングを維持。

**注意点:** テンプレートの右側に残るダミーデータを`clearSide24(sheet, 17)`で明示的にクリア。図形は`clearExistingShapes()`でCTDrawingのTwoCellAnchor/OneCellAnchorを全削除してから新規描画。

## 5. 月別フィルターの仕様

- query param: `month`（実月の数値、例: 4月=4）
- `ProjectMapper.findFiltered()` に `@Param("month") Integer month` を追加
- XML: `<if test="month != null">AND MONTH(event_date) = #{month}</if>`
- `ActivityController.list()` と `exportYear()` の両方で受け取り
- 年度まとめExcel出力リンクにも `month=${selectedMonth}` を渡し、一覧と出力対象を一致させた

## 6. `.\mvnw compile` の結果

```
[INFO] BUILD SUCCESS
```

## 7. バージョン確認結果

- `src/main/resources/application.properties`: `app.version=v1.8.10` ✓
- `target/classes/application.properties`: `app.version=v1.8.10` ✓

## 8. コミットハッシュ

`71c4885` - [v1.8.10] Cycle5: プレビュー導線/令和表記/2-4/2-5/2-6修正/電話番号/月別フィルター

## 9. `git push origin main` の実行結果

```
To https://github.com/kazuma20002106-gif/icehockey-budget-system.git
   8105ede..71c4885  main -> main
```

## Dex(P4) に確認してほしい観点

1. **様式2-4の既存図形クリア**: `CTDrawing.removeTwoCellAnchor(0)` / `removeOneCellAnchor(0)` で削除。テンプレートの黒丸が実際に消えているか実機確認を。
2. **clearSide24()の範囲**: 右側クリア対象セルを主要なものに絞っているが、テンプレートに他のダミーデータが残っていないか確認を。
3. **様式2-5の宿泊日ヘッダー**: `eventDate`（活動日）を宿泊日として使用。実際の宿泊日と異なるケースがあれば要確認。
4. **様式2-6の雑費合計**: 雑費は画面「-」表示のため合計セル(39,27)に0を書き込んでいる。旅費合計(39,37)にはDBの`miscellaneousCost`も含めている（transport + accommodation + misc）。
5. **電話番号自動ハイフン**: 宮崎の市外局番(0985系)に対応した4桁判定ロジック。他の地域で正しく動作するか確認を。
