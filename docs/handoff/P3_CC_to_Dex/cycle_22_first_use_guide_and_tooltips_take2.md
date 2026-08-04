[C22: CC(P3) ⇒ Dex(P4) Take2]

# Cycle 22 Take2 P3実装報告: P4差し戻し4点の修正

## 1. 対象範囲

`docs/handoff/P4_Rollback/cycle_22_first_use_guide_and_tooltips.md` で指摘された4点のみを修正した。DB、保存、金額、Excel、Mapper、既存URL、hidden input、POST先、`app.version` には一切触れていない。`GuideController`のGET専用設計、共通tooltip初期化の`getInstance`ガード、既存`data-bs-html="true"`、P1文言・FAQ・既存の常時注意文も変更していない。

## 2. 修正内容（4点）

### (1) 活動一覧の「出力」ドロップダウンのHTML破損

`src/main/resources/templates/activity/list.html` の `出力` ボタンで、表示文字と閉じタグが欠落し `<ul class="dropdown-menu">` がbutton内に入り込んでいた。

修正: `data-bs-toggle="dropdown" aria-expanded="false">出力</button>` として文字と閉じタグを復元し、`<ul>` をbuttonの外側に戻した。`projectIds` hidden input、POST先(`/export/preview`)、出力様式（all/2-4/2-5/2-6）は一切変更していない。

### (2) ヘルプbuttonのlabel内混入

以下3箇所で `<label>...ラベル文字<button>...</button></label>` となっていたのを、`<label>ラベル文字</label>` + 直後の兄弟`<button>`へ分離した。

- `activity/form.html`: `交通費単価（円/km）`
- `activity/form.html`: `旅行雑費`
- `members/index.html`: 新規追加欄 `主な出発地点`

対象input（`id="transportRate"`、`id="travelMiscCost"`等、`name="departurePoint"`）の`id`/`name`/`oninput`/`th:value`は変更していない。`rg`で`help-tip-btn`の全出現箇所（8ファイル・18箇所）を再確認し、`<label>`または既存`<button>`の内側にあるものが無いことを確認した。

### (3) ガイド5カードの狭い幅崩れ

`src/main/resources/templates/guide/index.html` の5ステップカードで、`col-6 col-md-4`と`style="flex:1 1 20%; max-width:20%;"`が併存し、`max-width:20%`が小画面にも効いていた。

修正: inlineスタイルを全て削除し、`row row-cols-2 row-cols-md-5 g-3 mb-5` + `col`（Bootstrap grid標準）へ置き換えた。360px幅では2列×3行、`md`以上では5列で表示される。カードの順序・文言・リンク先（`/users/new`、`/members`、`/activity`、`/export`×2）、FAQ本文は一切変更していない。

### (4) 操作ユーザーヘルプが360pxで非表示

`src/main/resources/templates/layout.html` のヘルプbuttonから `d-none d-sm-inline-block` を削除し、全幅で表示されるようにした。あわせて、`？ 使い方`・操作ユーザーヘルプ・操作ユーザードロップダウンが横一列で並ぶ狭い幅（576px未満）でのみ、`src/main/resources/static/css/style.css`に以下を追加し、横あふれ時は折り返す形にした（既存のナビ表示方式・リンク自体は変更していない）。

```css
@media (max-width: 575.98px) {
    .navbar > .container-fluid { flex-wrap: wrap; row-gap: 4px; }
    .navbar-brand { font-size: 0.95rem; }
}
```

`？ 使い方`リンクと操作ユーザードロップダウンの削除・置換は行っていない。CSSのバージョンクエリを`?v=4`→`?v=5`へ更新した。

## 3. 検証結果

### 静的境界確認

- `git diff --stat` で `ExcelExportService.java`、`mapper/*.xml`、`schema.sql`、`application.properties`に差分がないことを確認。
- `app.version` は `v2.6.2` のまま（`src/main/resources/application.properties`と`target/classes/application.properties`が一致）。**バージョン変更なし。理由: 今回もUI構造修正のみで、P2/P1の不変条件に従った。**
- `rg "help-tip-btn"` の全18箇所を目視確認し、`<label>`・既存`<button>`の内側に無いことを確認（受入確認2）。

### ビルド・テスト

- `.\mvnw.cmd -q -DskipTests compile`：成功。
- `.\mvnw.cmd -q test`：**exit code 0で成功**（既存12件 + `GuideControllerTest`1件の計13件、DB読取込みの既存テストを含めて完走した。CC環境でのタイムアウトは発生していない）。

### 実画面確認について

Take2でも、CC環境のブラウザプレビューツールがdevサーバーへの接続に失敗する状態（ポート競合起因の問題）が再発したため、Kazumaxの直近の指示（Take1完了時と同様の判断）に基づき、**360px幅・PC幅での実画面確認は今回もCC側で実施していない。** 上記4点は、いずれもHTML構造上明確な欠陥（閉じタグ欠落、label内button、inline style優先度、非表示クラス）の修正であり、差分レベルで妥当性を確認した。

このため、Dex(P4)受入確認の3番目（実画面での360px/PC幅確認）は未実施のまま報告する。Dex(P4)またはKazumaxによる実機確認（`？使い方`、操作ユーザーヘルプ、ガイド5カード、活動一覧の出力dropdown）を必須で依頼したい。

## 4. compile / version

変更なし。`app.version=v2.6.2`のまま（P1/P2の不変条件による例外を継続適用）。

## 5. commit / push

（コミット後に追記）
