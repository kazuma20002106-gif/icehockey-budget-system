# [C7: Dex(P4) => CC(P3) Take2]

## P4レビュー結果

差し戻し（NG）。

電話番号の11桁・10桁フォーマット、様式2-6テーブルの余白削除、交通手段列の拡幅、Enterキー誤送信防止、サイドバーのバージョン項目削除はP1どおり実装されています。`app.version` と `target/classes` もv1.9.8で一致しています。

ただし、削除した `activity/layout.html` を参照する画面が2つ残っており、該当画面がテンプレートエラーで開けなくなります。

## 修正必須: 削除済みレイアウトへの参照を全廃する

P1は `activity/layout.html` を削除し、全画面を正規の `layout.html` へ一元化する仕様です。しかし、現在も次の2ファイルが削除済みテンプレートを参照しています。

### 1. 名簿管理画面

対象: `src/main/resources/templates/members/index.html:3`

現在:

```html
th:replace="~{activity/layout :: html(title='名簿管理', content=~{::div}, activePage='members')}"
```

修正:

```html
th:replace="~{layout :: html(title='名簿管理', content=~{::div}, activePage='members')}"
```

### 2. 操作ユーザー設定画面

対象: `src/main/resources/templates/users/form.html:3`

現在:

```html
th:replace="~{activity/layout :: html(title='操作ユーザー設定', content=~{::div}, activePage='')}"
```

修正:

```html
th:replace="~{layout :: html(title='操作ユーザー設定', content=~{::div}, activePage='')}"
```

修正後、`src/main/resources/templates` 全体を検索し、`activity/layout` への参照が0件であることを確認してください。

## 維持すること

- `activity/layout.html` の削除。
- `activity/form.html` と `activity/list.html` の共通レイアウト化。
- 正規サイドバーからバージョン表示を削除した修正。
- `User#getFormattedPhoneNumber()` の11桁 `3-4-4`、10桁 `4-2-4` 整形。
- プレビューおよびExcel3帳票での整形済み電話番号使用。
- 様式2-6テーブルコンテナの `p-0`。
- 交通手段列の `width:12%; min-width:110px`。
- textareaとbuttonを除くEnterキーの誤送信防止。

## Take2確認項目

1. `rg "activity/layout" src/main/resources/templates` が0件になる。
2. 活動一覧・活動入力・名簿管理・操作ユーザーの新規登録／編集がすべて表示できる。
3. 各画面で共通の上部バーと左メニューが表示される。
4. P1 Verification Planの電話番号、余白、交通手段、Enterキー確認を維持する。
5. 修正コミットを対象2テンプレートとバージョン更新へ限定する。

## テスト状況

- CC報告: `mvnw compile` BUILD SUCCESS。
- Dex環境: Maven Wrapperの既知エラーにより自動テスト未実行。
- 削除済みテンプレートへの参照2件は静的検索で再現済み。

P4レビュー結果: 差し戻し（NG）
