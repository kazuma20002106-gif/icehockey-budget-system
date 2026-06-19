#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner - Air・CC・Dex 自動連携スクリプト
    Cycle 9 Take3: Dex P4 全修正必須対応版

.PARAMETER Test
    第0段階 Phase1: 課金確認用疎通テスト (--no-session-persistence)

.PARAMETER TestResume
    第0段階 Phase2: nonce完全一致によるセッション継続確認

.PARAMETER Watch
    第1段階: manifest (.ready.json) 監視ループを開始

.EXAMPLE
    .\scripts\maestro_runner.ps1 -Test
    .\scripts\maestro_runner.ps1 -TestResume
    .\scripts\maestro_runner.ps1 -Watch
#>

param (
    [switch]$Test,
    [switch]$TestResume,
    [switch]$Watch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────
# 定数
# ─────────────────────────────────────────────────────────────────────────
$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$MaestroDir    = Join-Path $ProjectRoot "docs\handoff\maestro"
$AllowedP1Root = Join-Path $ProjectRoot "docs\handoff\P1_Air_Blueprint"
$PauseFile     = Join-Path $MaestroDir "PAUSE"
$LogFile       = Join-Path $MaestroDir "maestro.log"
$ProcessedLog  = Join-Path $MaestroDir "processed.log"
$LockFile      = Join-Path $MaestroDir "maestro.lock"
$NonceFile     = Join-Path $MaestroDir "test_nonce.txt"

$Script:ProcessedSet = @{}   # key="cycle:rN", value="validated"|"launched"|"done"
$Script:Mutex        = $null

# ─────────────────────────────────────────────────────────────────────────
# ログ出力（session_id 等の秘密値は先頭8桁のみ表示）
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

function Get-MaskedId {
    param([string]$Id)
    if ([string]::IsNullOrWhiteSpace($Id)) { return "(空)" }
    return $Id.Substring(0, [Math]::Min(8, $Id.Length)) + "..."
}

# ─────────────────────────────────────────────────────────────────────────
# Get-ClaudeExe: [version]キャストで最新バージョンを動的検出
# ─────────────────────────────────────────────────────────────────────────
function Get-ClaudeExe {
    $claudeBase = "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code"
    if (-not (Test-Path $claudeBase)) {
        throw "Claude Code インストールパスが見つかりません: $claudeBase"
    }
    $latest = Get-ChildItem $claudeBase |
        Where-Object { $_.PSIsContainer -and $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "バージョンディレクトリが見つかりません" }
    $exe = Join-Path $latest.FullName "claude.exe"
    if (-not (Test-Path $exe)) { throw "claude.exe が見つかりません: $exe" }
    Write-Log "claude.exe 検出: $($latest.Name)"
    return $exe
}

# ─────────────────────────────────────────────────────────────────────────
# Initialize-ProcessedSet: 起動時に processed.log を読み込み復元
# ─────────────────────────────────────────────────────────────────────────
function Initialize-ProcessedSet {
    $Script:ProcessedSet = @{}
    if (-not (Test-Path $ProcessedLog)) {
        Write-Log "processed.log なし。新規スタート。"
        return
    }
    $lines = Get-Content $ProcessedLog -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line -match '^([^|]+)\|([a-z]+)') {
            $Script:ProcessedSet[$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    Write-Log "処理済みキー復元: $($Script:ProcessedSet.Count) 件"
}

# ─────────────────────────────────────────────────────────────────────────
# 排他制御: named mutex + lock ファイルで Runner を単一起動に制限
# ─────────────────────────────────────────────────────────────────────────
function Enter-SingleInstance {
    $Script:Mutex = New-Object System.Threading.Mutex($false, "Global\MaestroRunnerBudgetSystem")
    if (-not $Script:Mutex.WaitOne(0)) {
        $Script:Mutex.Dispose(); $Script:Mutex = $null
        throw "別の Maestro Runner が起動中です（二重起動防止）"
    }
    $PID | Set-Content -Path $LockFile -Encoding UTF8
    Write-Log "排他ロック取得: PID=$PID"
}

function Exit-SingleInstance {
    try {
        if ($Script:Mutex) {
            $Script:Mutex.ReleaseMutex()
            $Script:Mutex.Dispose()
            $Script:Mutex = $null
        }
    } catch {}
    if (Test-Path $LockFile) { Remove-Item $LockFile -Force -ErrorAction SilentlyContinue }
    Write-Log "排他ロック解放"
}

# ─────────────────────────────────────────────────────────────────────────
# PAUSE チェック・生成
# ─────────────────────────────────────────────────────────────────────────
function Test-Paused {
    if (Test-Path $PauseFile) {
        Write-Log "PAUSE ファイルを検知。削除すると監視を再開します。" "PAUSE"
        return $true
    }
    return $false
}

function New-PauseFile {
    param([string]$Reason)
    try {
        New-Item -ItemType File -Path $PauseFile -Force | Out-Null
        Write-Log "PAUSE 自動生成: $Reason" "PAUSE"
        Write-Log "Kazumax が確認後、PAUSE ファイルを削除すると再開します。" "PAUSE"
    } catch {
        Write-Log "PAUSE ファイル生成失敗: $_" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────
# 重複処理防止（state管理付き）
# ─────────────────────────────────────────────────────────────────────────
function Test-AlreadyProcessed {
    param([string]$Cycle, [int]$Revision)
    return $Script:ProcessedSet.ContainsKey("${Cycle}:r${Revision}")
}

function Mark-AsProcessed {
    param([string]$Cycle, [int]$Revision, [string]$State = "validated")
    $key = "${Cycle}:r${Revision}"
    $Script:ProcessedSet[$key] = $State
    try {
        Add-Content -Path $ProcessedLog -Value "${key}|${State} at=$(Get-Date -Format 'o')" -Encoding UTF8
    } catch {}
    Write-Log "処理済みマーク: $key ($State)"
}

# ─────────────────────────────────────────────────────────────────────────
# ファイル安定待機（OneDrive同期対策）
# ─────────────────────────────────────────────────────────────────────────
function Wait-FileStable {
    param([string]$FilePath, [int]$StableMs = 500, [int]$MaxWaitMs = 5000)
    $interval = 100; $req = [int]($StableMs / $interval); $stable = 0
    $prevSize = -1L; $prevTime = [datetime]::MinValue; $waited = 0
    while ($waited -lt $MaxWaitMs) {
        Start-Sleep -Milliseconds $interval; $waited += $interval
        if (-not (Test-Path $FilePath)) { return $false }
        $fi = Get-Item $FilePath
        if ($fi.Length -eq $prevSize -and $fi.LastWriteTime -eq $prevTime) {
            $stable++; if ($stable -ge $req) { return $true }
        } else {
            $stable = 0; $prevSize = $fi.Length; $prevTime = $fi.LastWriteTime
        }
    }
    Write-Log "ファイル安定待機タイムアウト: $(Split-Path -Leaf $FilePath)" "WARN"
    return $false
}

# ─────────────────────────────────────────────────────────────────────────
# Process-Manifest: 値・型・パス境界の強化バリデーション
# ─────────────────────────────────────────────────────────────────────────
function Process-Manifest {
    param([string]$ManifestPath)
    $leaf = Split-Path -Leaf $ManifestPath
    Write-Log "manifest 処理開始: $leaf"

    # 1. ファイル存在
    if (-not (Test-Path $ManifestPath)) {
        Write-Log "manifest が存在しません: $ManifestPath" "ERROR"
        return $null
    }

    # 2. JSON パース（失敗→PAUSE）
    $manifest = $null
    try {
        $raw      = Get-Content -Path $ManifestPath -Encoding UTF8 -Raw
        $manifest = $raw | ConvertFrom-Json
    } catch {
        Write-Log "JSON パース失敗: $leaf" "ERROR"
        New-PauseFile "JSON パース失敗: $leaf"
        return $null
    }

    # 3. 必須フィールド存在確認
    foreach ($f in @("schema_version","producer","cycle","revision","p1_file","p1_sha256","created_at")) {
        if (-not ($manifest.PSObject.Properties.Name -contains $f)) {
            Write-Log "必須フィールド不足: '$f' ($leaf)" "ERROR"
            return $null
        }
    }

    # 4-9. 値・型・書式バリデーション（例外はすべてキャッチ）
    $cycle = ""; $revision = 0; $p1Sha256 = ""
    try {
        # schema_version == 1
        if ([int]$manifest.schema_version -ne 1) {
            Write-Log "schema_version 非対応: $($manifest.schema_version)" "ERROR"; return $null
        }
        # producer == "air"
        if ([string]$manifest.producer -ne "air") {
            Write-Log "producer が 'air' ではありません: $($manifest.producer)" "ERROR"; return $null
        }
        # cycle 非空
        $cycle = [string]$manifest.cycle
        if ([string]::IsNullOrWhiteSpace($cycle)) {
            Write-Log "cycle が空です" "ERROR"; return $null
        }
        # revision >= 1 の整数
        $revision = [int]$manifest.revision
        if ($revision -lt 1) {
            Write-Log "revision が 1 未満です: $revision" "ERROR"; return $null
        }
        # p1_sha256: 64桁16進数
        $p1Sha256 = [string]$manifest.p1_sha256
        if ($p1Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
            Write-Log "p1_sha256 が64桁16進数ではありません" "ERROR"; return $null
        }
        $p1Sha256 = $p1Sha256.ToLower()
        # created_at: 有効な日時として解析できること
        $null = [datetime]::Parse([string]$manifest.created_at)
    } catch {
        Write-Log "バリデーション中に例外: $_" "ERROR"
        return $null
    }
    Write-Log "値・型バリデーション OK: cycle=$cycle, revision=$revision"

    # 10. p1_file パス境界チェック（AllowedP1Root 配下のみ許可）
    $p1Relative = [string]$manifest.p1_file
    $p1FullPath = $null
    try {
        $combined   = [System.IO.Path]::Combine($ProjectRoot, $p1Relative)
        $p1FullPath = [System.IO.Path]::GetFullPath($combined)
    } catch {
        Write-Log "p1_file パス解決に失敗: $_" "ERROR"
        New-PauseFile "p1_file パス境界違反の可能性: $p1Relative"
        return $null
    }
    $allowedFull = [System.IO.Path]::GetFullPath($AllowedP1Root) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $p1FullPath.StartsWith($allowedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Log "p1_file がプロジェクト外または許可外ディレクトリ: $p1Relative" "ERROR"
        New-PauseFile "p1_file パス境界違反: $p1Relative"
        return $null
    }
    Write-Log "パス境界 OK: $p1Relative"

    # 11. P1ファイル存在
    if (-not (Test-Path $p1FullPath)) {
        Write-Log "P1ファイルが存在しません: $p1FullPath" "ERROR"
        return $null
    }

    # 12. SHA-256 一致確認（不一致→PAUSE）
    $actualHash = $null
    try {
        $actualHash = (Get-FileHash -Path $p1FullPath -Algorithm SHA256).Hash.ToLower()
    } catch {
        Write-Log "SHA-256 計算に失敗: $_" "ERROR"; return $null
    }
    if ($actualHash -ne $p1Sha256) {
        Write-Log "SHA-256 不一致！改ざん・同期ズレの可能性があります。" "ERROR"
        Write-Log "  manifest: $p1Sha256" "ERROR"
        Write-Log "  実際:     $actualHash" "ERROR"
        New-PauseFile "SHA-256 不一致: $cycle r$revision"
        return $null
    }
    Write-Log "SHA-256 一致 OK"

    # 13. 重複チェック
    if (Test-AlreadyProcessed -Cycle $cycle -Revision $revision) {
        Write-Log "処理済みのためスキップ: ${cycle}:r${revision}" "WARN"
        return $null
    }

    # 合格 → 処理済みマーク（state=validated）
    Mark-AsProcessed -Cycle $cycle -Revision $revision -State "validated"
    Write-Log "=== バリデーション完了: $cycle (r$revision) ===" "OK"
    return $manifest
}

# ─────────────────────────────────────────────────────────────────────────
# Invoke-PendingScan: 未処理の *.ready.json を一括スキャン
# 起動時・PAUSE解除時・定期スキャン（30秒ごと）で使用
# ─────────────────────────────────────────────────────────────────────────
function Invoke-PendingScan {
    Write-Log "保留中の manifest をスキャン..."
    $manifests = Get-ChildItem -Path $MaestroDir -Filter "*.ready.json" -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime
    if (-not $manifests -or $manifests.Count -eq 0) {
        Write-Log "保留中の manifest はありません。"
        return
    }
    Write-Log "スキャン検知: $($manifests.Count) 件"
    foreach ($m in $manifests) {
        if (Test-Paused) { Write-Log "スキャン中断（PAUSE 検知）"; return }
        if (-not (Wait-FileStable -FilePath $m.FullName)) { continue }
        $result = Process-Manifest -ManifestPath $m.FullName
        if ($result) {
            Write-Log ">>> 【第2段階未実装】Kazumax の承認後に CC を手動起動してください。" "WARN"
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────
# 第0段階 Phase1: Test-ClaudeConnection
# --no-session-persistence で課金経路のみを確認するための疎通テスト
# 成功条件: exit code 0 + JSON parse 成功 + session_id 非空 + result 非空
# ─────────────────────────────────────────────────────────────────────────
function Test-ClaudeConnection {
    Write-Log "=== 第0段階 Phase1: 疎通テスト (課金確認用) ===" "HEADER"

    if ($env:ANTHROPIC_API_KEY) {
        Write-Log "ANTHROPIC_API_KEY が設定されています。従量課金になる恐れがあり中断します。" "WARN"
        return $false
    }
    Write-Log "ANTHROPIC_API_KEY: 未設定 (OK)" "OK"

    $claudeExe = $null
    try { $claudeExe = Get-ClaudeExe } catch {
        Write-Log "claude.exe 検出失敗: $_" "ERROR"
        return $false
    }

    Write-Log "プロンプト送信中 (ツール無効・セッション保存なし)..."
    $output = $null; $exitCode = -1
    try {
        $output   = & $claudeExe --print --output-format json --tools "" --no-session-persistence "OKとだけ答えて" 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        Write-Log "claude.exe 呼び出し失敗: $_" "ERROR"
        return $false
    }

    if ($exitCode -ne 0) {
        Write-Log "終了コード: $exitCode (失敗)" "ERROR"
        $firstLine = ($output | Select-Object -First 1)
        if ($firstLine -match "Not logged in") {
            Write-Log "解決策: claude setup-token を実行してログインしてください。" "WARN"
        } else {
            Write-Log "エラー内容: $firstLine" "ERROR"
        }
        return $false
    }

    $json = $null
    try {
        $jsonStr = ($output | Where-Object { $_ -match '^\{' }) -join ""
        $json    = $jsonStr | ConvertFrom-Json
    } catch {
        Write-Log "JSON パース失敗 → テスト失敗" "ERROR"
        return $false
    }

    $sessionId = [string]$json.session_id
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        Write-Log "session_id が空 → テスト失敗" "ERROR"
        return $false
    }
    $result = [string]$json.result
    if ([string]::IsNullOrWhiteSpace($result)) {
        Write-Log "result が空 → テスト失敗" "ERROR"
        return $false
    }

    Write-Log "終了コード: 0 (成功)" "OK"
    Write-Log "session_id: $(Get-MaskedId $sessionId) (先頭8桁のみ表示)" "OK"
    Write-Log "応答内容: $result" "OK"
    Write-Log "─────────────────────────────────────────────" "INFO"
    Write-Log "【重要】Kazumax が Anthropic コンソールで課金なしを確認後、" "WARN"
    Write-Log "         -TestResume を実行してください (Phase2)。" "WARN"
    Write-Log "─────────────────────────────────────────────" "INFO"
    return $true
}

# ─────────────────────────────────────────────────────────────────────────
# 第0段階 Phase2: Test-ClaudeResume
# ランダムなnonce を記憶させ、--resume で完全一致返答させて文脈継続を確認
# 成功条件: nonce がレスポンスに完全一致で含まれること
# ─────────────────────────────────────────────────────────────────────────
function Test-ClaudeResume {
    Write-Log "=== 第0段階 Phase2: セッション再開テスト (nonce 完全一致) ===" "HEADER"

    $claudeExe = $null
    try { $claudeExe = Get-ClaudeExe } catch {
        Write-Log "claude.exe 検出失敗: $_" "ERROR"
        return $false
    }

    # ── Step A: nonce 生成 → セッション保存ありで記憶させる ──────────────
    $nonce = "NONCE-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8).ToUpper()
    Write-Log "nonce 生成 (内容はログに出力しません)"
    $nonce | Set-Content -Path $NonceFile -Encoding UTF8

    Write-Log "Step A: nonce 記憶セッション開始..."
    $outA = $null; $exitA = -1
    try {
        $outA  = & $claudeExe --print --output-format json --tools "" "次の文字列を記憶してください: $nonce  記憶したら OK とだけ答えてください。" 2>&1
        $exitA = $LASTEXITCODE
    } catch {
        Write-Log "Step A 呼び出し失敗: $_" "ERROR"; return $false
    }
    if ($exitA -ne 0) {
        Write-Log "Step A 失敗 (Exit Code: $exitA)" "ERROR"; return $false
    }
    $jsonA = $null
    try {
        $jsonA = (($outA | Where-Object { $_ -match '^\{' }) -join "") | ConvertFrom-Json
    } catch {
        Write-Log "Step A JSON パース失敗 → テスト失敗" "ERROR"; return $false
    }
    $sessionId = [string]$jsonA.session_id
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        Write-Log "Step A session_id が空 → テスト失敗" "ERROR"; return $false
    }
    Write-Log "Step A 完了: session_id $(Get-MaskedId $sessionId)" "OK"

    # ── Step B: --resume でセッション再開し nonce を返させる ──────────────
    Write-Log "Step B: セッション再開 (--resume)..."
    $outB = $null; $exitB = -1
    try {
        $outB  = & $claudeExe --print --output-format json --tools "" --resume $sessionId "先ほど記憶した文字列を、そのまま一言だけ答えてください。" 2>&1
        $exitB = $LASTEXITCODE
    } catch {
        Write-Log "Step B 呼び出し失敗: $_" "ERROR"; return $false
    }
    if ($exitB -ne 0) {
        Write-Log "Step B 失敗 (Exit Code: $exitB)" "ERROR"; return $false
    }
    $jsonB = $null
    try {
        $jsonB = (($outB | Where-Object { $_ -match '^\{' }) -join "") | ConvertFrom-Json
    } catch {
        Write-Log "Step B JSON パース失敗 → テスト失敗" "ERROR"; return $false
    }
    $response = [string]$jsonB.result
    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-Log "Step B result が空 → テスト失敗" "ERROR"; return $false
    }

    # ── Step C: nonce 完全一致確認 ──────────────────────────────────────
    $matched = $response.Trim() -eq $nonce -or $response -match [regex]::Escape($nonce)
    if ($matched) {
        Write-Log "nonce 完全一致: 文脈継続を確認しました！" "OK"
        Write-Log "第0段階 Phase1+Phase2 完了。-Watch で第1段階へ進めます。" "OK"
        try { Remove-Item $NonceFile -Force -ErrorAction SilentlyContinue } catch {}
        return $true
    } else {
        Write-Log "nonce 不一致 → セッション継続を確認できませんでした" "ERROR"
        Write-Log "  期待した nonce と応答が一致しません（詳細はログ外で確認）" "ERROR"
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────
# Start-Watching: メイン監視ループ
# Created | Changed | Renamed + IncludeSubdirectories=true
# 起動時・PAUSE解除時・30秒ごとに Invoke-PendingScan で保留分を回収
# ─────────────────────────────────────────────────────────────────────────
function Start-Watching {
    Write-Log "=== Maestro Runner 監視開始 ===" "HEADER"
    Write-Log "監視対象: $MaestroDir (サブディレクトリ含む)"
    Write-Log "停止: Ctrl+C または $PauseFile を作成"

    if (-not (Test-Path $MaestroDir)) {
        New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
    }

    # 起動時に processed.log から ProcessedSet を復元
    Initialize-ProcessedSet

    # 排他制御（二重起動防止）
    try {
        Enter-SingleInstance
    } catch {
        Write-Log "$_" "ERROR"
        return
    }

    # 起動時に既存の未処理 manifest を回収
    if (-not (Test-Paused)) { Invoke-PendingScan }

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path                  = $MaestroDir
    $watcher.Filter                = "*.ready.json"
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents   = $true

    $recentEvents   = @{}
    $pauseWasActive = (Test-Path $PauseFile)
    $lastScan       = [datetime]::UtcNow

    Write-Log "FileSystemWatcher 起動完了 (Created | Changed | Renamed, サブディレクトリ含む)" "OK"

    try {
        while ($true) {
            $paused = Test-Paused
            if ($paused) {
                $pauseWasActive = $true
                Start-Sleep -Seconds 5
                continue
            }

            # PAUSE 解除直後: 保留中 manifest を即時スキャン
            if ($pauseWasActive) {
                Write-Log "PAUSE 解除を検知。保留中 manifest をスキャンします。" "INFO"
                Invoke-PendingScan
                $pauseWasActive = $false
                $lastScan = [datetime]::UtcNow
            }

            # 定期スキャン（30秒ごと）
            if (([datetime]::UtcNow - $lastScan).TotalSeconds -ge 30) {
                Invoke-PendingScan
                $lastScan = [datetime]::UtcNow
            }

            # FileSystemWatcher: Created | Changed | Renamed を2秒待機
            $changeTypes = [System.IO.WatcherChangeTypes]::Created `
                        -bor [System.IO.WatcherChangeTypes]::Changed `
                        -bor [System.IO.WatcherChangeTypes]::Renamed
            $event = $watcher.WaitForChanged($changeTypes, 2000)
            if ($event.TimedOut) { continue }

            # Renamed の場合は .Name が変更後のファイル名
            $fileName     = $event.Name
            $manifestPath = Join-Path $MaestroDir $fileName

            # 100ms以内の重複イベントをスキップ
            if ($recentEvents.ContainsKey($fileName) -and
                ((Get-Date) - $recentEvents[$fileName]).TotalMilliseconds -lt 100) { continue }
            $recentEvents[$fileName] = Get-Date

            Write-Log "manifest イベント検知: $fileName ($($event.ChangeType))"

            if (-not (Wait-FileStable -FilePath $manifestPath)) { continue }

            $result = Process-Manifest -ManifestPath $manifestPath
            if ($null -eq $result) {
                Write-Log "manifest 処理失敗。次の manifest を待機します。" "WARN"
                continue
            }

            # ─── 第2段階以降でここに CC 起動ロジックを追加 ─────────────
            Write-Log ">>> バリデーション合格: $($result.cycle) (r$($result.revision))" "OK"
            Write-Log ">>> 【第2段階未実装】Kazumax の承認後に CC を手動起動してください。" "WARN"
            Write-Log "────────────────────────────────────────────" "INFO"
        }
    } finally {
        $watcher.Dispose()
        Exit-SingleInstance
        Write-Log "=== Maestro Runner 停止 ===" "INFO"
    }
}

# ─────────────────────────────────────────────────────────────────────────
# .gitignore: maestro ランタイムファイルをリポジトリから除外（初回のみ追記）
# ─────────────────────────────────────────────────────────────────────────
function Add-GitignoreEntries {
    $gitignore = Join-Path $ProjectRoot ".gitignore"
    $marker    = "# Maestro Runner runtime files"
    if (Test-Path $gitignore) {
        $existing = Get-Content $gitignore -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($existing -match [regex]::Escape($marker)) { return }
    }
    $entries = @"

$marker
docs/handoff/maestro/*.log
docs/handoff/maestro/*.txt
docs/handoff/maestro/PAUSE
docs/handoff/maestro/maestro.lock
"@
    Add-Content -Path $gitignore -Value $entries -Encoding UTF8
    Write-Log ".gitignore に maestro ランタイムエントリを追加しました"
}

# ─────────────────────────────────────────────────────────────────────────
# メイン
# ─────────────────────────────────────────────────────────────────────────
if (-not (Test-Path $MaestroDir)) {
    New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
}

Add-GitignoreEntries

if ($Test) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Maestro Runner - 第0段階 Phase1: 疎通テスト" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    $ok = Test-ClaudeConnection
    Write-Host ""
    if ($ok) {
        Write-Host "[OK] 疎通テスト完了！" -ForegroundColor Green
        Write-Host "     次: Anthropic コンソールで課金確認後、-TestResume を実行" -ForegroundColor Yellow
    } else {
        Write-Host "[NG] 疎通テスト失敗。maestro.log を確認してください。" -ForegroundColor Red
        Write-Host "     原因候補: claude setup-token 未実行 / ANTHROPIC_API_KEY 設定済み" -ForegroundColor Yellow
    }
    Write-Host ""

} elseif ($TestResume) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Maestro Runner - 第0段階 Phase2: セッション再開テスト" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    $ok = Test-ClaudeResume
    Write-Host ""
    if ($ok) {
        Write-Host "[OK] nonce 完全一致でセッション継続を確認しました！" -ForegroundColor Green
        Write-Host "     第0段階の全検証完了。-Watch で第1段階へ進めます。" -ForegroundColor Yellow
    } else {
        Write-Host "[NG] セッション再開テスト失敗。maestro.log を確認してください。" -ForegroundColor Red
    }
    Write-Host ""

} elseif ($Watch) {
    Start-Watching

} else {
    Write-Host ""
    Write-Host "Maestro Runner - 使い方" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  -Test         第0段階 Phase1: 疎通テスト (課金確認用)" -ForegroundColor White
    Write-Host "  -TestResume   第0段階 Phase2: nonce によるセッション再開テスト" -ForegroundColor White
    Write-Host "  -Watch        第1段階: manifest 監視ループ" -ForegroundColor White
    Write-Host ""
    Write-Host "実行順序:" -ForegroundColor Cyan
    Write-Host "  1. .\scripts\maestro_runner.ps1 -Test"
    Write-Host "  2. Anthropic コンソールで課金確認 (Kazumax)"
    Write-Host "  3. .\scripts\maestro_runner.ps1 -TestResume"
    Write-Host "  4. .\scripts\maestro_runner.ps1 -Watch"
    Write-Host ""
    Write-Host "緊急停止: $PauseFile を作成するか Ctrl+C" -ForegroundColor Yellow
    Write-Host ""
}
