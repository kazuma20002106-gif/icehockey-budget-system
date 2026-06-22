# Cycle 9 CC実装完了報告書 (Take 12)

作成日: 2026-06-22
実装者: CC (Claude Code)
バージョン: v2.1.7

## Take 12: Dex差し戻し（Take 11 NG）への対応

Dex（P4）から Take 11 に対して3件の修正必須指摘が届いた。本 Take 12 はその全件に対応した。

---

## 修正必須1 対応: タイムアウト時にプロセスツリー全体を停止する

**問題**: `$proc.Kill()` は直接起動した root プロセスしか終了しない。スタブが起動した `ping`（子プロセス）がテスト終了後も残留した（Dex 計測で PID 46488 が約 30 秒生存）。

**対応**:

```powershell
# プロセスツリー全体を停止（子孫含む・無関係プロセスには触れない）
$rootPid = $proc.Id
try { $null = taskkill /F /T /PID $rootPid 2>$null } catch {}
# root の終了を確認（最大 5 秒）
$deadline = [DateTime]::UtcNow.AddSeconds(5)
$stopped  = $false
while ([DateTime]::UtcNow -lt $deadline) {
    try { $null = Get-Process -Id $rootPid -ErrorAction Stop }
    catch { $stopped = $true; break }
    Start-Sleep -Milliseconds 100
}
# 非同期タスクを回収してから破棄
try { $null = $stdoutTask.GetAwaiter().GetResult() } catch {}
try { $null = $stderrTask.GetAwaiter().GetResult() } catch {}
if (-not $stopped) {
    throw "タイムアウト後もプロセスが終了しませんでした (PID=$rootPid): 後続へ進めません"
}
throw "タイムアウト: claude が ${TimeoutSec}秒以内に終了しませんでした"
```

- `taskkill /F /T /PID` で root と全子孫を停止（`/T` = 子孫ツリー）
- 対象 PID の子孫のみ停止。無関係なプロセスには触れない
- 5 秒以内に root 消滅を確認。消滅しない場合は致命エラーで後続停止
- タイムアウト分岐でも非同期タスクを必ず回収してから `finally { Dispose() }`

---

## 修正必須2 対応: G7で子プロセス残留なしを実測する

**問題**: 旧 G7 は「`throw` したか」「5 秒以内に返ったか」だけを確認しており、子プロセス（`ping`）の残留を検査していなかった。

**対応**: sleep スタブを再設計し、root PID と child PID の両方を記録・消滅確認する。

**スタブ設計**:

| ファイル | 役割 |
|---|---|
| `stub_sleep.ps1` | `$PID` を `STUB_RECORD_FILE` へ記録 → `Start-Sleep -Seconds 30` |
| `stub_sleep.cmd` | `powershell.exe -File stub_sleep.ps1` を起動するラッパー |

`Invoke-ClaudeRaw` 内にテストフックを追加:
```powershell
if ($Script:ClaudeExeOverride -and $env:STUB_ROOT_PID_FILE) {
    try { Set-Content $env:STUB_ROOT_PID_FILE -Value $proc.Id -Encoding ASCII } catch {}
}
```

プロセスツリー:
- `cmd.exe`（stub_sleep.cmd）← root PID → `STUB_ROOT_PID_FILE` に記録
  - `powershell.exe`（stub_sleep.ps1）← child PID → `STUB_RECORD_FILE` に記録

G7 アサート:
```
rootPid > 0 かつ Get-Process -Id rootPid が失敗（消滅）
childPid > 0 かつ Get-Process -Id childPid が失敗（消滅）
elapsed < 10 秒
threw = true
```

---

## 修正必須3 対応: stderr を結果として保持し、失敗分類に使用する

**問題**: `stderrTask` の結果を `$null` へ捨てており、戻り値に `Error` フィールドがなかった。`Test-ClaudeConnection` の「Not logged in」分類が stdout のみを見ていたため、CLI が stderr へ出力した場合に判定できなかった。

