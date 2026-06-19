#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner - Air・CC・Dex 自動連携スクリプト
    Cycle 9: 第0段階（疎通テスト）＋ 第1段階（manifest監視）の基盤実装

.DESCRIPTION
    Airが作成した完成合図 (*.ready.json) を検知し、バリデーション後に
    CCを自動起動するための中央制御プログラム。
    今回のスコープは「検知・バリデーション」まで。CC起動ロジックは第2段階以降に追加。

.PARAMETER Test
    第0段階の疎通テストのみ実行して終了する。

.PARAMETER Watch
    第1段階のmanifest監視ループを開始する。

.EXAMPLE
    .\scripts\maestro_runner.ps1 -Test
    .\scripts\maestro_runner.ps1 -Watch
#>

param (
    [switch]$Test,
    [switch]$Watch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────
# 定数
# ─────────────────────────────────────────────────────────────────────────
$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$MaestroDir    = Join-Path $ProjectRoot "docs\handoff\maestro"
$PauseFile     = Join-Path $MaestroDir "PAUSE"
$LogFile       = Join-Path $MaestroDir "maestro.log"
$ProcessedLog  = Join-Path $MaestroDir "processed.log"

$Script:ProcessedSet = @{}  # メモリ内重複防止リスト（起動中のみ有効）

# ─────────────────────────────────────────────────────────────────────────
# ログ出力
# ─────────────────────────────────────────────────────────────────────────
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","OK","WARN","ERROR","PAUSE","HEADER")]
        [string]$Level = "INFO"
    )
    $ts   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts][$Level] $Message"

    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}

    switch ($Level) {
        "HEADER" { Write-Host $line -ForegroundColor White }
        "INFO"   { Write-Host $line -ForegroundColor Cyan }
        "OK"     { Write-Host $line -ForegroundColor Green }
        "WARN"   { Write-Host $line -ForegroundColor Yellow }
        "ERROR"  { Write-Host $line -ForegroundColor Red }
        "PAUSE"  { Write-Host $line -ForegroundColor Magenta }
    }
}

