[C12C: Dex(P4) => CC(P3) Take2]

# Cycle 12C 年度末出力UI・タブプレビュー P4レビュー結果

## 判定

**NG / CC Take2差戻し**

理由: 年度末決算ファイルは「対象事業が変わる = 金額が変わる」ため、プレビュー画面の導線で絞り込み条件が落ちる不具合はP1扱いです。

---

## Finding P1: 入力画面POSTで `month` / `projectName` が落ち、対象事業が広がる

### 該当箇所

- `src/main/resources/templates/activity/list.html:82-83`
- `src/main/resources/templates/export/year_setup.html:15-47`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java:185-199`

### 内容

活動一覧から年度末決算ファイル出力へ進むリンクは、以下の条件を渡しています。

- `year`
- `budgetTypeId`
- `month`
- `targetCategory`
- `projectName`

しかし、`year_setup.html` のフォームには `year` / `budgetTypeId` / `targetCategory` しか存在せず、`month` と `projectName` を次の `POST /export/year/preview` に渡していません。

Controller側の `yearPreview` / `yearDownload` は `month` と `projectName` を受け取る設計になっており、`projectMapper.findFiltered(year, budgetTypeId, month, targetCategory, projectName)` で対象事業を決めています。つまり、フォームで条件が落ちると、プレビュー対象とExcel出力対象がユーザーの選択より広がる可能性があります。

### 何が危険か

中学生向けに言うと、Kazumaxが「5月の成年男子だけで書類を作って」と選んだつもりでも、画面の途中で「5月」や「事業名」の条件が消えて、年度全体や別の事業まで混ざる可能性があります。

これは見た目の問題ではなく、年度末決算ファイルの金額そのものが変わり得る問題です。

### 修正指示

`year_setup.html` のフォームに、少なくとも以下を追加してください。

- `month`
- `projectName`

実装方法はどちらでも可です。

1. 画面上で編集できる検索項目として表示する
2. 活動一覧から渡された値を hidden input として保持する

ただし、ユーザーが「通常の活動一覧と同じ条件」と理解できる導線にしてください。表示しない場合でも、条件が保持されていることを画面上に短く表示するのが望ましいです。

---

## Finding P2: 「条件を編集」リンクで絞り込み条件と提出情報が落ちる

### 該当箇所

- `src/main/resources/templates/export/year_preview.html:8`

### 内容

プレビュー画面の「条件を編集」は `year` だけを渡しています。

そのため、プレビューまで進んだ後に戻ると、`budgetTypeId` / `month` / `targetCategory` / `projectName` と提出日・団体名・代表者が初期値に戻ります。

これは直接ダウンロード時の金額破壊ではありませんが、ユーザーが修正して再プレビューすると条件がズレるため、P1の修正と一緒に直してください。

### 修正指示

`year_preview.html` の「条件を編集」は、少なくとも絞り込み条件を保持してください。

- `year`
- `budgetTypeId`
- `month`
- `targetCategory`
- `projectName`

提出情報も可能なら保持してください。GETで長くなるのを避けたい場合は、編集用フォームをPOSTにする、またはsetup側でパラメータを受けられるようにする形でも構いません。

---

## Finding P3: まとめ(2-2)の全体合計行で列数が1列不足

### 該当箇所

- `src/main/resources/templates/export/year_preview.html:86-89`

### 内容

ヘッダーは10列ありますが、全体合計行は以下の構成です。

- 1列目: 全体合計
- `colspan="7"`
- 最後の合計列

合計9列になっており、1列不足しています。`colspan="8"` が自然です。

金額計算には影響しませんが、表の見た目がずれる可能性があります。

---

## 良かった点 / OK確認

- プレビューとExcel出力が `buildAnnualClosingWorkbook` を共通で通る設計は、P2指示の「UI専用の再計算を作らない」に沿っています。
- `/activity/export/annual` 既存ルートは残されており、従来出力の入口は壊していません。
- `budget_allocations` の仕様変更、mapper変更、DBスキーマ変更、原本Excelテンプレート本体の変更は12C範囲では確認していません。
- `/api/export/preview-yearly` 未実装は、P2指示でSSR優先を許容していたため問題なしです。

---

## CC Take2で必ず確認してほしいこと

1. 活動一覧で `month` と `projectName` を指定して「年度末決算ファイル出力」へ進む
2. setup画面からプレビューへ進む
3. `POST /export/year/preview` に `month` と `projectName` が渡っていることを確認する
4. プレビュー画面のhidden inputにも同じ値が保持されることを確認する
5. ダウンロード時の `POST /export/year/download` にも同じ値が渡ることを確認する
6. 「条件を編集」で戻ったとき、少なくとも絞り込み条件が消えないことを確認する
7. `.\mvnw.cmd -q -DskipTests compile` と `target/classes/application.properties` の `app.version=v2.4.2` を確認する

---

## Dex検証メモ

- 今回はP1ブロッカーを静的レビューで確認したため、実機ダウンロード検証には進んでいません。
- ブロッカー解消後、プレビュー画面とダウンロードPOSTの条件一致を重点的に再レビューします。

