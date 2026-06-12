# [C3: Dex(P4) => CC(P3) Take2]

## 判定

差し戻し（NG）

## ステータス

- Dex(P4) レビュー完了
- CC(P3) Take2 修正待ち

## レビュー対象

- 実装コミット: `f0e3fb9` `[v1.8.5] C3: ツールチップ化・視認性・sticky隙間修正・交通費自動計算・交通手段4択・Excel連携`
- P3報告書: `docs/handoff/P3_CC_to_Dex/cycle_3.md`
- 主な対象ファイル:
  - `src/main/resources/templates/activity/form.html`
  - `src/main/resources/static/css/style.css`
  - `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
  - `src/main/resources/application.properties`

## 修正指示

### 1. 距離欄を空または0にしたとき、古い交通費が残る問題を修正してください

`src/main/resources/templates/activity/form.html` の交通費自動計算で、距離欄を空にした場合や `0` にした場合に、交通費欄へ以前の値が残る可能性があります。

該当箇所:

```javascript
costInput.value=(!isNaN(dist)&&dist>=0)?dist*rate:costInput.value;
```

この実装だと、距離欄を空にした瞬間は `parseInt('', 10)` が `NaN` になり、`costInput.value` が古い値のまま維持されます。ユーザー視点では「距離を消したのに交通費と合計だけ残る」状態になり、Excel出力や合計金額の誤りにつながります。

また、`recalculateTransportCosts()` 本体も現在は `dist > 0` のときだけ交通費を書き換えるため、単価変更時や距離スピナー経由でも、距離が空/0の行に古い交通費が残り得ます。

修正方針:

- `.distance-input` の `input` イベントで距離が空または不正値の場合は、該当行の交通費を `0` または空文字にクリアしてください。
- `recalculateTransportCosts()` でも、距離が空/不正/0 の場合は交通費を `0` または空文字にクリアしてください。
- クリア後に必ず `calculateTotals()` を呼び、合計表示も即時更新してください。
- 金額欄をユーザーが手入力した場合の既存挙動は維持して構いません。ただし距離または単価が変更された時点では、自動計算値またはクリア値で上書きされる仕様で問題ありません。

実装例:

```javascript
function calculateTransportCostForRow(row) {
    const rate = parseInt(document.getElementById('transportRate').value, 10) || 17;
    const distInput = row.querySelector('.distance-input');
    const costInput = row.querySelector('input[name*=".transportCost"]');
    if (!distInput || !costInput) return;

    const dist = parseInt(distInput.value, 10);
    costInput.value = (!isNaN(dist) && dist > 0) ? dist * rate : 0;
}
```

このような小さな helper にまとめると、`input` イベントと `recalculateTransportCosts()` のロジック重複も避けられます。

## OKだった点

- 日付注意書きの `small` 2行削除とツールチップ化はP2どおり。
- ツールチップの薄灰色背景、濃い文字、濃い枠線はP2どおり。
- Sticky Header のCSS移管と隙間対策は、セレクタが `#rosterTable` / `#expenseTable` に限定されており妥当。
- 交通手段セレクトは既存行・テンプレート行ともに4択化済み。
- Excel出力は新しい交通手段名を1行目、交通区間を3行目に出す形へ変更されており、P2の方向性に合っています。
- `src/main/resources/application.properties` と `target/classes/application.properties` はどちらも `app.version=v1.8.5` でした。

## Dex側の検証メモ

- Dex環境では `.\mvnw compile` / `.\mvnw.cmd compile` が wrapper 起動時に `Cannot start maven from wrapper` で失敗しました。CC報告では `BUILD SUCCESS` なので、Take2後にCC側で再度 `.\mvnw compile` を実行して結果をP3報告に記載してください。
- `mvn` コマンドはDex環境にはインストールされていませんでした。

## Take2 完了時の必須作業

1. `form.html` の交通費自動計算を修正する。
2. `app.version` を `v1.8.6` に更新する。
3. `.\mvnw compile` を実行する。
4. `src/main/resources/application.properties` と `target/classes/application.properties` がどちらも `v1.8.6` であることを確認する。
5. 修正をコミットする。
6. 必ず `git push origin main` を実行する。
7. `docs/handoff/P3_CC_to_Dex/cycle_3_take2.md` を作成して、修正内容・compile結果・コミットハッシュ・push結果を書く。
8. Kazumax向けチャット報告に「GitHubへプッシュしました」と明記する。

## 提案

提案なし。

## ⏩ 次の担当への合図（コピペ用）

```text
CCへ。docs/handoff/P4_Rollback/cycle_3.md を読んで、Take2修正をお願いします。距離欄を空/0にしたとき古い交通費が残る問題を修正し、app.version=v1.8.6、.\mvnw compile、src/target同期確認、コミット、git push origin main まで実施してください。完了報告は docs/handoff/P3_CC_to_Dex/cycle_3_take2.md に作成し、Kazumax向け報告には「GitHubへプッシュしました」と明記してください。
```
