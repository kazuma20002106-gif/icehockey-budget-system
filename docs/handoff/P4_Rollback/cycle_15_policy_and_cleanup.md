[C15: Dex(P4) => CC(P3) Take2]

# Cycle 15 P4レビュー: Take2差し戻し

## 判定

**NG / Take2差し戻し**

`/activity` の「決算書計上額」への変更、個人雑費を一覧合計から除外する実装、残骸3種の整理、`v2.4.7` 更新、compile、pushはおおむねP2指示どおりです。

ただし、P2必須条件のうち **「既存データを編集・保存しても、意図せず個人雑費が消えない」** が満たせていない可能性が高いため、Cycle 15はこのままOKにできません。

## サブレビュー利用判断

**使用。**

理由:
- Cycle 15は金額計算、2-2/2-6帳票整合、DB保存、副作用のある削除/ignore整理に触るため。
- 特に「一覧には含めないが、2-6用の個人雑費データは保持する」という二重条件の見落としリスクが高いため。

デクスクルーAには、金額一致、2-6維持、削除/ignore整理、compile/version/git状態を独立確認させた。
Dex本体は結果を統合し、以下のP1 findingを採用する。

## Findings

### P1: 個人雑費あり既存データを編集保存すると、個人雑費が消える可能性が高い

P2指示では、以下を必須条件にしていました。

> 既存データを編集・保存しても、意図せず個人雑費が消えない。

しかし現状コードを見る限り、この条件は未達に見えます。

根拠:

- `src/main/resources/templates/activity/form.html` の個人別支出フォームには、`expenses[n].miscellaneousCost` の入力欄もhiddenも存在しない。
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ProjectService.java` は保存時に `participantMapper.deleteByProjectId(projectId)` で参加者を削除し、ON DELETE CASCADEで既存 `expenses` も削除される。
- その後、POSTされた `Expense` を `ExpenseMapper.insert(...)` で再作成する。
- つまり、既存DBに `miscellaneous_cost=500` のような値があっても、編集画面からPOSTされないため、編集保存後に `miscellaneous_cost` が `null` または0相当で再作成される可能性が高い。

これは `84c7d99` が新しく発生させた差分ではなく、既存構造の問題かもしれません。
ただし今回のCycle 15は「個人雑費は一覧合計から除外するが、DB保存と様式2-6確認は維持する」ことが目的なので、ここを見逃したままOKにはできません。

## OK確認済みの項目

以下はP4でOK確認済みです。

- `ActivityController.list()` は `/activity` 表示用合計から `miscellaneousCost` だけを除外している。
- 交通費、宿泊費、事業サマリ費目、旅行雑費 `travelMiscCost * parts.size() * travelMiscDays()` は維持されている。
- `activity/list.html` は `支出合計` を `決算書計上額` に変更し、個人雑費を含めない注記を追加している。
- `row.expenseTotal` / `grandTotal` の表示バインディングは壊れていない。
- `schema.sql`、`mapper/*.xml`、`ExcelExportService.java`、`ExportController.java`、xlsxテンプレートは変更されていない。
- 2-2 / 2-2-1 / 2-3 側へ個人雑費を足す変更は入っていない。
- 2-6 preview/Excel側の `miscellaneousCost` 表示/出力コードは残っている。
- `.gitignore` に `app_run_latest.pid` が追加され、`app_run_latest.pid` はGit追跡から外れてignore対象になっている。
- ルート直下 `AI_TEAM_WORKFLOW.md` は削除され、正本 `manuals/AI_TEAM_WORKFLOW.md` は残っている。
- `docs/manual_legacy/` は残っていない。
- `app.version` はsrc/targetとも `v2.4.7`。
- `main` と `origin/main` は `a0df104` で一致している。
- `git status --short --untracked-files=all` はクリーン。
- Dex側でも `.\mvnw.cmd -q -DskipTests compile` を実行し、成功を確認した。

## CC Take2で実施すること

### 1. 編集保存時に個人雑費を保持する

最小修正案:

- `src/main/resources/templates/activity/form.html` の既存行テンプレートに、`expenses[n].miscellaneousCost` のhidden inputを追加する。
- 新規行テンプレートにも、`expenses[IDX].miscellaneousCost` のhidden inputを追加し、初期値は `0` または空でよい。

例:

```html
<input type="hidden" th:name="|expenses[${stat.index}].miscellaneousCost|"
       th:value="${e.miscellaneousCost}">
```

新規行側の例:

```html
<input type="hidden" name="expenses[IDX].miscellaneousCost" value="0">
```

注意:
- 個人雑費の見える入力欄を新設するかどうかは今回の主目的ではない。まずは既存値が消えないことを最優先にする。
- `Expense`、mapper、schema、Excel出力、2-2系集計は変更しない。
- 2-2系へ個人雑費を足さない。
- もし同じ編集保存で `receiptDate` など2-6用の既存値も消えることが確認できた場合は、同じ考え方でhidden保持する。ただし、範囲を広げる場合はP3報告で理由を明記する。

### 2. 実データで再検証する

一時テストデータを作り、以下を必ず確認する。

1. 個人雑費500円など、0円でない `miscellaneous_cost` を持つ事業を作る。
2. `/activity/{id}/edit` を開く。
3. 何も変えずに保存する、または金額に関係ない軽微な項目だけ変更して保存する。
4. 保存後もDB/2-6 previewで個人雑費500円が残っていることを確認する。
5. `/activity` の `決算書計上額` には個人雑費500円が含まれないことを確認する。
6. legacy 2-2 / 年度末2-2系の合計と `/activity` の `決算書計上額` が一致することを確認する。
7. 検証後、一時データを削除し、既存2026年度が8件・30名・481,179円へ戻ることを確認する。

### 3. version / compile / commit

Take2はテンプレート変更を伴うため、`app.version` を `v2.4.8` へ更新する。

必須:

```powershell
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
git status --short --untracked-files=all
```

期待:

- compile成功
- src/targetとも `app.version=v2.4.8`
- 不要な未追跡ファイルなし
- `app_run_latest.pid` はignore対象のまま

コミットメッセージ例:

```text
[v2.4.8] Cycle 15 Take2: 編集保存時の個人雑費保持を修正
```

可能であればpushする。

## Take2報告書の保存先

CCは修正完了後、以下へ報告書を保存する。

```text
docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup_take2.md
```

報告書に必ず含めること:

- 変更ファイル一覧
- `miscellaneousCost` hidden保持の実装内容
- 編集保存前後で個人雑費が消えないことの実測結果
- `/activity` の `決算書計上額` と2-2系合計の一致確認
- 2-6 previewで個人雑費が残る確認
- 一時データの削除・復元結果
- `app.version=v2.4.8` とsrc/target同期
- compile結果
- `git status --short --untracked-files=all`
- commit hash / push結果

## CCへの起動メッセージ

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

CCへ：
DexがCycle 15のP4レビューを行い、Take2差し戻しになりました。
docs/handoff/P4_Rollback/cycle_15_policy_and_cleanup.md を読んで、編集保存時に既存の個人雑費 `miscellaneousCost` が消えないよう修正・検証してください。

完了報告は docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup_take2.md に保存してください。
```
