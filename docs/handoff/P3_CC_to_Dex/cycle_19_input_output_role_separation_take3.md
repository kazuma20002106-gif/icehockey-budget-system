[C19: CC(P3) Take3 ⇒ Dex(P4)]

# Cycle 19 入力・出力ページ役割分離 CC実装報告 Take3

## 1. 差し戻し内容（Take2実機再監査NG）と修正内容

Dex(P4 Take2再監査)差し戻し（`docs/handoff/P4_Rollback/cycle_19_input_output_role_separation_take2.md`）:

- `export/index.html`の操作用`<script>`（`toggleAll`/`bulkPrintStatus`/`submitDynamicForm`等）が、`th:replace="~{layout :: html(..., content=~{::div}, ...)}"`が取り込む唯一の`<div>`の外側に置かれており、レイアウト展開後のHTMLから丸ごと欠落。ブラウザで`ReferenceError: toggleAll is not defined`等が発生し、一括選択・印刷状態ボタンが機能していなかった。
- 「旧・簡易年度まとめ」カードは公式年度末出力と紛らわしく、利用者に無反応に見えるため画面から削除。

### 修正内容

- `export/index.html`: ページ本文用の唯一の`<div>`（`content=~{::div}`が抽出する範囲）を、ファイル内で最初に開く`<div>`から`</body>`直前まで一貫させ、その内側に`<style>`・本文コンテンツ・`<script>`のすべてを収める構造へ変更した。具体的には、`<style>`をルート`<div>`の直後（開いたまま）へ移動し、`<script>`をルート`<div>`が閉じる直前へ移動、最後にルート`<div>`を閉じる`</div>`を追加した。
- 「互換用の簡易出力（旧・簡易年度まとめ）」カードを画面から削除した。
- `/activity/export/year`のURL・`ActivityController.exportYear()`・Excel処理（`exportYearlySummary`）は一切変更していない（`git diff -- src/main/java`で無差分確認済み）。

## 2. 実ブラウザでの必須検証結果（compileだけで完了にせず実施）

MySQL（既存ローカルDB）を使用し、`mvnw.cmd spring-boot:run`をポート8091で起動して実機確認した（本物DBへの書込みは発生させていない）。

| No. | 確認項目 | 結果 |
|---|---|---|
| 1 | `/export?year=2026&printedStatus=all`で親チェックOFF→子が0件になる | OK（`selectAllChecked=false, checkedCount=0, totalCount=8`をJSで確認） |
| 2 | 親チェックONに戻すと表示中の子が全件ONになる | OK（`checkedCount=8`） |
| 3 | 1件以上選択して「印刷済みにする」でSweetAlert確認ダイアログが開く | OK（`選択した 8 件を印刷済みにしますか？`／物理印刷確認文を確認） |
| 4 | ダイアログの「キャンセル」でPOSTされず、DBも変わらない | OK（キャンセルクリック後、ネットワークログにPOST発生なし。ダイアログは閉じるアニメーション状態(`swal2-backdrop-hide`)に遷移のみ） |
| 5 | 対象0件でボタンを押すと「選択されていません」が出る | OK（`選択されていません／対象の活動を1件以上選択してください。`） |
| 6 | 旧・簡易年度まとめのカードが画面にない | OK（`get_page_text`全文に該当要素なし） |
| 7 | legacy URLへ直接アクセスすれば従来どおりExcelを取得できる | OK（`/activity/export/year?year=2026`→200、`content-type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`、`filename*=UTF-8''2026年度_まとめ.xlsx`） |
| 8 | 6条件を付けてpreviewへ進み、「一覧に戻る」で6条件が復元される | OK。`/export?year=2026&budgetTypeId=1&month=6&targetCategory=成年男子&projectName=強化練習&printedStatus=all`（4件: ID 25,23,22,10、Dex実測例と一致）→プレビュー→「一覧に戻る」リンクのhrefに6条件を確認→実際にクリックし同じ4件・同じ検索条件が復元されることを確認 |
| 9 | 日本語のtargetCategory/projectNameがpercent-encodeされる | OK（`targetCategory=%E6%88%90%E5%B9%B4%E7%94%B7%E5%AD%90`＝成年男子、`projectName=%E5%BC%B7%E5%8C%96%E7%B7%B4%E7%BF%92`＝強化練習） |
| 10 | ブラウザコンソールに`ReferenceError`がない | OK（`read_console_messages`常時「No console logs.」／エラーなし） |

上記いずれも実際のDB印刷状態は変更していない（4のキャンセル確認のみを実施し、確認ボタンでの実POSTは行っていない）。

## 3. CCクルー3観点の補助レビュー結果

- **CCクルーA（Thymeleafレイアウト取込・JS到達確認担当）**: 「問題なし」。修正後の`<div>`が`<style>`・本文・`<script>`をすべて内包しファイル末尾直前まで続くこと、div開閉タグ数の一致（26/26）、`toggleAll`等4関数と`EXPORT_CURRENT_FILTERS`が取込範囲内にあることを確認。
- **CCクルーB（UI画面構造・legacy導線担当）**: 「問題なし」。旧簡易出力カードの完全削除、`ActivityController.java`無差分によるlegacy処理の維持、年度末公式出力ブロック等の他要素が無傷であることを確認。
- **CCクルーC（回帰・不可触領域差分担当）**: 「問題なし」。変更が`export/index.html`と`application.properties`のみに限定され、Javaコード・ExcelExportService・mapper・schemaに無差分、compile成功、app.version=v2.5.3のsrc/target一致を確認。なお`git status`上のドキュメント/manuals差分および`tmp/cycle19_xlsx_audit/`はDex監査由来の既存差分と判断し対象外とした。

3クルーとも重大な指摘なし。採用/不採用判断: 対応事項なし。

## 4. 静的確認

```
git diff --stat -- src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java src/main/resources/mapper/ src/main/resources/schema.sql
```
無差分。

```
git diff -- src/main/java
```
無差分（Take3はテンプレートとapplication.propertiesのみの変更）。

## 5. compile/version

```
.\mvnw.cmd -q -DskipTests compile
```
成功。

```
app.version: src/main/resources/application.properties = v2.5.3
             target/classes/application.properties     = v2.5.3
```
同期確認済み。

## 6. 未実施のDB書込みテストの扱い

Kazumaxの明示許可がないため、印刷状態の実POST（確認ダイアログで「はい」を押してDBを実際に更新する操作）はTake3でも実施していない。ダイアログ表示とキャンセル時の非送信までを実機確認した。Take3がP4 OKとなった場合、対象1件のみの変化・復元をKazumax確認として依頼したい。

## 7. compile/version と commit

commit hash: 後述（本報告書保存後にcommit・push）。

## 8. 最終git status

Take3対象外の差分（`.cursorrules`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `docs/handoff/WORKFLOW_RULES.md`, `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`, 各種`docs/handoff/`・`docs/proposals/`の未追跡ファイル、Dex監査用`tmp/cycle19_xlsx_audit/`）は他AI（Air/Dex）による既存差分・監査artifactと判断し、一切触れていない・commitに含めない。`.claude/launch.json`（本セッションでの実機確認用dev server設定、budget-system直下・親フォルダ直下とも）もcommit対象に含めない。
