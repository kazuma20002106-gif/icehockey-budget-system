# [C2: Dex(P4) ⇒ CC 修正差し戻し]

## 判定
差し戻し（NG）

## 対象
- コミット: `c3c14c8` `[v1.8.3] form.html UX改善：初期値・標準サイズ化・stickyヘッダー・高さ調整・ツールチップ・注釈修正`
- 主対象ファイル:
  - `src/main/resources/templates/activity/form.html`

## NG理由
要件4「縦スクロール領域の高さをヘッダー＋4行に最適化」について、現在の `max-height: 320px` では不足する可能性があります。

このアプリでは既存CSSにより `.table thead th` / `.table tbody td` / `.form-control` / `.form-select` に大きめの padding が設定されています。今回 `form-control-sm` / `form-select-sm` / `input-group-sm` を外して標準サイズ化したため、行高が増え、`320px` だと「ヘッダー1行＋4行」がぴったり表示されず、4行目が窮屈または一部スクロールになる懸念があります。

## CCへの修正指示
`src/main/resources/templates/activity/form.html` の両テーブル親divの `max-height` を `320px` から `350px` 前後へ変更してください。

該当箇所:
- 参加者名簿（様式2-5）の `.table-responsive`
- 個人別支出（様式2-6）の `.table-responsive`

修正例:

```html
<div class="table-responsive" style="max-height: 350px; overflow-y: auto;">
```

## 検証観点
- 様式2-5で、ヘッダー固定状態のまま「ヘッダー＋4行」が自然に見えること。
- 様式2-6で、ヘッダー固定状態のまま「ヘッダー＋4行」が自然に見えること。
- 5行目以降で縦スクロールが発生すること。
- Stickyヘッダーの背景が透けないこと。
- `form-control-sm` / `form-select-sm` / `input-group-sm` が対象テーブル内に復活していないこと。

## 提案
- まずは `350px` に変更してください。
- 実機確認で余白が大きすぎる場合のみ `340px` まで下げる調整を許容します。
- `320px` のまま完了扱いにはしないでください。

## 現在のステータス
P4レビュー結果: 差し戻し（NG）
