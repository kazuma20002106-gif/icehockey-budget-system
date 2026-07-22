[C15: CC(P3) => Dex(P4)]

# Cycle 15 個人雑費の扱い方針決定とリポジトリ残骸整理 完了報告

`docs/handoff/P2_Dex_to_CC/cycle_15_policy_and_cleanup_instructions.md` に従い実装した。

## 変更ファイル一覧

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
  - `list(...)` の `expenseTotal` 計算から、参加者ごとの個人雑費 `miscellaneousCost` を除外（`transportCost` + `accommodationCost` のみに変更）。
- `src/main/resources/templates/activity/list.html`
  - テーブルヘッダー・集計フッターの「支出合計」を「決算書計上額」に変更。
  - 集計フッター下に「※個人雑費はこの合計に含めず、様式2-6で確認します。」の注記を追加。
- `src/main/resources/application.properties`
  - `app.version` を `v2.4.7` に更新。
- `.gitignore`
  - `app_run_latest.pid` を追加。
- `AI_TEAM_WORKFLOW.md`（リポジトリルート）
  - `git rm -f` で削除（ローカルに未コミットの旧版差分が残っていたため `-f` を使用。`manuals/AI_TEAM_WORKFLOW.md` が正本であることを`git ls-files`で確認したうえで実施）。
- `app_run_latest.pid`
  - `git rm --cached` でGit追跡から除外（ファイル自体はローカルに残存、内容はPID番号のみ）。
- `docs/manual_legacy/` 配下7ファイル
  - 個別パス指定で物理削除（詳細は下記「残骸3種の整理結果」参照）。

`src/main/resources/schema.sql`、`mapper/*.xml`、`ExcelExportService.java`、`ExportController.java`、`*.xlsx`、`Expense`モデルの`miscellaneousCost`フィールドはいずれも変更していない。

## `/activity`合計から`miscellaneousCost`を除外したことの確認

`ActivityController.list(...)`の該当行を以下のように変更した。

```java
// 変更前
expenseTotal += nz(e.getTransportCost()) + nz(e.getAccommodationCost()) + nz(e.getMiscellaneousCost());
// 変更後
expenseTotal += nz(e.getTransportCost()) + nz(e.getAccommodationCost());
```

事業サマリ側の借用料・需用費・駐車料金・報償費・役務費・旅行雑費（`travelMiscCost * 参加人数 * travelMiscDays`）は変更していない。

## 個人雑費のDB保存・2-6 preview/Excel表示を維持した確認結果

- `ProjectService.saveProjectData(...)`、`ExpenseMapper`、`Expense`モデルはいずれも今回変更していないため、DB保存ロジックへの影響はない。
- legacy `exportType=2-6` previewで、個人雑費が「雑費」列にそのまま表示されることを実データ検証（下記）で確認した。
- 2-6 Excel出力についても、`ExcelExportService`を変更していないため出力ロジックへの影響はない（実データ検証では2-6のExcelダウンロードまでは行っていないが、previewで使われている集計元と同じ`getLoadedParticipants(...)`/`Expense`データを使うため、コード上の非破壊性は担保されている）。

## legacy 2-2 / 年度末2-2系との一致確認結果

一時テストデータ（下記）を用いて、`/activity`の「決算書計上額」・legacy 2-2 preview・年度末2-2-1（2-3）のすべてが一致することを確認した。

| 画面 | 値 |
|---|---|
| `/activity`「決算書計上額」（テスト事業単体） | 4,000円（交通費1,000＋宿泊費3,000。個人雑費500円は含まない） |
| legacy `/export` 様式2-2 preview（テスト事業のみ選択） | 4,000円（交通費1,000＋宿泊費3,000の内訳表示、総合計4,000円） |
| legacy `/export` 様式2-6 preview（テスト事業のみ選択） | 個人雑費500円がそのまま表示 |
| 年度末2-3タブ「選手強化費・成年男子」決算額（`budgetTypeId=1&targetCategory=成年男子`条件） | 387,658円（既存の実データ分383,658円 ＋ テスト事業分4,000円） |

年度末プレビューでは「様式2-2の合計と、選手強化・トップ・ふるさと（2-2-1）の合計は一致しています。」の整合メッセージも表示された。

## 一時データを使った確認内容・期待値・実測値・削除復元結果

環境に`mysql`/`mariadb`クライアントが無いため、Cycle 14と同様に`tmp_cycle15_audit/`にJDBC検証ヘルパー（`Cycle15Setup.java`）を作成し、検証後に削除した。

### 作成した一時データ

