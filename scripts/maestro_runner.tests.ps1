#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner 第1段階 統合テストハーネス（外部Claude通信なし）

.DESCRIPTION
    maestro_runner.ps1 を dot-source（$env:MAESTRO_NO_MAIN）で読み込み、
    一時ディレクトリ上で manifest 検証・PAUSE・再起動・二重起動・quarantine を
    外部通信なしで自動検証する。
    Take11: G1〜G7をInvoke-ClaudeRaw実行テスト(スタブ)に置き換え。

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

# ── Run-Case: 各テストを try/catch で隔離し、想定外例外を FAIL 計上 ──────
function Run-Case {
    param([string]$CaseName, [scriptblock]$Body)
    try { & $Body }
    catch {
        $script:failCount++
        Write-Host ("  [FAIL] {0}  例外: {1}" -f $CaseName, ($_.ToString() -replace '\r?\n', ' ')) -ForegroundColor Red
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

# ── テスト専用 mutex 名（本番と分離）────────────────────────────────────
$MutexName = "Global\MaestroRunnerBudgetSystem_Test"

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

    Run-Case "A1" {
        Reset-Env
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\a1.md"
        New-TestManifest (Join-Path $MaestroDir "a1.ready.json") (New-ValidFields "cycA1" 1 $h "docs/handoff/P1_Air_Blueprint/a1.md")
        Initialize-ProcessedSet
        Invoke-PendingScan
        Invoke-PendingScan
        Assert-That "A1 起動前配置が1回だけ処理される" ((Get-ProcessedLineCount) -eq 1) "processed=$(Get-ProcessedLineCount)"
    }

    Run-Case "A2" {
        Reset-Env
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\a2.md"
        New-TestManifest (Join-Path $MaestroDir "cycle_9\revision_1\air.ready.json") (New-ValidFields "cycA2" 1 $h "docs/handoff/P1_Air_Blueprint/a2.md")
        Initialize-ProcessedSet
        Invoke-PendingScan
        Assert-That "A2 サブディレクトリ配置を検知" ($ProcessedSet.ContainsKey("cycA2:r1"))
    }

    Run-Case "A3" {
        Reset-Env
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\a3.md"
        $tmp = Join-Path $MaestroDir "a3.tmp"
        New-TestManifest $tmp (New-ValidFields "cycA3" 1 $h "docs/handoff/P1_Air_Blueprint/a3.md")
        Rename-Item -Path $tmp -NewName "a3.ready.json"
        Initialize-ProcessedSet
        Invoke-PendingScan
        Invoke-PendingScan
        Assert-That "A3 temp→rename後に1回だけ処理される" ((Get-ProcessedLineCount) -eq 1) "processed=$(Get-ProcessedLineCount)"
    }

    # ─── B: 重複・再起動・二重起動 ───────────────────────────────────────
    Write-Host "[B] 重複防止・再起動・二重起動" -ForegroundColor White

    Run-Case "B1" {
        Reset-Env
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\b1.md"
        $mf = Join-Path $MaestroDir "b1.ready.json"
        New-TestManifest $mf (New-ValidFields "cycB1" 1 $h "docs/handoff/P1_Air_Blueprint/b1.md")
        $script:ProcessedSet = @{}
        $r1 = Process-Manifest -ManifestPath $mf
        $r2 = Process-Manifest -ManifestPath $mf
        Assert-That "B1 同一revision再通知は2回目スキップ" (($null -ne $r1) -and ($null -eq $r2) -and (Get-ProcessedLineCount) -eq 1)
    }

    Run-Case "B2" {
        Reset-Env
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\b2.md"
        $mf = Join-Path $MaestroDir "b2.ready.json"
        New-TestManifest $mf (New-ValidFields "cycB2" 1 $h "docs/handoff/P1_Air_Blueprint/b2.md")
        $script:ProcessedSet = @{}
        $null = Process-Manifest -ManifestPath $mf
        $script:ProcessedSet = @{}
        Initialize-ProcessedSet
        $r = Process-Manifest -ManifestPath $mf
        Assert-That "B2 再起動後は同一revisionを再処理しない(正常ISO日時の復元確認)" (($null -eq $r) -and (Get-ProcessedLineCount) -eq 1)
    }

    Run-Case "B3" {
        $testMutex = $MutexName
        $job = Start-Job -ScriptBlock {
            param($mn)
            $m = New-Object System.Threading.Mutex($false, $mn)
            $got = $m.WaitOne(0)
            Start-Sleep -Seconds 3
            if ($got) { $m.ReleaseMutex() }
            $m.Dispose()
            return $got
        } -ArgumentList $testMutex
        Start-Sleep -Milliseconds 800
        $m2 = New-Object System.Threading.Mutex($false, $testMutex)
        $got2 = $m2.WaitOne(0)
        Assert-That "B3 二重起動はmutexで2つ目が取得失敗(別プロセス)" (-not $got2) "got2=$got2"
        if ($got2) { $m2.ReleaseMutex() }
        $m2.Dispose()
        Stop-Job $job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job $job -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Run-Case "B4" {
        Reset-Env
        $script:ProcessedSet = @{}
        Initialize-ProcessedSet
        Enter-SingleInstance
        try { throw "起動時スキャン失敗の模擬" } catch {} finally { Exit-SingleInstance }
        $reEntered = $false
        try { Enter-SingleInstance; $reEntered = $true } catch {} finally { Exit-SingleInstance }
        Assert-That "B4 スキャン失敗後にmutex解放→再起動可能" $reEntered
    }

    # ─── C: 形式不正で後続に進まない ─────────────────────────────────────
    Write-Host "[C] 形式不正の隔離・停止" -ForegroundColor White

    Run-Case "C1" {
        Reset-Env; $script:ProcessedSet = @{}
        Set-Content -Path (Join-Path $MaestroDir "c1.ready.json") -Value "{ broken json ::" -Encoding UTF8
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c1.ready.json")
        Assert-That "C1 JSON不正→null+quarantine+PAUSE" (($null -eq $r) -and (Get-QuarantineCount) -eq 1 -and (Test-Path $PauseFile))
    }

    Run-Case "C2" {
        Reset-Env; $script:ProcessedSet = @{}
        New-TestManifest (Join-Path $MaestroDir "c2.ready.json") @{ schema_version = 1; producer = "air"; cycle = "x" }
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c2.ready.json")
        Assert-That "C2 必須値不足→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C3" {
        Reset-Env; $script:ProcessedSet = @{}
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c3.md"
        $f = New-ValidFields "cycC3" 1 $h "docs/handoff/P1_Air_Blueprint/c3.md"; $f.schema_version = 1.5
        New-TestManifest (Join-Path $MaestroDir "c3.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c3.ready.json")
        Assert-That "C3 schema_version=1.5→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C4" {
        Reset-Env; $script:ProcessedSet = @{}
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c4.md"
        $f = New-ValidFields "cycC4" 1 $h "docs/handoff/P1_Air_Blueprint/c4.md"; $f.revision = 1.5
        New-TestManifest (Join-Path $MaestroDir "c4.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c4.ready.json")
        Assert-That "C4 revision=1.5→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C5" {
        Reset-Env; $script:ProcessedSet = @{}
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c5.md"
        $f = New-ValidFields "cycC5" 1 $h "docs/handoff/P1_Air_Blueprint/c5.md"; $f.revision = [long]2147483648
        New-TestManifest (Join-Path $MaestroDir "c5.ready.json") $f
        $threw = $false
        try { $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c5.ready.json") } catch { $threw = $true }
        Assert-That "C5 revision Int32超→例外なくquarantine" ((-not $threw) -and ($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C6" {
        Reset-Env; $script:ProcessedSet = @{}
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c6.md"
        $f = New-ValidFields "bad:r9|x" 1 $h "docs/handoff/P1_Air_Blueprint/c6.md"
        New-TestManifest (Join-Path $MaestroDir "c6.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c6.ready.json")
        Assert-That "C6 cycle不正文字→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C7" {
        Reset-Env; $script:ProcessedSet = @{}
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c7.md"
        $f = New-ValidFields "cycC7" 1 $h "docs/handoff/P1_Air_Blueprint/c7.md"; $f.created_at = "June 19, 2026"
        New-TestManifest (Join-Path $MaestroDir "c7.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c7.ready.json")
        Assert-That "C7 created_at非ISO→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C8" {
        Reset-Env; $script:ProcessedSet = @{}
        $f = New-ValidFields "cycC8" 1 ("a"*64) "docs/handoff/P1_Air_Blueprint/../../../secret.md"
        New-TestManifest (Join-Path $MaestroDir "c8.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c8.ready.json")
        Assert-That "C8 許可外パス(..)→null+PAUSE" (($null -eq $r) -and (Test-Path $PauseFile))
    }

    Run-Case "C9" {
        Reset-Env; $script:ProcessedSet = @{}
        New-Item -ItemType Directory -Path (Join-Path $AllowedP1Root "c9dir") -Force | Out-Null
        $f = New-ValidFields "cycC9" 1 ("b"*64) "docs/handoff/P1_Air_Blueprint/c9dir"
        New-TestManifest (Join-Path $MaestroDir "c9.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c9.ready.json")
        Assert-That "C9 P1がディレクトリ→null+quarantine" (($null -eq $r) -and (Get-QuarantineCount) -eq 1)
    }

    Run-Case "C10" {
        Reset-Env; $script:ProcessedSet = @{}
        $null = New-TestP1 "docs\handoff\P1_Air_Blueprint\c10.md"
        $f = New-ValidFields "cycC10" 1 ("c"*64) "docs/handoff/P1_Air_Blueprint/c10.md"
        New-TestManifest (Join-Path $MaestroDir "c10.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "c10.ready.json")
        Assert-That "C10 SHA-256不一致→null+PAUSE" (($null -eq $r) -and (Test-Path $PauseFile))
    }

    Run-Case "C11" {
        Reset-Env; $script:ProcessedSet = @{}
        New-Item -ItemType Directory -Path $ProcessedLog -Force | Out-Null
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\c11.md"
        $mf = Join-Path $MaestroDir "c11.ready.json"
        New-TestManifest $mf (New-ValidFields "cycC11" 1 $h "docs/handoff/P1_Air_Blueprint/c11.md")
        $r = Process-Manifest -ManifestPath $mf
        Assert-That "C11 履歴書込失敗(PAUSE可)→null+PAUSE" (($null -eq $r) -and (Test-Path $PauseFile))
        Remove-Item $ProcessedLog -Recurse -Force -ErrorAction SilentlyContinue
    }

    # ─── D: PAUSE回収・quarantine再処理防止 ──────────────────────────────
    Write-Host "[D] PAUSE回収・隔離後の再処理防止" -ForegroundColor White

    Run-Case "D1" {
        Reset-Env; $script:ProcessedSet = @{}
        New-Item -ItemType File -Path $PauseFile -Force | Out-Null
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\d1.md"
        New-TestManifest (Join-Path $MaestroDir "d1.ready.json") (New-ValidFields "cycD1" 1 $h "docs/handoff/P1_Air_Blueprint/d1.md")
        Initialize-ProcessedSet
        Invoke-PendingScan
        $duringPause = $ProcessedSet.ContainsKey("cycD1:r1")
        Remove-Item $PauseFile -Force
        Invoke-PendingScan
        $afterPause = $ProcessedSet.ContainsKey("cycD1:r1")
        Assert-That "D1 PAUSE中スキップ→解除後に回収" ((-not $duringPause) -and $afterPause)
    }

    Run-Case "D2" {
        Reset-Env; $script:ProcessedSet = @{}
        New-TestManifest (Join-Path $MaestroDir "d2.ready.json") @{ schema_version = 1; producer = "air" }
        Initialize-ProcessedSet
        Invoke-PendingScan
        $qAfter1 = Get-QuarantineCount
        if (Test-Path $PauseFile) { Remove-Item $PauseFile -Force }
        Invoke-PendingScan
        Invoke-PendingScan
        $qAfter3 = Get-QuarantineCount
        Assert-That "D2 quarantine後に再処理されない(件数不変)" (($qAfter1 -eq 1) -and ($qAfter3 -eq 1)) "after1=$qAfter1 after3=$qAfter3"
    }

    # ─── E: 安全装置失敗時の致命停止 ────────────────────────────────────
    Write-Host "[E] 安全装置失敗時の致命停止" -ForegroundColor White

    Run-Case "E1" {
        Reset-Env; $script:ProcessedSet = @{}
        New-Item -ItemType Directory -Path $ProcessedLog -Force | Out-Null
        New-Item -ItemType Directory -Path $PauseFile    -Force | Out-Null
        $threw = $false
        try { Initialize-ProcessedSet } catch { $threw = $true }
        Assert-That "E1 読込失敗+PAUSE失敗→throw(後続に進まない)" $threw "threw=$threw"
    }

    Run-Case "E2" {
        Reset-Env; $script:ProcessedSet = @{}
        $h = New-TestP1 "docs\handoff\P1_Air_Blueprint\e2.md"
        $mf = Join-Path $MaestroDir "e2.ready.json"
        New-TestManifest $mf (New-ValidFields "cycE2" 1 $h "docs/handoff/P1_Air_Blueprint/e2.md")
        New-Item -ItemType Directory -Path $ProcessedLog -Force | Out-Null
        New-Item -ItemType Directory -Path $PauseFile    -Force | Out-Null
        $threw = $false
        try { $null = Process-Manifest -ManifestPath $mf } catch { $threw = $true }
        Assert-That "E2 書込失敗+PAUSE失敗→throw & メモリ未登録" ($threw -and -not $script:ProcessedSet.ContainsKey("cycE2:r1")) "threw=$threw"
    }

    Run-Case "E3" {
        Reset-Env; $script:ProcessedSet = @{}
        New-Item -ItemType File -Path $QuarantineDir -Force | Out-Null
        $mf = Join-Path $MaestroDir "e3.ready.json"
        New-TestManifest $mf @{ schema_version = 1; producer = "air" }
        $threw = $false
        try { $null = Process-Manifest -ManifestPath $mf } catch { $threw = $true }
        Assert-That "E3 quarantine移動失敗→原本残り+PAUSE+throw" ($threw -and (Test-Path $mf) -and (Test-Path $PauseFile)) "threw=$threw"
    }

    Run-Case "E4" {
        Reset-Env; $script:ProcessedSet = @{}
        Set-Content -Path $ProcessedLog -Value "cycE4:r1|validated at=2026/6/19" -Encoding UTF8
        Initialize-ProcessedSet
        Assert-That "E4 processed.log不正日時→PAUSE(throwなし)・該当行未登録" ((Test-Path $PauseFile) -and -not $script:ProcessedSet.ContainsKey("cycE4:r1"))
    }

} finally {
    if (Test-Path $tmpRoot) { Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ─── F: 文字コード検証（Runnerファイル内の日本語文字列を直接確認）────────
Write-Host "[F] 文字コード検証" -ForegroundColor White

$runnerPath = Join-Path $PSScriptRoot "maestro_runner.ps1"
[string[]]$runnerLines = [System.IO.File]::ReadAllLines($runnerPath, [System.Text.UTF8Encoding]::new($false))
$runnerText = $runnerLines -join "`n"

Assert-That "F1 Phase1プロンプト『OKとだけ答えて』が正しく存在する" `
    ($runnerText -match [regex]::Escape("OKとだけ答えて"))

Assert-That "F2 Phase2 StepAプロンプト『次の文字列を記憶』が正しく存在する" `
    ($runnerText -match [regex]::Escape("次の文字列を記憶"))

Assert-That "F3 Phase2 StepBプロンプト『先ほど記憶した』が正しく存在する" `
    ($runnerText -match [regex]::Escape("先ほど記憶した"))

Assert-That "F4 Runner内に置換文字(U+FFFD)が存在しない" `
    (-not $runnerText.Contains([char]0xFFFD))

# ─── G: Invoke-ClaudeRaw 実行テスト（Take 15）────────────────────────────
Write-Host "[G] Invoke-ClaudeRaw 実行テスト（Take 15）" -ForegroundColor White

# G用スタブ: 外部通信なしで実際にプロセスを起動し動作を検証
$gTmp            = Join-Path ([System.IO.Path]::GetTempPath()) ("g_stub_" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $gTmp -Force | Out-Null
$stubRecordFile  = Join-Path $gTmp "stub_args.txt"
$stubCmdPath     = Join-Path $gTmp "stub.cmd"
$stubSleepPath   = Join-Path $gTmp "stub_sleep.cmd"
$stubSleepPs1    = Join-Path $gTmp "stub_sleep.ps1"
$stubStderrPath  = Join-Path $gTmp "stub_stderr.cmd"

# 通常スタブ: args を STUB_RECORD_FILE に記録し JSON を返す
[System.IO.File]::WriteAllLines($stubCmdPath, [string[]]@(
    '@echo off',
    'if defined STUB_RECORD_FILE (echo %* > "%STUB_RECORD_FILE%")',
    'echo {^"result^":^"OK^",^"session_id^":^"stub00000000^"}'
), [System.Text.Encoding]::ASCII)

# sleepスタブ用 PS1: 自PID を STUB_RECORD_FILE へ書き込み 30 秒待機
[System.IO.File]::WriteAllLines($stubSleepPs1, [string[]]@(
    'if ($env:STUB_RECORD_FILE) { Set-Content $env:STUB_RECORD_FILE -Value $PID -Encoding ASCII }',
    'Start-Sleep -Seconds 30'
), [System.Text.UTF8Encoding]::new($false))

# sleepスタブ: PS1 を呼び出す（子 PowerShell PID が記録され taskkill /T で消滅するかを検証）
[System.IO.File]::WriteAllLines($stubSleepPath, [string[]]@(
    '@echo off',
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0stub_sleep.ps1"'
), [System.Text.Encoding]::ASCII)

# stderrスタブ: stdout に JSON、stderr に固定文字列を出す（Fix3 検証用）
[System.IO.File]::WriteAllLines($stubStderrPath, [string[]]@(
    '@echo off',
    'echo {^"result^":^"OK^",^"session_id^":^"stub00000000^"}',
    'echo STUB_STDERR_CONTENT 1>&2'
), [System.Text.Encoding]::ASCII)

try {
    # G1: 戻り値が PSCustomObject 1個（配列ではない）
    Run-Case "G1" {
        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubCmdPath
        try {
            $r = Invoke-ClaudeRaw @('--help')
            $isSingle = $r -is [PSCustomObject]
            $notArray = -not ($r -is [System.Array])
            Assert-That "G1 Invoke-ClaudeRaw が PSCustomObject を 1 個だけ返す" ($isSingle -and $notArray) "type=$($r.GetType().Name)"
        } finally { $Script:ClaudeExeOverride = $prev }
    }

    # G2: ExitCode を正常取得できる（整数型）
    Run-Case "G2" {
        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubCmdPath
        try {
            $r = Invoke-ClaudeRaw @('--help')
            $hasExitCode = ($r.ExitCode -is [int] -or $r.ExitCode -is [long])
            Assert-That "G2 ExitCode を正常取得できる" $hasExitCode "ExitCode=$($r.ExitCode) type=$($r.ExitCode.GetType().Name)"
        } finally { $Script:ClaudeExeOverride = $prev }
    }

    # G3: --tools と空文字が OS 層の実引数に並んでいる（default なし）
    Run-Case "G3" {
        $prev = $Script:ClaudeExeOverride
        $env:STUB_RECORD_FILE = $stubRecordFile
        if (Test-Path $stubRecordFile) { Remove-Item $stubRecordFile -Force }
        $Script:ClaudeExeOverride = $stubCmdPath
        try {
            $null = Invoke-ClaudeRaw @('--output-format', 'json', '--tools', '', '--no-session-persistence')
            $recorded = if (Test-Path $stubRecordFile) { (Get-Content $stubRecordFile -Raw).Trim() } else { '' }
            $hasToolsEmpty = $recorded -match '--tools\s+""'
            $noDefault     = $recorded -notmatch '\bdefault\b'
            Assert-That "G3 --tools 空文字あり・default なし" ($hasToolsEmpty -and $noDefault) "recorded=[$recorded]"
        } finally { $Script:ClaudeExeOverride = $prev; $env:STUB_RECORD_FILE = $null }
    }

    # G4: Phase1 呼び出しに --no-session-persistence がある
    Run-Case "G4" {
        $prev = $Script:ClaudeExeOverride
        $env:STUB_RECORD_FILE = $stubRecordFile
        if (Test-Path $stubRecordFile) { Remove-Item $stubRecordFile -Force }
        $Script:ClaudeExeOverride = $stubCmdPath
        try {
            $null = Invoke-ClaudeRaw @('--output-format', 'json', '--tools', '', '--no-session-persistence')
            $recorded = if (Test-Path $stubRecordFile) { (Get-Content $stubRecordFile -Raw).Trim() } else { '' }
            Assert-That "G4 --no-session-persistence が実引数にある" ($recorded -match '--no-session-persistence') "recorded=[$recorded]"
        } finally { $Script:ClaudeExeOverride = $prev; $env:STUB_RECORD_FILE = $null }
    }

    # G5: Step A 呼び出しに --resume なし
    Run-Case "G5" {
        $prev = $Script:ClaudeExeOverride
        $env:STUB_RECORD_FILE = $stubRecordFile
        if (Test-Path $stubRecordFile) { Remove-Item $stubRecordFile -Force }
        $Script:ClaudeExeOverride = $stubCmdPath
        try {
            $null = Invoke-ClaudeRaw @('--output-format', 'json', '--tools', '')
            $recorded = if (Test-Path $stubRecordFile) { (Get-Content $stubRecordFile -Raw).Trim() } else { '' }
            Assert-That "G5 Step A 実引数に --resume なし" ($recorded -notmatch '--resume') "recorded=[$recorded]"
        } finally { $Script:ClaudeExeOverride = $prev; $env:STUB_RECORD_FILE = $null }
    }

    # G6: Step B 呼び出しに --resume <sessionId> あり
    Run-Case "G6" {
        $prev = $Script:ClaudeExeOverride
        $env:STUB_RECORD_FILE = $stubRecordFile
        if (Test-Path $stubRecordFile) { Remove-Item $stubRecordFile -Force }
        $Script:ClaudeExeOverride = $stubCmdPath
        try {
            $testSid = "test-session-id-12345"
            $null = Invoke-ClaudeRaw @('--output-format', 'json', '--tools', '', '--resume', $testSid)
            $recorded = if (Test-Path $stubRecordFile) { (Get-Content $stubRecordFile -Raw).Trim() } else { '' }
            Assert-That "G6 Step B 実引数に --resume sessionId あり" ($recorded -match ('--resume\s+' + [regex]::Escape($testSid))) "recorded=[$recorded]"
        } finally { $Script:ClaudeExeOverride = $prev; $env:STUB_RECORD_FILE = $null }
    }

    # G7: タイムアウト後に root + child PID 両方消滅し 8 秒以内に返る（プロセスツリー停止の実測）
    Run-Case "G7" {
        $rootPidFile = Join-Path $gTmp "root_pid.txt"
        $env:STUB_RECORD_FILE   = $stubRecordFile
        $env:STUB_ROOT_PID_FILE = $rootPidFile
        if (Test-Path $stubRecordFile) { Remove-Item $stubRecordFile -Force }
        if (Test-Path $rootPidFile)    { Remove-Item $rootPidFile    -Force }
        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubSleepPath

        # テスト前のプロセス ID セット（残留チェック基準）
        $psIdsBefore = @(Get-Process -Name 'powershell','pwsh' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Id)

        # finally でアクセスできるよう try スコープ外で初期化
        $rootPid  = 0
        $childPid = 0

        try {
            $threw    = $false
            $errorMsg = ''
            $sw       = [System.Diagnostics.Stopwatch]::StartNew()
            try { $null = Invoke-ClaudeRaw @('--help') -TimeoutSec 4 }
            catch { $threw = $true; $errorMsg = $_.Exception.Message }
            $sw.Stop()
            $elapsed = $sw.Elapsed.TotalSeconds

            # PID ファイルを読み込む（スタブが起動できた証拠も兼ねる）
            $rootPidStr  = if (Test-Path $rootPidFile)    { (Get-Content $rootPidFile    -Raw).Trim() } else { '' }
            $childPidStr = if (Test-Path $stubRecordFile) { (Get-Content $stubRecordFile -Raw).Trim() } else { '' }
            $rootPid  = if ($rootPidStr  -match '^\d+$') { [int]$rootPidStr  } else { 0 }
            $childPid = if ($childPidStr -match '^\d+$') { [int]$childPidStr } else { 0 }

            # root は Invoke-ClaudeRaw 内で消滅確認済みのはず
            $rootGone = ($rootPid -gt 0) -and ($null -eq (Get-Process -Id $rootPid -ErrorAction SilentlyContinue))

            # child の消滅を最大 2 秒待ち、かかった時間を記録
            $cSw = [System.Diagnostics.Stopwatch]::StartNew()
            $childGone = $false
            if ($childPid -gt 0) {
                while (-not $childGone -and $cSw.Elapsed.TotalSeconds -lt 2) {
                    $childGone = ($null -eq (Get-Process -Id $childPid -ErrorAction SilentlyContinue))
                    if (-not $childGone) { Start-Sleep -Milliseconds 100 }
                }
            }
            $cSw.Stop()
            $childKillMs = [math]::Round($cSw.Elapsed.TotalMilliseconds)

            # 残留プロセス確認（テスト前にいなかった powershell/pwsh を検出）
            $psIdsAfter  = @(Get-Process -Name 'powershell','pwsh' -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Id)
            $residualCnt = @($psIdsAfter | Where-Object { $_ -notin $psIdsBefore -and $_ -ne $PID }).Count

            # rootGone・childGone は記録済みPIDの消滅を必須条件としてアサート
            Assert-That "G7 throw・8秒内・rootPID消滅・childPID消滅(${childKillMs}ms)" `
                ($threw -and $elapsed -lt 8 -and $rootGone -and $childGone) `
                "threw=$threw elapsed=$([math]::Round($elapsed,1))s rootPid=$rootPid rootGone=$rootGone childPid=$childPid childGone=$childGone childKillMs=${childKillMs}ms residualPsCount=$residualCnt errMsg=$errorMsg"
        } finally {
            $Script:ClaudeExeOverride = $prev
            $env:STUB_RECORD_FILE   = $null
            $env:STUB_ROOT_PID_FILE = $null
            # テスト生成PIDのみをクリーンアップ（広範囲の powershell 全停止は禁止）
            @($rootPid, $childPid) | Where-Object { $_ -gt 0 } | ForEach-Object {
                $p = Get-Process -Id $_ -ErrorAction SilentlyContinue
                if ($p) { try { $p.Kill() } catch {} }
            }
        }
    }

    # G8: stdout→Output・stderr→Error に正しく分離される
    Run-Case "G8" {
        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubStderrPath
        try {
            $r = Invoke-ClaudeRaw @('--help')
            $hasOutput = $r.Output -match '\{'
            $hasError  = $r.Error  -match 'STUB_STDERR_CONTENT'
            Assert-That "G8 stdout→Output・stderr→Error に正しく分離される" ($hasOutput -and $hasError) `
                "Output=[$($r.Output.Trim())] Error=[$($r.Error.Trim())]"
        } finally { $Script:ClaudeExeOverride = $prev }
    }

} finally {
    $Script:ClaudeExeOverride = $null
    if (Test-Path $gTmp)    { Remove-Item $gTmp    -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $tmpRoot) { Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ── 結果サマリー ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ("結果: PASS={0}  FAIL={1}" -f $passCount, $failCount) -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "=========================================" -ForegroundColor Cyan
if ($failCount -gt 0) { exit 1 } else { exit 0 }
