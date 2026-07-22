# [C9: Dex(P4) ⇒ Kazumax/CC] Cycle 9 事後DIFFレビュー Take3

## 判定

**P4 OK**

Cycle 9 Take3 のツール本体修正は、差し戻し元 `docs/handoff/P4_Rollback/cycle_9_post_review.md` の必須項目を満たしていると判断する。

ただし、Dex環境ではMaven Wrapperの既知起動問題によりコンパイルを再実行できなかったため、コンパイル成功はCCのP3報告を採用する。

## レビュー対象

- P3: `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take3.md`
- 差し戻し元: `docs/handoff/P4_Rollback/cycle_9_post_review.md`
- 実装コミット: `5ebdb25 [v2.3.6] Cycle9 Take3: ExcelExportService trailing whitespace除去・long型キャスト除去・検証スクリプト削除`
- 状態更新コミット: `b36b8f9 [v2.3.6] CURRENT_STATUS更新: Cycle9 Take3完了・Dex P4レビュー待ちに更新`

## Findings

**ブロッカーなし。**

金額計算、セル座標、不要ソースファイル除去、trailing whitespace除去、long出力化、バージョン更新のいずれも、今回のP4対象としては許容範囲。

## 差し戻し項目の確認

### 1. `replace.py`, `test.py`, `src/main/resources/templates/test.py` の削除

**OK**

Dex環境で以下を確認した。

- `replace.py`: 存在しない
- `test.py`: 存在しない
- `src/main/resources/templates/test.py`: 存在しない
- `git ls-files` でも上記3ファイルは管理対象外
- `src/main/resources/templates` 配下に `.py` は残っていない

注意点として、Dex環境には古いビルド成果物 `target/classes/templates/test.py` が残っていた。
これは `target/` 配下で `.gitignore` 対象であり、ソース・コミットには含まれない。
ただし、最終配布やパッケージング前には `clean` を含むビルド、または `target/` の削除後ビルドを推奨する。

### 2. 対象外差分のコミット除外

**OK**

実装コミット `5ebdb25` の変更対象は以下。

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/application.properties`
- `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take2.md`
- `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take3.md`

マニュアル再整理の差分は別コミット `b8028a7` として分離されており、Cycle 9本体コミットには混入していない。

### 3. trailing whitespace除去

**OK**

`git diff --check 5ebdb25^ 5ebdb25` で警告なし。

### 4. compile結果の記録

**条件付きOK**

P3 Take3には以下が記録されている。

```text
.\mvnw.cmd -q -DskipTests compile
exit: 0（エラーなし）
```

Dex環境では同コマンドが既知問題で失敗した。

```text
Cannot index into a null array.
Cannot start maven from wrapper
```

通常の `mvn` コマンドもDex環境には存在しない。
そのため、Dex側での再コンパイルは不可。CC側の成功記録を採用する。

### 5. `(int)` キャスト除去とlong出力化

**OK**

`populate22Summary` 内の金額集計は `long` 配列・`long` 合計値へ変更され、カテゴリ別/全体合計とも `(int)` キャストなしで出力される。

追加された `writeSafeNumeric(Sheet, int, int, long)` は `cell.setCellValue((double) value)` を使っており、Excel数値として出力される。

## コード正確性レビュー

### 金額集計

**OK**

- 全体合計は、対象プロジェクト全体の交通費・宿泊費・旅行雑費・駐車料金・借用料・補償費・需用費・役務費を合算している。
- カテゴリ別合計は `Project#getTargetCategory()` から成年男子、少年男子、成年女子、少年女子へ分類している。
- UI側の選択肢も同じ4カテゴリのため、通常入力ではカテゴリ値が一致する。
- 旅行雑費は `summary.travelMiscCost × 参加人数 × summary.travelMiscDays` の既存仕様を維持している。
- `Expense#getMiscellaneousCost()` を様式2-2-1へ誤って混ぜていない。

### セル座標

**OK**

前回P4でテンプレート実読確認済みの座標と一致している。

- J16/J18/J20/J22/J24/J26/J28/J30: 決算額
- S列: 成年男子/少年男子
- AF列: 成年女子/少年女子
- 各費目の上段が成年、下段が少年

実装は0-indexedで `col=18` がS列、`col=31` がAF列、`offset=1` が少年行に対応する。

### ダミー値クリア

**OK**

対象費目行のS列/AF列について、成年・少年の両行を先に空文字で上書きし、その後0より大きいカテゴリ別金額のみ再出力している。
テンプレート由来のダミー数値が残る問題は解消される見込み。

### バージョン

**OK**

- `src/main/resources/application.properties`: `app.version=v2.3.6`
- `target/classes/application.properties`: `app.version=v2.3.6`

## 残る注意点

### `target/classes/templates/test.py` の古い成果物

Dex環境では `target/classes/templates/test.py` が残っている。
LastWriteTimeは `2026/06/30 9:47:38` で、Take3コミット前の古い成果物と見られる。

ソース側の `src/main/resources/templates/test.py` は削除済みのため、クリーンな環境では再混入しない。
ただし、Mavenの通常 `compile` は古い `target/classes` の不要ファイルを必ず消すとは限らない。
最終配布前は以下のどちらかを行うことを推奨する。

- `.\mvnw.cmd clean compile`
- `target/` 削除後に `.\mvnw.cmd -q -DskipTests compile`

これはP4 OKを妨げるブロッカーではなく、配布前の衛生チェックとして扱う。

## Kazumax向け実機確認チェックリスト

1. 「提出データ出力・集計」から、対象事業を複数選択して「まとめて（様式2-4・2-5・2-6一括）」を出力する。
2. 様式2-2-1のJ列で、交通費・宿泊費・旅行雑費などの決算額が対象事業合計になっていることを確認する。
3. S列/AF列の成年男子・少年男子・成年女子・少年女子の内訳欄に、テンプレートのダミー値が残っていないことを確認する。
4. 金額が0のカテゴリ欄が空白で、実金額があるカテゴリ欄だけ出力されることを確認する。
5. 画面フッターまたはアプリ表示で `v2.3.6` になっていることを確認する。

## 次担当

ツール本体のCycle 9 Take3は **P4 OK**。

現在はマニュアル整備Cycle 10が別軸で進行中のため、次はマニュアル側のP4レビューへ戻ってよい。

## Kazumax用短文

```text
Cycle 9 Take3のツール本体P4レビューはOKです。
詳細は docs/handoff/P4_Dex_Review/cycle_9_post_review_take3.md を読んでください。
次は保留していたマニュアル整備レビューに戻ってください。
```
