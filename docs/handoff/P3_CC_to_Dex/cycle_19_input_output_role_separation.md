[C19: CC(P3) ⇒ Dex(P4)]

# Cycle 19 入力・出力ページ役割分離 CC実装報告

## 1. 変更ファイル一覧

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/resources/templates/activity/list.html`
- `src/main/resources/templates/export/index.html`
- `src/main/resources/application.properties`（app.version=v2.5.1）

`ExcelExportService.java` / `ProjectMapper.xml` / `ProjectMapper.java` / `schema.sql` / `書類.xlsx` は一切変更なし（`git diff --stat` で無差分を確認済み）。

## 2. Air案に対するP2補正の実装結果

- **2.1 旧年度まとめの説明**: export/index.html の互換用リンクを「旧・簡易年度まとめ（2-2＋2-4〜2-6、2-1/2-2-1/2-3なし）」と正確な表記に変更。「2-2のみ」等の誤表現は使用していない。処理・URL(`/activity/export/year`)は削除せず維持。
- **2.2 旅行雑費固定禁止**: 2,200円等のハードコードは新規コードに追加していない（grep確認済み）。旅行雑費の入力・保存・合算処理は無変更。
- **2.3 年度末公式出力とprintedStatusの完全分離**: `ExportController.yearPreview()` / `yearDownload()` は `findFiltered(year, budgetTypeId, month, targetCategory, projectName, null)` のまま。export/index.html の「年度末決算ファイル出力へ進む」リンク、および list.html の `/export` 案内リンクは、いずれも year/budgetTypeId/month/targetCategory/projectName のみを渡し、printedStatus・checkboxのprojectIdsは渡していない。
- **2.4 印刷状態の意味**: Excel preview/download処理（`preview()`, `download()`, `yearPreview()`, `yearDownload()`）はいずれもDB更新を行わない。印刷状態更新は新設の `POST /export/bulk/status` のみで行い、SweetAlertで「実際に紙への物理印刷が完了していることを確認してから」の明示確認を経てから更新する。ダウンロードとの自動連動なし。

## 3. hidden/queryパラメータ表の確認結果

P2指示書 6章の表に沿って全導線を実装・確認。

| 導線 | 実装結果 |
|---|---|
| `/activity` GET再検索 | year/budgetTypeId/month/targetCategory/projectName/printedStatus すべて維持（既存のまま） |
| `/activity` 一括削除→戻り | `activityRedirectUrl()` で上記すべて維持（既存のまま、無変更） |
| `/activity`→`/export` | year/budgetTypeId/month/targetCategory/projectNameのみ付与。printedStatus非引き継ぎ |
| `/export` GET再検索 | 新設。year/budgetTypeId/month/targetCategory/projectName/printedStatusすべて維持 |
| `/export`通常preview/download | 既存どおりexportType, 明示選択projectIdsのみ。一覧にないIDの暗黙追加なし |
| `/export`印刷状態更新→戻り | `POST /export/bulk/status`（新設）。projectIds, isPrinted＋全GET条件をUriComponentsBuilderでエンコードして`/export`へリダイレクト。ダウンロードとの自動連動なし |
| `/export`→年度末setup | year/budgetTypeId/month/targetCategory/projectNameのみ。printedStatus, checkbox projectIds非引き継ぎ |
| 年度末setup→preview→download | 既存のまま無変更（printedStatusを含まない） |
| `/export`→旧年度まとめ | year/budgetTypeId/month/targetCategory/projectNameのみ。printedStatus非引き継ぎ |

すべてThymeleaf `th:href`（URL式）または `UriComponentsBuilder` を使用。手書き文字列連結は使用していない。

## 4. 12の必須受入確認＋P2追加ケースの結果

Kazumax本物DBに対する起動確認（コンパイル成功・静的確認）を実施。**実機ブラウザでの全項目操作確認（DB書き込みを伴う印刷状態テストを含む）はCC本体では未実施**。理由: 本物DBへの接続・操作は破壊的変更のリスクを伴うため、Kazumaxの立ち会いまたは明示許可のもとでの実機確認を推奨する（後述9章参照）。以下はコード静的確認・CCクルーレビューによる結果。

1. `/activity` 初期表示: `printedStatusDefaulted` 時 `effectivePrintedStatus="all"` に変更済み（コード確認OK、実機要確認）
2. `/activity` 基本機能: 新規/編集/複製/削除/検索コードは無変更（差分なし確認OK）
3. 個人雑費: 画面注記のみ削除（list.html該当箇所削除確認）、DB値・hidden・様式2-6出力ロジックは無変更（差分なし確認）
4. `/export` フィルタ: unprinted/printed/allの3値をGETで切替可能な実装（コードOK、実機要確認）
5. `/export` 王道設計: 年度末決算ブロックを最上部に配置し、旧簡易出力は下部に別枠配置（実装OK、実機要確認）
6. 年度末Excel収録: `yearPreview/yearDownload`のロジック・ExcelExportService呼び出しは無変更（差分なしのため従来どおり2-1〜2-6収録のはず、実機/Excel回帰は未実施・要Dex/Kazumax確認）
7. 自動印刷済み無効化: preview/download系メソッドにDB更新コードなし（コード確認OK）
8. 手動更新: `/export/bulk/status`はSweetAlert明示確認後のみJSが送信（コードOK、実機要確認）
9. 巻き戻し: 「未印刷に戻す」ボタン実装済み（コードOK、実機要確認）
10. 条件引き継ぎ: 3章の表どおり実装（コードOK、実機要確認）
11. 金額・件数一致: ExcelExportService/mapper無変更のため計算結果自体は不変のはず。**変更前後のExcel実出力比較はCC本体で未実施**（要Dex/Kazumax確認、9章参照）
12. DBデータ保全: 本物DBへの書き込みテストはCC本体では実施していない（未実施のため破壊リスクなし）

## 5. CCクルー3観点の補助レビュー結果

CCクルー利用: **必須**（Dex指示どおり実施）。

- **CCクルーA（条件・金額・Excel担当）**: 「問題なし」。パラメータ導線、`yearPreview/yearDownload`の`findFiltered(...,null)`維持、ExcelExportService/mapper/schema無差分、2,200円ハードコード非混入をすべて確認。補足として`/activity/bulk/status`が呼び出し元なしで残存している点を指摘（P2指示書どおり互換維持のため意図的残置であり、対応不要と判断）。
- **CCクルーB（UI・フォーム・スマホ担当）**: 「問題なし」。form入れ子なし、name/value整合、SweetAlert物理印刷確認文・未印刷復帰・未選択ガードあり、削除ボタンの`ms-auto`右寄せ確認、年度末リンクへのprintedStatus/projectIds非混入を確認。
- **CCクルーC（回帰・データ保全担当）**: 「問題なし」。git status上のCycle19対象外差分はドキュメント系のみ（他AI差分と判断・不干渉）、個人雑費/旅行雑費diff皆無、legacy URL(`/activity/export/year`, `/export/preview`, `/export/download`)無変更、compile再実行成功を確認。

3クルーとも重大な指摘なし。採用/不採用判断: 指摘なしのため対応事項なし。

## 6. 変更前baselineと変更後の件数・金額・参加人数・Excel比較

**未実施**。本物DBに対する実機確認・Excel回帰比較はCC本体では行っていない。理由は5章・9章参照。Dex(P4)またはKazumaxによる実施を要請する。

## 7. 印刷状態テスト対象と復元結果

**未実施**（本物DBへの書き込みテストを行っていないため、復元対象自体が発生していない）。

## 8. compile/versionとtarget同期

```
.\mvnw.cmd -q -DskipTests compile
```
成功（エラーなし）。CCクルーCによる再実行でも成功を確認。

```
app.version: src/main/resources/application.properties = v2.5.1
             target/classes/application.properties     = v2.5.1
