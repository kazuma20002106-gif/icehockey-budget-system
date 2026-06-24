#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner - Air・CC・Dex 自動連携スクリプト
    Cycle 9 Take11: Invoke-ClaudeRaw非同期タイムアウト・G1-G7実行テスト

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
    [switch]$Watch,
    [switch]$TestPhase2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────
# 定数
# ─────────────────────────────────────────────────────────────────────────
$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$MaestroDir    = Join-Path $ProjectRoot "docs\handoff\maestro"
$AllowedP1Root = Join-Path $ProjectRoot "docs\handoff\P1_Air_Blueprint"
$QuarantineDir = Join-Path $MaestroDir "quarantine"
$PauseFile     = Join-Path $MaestroDir "PAUSE"
$LogFile       = Join-Path $MaestroDir "maestro.log"
$ProcessedLog  = Join-Path $MaestroDir "processed.log"
$LockFile      = Join-Path $MaestroDir "maestro.lock"

$Script:ProcessedSet    = @{}
$Script:Mutex           = $null
$Script:ClaudeExeOverride = $null   # テスト用スタブ差し替え

$MutexName = "Global\MaestroRunnerBudgetSystem"
$Iso8601Tz  = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})'

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
        New-Item -ItemType File -Path $PauseFile -Force -ErrorAction Stop | Out-Null
        Write-Log "PAUSE 自動生成: $Reason" "PAUSE"
        Write-Log "Kazumax が確認後、PAUSE ファイルを削除すると再開します。" "PAUSE"
        return $true
    } catch {
        Write-Log "PAUSE ファイル生成失敗: $_" "ERROR"
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────
# Initialize-ProcessedSet: 起動時に processed.log を厳密に読み込み復元
# 不正行・欠損・未知state があれば即PAUSE
# ─────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────
# Require-Pause: PAUSE生成失敗を握りつぶさない致命エラー用ラッパー
# ─────────────────────────────────────────────────────────────────────────
function Require-Pause {
    param([string]$Reason)
    if (-not (New-PauseFile $Reason)) {
        $msg = "致命エラー: PAUSE 生成に失敗しました。監視を停止します。 理由: $Reason"
        Write-Host $msg -ForegroundColor Red
        throw $msg
    }
}

function Initialize-ProcessedSet {
    $Script:ProcessedSet = @{}
    if (-not (Test-Path $ProcessedLog)) {
        Write-Log "processed.log なし。新規スタート。"
        return
    }
    $lines = $null
    try {
        $lines = Get-Content $ProcessedLog -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Log "processed.log 読み込み失敗: $_" "ERROR"
        Require-Pause "processed.log 読み込み失敗: 手動確認後 PAUSE を削除してください。"
        return
    }
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        # キー(cycle許可文字+:rN) | state at=<ISO8601>
        if ($line -notmatch "^([A-Za-z0-9_.\-]+:r\d+)\|(validated|launched|done) at=($Iso8601Tz)`$") {
            Write-Log "processed.log 行 ${lineNum}: フォーマット不正 → PAUSE" "ERROR"
            Require-Pause "processed.log 整合性エラー (行 ${lineNum}): 手動確認後 PAUSE を削除してください。"
            return
        }
        # 日時部を ISO 8601 として厳密検証
        $atStr = $Matches[3]
        $dummy = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse($atStr, [ref]$dummy)) {
            Write-Log "processed.log 行 ${lineNum}: 日時が ISO 8601 ではありません → PAUSE" "ERROR"
            Require-Pause "processed.log 日時不正 (行 ${lineNum}): 手動確認後 PAUSE を削除してください。"
            return
        }
        $Script:ProcessedSet[$Matches[1]] = $Matches[2]
    }
    Write-Log "処理済みキー復元: $($Script:ProcessedSet.Count) 件"
}

# ─────────────────────────────────────────────────────────────────────────
# 排他制御: named mutex + lock ファイルで Runner を単一起動に制限
# mutex取得後のlockファイル書き込み失敗時も確実に解放
# ─────────────────────────────────────────────────────────────────────────
function Enter-SingleInstance {
    $Script:Mutex = New-Object System.Threading.Mutex($false, $MutexName)
    $acquired = $false
    try {
        try {
            $acquired = $Script:Mutex.WaitOne(0)
        } catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
            Write-Log "前回の Runner が異常終了していました。ロック回復して続行します。" "WARN"
        }
        if (-not $acquired) {
            throw "別の Maestro Runner が起動中です（二重起動防止）"
        }
        $PID | Set-Content -Path $LockFile -Encoding UTF8 -ErrorAction Stop
        Write-Log "排他ロック取得: PID=$PID"
    } catch {
        if ($acquired) {
            try { $Script:Mutex.ReleaseMutex() } catch {}
        }
        $Script:Mutex.Dispose()
        $Script:Mutex = $null
        throw
    }
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
# 重複処理防止（state管理付き）
# ─────────────────────────────────────────────────────────────────────────
function Test-AlreadyProcessed {
    param([string]$Cycle, [int]$Revision)
    return $Script:ProcessedSet.ContainsKey("${Cycle}:r${Revision}")
}

function Mark-AsProcessed {
    param([string]$Cycle, [int]$Revision, [string]$State = "validated")
    $key  = "${Cycle}:r${Revision}"
    $line = "${key}|${State} at=$(Get-Date -Format 'o')"
    # ディスクへの永続化を先に行い、成功後にメモリを更新
    try {
        Add-Content -Path $ProcessedLog -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Log "processed.log 追記失敗 → PAUSE: $_" "ERROR"
        Require-Pause "processed.log 書き込み失敗: $key を記録できません。ディスクを確認してください。"
        return $false
    }
    $Script:ProcessedSet[$key] = $State
    Write-Log "処理済みマーク: $key ($State)"
    return $true
}

