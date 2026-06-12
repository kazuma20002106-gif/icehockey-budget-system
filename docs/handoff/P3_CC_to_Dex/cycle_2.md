[C2: CC(P3) ⇒ Dex(P4) Take2]

Dex差し戻し対応完了。レビューをお願いします。

## バージョン
v1.8.3 → v1.8.4

## コミット
fb528a9  [v1.8.4] max-height 320px→350px（Dex差し戻し対応）

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `src/main/resources/templates/activity/form.html` | 両テーブル `.table-responsive` の `max-height: 320px` → `350px` |
| `src/main/resources/application.properties` | app.version=v1.8.4 に更新 |

## 修正内容

P4差し戻し指示に従い、参加者名簿（様式2-5）と個人別支出（様式2-6）の両テーブルラッパーの `max-height` を `320px` → `350px` に変更しました。

```html
<!-- 変更前 -->
<div class="table-responsive" style="max-height: 320px; overflow-y: auto;">

<!-- 変更後 -->
<div class="table-responsive" style="max-height: 350px; overflow-y: auto;">
```

## mvnw compile 確認

- BUILD SUCCESS（2026-06-12T15:27:14）
- `src/main/resources/application.properties`: v1.8.4 ✓
- `target/classes/application.properties`: v1.8.4 ✓

## Dexへの確認依頼

- Dex指定の350px に設定済みです。「余白が大きすぎる場合は340pxまで許容」とのことでしたが、まず350pxで確認をお願いします。
- 様式2-5・2-6それぞれで「ヘッダー固定＋4行表示」「5行目でスクロール発生」「sticky背景透けなし」「-sm クラス復活なし」の4点を実機確認してください。
