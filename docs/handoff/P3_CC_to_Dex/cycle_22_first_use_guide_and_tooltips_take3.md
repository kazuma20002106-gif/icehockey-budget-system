[C22: CC(P3) ⇒ Dex(P4) Take3]

# Cycle 22 Take3 P3実装報告: 360pxヘッダー横あふれの修正

## 1. 対象範囲

`docs/handoff/P4_Rollback/cycle_22_first_use_guide_and_tooltips_take2.md` で指摘された1点（360px幅で操作ユーザーdropdownが画面右で見切れる）のみを修正した。Take2で修正済みの出力dropdown HTML、label外button、guideカードgrid、共通tooltip初期化、P1文言・FAQ・常時注意文、`GuideController`のGET専用設計は再変更していない。DB、保存、金額、Excel、Mapper、既存URL、hidden input、POST先、`app.version`にも触れていない。

## 2. 修正内容

### 対象: `src/main/resources/templates/layout.html` と最小限のCSS

Take2までは「？使い方」リンク・操作ユーザーヘルプ・操作ユーザーdropdownの3要素がそれぞれ個別に`ms-auto`等を持つ独立したフレックス子要素として並んでおり、狭い幅で`flex-wrap`しても、ブランド行とこれら3要素が同じ行の残り幅を奪い合う形になっていたため、操作ユーザーdropdownだけが画面右で見切れていた。

修正方針: 3要素を1つの`<div class="d-flex align-items-center gap-2 ms-auto header-right-group">`にまとめ、狭い幅では`header-right-group`自体を`flex-basis: 100%`でブランド行から独立した1行へ強制的に折り返す。これにより狭い幅では常に「ブランド行」→「？使い方・ヘルプ・操作ユーザーの行」という2行構成になり、操作ユーザーdropdownは自分の行の全幅を使えるため見切れなくなる。

```css
@media (max-width: 575.98px) {
    .navbar > .container-fluid { flex-wrap: wrap; row-gap: 4px; }
    .navbar-brand { font-size: 0.95rem; }
    .header-right-group { flex-basis: 100%; justify-content: flex-end; }
}
```

あわせて、操作ユーザーdropdownのbuttonに`text-truncate`と`max-width: 150px;`を追加した。氏名が長い場合でも省略記号で収まり、狭い幅での再発を防ぐ（`th:text`のロジック自体は変更していない）。

`？ 使い方`リンク、操作ユーザーヘルプ`ⓘ`、操作ユーザーdropdown（ユーザー切替POST、＋新規登録、編集への各リンク）は、要素の入れ子構造をグループ化しただけで、削除・置換・URL変更は一切行っていない。CSSのバージョンクエリを`?v=5`→`?v=6`へ更新した。

## 3. 検証結果

### 静的境界確認

- `git diff --stat` で `ExcelExportService.java`、`mapper/*.xml`、`schema.sql`、`application.properties`に差分がないことを確認。
- `app.version` は `v2.6.2` のまま（`application.properties`と`target/classes/application.properties`が一致）。**バージョン変更なし。理由: 今回もヘッダーCSS構造の修正のみで、P2/P1の不変条件に従った。**
- 操作ユーザーdropdownのユーザー切替POST(`/users/switch`)、hidden input（`userId`/`redirect`）、`/users/new`・`/users/edit/{id}`へのリンクは無変更であることをdiffで確認した。

### ビルド・テスト

- `.\mvnw.cmd -q -DskipTests compile`：成功。
- `.\mvnw.cmd -q test`：**exit code 0で成功**（既存12件 + `GuideControllerTest`1件の計13件、DB読取込みの既存テストを含め完走）。

### 実画面確認について

Take3でも、CC環境のブラウザプレビューツールが`http://localhost:8091/guide`等へ`ERR_CONNECTION_REFUSED`で接続できない状態が継続しており（`read_network_requests`で明示的に確認済み）、**360px幅・PC幅での実画面確認は今回もCC側で実施できていない。**

このため、CSSの挙動はコードレビューで説明可能な範囲（`flex-basis: 100%`による強制改行、`header-right-group`が1つのフレックスアイテムとして丸ごと次行へ落ちる標準的なFlexboxの挙動）に留め、実機での最終確認をDex(P4)またはKazumaxに依頼したい。Dex(P4)は前回`headlessブラウザ`で実機確認できているとのことなので、Take3でも同様の確認を重ねてお願いしたい。

## 4. 受入確認への対応状況

P4_Rollback指定の受入確認5項目のうち、1・2（360px/PC幅の実画面確認）はCC側で未実施。3（ガイド5カード・出力button再確認）はTake2から差分なし（コード上は`row-cols-2 row-cols-md-5`のまま）。4（禁止領域への差分なし）は上記静的確認で確認済み。5（compile/test/commit hash記録）は本報告に記載のとおり完了。

## 5. compile / version

変更なし。`app.version=v2.6.2`のまま。

## 6. commit / push

（コミット後に追記）
