# [C9: Dex(P4) ⇒ CC(P3) Take3] Cycle 9 事後DIFFレビュー Take2

## レビュー結果

**P4 NG継続**

Take2で `ExcelExportService.java` の金額コードは改善された。
特に以下は前回差し戻しから前進している。

- `git diff --check -- ExcelExportService.java` は警告なし。
- `long` 集計値を `(int)` キャストせず、`writeSafeNumeric(..., long)` で出力するようになった。
- J列全体合計とカテゴリ別S/AF列出力の構造は、Dexのテンプレート実読確認と整合している。

ただし、危険タスクとして最終確認へ進めるには、まだ作業ツリー安全性と検証状態に問題が残っている。

## コード安全性レビュー

### 1. 金額計算ロジック

**OK寄り**

- 全体合計:
  - 交通費、宿泊費、旅行雑費、駐車料金、借用料、補償費、需用費、役務費を対象プロジェクト全体で合算している。
- カテゴリ別内訳:
  - `Project#getTargetCategory()` を見て、成年男子、少年男子、成年女子、少年女子に分類している。
  - 現行UIの種別選択肢もこの4つに限定されているため、通常運用ではカテゴリ漏れは起きにくい。
- 旅行雑費:
  - `summary.travelMiscCost × 参加人数 × summary.travelMiscDays` の新仕様を維持している。
  - `Expense#getMiscellaneousCost()` を2-2-1決算集計へ再導入していない。

### 2. セル座標

**OK寄り**

Dex側で `src/main/resources/書類.xlsx` をopenpyxlで実読した結果、様式2-2-1（選手強化費）の座標は以下。

- J16/J18/J20/J22/J24/J26/J28/J30: 決算額の各費目
- S列: 成年男子/少年男子の金額欄
- AF列: 成年女子/少年女子の金額欄
- 各費目の上段が成年、下段が少年

実装の0-indexed座標 `col=18` はS列、`col=31` はAF列に対応し、`offset` で少年行へ1行下げる実装もテンプレート構造と一致する。

### 3. 副作用

**コード局所性はOK寄り**

今回のロジック変更は `populate22Summary` と `writeSafeNumeric(long)` 追加に限定されている。
2-4/2-5/2-6の通常帳票出力ロジックには直接触れていない。

## 残るNG理由

### 1. 不要な検証スクリプトがresources成果物へ混入している

以下が未追跡で残っている。

- `replace.py`
- `test.py`
- `src/main/resources/templates/test.py`

さらに `src/main/resources/templates/test.py` はビルド成果物側にもコピーされている。

- `target/classes/templates/test.py`

これは「不要ファイルがresources配下に混入し、成果物へ入った」状態であり、危険タスクの作業ツリーとして不可。

CCの安全ガードで削除できないなら、Kazumaxに削除承認を取るか、明示的な安全手順を提示して削除すること。
今回コミットで放置するC案は不可。

### 2. 無関係なマニュアル差分が作業ツリーに大量に残っている

現時点の `git diff --name-only` には、今回のExcel修正と直接関係しない以下が含まれている。

- `.cursorrules`
- `AGENTS.md`
- `AI_TEAM_WORKFLOW.md`
- `CLAUDE.md`
- `docs/handoff/CURRENT_STATUS.md`
- `docs/handoff/P1_Air_Blueprint/cycle_8_3_draft.md`
- `docs/handoff/P2_Dex_to_CC/cycle_8_3.md`

CCが `git add` を明示指定する予定とはいえ、危険タスクの直後としては混入リスクが高い。
Take3では「今回コミット対象ファイル」と「作業ツリーに残す別件差分」をP3に明確に分けて書くこと。

### 3. compile結果が未記録

Dex環境では引き続きMaven Wrapper起動問題によりcompile不可。

```text
Cannot index into a null array.
Cannot start maven from wrapper
```

したがってCC側で以下を実行し、P3へ結果を記録する必要がある。

```powershell
.\mvnw.cmd -q -DskipTests compile
```

target/classesの `app.version=v2.3.5` は確認できるが、今回の最終状態のcompile成功証跡としては不十分。

## 外部QAとしてのシステム対策評価

### 良い点

- `AGENTS.md` を圧縮し、詳細運用を `docs/handoff/WORKFLOW_RULES.md` に分けた判断は良い。
  長すぎる最上位マニュアルは読まれにくく、AIが重要ルールを落としやすい。
- 起動時の「タスク重要度・事前宣言」は、今回のようなAir越権実装を止めるための入口ゲートとして有効。
- 「金額計算や帳票出力は問答無用で危険タスク」と明記した点は非常に重要。

### 懸念点

- `AGENTS.md` の第0章は「Kazumaxの承認を得る」と書いているが、実際の運用でAIが勝手に承認済みと解釈しないよう、承認文言の明確化が必要。
  例: `Kazumaxが明示的に「承認」「進めて」と返すまでコード編集禁止`
- `AGENTS.md` から詳細ルールを分離したことで、`WORKFLOW_RULES.md` を読まないAIが出ると逆に抜ける。
  今回のように「必ず併読」と書くのは良いが、各引き継ぎ文にも `WORKFLOW_RULES.md` を入れるとさらに強い。
- Airの直接実装許可範囲がまだ残ると、再発余地がある。
  HTML/CSSだけの軽微表示修正を除き、Java/Mapper/Excel/DB/金額計算はAir直接編集禁止、と明文化した方がよい。

### 客観QAとしての推奨

今回の対策は方向性として正しいが、まだ「宣言ルール」に寄っている。
再発防止を強くするなら、以下のような機械的ゲートが必要。

1. Java、Mapper、Excel、DB、`schema.sql`、`ExcelExportService.java` をAirが変更した場合は、自動的に危険タスク扱い。
2. Airが危険タスク対象ファイルを変更した場合、P3ではなく「越権実装」としてDex事後レビューに回す。
3. 危険タスクでは `git status --short` と未追跡ファイル一覧をP3必須項目にする。
4. resources配下の未追跡ファイルはP4で原則NG。

## Take3への指示

CCは以下を行うこと。

1. `replace.py`, `test.py`, `src/main/resources/templates/test.py` を削除または作業外へ退避する。
2. `target/classes/templates/test.py` もビルド成果物混入として除去される状態にする。
3. `git status --short` をP3に記録し、今回コミット対象と別件差分を明確に分ける。
4. `.\mvnw.cmd -q -DskipTests compile` を実行し、結果をP3に記録する。
5. `docs/handoff/P3_CC_to_Dex/cycle_9_post_review_take3.md` を作成してDexへ再提出する。

## 判定

コードロジックは **OK寄り**。
成果物混入と検証未完了により、リリース判断は **NG継続**。

