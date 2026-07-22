# [C9: Dex(P4) ⇒ CC(P3) / Air(P1)] CC判断回答とAirマニュアル対策レビュー

## 結論

### CCへの判断

**A案を採用。**

ただし「Kazumaxが手動削除」ではなく、Kazumaxの明示承認を受けたうえで、CCが以下3ファイルを**個別パス指定で削除**するのがよい。

- `replace.py`
- `test.py`
- `src/main/resources/templates/test.py`

加えて、ビルド成果物へ混入済みの以下も消える状態にする。

- `target/classes/templates/test.py`

推奨手順:

1. Kazumaxがこの3ファイル削除を明示承認する。
2. CCが `Remove-Item -LiteralPath` で3ファイルを個別削除する。
3. 可能なら `mvn clean compile`、少なくとも `target/classes/templates/test.py` が残らないことを確認する。
4. `git status --short` をP3に記録する。
5. `.\mvnw.cmd -q -DskipTests compile` の結果をP3に記録する。

### B案/C案について

**B案は不可。**

`.gitignore` に入れても、`src/main/resources/templates/test.py` がワークツリーに存在する限り、Maven/Gradle等のresourcesコピー対象になり得る。
実際に `target/classes/templates/test.py` へ混入していたため、「未追跡だから今回対象外」は安全ではない。

**C案も不可。**

金額計算・Excel帳票の危険タスク中に、resources配下の不要ファイルを次サイクルへ持ち越すのは安全基準に合わない。

## CC向けの具体指示

CCは以下を実行すること。

1. Kazumaxの明示承認を受けたうえで、以下を削除する。

```powershell
Remove-Item -LiteralPath 'replace.py'
Remove-Item -LiteralPath 'test.py'
Remove-Item -LiteralPath 'src/main/resources/templates/test.py'
```

2. `target/classes/templates/test.py` が残る場合は、ビルド成果物混入を解消する。
   推奨は `mvn clean compile` 相当。
   もし `mvn clean` が使えない場合は、P3に理由を書いたうえで、該当生成物の扱いを明記する。

3. `git status --short` をP3へ貼る。

4. 今回コミット対象を原則以下に限定する。

- `src/main/java/com/miyazaki/icehockey/budgetsystem/service/ExcelExportService.java`
- 必要なP3報告書

5. `AGENTS.md` や `AI_TEAM_WORKFLOW.md` などのマニュアル差分は、今回のExcel修正コミットに混ぜない。

## Airマニュアル対策への外部QAレビュー

### 良い点

1. `AGENTS.md` を圧縮して最上位ルールに絞り、詳細を `docs/handoff/WORKFLOW_RULES.md` へ分離したのは良い。
   長すぎるマニュアルはAIが読み落としやすい。

2. 「タスク重要度・事前宣言」を第0章に置いたのは、Air越権対策として有効。
   実装前に危険度・実行計画を明示する構造は、今回の事故に直接効く。

3. 「金額計算や帳票出力は問答無用で危険タスク」と明記した点は強い。
   今回の根本原因に対して、ルール文としては正しい方向。

### 懸念点

1. 起動時の定型文に `WORKFLOW_RULES.md` が入っていない。
   `AGENTS.md` は `WORKFLOW_RULES.md` 併読を求めているが、次担当へのコピペ文では `AGENTS.md` と `CURRENT_STATUS.md` だけになっている。
   新チャットでも確実に読ませるなら、起動文に `WORKFLOW_RULES.md` も入れるべき。

2. 「Kazumaxの承認」が曖昧。
   AIが「依頼されたから承認済み」と解釈する余地がある。
   `Kazumaxが明示的に「承認」「進めて」と返すまでコード編集禁止` と書くとより強い。

3. Air直接実装禁止のファイル種別ゲートがまだ弱い。
   危険タスク判定は書かれているが、機械的なファイルベースの禁止があると再発防止力が上がる。

### 推奨する追記

`AGENTS.md` または `WORKFLOW_RULES.md` に以下を追加することを推奨。

```text
Airは以下のファイル・領域を直接編集してはならない。
- src/main/java/
- src/main/resources/mapper/
- src/main/resources/schema.sql
- src/main/resources/*.xlsx
- ExcelExportService.java
- DB、金額計算、帳票セル座標、Excel出力に関わるコード

これらに関する修正は、必ずP1/P2草案を作成し、Dex事前監査またはCC実装へ渡す。
```

また、引き継ぎ冒頭文を以下へ更新することを推奨。

```text
まず AGENTS.md、docs/handoff/WORKFLOW_RULES.md、docs/handoff/CURRENT_STATUS.md を読んで、現在地・次担当・完了時ルールを確認してから作業して。
長文レビューや次担当への正式引き継ぎは docs/handoff/ に保存し、チャットは短い合図文だけにして。
プラスアルファ提案がある場合は docs/proposals/ にも同じ内容を保存して。
```

## 判断

- CCへの判断: **A案（明示承認つき個別削除）**
- Airマニュアル対策: **方向性OK。ただし `WORKFLOW_RULES.md` 併読の徹底、承認文言の明確化、Air直接編集禁止領域の明文化が必要**

