# [C10: CC(P3)] Cycle 10 Take 5 実装報告書

作成日: 2026-06-24
作成者: CC (Claude Code)
バージョン: v2.1.12
対象: `scripts/maestro_runner.ps1` / `scripts/maestro_runner.tests.ps1`

---

## 1. 対象と背景

Cycle 10 は「Maestro Runner Phase 2 (CC自動起動とサンドボックス確認)」の実装サイクルです。  
Take 5 として、Dex の Take 4 レビュー (`docs/handoff/P4_Dex_Review/cycle_10_take4.md`) で指摘された修正必須3件を実施しました。

---

## 2. 修正内容

### Fix1: `Invoke-PendingScan` 経由でも Phase 2 自動起動に進む

**問題**: `Start-Watching` のイベント検知経路だけが `Invoke-ClaudeAgent` に進む実装になっていた。  
**修正**:
- `Invoke-Phase2IfAllowed` 関数を新規作成し、バリデーション済み manifest から Phase 2 起動判定を共通化。
- `Invoke-PendingScan` に `[bool]$AllowPhase2 = $false` パラメータを追加。
- `Invoke-PendingScan` 内で `Invoke-Phase2IfAllowed -Result $result -AllowPhase2 $AllowPhase2` を呼ぶ。
- `Start-Watching` 内の既存インライン処理も `Invoke-Phase2IfAllowed` を呼ぶ形に統一。

**ガード維持**:
- `-TestPhase2` なし → `Invoke-Phase2IfAllowed` は自動起動しない（WARN ログのみ）。
- cycle名が `test`/`dummy` 系でなければ自動起動しない（本番 P1 ガード）。

### Fix2: `git status` 失敗時に PAUSE

**問題**: `git status --porcelain 2>$null` で stderr を捨てており、監査失敗を無視していた。  
**修正**:
- baseline/after 両方で `git status --porcelain --untracked-files=all 2>&1` を実行し `$LASTEXITCODE` を確認。
- 失敗（exit != 0）時は即 `Require-Pause` で停止。
- `try { ... } catch { }` で `$ErrorActionPreference = "Stop"` 環境での stderr ErrorRecord throw にも対応。
- エラー文字列はログに記録（`$gitBaselineStderr` / `$gitAfterStderr`）。

### Fix3: 既存 dirty ファイルの内容変化を検知

**問題**: `$gitAfter | Where-Object { $gitBaseline -notcontains $_ }` の delta-only 方式では、起動前から dirty だったファイルへの CC による追記・変更を検知できなかった。  
**修正**:
- git baseline 取得時に `--untracked-files=all` でディレクトリではなく個別ファイルを列挙。
- 許可外の各ファイルについて、Claude 起動前に SHA-256 ハッシュを `$baselineHashes` に記録。
- Claude 完了後にハッシュを再計算し、変化したファイルを `$invalidPaths` に追加して PAUSE。

**除外設計**:
- `$allowedP3`（P3 ファイル）、`$allowedDone`（cc.done.json）、`$allowedTmp`（tmp/ 以下）は既存通り除外。
- `$maestroDirRel`（`docs/handoff/maestro/` 配下全体）を新規追加除外: `maestro.log` 等のランタイムファイルがハッシュ比較でfalse PAUSEを起こさないようにする。

---

## 3. 追加テスト（H7〜H11）

| テスト | 内容 | 結果 |
|--------|------|------|
| H7 | `Invoke-PendingScan -AllowPhase2 $true` + dummy cycle → ClaudeAgent 呼ばれ P3 作成 | PASS |
| H7(b) | `Invoke-PendingScan` 正常系 → PAUSE なし | PASS |
| H8 | 本番 cycle → ClaudeAgent 不呼び出し・警告のみ | PASS |
| H8(b) | 本番 cycle → PAUSE なし | PASS |
| H9 | git status 失敗（git repo なしのディレクトリ）→ Require-Pause → PAUSE 作成 | PASS |
| H10 | 起動前 dirty ファイルをスタブが変更 → ハッシュ変化検知 → PAUSE | PASS |
| H11 | 起動前 dirty ファイルをスタブが触らない → PAUSE なし | PASS |

全テスト: **PASS=49 FAIL=0**

---

## 4. テスト実行コマンド

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\maestro_runner.tests.ps1
```

---

## 5. 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|----------|----------|------|
| `scripts/maestro_runner.ps1` | 修正 | Fix1-Fix3 実装 |
| `scripts/maestro_runner.tests.ps1` | 修正 | H7〜H11 スタブテスト追加 |
| `src/main/resources/application.properties` | バージョン更新 | v2.1.11 → v2.1.12 |

---

## 6. Stop Conditions 遵守確認

- `git reset --hard` / `git restore .` / `git clean` の自動実行: **なし**
- 実 Claude 自動起動 (`-Watch -TestPhase2`): **実施していない**
- 本番 P1 での自動起動: **なし**
- 第3段階への進行: **なし**
- ANTHROPIC_API_KEY の設定・変更: **なし**
