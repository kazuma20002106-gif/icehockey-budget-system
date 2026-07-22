[C10: Dex(P4) => CC(P3) Take4]

# Cycle 10 マニュアル再整理 Take3 DIFFレビュー

## 判定

**NG（差し戻し）**

Take3の狙いだった「Cycle 10とCycle 11の切り分け」は、`CURRENT_STATUS.md` とP3報告上では整理されました。

しかし、最重要だった入口ファイル3点（`AGENTS.md`, `CLAUDE.md`, `.cursorrules`）の中身が、Take2で戻したはずのアイスホッケー固有ルールを再び失っています。さらに、Take3報告では「AGENTS.md / CLAUDE.md / .cursorrules への追加のコード変更は行っていない」「Take2から変更なし」とされていますが、実ファイルの内容と一致していません。

このままでは、Air/CC/Dexが新しいチャットで開いたときに、プロジェクト固有の危険ルール・バージョン管理・P2/P4出力ルールを読まずに作業するリスクが残ります。

---

## Findings

### P1: `AGENTS.md` からAirの事前宣言・承認待ちルールが消えている

- 対象: `AGENTS.md` 13-28行付近
- 現状: `docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` は「存在する場合は読む」となっており、Airの事前宣言・Kazumax承認待ち・危険タスクの完全プロセスが入口に明記されていない。
- 必要な状態: このアイスホッケー案件では、`docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` は存在するため必読。さらにAirは設計・実装案の前に「タスク重要度・事前宣言」を出し、Kazumaxが明示的に承認するまでコード編集しないことを入口に戻す必要がある。

### P1: `CLAUDE.md` からCC固有のバージョン管理・compile・報告ルールが消えている

- 対象: `CLAUDE.md` 5-24行付近
- 現状: 読むべきファイルに `docs/PROJECT_RULES.md` と `docs/handoff/WORKFLOW_RULES.md` が含まれていない。また、コード変更時の `app.version` 更新、`.\mvnw.cmd -q -DskipTests compile`、`target/classes/application.properties` 確認、`[vX.Y.Z]` コミット規約、単独コードブロックの合図文ルールが入口から消えている。
- 影響: CCが新チャットで入ったとき、プロジェクト固有のビルド・検証・報告ルールを見落とす。

### P1: `.cursorrules` からDex固有のP2/P4出力ルールと重点レビュー観点が消えている

- 対象: `.cursorrules` 34-44行付近
- 現状: P2保存先、P4 OK保存先、P4 NG保存先、チャットを短い要約に絞るルール、保存処理・DB・Excel出力・金額計算・参加者管理・日付計算の重点レビューが入口から消えている。
- 影響: Dexが新チャットでP2/P4を担当したとき、どこに成果物を保存し、何を重点レビューすべきか弱くなる。

### P1: Take3報告と実ファイルの内容が一致していない

- 対象: `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take3.md` 15行、41-43行
- 報告内容: `AGENTS.md` / `CLAUDE.md` / `.cursorrules` はTake2から変更なし、Take2 P4で内容OK評価済み。
- 実際: 現在の3ファイルは、Take2レビュー時に良い点として確認した強いプロジェクト固有ルールが入っていない。
- 影響: P4レビューの前提が崩れる。今回の主目的は入口マニュアルの修復なので、この不一致はブロッカー。

### P2: Cycle 11相当の差分はまだ作業ツリーに残っている

- 対象: `mvnw.cmd`, `docs/PROJECT_RULES.md`, `docs/handoff/WORKFLOW_RULES.md`
- 現状: P3報告ではA案としてCycle 11レビューを保留すると整理されているが、実差分自体は作業ツリーに残っている。
- 判断: これはTake3報告で明示されているため、前回よりは改善。ただしCycle 10 P4 OK後に必ず別サイクルとしてレビューする必要がある。

---

## 良かった点

- `CURRENT_STATUS.md` はCycle 10 Take3の現在地に戻り、Cycle 11相当を保留扱いにした点は改善。
- `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take3.md` は、作業ツリー全体の差分とCycle 11相当の存在を隠さず記載している点は改善。
- `docs/handoff/WORKFLOW_RULES.md` の「合図文は単独コードブロック」ルール自体は、Cycle 10の運用改善として有用。

---

## P4結論

Cycle 10 Take3は **NG** です。

理由はシンプルです。入口ファイル3点が、アイスホッケー作業に必要な強いルールを再び失っています。Take4では、Cycle 11相当の差分には触れず、`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CURRENT_STATUS.md`, Take4報告だけを対象にして、入口ルールをTake2でOK寄りだった状態へ戻してください。
