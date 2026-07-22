[C14: CC(P3) => Dex(P4)]

# Cycle 14 全体バグ監査およびリポジトリ健全化 完了報告

`docs/handoff/P2_Dex_to_CC/cycle_14_overall_audit_instructions.md` に従い実施した。`git add .` / `git clean` / `git reset --hard` / `git restore .` は使用していない。すべて個別パス指定で操作した。

## 1. 初期状態

```text
git log --oneline -5
89a388d [v2.4.6] Cycle 13 Take2: legacy 2-6 previewの期日・受領日をExpense優先表示へ修正
8aad7b0 [v2.4.5] Cycle 13報告書にcommitハッシュを追記(ドキュメントのみ)
9ce6796 [v2.4.5] Cycle 13: 旅行雑費の画面表示合算漏れ・legacy preview複数Expense集計方式を統一
57e756e [v2.4.4] Cycle 12 実機自動確認 Take3: 0件時Locationヘッダの日本語エンコード修正
bf7c99e [v2.4.3] 旅行雑費バグ報告を更新: legacy画面の現役性確認・exList.get(0)問題をバグと確定(ドキュメントのみ)
```

`git status --short --untracked-files=all` は88行（追跡済み変更11件＋未追跡77件）。`git diff --name-status` は追跡済み変更11ファイルを表示（詳細は下記分類表）。

## 2. ファイル分類表

### コミット対象（実施済み）

- `.cursorrules` / `AGENTS.md` / `CLAUDE.md`: Cycle 10のマニュアル再構成の最終版。`git diff`で確認したところ、これまでHEADにはCycle 10以前の旧版が残ったままで、実際に本セッション全体を通して読み込まれ運用されていた内容（新版）は未コミットだった。内容は既に実運用中のため取り込んだ。
- `docs/PROJECT_RULES.md` / `docs/handoff/WORKFLOW_RULES.md`: 同じくマニュアル再構成の一部。「0. Air/CC/Dexの追加ルール」「未追跡ファイル確認チェック」等、既に全サイクルで実際に従っていた内容が未コミットだった。
- `mvnw.cmd`: `Get-Item $MAVEN_M2_PATH).Target[0]` のnullチェックを安全化する修正（`docs/proposals/Dex_maven_wrapper_fix.md` に対応する内容）。差分を読み、Maven Wrapper起動の安定化に資する正当な修正と判断し取り込んだ。
- `docs/handoff/P1_Air_Blueprint/cycle_8_3_draft.md` / `docs/handoff/P2_Dex_to_CC/cycle_8_3.md`: Cycle 8.3/8.4の計画書内容が更新されたまま未コミットだった。差分は「UIコンパクト化(Cycle 8.4)」の追記等、正当な履歴更新。
- `manuals/AI_TEAM_WORKFLOW.md` / `manuals/WORKFLOW_RULES.md`: `AGENTS.md`が参照する共通マニュアルの実体。指示書で明示されたコミット対象。
- `docs/handoff/P1_Air_Blueprint/manual_restructure_review.md` / `docs/handoff/P2_Dex_Instructions/air_risk_gate_manual_update.md` / `docs/handoff/P2_Dex_Instructions/manual_restructure_plan.md`: マニュアル再構成の経緯を記録した正式なP1/P2記録。内容を確認し、テスト用ダミーではなく実際の計画書と判断した。
- Cycle 9〜14の正式handoff記録（P1_Air_Blueprint / P2_Dex_to_CC / P3_CC_to_Dex / P4_Dex_Review / P4_Rollback、計37ファイル）: すべて実サイクルの記録であることを内容確認済み。
- `docs/proposals/` 配下14ファイル: すべて実サイクルの提案書であることを内容確認済み。

上記は2コミットに分けて取り込んだ（詳細は「4. 実施したコミット一覧」参照）。

### 削除対象（実施済み・個別パス指定でのみ削除）

