#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner 第1段階 統合テストハーネス（外部Claude通信なし）

.DESCRIPTION
    maestro_runner.ps1 を dot-source（$env:MAESTRO_NO_MAIN）で読み込み、
    一時ディレクトリ上で manifest 検証・PAUSE・再起動・二重起動・quarantine を
    外部通信なしで自動検証する。Dex P4 Take4 修正必須4 対応。

.EXAMPLE
    .\scripts\maestro_runner.tests.ps1
#>

$ErrorActionPreference = "Continue"

# ── テスト集計 ───────────────────────────────────────────────────────────
$script:passCount = 0
$script:failCount = 0

function Assert-That {
    param([string]$Name, [bool]$Condition, [string]$Detail = "")
    if ($Condition) {
        $script:passCount++
        Write-Host ("  [PASS] {0}" -f $Name) -ForegroundColor Green
    } else {
        $script:failCount++
        Write-Host ("  [FAIL] {0}  {1}" -f $Name, $Detail) -ForegroundColor Red
    }
}

# ── maestro_runner.ps1 を関数のみ dot-source ─────────────────────────────
$env:MAESTRO_NO_MAIN = "1"
. "$PSScriptRoot\maestro_runner.ps1"
$env:MAESTRO_NO_MAIN = $null

# ── 一時テスト領域へ各パス変数を差し替え ─────────────────────────────────
$script:tmpRoot   = Join-Path ([System.IO.Path]::GetTempPath()) ("maestro_test_" + [guid]::NewGuid().ToString("N").Substring(0,8))
$script:ProjectRoot   = $tmpRoot
$script:MaestroDir    = Join-Path $tmpRoot "docs\handoff\maestro"
$script:AllowedP1Root = Join-Path $tmpRoot "docs\handoff\P1_Air_Blueprint"
$script:QuarantineDir = Join-Path $MaestroDir "quarantine"
$script:PauseFile     = Join-Path $MaestroDir "PAUSE"
$script:LogFile       = Join-Path $MaestroDir "maestro.log"
$script:ProcessedLog  = Join-Path $MaestroDir "processed.log"
$script:LockFile      = Join-Path $MaestroDir "maestro.lock"

# ── ヘルパー ─────────────────────────────────────────────────────────────
function Reset-Env {
    foreach ($d in @($MaestroDir, $AllowedP1Root)) {
        if (Test-Path $d) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
    }
    New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AllowedP1Root -Force | Out-Null
    $script:ProcessedSet = @{}
}

function New-TestP1 {
    param([string]$RelPath, [string]$Content = "test p1 content")
    $full = Join-Path $ProjectRoot $RelPath
    $dir  = Split-Path -Parent $full
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($full, $Content, [System.Text.UTF8Encoding]::new($false))
    return (Get-FileHash -Path $full -Algorithm SHA256).Hash.ToLower()
}

function New-TestManifest {
    param([string]$Path, [hashtable]$Fields)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ($Fields | ConvertTo-Json -Depth 5) | Set-Content -Path $Path -Encoding UTF8
}

function Get-ProcessedLineCount {
    if (-not (Test-Path $ProcessedLog)) { return 0 }
    return @(Get-Content $ProcessedLog | Where-Object { $_ -match '\S' }).Count
}

function Get-QuarantineCount {
    if (-not (Test-Path $QuarantineDir)) { return 0 }
    return @(Get-ChildItem $QuarantineDir -Filter "*.rejected.json" -ErrorAction SilentlyContinue).Count
}

function New-ValidFields {
    param([string]$Cycle, [int]$Revision, [string]$Hash, [string]$P1Rel)
    return @{
        schema_version = 1
        producer       = "air"
        cycle          = $Cycle
        revision       = $Revision
        p1_file        = $P1Rel
        p1_sha256      = $Hash
        created_at     = "2026-06-19T12:00:00+09:00"
    }
}

Write-Host ""
Write-Host "=== Maestro Runner 第1段階 統合テスト ===" -ForegroundColor Cyan
Write-Host "一時領域: $tmpRoot" -ForegroundColor DarkGray
Write-Host ""

