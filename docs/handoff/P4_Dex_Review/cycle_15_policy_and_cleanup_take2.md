[C15: Dex(P4) => Kazumax]

# Cycle 15 Take2 P4レビュー: OK

## 判定

**OK / Cycle 15完了**

CCのTake2修正は、`docs/handoff/P4_Rollback/cycle_15_policy_and_cleanup.md` の差し戻し指示を満たしています。

Take1で見つかった「編集保存時に既存の個人雑費 `miscellaneousCost` が消える可能性」は、`activity/form.html` にhidden inputを追加することで解消されています。
同じ保存経路で消える可能性があった `receiptDate` も保持対象に含めた判断は妥当です。

## サブレビュー利用判断

**使用。**

理由:
- Take2はDB保存、2-6表示、hidden input、金額帳票一致に触るため。
- 編集保存時のPOST名・JS再採番・既存データ保持は、Dex単独より複数視点で見た方が安全なため。

デクスクルーAには以下を確認させ、Dex本体レビューへ統合しました。

- Take2差分範囲
- `miscellaneousCost` / `receiptDate` hidden inputのPOST名
- JSの `IDX` 置換と `reindexAll()` の影響
- 2-2系集計へ個人雑費が混入していないこと
- version / compile / git status / push状態

統合結果:
- デクスクルーAのOK確認を採用。
- 報告書のcommit記載が実装コミット `2fc6a33` 中心で、最新HEAD `0026794` まで明示し切れていない点は軽微な報告ズレとして扱う。`0026794` はTake2報告書のcommit hash追記のみで、コード影響はない。

## Findings

**差し戻し事項はありません。**

## 確認内容

### 1. 差分範囲

Take2の実装差分は以下に限定されています。

- `src/main/resources/templates/activity/form.html`
- `src/main/resources/application.properties`
- handoff記録

Take2では以下への差分はありませんでした。

- `src/main/java`
- `src/main/resources/mapper`
- `src/main/resources/schema.sql`
- `src/main/java/.../service/ExcelExportService.java`
- `src/main/java/.../controller/ExportController.java`
- `src/main/resources/*.xlsx`

したがって、2-2 / 2-2-1 / 2-3 系へ個人雑費を足す変更は入っていません。

### 2. `miscellaneousCost` / `receiptDate` のhidden保持

既存行:

```html
<input type="hidden" th:name="|expenses[${stat.index}].miscellaneousCost|" th:value="${e.miscellaneousCost}">
<input type="hidden" th:name="|expenses[${stat.index}].receiptDate|" th:value="${e.receiptDate}">
```

新規行テンプレート:

```html
<input type="hidden" name="expenses[IDX].miscellaneousCost" value="0">
<input type="hidden" name="expenses[IDX].receiptDate" value="">
```

どちらもフォーム送信対象の `<td>` 内にあり、POST名も `ProjectService.saveProjectData(...)` が受け取る `expenses[n]` 形式と一致しています。

### 3. JS再採番

`addRow()` は `expenseTemplate` の `IDX` を置換したうえで `reindexAll()` を呼びます。
`setRowNames()` は `[name]` を持つ要素すべてを再採番するため、hidden inputも `expenses[n]` として追従します。

このため、行追加・行削除後にhidden inputだけ古いindexで残るリスクは低いと判断します。

### 4. 金額・帳票整合

Take1でOK確認済みだった以下は維持されています。

- `/activity` の `決算書計上額` は `miscellaneousCost` を含まない。
- 交通費、宿泊費、事業サマリ費目、旅行雑費は維持。
- legacy 2-2 / 年度末2-2系には個人雑費を足していない。
- 2-6 preview / Excel側の個人雑費表示コードは残っている。

CC報告では、個人雑費500円・受領日06/30の一時データを作り、編集保存後もDB/2-6 previewで値が保持されることを実測確認しています。
Dex側では静的構造とcompileで裏取りし、報告内容と矛盾する差分は見つかりませんでした。

### 5. version / compile / git

Dex側でも確認しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
git status --short --untracked-files=all
```

結果:

- sandbox内compile: Maven親POM解決のネットワーク制限で失敗
- 外側権限で同じcompileを再実行: 成功
- `src/main/resources/application.properties`: `app.version=v2.4.8`
- `target/classes/application.properties`: `app.version=v2.4.8`
- `git status --short --untracked-files=all`: 出力なし
- `main` と `origin/main`: `0026794686a281aad668595f07982472a8a50226` で一致
- `app_run_latest.pid`: ignore対象のまま

## 残リスク

大きな残リスクはありません。

軽微な注意点:
- CC報告書の本文は実装コミット `2fc6a33` を中心に書かれていますが、最新HEADは報告書追記コミット `0026794` です。コード差分は `2fc6a33` に含まれており、`0026794` はドキュメントのみなので機能リスクはありません。
- Dex側では実ブラウザ保存/JDBC再現までは再実施していません。CCの実測報告、静的構造、compile結果、差分範囲からOKと判断します。

## Kazumax向け短縮チェック

実機で軽く見るなら、次だけ確認してください。

1. `/activity?year=2026` を開き、表示ラベルが「決算書計上額」になっている。
2. 2026年度が事業件数8件・延べ参加人数30名・決算書計上額481,179円で表示される。
3. どれか1件を編集画面で開き、参加者追加ボタンを押しても画面が崩れず、保存できる。
4. legacy「提出データ出力・集計」から2-2 previewと2-6 previewが開ける。
5. 2-6 previewで個人別明細が表示される。

## 次の担当

**Kazumax確認待ち。**

Cycle 15はAIレビュー上OKです。
次に進む場合は、Air(P1)へ次Cycleの方針整理を依頼してください。
