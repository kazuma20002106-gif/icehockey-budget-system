# [C3: Dex(P4) => CC(P3) Take2 Review]

## 判定

OK

## ステータス

- Dex(P4) Take2 レビュー完了
- Kazumax 最終確認待ち

## レビュー対象

- Take2 実装コミット: `aaf7989` `[v1.8.6] C3 Take2: 距離欄空/0時の交通費クリア漏れを修正`
- P3 Take2 報告書: `docs/handoff/P3_CC_to_Dex/cycle_3_take2.md`
- 対象ファイル:
  - `src/main/resources/templates/activity/form.html`
  - `src/main/resources/application.properties`

## レビュー結果

前回P4で差し戻した「距離欄を空または0にしたとき、古い交通費が残る問題」は修正済みです。

確認内容:

- `calculateTransportCostForRow(row)` が追加され、距離が `NaN` / 空 / `0` の場合は交通費が `0` にクリアされる。
- `recalculateTransportCosts()` が全行に対して `calculateTransportCostForRow(row)` を呼ぶため、単価変更時にも古い交通費が残らない。
- `.distance-input` の `input` イベントも同じ helper を使うため、手入力で距離を消した瞬間に交通費と合計が更新される。
- `app.version` は `src/main/resources/application.properties` と `target/classes/application.properties` の両方で `v1.8.6`。
- `aaf7989` は `origin/main` に反映済み。

## Dex側の検証メモ

- Dex環境では `.\mvnw compile` が Maven wrapper 起動時に `Cannot start maven from wrapper` で失敗しました。前回と同じ環境依存の wrapper 起動エラーです。
- CC報告では `.\mvnw compile` が `BUILD SUCCESS` で、`src` / `target/classes` の `app.version=v1.8.6` 同期も確認済みです。
- Dex側でも `src` / `target/classes` の `app.version=v1.8.6` は確認しました。

## Kazumax 最終確認チェックリスト

- 活動日入力画面の様式2-6で、距離欄に数値を入れると交通費が `距離 × 単価` で即時更新されること。
- 距離欄を空にしたとき、交通費が `0` になり、旅費合計も即時更新されること。
- 距離欄を `0` にしたとき、交通費が `0` になり、旅費合計も即時更新されること。
- 交通費単価を変更したとき、全行の交通費が再計算されること。
- 画面上のバージョンが `v1.8.6` になっていること。

## 提案

提案なし。

## ⏩ 次の担当への合図（コピペ用）

```text
Kazumaxへ。Cycle 3 Take2 のDex(P4)レビューはOKです。docs/handoff/P4_Rollback/cycle_3_take2.md の最終確認チェックリストに沿って、画面で距離欄の空/0入力、交通費単価変更、バージョンv1.8.6表示を確認してください。
```
