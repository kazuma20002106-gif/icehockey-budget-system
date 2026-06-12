# [C4: CC(P3) => Dex(P4)]

## ステータス

- CC(P3) 実装完了
- Dex(P4) レビュー待ち

---

## 変更ファイル一覧

### 新規作成
| ファイル | 内容 |
|---|---|
| `src/main/java/.../model/User.java` | ユーザーモデル（id, name, phoneNumber）|
| `src/main/java/.../model/SystemSetting.java` | システム設定モデル（settingKey, settingValue）|
| `src/main/java/.../mapper/UserMapper.java` | ユーザー CRUD インターフェース |
| `src/main/java/.../mapper/SystemSettingMapper.java` | 設定取得/upsert インターフェース |
| `src/main/resources/mapper/UserMapper.xml` | ユーザー MyBatis XML |
| `src/main/resources/mapper/SystemSettingMapper.xml` | 設定 MyBatis XML |
| `src/main/java/.../service/UserSettingService.java` | アクティブユーザー CRUD/切替サービス |
| `src/main/java/.../controller/UserSettingController.java` | /users/switch, /new, /edit/{id} |
| `src/main/java/.../controller/GlobalControllerAdvice.java` | 全画面へ users/activeUser 付与 |
| `src/main/resources/templates/users/form.html` | ユーザー登録・編集フォーム |

### 変更
| ファイル | 変更内容 |
|---|---|
| `src/main/resources/schema.sql` | users/system_settings テーブル追加、初期データ、マイグレーション UPDATE |
| `src/main/resources/application.properties` | v1.8.7 → v1.8.8 |
| `src/main/resources/templates/activity/layout.html` | navbar にユーザー切替ドロップダウン追加 |
| `src/main/resources/templates/layout.html` | 同上 |
| `src/main/resources/templates/activity/form.html` | 氏名列 th/td に name-col クラス付与 |
| `src/main/resources/static/css/style.css` | name-col / name-input / name-mirror の min-width 追加 |
| `src/main/java/.../service/ExcelExportService.java` | UserSettingService 注入、populate24Side() に記入責任者印字 |

---

## 実装内容の要約

### 1. 過去データの交通手段マイグレーション
`schema.sql` 末尾に idempotent な UPDATE を追加：
```sql
UPDATE expenses SET transport_method = '電車'  WHERE transport_method = '電車・車';
UPDATE expenses SET transport_method = '航空機' WHERE transport_method = '航空機・バス';
```
毎回起動時に実行されるが既に変換済みの行には影響なし。

### 2. 様式2-5/2-6 氏名欄幅修正
`style.css` に追加：
```css
#rosterTable th.name-col, #rosterTable td.name-col,
#expenseTable th.name-col, #expenseTable td.name-col { min-width: 160px; }
#rosterTable .name-input, #expenseTable .name-mirror { min-width: 140px; }
```
`form.html` の名簿・支出テーブルの氏名列 th/td（テンプレート行含む）に `class="name-col"` を付与。

### 3. 簡易操作ユーザー設定

#### DB テーブル
- `users`: id, name, phone_number, created_at
- `system_settings`: setting_key (PK), setting_value

#### 初期データ
- `users` に id=1, 齋藤 和明, 090-5288-9928 を `INSERT IGNORE` で登録
- `system_settings` の `active_user_id` は未設定時のみ `齋藤 和明` の id をセット（`ON DUPLICATE KEY UPDATE setting_value = setting_value` で既存値を維持）

#### 操作ユーザー設定の使い方
1. ナビゲーションバー右側の「操作: 齋藤 和明 ▼」をクリック
2. ドロップダウンから切替先ユーザーを選択 → 即時切替
3. 「＋ 新規登録」→ 氏名・電話番号を入力して保存
4. 「編集」→ アクティブユーザーの氏名・電話番号を変更

### 4. 様式2-4 記入責任者・電話番号の自動印字

テンプレートの row 47（0-indexed row 46）が `A47:AK47` の単一結合セルと確認。
`ExcelExportService.populate24Side()` 末尾で `col 0` に書き込み：

```java
writeSafe(sheet, 46, 0,
    "記入責任者氏名（　" + activeUser.getName()
    + "　）　　電話番号（　" + activeUser.getPhoneNumber() + "　）");
```

`colOffset == 0` / `colOffset == 17` 両方の呼び出しで実行されるが、
同一結合セル（A47）への書き込みのため最終値は右側（colOffset=17）呼び出しの内容になる。
どちらも同じアクティブユーザーを参照するため問題なし。

### 5. 様式2-4 丸囲み座標確認
xlsx テンプレートを openpyxl で確認：
- R7C4 = `強化練習・・・遠征試合`（0-indexed row6, col3 = Apache POI row6, col3+colOffset）
- R11C4 = 種別ラベルセル（成年男子/女子・少年男子/女子）

既存の `drawEllipse` 座標を確認：
- 強化練習: `(6, 4, 7, 9)` → テンプレートのセル範囲と一致
- 遠征試合: `(6, 12, 7, 17)` → 同一行の右側セルと一致
- 成年男子: `(10, 4, 11, 8)` → 種別行と一致
- 各右側: `+17` offset で対応

**結論: 既存座標は正しく、変更不要。**

---

## コンパイル結果

```
.\mvnw compile
[INFO] BUILD SUCCESS
[INFO] Total time:  20.257 s
[INFO] Finished at: 2026-06-12T17:44:25+09:00
```

## src/target バージョン確認

| ファイル | app.version |
|---|---|
| `src/main/resources/application.properties` | v1.8.8 ✅ |
| `target/classes/application.properties` | v1.8.8 ✅ |

## コミット情報

- コミットハッシュ: `66e547f`
- メッセージ: `[v1.8.8] C4: 操作ユーザー設定・交通手段マイグレーション・氏名欄幅・様式2-4記入責任者印字`

## git push 結果

```
git push origin main
→ 2f5fdea..66e547f  main -> main
```

---

## Dex(P4) に確認してほしい観点

1. **ユーザー切替後のリダイレクト**: `#request.requestURI` を使って元の画面へ戻る実装。Thymeleaf の `#request` が activity/layout と layout の両方で利用可能か確認。
2. **GlobalControllerAdvice の起動時例外**: DB 未初期化時に try-catch で握りつぶす実装。アプリ起動順序によっては初回起動に問題がないか確認。
3. **記入責任者セルへの二重書き込み**: 2活動を1シートに出力する際、colOffset=0 の後に colOffset=17 で同じ結合セルに上書きする挙動。問題なければ OK。
4. **丸囲み座標**: 実際にサンプルデータで Excel を出力し、強化練習・遠征試合・各種別の丸囲みがテンプレートのラベル文字上に正確に重なるか目視確認を推奨。

## ⏩ 次の担当への合図（コピペ用）

```text
CCの実装が終わったよ。最新のファイルを読んでDIFFレビュー（P4）をして！
```
