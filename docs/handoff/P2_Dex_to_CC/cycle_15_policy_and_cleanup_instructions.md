[C15: Dex(P2) => CC(P3)]

# Cycle 15 CC向け最終指示書: 個人雑費の扱い方針決定とリポジトリ残骸整理

## 判定

**Air Blueprintは条件付きOK。CC(P3)へ実装を依頼してよい。**

Kazumax判断により、個人雑費の扱いは **案A（完全一致優先ルート）** で確定済み。
つまり `/activity` 一覧の表示合計は、提出用Excelの様式2-2系に1円単位で合わせる。

ただし、Air草案のうち `docs/manual_legacy/` の `git rm -r` 指示はそのまま使わないこと。
現状この配下は未追跡ファイルなので、Git削除ではなく、個別パス確認後の物理削除として扱う。

## サブレビュー利用判断

**使用。**

理由:
- 金額計算、帳票との一致、既存データ、ファイル削除が同時に絡むため。
- 2-2系へ個人雑費を混入させる事故、または2-6側の個人雑費表示を壊す事故を防ぐため。

デクスクルーAには、金額計算・帳票一致・削除手順の観点を確認させた。
Dex本体はその結果を統合し、以下の必須条件をCC向け最終指示として採用する。

## 今回の目的

1. `/activity` 一覧の合計を、公式帳票である様式2-2系の総合計と一致させる。
2. 個人雑費 `miscellaneousCost` は「決算書計上額」には含めない。
3. ただし、個人雑費そのもののDB保存・既存表示・様式2-6確認機能は消さない。
4. Cycle 14で保留した作業ツリー残骸3種を、安全な手順で整理する。

## 変更してよいファイル

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/resources/templates/activity/list.html`
- `src/main/resources/application.properties`
- `.gitignore`
- `AI_TEAM_WORKFLOW.md`（ルート直下のみ削除対象）
- `app_run_latest.pid`（Git追跡から外す対象。物理削除ではない）
- `docs/manual_legacy/` 配下の未追跡バックアップ（物理削除対象）
- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup.md`

## 触ってはいけないファイル・領域

今回の案Aでは、以下を変更しないこと。

- `src/main/resources/schema.sql`
- `src/main/resources/mapper/*.xml`
- `src/main/java/.../service/ExcelExportService.java`
- `src/main/java/.../controller/ExportController.java`
- `src/main/resources/*.xlsx`
- `Expense` モデルの `miscellaneousCost`
- DB保存ロジック、編集フォームの保存処理、様式2-6の雑費表示

特に禁止:
- 2-2 / 2-2-1 / 2-3 の集計に個人雑費 `miscellaneousCost` を足さない。
- 個人雑費 `miscellaneousCost` と旅行雑費 `travelMiscCost` を混同しない。
- 「総支出額」などの新しい列は今回追加しない。
- `git add .`、`git clean`、`git reset --hard`、`git restore .` は使わない。

## 実装指示1: `/activity` の合計計算を様式2-2系へ合わせる

対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `list()` メソッド内の `expenseTotal` 計算

現在の考え方:

```java
expenseTotal += nz(e.getTransportCost()) + nz(e.getAccommodationCost()) + nz(e.getMiscellaneousCost());
```

変更後:

```java
expenseTotal += nz(e.getTransportCost()) + nz(e.getAccommodationCost());
```

維持するもの:

- 参加者ごとの交通費 `transportCost`
- 参加者ごとの宿泊費 `accommodationCost`
- 事業サマリの借用料、需用費、駐車料金、報償費、役務費
- 旅行雑費 `travelMiscCost * 参加人数 * travelMiscDays`

除外するもの:

- 参加者ごとの個人雑費 `miscellaneousCost`

注意:
- この変更は `/activity` 一覧の表示用合計だけに閉じる。
- `Expense`、mapper、schema、保存処理は変えない。
- 変数名 `expenseTotal` の大規模リネームは不要。リスクが増えるため、最小差分を優先する。

## 実装指示2: `/activity` の表示名を変える

対象:

- `src/main/resources/templates/activity/list.html`

変更:

- テーブルヘッダーの `支出合計` を `決算書計上額` に変更する。
- 集計フッターの `支出合計` を `決算書計上額` に変更する。
- 近くに短い注記を追加し、個人雑費が含まれないことを明示する。

注記文の例:

```text
※個人雑費はこの合計に含めず、様式2-6で確認します。
```

注意:
- `row.expenseTotal` と `grandTotal` のバインディングは、Java側のフィールド名を変えないならそのままでよい。
- レイアウトを大きく変えない。

## 実装指示3: 個人雑費を壊さない

以下が維持されていることを確認する。

- 個人雑費 `miscellaneousCost` がDB上の値として残る。
- 既存データを編集・保存しても、意図せず個人雑費が消えない。
- legacy 2-6 previewで個人雑費が表示される。
- 2-6 Excel出力でも個人雑費が出力される。

重要:
- 現在の `/activity` 入力フォームに個人雑費欄が見当たらない場合でも、保存処理の副作用で既存値を消していないか確認すること。
- 今回は「一覧合計から除外する」だけであり、「個人雑費データを廃止する」作業ではない。

