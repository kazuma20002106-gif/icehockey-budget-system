# [C4 Take2: CC(P3) => Dex(P4)]

## ステータス

- CC(P3) Take2 修正完了
- Dex(P4) レビュー待ち

---

## 修正内容

### 1. schema.sql — 固定 ID 除去

**修正前**:
```sql
INSERT IGNORE INTO users (id, name, phone_number) VALUES (1, '齋藤 和明', '090-5288-9928');
INSERT INTO system_settings ... SELECT ... FROM users WHERE name = '齋藤 和明' LIMIT 1
ON DUPLICATE KEY UPDATE setting_value = setting_value;
```

**修正後**:
```sql
INSERT INTO users (name, phone_number)
SELECT '齋藤 和明', '090-5288-9928'
WHERE NOT EXISTS (
    SELECT 1 FROM users
    WHERE name = '齋藤 和明' AND phone_number = '090-5288-9928'
);

INSERT INTO system_settings (setting_key, setting_value)
SELECT 'active_user_id', CAST(id AS CHAR)
FROM users
WHERE name = '齋藤 和明' AND phone_number = '090-5288-9928'
ORDER BY id LIMIT 1
ON DUPLICATE KEY UPDATE setting_value = setting_value;
```

既存 DB で `id=1` が別ユーザーに使われていても齋藤和明を正しく登録。`active_user_id` は未設定時のみ実 ID をセット、既存値は維持。

---

### 2. GlobalControllerAdvice — HttpServletRequest + catch 改善

- `addGlobalAttributes(Model, HttpServletRequest)` に変更
- `catch` 時に空リスト・null を明示的に model へセット
- `currentRequestUri` を `request.getRequestURI()` から model に追加

---

### 3. activity/layout.html・layout.html — Thymeleaf 式修正

| 変更前 | 変更後 |
|---|---|
| `th:value="${#request.requestURI}"` | `th:value="${currentRequestUri}"` |
| `redirect=${#request.requestURI}` | `redirect=${currentRequestUri}` |
| `${activeUser != null} ? '操作: ' + ${activeUser.name} : '...'` | `${activeUser != null ? '操作: ' + activeUser.name : '...'}` |

両 layout.html（`activity/layout.html` と `layout.html`）を修正済み。

---

## コンパイル結果

```
.\mvnw compile
[INFO] BUILD SUCCESS
[INFO] Total time:  22.262 s
[INFO] Finished at: 2026-06-12T17:54:43+09:00
```

## src/target バージョン確認

| ファイル | app.version |
|---|---|
| `src/main/resources/application.properties` | v1.8.9 ✅ |
| `target/classes/application.properties` | v1.8.9 ✅ |

## コミット情報

- コミットハッシュ: `8105ede`
- メッセージ: `[v1.8.9] C4 Take2: schema固定ID除去・GlobalAdvice改善・Thymeleaf式修正`

## git push 結果

```
git push origin main
→ 66e547f..8105ede  main -> main
```

---

## Dex(P4) に確認してほしい観点

1. **schema.sql の WHERE NOT EXISTS**: MySQL で `INSERT ... SELECT ... WHERE NOT EXISTS (...)` の構文が正しく動作するか確認。
2. **currentRequestUri のリダイレクト先**: POST `/users/switch` 後に `redirect` パラメータで元画面へ戻る動作を `/activity` と `/` 両方で確認。
3. **GlobalControllerAdvice の catch**: DB 未初期化時（初回起動直後）に空リストが返り、画面がクラッシュしないことを確認。

## ⏩ 次の担当への合図（コピペ用）

```text
CCの実装が終わったよ。最新のファイルを読んでDIFFレビュー（P4）をして！
```
