[C10: Dex(P4) => CC(P3) Take3]

# Cycle 10 マニュアル再整理 Take2 差し戻し指示

## 判定

**NG / CC Take3対応待ち**

今回の問題は、入口ファイルの中身ではなく「作業単位の混在」です。勝手な自動ロールバックは禁止です。差分を読んだ上で、CCが次の方針で整理してください。

---

## CCへの修正指示

### 1. Cycle 10とCycle 11を分離する

Cycle 10 Take3として扱う変更は、原則として以下に限定してください。

- `AGENTS.md`
- `CLAUDE.md`
- `.cursorrules`
- `docs/handoff/CURRENT_STATUS.md`
- 必要なら `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take3.md`

`mvnw.cmd`, `docs/PROJECT_RULES.md`, `docs/handoff/WORKFLOW_RULES.md` のCycle 11相当変更は、Cycle 10 Take3のP3報告に混ぜないでください。

### 2. `CURRENT_STATUS.md` をCycle 10 Take3の現在地に戻す

`CURRENT_STATUS.md` は以下の意味になるよう更新してください。

- 今: Cycle 10 マニュアル再整理 Take3対応中、またはTake3完了
- 次: Dex(P4) 再レビュー
- 読むべきファイル:
  - `docs/handoff/P3_CC_to_Dex/cycle_10_manual_restructure_take3.md`
  - `docs/handoff/P4_Dex_Review/cycle_10_manual_restructure_take2.md`
  - `docs/handoff/P4_Rollback/cycle_10_manual_restructure_take2.md`

### 3. Cycle 11相当の変更は別扱いにする

`mvnw.cmd` の修正、`docs/PROJECT_RULES.md` のclean compile追記、`docs/handoff/WORKFLOW_RULES.md` の出口ゲート強化を残す場合は、Cycle 11として明示的に分けてください。

分け方はどちらかにしてください。

- A案: いったんCycle 10 Take3の報告から除外し、Cycle 10 P4 OK後にCycle 11としてDexへレビュー依頼する。
- B案: Cycle 11を続ける場合、Kazumaxに「Cycle 10とは別の運用改善として進めてよいか」を確認し、P3報告に検証結果を追加する。

### 4. P3報告と実際の差分を一致させる

Take3のP3報告には、実際に変更したファイルだけを列挙してください。

特に以下のような食い違いを残さないでください。

- 「`docs/PROJECT_RULES.md` は未変更」と書いているのに実際は変更されている
- 「`docs/handoff/WORKFLOW_RULES.md` は未変更」と書いているのに実際は変更されている
- `mvnw.cmd` を変更しているのに変更ファイル一覧にない

### 5. 自動ロールバックは禁止

`git reset --hard`, `git restore .`, `git clean` は実行しないでください。必要な整理は、差分を確認して手動で行ってください。

---

## Dexへの次回レビュー依頼文

Take3完了後、Kazumaxへ渡す合図文は単独コードブロックで出してください。

```text
CCのCycle 10 Take3修正が終わったよ。最新のファイルを読んで、Cycle 10マニュアル再整理のDIFFレビュー（P4）をして！
```
