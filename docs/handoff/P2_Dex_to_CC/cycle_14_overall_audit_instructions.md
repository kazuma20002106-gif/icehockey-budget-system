[C14: Dex(P2) => CC(P3)]

# Cycle 14 全体バグ監査およびリポジトリ健全化 CC向け最終指示書

## 判定

Air(P1)のBlueprintは **実行可** です。

ただし、金額・Excel・DB実データ・リポジトリ整理を同時に扱う危険サイクルなので、CCはこの指示書の範囲だけを実行してください。
本サイクルの目的は **新機能追加ではなく、金額の正確性を証明し、作業ツリーを健全化すること** です。

## サブレビュー利用判断

**使用。**

理由:
- Cycle 14は金額、Excel、legacy導線、新年度末導線、複数Expense、DB実データ、未追跡ファイル整理にまたがる。
- Dex単独では観点が多いため、デクスクルーAにAir Blueprintの観点漏れレビューを依頼した。

デクスクルーAの指摘は以下を採用した。

- Excel検証は合計値だけでなく、様式別セル値・カテゴリ別小計・ダミー値残りなしまで見る。
- preview/download一致は、同一テストデータで画面表示値とExcelセル値を1円単位で突合する。
- 未追跡ファイル整理では `git add .`、`git clean`、`git reset --hard`、`git restore .` を禁止する。
- 未追跡ファイルは、コミット対象 / 削除対象 / 保留対象の一覧をP3報告に残してから処理する。
- 複数Expenseは、1参加者だけでなく複数参加者、空/0円、複数カテゴリ混在も最低1ケース確認する。
- Cycle 13由来の2-6期日/受領日fallbackも回帰観点に入れる。

## 絶対禁止

- `git add .`
- `git clean`
- `git reset --hard`
- `git restore .`
- `git checkout -- .`
- 目的外のJava / HTML / mapper / schema / Excelテンプレート変更
- バグを見つけたときの無断修正
- 本番的に必要な既存データの削除・上書き
- `src/main/resources/templates/` 配下への検証スクリプトや一時ファイル作成

補足:
- `app_run_latest.pid` のような実行時ファイルを戻す必要がある場合でも、広範囲restoreは禁止。中身がPIDだけであることを確認し、P3報告に書いたうえで対象ファイル単体だけを扱うこと。
- バグを見つけた場合は、勝手に修正せず、再現条件・期待値・実際値・影響範囲をP3報告に書く。修正が必要な場合は、Dex(P4)差し戻しまたは次サイクル起票で扱う。

## 必ず読むファイル

- `AGENTS.md`
- `docs/handoff/WORKFLOW_RULES.md`
- `docs/handoff/CURRENT_STATUS.md`
- `docs/PROJECT_RULES.md`
- `manuals/AI_TEAM_WORKFLOW.md`
- `manuals/WORKFLOW_RULES.md`
- `docs/handoff/P1_Air_Blueprint/cycle_14_overall_audit_planning.md`
- `docs/handoff/P4_Dex_Review/cycle_13_travel_misc_preview_totals_take2.md`
- `docs/proposals/Dex_cycle_13_multiple_expense_edit_ui_followup.md`
- `docs/proposals/Dex_cycle_13_travel_misc_preview_totals_fix.md`
- `docs/proposals/CC_activity_list_travel_misc_total_bug.md`

## 作業全体の流れ

1. 初期状態を記録する。
2. リポジトリ健全化の分類表を作る。
3. 複数Expenseを含む監査用テストデータを安全に準備する。
4. legacy導線と新年度末導線でpreview/Excelの金額を突合する。
5. 旅行雑費と個人雑費の混同がないかコード・画面・Excelで確認する。
6. 監査用に触った実データを元へ戻す。
7. 必要なhandoff/proposals/manual記録を明示的にstage/commitし、明らかな一時ファイルだけ物理削除する。
8. compile、version同期、git statusを確認する。
9. P3報告書を保存する。

## 1. 初期状態の記録

P3報告書に、作業開始時点の以下を貼ること。

```powershell
git log --oneline -5
git status --short --untracked-files=all
git diff --name-status
```

現在Dexが確認した時点では、以下の種類の未整理ファイルがある。

- 追跡済みの変更: `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `AI_TEAM_WORKFLOW.md`, `docs/PROJECT_RULES.md`, `docs/handoff/WORKFLOW_RULES.md`, `mvnw.cmd`, 過去handoff数件, `app_run_latest.pid` など
- 未追跡のhandoff/proposals: Cycle 9-14周辺のP1/P2/P3/P4記録、提案書
- 未追跡の共通manual: `manuals/AI_TEAM_WORKFLOW.md`, `manuals/WORKFLOW_RULES.md`
- 未追跡のmanual backup: `docs/manual_legacy/`
- 明らかな一時ファイル候補: `sheets_preview.txt`, `sheets_preview_utf8.txt`, `tmp_cycle12_check/`
- Maestro dummy / tmp候補: `docs/handoff/maestro/dummy_fail/`, `docs/handoff/maestro/dummy_success/` 配下の `tmp/temp_prompt.txt` や `cc.done.json`

## 2. リポジトリ健全化の分類ルール

処理前に、P3報告書へ以下の3分類表を作ること。

```text
コミット対象:
- path: 理由