- 参加者「監査テストE」（選手）
- 事業「Cycle15監査テスト」（2026年度・選手強化費・成年男子・event_date=2026-06-28）
  - Expense: 交通費1,000円、宿泊費3,000円、個人雑費500円、期日06/28、受領日06/29

### 期待値と実測値

| 項目 | 期待値 | 実測値 | 判定 |
|---|---|---|---|
| `/activity`「決算書計上額」（テスト事業単体） | 4,000円 | 4,000円 | OK |
| `/activity`「決算書計上額」（全体、8→9件） | 481,179 + 4,000 = 485,179円 | 485,179円 | OK |
| legacy 2-2 preview 総合計 | 4,000円 | 4,000円 | OK |
| legacy 2-6 preview「雑費」列 | 500円 | 500円 | OK |
| 年度末2-3「選手強化費・成年男子」決算額 | 383,658 + 4,000 = 387,658円 | 387,658円 | OK |

### 削除・復元結果

検証完了後、`Cycle15Setup.java`の`cleanup`モードで事業・参加者を削除し（`project_participants`/`expenses`は`ON DELETE CASCADE`で連動削除）、`verify`モードで対象が0件であることを確認した。

サーバーを再起動し`/activity?year=2026`を確認したところ、事業件数8件・延べ参加人数30名・決算書計上額481,179円と、Cycle 14終了時点（および本サイクル作業開始前）と完全に同じ値に復元されていることを確認した。テスト用の事業名「Cycle15監査テスト」・参加者名「監査テストE」は残っていない。

## `app.version=v2.4.7`とsrc/target同期確認

```powershell
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

```text
src/main/resources/application.properties: app.version=v2.4.7
target/classes/application.properties: app.version=v2.4.7
```

一致を確認した。

## compile結果

```powershell
.\mvnw.cmd -q -DskipTests compile
```

成功（エラーなし）。

## 残骸3種の整理結果

### 4-1. ルート直下 `AI_TEAM_WORKFLOW.md`

```powershell
git ls-files AI_TEAM_WORKFLOW.md manuals/AI_TEAM_WORKFLOW.md
# → 両方とも追跡済みであることを確認
git rm -- AI_TEAM_WORKFLOW.md
# → ローカルに未コミットの変更が残っているため拒否された
git rm -f -- AI_TEAM_WORKFLOW.md
# → 成功。ファイルも削除された
```

正本 `manuals/AI_TEAM_WORKFLOW.md` は変更していない。

### 4-2. `app_run_latest.pid`

```powershell
# .gitignoreへ追加
app_run_latest.pid

git rm --cached -- app_run_latest.pid
```

実行後、`cat app_run_latest.pid` でファイル自体（内容`4964`のみ）はローカルに残っていることを確認した。`git status --short --ignored app_run_latest.pid` で、インデックスからの削除（`D`）とignore対象化（`!!`）の両方を確認した。

### 4-3. `docs/manual_legacy/`

```powershell
git status --short --untracked-files=all docs/manual_legacy
# → 7ファイルすべて未追跡(??)であることを確認
```

7ファイルすべてについて、`realpath`でこのプロジェクトの`docs/manual_legacy/`配下にあることを1件ずつ確認したうえで個別`rm`した（`git clean`・ワイルドカード削除は不使用）。`docs/`全体・`manuals/`・`AGENTS.md`・`CLAUDE.md`・`.cursorrules`が削除されていないことを確認した。空になった`docs/manual_legacy/`ディレクトリも`rmdir`で削除した。

## 最終 `git status --short --untracked-files=all`

```text
 M .gitignore
D  AI_TEAM_WORKFLOW.md
D  app_run_latest.pid
 M docs/handoff/CURRENT_STATUS.md
 M src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java
 M src/main/resources/application.properties
 M src/main/resources/templates/activity/list.html
?? docs/handoff/P1_Air_Blueprint/cycle_15_policy_and_cleanup.md
?? docs/handoff/P2_Dex_to_CC/cycle_15_policy_and_cleanup_instructions.md
?? docs/handoff/P4_Dex_Review/cycle_14_overall_audit_and_repo_cleanup.md
```

期待通り、`docs/manual_legacy/`は未追跡として残っておらず、`app_run_latest.pid`はGit追跡から外れ`!!`（ignore対象）になっており、ルート直下`AI_TEAM_WORKFLOW.md`は削除としてステージ済み、`manuals/AI_TEAM_WORKFLOW.md`は残っている。

未追跡3件（Cycle 14/15の正式handoff記録）は、本報告と合わせてコミット対象に含める。

## commit / push

コミット・push実施後、本セクションを更新する。

## 次への合図

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
CCがCycle 15（個人雑費の扱い方針決定とリポジトリ残骸整理）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup.md を読んで、事後レビュー(P4)をお願いします。
```