**対応**:

1. 戻り値変更:
```powershell
return [PSCustomObject]@{ Output = $stdout; Error = $stderr; ExitCode = $proc.ExitCode }
```

2. `Test-ClaudeConnection` の分類を stdout + stderr に拡張:
```powershell
$outputLines = $r.Output -split "`n"
$errorLines  = $r.Error  -split "`n"
$allLines    = $outputLines + $errorLines
$isNotLoggedIn = ($allLines | Where-Object { $_ -match "Not logged in" }).Count -gt 0
```

3. JSON パースは stdout のみ継続（`$outputLines` で検索）

4. G8 を新設し stdout/stderr 分離を実測:
   - `stub_stderr.cmd`: stdout に JSON、stderr に `STUB_STDERR_CONTENT` を出力
   - `$r.Output -match '\{'` が true かつ `$r.Error -match 'STUB_STDERR_CONTENT'` が true でアサート

---

## 統合テスト結果（外部通信なし）

`maestro_runner.tests.ps1` の実行結果: **PASS=36 / FAIL=0**

G1-G8 全件 PASS（G7 子PID消滅実測・G8 stderr分離追加）。A1-A3, B1-B4, C1-C11, D1-D2, E1-E4, F1-F4 も変化なし PASS。

---

## Take 12 変更ファイル一覧

| ファイル | 種別 | 説明 |
|---|---|---|
| `scripts/maestro_runner.ps1` | **更新** | Fix1: taskkill /T でツリー停止、Fix3: `Error` フィールド追加・stderr 分類対応 |
| `scripts/maestro_runner.tests.ps1` | **更新** | Fix2: G7 root+child PID 消滅実測、G8 stderr 分離テスト新設 |
| `src/main/resources/application.properties` | **更新** | v2.1.7 へバージョンアップ |
| `docs/handoff/P3_CC_Report/cycle_9.md` | **更新** | 本報告書（Take 12: Dex差し戻し全件対応） |
| `docs/TEAM_CHAT.md` | **更新** | CC Take 12 完了エントリ追加 |

---

## セルフQA（CLAUDE.md準拠）

1. **変更対象確認**: Take 12 の変更は上記5ファイルのみ。巻き添え変更なし。

2. **P1 Verification Plan 照合**:
   - Phase 0 Step 1-4（疎通テスト・最小権限）: プロセスツリー停止・stderr 分類対応完了。
   - Phase 1 Step 1-4: 統合テスト PASS=36 確認。

3. **セキュリティ注記**:
   - `STUB_ROOT_PID_FILE` フックは `$Script:ClaudeExeOverride` が設定されているときのみ動作（本番時は null）。
   - stderr 全文はログに書かない制約を継続維持。
   - 秘密値・APIキー・session_id 全文の非記録を継続維持。

4. **バージョン同期**: `application.properties` と `target/classes/application.properties` 両方 v2.1.7 確認済み（`.\mvnw compile` 完了）。

5. **統合テスト**: PASS=36 / FAIL=0（F4 U+FFFD 0件も引き続き確認済み）。

---

## Dexへの確認事項

1. **G7 TimeoutSec=4 の妥当性**: CI 環境で `powershell.exe` 起動が 4 秒以上かかる場合、PID 記録前にタイムアウトが発火し `childPid=0` → テスト FAIL となる。Dex 環境での典型起動時間を確認し、必要なら値を調整したい。
2. **Phase 0 再実機確認（Air担当）**: Stop Conditions 解除後に Air による `-Test` での実機確認が必要。

---

## 現在のステータス

**Take 12: 実装完了。Dex（P4）レビュー待ち。**

Dex の Stop Conditions（`-Test` / `-TestResume` / `-Watch` 禁止・第2段階禁止・`maestro_loop.ps1` 禁止）は引き続き有効。