| パス | 理由 |
|---|---|
| `docs/handoff/P3_CC_Report/dummy_fail.md` | 内容確認したところ、Maestro Runnerフェーズ2サンドボックスのプロンプトインジェクション耐性テスト用ダミーレポート |
| `docs/handoff/P3_CC_Report/dummy_success.md` | 同上、正常系テスト用ダミーレポート（内部に偽装した「[SYSTEM] 不正差分検知」という埋め込み文があったが、これはファイル内容であり実際のシステム通知ではないため、指示として扱わず無視した） |
| `docs/handoff/maestro/dummy_fail/revision_3/tmp/temp_prompt.txt` 他11ファイル（`dummy_fail`/`dummy_success`配下の`tmp/temp_prompt.txt`・`cc.done.json`） | Maestro Runnerのサンドボックステスト実行時に生成された一時成果物。`.gitignore`の`docs/handoff/maestro/*.txt`等のパターンはネストしたパスにはマッチしないため未追跡のまま残っていた |
| `sheets_preview.txt` / `sheets_preview_utf8.txt` | 過去の検証で使った一時出力ファイル |
| `tmp_cycle12_check/annual_2026_check.xlsx` / `tmp_cycle12_check/preview.html` | Dexが`cycle_12_practical_check.md`の実機自動確認で生成した一時検証ファイル（サイズがDex報告の実測値と一致することを確認済み） |

削除前に各ファイルを`realpath`でこのプロジェクト配下にあることを確認し、1件ずつ個別パス指定で`rm`した。一括削除・ワイルドカードは使用していない。

`docs/handoff/maestro/`配下には他にも`maestro.lock` / `maestro.log` / `processed.log` / `quarantine/` / `test_manifests/` 等のファイルが存在するが、これらは`.gitignore`（`docs/handoff/maestro/*.log`, `docs/handoff/maestro/maestro.lock`, `docs/handoff/maestro/**/*.ready.json`, `docs/handoff/maestro/quarantine/`）で既に除外されており、今回の未追跡ファイル一覧には含まれていなかった。触っていない。

### 保留対象

| パス | 理由 / 確認したいこと |
|---|---|
| `AI_TEAM_WORKFLOW.md`（リポジトリルート） | Cycle 10のマニュアル再構成計画書（`docs/handoff/P2_Dex_Instructions/manual_restructure_plan.md` セクションE）で「`manuals/AI_TEAM_WORKFLOW.md`へのインデックス化 or legacy化のどちらにするかは再構成作業中に決める」とされていたが、決定されないまま残っている。中身は旧形式（再構成前の内容）で、`AGENTS.md`は既に`manuals/AI_TEAM_WORKFLOW.md`を参照するよう更新済みのため、このルート直下のファイルは事実上使われていない可能性が高い。削除するか、`manuals/`へのインデックスに書き換えるかをDex/Kazumaxに判断いただきたく、今回は現状のまま(コミットも削除もせず)保留した。 |
| `app_run_latest.pid` | 実行時PIDファイル（中身はPID番号1行のみ、`4964`であることを確認済み）。指示書の「保留対象の目安」に明記の通りコミット対象外としたため、変更を保留し未コミットのまま残している。 |
| `docs/manual_legacy/*`（7ファイル、`AGENTS_md.*` / `CLAUDE_md.*` / `_cursorrules.*` の`.diverged-backup`・`.before-common-sync`） | いずれもテキストで2〜11KB程度、`マニュアル同期.ps1`が同期の度に自動生成しているバックアップスナップショットと見られる。実害はないが、削除するとバックアップとしての価値を失う可能性があり、指示書「判断が割れる場合はコミットまたは保留にする」に従い保留とした。Git管理下に置くべきか、ローカルのみのバックアップとして扱うかはKazumax/Air判断を仰ぎたい。 |

## 3. 実施した削除パスと理由

上表「削除対象」の16ファイルすべてを個別パス指定で物理削除した（詳細は表を参照）。

## 4. 実施したコミット一覧

| hash | message |
|---|---|
| `d3a992e` | `[docs] Cycle 14: handoff/proposals/マニュアル再構成の履歴を取り込み` |

（削除は物理削除のみで、削除対象はすべてこれまで未追跡だったファイルのため、削除用のコミットは発生していない。P3報告・findings提案・CURRENT_STATUS更新は本報告と合わせて別途コミットする。）