```
同期確認済み。

## 9. 残課題・Dex/Kazumaxへの申し送り

- **必須確認レベル: 必須確認**。理由: 印刷状態のDB更新、年度末公式Excelの対象件数・金額という「金額・Excel・公式提出書類」に該当するため。
- CC本体では本物DBへの接続・書き込みを伴う実機確認（12の必須受入確認のうち多くの項目）を実施していない。静的確認・コンパイル・CCクルーによるコードレビューのみで完了させている。
- Dex(P4)のDIFFレビューに加え、Kazumaxまたは許可を得たAIによる以下の実機確認を推奨する:
  - `/activity` 初期表示ですべて（印刷済み含む）が表示されること
  - `/export` の3種類の印刷ステータスフィルタ動作
  - 印刷済み更新→未印刷に戻す操作が対象IDのみに作用し、他データに影響しないこと（テスト後は元の状態に復元）
  - 年度末Excel出力の件数・2-2/2-2-1合計・シート数が変更前と一致すること
- `5.2` 節（P2指示書）の残課題: 通常出力preview/download未選択時のエラー戻り先は、既存動作（フィルタ条件を付けずに`/export?error=no_selection`へ戻る）のまま変更していない。P2指示書の許可事項どおり、既存動作維持を優先した。

## 10. commit / push

commit hash: `466ad9d`（`[v2.5.1] Cycle 19: 入力・出力ページの役割分離と印刷状態導線整理`）。origin/mainへpush済み（616f13e→466ad9d）。

## 11. 最終 git status

commit前の状態は本ファイル保存時点の `git status --short --untracked-files=all` を参照。Cycle19対象外の差分（`.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/WORKFLOW_RULES.md`, `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`, 各種 `docs/handoff/`・`docs/proposals/` の未追跡ファイル）は他AI（Air/Dex）による既存差分と判断し、一切触れていない・commitに含めない。
