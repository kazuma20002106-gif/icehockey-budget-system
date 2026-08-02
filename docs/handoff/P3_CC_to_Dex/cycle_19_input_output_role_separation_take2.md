[C19: CC(P3) Take2 ⇒ Dex(P4)]

# Cycle 19 入力・出力ページ役割分離 CC実装報告 Take2

## 1. 差し戻し内容（Finding P1）と修正diff

Dex(P4)差し戻し（`docs/handoff/P4_Rollback/cycle_19_input_output_role_separation.md`）: 通常プレビュー(`/export/preview`)から「一覧に戻る」で year/budgetTypeId/month/targetCategory/projectName/printedStatus の6条件が失われる。

### 修正内容

- `ExportController.preview(...)`: 上記6条件を任意`@RequestParam`として追加し受け取り、`backYear`/`backBudgetTypeId`/`backMonth`/`backTargetCategory`/`backProjectName`/`backPrintedStatus`としてmodelへ渡す。projectIds未選択時も新たに `exportRedirectUrl(...)` を使い、6条件を維持したまま `/export?error=no_selection` へ戻すよう変更（従来は固定文字列 `"redirect:/export?error=no_selection"` だった）。
- `export/preview.html`: 「一覧に戻る」リンクを固定`href="/export"`からThymeleaf URL式 `th:href="@{/export(year=${backYear}, budgetTypeId=${backBudgetTypeId}, month=${backMonth}, targetCategory=${backTargetCategory}, projectName=${backProjectName}, printedStatus=${backPrintedStatus})}"` へ変更。
- `export/index.html`: `exportForm`（`/export/preview`・`/export/download`共用）に6条件のhidden inputを追加（`th:value="${selectedYear}"`等、`/export` GET一覧表示時のmodel属性をそのまま埋め込み）。

## 2. 6条件のpreview往復確認

コード上の確認結果（CCクルーAによる静的確認）:

- `/export?year=2026&month=6&budgetTypeId=1&targetCategory=成年男子&projectName=強化練習&printedStatus=printed` で表示された `export/index.html` のhiddenに上記6値が埋め込まれる。
- 通常出力formから `/export/preview` へPOSTすると、`ExportController.preview()` がこれらをそのまま受け取り `backXxx` としてmodelへ渡す。
- `export/preview.html` の「一覧に戻る」がその6値を使って `/export` へURLエンコード付きで復元する。

**実機ブラウザでの実操作確認は未実施**（後述9章参照、Take2でも本物DBへの書込みを伴わない範囲での実機確認は可能だが、今回はコード静的確認とCCクルーレビューに留めた）。

## 3. 日本語URL確認

`th:href="@{...}"` のThymeleaf URL式を使用しており、`targetCategory`/`projectName`の日本語値は自動的にパーセントエンコードされる。手書き文字列連結は使用していない（CCクルーB確認済み）。

## 4. 未選択時確認

`preview()`が`projectIds`空の場合、`exportRedirectUrl(year, budgetTypeId, month, targetCategory, projectName, printedStatus, "no_selection")`で6条件＋`error=no_selection`を付けて`/export`へ戻る（従来の固定文字列リダイレクトから変更）。DB更新は発生しない。

## 5. download時の状態不変確認

`download()`メソッド自体は今回のdiff対象外（無変更）。印刷状態(`is_printed`)を更新する処理は元から存在せず、Take2でも追加していない（CCクルーA確認済み）。

## 6. CCクルー結果（Take2でも必須）

- **CCクルーA（条件・金額・Excel担当）**: 「問題なし」。6条件のpreview往復実装、`yearPreview()`/`yearDownload()`の`findFiltered(...,null)`無変更、ExcelExportService/mapper/schema無差分、2-2集計ロジック無変更、download()の印刷状態自動更新なしを確認。
- **CCクルーB（UI・HTMLフォーム構造担当）**: 「問題なし」。hidden inputのname属性と`@RequestParam`名の完全一致、nested formなし、preview.htmlのth:href構文とmodel属性名の一致、日本語URLエンコード、bulkPrintStatus/SweetAlertへの影響なしを確認。
- **CCクルーC（回帰・不可触領域差分担当）**: 「問題なし」。変更ファイルがTake2対象範囲内に限定、個人雑費/旅行雑費への差分なし、legacy URL・年度末エンドポイント・`/export/bulk/status`は無変更、compile成功、app.version=v2.5.2のsrc/target同期を確認。

3クルーとも重大な指摘なし。採用/不採用判断: 対応事項なし。

## 7. compile/version

```
.\mvnw.cmd -q -DskipTests compile
```
成功（エラーなし）。CCクルーCによる再実行でも成功確認。

```
app.version: src/main/resources/application.properties = v2.5.2
             target/classes/application.properties     = v2.5.2
```
同期確認済み。

## 8. 静的確認

```
git diff --stat -- src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java src/main/resources/mapper/ src/main/resources/schema.sql
```
無差分。

```
grep -rn "2200|2,200" src/main/java src/main/resources/templates
```
該当なし。

## 9. 未実施のDB書込み・実機検証の扱い

P4差し戻し文書9章の指示どおり、Kazumaxの明示許可を得ていないため、Take2でも本物DBへの書込みを伴う実機確認（印刷状態の実操作、年度末Excel実出力比較）は実施していない。静的・非書込み検証（コンパイル、diff、CCクルーレビュー）までに留めた。Take2がP4 OKとなった場合、以下をKazumax必須確認として依頼したい。

1. `/export?year=...&printedStatus=printed`等で絞り込み後、通常previewへ進み「一覧に戻る」で6条件が完全復元されること
2. `printedStatus=unprinted|printed|all`いずれもpreview往復後に維持されること
3. 日本語targetCategory/projectNameを含めても文字化けしないこと
4. 印刷状態の実操作（対象1件のみ変化・復元）
5. 年度末Excelのシート数・2-2/2-2-1合計・2-4/2-5/2-6枚数が変更前と一致すること

## 10. commit / push

このTake2報告書保存後、Take2対象ファイル（ExportController.java, export/index.html, export/preview.html, application.properties, CURRENT_STATUS.md, 本報告書）のみをstageしてcommit・push予定（コミットメッセージ先頭 `[v2.5.2]`）。

## 11. 最終git status

Cycle19 Take2対象外の差分（`.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/WORKFLOW_RULES.md`, `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`, および各種`docs/handoff/`・`docs/proposals/`の未追跡ファイル）は他AI（Air/Dex）による既存差分と判断し、一切触れていない・commitに含めない。
