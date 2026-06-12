# [C4: Dex(P4) => CC(P3) Take2]

## レビュー結果

NGです。Cycle 4 の主要実装は入っていますが、既存DBで初期ユーザーが作成されない可能性と、Thymeleaf テンプレートでリクエストURI取得が壊れる可能性があります。以下を修正してください。

## 対象

- P2指示書: `docs/handoff/P2_Dex_to_CC/cycle_4.md`
- P3報告書: `docs/handoff/P3_CC_to_Dex/cycle_4.md`
- レビュー対象コミット: `66e547f`

## 修正指示

### 1. `schema.sql` の初期ユーザー登録を固定ID依存にしない

現在の実装:

```sql
INSERT IGNORE INTO users (id, name, phone_number) VALUES (1, '齋藤 和明', '090-5288-9928');
```

この実装だと、既存DBで `users.id = 1` が別ユーザーに使われている場合、`INSERT IGNORE` により `齋藤 和明` が登録されません。その結果、次の `active_user_id` 初期設定も空振りする可能性があります。

P2では「初期ユーザーIDは固定値で決め打ちせず、登録済みの `齋藤 和明` を検索して取得」と指示しているため、以下の方針に直してください。

- `id` を指定せずに `齋藤 和明 / 090-5288-9928` を登録する。
- 既に同じ氏名・電話番号のユーザーがある場合は重複作成しない。
- `active_user_id` は未設定の場合だけ、そのユーザーの実IDを設定する。
- 既存の `active_user_id` がある場合は上書きしない。

実装例:

```sql
INSERT INTO users (name, phone_number)
SELECT '齋藤 和明', '090-5288-9928'
WHERE NOT EXISTS (
    SELECT 1 FROM users
    WHERE name = '齋藤 和明'
      AND phone_number = '090-5288-9928'
);

INSERT INTO system_settings (setting_key, setting_value)
SELECT 'active_user_id', CAST(id AS CHAR)
FROM users
WHERE name = '齋藤 和明'
  AND phone_number = '090-5288-9928'
ORDER BY id
LIMIT 1
ON DUPLICATE KEY UPDATE setting_value = setting_value;
```

### 2. `#request.requestURI` を使わず、共通 model attribute に置き換える

`src/main/resources/templates/layout.html` と `src/main/resources/templates/activity/layout.html` で `#request.requestURI` を使っています。

Spring Boot 4 / Thymeleaf 3.1 系では `#request` のような Servlet API 由来の式オブジェクトが利用できない可能性が高く、画面表示時にテンプレート例外になるリスクがあります。

`GlobalControllerAdvice` に `HttpServletRequest` を受け取り、現在URIを model に渡してください。

実装例:

```java
@ModelAttribute
public void addGlobalAttributes(Model model, HttpServletRequest request) {
    try {
        model.addAttribute("users", userSettingService.getAllUsers());
        model.addAttribute("activeUser", userSettingService.getActiveUser());
    } catch (Exception e) {
        model.addAttribute("users", java.util.Collections.emptyList());
        model.addAttribute("activeUser", null);
    }
    model.addAttribute("currentRequestUri", request.getRequestURI());
}
```

テンプレート側は以下のように置き換えてください。

- `th:value="${#request.requestURI}"` -> `th:value="${currentRequestUri}"`
- `redirect=${#request.requestURI}` -> `redirect=${currentRequestUri}`

### 3. 操作ユーザー表示の `th:text` を単一式に整理する

現在の実装:

```html
<span th:text="${activeUser != null} ? '操作: ' + ${activeUser.name} : '操作ユーザー未設定'">
```

これはテンプレートパーサー依存で壊れやすいため、以下のように単一の式にしてください。

```html
<span th:text="${activeUser != null ? '操作: ' + activeUser.name : '操作ユーザー未設定'}">
```

`layout.html` と `activity/layout.html` の両方を修正してください。

### 4. `users` が空でもナビゲーションが落ちないようにする

`GlobalControllerAdvice` の catch 時に何も model へ入れないと、テンプレート側の `${users}` が null になります。初回起動やDB未初期化時でも画面が落ちにくいよう、catch時は空リストを渡してください。

```java
model.addAttribute("users", java.util.Collections.emptyList());
model.addAttribute("activeUser", null);
```

### 5. 再検証

修正後に以下を確認してください。

- `.\mvnw compile` が `BUILD SUCCESS`。
- `src/main/resources/application.properties` と `target/classes/application.properties` がどちらも `app.version=v1.8.9`。
- 既存DBで `users.id = 1` が埋まっていても、`齋藤 和明 / 090-5288-9928` が登録され、未設定時だけ `active_user_id` に入る。
- `/activity` と `/` の両方がテンプレート例外なく表示できる。
- 操作ユーザーの切替、新規登録、編集後に元画面へ戻れる。
- 様式2-4の記入責任者氏名・電話番号が引き続き印字される。

## 完了時の必須作業

1. `app.version=v1.8.9` に更新する。
2. `.\mvnw compile` を実行する。
3. `target/classes/application.properties` の `app.version=v1.8.9` を確認する。
4. 変更をコミットする。
5. `git push origin main` を実行する。
6. P3 Take2 報告書を `docs/handoff/P3_CC_to_Dex/cycle_4_take2.md` に作成する。
7. Kazumax向け報告には「GitHubへプッシュしました」と明記する。

## 次の担当への合図（コピー用）

```text
デクスから差し戻しがあったよ。最新のファイルを読んで修正して！
```