削除対象:
- path: 理由

保留対象:
- path: 理由 / Kazumax or Dexへ確認したいこと
```

### コミット対象の目安

- Cycle 10-14の正式なhandoff記録
- Cycle 12-13のP4 OK/NG、P3報告、P2指示書、P1 Blueprint
- Cycle 13/14の提案書
- `AGENTS.md` が参照している `manuals/AI_TEAM_WORKFLOW.md` と `manuals/WORKFLOW_RULES.md`
- 共通マニュアル同期やP4レビューで正式に作られた記録

### 削除対象の目安

- `sheets_preview.txt`
- `sheets_preview_utf8.txt`
- `tmp_cycle12_check/`
- `docs/handoff/P3_CC_Report/dummy_fail.md`
- `docs/handoff/P3_CC_Report/dummy_success.md`
- `docs/handoff/maestro/dummy_fail/` 配下の実行一時成果物
- `docs/handoff/maestro/dummy_success/` 配下の実行一時成果物

削除は、必ず対象パスを解決してこのプロジェクト内にあることを確認してから、個別パス指定で実行すること。
一括削除コマンドやワイルドカード削除は禁止。

### 保留対象の目安

- `docs/manual_legacy/` はバックアップの可能性があるため、削除する前に中身と意図を確認する。判断が割れる場合はコミットまたは保留にする。
- `mvnw.cmd` の変更は、過去のMaven wrapper修正の可能性があるため、差分を読んで必要ならコミット、不要なら理由を報告する。
- `app_run_latest.pid` は実行時ファイルなのでコミットしない。単体復元する場合は、中身がPIDだけであることをP3に記録する。

## 3. 複数Expense実データ検証

目的:
- Cycle 13で修正した `Expense.aggregate(...)` が、実データで正しく効くことを証明する。

注意:
- `ActivityController.editForm(...)` は1参加者の先頭Expenseだけをフォームに載せる。
- `ProjectService.saveProjectData(...)` は参加者とExpenseを再作成する。
- そのため、複数Expenseを作った後に `/activity/{id}/edit` を不用意に保存すると、複数Expenseが失われる可能性がある。

CCは以下を守ること。

1. 監査用データは、既存の本番的に必要なデータを壊さない形で用意する。
2. 既存データを一時的に使う場合は、変更前の対象project/participant/expense/summaryをP3報告に記録し、最後に復元する。
3. 複数Expense挿入は、mysql/mariadbクライアントが使えるならSQLで行う。
4. mysql/mariadbクライアントがない場合は、`tmp_cycle14_audit/` のような一時フォルダにだけ検証ヘルパーを置き、`src/main/resources/` 配下には置かない。検証後、その一時フォルダは削除対象に分類する。
5. 複数Expense作成後、編集画面で保存しない。

最低限作る/確認するケース:

- ケースA: 1参加者にExpense 2件
  - 交通費2件、宿泊費2件、個人雑費2件が合算されること
  - 先頭Expenseの期日/受領日が2-6 previewとExcelに出ること
- ケースB: 複数参加者 + 片方だけ複数Expense
  - 参加者全体の合計が正しくなること
- ケースC: 0円/空値を含むExpense
  - null/空/0円が合計を壊さないこと
- ケースD: 旅行雑費ありの事業
  - `travelMiscCost * 参加者数 * travelMiscDays` が事業サマリとして加算されること
  - 2-6の個人雑費列に旅行雑費が混ざらないこと
- ケースE: 可能なら複数カテゴリ
  - 成年男子 / 少年男子 / 成年女子 / 少年女子のうち、少なくとも2カテゴリで小計が崩れないこと

## 4. preview / Excel 1円単位突合

金額検証は、同一のテストデータを使って、legacy導線と新年度末導線の表示値・Excelセル値を1円単位で突合すること。

### Legacy導線

対象:

- `/export` または活動一覧の出力ボタン
- `POST /export/preview`
- `POST /export/download`

確認する様式:

- 様式2-2 preview / Excel
- 様式2-4 preview / Excel
- 様式2-6 preview / Excel
- `all` 出力の中に含まれる2-4/2-5/2-6

確認する金額:

- 総合計
- 交通費
- 宿泊費
- 旅行雑費
- 個人雑費
- 駐車料
- 借用料
- 報償費
- 需用費
- 役務費

### 新年度末導線

対象:

- `/export/year/setup`
- `/export/year/preview`
- `/export/year/download`
- 活動一覧からの年度末出力リンク
- 既存の `/activity/export/annual` 導線

確認する様式:

- 様式2-1
- 様式2-2
- 様式2-2-1（選手強化費 / トップチーム活用事業 / ふるさと選手活動支援）
- 様式2-3
- 年度末ブック内の2-4/2-5/2-6

確認すること:

- previewの表示値とExcelセル値が一致する
- 2-2合計と2-2-1合計が一致する
- 2-3の内示額/決算額の行が意図どおり出る
- `month`, `projectName`, `targetCategory`, `budgetTypeId` 条件で対象事業がズレない
- ダミー値（例: `830550` など）が出力結果に残っていない

## 5. 旅行雑費と個人雑費の混同チェック

必ず以下の文をP3報告に自分の確認結果として書くこと。

```text
miscellaneousCost（個人雑費）と travelMiscCost（旅行雑費）は別物として扱われている。
2-2集計に個人雑費は混入していない。
旅行雑費は事業サマリ側の人数×日数計算として、個人雑費は参加者ごとのExpenseとして、それぞれ独立に検証した。
```

コード確認対象:

- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ActivityController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/controller/ExportController.java`
- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- `src/main/resources/templates/activity/list.html`
- `src/main/resources/templates/export/preview.html`
- `src/main/resources/templates/export/year_preview.html`