# ─────────────────────────────────────────────────────────────────────────
# 第0段階: Get-ClaudeExe
# claude.exe の最新バージョンを動的検知する
# [version] キャストにより "2.1.9" < "2.1.181" を正しく判定
# ─────────────────────────────────────────────────────────────────────────
function Get-ClaudeExe {
    $claudeBase = "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code"

    if (-not (Test-Path $claudeBase)) {
        throw "Claude Code のインストールパスが見つかりません: $claudeBase"
    }

    $latest = Get-ChildItem $claudeBase |
        Where-Object { $_.PSIsContainer -and $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1

    if (-not $latest) {
        throw "バージョンディレクトリが見つかりません: $claudeBase"
    }

    $exe = Join-Path $latest.FullName "claude.exe"
    if (-not (Test-Path $exe)) {
        throw "claude.exe が見つかりません: $exe"
    }

    Write-Log "claude.exe 検出: $($latest.Name) → $exe"
    return $exe
}

# ─────────────────────────────────────────────────────────────────────────
# 第0段階: Test-ClaudeConnection
# ツール無効・セッション保存なし の最小権限で疎通確認
# ─────────────────────────────────────────────────────────────────────────
function Test-ClaudeConnection {
    Write-Log "=== 第0段階: 疎通テスト開始 ===" "HEADER"

    # ANTHROPIC_API_KEY が設定されていたら従量課金の恐れがあるため中断
    if ($env:ANTHROPIC_API_KEY) {
        Write-Log "ANTHROPIC_API_KEY が設定されています。従量課金になる恐れがあるためテストを中断します。" "WARN"
        Write-Log "解決策: 環境変数を削除してから再実行してください。" "WARN"
        return $false
    }
    Write-Log "ANTHROPIC_API_KEY: 未設定を確認 (OK)" "OK"

    try {
        $claudeExe = Get-ClaudeExe
    } catch {
        Write-Log "claude.exe 検出失敗: $_" "ERROR"
        Write-Log "解決策: claude setup-token を実行してログインしてください。" "WARN"
        return $false
    }

    Write-Log "プロンプト送信中... (ツール無効・セッション保存なし)"

    $output = & $claudeExe `
        --print `
        --output-format json `
        --tools "" `
        --no-session-persistence `
        "OKとだけ答えて" 2>&1

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Write-Log "終了コード: $exitCode (失敗)" "ERROR"
        Write-Log "出力: $output" "ERROR"
        if ($output -match "Not logged in") {
            Write-Log "解決策: claude setup-token を実行してCLIにログインしてください。" "WARN"
        }
        return $false
    }

    try {
        $json = ($output | Where-Object { $_ -match '^\{' }) -join "" | ConvertFrom-Json
        Write-Log "終了コード: 0 (成功)" "OK"
        Write-Log "セッションID: $($json.session_id)" "OK"
        Write-Log "応答内容:     $($json.result)" "OK"
        if ($json.cost_usd) {
            Write-Log "cost_usd キー: 存在 (値の記録は省略)" "INFO"
        }
    } catch {
        Write-Log "JSON パース失敗: $_" "WARN"
        Write-Log "生出力 (参考): $output" "INFO"
    }

    Write-Log "─────────────────────────────────────────────" "INFO"
    Write-Log "【重要】APIの従量課金が発生していないか、Kazumax が" "WARN"
    Write-Log "        Anthropic コンソールで手動確認してください。" "WARN"
    Write-Log "─────────────────────────────────────────────" "INFO"
    return $true
}

# ─────────────────────────────────────────────────────────────────────────
# SHA-256 ハッシュ計算
# ─────────────────────────────────────────────────────────────────────────
function Get-FileSha256 {
    param([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
}

# ─────────────────────────────────────────────────────────────────────────
# 重複処理防止（メモリ内 + ログファイル追記）
# ─────────────────────────────────────────────────────────────────────────
function Test-AlreadyProcessed {
    param([string]$Cycle, [int]$Revision)
    return $Script:ProcessedSet.ContainsKey("${Cycle}:r${Revision}")
}

function Mark-AsProcessed {
    param([string]$Cycle, [int]$Revision)
    $key = "${Cycle}:r${Revision}"
    $Script:ProcessedSet[$key] = (Get-Date -Format "o")
    try {
        Add-Content -Path $ProcessedLog -Value "$key  processed_at=$(Get-Date -Format 'o')" -Encoding UTF8
    } catch {}
    Write-Log "処理済みとしてマーク: $key" "INFO"
}

# ─────────────────────────────────────────────────────────────────────────
# ファイル安定待機（OneDrive同期・エディタ複数回保存対策）
# ─────────────────────────────────────────────────────────────────────────
function Wait-FileStable {
    param(
        [string]$FilePath,
        [int]$StableMs  = 500,
        [int]$MaxWaitMs = 5000
    )
    $interval       = 100
    $requiredStable = [int]($StableMs / $interval)
    $stableCount    = 0
    $prevSize       = -1L
    $prevTime       = [datetime]::MinValue
    $waited         = 0

    while ($waited -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds $interval
        $waited += $interval
        if (-not (Test-Path $FilePath)) { return $false }

        $fi = Get-Item $FilePath
        if ($fi.Length -eq $prevSize -and $fi.LastWriteTime -eq $prevTime) {
            $stableCount++
            if ($stableCount -ge $requiredStable) { return $true }
        } else {
            $stableCount = 0
            $prevSize    = $fi.Length
            $prevTime    = $fi.LastWriteTime
        }
    }
    Write-Log "ファイル安定待機タイムアウト: $FilePath" "WARN"
    return $false
}

# ─────────────────────────────────────────────────────────────────────────
# 第1段階: Process-Manifest
# *.ready.json を解析・バリデーションし、合格した manifest を返す
# 失敗時は $null を返す（例外ではなくnullで統一し、呼び出し元が継続できるようにする）
# ─────────────────────────────────────────────────────────────────────────
function Process-Manifest {
    param([string]$ManifestPath)

    Write-Log "manifest 処理開始: $(Split-Path -Leaf $ManifestPath)" "INFO"

    # 1. ファイル存在確認
    if (-not (Test-Path $ManifestPath)) {
        Write-Log "manifest ファイルが存在しません: $ManifestPath" "ERROR"
        return $null
    }

    # 2. JSONパース
    $manifest = $null
    try {
        $raw      = Get-Content -Path $ManifestPath -Encoding UTF8 -Raw
        $manifest = $raw | ConvertFrom-Json
    } catch {
        Write-Log "JSON パース失敗: $_" "ERROR"
        return $null
    }

    # 3. 必須フィールド確認
    $required = @("schema_version", "producer", "cycle", "revision", "p1_file", "p1_sha256", "created_at")
    foreach ($field in $required) {
        if (-not ($manifest.PSObject.Properties.Name -contains $field)) {
            Write-Log "必須フィールドが不足しています: '$field'" "ERROR"
            return $null
        }
    }

    $cycle    = [string]$manifest.cycle
    $revision = [int]$manifest.revision
    $p1File   = [string]$manifest.p1_file
    $p1Sha256 = [string]$manifest.p1_sha256

    Write-Log "manifest: cycle=$cycle, revision=$revision, producer=$($manifest.producer)" "INFO"

    # 4. 重複チェック
    if (Test-AlreadyProcessed -Cycle $cycle -Revision $revision) {
        Write-Log "この cycle + revision はすでに処理済みです。スキップします: ${cycle}:r${revision}" "WARN"
        return $null
    }

    # 5. P1ファイル存在確認
    $p1FullPath = Join-Path $ProjectRoot $p1File
    if (-not (Test-Path $p1FullPath)) {
        Write-Log "P1ファイルが存在しません: $p1FullPath" "ERROR"
        return $null
    }
    Write-Log "P1ファイル確認OK: $p1File" "OK"

    # 6. SHA-256 一致確認
    $actualHash = Get-FileSha256 -FilePath $p1FullPath
    if ($actualHash -ne $p1Sha256.ToLower()) {
        Write-Log "SHA-256 不一致！自動修正は行わず停止します。" "ERROR"
        Write-Log "  manifest 記載: $p1Sha256" "ERROR"
        Write-Log "  実際のハッシュ: $actualHash" "ERROR"
        Write-Log "Kazumax に確認を依頼してください。Maestro Runner を停止します。" "ERROR"
        return $null
    }
    Write-Log "SHA-256 一致確認OK" "OK"

    # バリデーション合格 → 処理済みとしてマーク
    Mark-AsProcessed -Cycle $cycle -Revision $revision
    Write-Log "=== バリデーション完了: $cycle (revision $revision) ===" "OK"

    return $manifest
}

# ─────────────────────────────────────────────────────────────────────────
# PAUSEファイルチェック
# ─────────────────────────────────────────────────────────────────────────
function Test-Paused {
    if (Test-Path $PauseFile) {
        Write-Log "PAUSE ファイルを検知。監視を一時停止中... 削除すると再開します。" "PAUSE"
        return $true
    }
    return $false
}

# ─────────────────────────────────────────────────────────────────────────
# 第1段階: Start-Watching
# FileSystemWatcher で *.ready.json を監視し、Process-Manifest を呼ぶ
# ─────────────────────────────────────────────────────────────────────────
function Start-Watching {
    Write-Log "=== Maestro Runner 監視開始 ===" "HEADER"
    Write-Log "監視対象: $MaestroDir" "INFO"
    Write-Log "停止: Ctrl+C、または $PauseFile を作成" "INFO"
    Write-Log "" "INFO"

    if (-not (Test-Path $MaestroDir)) {
        New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
        Write-Log "maestro ディレクトリを作成しました: $MaestroDir" "INFO"
    }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path                  = $MaestroDir
    $watcher.Filter                = "*.ready.json"
    $watcher.IncludeSubdirectories = $false
    $watcher.EnableRaisingEvents   = $true

    $recentEvents = @{}  # 短時間の重複イベント防止用（ファイル名→最終検知時刻）

    Write-Log "FileSystemWatcher 起動完了。manifest (.ready.json) を待機中..." "OK"

    try {
        while ($true) {
            if (Test-Paused) {
                Start-Sleep -Seconds 5
                continue
            }

            $changeTypes = [System.IO.WatcherChangeTypes]::Created -bor [System.IO.WatcherChangeTypes]::Changed
            $event = $watcher.WaitForChanged($changeTypes, 2000)

            if ($event.TimedOut) { continue }

            $fileName     = $event.Name
            $manifestPath = Join-Path $MaestroDir $fileName

            # 同一ファイルの100ms以内の重複イベントをスキップ
            if ($recentEvents.ContainsKey($fileName)) {
                $elapsed = ((Get-Date) - $recentEvents[$fileName]).TotalMilliseconds
                if ($elapsed -lt 100) { continue }
            }
            $recentEvents[$fileName] = Get-Date

            Write-Log "新しい manifest を検知: $fileName" "INFO"

            # OneDrive同期対策: ファイルが安定するまで待機
            Write-Log "ファイル安定確認中 (最大5秒)..." "INFO"
            if (-not (Wait-FileStable -FilePath $manifestPath)) {
                Write-Log "ファイルが安定しませんでした。スキップします: $fileName" "WARN"
                continue
            }
            Write-Log "ファイル安定確認OK" "OK"

            # manifest バリデーション
            $manifest = Process-Manifest -ManifestPath $manifestPath
            if ($null -eq $manifest) {
                Write-Log "manifest の処理に失敗しました。次の manifest を待機します。" "WARN"
                continue
            }

            # ─── 第2段階以降でここにCC起動ロジックを追加 ───
            Write-Log ">>> バリデーション合格: $($manifest.cycle) (r$($manifest.revision))" "OK"
            Write-Log ">>> P1ファイル: $($manifest.p1_file)" "INFO"
            Write-Log ">>> 【第2段階未実装】Kazumax の承認を得てから CC を手動起動してください。" "WARN"
            Write-Log "────────────────────────────────────────────" "INFO"
        }
    } finally {
        $watcher.Dispose()
        Write-Log "=== FileSystemWatcher を停止しました ===" "INFO"
    }
}

# ─────────────────────────────────────────────────────────────────────────
# メイン
# ─────────────────────────────────────────────────────────────────────────

# maestro ディレクトリがなければ作成
if (-not (Test-Path $MaestroDir)) {
    New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
}

if ($Test) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Maestro Runner - 第0段階: 疎通テスト" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    $ok = Test-ClaudeConnection

    Write-Host ""
    if ($ok) {
        Write-Host "[OK] 疎通テスト完了！" -ForegroundColor Green
        Write-Host "     次のステップ:" -ForegroundColor Yellow
        Write-Host "       1. Anthropic コンソールで課金がないことをKazumaxが確認" -ForegroundColor Yellow
        Write-Host "       2. 問題なければ -Watch で監視ループを開始してください" -ForegroundColor Yellow
    } else {
        Write-Host "[NG] 疎通テスト失敗。maestro.log を確認してください。" -ForegroundColor Red
        Write-Host "     原因候補:" -ForegroundColor Yellow
        Write-Host "       - claude setup-token が未実行（要ログイン）" -ForegroundColor Yellow
        Write-Host "       - ANTHROPIC_API_KEY が設定されている" -ForegroundColor Yellow
    }
    Write-Host ""

} elseif ($Watch) {
    Start-Watching

} else {
    Write-Host ""
    Write-Host "Maestro Runner - 使い方" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  -Test   第0段階: claude.exe の疎通テストを実行" -ForegroundColor White
    Write-Host "  -Watch  第1段階: manifest (.ready.json) の監視ループを開始" -ForegroundColor White
    Write-Host ""
    Write-Host "例:" -ForegroundColor Cyan
    Write-Host "  .\scripts\maestro_runner.ps1 -Test"
    Write-Host "  .\scripts\maestro_runner.ps1 -Watch"
    Write-Host ""
    Write-Host "緊急停止: $PauseFile を作成するか Ctrl+C" -ForegroundColor Yellow
    Write-Host ""
}
