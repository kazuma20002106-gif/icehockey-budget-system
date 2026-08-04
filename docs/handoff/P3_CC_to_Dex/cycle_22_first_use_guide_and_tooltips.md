[C22: CC(P3) ⇒ Dex(P4)]

# Cycle 22 P3実装報告: 初見利用者ガイド・ツールチップ

## 1. 対象範囲

`docs/handoff/P2_Dex_to_CC/cycle_22_first_use_guide_and_tooltips_instructions.md` を正として、案内UI（ツールチップ・常時注意文・`/guide` ガイドページ）のみを実装した。DB、保存処理、金額計算、Excel、Mapper、既存URL、`app.version` には一切触れていない。

CCクルー利用判断: **不使用**（Dex(P2)指示書の判定「不要」に従った。保存・金額・Excel・DBに触れないUI限定差分のため）。

## 2. 変更ファイル一覧

### 新規

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/GuideController.java`：`GET /guide` のみ。Service/Repository/Mapperを注入・呼び出ししない。テンプレート名を返すだけ。
- `src/main/resources/templates/guide/index.html`：5ステップカード、画面ごとの詳細解説（🚨/⚠️/💡アラート）、FAQ（P1の7項目）。すべて既存GET URLへのリンクのみで、POST・状態変更要素なし。
- `src/test/java/com/miyazaki/icehockey/budgetsystem/controller/GuideControllerTest.java`：DB接続を必要としない`@WebMvcTest(GuideController.class)`によるGET到達性テスト。`GlobalControllerAdvice`が依存する`UserSettingService`は`@MockitoBean`でモックした。

### 変更（案内UIの追加のみ）

- `src/main/resources/templates/layout.html`：デスクトップナビへ「📖 使い方」追加、狭い幅専用の独立「？ 使い方」リンク追加（`d-md-none`、既存ナビ非表示時のみ表示）、「操作:氏名」横のヘルプアイコン追加、共通ツールチップ初期化スクリプトを追加。
- `src/main/resources/static/css/style.css`：ツールチップトリガー用の`.help-tip-btn`最小スタイルのみ追加。バージョンクエリを`?v=3`→`?v=4`に更新。
- `src/main/resources/templates/dashboard/index.html`、`members/index.html`、`budget_allocations/index.html`、`users/form.html`、`activity/list.html`、`activity/form.html`、`export/index.html`、`export/year_setup.html`：P1 Blueprint確定文言のツールチップ・常時注意文をP2指示書の画面ごとの要件に沿って追加。既存の常時警告文（DLだけでは印刷済みにならない、複製後の注意など）は削除・弱化せず維持し、確定文言を補足として追加した。

いずれのファイルもテンプレート・CSS・GET専用Controller・そのテストのみで、`ExcelExportService`、`mapper/*.xml`、`schema.sql`、`application.properties`への差分はない（3.静的境界確認を参照）。

## 3. ツールチップ共通初期化と二重初期化への対処

- 初期化は `layout.html` の1箇所（`DOMContentLoaded`）のみで行い、`bootstrap.Tooltip.getInstance(el)` を確認してから未生成の要素だけ`new bootstrap.Tooltip(el, { trigger: 'hover focus click' })`する。JS側で`html`オプションを指定しないため、各要素の`data-bs-html="true"`属性がBootstrapのデフォルト優先順位どおりそのまま尊重される。
- `activity/form.html` と `members/index.html` に存在していたページ個別の `window.addEventListener('load', ...)` 初期化は削除した（コメントで「layout.htmlの共通初期化へ統一済み」と明記）。ページはlayoutのcontentスロットへサーバーサイドでレンダリングされるため、`DOMContentLoaded`時点で全ツールチップトリガーが揃っており、二重初期化・未初期化のいずれも発生しない。
- 新規ヘルプアイコンは原則`<button type="button" class="help-tip-btn">`とし、`tabindex="0"`、`aria-label="ヘルプ: ..."`、`data-bs-toggle="tooltip"`、`data-bs-trigger="hover focus click"`を付与した（P2/P1 4.2のアクセシビリティ必須仕様）。既存のBootstrapドロップダウン切替ボタン（`data-bs-toggle="dropdown"`）など、他の`data-bs-toggle`用途と競合する箇所（活動一覧の「出力」ボタン等）は、ボタン内部に入れ子にせず、隣接する独立ボタンとして配置した。
- 既存の名簿見出しアイコン（`<i>`ベース）はP1確定文言へ更新する際にaccessibility属性が無かったため、`<button>`ベースへ差し替えて統一した。

## 4. `/guide` の到達性・不動条件

- モバイル到達性: デスクトップ用ナビ(`d-none d-md-flex`)とは独立した`？ 使い方`リンクを`d-md-none`で常設し、既存ナビが非表示になる狭い幅でも到達できる。既存の操作ユーザー選択・新規登録・編集機能は変更していない。
- `GuideController`はGETのみで、Service/Repository/Mapperを一切呼ばない。テンプレートも変数を持たず、DB由来のモデル属性に依存しない。
- 5カード・本文リンクは`/users/new`、`/members`、`/activity`、`/export`のみで、出力・状態更新POSTへの直リンクはない。

## 5. 検証結果

### 静的境界確認

- `git diff --stat` で以下に差分がないことを確認：`src/main/java/.../service/ExcelExportService.java`、`src/main/resources/mapper/*.xml`、`src/main/resources/schema.sql`、`src/main/resources/application.properties`。
- `app.version` は `v2.6.2` のまま不変（`src/main/resources/application.properties` と `target/classes/application.properties` を照合し一致を確認）。**バージョン変更なし。理由: Cycle 22は案内UIのみで、P2不変条件に従った。**
- `git status --short` で `src/main/resources/templates/` 配下に検証スクリプト等の混入がないことを確認（新規は`guide/index.html`のみ）。

### ビルド・テスト

- `.\mvnw.cmd -q -DskipTests compile`：成功。
- `.\mvnw.cmd -q test`：**exit code 0で成功**（既存12件 + 新規`GuideControllerTest`1件の計13件、全件成功。件数は固定値として断定していない）。`GuideControllerTest`はDBに接続しない`@WebMvcTest`スライステストとして実装した。

### 実画面確認について

開発サーバーの起動・ブラウザでのUI実機確認（hover/Tab/タップでのツールチップ表示、幅360〜480pxでの`？使い方`到達性、`/guide`各リンクの遷移確認）は、Kazumaxからの明示的な指示により**今回は実施していない**。理由: ローカル環境で別プロセスが同一ポートを占有しファイルロックが発生する問題が生じたため、Kazumaxの判断で「ビルド・自動テストの合格をもってP3完了とし、実UI見た目確認はKazumax/Dex側で行う」こととなった。

このため、P3報告として明記する：**DB書込み、保存、Excelダウンロード、印刷状態更新、削除はもちろん、ブラウザでの実画面確認（GET表示含む）自体を実施していない。** 静的差分確認とビルド・自動テストのみで安全性を担保している。Dex(P4)および実機確認では、この点を踏まえてUIの見た目・到達性・アクセシビリティ動作を重点的に確認してほしい。

## 6. compile / version

変更なし。`app.version=v2.6.2`のまま（`docs/PROJECT_RULES.md`のバージョン管理ルール上、マニュアル・ドキュメントのみの変更ではないが、P2指示書の不変条件に従い今回のUIテンプレート・CSS・GET専用Controller追加でもバージョンアップは行っていない — Air Blueprint 0(#7)およびP2「4. アプリケーション実装の必須テクニカル指示 4.4」の明示的な指示による例外）。

## 7. 次のステップ

Dex(P4)によるDIFFレビューを依頼する。特に以下を重点確認いただきたい：

- 差分が許可範囲（案内UI）だけで、保存・金額・Excel・DB・Mapper・既存URLに一切触れていないこと。
- `/guide`がGET専用でService/Repository/Mapperを呼ばないこと。
- 狭い幅での`？使い方`到達性と既存ナビ・操作ユーザー非干渉（実機未確認のため、コードレビューでの確認をお願いしたい）。
- tooltipの重複初期化なし、既存`data-bs-html="true"`の表示維持、クリック・キーボード対応。
- P1の文言、常時注意文、FAQ、5カード、既存メッセージ維持の漏れがないこと。

Kazumax確認レベル: 実UI見た目確認が未実施のため、Dex(P4)レビュー後、Kazumaxによる実機での`軽い確認`（`？使い方`到達性、いくつかのツールチップの表示）を推奨する。

## 8. commit / push

commit hash: `852a021`（`[v2.6.2] Cycle 22: 初見利用者ガイド(/guide)・ツールチップ実装(バージョン変更なし・案内UIのみ)`）。
