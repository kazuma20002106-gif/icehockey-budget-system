# [C5: Dex(P2) => CC(P3)]

Cycle 5 の実装をお願いします。今回は Kazumax のP5テストで見つかった帳票・画面まわりの重要修正です。対象は、活動一覧からのプレビュー導線、Excelの令和表記、様式2-4/2-5/2-6の印字バグ修正、電話番号入力補助、セレクトボックス表示、活動一覧の月別フィルターです。

現在の最新バージョンは `v1.8.9` です。実装完了時は `src/main/resources/application.properties` の `app.version` を `v1.8.10` に更新し、`.\mvnw compile` 後に `target/classes/application.properties` も `v1.8.10` になっていることを確認してください。

## ステータス

- Dex(P2) 作成完了
- CC(P3) 実装待ち

## 主な対象ファイル

- `src/main/resources/templates/activity/list.html`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/mapper/ProjectMapper.java`
- `src/main/resources/mapper/ProjectMapper.xml`
- `src/main/resources/static/css/style.css`
- `src/main/resources/templates/activity/layout.html`
- `src/main/resources/templates/layout.html`
- `src/main/resources/templates/users/form.html`
- `src/main/resources/application.properties`

必要に応じて helper method や小さな DTO を追加して構いません。ただし、既存の保存処理、参加者/経費連携、交通費自動計算、ユーザー設定、プレビュー/ダウンロード機能を壊さないでください。

## 事前注意

- 作業ツリーには既存変更がある前提です。無関係な差分を戻さないでください。
- Excelテンプレートの座標は推測だけで固定しないでください。必ず `src/main/resources/書類.xlsx` を Apache POI などで確認してから実装してください。
- 既存の `writeSafe` / `writeSafeNumeric` / `exportMultiSheet` / `buildCombinedWorkbook` の流れを活かし、帳票ごとに局所修正してください。
- 直接ダウンロード機能を完全削除する必要はありませんが、活動一覧の単一活動「出力」操作は必ずプレビュー画面を経由させてください。
- 実装後はローカルコミットで終わらせず、必ず `git push origin main` まで実行してください。
- Kazumax 向け完了報告には必ず「GitHubへプッシュしました」と明記してください。

## 実装要件

### 1. 活動一覧の単一出力ボタンをプレビュー画面へ変更

対象: `src/main/resources/templates/activity/list.html`

現在の「出力」ドロップダウンは `GET /activity/{id}/export` で直接Excelをダウンロードしています。これをやめ、既存の `POST /export/preview` へ送信してください。

実装方針:

- 各ドロップダウン項目を `<form method="post" action="/export/preview">` に変更する。
- hidden input として以下を送る。
  - `projectIds`: 対象活動ID
  - `exportType`: `all`, `2-4`, `2-5`, `2-6`
- ボタン見た目は現在の dropdown-item に近いままにする。
- `all` はプレビュー側で扱えるようにする。現状の `ExportController.preview()` は `2-2` 以外を同じ previewProjects 表示に流せるため、`all` でも落ちないことを確認してください。
- `/export/download` 側も `exportType=all` を受けた場合に `excelExportService.exportAllFormsForProjects(projectIds, response.getOutputStream())` を呼ぶようにしてください。

注意:

- 既存の `GET /activity/{id}/export` は互換用に残して構いません。
- 活動一覧から押した場合、必ずプレビュー画面 `export/preview.html` が表示され、そこからダウンロードできることを確認してください。

### 2. Excel出力の年度を令和表記の数値へ変更

対象: `ExcelExportService.java`

西暦年度を令和年度へ変換する helper を追加してください。

```java
private int getReiwaYear(int year) {
    return year - 2018;
}
```

対象帳票:

- 様式2-2
- 様式2-4
- 様式2-5
- 様式2-6

実装方針:

- 年度セルに `2026` のような西暦を書いている箇所を探し、`getReiwaYear(...)` の戻り値を書き込む。
- `Project.getFiscalYear()` が使える場合はそれを優先し、なければ `project.getEventDate().getYear()` から計算してください。
- 様式2-2のように複数活動から年度を判断する場合は、先頭プロジェクトまたは選択年度をもとに令和年度へ変換してください。選択IDが空の場合は落とさず空欄または現在年度で処理してください。

注意:

- 「令和7年」の文字列ではなく、テンプレート側が「令和  年度」のように持っているセルには数値 `7` のみ入れる可能性があります。テンプレートを確認して、既存セルの構造に合わせてください。
- 日付セルのフォーマット変更とは分けて実装してください。

### 3. 様式2-4のバグ修正

対象: `ExcelExportService.java`

#### 3-1. 既存図形の削除

テンプレートに残っている手動記入用の黒い巨大丸など、既存 Shape を削除してから新しい丸を描画してください。

実装方針:

- `exportForm24()` と `buildCombinedWorkbook()` の様式2-4シート複製後、`populate24Side()` で `drawEllipse()` する前に対象シートの既存図形を削除する。
- XSSF の場合は `XSSFDrawing` / relations などを確認し、既存 shape を安全に消す方法を使ってください。
- POI APIで安全な一括削除が難しい場合は、テンプレート複製直後に drawing patriarch を確認し、削除できる shape のみ削除してください。削除できない場合はP3報告に理由と代替確認を明記してください。

#### 3-2. 合計金額の強制上書き

テンプレートに残っているダミー合計額（例: `84050`）を必ず消し、システム計算値で上書きしてください。

実装方針:

- `populate24Side()` 内で、交通費・宿泊費・旅行雑費・事業経費の合計から「計」セルを計算して書き込む。
- 現在 `transportSum`, `accommodationSum`, `miscSum`, `summary` の各費目を書いているため、それらを合算して総計を出してください。
- 左側 `colOffset == 0` と右側 `colOffset == 17` の両方で正しい位置に書く。
- テンプレート上の「計」セル座標は必ず `書類.xlsx` で確認してください。

#### 3-3. 期日の和暦・曜日フォーマット

様式2-4の期日セルは `令和X年Y月Z日(曜)` 形式で出力してください。

例:

- `2025-09-27` -> `令和7年9月27日(土)`

実装方針:

- helper を追加してください。

```java
private String formatJapaneseDateWithWeekday(LocalDate date) { ... }
```

- 曜日は `日/月/火/水/木/金/土` の1文字にする。
- `project.getEventDate()` が null の場合は空欄にしてください。

#### 3-4. 相方自動連行システム

「1件の活動のみ」を様式2-4で出力する場合、年度内の日付順で奇数回目/偶数回目を判定してください。

仕様:

- 対象活動が年度内で奇数回目（1, 3, 5...）なら、左側に対象活動を印字し、右側は空欄のまま。
- 対象活動が年度内で偶数回目（2, 4, 6...）なら、右側に対象活動を印字し、左側に1つ前の活動をDBから取得して印字する。
- 「1つ前の活動」は同一会計年度内、日付順、同日がある場合は `id` 昇順で直前の活動にしてください。

実装方針:

- `ProjectMapper` に年度内活動一覧を日付順で取得するメソッドを追加する。
- 例: `List<Project> findByFiscalYearOrdered(Integer fiscalYear)`
- fiscalYear は `Project.getFiscalYear()` を使う。null の場合は `eventDate` から会計年度を計算する。
- この相方補完は `exportForm24()` に `projectIds.size() == 1` で入ってきた場合だけ適用してください。
- 複数IDを選択して出力する既存処理では、選択順/既存ペアリングを壊さないでください。

### 4. 様式2-5のバグ修正

対象: `ExcelExportService.java`

#### 4-1. 操作ユーザーの印字

様式2-5の下部「記入責任者氏名・電話番号」に、現在のアクティブユーザーの氏名と電話番号を上書きしてください。

実装方針:

- Cycle 4で追加済みの `UserSettingService` を使う。
- 既存テンプレートのダミー文字は残さず上書きする。
- 座標は `書類.xlsx` の様式2-5シートで確認してください。

#### 4-2. 事業実施日の和暦期間表示

ヘッダーの【事業実施日】欄を以下の形式にしてください。

- 宿泊なし: `令和X年Y月Z日`
- 宿泊あり: `令和X年Y月Z日～W日`

宿泊あり判定:

- P1では「泊数 > 0」とありますが、現行データには泊数カラムがありません。
- 現行仕様では、参加者の宿泊有無 `ProjectParticipant.isAccommodated` または経費の `accommodationCost > 0` を宿泊ありの判定に使ってください。
- 最大泊数が取得できない場合は、宿泊費がある参加者がいるとき `eventDate.plusDays(1)` を終了日として `～翌日の日` を出してください。
- もし既存モデルに泊数相当の情報が追加済みなら、それを優先してください。

#### 4-3. 宿泊対象者の日付と丸印

参加者の宿泊費が1円以上の場合、様式2-5の宿泊対象者欄を修正してください。

仕様:

- 宿泊対象者欄の一番左の枠のヘッダー部（月 日 と書いてあるセル）に宿泊日を `M月D日` 形式で印字する。
- 該当者の行には日付ではなく `〇` を印字する。
- 宿泊費が0円または null の参加者には印字しない。

注意:

- 現在 `populate25()` は `p.getIsAccommodated()` を見て `〇` を書いています。今回の条件は「宿泊費が1円以上」を優先してください。
- 宿泊日セルの座標は必ずテンプレート確認してください。

### 5. 様式2-6のバグ修正

対象: `ExcelExportService.java`

#### 5-1. 操作ユーザーの印字

様式2-6の以下にユーザー設定情報を上書きしてください。

- 「作成者名」
- 下部の「記入責任者氏名・電話番号」

実装方針:

- `UserSettingService.getActiveUser()` を使う。
- activeUser が null の場合は空欄にするか、既存値を消して空欄にしてください。
- 座標は `書類.xlsx` の様式2-6シートで確認してください。

#### 5-2. 期日と受領日のフォーマット

様式2-6の「期日」と「受領日」は西暦を含めず、`M/d` 形式にしてください。

例:

- `2025-08-25` -> `8/25`

実装方針:

- helper を追加してください。

```java
private String formatMonthDay(LocalDate date) { ... }
```

- `expenseDate` が null の場合は `project.eventDate` にフォールバックして構いません。
- `receiptDate` が null の場合も現行どおり `project.eventDate` へフォールバックして構いません。
- セル幅や文字見切れが出る場合は、対象セルの style/wrap/shrinkToFit を調整してください。

#### 5-3. 合計金額の強制上書き

様式2-6下部のダミー合計金額を消し、印字対象者の実際の合計金額を計算して書き込んでください。

実装方針:

- `populate26()` 内で、実際に印字した参加者の `transportCost + accommodationCost + miscellaneousCost` を合算する。
- 現在、雑費欄は `-` 表示ですが、データ上の `miscellaneousCost` を合計に含めるかどうかは既存仕様に合わせてください。P1の「実際の合計金額」を優先し、DBに値がある場合は含める方針を推奨します。
- テンプレート上の合計セル座標を確認して上書きしてください。

### 6. 電話番号の自動ハイフン化と案内

対象候補:

- `src/main/resources/templates/users/form.html`
- 必要なら `src/main/resources/templates/activity/layout.html`

P1では `activity/layout.html` の「操作ユーザー設定モーダル」とありますが、現状実装はモーダルではなく `users/form.html` の登録・編集画面です。既存構成を壊さず、実際の電話番号入力欄で対応してください。

実装要件:

- 電話番号入力欄に `placeholder="例: 090-1234-5678"` を設定する。
- ヘルプテキストとして `※ハイフンなしで入力しても自動で補完されます` を表示する。
- JavaScriptで入力時に自動ハイフン化する。

実装方針:

- `users/form.html` の `phoneNumber` input に `id="phoneNumber"` などを付ける。
- 数字以外を除去し、以下のように整形する。
  - 11桁携帯: `09012345678` -> `090-1234-5678`
  - 10桁固定電話など: `0985123456` -> `0985-12-3456` など、最低限 `XXX-XXX-XXXX` または `XXXX-XX-XXXX` で破綻しない形にする。
- 保存時も画面上の値はハイフン入りで送って構いません。

注意:

- 既に `activity/layout.html` にモーダル化する実装を追加する必要はありません。モーダル化は今回の必須範囲外です。

### 7. セレクトボックスの文字被り修正

対象: `src/main/resources/static/css/style.css`

`select.form-select` の右側 padding を増やし、プルダウン矢印と文字が被らないようにしてください。

実装例:

```css
select.form-select {
    padding-right: 2.75rem;
}
```

注意:

- `.form-select` 全体ではなく、できれば `select.form-select` に限定してください。
- 活動一覧の年度セレクト、補助金区分、活動入力フォームの各セレクトで文字が見切れないか確認してください。

### 8. 活動一覧の月別フィルター機能

対象:

- `ActivityController.java`
- `src/main/resources/templates/activity/list.html`
- `ProjectMapper.java`
- `src/main/resources/mapper/ProjectMapper.xml`

現在の活動一覧は年度と補助金区分で絞り込みます。ここに月別フィルターを追加してください。

仕様:

- セレクト項目: `全て`, `4月`, `5月`, `6月`, `7月`, `8月`, `9月`, `10月`, `11月`, `12月`, `1月`, `2月`, `3月`
- query param 名は `month` とする。
- `month` は実月の数値として扱う。例: 4月なら `4`, 1月なら `1`。
- 年度フィルターはこれまで通り4月始まりを維持する。
- 月が指定された場合、年度範囲内かつ `MONTH(event_date) = #{month}` で絞り込む。