# ─────────────────────────────────────────────────────────────────────────
# パス境界判定: quarantine 配下かどうかを FullPath で判定（文字列一致でなく境界）
# ─────────────────────────────────────────────────────────────────────────
function Test-UnderQuarantine {
    param([string]$Path)
    try {
        $q = [System.IO.Path]::GetFullPath($QuarantineDir).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        $p = [System.IO.Path]::GetFullPath($Path)
        return $p.StartsWith($q, [System.StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────
# Test-ReparseInPath: BoundaryRoot から LeafPath までの各ノード（leaf含む）に
# reparse point / junction / symlink が無いかを確認（許可境界より上は確認不要）
# ─────────────────────────────────────────────────────────────────────────
function Test-ReparseInPath {
    param([string]$LeafPath, [string]$BoundaryRoot)
    $boundary = [System.IO.Path]::GetFullPath($BoundaryRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $current  = [System.IO.Path]::GetFullPath($LeafPath)
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                # OneDrive クラウドファイル/フォルダーは ReparsePoint 属性を持つが
                # LinkType と Target が空文字/null → 許可候補（パストラバーサルリスクなし）
                # Junction / SymbolicLink は LinkType または Target が設定される → 拒否
                $linkType   = [string]$item.LinkType
                $linkTarget = if ($null -ne $item.Target) { [string]($item.Target | Select-Object -First 1) } else { '' }
                if (-not [string]::IsNullOrEmpty($linkType) -or -not [string]::IsNullOrEmpty($linkTarget)) {
                    return $true   # 実リンク（Junction / Symlink）→ 拒否
                }
                # OneDriveプレースホルダー → 継続して上位ノードを確認
            }
        }
        if ($current.TrimEnd([System.IO.Path]::DirectorySeparatorChar) -ieq $boundary) { break }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    return $false
}

# ─────────────────────────────────────────────────────────────────────────
# Deny-Manifest: 不正manifest を隔離（.rejected.json へ改名 = 監視Filter外）
# 移動失敗時は原本を残して PAUSE し、致命異常は throw で監視ループを停止
# ─────────────────────────────────────────────────────────────────────────
function Deny-Manifest {
    param([string]$ManifestPath, [string]$Reason, [switch]$DoPause)
    $leaf = Split-Path -Leaf $ManifestPath
    Write-Log "manifest 不合格 → 隔離: $leaf" "ERROR"
    Write-Log "  理由: $Reason" "ERROR"

    if (-not (Test-Path $QuarantineDir)) {
        try {
            New-Item -ItemType Directory -Path $QuarantineDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Log "  quarantine ディレクトリ作成失敗。原本を残し PAUSE します。" "ERROR"
            if (-not (New-PauseFile "quarantine 作成失敗: $Reason")) {
                throw "PAUSE 生成にも失敗しました。監視を停止します。"
            }
            throw "quarantine 作成失敗のため監視を停止します（原本は保全）。"
        }
    }

    # 監視Filter (*.ready.json) に一致しない拡張子へ改名し、再検知ループを根絶
    # GUID で一意名を保証し、既存隔離ファイルを上書きしない
    $baseName = $leaf -replace '\.ready\.json$', ''
    $unique   = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $ts       = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest     = Join-Path $QuarantineDir "${ts}_${unique}_${baseName}.rejected.json"

    try {
        # -Force を付けず、一意名により衝突しない前提で移動
        Move-Item -Path $ManifestPath -Destination $dest -ErrorAction Stop
        Write-Log "  隔離完了: quarantine\${ts}_${unique}_${baseName}.rejected.json" "WARN"
    } catch {
        # 移動失敗: 原本を削除せず残し、PAUSE して停止（監査証跡を保全）
        Write-Log "  隔離移動失敗。原本を残し PAUSE します: $_" "ERROR"
        if (-not (New-PauseFile "quarantine 移動失敗（原本保全）: $Reason")) {
            throw "PAUSE 生成にも失敗しました。監視を停止します。"
        }
        throw "quarantine 移動失敗のため監視を停止します（原本は保全）。"
    }

    if ($DoPause) {
        if (-not (New-PauseFile $Reason)) {
            throw "PAUSE 生成に失敗しました。監視を停止します。"
        }
    }
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
# Process-Manifest: 厳密バリデーション + 全不正をquarantine/PAUSE
# ─────────────────────────────────────────────────────────────────────────
function Process-Manifest {
    param([string]$ManifestPath)
    $leaf = Split-Path -Leaf $ManifestPath
    Write-Log "manifest 処理開始: $leaf"

    # 1. ファイル存在
    if (-not (Test-Path $ManifestPath)) {
        Write-Log "manifest が存在しません: $leaf" "ERROR"
        return $null
    }

    # 2. JSON パース（失敗→PAUSE: 構造破損の可能性）
    $manifest = $null
    try {
        $raw      = Get-Content -Path $ManifestPath -Encoding UTF8 -Raw -ErrorAction Stop
        $manifest = $raw | ConvertFrom-Json
    } catch {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "JSON パース失敗: $leaf" -DoPause
        return $null
    }

    # 3. 必須フィールド存在確認（→quarantine）
    foreach ($f in @("schema_version","producer","cycle","revision","p1_file","p1_sha256","created_at")) {
        if (-not ($manifest.PSObject.Properties.Name -contains $f)) {
            Deny-Manifest -ManifestPath $ManifestPath -Reason "必須フィールド不足: '$f'"
            return $null
        }
    }

    # 4. schema_version: JSON Int32型かつ値1のみ
    #    （Int64=Int32範囲外, Double, String, Boolean, null は全て→quarantine）
    $sv = $manifest.schema_version
    if ($null -eq $sv) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "schema_version が null です"
        return $null
    }
    if ($sv -isnot [int]) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "schema_version が Int32 整数ではありません: 型=$($sv.GetType().Name), 値=$sv"
        return $null
    }
    if ($sv -ne 1) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "schema_version 非対応: $sv (対応: 1)"
        return $null
    }

    # 5. producer == "air"（→quarantine）
    if ([string]$manifest.producer -ne "air") {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "producer が 'air' ではありません: $($manifest.producer)"
        return $null
    }

    # 6. cycle: 許可文字（英数 . _ -）のみ。改行・`|`・`:` 等で履歴形式へ干渉させない（→quarantine）
    $cycle = [string]$manifest.cycle
    if ($cycle -notmatch '^[A-Za-z0-9_.\-]+$') {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "cycle が許可文字(英数 . _ -)以外を含むか空です: '$cycle'"
        return $null
    }

    # 7. revision: JSON Int32型かつ1以上
    #    （Int64=Int32範囲外 2147483648以上, Double, String, 指数表記は全て→quarantine）
    $rv = $manifest.revision
    if ($null -eq $rv) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "revision が null です"
        return $null
    }
    if ($rv -isnot [int]) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "revision が Int32 整数ではありません（小数・文字列・Int32範囲外を含む）: 型=$($rv.GetType().Name), 値=$rv"
        return $null
    }
    $revision = [int]$rv
    if ($revision -lt 1) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "revision が 1 未満です: $revision"
        return $null
    }

    # 8. p1_sha256: 64桁16進数（→quarantine）
    $p1Sha256 = [string]$manifest.p1_sha256
    if ($p1Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "p1_sha256 が64桁16進数ではありません"
        return $null
    }
    $p1Sha256 = $p1Sha256.ToLower()

    # 9. created_at: タイムゾーン付きISO 8601のみ受理（"June 19, 2026" 等は拒否→quarantine）
    $createdAt = [string]$manifest.created_at
    if ($createdAt -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "created_at がISO 8601+TZ形式ではありません: $createdAt"
        return $null
    }
    $dtResult = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse($createdAt, [ref]$dtResult)) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "created_at が解析できません: $createdAt"
        return $null
    }
    Write-Log "値・型バリデーション OK: cycle=$cycle, revision=$revision"

    # 10. p1_file パス境界チェック（AllowedP1Root 配下のみ→PAUSE: セキュリティ問題）
    $p1Relative = [string]$manifest.p1_file
    $p1FullPath = $null
    try {
        $combined   = [System.IO.Path]::Combine($ProjectRoot, $p1Relative)
        $p1FullPath = [System.IO.Path]::GetFullPath($combined)
    } catch {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "p1_file パス解決失敗: $p1Relative" -DoPause
        return $null
    }
    $allowedFull = [System.IO.Path]::GetFullPath($AllowedP1Root) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $p1FullPath.StartsWith($allowedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "p1_file パス境界違反: $p1Relative" -DoPause
        return $null
    }
    Write-Log "パス境界 OK: $p1Relative"

    # 11. P1ファイル存在 + 通常ファイル確認（ディレクトリ禁止→quarantine）
    if (-not (Test-Path $p1FullPath -PathType Leaf)) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "P1が存在しないかディレクトリです: $p1FullPath"
        return $null
    }
    # P1ファイル自身 + AllowedP1Root から対象までの親ディレクトリの
    # reparse point / junction / symlink を確認（→PAUSE: セキュリティ問題）
    # OneDriveクラウドプレースホルダー(LinkType/Target空)は許可、実リンクは拒否
    if (Test-ReparseInPath -LeafPath $p1FullPath -BoundaryRoot $AllowedP1Root) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "P1ファイルまたは親ディレクトリに reparse point/junction があります: $p1FullPath" -DoPause
        return $null
    }

    # 12. SHA-256 一致確認（不一致→PAUSE: 改ざん・同期ズレ）
    $actualHash = $null
    try {
        $actualHash = (Get-FileHash -Path $p1FullPath -Algorithm SHA256).Hash.ToLower()
    } catch {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "SHA-256 計算失敗: $_" -DoPause
        return $null
    }
    if ($actualHash -ne $p1Sha256) {
        Write-Log "SHA-256 不一致！改ざん・同期ズレの可能性。" "ERROR"
        Deny-Manifest -ManifestPath $ManifestPath -Reason "SHA-256 不一致: $cycle r$revision" -DoPause
        return $null
    }
    Write-Log "SHA-256 一致 OK"

    # 13. 重複チェック
    if (Test-AlreadyProcessed -Cycle $cycle -Revision $revision) {
        Write-Log "処理済みのためスキップ: ${cycle}:r${revision}" "WARN"
        return $null
    }

    # 合格 → 永続化を先に行い、成功後にメモリを更新（失敗→PAUSE）
    $marked = Mark-AsProcessed -Cycle $cycle -Revision $revision -State "validated"
    if (-not $marked) { return $null }

    Write-Log "=== バリデーション完了: $cycle (r$revision) ===" "OK"
    return $manifest
}

