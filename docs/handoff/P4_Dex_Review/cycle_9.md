# [C9: Dex(P4) ⇒ Kazumax] Cycle 9 DIFFレビュー

## レビュー結果

**OK**

最新コミット:

- `5860465 [v2.3.2] Cycle 9: 情報量が少ない画面のUI幅・余白最適化`
- `c322c0d [v2.3.2] P3報告書を追加 (cycle_9)`

最新P3:

- `docs/handoff/P3_CC_to_Dex/cycle_9.md`

## 確認内容

### 1. 変更対象の限定

OK。

P2指定対象どおり、実装差分は以下に限定されている。

- `src/main/resources/templates/members/index.html`
- `src/main/resources/templates/export/index.html`
- `src/main/resources/static/css/style.css`
- `src/main/resources/application.properties`（バージョン更新のみ）

`activity/list.html` と `activity/form.html` は変更なし。

### 2. 専用ラッパークラス

OK。

`style.css` に `.content-narrow-wrap` が追加され、`max-width: 900px; margin: 0;` で情報量が少ない画面だけ左寄せ・適正幅に制限されている。

適用箇所:

- `members/index.html`
- `export/index.html`

共通 `layout.html` や既存 `.main-content` は触っていないため、他画面への影響は限定的。

### 3. 名簿管理

OK。

- 新規メンバー追加フォームが `col-auto` + 固定幅になり、横幅いっぱいに伸びなくなっている。
- 氏名、年齢、種別、出発地点の入力幅が内容量ベースに調整されている。
- 登録メンバー一覧のID、年齢、種別、操作列が固定幅化されている。
- 年齢入力は `max-width:68px` で過剰な空白が抑制されている。

### 4. 提出データ出力・集計

OK。

- 画面全体が `.content-narrow-wrap` で最大幅900pxに制限されている。
- 登録済み事業数カードが `col-auto` 化され、横長カードにならない。
- 出力対象テーブルのチェック列、ID列、期日列が固定幅化されている。
- 出力様式選択エリアが `d-flex flex-wrap gap-2` + `form-select-sm` + `btn-sm` でコンパクトになっている。

### 5. バージョン

OK。

- `app.version=v2.3.2`

## Dex環境での検証

- `git diff --check 078175d..HEAD`: 問題なし。
- `git show 5860465` で実装差分を確認。
- `git diff --name-only 078175d..HEAD` で変更対象を確認。
- `.\mvnw.cmd -q -DskipTests compile` はDex環境のMaven Wrapper起動問題で実行不可。
  - エラー: `Cannot index into a null array. Cannot start maven from wrapper`
  - この件は別提案 `docs/proposals/Dex_maven_wrapper_fix.md` に記録済み。

## 残る確認

今回は見た目の改善なので、最終判断はKazumaxの実機目視確認が必要。
コード上はP2の意図どおりだが、900px幅が狭すぎる/広すぎる場合は、次回微調整で `max-width` を変更すればよい。

## Kazumax向け最終確認チェックリスト

1. 名簿管理画面が横幅いっぱいに伸びず、左側にコンパクトにまとまっている。
2. 新規メンバー追加の氏名・年齢・種別・出発地点欄が、内容量に合った幅になっている。
3. 登録メンバー一覧の年齢欄・種別欄が広すぎず、氏名/出発地点も見づらくない。
4. 提出データ出力・集計画面のカードと表が横に間延びしていない。
5. 出力様式セレクトとプレビュー/ダウンロードボタンが1行または自然な折り返しで収まる。
6. 活動一覧と活動入力の横幅が狭くなっていない。
7. 画面バージョンが `v2.3.2` になっている。

## 判定

Cycle 9 は **P4レビューOK**。

