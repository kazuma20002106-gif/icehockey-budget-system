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

# ─── H: Invoke-ClaudeAgent スタブテスト（外部通信なし・Take4実装）──────────
Write-Host "[H] Invoke-ClaudeAgent テスト（スタブ・外部通信なし）" -ForegroundColor White

# H 専用テスト領域（A-E で削除された tmpRoot とは別に作成）
$hTestRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("h_test_" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $hTestRoot -Force | Out-Null

# H テスト用スクリプト変数を差し替え
$script:ProjectRoot   = $hTestRoot
$script:MaestroDir    = Join-Path $hTestRoot "docs\handoff\maestro"
$script:AllowedP1Root = Join-Path $hTestRoot "docs\handoff\P1_Air_Blueprint"
$script:PauseFile     = Join-Path $hTestRoot "docs\handoff\maestro\PAUSE"
$script:LogFile       = Join-Path $hTestRoot "docs\handoff\maestro\maestro.log"
$script:ProcessedLog  = Join-Path $hTestRoot "docs\handoff\maestro\processed.log"
New-Item -ItemType Directory -Path $script:MaestroDir    -Force | Out-Null
New-Item -ItemType Directory -Path $script:AllowedP1Root -Force | Out-Null

# git status が機能するよう hTestRoot にリポジトリを初期化
Push-Location $script:ProjectRoot
git init --quiet 2>&1 | Out-Null
git -C $script:ProjectRoot config user.email "test@test.com" 2>&1 | Out-Null
git -C $script:ProjectRoot config user.name  "Test" 2>&1 | Out-Null
Pop-Location

# H スタブ用テンポラリ
$hTmp    = Join-Path ([System.IO.Path]::GetTempPath()) ("h_stub_" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $hTmp -Force | Out-Null
$stubHPs1 = Join-Path $hTmp "stub_h.ps1"
$stubHCmd = Join-Path $hTmp "stub_h.cmd"

# スタブ PS1: 環境変数で動作制御（P3・done.json作成、不正ファイル作成、WorkingDir記録）
[System.IO.File]::WriteAllLines($stubHPs1, [string[]]@(
    'param()',
    '$p3Path    = $env:STUB_H_P3_PATH',
    '$donePath  = $env:STUB_H_DONE_PATH',
    '$p1Path    = $env:STUB_H_P1_PATH',
    '$cycleVal  = $env:STUB_H_CYCLE',
    '$revVal    = if ($env:STUB_H_REVISION) { [int]$env:STUB_H_REVISION } else { 1 }',
    '$p3RelVal  = $env:STUB_H_P3_REL',
    '$invPath   = $env:STUB_H_INVALID_PATH',
    '$tmpFile   = $env:STUB_H_TMP_FILE_PATH',
    '$wdFile    = $env:STUB_H_RECORD_WORKDIR',
    '$modifyPath = $env:STUB_H_MODIFY_PATH',
    'if ($wdFile) { (Get-Location).Path | Set-Content $wdFile -Encoding ASCII }',
    'if ($modifyPath -and (Test-Path $modifyPath)) { "MODIFIED_BY_STUB" | Set-Content $modifyPath -Encoding UTF8 }',
    'if ($p3Path) {',
    '    $d = [System.IO.Path]::GetDirectoryName($p3Path)',
    '    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }',
    '    "# Stub P3 Report`nGenerated by H-section stub." | Set-Content $p3Path -Encoding UTF8',
    '}',
    'if ($donePath -and $p3Path) {',
    '    $p1Sha = if ($p1Path -and (Test-Path $p1Path)) { (Get-FileHash $p1Path -Algorithm SHA256).Hash.ToLower() } else { "aabbccdd" }',
    '    $p3Sha = (Get-FileHash $p3Path -Algorithm SHA256).Hash.ToLower()',
    '    $d = [System.IO.Path]::GetDirectoryName($donePath)',
    '    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }',
    '    $ts = [datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")',
    '    $j = "{`"cycle`":`"$cycleVal`",`"revision`":$revVal,`"source_p1_sha256`":`"$p1Sha`",`"p3_file`":`"$p3RelVal`",`"p3_sha256`":`"$p3Sha`",`"completed_at`":`"$ts`",`"result`":`"success`"}"',
    '    $j | Set-Content $donePath -Encoding UTF8',
    '}',
    'if ($invPath) {',
    '    $d = [System.IO.Path]::GetDirectoryName($invPath)',
    '    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }',
    '    "INVALID_STUB_FILE" | Set-Content $invPath -Encoding UTF8',
    '}',
    'if ($tmpFile) {',
    '    $d = [System.IO.Path]::GetDirectoryName($tmpFile)',
    '    if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }',
    '    "tmp_stub_file" | Set-Content $tmpFile -Encoding UTF8',
    '}',
    'Write-Output "{`"result`":`"OK`",`"session_id`":`"abcd1234abcd1234`"}"',
    'exit 0'
), [System.Text.UTF8Encoding]::new($false))

[System.IO.File]::WriteAllLines($stubHCmd, [string[]]@(
    '@echo off',
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0stub_h.ps1" %*'
), [System.Text.Encoding]::ASCII)

# 環境変数クリアヘルパー
function Clear-HStubEnv {
    foreach ($n in @('STUB_H_P3_PATH','STUB_H_DONE_PATH','STUB_H_P1_PATH','STUB_H_CYCLE',
                     'STUB_H_REVISION','STUB_H_P3_REL','STUB_H_INVALID_PATH',
                     'STUB_H_TMP_FILE_PATH','STUB_H_RECORD_WORKDIR','STUB_H_MODIFY_PATH')) {
        Set-Item "env:$n" -Value ''
    }
}

# PAUSE ファイルクリアヘルパー
function Clear-HTestPause {
    if (Test-Path $script:PauseFile) { Remove-Item $script:PauseFile -Force -ErrorAction SilentlyContinue }
}

try {
    # ── H1: 正常系 ─────────────────────────────────────────────────────────
    Run-Case "H1" {
        Clear-HTestPause
        $hCycle = "h_test_01"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_01.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H1 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_01.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH   = $hP3Path
        $env:STUB_H_DONE_PATH = $hDonePath
        $env:STUB_H_P1_PATH   = $hP1Path
        $env:STUB_H_CYCLE     = $hCycle
        $env:STUB_H_REVISION  = "$hRev"
        $env:STUB_H_P3_REL    = $hP3Rel

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        Assert-That "H1 正常系: PAUSE停止なし・正常完了" (-not (Test-Path $script:PauseFile)) "PauseFile が存在している"
    }

    # ── H2: 不正差分系 → PAUSE停止 ───────────────────────────────────────
    Run-Case "H2" {
        Clear-HTestPause
        $hCycle = "h_test_02"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_02.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        $hInvPath  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "src\invalid_h2.txt"))
        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H2 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_02.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH      = $hP3Path
        $env:STUB_H_DONE_PATH    = $hDonePath
        $env:STUB_H_P1_PATH      = $hP1Path
        $env:STUB_H_CYCLE        = $hCycle
        $env:STUB_H_REVISION     = "$hRev"
        $env:STUB_H_P3_REL       = $hP3Rel
        $env:STUB_H_INVALID_PATH = $hInvPath

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        Assert-That "H2 不正差分: Require-Pause が呼ばれPAUSEファイルが作成される" (Test-Path $script:PauseFile) "PauseFile が存在しない"
    }

    # ── H3: 不正差分後に git reset/restore/clean が実行されないこと ────────
    Run-Case "H3" {
        $runnerSrc = Get-Content (Join-Path $PSScriptRoot "maestro_runner.ps1") -Raw
        $noReset   = $runnerSrc -notmatch 'git\s+reset\s+--hard'
        $noRestore = $runnerSrc -notmatch 'git\s+restore\s+\.'
        $noClean   = $runnerSrc -notmatch 'git\s+clean\s+-[a-zA-Z]*f'
        Assert-That "H3 Invoke-ClaudeAgent に git reset/restore/clean が含まれない" ($noReset -and $noRestore -and $noClean) `
            "reset=$(-not $noReset) restore=$(-not $noRestore) clean=$(-not $noClean)"
    }

    # ── H4: 許可パス判定（P3・done.json・tmp配下がすべて許可） ───────────
    Run-Case "H4" {
        Clear-HTestPause
        $hCycle = "h_test_04"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_04.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        $hTmpFile  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\tmp\extra_allowed.txt"))
        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H4 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_04.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH       = $hP3Path
        $env:STUB_H_DONE_PATH     = $hDonePath
        $env:STUB_H_P1_PATH       = $hP1Path
        $env:STUB_H_CYCLE         = $hCycle
        $env:STUB_H_REVISION      = "$hRev"
        $env:STUB_H_P3_REL        = $hP3Rel
        $env:STUB_H_TMP_FILE_PATH = $hTmpFile

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        Assert-That "H4 許可パス判定: P3・done.json・tmp配下はすべて許可されPAUSEなし" (-not (Test-Path $script:PauseFile)) "PauseFile が存在している"
    }

    # ── H5: サンドボックス WorkingDirectory 確認 ─────────────────────────
    Run-Case "H5" {
        Clear-HTestPause
        $hCycle = "h_test_05"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_05.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        $wdFile    = Join-Path $hTmp "h5_workdir.txt"
        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H5 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_05.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH        = $hP3Path
        $env:STUB_H_DONE_PATH      = $hDonePath
        $env:STUB_H_P1_PATH        = $hP1Path
        $env:STUB_H_CYCLE          = $hCycle
        $env:STUB_H_REVISION       = "$hRev"
        $env:STUB_H_P3_REL         = $hP3Rel
        $env:STUB_H_RECORD_WORKDIR = $wdFile

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        $recordedWd      = if (Test-Path $wdFile) { (Get-Content $wdFile -Raw).Trim() } else { '' }
        $expectedSandbox = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "sandbox"))
        Assert-That "H5 スタブの WorkingDirectory がサンドボックスディレクトリ" ($recordedWd -eq $expectedSandbox) `
            "recorded='$recordedWd' expected='$expectedSandbox'"
    }

    # ── H6: プロンプトに P1・P3・done.json の絶対パスが含まれること ────────
    Run-Case "H6" {
        Clear-HTestPause
        $hCycle = "h_test_06"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_06.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H6 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_06.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH   = $hP3Path
        $env:STUB_H_DONE_PATH = $hDonePath
        $env:STUB_H_P1_PATH   = $hP1Path
        $env:STUB_H_CYCLE     = $hCycle
        $env:STUB_H_REVISION  = "$hRev"
        $env:STUB_H_P3_REL    = $hP3Rel

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        # プロンプトファイルを直接読み込んで絶対パス埋め込みを確認
        $promptFilePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\tmp\temp_prompt.txt"))
        $promptContent  = if (Test-Path $promptFilePath) { Get-Content $promptFilePath -Raw } else { '' }
        $hasP1   = $promptContent -match [regex]::Escape($hP1Path)
        $hasP3   = $promptContent -match [regex]::Escape($hP3Path)
        $hasDone = $promptContent -match [regex]::Escape($hDonePath)
        Assert-That "H6 プロンプトに P1・P3・done.json の絶対パスが含まれる" ($hasP1 -and $hasP3 -and $hasDone) `
            "p1=$hasP1 p3=$hasP3 done=$hasDone"
    }

    # ── H7: Invoke-PendingScan + AllowPhase2=true + dummy cycle → ClaudeAgent呼び出し ──
    Run-Case "H7" {
        Clear-HTestPause
        $Script:ProcessedSet = @{}
        if (Test-Path $script:ProcessedLog) { Remove-Item $script:ProcessedLog -Force }

        $hCycle   = "dummy_h7"
        $hRev     = 1
        $hP3Path  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1File  = "docs/handoff/P1_Air_Blueprint/h_test_07.md"
        $hP1Path  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, ($hP1File -replace '/', '\')))
        $hP3Rel   = "docs/handoff/P3_CC_Report/${hCycle}.md"

        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H7 P1 Test Dummy" | Set-Content $hP1Path -Encoding UTF8
        $hP1Sha256 = (Get-FileHash -Path $hP1Path -Algorithm SHA256).Hash.ToLower()

        $h7ManifestPath = Join-Path $script:MaestroDir "h7_dummy.ready.json"
        [PSCustomObject]@{
            schema_version = [int]1
            producer       = "air"
            cycle          = $hCycle
            revision       = [int]$hRev
            p1_sha256      = $hP1Sha256
            p1_file        = $hP1File
            created_at     = [datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
        } | ConvertTo-Json -Compress | Set-Content $h7ManifestPath -Encoding UTF8

        Clear-HStubEnv
        $env:STUB_H_P3_PATH   = $hP3Path
        $env:STUB_H_DONE_PATH = $hDonePath
        $env:STUB_H_P1_PATH   = $hP1Path
        $env:STUB_H_CYCLE     = $hCycle
        $env:STUB_H_REVISION  = "$hRev"
        $env:STUB_H_P3_REL    = $hP3Rel

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-PendingScan -AllowPhase2 $true
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
            if (Test-Path $h7ManifestPath) { Remove-Item $h7ManifestPath -Force -ErrorAction SilentlyContinue }
        }
        Assert-That "H7 PendingScan+AllowPhase2+dummy cycle → ClaudeAgent呼ばれP3作成" (Test-Path $hP3Path) "P3が作成されていない"
        Assert-That "H7 PendingScan正常系 → PAUSEなし" (-not (Test-Path $script:PauseFile)) "PAUSEファイルが存在している"
    }

    # ── H8: Invoke-PendingScan + AllowPhase2=true + 本番cycle → 警告のみ・ClaudeAgent不呼び出し ──
    Run-Case "H8" {
        Clear-HTestPause
        $Script:ProcessedSet = @{}
        if (Test-Path $script:ProcessedLog) { Remove-Item $script:ProcessedLog -Force }

        $hCycle   = "production_h8"
        $hRev     = 1
        $hP3Path  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hP1File  = "docs/handoff/P1_Air_Blueprint/h_test_08.md"
        $hP1Path  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, ($hP1File -replace '/', '\')))

        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H8 P1 Test Production" | Set-Content $hP1Path -Encoding UTF8
        $hP1Sha256 = (Get-FileHash -Path $hP1Path -Algorithm SHA256).Hash.ToLower()

        $h8ManifestPath = Join-Path $script:MaestroDir "h8_prod.ready.json"
        [PSCustomObject]@{
            schema_version = [int]1
            producer       = "air"
            cycle          = $hCycle
            revision       = [int]$hRev
            p1_sha256      = $hP1Sha256
            p1_file        = $hP1File
            created_at     = [datetime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
        } | ConvertTo-Json -Compress | Set-Content $h8ManifestPath -Encoding UTF8

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-PendingScan -AllowPhase2 $true
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
            if (Test-Path $h8ManifestPath) { Remove-Item $h8ManifestPath -Force -ErrorAction SilentlyContinue }
        }
        Assert-That "H8 本番cycle → ClaudeAgent不呼び出し(P3なし)" (-not (Test-Path $hP3Path)) "P3が作成されている（呼ばれてはいけない）"
        Assert-That "H8 本番cycle警告のみ → PAUSEなし" (-not (Test-Path $script:PauseFile)) "PAUSEファイルが存在している"
    }

    # ── H9: git status 失敗時に Require-Pause される ─────────────────────────
    Run-Case "H9" {
        $h9Root       = Join-Path ([System.IO.Path]::GetTempPath()) ("h9_nogit_" + [guid]::NewGuid().ToString("N").Substring(0,8))
        $h9MaestroDir = Join-Path $h9Root "docs\handoff\maestro"
        $h9PauseFile  = Join-Path $h9MaestroDir "PAUSE"
        New-Item -ItemType Directory -Path $h9MaestroDir -Force | Out-Null
        # NO git init — git status は exit 128 で失敗する

        $prevProjectRoot  = $script:ProjectRoot
        $prevMaestroDir   = $script:MaestroDir
        $prevPauseFile    = $script:PauseFile
        $prevLogFile      = $script:LogFile
        $prevProcessedLog = $script:ProcessedLog
        $script:ProjectRoot  = $h9Root
        $script:MaestroDir   = $h9MaestroDir
        $script:PauseFile    = $h9PauseFile
        $script:LogFile      = Join-Path $h9MaestroDir "maestro.log"
        $script:ProcessedLog = Join-Path $h9MaestroDir "processed.log"

        $h9Manifest = [PSCustomObject]@{ cycle = "dummy_h9"; revision = 1; p1_file = "dummy.md" }
        $h9P1Path   = Join-Path $h9Root "dummy.md"
        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        $h9PauseCreated = $false
        try {
            Invoke-ClaudeAgent -ManifestObj $h9Manifest -P1FullPath $h9P1Path
        } catch {}
        finally {
            $h9PauseCreated      = Test-Path $h9PauseFile
            $Script:ClaudeExeOverride = $prev
            $script:ProjectRoot  = $prevProjectRoot
            $script:MaestroDir   = $prevMaestroDir
            $script:PauseFile    = $prevPauseFile
            $script:LogFile      = $prevLogFile
            $script:ProcessedLog = $prevProcessedLog
            if (Test-Path $h9Root) { Remove-Item $h9Root -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Assert-That "H9 git status 失敗時にRequire-PauseされPAUSEファイル作成" $h9PauseCreated "PAUSEファイルが作成されていない"
    }

    # ── H10: 起動前dirty許可外ファイルをスタブが変更 → PAUSE ────────────────
    Run-Case "H10" {
        Clear-HTestPause
        $hCycle = "h_test_10"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_10.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"

        # 起動前から存在するdirtyな許可外ファイル（スタブが内容を変更する）
        $dirtyDir  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "src"))
        if (-not (Test-Path $dirtyDir)) { New-Item -ItemType Directory $dirtyDir -Force | Out-Null }
        $dirtyFile = Join-Path $dirtyDir "existing_h10.txt"
        "ORIGINAL_CONTENT" | Set-Content $dirtyFile -Encoding UTF8

        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H10 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_10.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH     = $hP3Path
        $env:STUB_H_DONE_PATH   = $hDonePath
        $env:STUB_H_P1_PATH     = $hP1Path
        $env:STUB_H_CYCLE       = $hCycle
        $env:STUB_H_REVISION    = "$hRev"
        $env:STUB_H_P3_REL      = $hP3Rel
        $env:STUB_H_MODIFY_PATH = $dirtyFile   # スタブが既存ファイルを変更する

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        Assert-That "H10 既存dirtyファイルの内容変化を検知しPAUSE" (Test-Path $script:PauseFile) "PAUSEファイルが作成されていない"
    }

    # ── H11: 起動前dirty許可外ファイルをスタブが触らない → PAUSEなし ─────────
    Run-Case "H11" {
        Clear-HTestPause
        $hCycle = "h_test_11"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_11.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"

        # 起動前から存在するdirtyな許可外ファイル（スタブは触らない）
        $dirtyDir  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "src"))
        if (-not (Test-Path $dirtyDir)) { New-Item -ItemType Directory $dirtyDir -Force | Out-Null }
        $dirtyFile = Join-Path $dirtyDir "existing_h11.txt"
        "ORIGINAL_CONTENT" | Set-Content $dirtyFile -Encoding UTF8

        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H11 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_11.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH   = $hP3Path
        $env:STUB_H_DONE_PATH = $hDonePath
        $env:STUB_H_P1_PATH   = $hP1Path
        $env:STUB_H_CYCLE     = $hCycle
        $env:STUB_H_REVISION  = "$hRev"
        $env:STUB_H_P3_REL    = $hP3Rel
        # STUB_H_MODIFY_PATH 未設定 → スタブはdirtyファイルを変更しない

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        Assert-That "H11 既存dirtyファイルを触らなければPAUSEなし" (-not (Test-Path $script:PauseFile)) "PAUSEファイルが存在している"
    }

    # ── H12: maestro配下の許可外ファイル作成 → PAUSE ─────────────────────────
    Run-Case "H12" {
        Clear-HTestPause
        $hCycle = "h_test_12"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_12.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        # 許可外 maestro 配下ファイル（done.json/tmp 以外）
        $evilPath  = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "evil.txt"))

        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H12 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_12.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH      = $hP3Path
        $env:STUB_H_DONE_PATH    = $hDonePath
        $env:STUB_H_P1_PATH      = $hP1Path
        $env:STUB_H_CYCLE        = $hCycle
        $env:STUB_H_REVISION     = "$hRev"
        $env:STUB_H_P3_REL       = $hP3Rel
        $env:STUB_H_INVALID_PATH = $evilPath   # スタブが maestro 配下に許可外ファイルを作成

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        Assert-That "H12 maestro配下許可外ファイル作成でPAUSE" (Test-Path $script:PauseFile) "PAUSEファイルが作成されていない"
    }

    # ── H13: maestro.log の変化だけではPAUSEしない ────────────────────────────
    Run-Case "H13" {
        Clear-HTestPause
        $hCycle = "h_test_13"
        $hRev   = 1
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_13.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"

        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H13 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_13.md" }

        # maestro.log が存在することを確認（H1-H12 で作成済み）、baseline前の内容を記録
        $logBefore = if (Test-Path $script:LogFile) { Get-Content $script:LogFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH   = $hP3Path
        $env:STUB_H_DONE_PATH = $hDonePath
        $env:STUB_H_P1_PATH   = $hP1Path
        $env:STUB_H_CYCLE     = $hCycle
        $env:STUB_H_REVISION  = "$hRev"
        $env:STUB_H_P3_REL    = $hP3Rel
        # STUB_H_INVALID_PATH 未設定 → スタブは P3+done.json のみ作成

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        $logAfter   = if (Test-Path $script:LogFile) { Get-Content $script:LogFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue } else { '' }
        $logChanged = $logBefore -ne $logAfter
        Assert-That "H13 maestro.log変化のみではPAUSEしない" (-not (Test-Path $script:PauseFile)) "PAUSEファイルが存在している"
        Assert-That "H13 (前提確認) maestro.logは実際に変化した" $logChanged "maestro.logが変化していない"
    }

    # ── H14: プロンプトに cc.done.json の厳密契約（revision/result）が含まれること ──
    Run-Case "H14" {
        Clear-HTestPause
        $hCycle = "h_test_14"
        $hRev   = 2   # 実機異常の再現: revision=2
        $hP3Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:ProjectRoot, "docs\handoff\P3_CC_Report\${hCycle}.md"))
        $hDonePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\cc.done.json"))
        $hP1Path   = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:AllowedP1Root, "h_test_14.md"))
        $hP3Rel    = "docs/handoff/P3_CC_Report/${hCycle}.md"
        if (-not (Test-Path ([System.IO.Path]::GetDirectoryName($hP1Path)))) { New-Item -ItemType Directory ([System.IO.Path]::GetDirectoryName($hP1Path)) -Force | Out-Null }
        "# H14 P1 Test" | Set-Content $hP1Path -Encoding UTF8
        $hP1Sha = (Get-FileHash -Path $hP1Path -Algorithm SHA256).Hash.ToLower()
        $hManifest = [PSCustomObject]@{ cycle = $hCycle; revision = $hRev; p1_file = "docs/handoff/P1_Air_Blueprint/h_test_14.md" }

        Clear-HStubEnv
        $env:STUB_H_P3_PATH   = $hP3Path
        $env:STUB_H_DONE_PATH = $hDonePath
        $env:STUB_H_P1_PATH   = $hP1Path
        $env:STUB_H_CYCLE     = $hCycle
        $env:STUB_H_REVISION  = "$hRev"
        $env:STUB_H_P3_REL    = $hP3Rel

        $prev = $Script:ClaudeExeOverride
        $Script:ClaudeExeOverride = $stubHCmd
        try {
            Invoke-ClaudeAgent -ManifestObj $hManifest -P1FullPath $hP1Path
        } finally {
            $Script:ClaudeExeOverride = $prev
            Clear-HStubEnv
        }
        $promptFilePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($script:MaestroDir, "${hCycle}\revision_${hRev}\tmp\temp_prompt.txt"))
        $promptContent  = if (Test-Path $promptFilePath) { Get-Content $promptFilePath -Raw } else { '' }
        # revision の数値明記、revision_2文字列の禁止、result success、独自値禁止、P1ハッシュ埋め込みを確認
        $hasRevNum      = $promptContent -match '"revision":\s*2'
        $hasRevForbid   = $promptContent -match 'revision_2'   # 禁止例として明記されている
        $hasResultOK    = $promptContent -match '"result":\s*"success"'
        $hasResultForbid= $promptContent -match 'sandbox_compliant'  # 禁止例として明記されている
        $hasP1Sha       = $promptContent -match [regex]::Escape($hP1Sha)
        Assert-That "H14 プロンプトに revision数値・result success・禁止例・P1ハッシュが含まれる" `
            ($hasRevNum -and $hasRevForbid -and $hasResultOK -and $hasResultForbid -and $hasP1Sha) `
            "revNum=$hasRevNum revForbid=$hasRevForbid resultOK=$hasResultOK resultForbid=$hasResultForbid p1sha=$hasP1Sha"
        Assert-That "H14 厳密契約強化でも正常完了しPAUSEなし" (-not (Test-Path $script:PauseFile)) "PAUSEファイルが存在している"
    }

} finally {
    $Script:ClaudeExeOverride = $null
    Clear-HStubEnv
    if (Test-Path $hTmp)      { Remove-Item $hTmp      -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $hTestRoot) { Remove-Item $hTestRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ── 結果サマリー ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ("結果: PASS={0}  FAIL={1}" -f $passCount, $failCount) -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "=========================================" -ForegroundColor Cyan
if ($failCount -gt 0) { exit 1 } else { exit 0 }

