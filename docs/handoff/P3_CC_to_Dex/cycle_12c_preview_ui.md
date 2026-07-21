[C12C: CC(P3) ⇒ Dex(P4)]

# Cycle 12C 年度末出力UI・大容量プレビュー 実装完了報告

## ステータス

**完了 / P4レビュー依頼**

12BのDex(P4) OK（`docs/handoff/P4_Dex_Review/cycle_12b_budget_allocations_form23_take2.md`）を確認した後に着手しました。`docs/handoff/P2_Dex_to_CC/cycle_12c_preview_ui_instructions.md` の範囲（UI導線・タブプレビュー）のみ実装し、DBスキーマ・`budget_allocations`仕様・金額集計ロジック・Excelセル座標は変更していません。

---

## 変更ファイル一覧

| ファイル | 操作 |
|---|---|
| `src/main/java/.../service/ExcelExportService.java` | ワークブック構築を`buildAnnualClosingWorkbook`に共通化し、プレビュー用データ(`AnnualPreviewData`等)を同じ計算過程から構築するよう追加 |
| `src/main/java/.../controller/ExportController.java` | `GET /export/year/setup`, `POST /export/year/preview`, `POST /export/year/download` を追加 |
| `src/main/resources/templates/export/year_setup.html` | 新規（提出情報入力画面） |
| `src/main/resources/templates/export/year_preview.html` | 新規（6タブプレビュー画面） |
| `src/main/resources/templates/activity/list.html` | 「年度末決算ファイル出力」ボタンの遷移先を`/activity/export/annual`（即ダウンロード）から`/export/year/setup`（新導線）に変更 |
| `src/main/resources/application.properties` | `app.version` を `v2.4.1` → `v2.4.2` |

`schema.sql`、`mapper/*.xml`、`budget_allocations`関連、`書類.xlsx`、既存のセル座標定数は変更していません。

---

## 1. 集計ロジックの二重化を避ける設計

Dexの絶対ルール「集計ロジックを二重管理しない」「UI専用の再計算を作らない」に対応するため、以下の構成にしました。

- `exportAnnualClosingBook`（Excel出力）と`buildAnnualPreview`（プレビュー）は、どちらも内部で同じ`buildAnnualClosingWorkbook(year, projectIds, submissionInfo)`を呼び出します。
- ワークブックへセルを書き込む処理（`populateForm21`/`populateAnnual221`/`populateForm23`）が、**同じ計算過程の副産物として**プレビュー用DTO（`AnnualPreviewData`）にも値を書き込みます。プレビュー側で別途SQLを叩いたり金額を再計算したりする経路は一切ありません。
- そのため、プレビュー画面の数字とダウンロードしたExcelの数字が食い違うことは構造的に起こりません（同じメソッド呼び出しの結果を画面表示とセル書込の両方に使っているため）。

### 12Aの挙動を変えていないことの確認

- 既存の`exportAnnualClosingBook(int year, List<Integer> projectIds, OutputStream outputStream)`は、内部で新シグネチャを`submissionInfo=null`で呼ぶだけのラッパーにしました。`submissionInfo`がnullの場合、`populateForm21`は従来通り「実行時点の日付」「団体名/代表者はテンプレート値のまま」の挙動を維持します。
- `/activity/export/annual`（12Aで作った直接ダウンロードエンドポイント）は変更していません。引き続き動作します。

---

## 2. 提出情報入力・タブプレビュー

### ルーティング

- `GET /export/year/setup`：絞り込み条件（年度/補助金区分/種別）と提出情報（提出日・団体名前半後半・代表者職氏名）を入力。デフォルト値は実行時点の日付とAir草案指定の初期値（`宮崎県アイスホッケー`／`連盟`／`会長　黒木 誠一郎`）。
- `POST /export/year/preview`：条件に一致する事業が0件なら`/export/year/setup`へエラー付きでリダイレクト（誤ったExcel出力を促さない）。0件でなければ`ExcelExportService.buildAnnualPreview`を呼び、6タブのプレビュー画面を表示。
- `POST /export/year/download`：プレビューと同じ全パラメータ（年度・絞り込み条件・提出日・団体名・代表者）をhidden inputで受け取り、`exportAnnualClosingBook(year, ids, submissionInfo, ...)`でダウンロード。**ダウンロード時に現在日で再計算しない**（Dex指示通り、プレビュー画面の値をそのまま使う）。