# ─────────────────────────────────────────────────────────────────────────
# Invoke-PendingScan: 未処理の *.ready.json を一括スキャン
# quarantine 配下は除外して走査
# ─────────────────────────────────────────────────────────────────────────
function Invoke-PendingScan {
    param([bool]$AllowPhase2 = $false)
    Write-Log "保留中の manifest をスキャン..."
    $manifests = @(Get-ChildItem -Path $MaestroDir -Filter "*.ready.json" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-UnderQuarantine $_.FullName) } |
        Sort-Object LastWriteTime)
    if ($manifests.Count -eq 0) {
        Write-Log "保留中の manifest はありません。"
        return
    }
    Write-Log "スキャン検知: $($manifests.Count) 件"
    foreach ($m in $manifests) {
        if (Test-Paused) { Write-Log "スキャン中断（PAUSE 検知）"; return }
        if (-not (Wait-FileStable -FilePath $m.FullName)) { continue }
        $result = Process-Manifest -ManifestPath $m.FullName
        if ($result) {
            Invoke-Phase2IfAllowed -Result $result -AllowPhase2 $AllowPhase2
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────
# Invoke-Phase2IfAllowed: Phase2起動判定の共通ロジック
# Start-Watching (イベント経路) と Invoke-PendingScan (スキャン経路) の両方から呼ぶ
# Fix1: Invoke-PendingScan経由でも同じ判定を通すことで経路漏れを防ぐ
# ─────────────────────────────────────────────────────────────────────────
function Invoke-Phase2IfAllowed {
    param([PSCustomObject]$Result, [bool]$AllowPhase2 = $false)
    if ($AllowPhase2) {
        if ($Result.cycle -match "test|dummy") {
            $p1FullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($ProjectRoot, $Result.p1_file))
            Invoke-ClaudeAgent -ManifestObj $Result -P1FullPath $p1FullPath
        } else {
            Write-Log ">>> 本番P1の自動起動は禁止: cycle名が test/dummy 系ではありません ($($Result.cycle))" "WARN"
            Write-Log ">>> 任意cycleの自動起動には -AllowNonDummyPhase2 とKazumax承認が別途必要です。" "WARN"
        }
    } else {
        Write-Log ">>> 【第2段階】-TestPhase2 なしでは自動起動しません。Kazumax承認後に -TestPhase2 を付けて実行してください。" "WARN"
    }
}

# ─────────────────────────────────────────────────────────────────────────
# 第0段階 Phase1: Test-ClaudeConnection
# 成功条件: exit0 + JSON + session_id非空 + result.Trim() == "OK"
# CLI生出力は通常ログに書かない。エラー分類のみ記録。
# ─────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────
# Invoke-ClaudeRaw: ProcessStartInfo で空文字列引数を確実に渡す共通関数
# --tools "" は PowerShell のネイティブ呼び出しで落ちる恐れがあるため
# Arguments 文字列を直接組み立て、空引数を "" として渡す。
# $Script:ClaudeExeOverride が設定されていればそのパスを使用（テスト用）。
# ─────────────────────────────────────────────────────────────────────────
function Invoke-ClaudeRaw {
    param([string[]]$ArgList, [int]$TimeoutSec = 60, [string]$WorkingDirectory = '')

    $exe = if ($Script:ClaudeExeOverride) { $Script:ClaudeExeOverride } else {
        try { Get-ClaudeExe } catch { throw "claude.exe 検出失敗: $_" }
    }

    # 各引数を Windows コマンドライン規則でクォート
    # 空文字列 → ""  /  スペース・引用符を含む → "..."  /  それ以外はそのまま
    $argStr = ($ArgList | ForEach-Object {
        if ($_ -eq '')              { '""' }
        elseif ($_ -match '[\s"]') { '"' + $_.Replace('"', '\"') + '"' }
        else                       { $_ }
    }) -join ' '

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = $exe
    $psi.Arguments              = $argStr
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }

    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    try {
        $null = $proc.Start()
        # テストフック: スタブ起動時に root PID をファイルへ記録
        if ($Script:ClaudeExeOverride -and $env:STUB_ROOT_PID_FILE) {
            try { Set-Content $env:STUB_ROOT_PID_FILE -Value $proc.Id -Encoding ASCII } catch {}
        }
        # stdout/stderr を非同期で読み始めてデッドロックを防ぐ
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $exited = $proc.WaitForExit($TimeoutSec * 1000)
        if (-not $exited) {
            # プロセスツリー全体を停止（子孫含む・無関係プロセスには触れない）
            $rootPid             = $proc.Id
            $tkExitCode          = -1
            $tkErrClass          = 'NotRun'
            $killFallback        = $false
            $rootKillAttempted   = $false
            $childKillAttempted  = $false
            $wmiFailed           = $false
            # taskkill を try/catch で包む: Access denied が PS 例外として伝播するのを防ぐ
            try {
                $null = taskkill /F /T /PID $rootPid 2>&1
                $tkExitCode = $LASTEXITCODE
                $tkErrClass = if ($tkExitCode -eq 0) { 'None' } else { 'NonZero' }
            } catch {
                $tkErrClass = 'PSException'
            }
            # exit code ではなく「root がまだ生きているか」でフォールバックを判断
            if ($null -ne (Get-Process -Id $rootPid -ErrorAction SilentlyContinue)) {
                $killFallback = $true
                # フォールバック1: root をプロセスハンドル経由で Kill()（取得済みハンドルで確実）
                $rootKillAttempted = $true
                try { $proc.Kill() } catch {}
                # フォールバック2: WMI で子孫を停止（失敗しても診断に記録して続行）
                try {
                    Get-WmiObject -Class Win32_Process -Filter "ParentProcessId=$rootPid" -ErrorAction SilentlyContinue |
                        ForEach-Object { $childKillAttempted = $true; try { Stop-Process -Id ([int]$_.ProcessId) -Force -ErrorAction SilentlyContinue } catch {} }
                } catch { $wmiFailed = $true }
                # テストフック: STUB_RECORD_FILE の child PID を直接停止（WMI 失敗時の補完）
                if ($Script:ClaudeExeOverride -and $env:STUB_RECORD_FILE -and (Test-Path $env:STUB_RECORD_FILE)) {
                    $sPidStr = (Get-Content $env:STUB_RECORD_FILE -Raw -ErrorAction SilentlyContinue).Trim()
                    if ($sPidStr -match '^\d+$') {
                        $childKillAttempted = $true
                        try { Stop-Process -Id ([int]$sPidStr) -Force -ErrorAction SilentlyContinue } catch {}
                    }
                }
            }
            # root の終了を最大 2 秒確認（TimeoutSec+2 が 8 秒以内に収まるため）
            $deadline = [DateTime]::UtcNow.AddSeconds(2)
            $stopped  = $false
            while ([DateTime]::UtcNow -lt $deadline) {
                try { $null = Get-Process -Id $rootPid -ErrorAction Stop }
                catch { $stopped = $true; break }
                Start-Sleep -Milliseconds 100
            }
            # タイムアウト時は stdout/stderr 完全回収を待たない（安全停止優先）
            # パイプを保持する子孫がいると GetResult() がパイプ閉鎖まで無期限待機するため
            $diagMsg = "taskkillExitCode=$tkExitCode taskkillErrClass=$tkErrClass killFallback=$killFallback rootKillAttempted=$rootKillAttempted childKillAttempted=$childKillAttempted wmiFailed=$wmiFailed stopped=$stopped"
            if (-not $stopped) {
                throw "タイムアウト後もプロセスが終了しませんでした (PID=$rootPid $diagMsg): 後続へ進めません"
            }
            throw "タイムアウト: claude が ${TimeoutSec}秒以内に終了しませんでした ($diagMsg)"
        }
        $proc.WaitForExit()   # 非同期バッファのフラッシュ（void・パイプライン汚染なし）

        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()

        return [PSCustomObject]@{ Output = $stdout; Error = $stderr; ExitCode = $proc.ExitCode }
    } finally {
        $proc.Dispose()
    }
}