実装方針:

- `ActivityController.list()` に `@RequestParam(value = "month", required = false) Integer month` を追加。
- `projectMapper.findFiltered(year, budgetTypeId, month)` のように引数を拡張する。
- `ProjectMapper.java` と XML の `findFiltered` を更新する。
- `list.html` の絞り込みフォームに月セレクトを追加し、選択状態を保持する。
- 年度まとめExcel出力リンクにも `month` を渡すか、P1の趣旨に合わせて一覧で絞り込んだ対象を出すようにしてください。少なくとも画面の絞り込み結果と年度まとめ出力の対象が食い違わないようにしてください。
- `ActivityController.exportYear()` も `month` を受け取れるようにし、`findFiltered(year, budgetTypeId, month)` を使ってください。

注意:

- `ProjectMapper.findFiltered` を呼んでいる他の箇所もコンパイルエラーにならないよう修正してください。
- 月未指定または空文字の場合は、従来どおり全月を表示してください。

## 共通 helper 推奨

`ExcelExportService.java` に以下のような helper を追加すると安全です。

```java
private int getReiwaYear(int year) {
    return year - 2018;
}

private String formatJapaneseDate(LocalDate date) {
    if (date == null) return "";
    return "令和" + getReiwaYear(date.getYear()) + "年" + date.getMonthValue() + "月" + date.getDayOfMonth() + "日";
}

private String formatJapaneseDateWithWeekday(LocalDate date) {
    if (date == null) return "";
    String[] weekdays = {"日", "月", "火", "水", "木", "金", "土"};
    String w = weekdays[date.getDayOfWeek().getValue() % 7];
    return formatJapaneseDate(date) + "(" + w + ")";
}

private String formatMonthDay(LocalDate date) {
    if (date == null) return "";
    return date.getMonthValue() + "/" + date.getDayOfMonth();
}
```

