#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner 第1段階 統合テストハーネス（外部Claude通信なし）

.DESCRIPTION
    maestro_runner.ps1 を dot-source（$env:MAESTRO_NO_MAIN）で読み込み、
    一時ディレクトリ上で manifest 検証・PAUSE・再起動・二重起動・quarantine を
    外部通信なしで自動検証する。
    Take8: Run-Case分離・E1〜E4・F1〜F4(UTF-8文字コード検証)追加。

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

# ─── G: Invoke-ClaudeRaw・OneDrive対応 Test-ReparseInPath（Take 10）────
Write-Host "[G] Invoke-ClaudeRaw・reparse検証（Take 10）" -ForegroundColor White

# G1-G4: ソースコード検証（$runnerLines/$runnerText を再利用、外部通信なし）
Assert-That "G1 Invoke-ClaudeRaw が ProcessStartInfo を使用している" `
    ($runnerText -match [regex]::Escape("ProcessStartInfo"))

Run-Case "G2" {
    $matched = @($runnerLines | Where-Object {
        $_ -match [regex]::Escape("OKとだけ答えて") -and $_ -match [regex]::Escape("'--tools', ''")
    })
    Assert-That "G2 Test-ClaudeConnection の Invoke-ClaudeRaw に '--tools', '' がある" ($matched.Count -gt 0) "matched=$($matched.Count)"
}

Run-Case "G3" {
    $matched = @($runnerLines | Where-Object {
        $_ -match [regex]::Escape("OKとだけ答えて") -and $_ -match "--no-session-persistence"
    })
    Assert-That "G3 Phase1 Invoke-ClaudeRaw に --no-session-persistence がある" ($matched.Count -gt 0) "matched=$($matched.Count)"
}

Run-Case "G4" {
    $stepAHasResume = @($runnerLines | Where-Object {
        $_ -match [regex]::Escape("記憶したら OK") -and $_ -match "--resume"
    }).Count -gt 0
    $stepBHasResume = @($runnerLines | Where-Object {
        $_ -match [regex]::Escape("先ほど記憶した") -and $_ -match "--resume"
    }).Count -gt 0
    Assert-That "G4 Step A に --resume なし・Step B に --resume あり" (-not $stepAHasResume -and $stepBHasResume) `
        "stepAHasResume=$stepAHasResume stepBHasResume=$stepBHasResume"
}

# G5-G7: 機能テスト（独自 try/finally でクリーンアップ）
try {
    Run-Case "G5" {
        $g5Root = Join-Path ([System.IO.Path]::GetTempPath()) ("g5_" + [guid]::NewGuid().ToString("N").Substring(0,8))
        New-Item -ItemType Directory -Path $g5Root -Force | Out-Null
        try {
            $leaf = Join-Path $g5Root "leaf.txt"
            [System.IO.File]::WriteAllText($leaf, "test", [System.Text.UTF8Encoding]::new($false))
            $result = Test-ReparseInPath -LeafPath $leaf -BoundaryRoot $g5Root
            Assert-That "G5 通常パスに Test-ReparseInPath → false" (-not $result) "result=$result"
        } finally {
            Remove-Item $g5Root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Run-Case "G6" {
        $g6Base   = Join-Path ([System.IO.Path]::GetTempPath()) ("g6_" + [guid]::NewGuid().ToString("N").Substring(0,8))
        $g6Target = Join-Path $g6Base "target"
        $g6Link   = Join-Path $g6Base "junction"
        New-Item -ItemType Directory -Path $g6Target -Force | Out-Null
        try {
            $null = New-Item -ItemType Junction -Path $g6Link -Target $g6Target -ErrorAction Stop
            [System.IO.File]::WriteAllText((Join-Path $g6Target "leaf.txt"), "test", [System.Text.UTF8Encoding]::new($false))
            $leaf   = Join-Path $g6Link "leaf.txt"
            $result = Test-ReparseInPath -LeafPath $leaf -BoundaryRoot $g6Base
            Assert-That "G6 junction 経由パスに Test-ReparseInPath → true" ($result -eq $true) "result=$result"
        } finally {
            if (Test-Path $g6Link) { [System.IO.Directory]::Delete($g6Link, $false) }
            if (Test-Path $g6Base) { Remove-Item $g6Base -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    Run-Case "G7" {
        Reset-Env; $script:ProcessedSet = @{}
        $null = New-TestP1 "docs\handoff\P1_Air_Blueprint\g7.md"
        $f = New-ValidFields "cycG7" 1 ("d"*64) "docs/handoff/P1_Air_Blueprint/g7.md"
        New-TestManifest (Join-Path $MaestroDir "g7.ready.json") $f
        $r = Process-Manifest -ManifestPath (Join-Path $MaestroDir "g7.ready.json")
        Assert-That "G7 SHA-256不一致は reparse と独立して PAUSE される" (($null -eq $r) -and (Test-Path $PauseFile)) "r=$r"
    }

} finally {
    if (Test-Path $tmpRoot) { Remove-Item $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

# ── 結果サマリー ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ("結果: PASS={0}  FAIL={1}" -f $passCount, $failCount) -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "=========================================" -ForegroundColor Cyan
if ($failCount -gt 0) { exit 1 } else { exit 0 }