function Test-ClaudeConnection {
    Write-Log "=== 第0段階 Phase1: 疎通テスト (課金確認用) ===" "HEADER"

    if ($env:ANTHROPIC_API_KEY) {
        Write-Log "ANTHROPIC_API_KEY が設定されています。従量課金になる恐れがあり中断します。" "WARN"
        return $false
    }
    Write-Log "ANTHROPIC_API_KEY: 未設定 (OK)" "OK"

    Write-Log "プロンプト送信中 (ツール無効・セッション保存なし)..."
    $r = $null; $exitCode = -1
    try {
        $r        = Invoke-ClaudeRaw @('-p', 'OKとだけ答えて', '--output-format', 'json', '--tools', '', '--no-session-persistence')
        $exitCode = $r.ExitCode
    } catch {
        Write-Log "claude.exe 呼び出し失敗: 終了コード不明" "ERROR"
        return $false
    }
    $outputLines = $r.Output -split "`n"
    $errorLines  = $r.Error  -split "`n"

    if ($exitCode -ne 0) {
        Write-Log "終了コード: $exitCode (失敗)" "ERROR"
        # CLI生出力は通常ログに書かない。パターンマッチでエラー分類のみ記録。
        $allLines = $outputLines + $errorLines
        $isNotLoggedIn = ($allLines | Where-Object { $_ -match "Not logged in" }).Count -gt 0
        if ($isNotLoggedIn) {
            Write-Log "エラー分類: 未ログイン → claude setup-token を実行してください。" "WARN"
        } else {
            Write-Log "エラー分類: 終了コード $exitCode (CLI生出力は記録しません)" "ERROR"
        }
        return $false
    }

    $json = $null
    try {
        $jsonStr = ($outputLines | Where-Object { $_ -match '^\{' }) -join ""
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

    # Phase1 成功条件: result.Trim() が "OK" と完全一致
    if ($result.Trim() -ne "OK") {
        Write-Log "応答が期待値 'OK' と不一致 → テスト失敗 (応答内容は記録しません)" "ERROR"
        return $false
    }

    Write-Log "終了コード: 0 (成功)" "OK"
    Write-Log "session_id: $(Get-MaskedId $sessionId) (先頭8桁のみ表示)" "OK"
    Write-Log "応答: 'OK' 完全一致 確認済み" "OK"
    Write-Log "─────────────────────────────────────────────" "INFO"
    Write-Log "【重要】Kazumax が Anthropic コンソールで課金なしを確認後、" "WARN"
    Write-Log "         -TestResume を実行してください (Phase2)。" "WARN"
    Write-Log "─────────────────────────────────────────────" "INFO"
    return $true
}

# ─────────────────────────────────────────────────────────────────────────
# 第0段階 Phase2: Test-ClaudeResume
# nonce はメモリのみ保持（ファイル保存なし・漏洩リスクゼロ）
# 成功条件: response.Trim() == nonce（完全一致のみ・前後説明付き応答は不合格）
# ─────────────────────────────────────────────────────────────────────────
function Test-ClaudeResume {
    Write-Log "=== 第0段階 Phase2: セッション再開テスト (nonce 完全一致) ===" "HEADER"

    # nonce はメモリのみ（ファイル保存不要）
    $nonce = "NONCE-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8).ToUpper()
    Write-Log "nonce 生成完了 (メモリのみ保持、ログ出力なし)"

    # ── Step A: nonce 記憶セッション開始（persistence有効・ツール無効） ───
    Write-Log "Step A: nonce 記憶セッション開始..."
    $rA = $null; $exitA = -1
    try {
        $rA    = Invoke-ClaudeRaw @('-p', "次の文字列を記憶してください: $nonce  記憶したら OK とだけ答えてください。", '--output-format', 'json', '--tools', '')
        $exitA = $rA.ExitCode
    } catch {
        Write-Log "Step A 呼び出し失敗: 終了コード不明" "ERROR"; return $false
    }
    if ($exitA -ne 0) {
        Write-Log "Step A 失敗 (終了コード: $exitA)" "ERROR"; return $false
    }
    $jsonA = $null
    try {
        $jsonA = (($rA.Output -split "`n" | Where-Object { $_ -match '^\{' }) -join "") | ConvertFrom-Json
    } catch {
        Write-Log "Step A JSON パース失敗 → テスト失敗" "ERROR"; return $false
    }
    $sessionId = [string]$jsonA.session_id
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        Write-Log "Step A session_id が空 → テスト失敗" "ERROR"; return $false
    }
    Write-Log "Step A 完了: session_id $(Get-MaskedId $sessionId)" "OK"

    # ── Step B: --resume でセッション再開し nonce を返させる（ツール無効） ─
    Write-Log "Step B: セッション再開 (--resume)..."
    $rB = $null; $exitB = -1
    try {
        $rB    = Invoke-ClaudeRaw @('-p', '先ほど記憶した文字列を、そのまま一言だけ答えてください。', '--output-format', 'json', '--tools', '', '--resume', $sessionId)
        $exitB = $rB.ExitCode
    } catch {
        Write-Log "Step B 呼び出し失敗: 終了コード不明" "ERROR"; return $false
    }
    if ($exitB -ne 0) {
        Write-Log "Step B 失敗 (終了コード: $exitB)" "ERROR"; return $false
    }
    $jsonB = $null
    try {
        $jsonB = (($rB.Output -split "`n" | Where-Object { $_ -match '^\{' }) -join "") | ConvertFrom-Json
    } catch {
        Write-Log "Step B JSON パース失敗 → テスト失敗" "ERROR"; return $false
    }
    $response = [string]$jsonB.result
    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-Log "Step B result が空 → テスト失敗" "ERROR"; return $false
    }

    # ── Step C: nonce 完全一致確認（-eq のみ。前後説明付きは不合格）─────
    if ($response.Trim() -eq $nonce) {
        Write-Log "nonce 完全一致: 文脈継続を確認しました！" "OK"
        Write-Log "第0段階 Phase1+Phase2 完了。-Watch で第1段階へ進めます。" "OK"
        return $true
    } else {
        Write-Log "nonce 不一致 → セッション継続を確認できませんでした" "ERROR"
        Write-Log "  応答内容はログに記録しません。" "ERROR"
        return $false
    }
}

