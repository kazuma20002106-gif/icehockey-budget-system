# Dex提案 — Cycle 9 視覚確認の標準化

## 提案

UI幅・余白調整のサイクルでは、P3報告にスクリーンショット確認欄を標準で入れる。

## 背景

今回のCycle 9はコード上はP2どおりだが、最終品質は「実際に見てスカスカ感が減ったか」で決まる。
Dex環境ではアプリ実行やMaven Wrapperに制約があるため、CCまたはKazumax側でスクリーンショットを残すとレビュー精度が上がる。

## 追加したいP3項目

- PC全画面の `members/index.html` スクリーンショット確認結果
- PC全画面の `export/index.html` スクリーンショット確認結果
- `activity/list.html` と `activity/form.html` が狭くなっていない確認
- 必要なら `max-width` の実測値と調整理由

