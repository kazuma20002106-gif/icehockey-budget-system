[C14: Dex(P4) => Kazumax / Air(P1)]

# Cycle 14 全体バグ監査およびリポジトリ健全化 P4レビュー

## 判定

**OK / Cycle 14完了**

CCは `docs/handoff/P2_Dex_to_CC/cycle_14_overall_audit_instructions.md` の範囲どおり、監査・リポジトリ健全化を実施しています。
本サイクルの目的は「新機能追加」ではなく「金額の正確性証明」と「作業ツリー健全化」だったため、発見事項を無断修正せず報告に止めた判断も妥当です。

## サブレビュー利用判断

**使用。**

理由:
- Cycle 14は金額、Excel、DB実データ、legacy/年度末導線、repo整理にまたがる。
- CCが新規発見した `/activity` 合計と様式2-2系合計の差異が、仕様差かバグかの判断を要した。

デクスクルーAには以下を確認させ、Dex本体レビューへ統合しました。

- 個人雑費差異のコード上の妥当性
- Cycle 14差し戻しにすべきか、次Cycle起票でよいか
- 作業ツリー残存3種に危険な見落としがないか

統合結果:
- デクスクルーAの「Cycle 14はOK、個人雑費の扱いは次Cycleで方針決定/修正が妥当」という判定を採用。
- `AI_TEAM_WORKFLOW.md` と `app_run_latest.pid` は未追跡ではなく追跡済み変更なので、本P4では「作業ツリー残存3種」と表現する。

## Findings

**Cycle 14の差し戻し事項はありません。**

ただし、次Cycleで扱うべき重要な設計課題があります。

### 次Cycle候補: `/activity` 支出合計と様式2-2系総合計の個人雑費差異

CCの発見はコード上妥当です。

- `/activity` 一覧: `transportCost + accommodationCost + miscellaneousCost` を加算する
- legacy 2-2 / 年度末2-2 / 2-2-1 / 2-3: 交通費・宿泊費・旅行雑費・事業サマリ費目を加算し、個人雑費は含めない

そのため、個人雑費が0円でない事業がある場合、差額は個人雑費合計と一致します。

これは「帳票出力が間違っている」と即断するものではありません。
様式2-2系に個人雑費の欄がないため、活動一覧の支出合計を「全経費合計」とするのか、「様式2-2検算用合計」に寄せるのか、Kazumax判断が必要です。

方針候補は `docs/proposals/CC_cycle_14_audit_findings.md` にまとまっています。
個人的には、次Cycleでまず **方針1: 現状維持 + `/activity` に注記または合計ラベル整理** を第一候補としてAirに検討させるのが安全です。
様式2-2へ個人雑費を足す案は公式帳票定義を変えるため高リスクです。

## 確認内容

### 1. コミットと差分範囲

確認した主なコミット:

- `d3a992e [docs] Cycle 14: handoff/proposals/マニュアル再構成の履歴を取り込み`
- `a0bd36d [docs] Cycle 14: 全体バグ監査結果を報告`

`a0bd36d` の変更:

- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P3_CC_to_Dex/cycle_14_overall_audit_and_repo_cleanup.md`
- `docs/proposals/CC_cycle_14_audit_findings.md`

`HEAD~2..HEAD` の範囲で、以下への差分はありませんでした。

- `src/main/java`
- `src/main/resources/templates`
- `src/main/resources/mapper`
- `src/main/resources/schema.sql`
- `src/main/resources/application.properties`

つまり、Cycle 14ではアプリ本体の金額ロジックや帳票テンプレートは変更されていません。

### 2. 監査観点の達成

OKです。

CCは以下を報告済みです。

- 複数Expense実データ検証ケースA-E
- legacy 2-2 preview / Excel突合
- legacy 2-6 previewの期日/受領日fallback回帰確認
- 新年度末導線 preview / Excel突合
- 旅行雑費と個人雑費の混同なし確認
- 監査用テストデータの削除・復元確認
- `compile` 成功
- `app.version=v2.4.6` のsrc/target同期

P2指示の要求項目は満たしています。

### 3. リポジトリ健全化

OKです。

初期の未追跡77件 + 追跡済み変更11件相当の作業ツリーを、以下まで整理しています。

- 正式handoff/proposals/manual記録: コミット済み
- 明らかな一時ファイル: 個別パス指定で削除済み
- 判断が割れるもの: 保留対象として報告済み

禁止していた以下の操作を使っていないとP3に記録されています。

- `git add .`
- `git clean`
- `git reset --hard`
- `git restore .`

Dex側でも最終 `git status --short --untracked-files=all` を確認し、残存は以下3種のみでした。

- `AI_TEAM_WORKFLOW.md`（追跡済み変更）
- `app_run_latest.pid`（追跡済み変更）
- `docs/manual_legacy/` 配下7ファイル（未追跡）

### 4. 保留対象3種の扱い

保留判断は妥当です。

#### `AI_TEAM_WORKFLOW.md`

ルート直下の旧/重複マニュアルです。
現在の入口である `AGENTS.md` は `manuals/AI_TEAM_WORKFLOW.md` を読むようになっているため、ルート直下ファイルは使われていない可能性が高いです。

ただし差分が大きく、旧運用資料としての意味もあり得るため、Cycle 14内でCCが勝手に削除しなかった判断は安全です。
次に整理するなら、削除ではなく `manuals/AI_TEAM_WORKFLOW.md` への案内文にするか、`docs/manual_legacy/` へ退避するかを決めるのがよいです。

#### `app_run_latest.pid`

実行時PIDファイルで、内容はPID番号1行の差分のみです。
コミット対象ではありません。
将来的にはGit管理から外す、またはignore対象化を検討してください。

#### `docs/manual_legacy/`

マニュアル同期時のバックアップ群です。
危険ファイル混入ではありませんが、放置すると未追跡ノイズとして残ります。
保管方針を決めるまでは保留で問題ありません。

### 5. `git diff --check`

`git diff --check HEAD~2 HEAD` は、一部の古いhandoff/proposalsで `new blank line at EOF` 警告を出しました。

対象はドキュメントのみで、Java/HTML/mapper/schema/application.propertiesには該当しません。
機能ブロッカーではないため、Cycle 14 OKを妨げません。

### 6. compile / version同期

Dex側でも確認しました。

```powershell
.\mvnw.cmd -q -DskipTests compile
Select-String -Path src\main\resources\application.properties,target\classes\application.properties -Pattern "app.version"
```

結果:

- sandbox内compile: Maven親POM解決のネットワーク制限で失敗
- 外側権限で同じcompileを再実行: 成功
- `src/main/resources/application.properties`: `app.version=v2.4.6`
- `target/classes/application.properties`: `app.version=v2.4.6`

## 残リスク

1. 個人雑費が入る事業では、`/activity` の支出合計と様式2-2系総合計が一致しない。
2. ルート直下 `AI_TEAM_WORKFLOW.md` の扱いが未決定。
3. `app_run_latest.pid` が追跡済みruntimeファイルとして残っている。
4. `docs/manual_legacy/` の保管/削除方針が未決定。

いずれもCycle 14の監査・健全化そのものの失敗ではなく、次Cycle候補として扱うのが妥当です。

## Kazumax向け短縮チェック

AIレビュー上、Cycle 14はOKです。
実機で軽く見るなら、次だけで十分です。

1. `/activity?year=2026` が開き、事業件数8件・延べ参加人数30名・支出合計481,179円になっている
2. legacy「提出データ出力・集計」から2-2/2-6 previewが開ける
3. 年度末出力previewが開ける
4. `docs/proposals/CC_cycle_14_audit_findings.md` の3案を読み、個人雑費の扱いを次Cycleでどうするか決める
5. 作業ツリー残存3種（`AI_TEAM_WORKFLOW.md`, `app_run_latest.pid`, `docs/manual_legacy/`）を次に整理するか決める

## 次の担当

**Air(P1)**:

次Cycle候補は、個人雑費と様式2-2系合計の扱い方針決めです。
金額・帳票に関わるため危険タスクとして扱い、AirはまずKazumaxの方針確認から始めてください。