# ─────────────────────────────────────────────────────────────────────────
# 第2段階 Phase2: Invoke-ClaudeAgent (CC自動起動)
# Fix3: Claude起動前にgitベースライン取得 → 差分のみを許可パス監査
# Fix4: Push-Location/Pop-Location を try/finally で例外安全化
# Fix5: cc.done.json の JSONパース + 全フィールド検証
# ─────────────────────────────────────────────────────────────────────────
function Invoke-ClaudeAgent {
    param([PSCustomObject]$ManifestObj, [string]$P1FullPath)

    $cycle    = $ManifestObj.cycle
    $revision = $ManifestObj.revision

    # ディレクトリ作成
    $sandboxDir = Join-Path $MaestroDir "sandbox"
    if (-not (Test-Path $sandboxDir)) { New-Item -ItemType Directory -Path $sandboxDir -Force | Out-Null }

    $runDir = Join-Path $MaestroDir "$cycle\revision_$revision"
    if (-not (Test-Path $runDir)) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }

    $tmpDir = Join-Path $runDir "tmp"
    if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }

    # 絶対パスに解決（git status 照合用にスラッシュ統一済み相対パスも保持）
    $p3RelPath        = "docs/handoff/P3_CC_Report/${cycle}.md"
    $p3FullPath       = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($ProjectRoot, $p3RelPath))

    $doneJsonRelPath  = "docs/handoff/maestro/${cycle}/revision_${revision}/cc.done.json"
    $doneJsonFullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($ProjectRoot, $doneJsonRelPath))

    $tmpFullPath = [System.IO.Path]::GetFullPath($tmpDir)
    $tmpRelPath  = $tmpFullPath.Substring($ProjectRoot.Length).TrimStart('\', '/') -replace '\\', '/'

    # Fix3/Fix7: 許可パス定義（git baseline/after 両方で参照するため先に定義）
    $allowedP3   = $p3RelPath
    $allowedDone = $doneJsonRelPath
    $allowedTmp  = $tmpRelPath.TrimEnd('/') + '/'

    # プロンプト作成（絶対パスを埋め込む）
    $promptFile = Join-Path $tmpDir "temp_prompt.txt"
    $promptText = "あなたはCCです。これはMaestro Runnerによる自動化フェーズ2のサンドボックステストです。`n" +
"P1ファイル '${P1FullPath}' を読み込んで、指示内容を理解してください。`n" +
"絶対に製品コード、設定ファイル、テンプレート、CSS、Java、SQL等は変更しないでください。`n`n" +
"許可されている出力先は以下の3つのみです。それ以外の場所への書き込みはすべて不正とみなされます。`n" +
"1. P3テスト報告書: ${p3FullPath}`n" +
"2. 完了合図: ${doneJsonFullPath}`n" +
"3. 一時ファイル: ${tmpFullPath}\ 配下`n`n" +
"P3には「読んだP1の要約」「実装せずに確認した内容」「出力したdone.jsonの場所」を書いてください。`n" +
"作業が完了したら、完了の証拠として ${doneJsonFullPath} を作成してください。`n" +
"JSONには以下のキーを含めてください: cycle, revision, source_p1_sha256, p3_file, p3_sha256, completed_at, result`n" +
"【重要】p3_file の値は絶対パスではなく、必ず次の相対パス文字列にすること: ${p3RelPath}`n" +
"【重要】p3_sha256 は実際に作成した P3 ファイルのSHA-256（小文字）にすること。"
    Set-Content -Path $promptFile -Value $promptText -Encoding UTF8

    # Fix3: Claude起動前にgitベースライン取得 + Fix2: 失敗時はPAUSE（git監査無効化を防ぐ）
    # --untracked-files=all でディレクトリではなく個別ファイルを列挙（Fix3 hash比較の前提）
    # try/catch: $ErrorActionPreference=Stop 環境でstderr ErrorRecord がthrowする問題に対応
    $gitBaseline         = @()
    $gitBaselineExitCode = 0
    $gitBaselineStderr   = ''
    $rawBaselineText     = ''
    Push-Location -LiteralPath $ProjectRoot
    try {
        try {
            $rawBaselineMixed    = git status --porcelain --untracked-files=all 2>&1
            $gitBaselineExitCode = $LASTEXITCODE
            $gitBaselineStderr   = ($rawBaselineMixed | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join ' '
            $rawBaselineText     = ($rawBaselineMixed | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
        } catch {
            if ($LASTEXITCODE -ne 0) { $gitBaselineExitCode = $LASTEXITCODE } else { $gitBaselineExitCode = 1 }
            $gitBaselineStderr = $_.Exception.Message -replace '\r?\n', ' '
        }
    } finally {
        Pop-Location
    }
    if ($rawBaselineText) {
        $gitBaseline = @($rawBaselineText -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if ($gitBaselineExitCode -ne 0) {
        Write-Log "git status --porcelain 失敗 (exit=$gitBaselineExitCode): $gitBaselineStderr" "ERROR"
        Require-Pause "git status 失敗: 安全監査不能。手動確認後 PAUSE を削除してください。"
        return
    }

    # Fix3 enhanced: 起動前dirty許可外ファイルのSHA-256を記録（CC起動後の内容変化検知用）
    # maestro.log のみ除外: Runner自身がbaseline〜after間に追記するため誤PAUSE防止
    # processed.log等他のmastroファイルは除外しない（CC書き込みを検知する必要あり）
    $logFileRel = ($LogFile.Substring($ProjectRoot.Length).TrimStart('\', '/') -replace '\\', '/').ToLower()
    $baselineHashes = @{}
    foreach ($line in $gitBaseline) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $bPath = $line.Substring(3).Trim(' "') -replace '\\', '/'
        if ($bPath -eq $allowedP3)   { continue }
        if ($bPath -eq $allowedDone) { continue }
        if ($bPath.StartsWith($allowedTmp, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($bPath.ToLower() -eq $logFileRel) { continue }
        $bFullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($ProjectRoot, ($bPath -replace '/', '\')))
        if (Test-Path $bFullPath -PathType Leaf) {
            try { $baselineHashes[$bPath] = (Get-FileHash -Path $bFullPath -Algorithm SHA256).Hash.ToLower() }
            catch { $baselineHashes[$bPath] = 'HASH_ERROR' }
        } else {
            $baselineHashes[$bPath] = 'NOT_EXISTS'
        }
    }

    Write-Log "CC(Claude Code) を自動起動します..." "INFO"

    # Fix4: WorkingDirectory を明示指定してサンドボックス隔離を保証
    $r = $null
    try {
        $promptArg = Get-Content -Path $promptFile -Raw
        $r = Invoke-ClaudeRaw @('-p', $promptArg, '--print', '--output-format', 'json', '--tools', 'default') -WorkingDirectory $sandboxDir
    } catch {
        Write-Log "CCプロセス呼び出し失敗: $_" "ERROR"
        Require-Pause "CC呼び出し失敗"
        return
    }

    $exitCode = $r.ExitCode
    $failed   = $false

    # 判定1: 終了コード
    if ($exitCode -ne 0) {
        Write-Log "CC終了コードが 0 ではありません: $exitCode" "ERROR"
        $failed = $true
    }

    # 判定2: P3の存在
    if (-not (Test-Path $p3FullPath)) {
        Write-Log "P3報告書が作成されていません: $p3FullPath" "ERROR"
        $failed = $true
    }

    # 判定3: cc.done.json の存在 + Fix5: 全フィールド検証
    if (-not (Test-Path $doneJsonFullPath)) {
        Write-Log "cc.done.json が作成されていません: $doneJsonFullPath" "ERROR"
        $failed = $true
    } else {
        $doneJson = $null
        try {
            $doneRaw  = Get-Content -Path $doneJsonFullPath -Raw -Encoding UTF8
            $doneJson = $doneRaw | ConvertFrom-Json
        } catch {
            Write-Log "cc.done.json のJSONパース失敗: $_" "ERROR"
            $failed = $true
        }
        if ($null -ne $doneJson) {
            if ([string]$doneJson.cycle -ne [string]$cycle) {
                Write-Log "done.json.cycle 不一致: '$($doneJson.cycle)' vs manifest '$cycle'" "ERROR"
                $failed = $true
            }
            if ([string]$doneJson.revision -ne [string]$revision) {
                Write-Log "done.json.revision 不一致: '$($doneJson.revision)' vs manifest '$revision'" "ERROR"
                $failed = $true
            }
            $p1Sha256 = (Get-FileHash -Path $P1FullPath -Algorithm SHA256).Hash.ToLower()
            if ([string]$doneJson.source_p1_sha256 -ne $p1Sha256) {
                Write-Log "done.json.source_p1_sha256 がP1ファイルのSHA256と不一致" "ERROR"
                $failed = $true
            }
            $p3FileInDone  = ([string]$doneJson.p3_file) -replace '\\', '/'
            $expectedP3Rel = $p3RelPath
            if ($p3FileInDone -ne $expectedP3Rel) {
                Write-Log "done.json.p3_file が許可パスと不一致: '$p3FileInDone' (expected '$expectedP3Rel')" "ERROR"
                $failed = $true
            }
            if (Test-Path $p3FullPath) {
                $actualP3Sha256 = (Get-FileHash -Path $p3FullPath -Algorithm SHA256).Hash.ToLower()
                if ([string]$doneJson.p3_sha256 -ne $actualP3Sha256) {
                    Write-Log "done.json.p3_sha256 が実際のP3ファイルのSHA256と不一致" "ERROR"
                    $failed = $true
                }
            }
            if (-not ([string]$doneJson.completed_at -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{2}:\d{2}|Z)$')) {
                Write-Log "done.json.completed_at がISO 8601+TZ形式ではありません: '$($doneJson.completed_at)'" "ERROR"
                $failed = $true
            }
            $allowedResults = @('success')
            if ($allowedResults -notcontains [string]$doneJson.result) {
                Write-Log "done.json.result が許可値ではありません: '$($doneJson.result)'" "ERROR"
                $failed = $true
            }
        }
    }

    # 判定4: Fix3: gitベースライン差分で許可パス監査 + Fix2: git失敗時はPAUSE
    $gitAfter         = @()
    $gitAfterExitCode = 0
    $gitAfterStderr   = ''
    $rawAfterText     = ''
    Push-Location -LiteralPath $ProjectRoot
    try {
        try {
            $rawAfterMixed    = git status --porcelain --untracked-files=all 2>&1
            $gitAfterExitCode = $LASTEXITCODE
            $gitAfterStderr   = ($rawAfterMixed | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { $_.ToString() }) -join ' '
            $rawAfterText     = ($rawAfterMixed | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
        } catch {
            if ($LASTEXITCODE -ne 0) { $gitAfterExitCode = $LASTEXITCODE } else { $gitAfterExitCode = 1 }
            $gitAfterStderr = $_.Exception.Message -replace '\r?\n', ' '
        }
    } finally {
        Pop-Location
    }
    if ($rawAfterText) {
        $gitAfter = @($rawAfterText -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if ($gitAfterExitCode -ne 0) {
        Write-Log "git status --porcelain (after) 失敗 (exit=$gitAfterExitCode): $gitAfterStderr" "ERROR"
        Require-Pause "git status (after) 失敗: 安全監査不能。手動確認後 PAUSE を削除してください。"
        return
    }

    # Fix3 enhanced: 既存dirty許可外ファイルの内容変化を検知（status行は変わらないが中身が変わる場合）
    $invalidPaths = @()
    foreach ($bPath in $baselineHashes.Keys) {
        $bFullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($ProjectRoot, ($bPath -replace '/', '\')))
        $afterHash = if (Test-Path $bFullPath -PathType Leaf) {
            try { (Get-FileHash -Path $bFullPath -Algorithm SHA256).Hash.ToLower() } catch { 'HASH_ERROR' }
        } else { 'NOT_EXISTS' }
        if ($afterHash -ne $baselineHashes[$bPath]) {
            Write-Log "既存dirty許可外ファイルの内容変化を検知: $bPath" "ERROR"
            $invalidPaths += $bPath
        }
    }

    # 新規または状態変化したファイルのdelta検査（maestro.logのみ除外: 他のmaestro配下ファイル新規作成は許可しない）
    $deltaLines = $gitAfter | Where-Object { $gitBaseline -notcontains $_ }
    foreach ($line in $deltaLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $modPath = $line.Substring(3).Trim(' "') -replace '\\', '/'
        if ($modPath -eq $allowedP3)   { continue }
        if ($modPath -eq $allowedDone) { continue }
        if ($modPath.StartsWith($allowedTmp, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        if ($modPath.ToLower() -eq $logFileRel) { continue }
        if ($invalidPaths -notcontains $modPath) { $invalidPaths += $modPath }
    }

    if ($invalidPaths.Count -gt 0) {
        Write-Log "許可外のファイル変更を検知しました:" "ERROR"
        foreach ($p in $invalidPaths) { Write-Log "  $p" "ERROR" }
        if (Test-Path $p3FullPath) {
            $bt = [char]96 + [char]96 + [char]96
            Add-Content -Path $p3FullPath -Value "`n`n### [SYSTEM] 不正差分検知`n`n以下の許可外パスが変更されました:`n`n${bt}`n$($invalidPaths -join "`n")`n${bt}" -Encoding UTF8
        }
        $failed = $true
    }

    if ($failed) {
        Require-Pause "CC異常終了 または 不正差分検知。自動ロールバックはしません。手動で確認・復旧してください。"
        return
    }

    Write-Log ">>> CCの処理が完了しました。Dexにレビューを依頼してください。" "OK"
}

# ─────────────────────────────────────────────────────────────────────────
# Start-Watching: メイン監視ループ
# mutex取得後の全処理を try/finally で囲み、異常終了でも確実に解放
# ─────────────────────────────────────────────────────────────────────────
function Start-Watching {
    Write-Log "=== Maestro Runner 監視開始 ===" "HEADER"
    Write-Log "監視対象: $MaestroDir (サブディレクトリ含む)"
    Write-Log "停止: Ctrl+C または $PauseFile を作成"

    if (-not (Test-Path $MaestroDir)) {
        New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
    }

    Initialize-ProcessedSet

    try {
        Enter-SingleInstance
    } catch {
        Write-Log "$_" "ERROR"
        return
    }

    # mutex 取得後: 全後続処理を try/finally で囲み、異常終了でも確実に解放
    try {
        if (-not (Test-Paused)) { Invoke-PendingScan -AllowPhase2 $TestPhase2 }

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

                if ($pauseWasActive) {
                    Write-Log "PAUSE 解除を検知。保留中 manifest をスキャンします。" "INFO"
                    Invoke-PendingScan -AllowPhase2 $TestPhase2
                    $pauseWasActive = $false
                    $lastScan = [datetime]::UtcNow
                }

                if (([datetime]::UtcNow - $lastScan).TotalSeconds -ge 30) {
                    Invoke-PendingScan -AllowPhase2 $TestPhase2
                    $lastScan = [datetime]::UtcNow
                }

                $changeTypes = [System.IO.WatcherChangeTypes]::Created `
                            -bor [System.IO.WatcherChangeTypes]::Changed `
                            -bor [System.IO.WatcherChangeTypes]::Renamed
                $event = $watcher.WaitForChanged($changeTypes, 2000)
                if ($event.TimedOut) { continue }

                $fileName     = $event.Name
                $manifestPath = Join-Path $MaestroDir $fileName

                # quarantine 配下のイベントはパス境界判定で破棄（隔離→再検知ループ防止）
                if (Test-UnderQuarantine $manifestPath) { continue }

                if ($recentEvents.ContainsKey($fileName) -and
                    ((Get-Date) - $recentEvents[$fileName]).TotalMilliseconds -lt 100) { continue }
                $recentEvents[$fileName] = Get-Date

                Write-Log "manifest イベント検知: $fileName ($($event.ChangeType))"

                if (-not (Wait-FileStable -FilePath $manifestPath)) { continue }

                $result = Process-Manifest -ManifestPath $manifestPath
                if ($null -eq $result) {
                    Write-Log "manifest 処理完了（quarantine 済みまたはスキップ）。次を待機します。" "WARN"
                    continue
                }

                Write-Log ">>> バリデーション合格: $($result.cycle) (r$($result.revision))" "OK"

                # Fix1: 共通関数でPhase2起動判定（Invoke-PendingScan経由と同一ロジック）
                Invoke-Phase2IfAllowed -Result $result -AllowPhase2 $TestPhase2
                
                Write-Log "────────────────────────────────────────────" "INFO"
            }
        } finally {
            $watcher.Dispose()
        }
    } finally {
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
docs/handoff/maestro/*.ready.json
docs/handoff/maestro/**/*.ready.json
docs/handoff/maestro/quarantine/
"@
    Add-Content -Path $gitignore -Value $entries -Encoding UTF8
    Write-Log ".gitignore に maestro ランタイムエントリを追加しました"
}

# ─────────────────────────────────────────────────────────────────────────
# メイン
# テストハーネス(maestro_runner.tests.ps1)から dot-source する場合は
# $env:MAESTRO_NO_MAIN を設定し、関数定義のみ読み込んでメインを実行しない
# ─────────────────────────────────────────────────────────────────────────
if ($env:MAESTRO_NO_MAIN) { return }

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