## 6. Excel検証の証跡

Excel検証は「見た」だけで終わらせないこと。

P3報告に以下を残す。

- どのURL/条件でpreviewしたか
- どのExcelファイルをダウンロードしたか
- どのシート名を見たか
- どのセル、またはどの表項目を突合したか
- 期待値
- 実際値
- OK/NG

Apache POIや他のExcel読み取り手段を使う場合、検証スクリプトは `tmp_cycle14_audit/` のような一時フォルダに置き、`src/main/resources/` には置かないこと。

## 7. バグ発見時の扱い

今回のCycle 14は、原則として監査と整理のサイクルです。

バグを見つけた場合:

1. すぐに修正しない。
2. 再現手順、対象データ、期待値、実際値、影響範囲をP3報告に書く。
3. 金額・Excel・DB・保存処理に関係する場合は、次サイクル候補として `docs/proposals/CC_cycle_14_audit_findings.md` にも保存する。
4. 修正が必要なら、Dex(P4)でOK/NGと次サイクル方針を決める。

例外:
- 明らかな一時ファイル削除、handoff/proposalsのコミット、runtime pidの単体復元など、リポジトリ健全化の範囲は実施してよい。

## 8. 検証コマンド

最低限:

```powershell
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
git status --short --untracked-files=all
```

コード変更を行わない限り `app.version` は上げない。
もしDexの許可範囲外でコード修正が必要になった場合は、修正前に止まり、P3報告でDexへ回すこと。

## 9. コミット方針

CCは、作業後に以下を目指すこと。

- 必要なhandoff/proposals/manual記録はGit管理下へ入れる。
- 明らかな一時ファイルは物理削除する。
- 判断不能なものは保留対象としてP3報告に理由を書く。
- 可能な限り `git status --short --untracked-files=all` をcleanに近づける。

推奨コミット:

1. 監査・handoff/proposals整理コミット
   - 例: `[docs] Cycle 14: handoff/proposals履歴を整理`
2. 一時ファイル削除コミット
   - 例: `[chore] Cycle 14: 一時検証ファイルを削除`
3. Cycle 14 P3報告コミット
   - 例: `[docs] Cycle 14: 全体バグ監査結果を報告`

ただし、無理に3コミットへ分けなくてもよい。
重要なのは、`git add .` ではなく、対象を明示してstageすること。

## 10. P3報告書

保存先:

- `docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md`

必ず含める項目:

- 初期 `git status`
- ファイル分類表（コミット対象 / 削除対象 / 保留対象）
- 実施した削除パスと理由
- 実施したコミット一覧（hash / message）
- 複数Expense実データ検証の手順と復元結果
- legacy導線のpreview/Excel突合表
- 新年度末導線のpreview/Excel突合表
- 旅行雑費/個人雑費の混同なし確認
- 2-6期日/受領日のExpense優先/fallback確認
- compile結果
- version同期結果
- 最終 `git status --short --untracked-files=all`
- バグや保留事項がある場合、その再現手順と次サイクル提案

## 次への合図

P3完了後、Kazumaxには以下を渡せるようにすること。

```text
CCがCycle 14（全体バグ監査およびリポジトリ健全化）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md を読んで、Dex(P4)レビューをお願いします。
```
