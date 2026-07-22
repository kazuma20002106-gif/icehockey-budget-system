# Dex提案 — Air越権対策の機械的ゲート化

## 提案

Air越権対策は「事前宣言」だけでなく、変更ファイル種別による機械的ゲートも追加する。

## 背景

`AGENTS.md` の圧縮と「タスク重要度・事前宣言」は良い改善。
ただし、AIがルールを読んでも、緊急修正や善意の判断で危険タスクを通常タスク扱いする余地は残る。

## 追加したいゲート

- `src/main/java/`
- `src/main/resources/mapper/`
- `src/main/resources/schema.sql`
- `src/main/resources/*.xlsx`
- `ExcelExportService.java`

上記にAirが触った場合、自動的に危険タスク扱いとし、Air直接実装禁止。
必ずDex事前監査、または越権実装としてDex事後レビューに回す。

## 期待効果

判断ミスではなく、変更対象ファイルで安全側に倒せる。
特に金額計算・Excel帳票・DB周辺の事故を減らせる。
