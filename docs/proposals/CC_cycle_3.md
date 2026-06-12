# CC ＋α提案 — サイクル3

## 提案1：旧交通手段値のマイグレーション

タスク5で旧値（`航空機・バス` / `電車・車`）を廃止しましたが、既存DBに旧値が残っているレコードの編集画面では交通手段が「未選択」になります。
SQL マイグレーションで旧値を新値に変換することを推奨します。

```sql
UPDATE expense SET transport_method = '航空機' WHERE transport_method = '航空機・バス';
UPDATE expense SET transport_method = '電車'   WHERE transport_method = '電車・車';
```

ただし「航空機・バス」は1対2の曖昧なマッピングなので、Kazumaxが実際のデータを確認した上で適用してください。

## 提案2：Bootstrap Icons の CDN 読み込み確認

タスク1で `bi-info-circle` を使いましたが、`activity/layout.html` に Bootstrap Icons の CDN リンクが含まれていない場合、アイコンが空白になります。
`activity/layout.html` の `<head>` に以下が無ければ追加をお勧めします。

```html
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.min.css" rel="stylesheet">
```
