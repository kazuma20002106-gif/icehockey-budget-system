[C10: CC(P3) ⇒ Dex(P4)]

# Cycle 10 マニュアル再整理 実装完了報告

## ステータス

**完了 / P4レビュー依頼**

---

## 実施内容

Air（P1）の修正方針（`docs/handoff/P1_Air_Blueprint/manual_restructure_review.md`）に従い、以下4ファイルを編集・作成した。

---

### 1. `docs/PROJECT_RULES.md`（新規作成）

- budget-system固有の危険ファイル一覧（`ExcelExportService.java`, `mapper/`, `schema.sql`, `*.xlsx`, `templates/`）
- 金額計算・Excelセル座標・テンプレート混入リスクの定義
- バージョン管理ルール（マニュアル変更のみはバージョンアップ不要を明記）
- Maven Wrapperの既知問題（Dex環境でのコンパイル不可）
- Kazumax代表の絶対方針の引用

---

### 2. `AGENTS.md`（編集）

**除去したもの**:
- `src/main/java/` 等のプロジェクト固有パスリスト（`PROJECT_RULES.md` へ移動）
- `application.properties` の具体パス（`PROJECT_RULES.md` 参照に変更）

**追加・変更したもの**:
- 起動ルール（セクション0）を4ステップに整理。`WORKFLOW_RULES.md` と `PROJECT_RULES.md` の読み込みを明記
- Air直接編集禁止領域を「`PROJECT_RULES.md` 参照」に汎化
- バージョン更新ルールに「マニュアルのみの変更は不要」を追加
- トラッキングタグ・Handoff Protocolを `WORKFLOW_RULES.md` への参照に整理

---

### 3. `docs/handoff/WORKFLOW_RULES.md`（編集）

**追加したもの**:
- **セクション7「予期せぬ破壊的変更時のリカバリプロトコル」**: Air含む全AIの越権・誤削除に対応する汎用的な5ステッププロセス
- **セクション6「出口ゲート」に `CURRENT_STATUS.md` 更新責任を明記**: フェーズを動かしたAI自身が必ず更新する旨を追加
- 起動テキスト（Bootstrap Text）を最新版（`PROJECT_RULES.md` を含む形）に更新

---

### 4. `docs/handoff/CURRENT_STATUS.md`（整理）

- 過去の長い履歴・完了済みサイクル表・旧来のStop Conditionsを削除
- 現在のCycle 10（マニュアル整備）のみに絞ったコンパクトな構成に変更
- Kazumaxが次にコピーする合図文を最新のBootstrap Textに更新

---

## 変更ファイル一覧

| ファイル | 操作 |
|---|---|
| `docs/PROJECT_RULES.md` | 新規作成 |
| `AGENTS.md` | 編集（プロジェクト固有パス除去・起動ルール更新） |
| `docs/handoff/WORKFLOW_RULES.md` | 編集（リカバリプロトコル追加・出口ゲート更新） |
| `docs/handoff/CURRENT_STATUS.md` | 整理（コンパクト化） |

---

## Dexへのレビュー依頼観点

1. `AGENTS.md` にプロジェクト固有のパスが残っていないか
2. `PROJECT_RULES.md` に不足している危険領域がないか
3. `WORKFLOW_RULES.md` のリカバリプロトコルが実運用上問題ないか
4. `CURRENT_STATUS.md` が「現在地だけ」のコンパクトな形になっているか
5. 4ファイル間でルールの矛盾・重複がないか

---

## 備考

- Javaコード・設定ファイル・Excelテンプレートへの変更はなし。バージョンアップなし。
- Cycle 9（様式2-2-1 Excel修正 Take3）は保留中。マニュアル整備完了後に再開予定。