## 実装指示4: 残骸3種の整理

### 4-1. ルート直下 `AI_TEAM_WORKFLOW.md`

処置:

- ルート直下の `AI_TEAM_WORKFLOW.md` を `git rm -- AI_TEAM_WORKFLOW.md` で削除する。

理由:

- 現在の正本は `manuals/AI_TEAM_WORKFLOW.md`。
- `manuals/AI_TEAM_WORKFLOW.md` は絶対に削除しない。

実行前確認:

```powershell
git ls-files AI_TEAM_WORKFLOW.md manuals/AI_TEAM_WORKFLOW.md
```

### 4-2. `app_run_latest.pid`

処置:

1. `.gitignore` に `app_run_latest.pid` を追加する。
2. `git rm --cached -- app_run_latest.pid` でGit追跡から外す。

理由:

- PID番号だけの実行時ファイルであり、履歴管理対象ではない。
- 物理削除ではなく、ローカルに残してGit管理から外す。

推奨追加位置:

```gitignore
# 実行時ログ（コミット対象外）
app_run.log
app_run_latest.pid
*.log
```

### 4-3. `docs/manual_legacy/`

処置:

- 未追跡バックアップなので `git rm -r` は使わない。
- 削除前に `git status --short --untracked-files=all docs/manual_legacy` で対象を確認する。
- PowerShellで実パスが必ずプロジェクト配下であることを確認してから、個別パス指定またはディレクトリ指定で物理削除する。

安全条件:

- `docs/manual_legacy/` の中だけを削除する。
- `docs/` 全体、`manuals/`、`AGENTS.md`、`CLAUDE.md`、`.cursorrules` は削除しない。
- `git clean` は絶対に使わない。

## version更新

今回はJava/HTML/.gitignoreの変更があるため、`app.version` を更新する。

現在:

```properties
app.version=v2.4.6
```

変更後:

```properties
app.version=v2.4.7
```

compile後、以下も確認する。

```powershell
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

両方が `v2.4.7` で一致していること。

## 必須検証

### 1. compile

```powershell
.\mvnw.cmd -q -DskipTests compile
```

成功すること。

### 2. 既存2026年度データの通常確認

`/activity?year=2026` を開き、画面が壊れていないことを確認する。

既存2026年度データは個人雑費が0円のため、ここだけでは今回修正の証明にならない。
あくまで回帰確認として扱う。

### 3. 個人雑費あり一時データでの確認

一時データまたは安全な検証手段で、個人雑費ありの事業を確認する。

例:

- 交通費: 1,000円
- 宿泊費: 3,000円
- 個人雑費: 500円

期待値:

- `/activity` の `決算書計上額`: 4,000円 + 事業サマリ費目（個人雑費500円を含めない）
- legacy 2-2 preview / Excel: `/activity` の `決算書計上額` と一致
- 年度末2-2 / 2-2-1 / 2-3 preview: `/activity` の `決算書計上額` と一致
- legacy 2-6 preview / Excel: 個人雑費500円が確認できる

検証後:

- 一時データは削除・復元する。
- 復元後にテスト用の事業名・参加者名が残っていないことを確認する。

### 4. 作業ツリー確認

最終的に以下を確認する。

```powershell
git status --short --untracked-files=all
git status --short --ignored app_run_latest.pid
```

期待:

- `docs/manual_legacy/` が未追跡として残っていない。
- `app_run_latest.pid` はGit追跡から外れ、ignore対象になっている。
- ルート直下 `AI_TEAM_WORKFLOW.md` は削除としてコミット対象になっている。
- `manuals/AI_TEAM_WORKFLOW.md` は残っている。

## コミット

検証完了後、必要ファイルのみ個別指定でstageする。
`git add .` は使わない。

コミットメッセージ例:

```text
[v2.4.7] Cycle 15: /activity決算書計上額と残存ファイル整理
```

可能であればpushする。

## P3報告書

CCは完了後、以下へ報告書を保存する。

```text
docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup.md
```

報告書に必ず含めること:

- 変更ファイル一覧
- `/activity` 合計から `miscellaneousCost` を除外したこと
- 個人雑費のDB保存・2-6 preview/Excel表示を維持した確認結果
- legacy 2-2 / 年度末2-2系との一致確認結果
- 一時データを使った場合の作成内容、期待値、実測値、削除・復元結果
- `app.version=v2.4.7` とsrc/target同期確認
- compile結果
- 残骸3種の整理結果
- 最終 `git status --short --untracked-files=all`
- コミットhashとpush結果

## Dex(P4)への合図文

CC完了後、Kazumaxへ以下をコピー用に出すこと。

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
このプロジェクトに docs/PROJECT_RULES.md がある場合は、それも読んで危険領域と検証条件を確認して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。

Dexへ：
CCがCycle 15（個人雑費の扱い方針決定とリポジトリ残骸整理）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_15_policy_and_cleanup.md を読んで、事後レビュー(P4)をお願いします。
```
