[Dex => Air/Kazumax]

# Cycle 13後の候補: 複数Expenseデータの編集UI整理

## 提案

Cycle 13では、画面表示・preview・Excel出力の金額合算を優先して直す。
ただし、既存の `ActivityController.editForm(...)` には `exList.get(0)` が残り、1参加者に複数Expenseがあるデータを編集画面で完全には扱えない。

## 理由

- `expenses.project_participant_id` にUNIQUE制約がないため、DB構造上は1参加者に複数Expenseを持てる。
- 一方、現在の入力フォームは「参加者1人につき経費1行」のUIになっている。
- Cycle 13でここまで直すと、金額表示修正から編集UI再設計へ広がりすぎる。

## 推奨

Cycle 13完了後、必要なら別サイクルで以下を決める。

- 1参加者1Expenseに運用を固定するのか
- 1参加者複数Expenseを正式対応するのか
- 複数Expenseがある既存データを編集画面でどう見せるのか
- 保存時に複数Expenseを消してしまわないようにするか

現時点では、Cycle 13のスコープ外として記録する。