try {
    # ─── A: 検知・一回性 ─────────────────────────────────────────────────
    Write-Host "[A] 検知と一回性" -ForegroundColor White

    # A1: 起動前配置 → 1回だけ処理
    Reset-Env
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\a1.md"
    New-TestManifest (Join-Path $MaestroDir "a1.ready.json") (New-ValidFields "cycA1" 1 $h "docs/handoff/P1_Air_Blueprint/a1.md")
    Initialize-ProcessedSet
    Invoke-PendingScan
    Invoke-PendingScan   # 2回目スキャンでも増えないこと
    Assert-That "A1 起動前配置が1回だけ処理される" ((Get-ProcessedLineCount) -eq 1) "processed=$(Get-ProcessedLineCount)"

    # A2: サブディレクトリ配置 (cycle_n/revision_n/air.ready.json) → 検知
    Reset-Env
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\a2.md"
    New-TestManifest (Join-Path $MaestroDir "cycle_9\revision_1\air.ready.json") (New-ValidFields "cycA2" 1 $h "docs/handoff/P1_Air_Blueprint/a2.md")
    Initialize-ProcessedSet
    Invoke-PendingScan
    Assert-That "A2 サブディレクトリ配置を検知" ($ProcessedSet.ContainsKey("cycA2:r1"))

    # A3: temp→ready rename → 1回だけ処理（走査が正本）
    Reset-Env
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\a3.md"
    $tmp = Join-Path $MaestroDir "a3.tmp"
    New-TestManifest $tmp (New-ValidFields "cycA3" 1 $h "docs/handoff/P1_Air_Blueprint/a3.md")
    Rename-Item -Path $tmp -NewName "a3.ready.json"
    Initialize-ProcessedSet
    Invoke-PendingScan
    Invoke-PendingScan
    Assert-That "A3 temp→rename後に1回だけ処理される" ((Get-ProcessedLineCount) -eq 1) "processed=$(Get-ProcessedLineCount)"

    # ─── B: 重複・再起動・二重起動 ───────────────────────────────────────
    Write-Host "[B] 重複防止・再起動・二重起動" -ForegroundColor White

    # B1: 同一revision再通知 → 1回
    Reset-Env
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\b1.md"
    $mf = Join-Path $MaestroDir "b1.ready.json"
    New-TestManifest $mf (New-ValidFields "cycB1" 1 $h "docs/handoff/P1_Air_Blueprint/b1.md")
    $script:ProcessedSet = @{}
    $r1 = Process-Manifest -ManifestPath $mf
    $r2 = Process-Manifest -ManifestPath $mf   # 2回目
    Assert-That "B1 同一revision再通知は2回目スキップ" (($null -ne $r1) -and ($null -eq $r2) -and (Get-ProcessedLineCount) -eq 1)

    # B2: Runner再起動 (ProcessedSet復元) → 再処理しない
    Reset-Env
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\b2.md"
    $mf = Join-Path $MaestroDir "b2.ready.json"
    New-TestManifest $mf (New-ValidFields "cycB2" 1 $h "docs/handoff/P1_Air_Blueprint/b2.md")
    $script:ProcessedSet = @{}
    $null = Process-Manifest -ManifestPath $mf      # 1回処理
    $script:ProcessedSet = @{}                       # メモリ消失（プロセス終了相当）
    Initialize-ProcessedSet                          # 再起動: processed.logから復元
    $r = Process-Manifest -ManifestPath $mf          # 再提示
    Assert-That "B2 再起動後は同一revisionを再処理しない" (($null -eq $r) -and (Get-ProcessedLineCount) -eq 1)

    # B3: 二重起動防止 (named mutex) — 別プロセス(ジョブ)で1つ目を保持させる
    #     ※同一スレッドの named mutex は再入可能なため、別プロセスで検証する
    $job = Start-Job -ScriptBlock {
        $m = New-Object System.Threading.Mutex($false, "Global\MaestroRunnerBudgetSystem")
        $got = $m.WaitOne(0)
        Start-Sleep -Seconds 3
        if ($got) { $m.ReleaseMutex() }
        $m.Dispose()
        return $got
    }
    Start-Sleep -Milliseconds 800   # ジョブが mutex を取得するまで待つ
    $m2 = New-Object System.Threading.Mutex($false, "Global\MaestroRunnerBudgetSystem")
    $got2 = $m2.WaitOne(0)
    Assert-That "B3 二重起動はmutexで2つ目が取得失敗(別プロセス)" (-not $got2) "got2=$got2"
    if ($got2) { $m2.ReleaseMutex() }
    $m2.Dispose()
    Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null

    # B4: 起動時スキャン失敗後にmutex解放され再起動可能
    Reset-Env
    $script:ProcessedSet = @{}
    Initialize-ProcessedSet
    Enter-SingleInstance
    try { throw "起動時スキャン失敗の模擬" } catch {} finally { Exit-SingleInstance }
    $reEntered = $false
    try { Enter-SingleInstance; $reEntered = $true } catch {} finally { Exit-SingleInstance }
    Assert-That "B4 スキャン失敗後にmutex解放→再起動可能" $reEntered

    # ─── C: 形式不正で後続に進まない（quarantine / PAUSE）─────────────────
    Write-Host "[C] 形式不正の隔離・停止" -ForegroundColor White

    # C1: JSON不正 → quarantine + PAUSE
    Reset-Env
    $script:ProcessedSet = @{}
    Set-Content -Path (Join-Path $MaestroDir "c1.ready.json") -Value "{ broken json ::" -Encoding UTF8
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c1.ready.json")
    Assert-That "C1 JSON不正→null+quarantine+PAUSE" (($null -eq $r) -and (Get-QuarantineCount) -eq 1 -and (Test-Path $PauseFile))

    # C2: 必須値不足 → quarantine
    Reset-Env
    $script:ProcessedSet = @{}
    New-TestManifest (Join-Path $MaestroDir "c2.ready.json") @{ schema_version = 1; producer = "air"; cycle = "x" }
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c2.ready.json")
    Assert-That "C2 必須値不足→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C3: schema_version=1.5 (小数) → quarantine
    Reset-Env
    $script:ProcessedSet = @{}
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c3.md"
    $f = New-ValidFields "cycC3" 1 $h "docs/handoff/P1_Air_Blueprint/c3.md"; $f.schema_version = 1.5
    New-TestManifest (Join-Path $MaestroDir "c3.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c3.ready.json")
    Assert-That "C3 schema_version=1.5→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C4: revision=1.5 (小数) → quarantine（丸めて通さない）
    Reset-Env
    $script:ProcessedSet = @{}
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c4.md"
    $f = New-ValidFields "cycC4" 1 $h "docs/handoff/P1_Air_Blueprint/c4.md"; $f.revision = 1.5
    New-TestManifest (Join-Path $MaestroDir "c4.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c4.ready.json")
    Assert-That "C4 revision=1.5→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C5: revision=Int32超 (2147483648) → quarantine（例外で落ちない）
    Reset-Env
    $script:ProcessedSet = @{}
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c5.md"
    $f = New-ValidFields "cycC5" 1 $h "docs/handoff/P1_Air_Blueprint/c5.md"; $f.revision = [long]2147483648
    New-TestManifest (Join-Path $MaestroDir "c5.ready.json") $f
    $threw = $false
    try { $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c5.ready.json") } catch { $threw = $true }
    Assert-That "C5 revision Int32超→例外なくquarantine" ((-not $threw) -and ($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C6: cycleに不正文字 (改行/コロン) → quarantine
    Reset-Env
    $script:ProcessedSet = @{}
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c6.md"
    $f = New-ValidFields "bad:r9|x" 1 $h "docs/handoff/P1_Air_Blueprint/c6.md"
    New-TestManifest (Join-Path $MaestroDir "c6.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c6.ready.json")
    Assert-That "C6 cycle不正文字→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C7: created_at 非ISO → quarantine
    Reset-Env
    $script:ProcessedSet = @{}
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c7.md"
    $f = New-ValidFields "cycC7" 1 $h "docs/handoff/P1_Air_Blueprint/c7.md"; $f.created_at = "June 19, 2026"
    New-TestManifest (Join-Path $MaestroDir "c7.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c7.ready.json")
    Assert-That "C7 created_at非ISO→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C8: 許可外パス (..) → PAUSE
    Reset-Env
    $script:ProcessedSet = @{}
    $f = New-ValidFields "cycC8" 1 ("a"*64) "docs/handoff/P1_Air_Blueprint/../../../secret.md"
    New-TestManifest (Join-Path $MaestroDir "c8.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c8.ready.json")
    Assert-That "C8 許可外パス(..)→null+PAUSE" (($null -eq $r) -and (Test-Path $PauseFile))

    # C9: P1がディレクトリ → quarantine
    Reset-Env
    $script:ProcessedSet = @{}
    New-Item -ItemType Directory -Path (Join-Path $AllowedP1Root "c9dir") -Force | Out-Null
    $f = New-ValidFields "cycC9" 1 ("b"*64) "docs/handoff/P1_Air_Blueprint/c9dir"
    New-TestManifest (Join-Path $MaestroDir "c9.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c9.ready.json")
    Assert-That "C9 P1がディレクトリ→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)

    # C10: SHA-256不一致 → PAUSE
    Reset-Env
    $script:ProcessedSet = @{}
    $null = New-TestP1 "docs\handoff\P1_Air_Blueprint\c10.md"
    $f = New-ValidFields "cycC10" 1 ("c"*64) "docs/handoff/P1_Air_Blueprint/c10.md"
    New-TestManifest (Join-Path $MaestroDir "c10.ready.json") $f
    $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c10.ready.json")
    Assert-That "C10 SHA-256不一致→null+PAUSE" (($null -eq $r) -and (Test-Path $PauseFile))

    # C11: 履歴書込失敗 → PAUSE, 後続に進まない
    Reset-Env
    $script:ProcessedSet = @{}
    New-Item -ItemType Directory -Path $ProcessedLog -Force | Out-Null  # processed.log をディレクトリ化して書込失敗を誘発
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c11.md"
    $mf = Join-Path $MaestroDir "c11.ready.json"
    New-TestManifest $mf (New-ValidFields "cycC11" 1 $h "docs/handoff/P1_Air_Blueprint/c11.md")
    $r = Process-Manifest -ManifestPath $mf
    Assert-That "C11 履歴書込失敗→null+PAUSE" (($null -eq $r) -and (Test-Path $PauseFile))
    Remove-Item $ProcessedLog -Recurse -Force -ErrorAction SilentlyContinue

    # ─── D: PAUSE回収・quarantine再処理防止 ──────────────────────────────
    Write-Host "[D] PAUSE回収・隔離後の再処理防止" -ForegroundColor White

    # D1: PAUSE中はスキップ、PAUSE解除後に回収
    Reset-Env
    $script:ProcessedSet = @{}
    New-Item -ItemType File -Path $PauseFile -Force | Out-Null
    $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\d1.md"
    New-TestManifest (Join-Path $MaestroDir "d1.ready.json") (New-ValidFields "cycD1" 1 $h "docs/handoff/P1_Air_Blueprint/d1.md")
    Initialize-ProcessedSet
    Invoke-PendingScan                       # PAUSE中: 処理されない
    $duringPause = $ProcessedSet.ContainsKey("cycD1:r1")
    Remove-Item $PauseFile -Force
    Invoke-PendingScan                       # 解除後: 回収
    $afterPause = $ProcessedSet.ContainsKey("cycD1:r1")
    Assert-That "D1 PAUSE中スキップ→解除後に回収" ((-not $duringPause) -and $afterPause)

    # D2: quarantine されたmanifestをスキャンが再処理しない
    Reset-Env
    $script:ProcessedSet = @{}
    New-TestManifest (Join-Path $MaestroDir "d2.ready.json") @{ schema_version = 1; producer = "air" }  # 必須値不足→quarantine
    Initialize-ProcessedSet
    Invoke-PendingScan
    $qAfter1 = Get-QuarantineCount
    if (Test-Path $PauseFile) { Remove-Item $PauseFile -Force }
    Invoke-PendingScan                       # 再スキャン: quarantineの.rejected.jsonは拾わない
    Invoke-PendingScan
    $qAfter3 = Get-QuarantineCount
    Assert-That "D2 quarantine後に再処理されない(件数不変)" (($qAfter1 -eq 1) -and ($qAfter3 -eq 1)) "after1=$qAfter1 after3=$qAfter3"

} finally {
    if (Test-Path $tmpRoot) { Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ── 結果サマリー ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ("結果: PASS={0}  FAIL={1}" -f $passCount, $failCount) -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "=========================================" -ForegroundColor Cyan
if ($failCount -gt 0) { exit 1 } else { exit 0 }