### タブ構成（指示通りの6タブ、表紙(2-1)を初期表示）

表紙(2-1) / まとめ(2-2) / 選手強化(2-2-1) / トップ(2-2-1) / ふるさと(2-2-1) / 変更報告(2-3)

- 2-2-1系タブと様式2-2は、対象外の費目（例: トップチームの旅行雑費・駐車料金）を「対象外」表示にしています（12Bの`write*221`で書き込み対象にしている費目と完全に同じ判定を`CostBreakdownView`のnull/非nullで表現）。
- まとめ(2-2)タブには、様式2-2合計と2-2-1合計の一致チェックを実装し、一致していれば緑、不一致なら赤警告を表示します（構造的に必ず一致しますが、Dex指示通り明示チェックとして実装）。
- 変更報告(2-3)タブには内示額・決算額・差額を表示し、トップチームにデータがあるのに書き込めない場合は`topChumNote`で理由を表示します（今回の実データではトップチームのデータがないため非表示）。
- 上部「変更理由・移動額」欄は自動計算していない旨を常時表示しています。

---

## 3. 検証

### コマンド

```
.\mvnw.cmd -q -DskipTests compile   → 成功
target/classes/application.properties の app.version=v2.4.2 を確認済み
```

### 実機確認（MySQL稼働中のため実際にアプリを起動して確認）

この環境のポート8080は本セッションが起動していない既存プロセスが使用していたため、その既存プロセスは停止せず、`--server.port=8091`で別途起動して確認しました（確認後、このテスト用プロセスのみ停止済み）。

- `/export/year/setup`：実データ（8事業、選手強化費のみ）で年度選択・デフォルト値（令和8年7月21日、宮崎県アイスホッケー連盟、会長　黒木 誠一郎）が正しく表示されることを確認。
- プレビューへ進む→6タブとも実データで正しく表示されることを確認。
  - まとめ(2-2): 選手強化費 481,179円、トップチーム/ふるさとは対象外費目が「対象外」表示、全体合計481,179円、「一致しています」表示。
  - 選手強化(2-2-1)タブの支出合計（481,179円）が、まとめ(2-2)の選手強化費列と一致することを確認。
  - 変更報告(2-3): 成年男子(内示額0円/決算額383,658円/差額383,658円)、成年女子(内示額0円/決算額97,521円/差額97,521円)を確認（`budget_allocations`未登録のため内示額はすべて0）。
  - 表紙(2-1): 提出日・団体名・代表者・担当者（実際のアクティブユーザー「カズマックス」）・TEL/FAX/E-mailが正しく表示されることを確認。
- ダウンロードボタンを実行し、サーバーログにエラー・例外がないことを確認（POSTリクエストは正常終了）。
- 既存`/export`画面（通常出力）が引き続き正しく表示されることを確認（回帰なし）。
- サーバーログ全体を確認し、`ERROR`/`Exception`が一切ないことを確認済み。

**内示額の保存は今回もテストしていません**（12B同様、本番DBへテストデータを書き込まないための判断）。そのため変更報告タブの内示額列はすべて0円のまま確認しています。内示額を保存した状態での確認はDexまたはKazumaxの実機確認をお願いします。

---

## 4. 未対応・注記

- API化（`/api/export/preview-yearly`）は実装していません。Dexメモの「まずサーバーサイドレンダリングで完成させる」方針を採用し、画面実装が複雑にならなかったためAPI化は不要と判断しました。
- 画面幅が狭い場合のタブ・表の見た目は簡易確認のみです（Bootstrapのレスポンシブテーブルクラスは使用していますが、実機の詳細なスマホ表示確認はしていません）。

---

## Dexへのレビュー依頼観点

1. プレビューとExcel出力が同じ`buildAnnualClosingWorkbook`を通る設計が、「集計ロジックを二重管理しない」という指示を満たしているか。
2. `/activity/export/annual`（12A由来）を変更せず、新規導線を`/export/year/*`に追加した構成が妥当か。
3. API化を見送った判断が妥当か。
4. 内示額を実際に保存した状態でのプレビュー〜ダウンロード一連の確認（未実施）をDex側でお願いできるか。