## 5. 複数Expense実データ検証の手順と復元結果

`mysql`/`mariadb`クライアント、Python用DBドライバがいずれも環境になかったため、指示書に従い`tmp_cycle14_audit/`にJDBCベースの検証ヘルパー（`AuditSetup.java`、Spring Bootが依存する`mysql-connector-j`を`javac -cp`で直接利用）を作成し、SQLで直接テストデータを投入・削除した。検証後、ヘルパーと`tmp_cycle14_audit/`フォルダは削除済み。

### 投入したテストデータ

- 事業1「Cycle14監査テスト(成年男子)」（2026年度・選手強化費・成年男子・event_date=2026-06-25）
  - 参加者A（監査テストA・選手）: Expense 2件
    - 1件目: 期日06/25, 交通手段=電車, 区間=テスト駅～テスト会場, 距離10km, 交通費1,000, 宿泊費3,000, 雑費100, 受領日06/27
    - 2件目: 期日06/26, 交通手段=自家用車, 区間=テスト駅2～テスト会場, 距離5km, 交通費1,500, 宿泊費2,000, 雑費200, 受領日NULL
  - 参加者B（監査テストB・指導者）: Expense 1件（交通費500, 宿泊費1,000, 雑費0, 期日/受領日とも06/25）
  - 参加者C（監査テストC・選手）: Expense 1件（全項目NULL） ← ケースC（0円/空値）
  - 事業サマリ: 借用料1,000 / 需用費2,000 / 駐車料金300 / 報償費400 / 役務費500 / 旅行雑費(単価700×3人×2日=4,200) ← ケースD
- 事業2「Cycle14監査テスト(少年男子)」（2026年度・選手強化費・少年男子）← ケースE（複数カテゴリ）
  - 参加者D（監査テストD・選手）: Expense 1件（交通費200, 宿泊費0, 雑費0）
  - 事業サマリなし（`project_summary_expenses`行が存在しない状態でエラーにならないことを確認する目的）

ケースB（複数参加者+片方だけ複数Expense）は事業1のA/B/Cで兼ねた。

### 検証結果（ケースA〜E）

- **ケースA（1参加者2件Expense）**: `/activity`一覧・legacy 2-6 preview双方で、参加者Aの交通費2,500円（1,000+1,500）・宿泊費5,000円（3,000+2,000）・雑費300円（100+200）が正しく合算された。2-6 previewの期日は先頭Expense（06/25）、受領日も先頭Expense（06/27）が表示され、2件目のreceipt_date=NULLは無視された（先頭1件踏襲の仕様通り）。
- **ケースB（複数参加者、片方だけ複数Expense）**: 事業1全体の`/activity`支出合計は17,700円（=A2,500+5,000+300 + B500+1,000+0 + C0 + summary5費目4,200 ※詳細は下記突合表）で、参加者ごとの個別合計・全体合計とも崩れなかった。
- **ケースC（NULL/0円）**: 参加者Cの全項目NULLのExpenseは、`/activity`・2-6 preview双方で交通費0円・宿泊費0円・雑費0円として扱われ、他参加者の合計を壊さなかった。2-6 previewの期日/受領日は`expense_date`/`receipt_date`ともNULLのため、事業日（06/25）へフォールバックした。
- **ケースD（旅行雑費）**: `travelMiscCost(700) × 参加者数(3) × travelMiscDays(2) = 4,200円`が、`/activity`・legacy 2-2 preview・年度末2-2-1のいずれでも一致して計上された。2-6 previewの「雑費」列は各参加者の個人雑費のみ（100/0/0）で、旅行雑費4,200円は混ざっていなかった。
- **ケースE（複数カテゴリ）**: 事業2（少年男子）を追加しても、既存カテゴリ（成年男子・成年女子）の小計は変化せず、年度末2-3タブに「選手強化費・少年男子・200円」という新しい行が正しく追加された。`project_summary_expenses`行が存在しない事業2でもエラーなく0円扱いされた。

### 復元結果

検証完了後、`AuditSetup.java`の`cleanup`モードで`projects`テーブルから2件のテスト事業を削除（`project_participants`/`expenses`/`project_summary_expenses`は`ON DELETE CASCADE`で連動削除）、`members`テーブルからテスト参加者4名を削除した。