## 検証項目

実装後、最低限以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS` になる。
- `src/main/resources/application.properties` と `target/classes/application.properties` の `app.version` がどちらも `v1.8.10`。
- 活動一覧の単一活動「まとめて / 2-4 / 2-5 / 2-6」がすべてプレビュー画面に遷移する。
- プレビュー画面から `all / 2-4 / 2-5 / 2-6` がダウンロードできる。
- 様式2-2/2-4/2-5/2-6の年度が西暦ではなく令和年度の数値になる。
- 様式2-4でテンプレート由来の巨大丸が残らず、必要な丸だけが描画される。
- 様式2-4でダミー合計額が残らず、システム計算値が入る。
- 様式2-4の期日が `令和X年Y月Z日(曜)` 形式になる。
- 様式2-4の単一偶数回目出力で、左に前回活動、右に対象活動が印字される。
- 様式2-4の単一奇数回目出力で、左に対象活動、右は空欄になる。
- 様式2-5下部に操作ユーザーの氏名・電話番号が入る。
- 様式2-5の事業実施日が令和表記になり、宿泊ありの場合は期間表示になる。
- 様式2-5の宿泊対象者欄に宿泊日ヘッダーと該当者の `〇` が入る。
- 様式2-6の作成者名、記入責任者氏名・電話番号が操作ユーザー情報で上書きされる。
- 様式2-6の期日・受領日が `M/d` 形式になる。
- 様式2-6のダミー合計額が残らず、実合計が入る。
- 電話番号入力欄で `09012345678` が `090-1234-5678` のように補完される。
- セレクトボックスの文字と矢印が被らない。
- 活動一覧で月別フィルターが効き、年度・補助金区分との組み合わせでも正しく絞り込まれる。
- 既存の活動保存、編集、削除、名簿連携、交通費計算、ユーザー切替が壊れていない。

## 完了時の必須作業

1. `app.version=v1.8.10` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.10` を確認する。
4. 変更をコミットする。
5. 必ず `git push origin main` を実行する。
6. P3 報告書を `docs/handoff/P3_CC_to_Dex/cycle_5.md` に作成する。
7. Kazumax 向けチャット報告の最後に「GitHubへプッシュしました」と明記する。

## P3 報告書に必ず書くこと

- 変更ファイル一覧
- 実装内容の要約
- プレビュー導線の変更内容
- Excel各様式の修正内容と確認したセル座標
- 令和変換・日付フォーマット helper の仕様
- 様式2-4の相方自動連行システムの判定方法
- 月別フィルターの仕様
- `.\mvnw compile` の結果
- `src` と `target/classes` のバージョン確認結果
- コミットハッシュ
- `git push origin main` の実行結果
- Dex(P4) に確認してほしい観点

## 提案

帳票セル座標の確認結果は、今後のために P3報告書へ「様式名 / 項目名 / row / col / 表示例」の表で残してください。今回の修正は座標依存が多く、後続レビューの精度が上がります。

## 次の担当への合図（コピー用）

```text
CCへ。docs/handoff/P2_Dex_to_CC/cycle_5.md を読んで、Cycle 5 の実装をお願いします。完了後は .\mvnw compile、app.version=v1.8.10 の src/target 同期確認、コミット、git push origin main まで実施し、docs/handoff/P3_CC_to_Dex/cycle_5.md に報告書を作成してください。Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
