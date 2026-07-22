[C15: CC(P3) => Dex(P4) Take2]

# Cycle 15 Take2 修正完了報告

`docs/handoff/P4_Rollback/cycle_15_policy_and_cleanup.md` のP1指摘（編集保存時に既存の個人雑費`miscellaneousCost`が消える）に対応した。

## 変更ファイル一覧

- `src/main/resources/templates/activity/form.html`
  - 既存行テンプレート（`th:each="e, stat : ${activityForm.expenses}"`側）の宿泊費セル内に、`expenses[${stat.index}].miscellaneousCost` と `expenses[${stat.index}].receiptDate` のhidden inputを追加。
  - 新規行JSテンプレート（`#expenseTemplate`側）の宿泊費セル内にも、同様に `expenses[IDX].miscellaneousCost`（初期値0）・`expenses[IDX].receiptDate`（初期値空）のhidden inputを追加。
- `src/main/resources/application.properties`
  - `app.version` を `v2.4.8` に更新。

`Expense`モデル、mapper、schema、`ExcelExportService.java`、`ExportController.java`、`ActivityController.java`、2-2系集計ロジックは変更していない。

## `miscellaneousCost` hidden保持の実装内容

Dexの指示書の実装例通り、既存行には次を追加した。

```html
<input type="hidden" th:name="|expenses[${stat.index}].miscellaneousCost|" th:value="${e.miscellaneousCost}">
```

新規行のJSテンプレート側には次を追加した。

```html
<input type="hidden" name="expenses[IDX].miscellaneousCost" value="0">
```

配置場所は、テーブル構造として妥当な位置（`<tr>`の直下ではなく、既存の`accommodationCost`と同じ`<td>`内）とした。新規行テンプレートは `innerHTML.replace(/IDX/g, ...)` という文字列置換でクローンされる実装のため、追加したhidden inputの`IDX`も既存の仕組みでそのまま置換されることをブラウザで実際に新規行を追加して確認した。

### 対応範囲を`receiptDate`にも広げた理由

指示書では`receiptDate`の保持は「同じ編集保存で既存値が消えることが確認できた場合」の条件付き対応だった。`ProjectService.saveProjectData(...)`が参加者を全削除→再作成する同じ保存経路を`miscellaneousCost`と`receiptDate`の両方が通ること、かつフォームに`receiptDate`の入力欄が元々存在しなかったことから、`miscellaneousCost`と全く同じ理由で`receiptDate`も編集保存のたびに消える構造だと判断し、同じ考え方で先にhidden保持を追加した。実データ検証（下記）でも、対応前は消えていたはずの`receiptDate`が対応後は保持されることを確認した。

## 編集保存前後で個人雑費が消えないことの実測結果

環境に`mysql`クライアントが無いため、Cycle 14/15 Take1と同様に一時フォルダ`tmp_cycle15_audit/`にJDBCヘルパー（`Cycle15Take2Setup.java`）を作成し、SQLで直接テストデータを投入・確認・削除した。

### 手順と実測値

1. 一時データ作成: 事業「Cycle15Take2監査テスト」（2026年度・選手強化費・成年男子）、参加者「監査テストF」、Expense（交通費1,200円・宿泊費3,200円・個人雑費500円・期日06/29・受領日06/30）をJDBCで直接INSERT。
2. `/activity/18/edit` を開き、hidden inputに `expenses[0].miscellaneousCost=500`・`expenses[0].receiptDate=2026-06-30` が正しく反映されていることをブラウザのJSで確認。
3. 何も変更せず「保存する」ボタンをクリック（`ActivityController.save(...)` 経由で通常の編集保存フローを実行）。
4. 保存後、JDBCで`expenses`テーブルを直接SELECTし、以下を確認した。

```text
transport=1200 accommodation=3200 misc=500 expenseDate=2026-06-29 receiptDate=2026-06-30
```

修正前のコード（Take1時点）であれば、`miscellaneousCost`と`receiptDate`はフォームにフィールドが無いため、この保存操作で`null`または`0`相当に上書きされていたはずである。修正後は入力した500円・06/30がそのまま保持された。

## `/activity`の`決算書計上額`と2-2系合計の一致確認

| 画面 | 値 |
|---|---|
| `/activity`「決算書計上額」（テスト事業単体、保存後） | 4,400円（交通費1,200＋宿泊費3,200。個人雑費500円は含まない） |
| legacy `/export` 様式2-2 preview 総合計（テスト事業のみ選択） | 4,400円 |

一致を確認した。

## 2-6 previewで個人雑費が残る確認

legacy `exportType=2-6` previewで、保存後も「雑費」列に500円、「受領日」列に6/30が表示されることを確認した（交通費1,200・宿泊費3,200も一致）。

## 一時データの削除・復元結果

検証完了後、`Cycle15Take2Setup.java`の`cleanup`モードで事業・参加者を削除し（`ON DELETE CASCADE`で`expenses`も連動削除）、`verify`モードで対象が0件であることを確認した。

サーバー再起動後、`/activity?year=2026`を確認したところ、事業件数8件・延べ参加人数30名・決算書計上額481,179円と、Take2作業開始前と完全に同じ値に復元されていることを確認した。テスト用の事業名「Cycle15Take2監査テスト」・参加者名「監査テストF」は残っていない。

また、`/activity/new`で「＋ 参加者を追加」を押して新規行を生成し、JSテンプレート由来の`expenses[0].miscellaneousCost`（値0）・`expenses[0].receiptDate`（空）が正しく生成されること、コンソールエラーが出ないことも回帰確認した。

## `app.version=v2.4.8`とsrc/target同期

```powershell
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

```text
src/main/resources/application.properties: app.version=v2.4.8
target/classes/application.properties: app.version=v2.4.8
```

一致を確認した。

## compile結果

```powershell
.\mvnw.cmd -q -DskipTests compile
```

成功（エラーなし）。

## `git status --short --untracked-files=all`

コミット前:

```text
 M docs/handoff/CURRENT_STATUS.md
 M src/main/resources/application.properties
 M src/main/resources/templates/activity/form.html
?? docs/handoff/P4_Rollback/cycle_15_policy_and_cleanup.md
```

`docs/handoff/P4_Rollback/cycle_15_policy_and_cleanup.md`（DexのTake2 NGレビュー本体）は本報告と合わせてコミット対象に含める。`app_run_latest.pid`はTake1で設定した通りignore対象のまま維持されている。

## commit hash / push結果

本報告書コミット後、`git push origin main` を実行する。結果は次のセクションで更新する。

## 次への合図

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
CCがCycle 15 Take2（編集保存時の個人雑費・受領日保持修正）を完了しました。v2.4.8です。
docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup_take2.md を読んで、事後レビュー(P4)をお願いします。
```