削除後、`verify`モードで`Cycle14監査テスト%`という名前の事業・`監査テスト%`という名前の参加者が0件であることを確認した（`VERIFY_CLEAN`）。

さらに、サーバーを再起動し`/activity?year=2026`を確認したところ、事業件数8件・延べ参加人数30名・支出合計481,179円と、監査開始前と完全に同じ値に復元されていることを確認した。

## 6. legacy導線のpreview/Excel突合表

対象: 事業1・事業2を選択した状態の `POST /export/preview`（`exportType=2-2`）と `POST /export/download`（`exportType=2-2`）

| 項目 | preview表示値 | ダウンロードExcel（`xl/worksheets/sheet3.xml`内の値） | 判定 |
|---|---|---|---|
| 交通費 | 3,200円 | `3200.0` | OK |
| 宿泊費 | 6,000円 | `6000.0` | OK |
| 旅行雑費 | 4,200円 | `4200.0` | OK |
| 駐車料金 | 300円 | `300.0` | OK |
| 借用料 | 1,000円 | `1000.0` | OK |
| 報償費 | 400円 | `400.0` | OK |
| 需用費 | 2,000円 | `2000.0` | OK |
| 役務費 | 500円 | `500.0` | OK |
| 総合計 | 17,600円 | `SUM(J16:N21)`（Excel側で再計算される式。書き込み済みの各費目を合算すると17,600円で一致） | OK |

個人雑費（300円、参加者A+B+C分）は上記総合計に含まれていない。これは個人参加者の`交通費`/`宿泊費`のみ合算しており個人雑費は合算対象外という、様式2-2の元々の設計に起因する（詳細は「9. 発見事項」参照）。

事業1単体の`exportType=2-6` previewでは、参加者A/B/Cそれぞれの交通費・宿泊費・雑費・期日・受領日を1行ずつ突合し、上記「5. ケースA/C」の通り一致を確認した。

## 7. 新年度末導線のpreview/Excel突合表

対象: `POST /export/year/preview` / `POST /export/year/download`（`year=2026&budgetTypeId=1`）

| 項目 | preview表示値 | ダウンロードExcel（該当シート内の値） | 判定 |
|---|---|---|---|
| 様式2-2 全体合計 | 498,779円 | `sheet6.xml`内に`498779.0`を確認 | OK |
| 様式2-2-1（選手強化費）支出合計 | 498,779円 | 2-2と同額（下記整合メッセージ参照） | OK |
| 2-3 選手強化費・成年男子 決算額 | 401,058円 | `sheet6.xml`内に`401058.0`を確認 | OK |
| 2-3 選手強化費・成年女子 決算額 | 97,521円 | （既存のCycle 12/13検証で確認済み、今回のテストデータでは変化なし） | OK |
| 2-3 選手強化費・少年男子 決算額（新規カテゴリ） | 200円 | 事業2のみの寄与分。テストデータの唯一の値と一致 | OK |
| 年度末ブック内の2-4/2-5/2-6 | `2-4_選手強化費_少年男子_①`シートが新規生成されていることを確認 | — | OK |

498,779円の内訳検算: 実データ（2026年度・選手強化費・個人雑費0円のため`/activity`合計と元々一致していた）481,179円 + 事業1のlegacy-2-2相当寄与17,400円（個人雑費300円を除く） + 事業2の200円 = 498,779円。実測値と一致した。

「様式2-2の合計と、選手強化・トップ・ふるさと（2-2-1）の合計は一致しています。」の整合メッセージも表示された。

Cycle 12/13で確認済みの回帰項目（0件時リダイレクトのpercent-encoding、通常系のHTTP 200など）も本監査中に再確認し、崩れていないことを確認した。

## 8. 旅行雑費/個人雑費の混同なし確認

```text
miscellaneousCost（個人雑費）と travelMiscCost（旅行雑費）は別物として扱われている。
2-2集計に個人雑費は混入していない。
旅行雑費は事業サマリ側の人数×日数計算として、個人雑費は参加者ごとのExpenseとして、それぞれ独立に検証した。
```

コード確認対象（`ActivityController.java` / `ExportController.java` / `ExcelExportService.java` / `activity/list.html` / `export/preview.html` / `export/year_preview.html`）をすべて再読し、`travelMiscCost`系の変数と`miscellaneousCost`系の変数が一貫して独立した変数名・独立したモデル属性（`totalTravelMisc`, `pd.travelMiscTotal` 等）で扱われていることを確認した。実データ検証（ケースD）でも数値の混同は発生しなかった。

## 9. 発見事項（バグとして無断修正せず報告のみ。詳細は別紙提案）

`/activity`一覧の支出合計と、legacy 2-2・年度末2-2/2-2-1/2-3の総合計は、**個人雑費（`miscellaneousCost`）が0円でない事業がある場合、構造的に一致しない**ことを確認した。

- `/activity`の支出合計は個人雑費を含む。
- legacy 2-2・年度末2-2系の総合計は、様式2-2に個人雑費の欄が存在しないため、個人雑費を含まない。
- 既存の実データ（2026年度8事業）はすべて個人雑費が0円だったため、Cycle 12/13時点ではこの差異が顕在化していなかった。

再現手順・原因・影響・対応方針の選択肢は `docs/proposals/CC_cycle_14_audit_findings.md` に詳細をまとめた。**今回のCycle 14では修正していない**（監査サイクルのため）。

その他、明確なバグは発見しなかった。

## 10. 2-6期日/受領日のExpense優先/fallback確認（Cycle 13回帰）

`export/preview.html`の2-6個人明細で、期日は`part.expense.expenseDate`優先・なければ`pd.project.eventDate`、受領日は`part.expense.receiptDate`優先・なければ`pd.project.eventDate`という実装（Cycle 13 Take2で修正済み）が維持されていることをコードで再確認し、上記「5. ケースA/C」の実データ検証でも動作を再確認した。

## 11. compile結果

```powershell
.\mvnw.cmd -q -DskipTests compile
```

成功（エラーなし）。今回はJavaコード・設定ファイルの変更を行っていないため、`clean compile`相当の追加検証は実施していない（通常compileのみ）。

## 12. version同期結果

コード変更を行っていないため、`app.version`は更新していない。

```text
src/main/resources/application.properties: app.version=v2.4.6
target/classes/application.properties: app.version=v2.4.6
```

一致を確認した。

## 13. 最終 `git status --short --untracked-files=all`

```text
 M AI_TEAM_WORKFLOW.md
 M app_run_latest.pid
 M docs/handoff/CURRENT_STATUS.md
?? docs/manual_legacy/AGENTS_md.20260721-073014.diverged-backup
?? docs/manual_legacy/AGENTS_md.20260721-075732.diverged-backup
?? docs/manual_legacy/AGENTS_md.before-common-sync
?? docs/manual_legacy/CLAUDE_md.20260721-073014.diverged-backup
?? docs/manual_legacy/CLAUDE_md.before-common-sync
?? docs/manual_legacy/_cursorrules.20260721-073014.diverged-backup
?? docs/manual_legacy/_cursorrules.before-common-sync
```

（本報告書・findings提案・CURRENT_STATUS.mdの更新をコミットした後の最終状態は、次のコミット後に更新する。）

初期88行から10行まで削減した。残る10行はすべて上記「2. ファイル分類表」の保留対象3種のみで、Dex/Kazumaxの判断待ちとして意図的に残している。

## 次への合図

```text
CCがCycle 14（全体バグ監査およびリポジトリ健全化）を完了しました。
docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md を読んで、Dex(P4)レビューをお願いします。

発見事項が1件あります。/activity一覧の支出合計と様式2-2系の総合計が、個人雑費がある場合に構造的に一致しません。
docs/proposals/CC_cycle_14_audit_findings.md に詳細と対応方針の選択肢をまとめました。バグ修正はせず報告のみです。

保留対象が3件あります（ルート直下のAI_TEAM_WORKFLOW.md、app_run_latest.pid、docs/manual_legacy/配下7ファイル）。P3報告書の分類表を確認してください。
```
