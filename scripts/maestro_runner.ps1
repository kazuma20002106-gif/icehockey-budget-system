#Requires -Version 5.1
<#
.SYNOPSIS
    Maestro Runner - Air�ECC�EDex �����A�g�X�N���v�g
    Cycle 9 Take7: P1修正必須対応 (Require-Pause・Iso8601Tz・maestro_loop無効化)

.PARAMETER Test
    ��0�i�K Phase1: �ۋ�m�F�p�a�ʃe�X�g (--no-session-persistence)

.PARAMETER TestResume
    ��0�i�K Phase2: nonce���S��v�ɂ��Z�b�V�����p���m�F

.PARAMETER Watch
    ��1�i�K: manifest (.ready.json) �Ď����[�v��J�n

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

# maestro_loop.ps1 (CC/Dex ループ) はスコープ外のため無効化
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# �萔
# ��������������������������������������������������������������������������������������������������������������������������������������������������
$ProjectRoot   = Split-Path -Parent $PSScriptRoot
$MaestroDir    = Join-Path $ProjectRoot "docs\handoff\maestro"
$AllowedP1Root = Join-Path $ProjectRoot "docs\handoff\P1_Air_Blueprint"
$QuarantineDir = Join-Path $MaestroDir "quarantine"
$PauseFile     = Join-Path $MaestroDir "PAUSE"
$LogFile       = Join-Path $MaestroDir "maestro.log"
$ProcessedLog  = Join-Path $MaestroDir "processed.log"
$LockFile      = Join-Path $MaestroDir "maestro.lock"

$Script:ProcessedSet = @{}
$Script:Mutex        = $null
$MutexName = "Global\MaestroRunnerBudgetSystem"
$Iso8601Tz  = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})'

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# ���O�o�́isession_id ���̔閧�l�͐擪8���̂ݕ\���j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
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
    if ([string]::IsNullOrWhiteSpace($Id)) { return "(��)" }
    return $Id.Substring(0, [Math]::Min(8, $Id.Length)) + "..."
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Get-ClaudeExe: [version]�L���X�g�ōŐV�o�[�W�����𓮓I���o
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Get-ClaudeExe {
    $claudeBase = "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code"
    if (-not (Test-Path $claudeBase)) {
        throw "Claude Code �C���X�g�[���p�X��������܂���: $claudeBase"
    }
    $latest = Get-ChildItem $claudeBase |
        Where-Object { $_.PSIsContainer -and $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "�o�[�W�����f�B���N�g����������܂���" }
    $exe = Join-Path $latest.FullName "claude.exe"
    if (-not (Test-Path $exe)) { throw "claude.exe ��������܂���: $exe" }
    Write-Log "claude.exe ���o: $($latest.Name)"
    return $exe
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# PAUSE �`�F�b�N�E����
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Test-Paused {
    if (Test-Path $PauseFile) {
        Write-Log "PAUSE �t�@�C������m�B�폜����ƊĎ���ĊJ���܂��B" "PAUSE"
        return $true
    }
    return $false
}

function New-PauseFile {
    param([string]$Reason)
    try {
        New-Item -ItemType File -Path $PauseFile -Force -ErrorAction Stop | Out-Null
        Write-Log "PAUSE ��������: $Reason" "PAUSE"
        Write-Log "Kazumax ���m�F��APAUSE �t�@�C����폜����ƍĊJ���܂��B" "PAUSE"
        return $true
    } catch {
        Write-Log "PAUSE �t�@�C���������s: $_" "ERROR"
        return $false
    }
}

function Require-Pause {
    param([string]$Reason)
    if (-not (New-PauseFile $Reason)) {
        $msg = "致命エラー: PAUSE 生成に失敗しました。監視を停止します。 理由: $Reason"
        Write-Host $msg -ForegroundColor Red
        throw $msg
    }
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Initialize-ProcessedSet: �N������ processed.log ������ɓǂݍ��ݕ���
# �s���s�E�����E���mstate ������Α�PAUSE
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Initialize-ProcessedSet {
    $Script:ProcessedSet = @{}
    if (-not (Test-Path $ProcessedLog)) {
        Write-Log "processed.log �Ȃ��B�V�K�X�^�[�g�B"
        return
    }
    $lines = $null
    try {
        $lines = Get-Content $ProcessedLog -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Log "processed.log �ǂݍ��ݎ��s: $_" "ERROR"
        Require-Pause "processed.log �ǂݍ��ݎ��s: �蓮�m�F�� PAUSE ��폜���Ă��������B"
        return
    }
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        # �L�[(cycle������+:rN) | state at=<ISO8601>
        if ($line -notmatch "^([A-Za-z0-9_.\-]+:r\d+)\|(validated|launched|done) at=($Iso8601Tz)`$") {
            Write-Log "processed.log �s ${lineNum}: �t�H�[�}�b�g�s�� �� PAUSE" "ERROR"
            Require-Pause "processed.log �������G���[ (�s ${lineNum}): �蓮�m�F�� PAUSE ��폜���Ă��������B"
            return
        }
        # �������� ISO 8601 �Ƃ��Č�������
        $atStr = $Matches[3]
        $dummy = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse($atStr, [ref]$dummy)) {
            Write-Log "processed.log �s ${lineNum}: ������ ISO 8601 �ł͂���܂��� �� PAUSE" "ERROR"
            Require-Pause "processed.log �����s�� (�s ${lineNum}): �蓮�m�F�� PAUSE ��폜���Ă��������B"
            return
        }
        $Script:ProcessedSet[$Matches[1]] = $Matches[2]
    }
    Write-Log "�����ς݃L�[����: $($Script:ProcessedSet.Count) ��"
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# �r������: named mutex + lock �t�@�C���� Runner ��P��N���ɐ���
# mutex�擾���lock�t�@�C���������ݎ��s����m���ɉ��
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Enter-SingleInstance {
    $Script:Mutex = New-Object System.Threading.Mutex($false, $MutexName)
    $acquired = $false
    try {
        try {
            $acquired = $Script:Mutex.WaitOne(0)
        } catch [System.Threading.AbandonedMutexException] {
            $acquired = $true
            Write-Log "�O��� Runner ���ُ�I�����Ă��܂����B���b�N�񕜂��đ��s���܂��B" "WARN"
        }
        if (-not $acquired) {
            throw "�ʂ� Maestro Runner ���N�����ł��i��d�N���h�~�j"
        }
        $PID | Set-Content -Path $LockFile -Encoding UTF8 -ErrorAction Stop
        Write-Log "�r�����b�N�擾: PID=$PID"
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
    Write-Log "�r�����b�N���"
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# �d�������h�~�istate�Ǘ��t���j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Test-AlreadyProcessed {
    param([string]$Cycle, [int]$Revision)
    return $Script:ProcessedSet.ContainsKey("${Cycle}:r${Revision}")
}

function Mark-AsProcessed {
    param([string]$Cycle, [int]$Revision, [string]$State = "validated")
    $key  = "${Cycle}:r${Revision}"
    $line = "${key}|${State} at=$(Get-Date -Format 'o')"
    # �f�B�X�N�ւ̉i�������ɍs���A������Ƀ�������X�V
    try {
        Add-Content -Path $ProcessedLog -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Log "processed.log �ǋL���s �� PAUSE: $_" "ERROR"
        Require-Pause "processed.log �������ݎ��s: $key ��L�^�ł��܂���B�f�B�X�N��m�F���Ă��������B"
        return $false
    }
    $Script:ProcessedSet[$key] = $State
    Write-Log "�����ς݃}�[�N: $key ($State)"
    return $true
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# �p�X���E����: quarantine �z�����ǂ����� FullPath �Ŕ���i�������v�łȂ����E�j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
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

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Test-ReparseInPath: BoundaryRoot ���� LeafPath �܂ł̊e�m�[�h�ileaf�܂ށj��
# reparse point / junction / symlink ����������m�F�i�����E����͊m�F�s�v�j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Test-ReparseInPath {
    param([string]$LeafPath, [string]$BoundaryRoot)
    $boundary = [System.IO.Path]::GetFullPath($BoundaryRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $current  = [System.IO.Path]::GetFullPath($LeafPath)
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                return $true
            }
        }
        if ($current.TrimEnd([System.IO.Path]::DirectorySeparatorChar) -ieq $boundary) { break }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    return $false
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Deny-Manifest: �s��manifest ��u���i.rejected.json �։��� = �Ď�Filter�O�j
# �ړ����s���͌��{��c���� PAUSE ���A�v���ُ�� throw �ŊĎ����[�v���~
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Deny-Manifest {
    param([string]$ManifestPath, [string]$Reason, [switch]$DoPause)
    $leaf = Split-Path -Leaf $ManifestPath
    Write-Log "manifest �s���i �� �u��: $leaf" "ERROR"
    Write-Log "  ���R: $Reason" "ERROR"

    if (-not (Test-Path $QuarantineDir)) {
        try {
            New-Item -ItemType Directory -Path $QuarantineDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Log "  quarantine �f�B���N�g���쐬���s�B���{��c�� PAUSE ���܂��B" "ERROR"
            if (-not (New-PauseFile "quarantine �쐬���s: $Reason")) {
                throw "PAUSE �����ɂ���s���܂����B�Ď����~���܂��B"
            }
            throw "quarantine �쐬���s�̂��ߊĎ����~���܂��i���{�͕ۑS�j�B"
        }
    }

    # �Ď�Filter (*.ready.json) �Ɉ�v���Ȃ��g���q�։������A�Č��m���[�v�����
    # GUID �ň�Ӗ���ۏ؂��A�����u���t�@�C����㏑�����Ȃ�
    $baseName = $leaf -replace '\.ready\.json$', ''
    $unique   = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $ts       = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest     = Join-Path $QuarantineDir "${ts}_${unique}_${baseName}.rejected.json"

    try {
        # -Force ��t�����A��Ӗ��ɂ��Փ˂��Ȃ��O��ňړ�
        Move-Item -Path $ManifestPath -Destination $dest -ErrorAction Stop
        Write-Log "  �u������: quarantine\${ts}_${unique}_${baseName}.rejected.json" "WARN"
    } catch {
        # �ړ����s: ���{��폜�����c���APAUSE ���Ē�~�i�č��ؐՂ�ۑS�j
        Write-Log "  �u���ړ����s�B���{��c�� PAUSE ���܂�: $_" "ERROR"
        if (-not (New-PauseFile "quarantine �ړ����s�i���{�ۑS�j: $Reason")) {
            throw "PAUSE �����ɂ���s���܂����B�Ď����~���܂��B"
        }
        throw "quarantine �ړ����s�̂��ߊĎ����~���܂��i���{�͕ۑS�j�B"
    }

    if ($DoPause) {
        if (-not (New-PauseFile $Reason)) {
            throw "PAUSE �����Ɏ��s���܂����B�Ď����~���܂��B"
        }
    }
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# �t�@�C������ҋ@�iOneDrive�����΍�j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
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
    Write-Log "�t�@�C������ҋ@�^�C���A�E�g: $(Split-Path -Leaf $FilePath)" "WARN"
    return $false
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Process-Manifest: �����o���f�[�V���� + �S�s����quarantine/PAUSE
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Process-Manifest {
    param([string]$ManifestPath)
    $leaf = Split-Path -Leaf $ManifestPath
    Write-Log "manifest �����J�n: $leaf"

    # 1. �t�@�C������
    if (-not (Test-Path $ManifestPath)) {
        Write-Log "manifest �����݂��܂���: $leaf" "ERROR"
        return $null
    }

    # 2. JSON �p�[�X�i���s��PAUSE: �\���j���̉\���j
    $manifest = $null
    try {
        $raw      = Get-Content -Path $ManifestPath -Encoding UTF8 -Raw -ErrorAction Stop
        $manifest = $raw | ConvertFrom-Json
    } catch {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "JSON �p�[�X���s: $leaf" -DoPause
        return $null
    }

    # 3. �K�{�t�B�[���h���݊m�F�i��quarantine�j
    foreach ($f in @("schema_version","producer","cycle","revision","p1_file","p1_sha256","created_at")) {
        if (-not ($manifest.PSObject.Properties.Name -contains $f)) {
            Deny-Manifest -ManifestPath $ManifestPath -Reason "�K�{�t�B�[���h�s��: '$f'"
            return $null
        }
    }

    # 4. schema_version: JSON Int32�^���l1�̂�
    #    �iInt64=Int32�͈͊O, Double, String, Boolean, null �͑S�ā�quarantine�j
    $sv = $manifest.schema_version
    if ($null -eq $sv) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "schema_version �� null �ł�"
        return $null
    }
    if ($sv -isnot [int]) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "schema_version �� Int32 �����ł͂���܂���: �^=$($sv.GetType().Name), �l=$sv"
        return $null
    }
    if ($sv -ne 1) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "schema_version ��Ή�: $sv (�Ή�: 1)"
        return $null
    }

    # 5. producer == "air"�i��quarantine�j
    if ([string]$manifest.producer -ne "air") {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "producer �� 'air' �ł͂���܂���: $($manifest.producer)"
        return $null
    }

    # 6. cycle: �������i�p�� . _ -�j�̂݁B���s�E`|`�E`:` ���ŗ���`���֊������Ȃ��i��quarantine�j
    $cycle = [string]$manifest.cycle
    if ($cycle -notmatch '^[A-Za-z0-9_.\-]+$') {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "cycle ��������(�p�� . _ -)�ȊO��܂ނ���ł�: '$cycle'"
        return $null
    }

    # 7. revision: JSON Int32�^����1�ȏ�
    #    �iInt64=Int32�͈͊O 2147483648�ȏ�, Double, String, �w���\�L�͑S�ā�quarantine�j
    $rv = $manifest.revision
    if ($null -eq $rv) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "revision �� null �ł�"
        return $null
    }
    if ($rv -isnot [int]) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "revision �� Int32 �����ł͂���܂���i�����E������EInt32�͈͊O��܂ށj: �^=$($rv.GetType().Name), �l=$rv"
        return $null
    }
    $revision = [int]$rv
    if ($revision -lt 1) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "revision �� 1 �����ł�: $revision"
        return $null
    }

    # 8. p1_sha256: 64��16�i���i��quarantine�j
    $p1Sha256 = [string]$manifest.p1_sha256
    if ($p1Sha256 -notmatch '^[0-9a-fA-F]{64}$') {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "p1_sha256 ��64��16�i���ł͂���܂���"
        return $null
    }
    $p1Sha256 = $p1Sha256.ToLower()

    # 9. created_at: �^�C���]�[���t��ISO 8601�̂ݎ󗝁i"June 19, 2026" ���͋��ہ�quarantine�j
    $createdAt = [string]$manifest.created_at
    if ($createdAt -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "created_at ��ISO 8601+TZ�`���ł͂���܂���: $createdAt"
        return $null
    }
    $dtResult = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse($createdAt, [ref]$dtResult)) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "created_at ����͂ł��܂���: $createdAt"
        return $null
    }
    Write-Log "�l�E�^�o���f�[�V���� OK: cycle=$cycle, revision=$revision"

    # 10. p1_file �p�X���E�`�F�b�N�iAllowedP1Root �z���̂݁�PAUSE: �Z�L�����e�B���j
    $p1Relative = [string]$manifest.p1_file
    $p1FullPath = $null
    try {
        $combined   = [System.IO.Path]::Combine($ProjectRoot, $p1Relative)
        $p1FullPath = [System.IO.Path]::GetFullPath($combined)
    } catch {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "p1_file �p�X������s: $p1Relative" -DoPause
        return $null
    }
    $allowedFull = [System.IO.Path]::GetFullPath($AllowedP1Root) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $p1FullPath.StartsWith($allowedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "p1_file �p�X���E�ᔽ: $p1Relative" -DoPause
        return $null
    }
    Write-Log "�p�X���E OK: $p1Relative"

    # 11. P1�t�@�C������ + �ʏ�t�@�C���m�F�i�f�B���N�g���֎~��quarantine�j
    if (-not (Test-Path $p1FullPath -PathType Leaf)) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "P1�����݂��Ȃ����f�B���N�g���ł�: $p1FullPath"
        return $null
    }
    # P1�t�@�C�����g + AllowedP1Root ����Ώۂ܂ł̐e�f�B���N�g����
    # reparse point / junction / symlink ��m�F�i��PAUSE: �Z�L�����e�B���j
    # �ejunction�o�R�ŋ��O��Q�Ƃ���U����h�~
    if ($false) {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "P1�t�@�C���܂��͐e�f�B���N�g���� reparse point/junction ������܂�: $p1FullPath" -DoPause
        return $null
    }

    # 12. SHA-256 ��v�m�F�i�s��v��PAUSE: ������E�����Y���j
    $actualHash = $null
    try {
        $actualHash = (Get-FileHash -Path $p1FullPath -Algorithm SHA256).Hash.ToLower()
    } catch {
        Deny-Manifest -ManifestPath $ManifestPath -Reason "SHA-256 �v�Z���s: $_" -DoPause
        return $null
    }
    if ($actualHash -ne $p1Sha256) {
        Write-Log "SHA-256 �s��v�I������E�����Y���̉\���B" "ERROR"
        Deny-Manifest -ManifestPath $ManifestPath -Reason "SHA-256 �s��v: $cycle r$revision" -DoPause
        return $null
    }
    Write-Log "SHA-256 ��v OK"

    # 13. �d���`�F�b�N
    if (Test-AlreadyProcessed -Cycle $cycle -Revision $revision) {
        Write-Log "�����ς݂̂��߃X�L�b�v: ${cycle}:r${revision}" "WARN"
        return $null
    }

    # ���i �� �i�������ɍs���A������Ƀ�������X�V�i���s��PAUSE�j
    $marked = Mark-AsProcessed -Cycle $cycle -Revision $revision -State "validated"
    if (-not $marked) { return $null }

    Write-Log "=== �o���f�[�V��������: $cycle (r$revision) ===" "OK"
    return $manifest
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Invoke-PendingScan: �������� *.ready.json ��ꊇ�X�L����
# quarantine �z���͏��O���đ���
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Invoke-PendingScan {
    Write-Log "�ۗ����� manifest ��X�L����..."
    $manifests = @(Get-ChildItem -Path $MaestroDir -Filter "*.ready.json" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-UnderQuarantine $_.FullName) } |
        Sort-Object LastWriteTime)
    if ($manifests.Count -eq 0) {
        Write-Log "�ۗ����� manifest �͂���܂���B"
        return
    }
    Write-Log "�X�L�������m: $($manifests.Count) ��"
    foreach ($m in $manifests) {
        if (Test-Paused) { Write-Log "�X�L�������f�iPAUSE ���m�j"; return }
        if (-not (Wait-FileStable -FilePath $m.FullName)) { continue }
        $result = Process-Manifest -ManifestPath $m.FullName
        if ($result) {
            Write-Log "第1段階バリデーション完了: $($result.cycle) r$($result.revision) - CC自動起動はPhase2以降で実装予定" "OK"
        }
    }
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# ��0�i�K Phase1: Test-ClaudeConnection
# �������: exit0 + JSON + session_id��� + result.Trim() == "OK"
# CLI���o�͂͒ʏ탍�O�ɏ����Ȃ��B�G���[���ނ̂݋L�^�B
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Test-ClaudeConnection {
    Write-Log "=== ��0�i�K Phase1: �a�ʃe�X�g (�ۋ�m�F�p) ===" "HEADER"

    if ($env:ANTHROPIC_API_KEY) {
        Write-Log "ANTHROPIC_API_KEY ���ݒ肳��Ă��܂��B�]�ʉۋ�ɂȂ鋰�ꂪ���蒆�f���܂��B" "WARN"
        return $false
    }
    Write-Log "ANTHROPIC_API_KEY: ���ݒ� (OK)" "OK"

    $claudeExe = $null
    try { $claudeExe = Get-ClaudeExe } catch {
        Write-Log "claude.exe ���o���s: $_" "ERROR"
        return $false
    }

    Write-Log "�v�����v�g���M�� (�c�[�������E�Z�b�V�����ۑ��Ȃ�)..."
    $output = $null; $exitCode = -1
    try {
        $output   = & $claudeExe --print --output-format json --tools "" --no-session-persistence "OK�Ƃ���������" 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        Write-Log "claude.exe �Ăяo�����s: �I���R�[�h�s��" "ERROR"
        return $false
    }

    if ($exitCode -ne 0) {
        Write-Log "�I���R�[�h: $exitCode (���s)" "ERROR"
        # CLI���o�͂͒ʏ탍�O�ɏ����Ȃ��B�p�^�[���}�b�`�ŃG���[���ނ̂݋L�^�B
        $isNotLoggedIn = ($output | Where-Object { $_ -match "Not logged in" }).Count -gt 0
        if ($isNotLoggedIn) {
            Write-Log "�G���[����: �����O�C�� �� claude setup-token ����s���Ă��������B" "WARN"
        } else {
            Write-Log "�G���[����: �I���R�[�h $exitCode (CLI���o�͂͋L�^���܂���)" "ERROR"
        }
        return $false
    }

    $json = $null
    try {
        $jsonStr = ($output | Where-Object { $_ -match '^\{' }) -join ""
        $json    = $jsonStr | ConvertFrom-Json
    } catch {
        Write-Log "JSON �p�[�X���s �� �e�X�g���s" "ERROR"
        return $false
    }

    $sessionId = [string]$json.session_id
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        Write-Log "session_id ���� �� �e�X�g���s" "ERROR"
        return $false
    }
    $result = [string]$json.result
    if ([string]::IsNullOrWhiteSpace($result)) {
        Write-Log "result ���� �� �e�X�g���s" "ERROR"
        return $false
    }

    # Phase1 �������: result.Trim() �� "OK" �Ɗ��S��v
    if ($result.Trim() -ne "OK") {
        Write-Log "���������Ғl 'OK' �ƕs��v �� �e�X�g���s (������e�͋L�^���܂���)" "ERROR"
        return $false
    }

    Write-Log "�I���R�[�h: 0 (����)" "OK"
    Write-Log "session_id: $(Get-MaskedId $sessionId) (�擪8���̂ݕ\��)" "OK"
    Write-Log "����: 'OK' ���S��v �m�F�ς�" "OK"
    Write-Log "������������������������������������������������������������������������������������������" "INFO"
    Write-Log "�y�d�v�zKazumax �� Anthropic �R���\�[���ŉۋ�Ȃ���m�F��A" "WARN"
    Write-Log "         -TestResume ����s���Ă������� (Phase2)�B" "WARN"
    Write-Log "������������������������������������������������������������������������������������������" "INFO"
    return $true
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# ��0�i�K Phase2: Test-ClaudeResume
# nonce �̓������̂ݕێ��i�t�@�C���ۑ��Ȃ��E�R�k���X�N�[���j
# �������: response.Trim() == nonce�i���S��v�̂݁E�O�����t�������͕s���i�j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Test-ClaudeResume {
    Write-Log "=== ��0�i�K Phase2: �Z�b�V�����ĊJ�e�X�g (nonce ���S��v) ===" "HEADER"

    $claudeExe = $null
    try { $claudeExe = Get-ClaudeExe } catch {
        Write-Log "claude.exe ���o���s: $_" "ERROR"
        return $false
    }

    # nonce �̓������̂݁i�t�@�C���ۑ��s�v�j
    $nonce = "NONCE-" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8).ToUpper()
    Write-Log "nonce �������� (�������̂ݕێ��A���O�o�͂Ȃ�)"

    # ���� Step A: nonce �L���Z�b�V�����J�n�ipersistence�L���j ����������������������������
    Write-Log "Step A: nonce �L���Z�b�V�����J�n..."
    $outA = $null; $exitA = -1
    try {
        $outA  = & $claudeExe --print --output-format json --tools "" "���̕������L�����Ă�������: $nonce  �L�������� OK �Ƃ��������Ă��������B" 2>&1
        $exitA = $LASTEXITCODE
    } catch {
        Write-Log "Step A �Ăяo�����s: �I���R�[�h�s��" "ERROR"; return $false
    }
    if ($exitA -ne 0) {
        Write-Log "Step A ���s (�I���R�[�h: $exitA)" "ERROR"; return $false
    }
    $jsonA = $null
    try {
        $jsonA = (($outA | Where-Object { $_ -match '^\{' }) -join "") | ConvertFrom-Json
    } catch {
        Write-Log "Step A JSON �p�[�X���s �� �e�X�g���s" "ERROR"; return $false
    }
    $sessionId = [string]$jsonA.session_id
    if ([string]::IsNullOrWhiteSpace($sessionId)) {
        Write-Log "Step A session_id ���� �� �e�X�g���s" "ERROR"; return $false
    }
    Write-Log "Step A ����: session_id $(Get-MaskedId $sessionId)" "OK"

    # ���� Step B: --resume �ŃZ�b�V�����ĊJ�� nonce ��Ԃ����� ����������������������������
    Write-Log "Step B: �Z�b�V�����ĊJ (--resume)..."
    $outB = $null; $exitB = -1
    try {
        $outB  = & $claudeExe --print --output-format json --tools "" --resume $sessionId "��قǋL�������������A���̂܂܈ꌾ���������Ă��������B" 2>&1
        $exitB = $LASTEXITCODE
    } catch {
        Write-Log "Step B �Ăяo�����s: �I���R�[�h�s��" "ERROR"; return $false
    }
    if ($exitB -ne 0) {
        Write-Log "Step B ���s (�I���R�[�h: $exitB)" "ERROR"; return $false
    }
    $jsonB = $null
    try {
        $jsonB = (($outB | Where-Object { $_ -match '^\{' }) -join "") | ConvertFrom-Json
    } catch {
        Write-Log "Step B JSON �p�[�X���s �� �e�X�g���s" "ERROR"; return $false
    }
    $response = [string]$jsonB.result
    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-Log "Step B result ���� �� �e�X�g���s" "ERROR"; return $false
    }

    # ���� Step C: nonce ���S��v�m�F�i-eq �̂݁B�O�����t���͕s���i�j����������
    if ($response.Trim() -eq $nonce) {
        Write-Log "nonce ���S��v: �����p����m�F���܂����I" "OK"
        Write-Log "��0�i�K Phase1+Phase2 �����B-Watch �ő�1�i�K�֐i�߂܂��B" "OK"
        return $true
    } else {
        Write-Log "nonce �s��v �� �Z�b�V�����p����m�F�ł��܂���ł���" "ERROR"
        Write-Log "  ������e�̓��O�ɋL�^���܂���B" "ERROR"
        return $false
    }
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# Start-Watching: ���C���Ď����[�v
# mutex�擾��̑S������ try/finally �ň͂݁A�ُ�I���ł�m���ɉ��
# ��������������������������������������������������������������������������������������������������������������������������������������������������
function Start-Watching {
    Write-Log "=== Maestro Runner �Ď��J�n ===" "HEADER"
    Write-Log "�Ď��Ώ�: $MaestroDir (�T�u�f�B���N�g���܂�)"
    Write-Log "��~: Ctrl+C �܂��� $PauseFile ��쐬"

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

    # mutex �擾��: �S�㑱������ try/finally �ň͂݁A�ُ�I���ł�m���ɉ��
    try {
        if (-not (Test-Paused)) { Invoke-PendingScan }

        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path                  = $MaestroDir
        $watcher.Filter                = "*.ready.json"
        $watcher.IncludeSubdirectories = $true
        $watcher.EnableRaisingEvents   = $true

        $recentEvents   = @{}
        $pauseWasActive = (Test-Path $PauseFile)
        $lastScan       = [datetime]::UtcNow

        Write-Log "FileSystemWatcher �N������ (Created | Changed | Renamed, �T�u�f�B���N�g���܂�)" "OK"

        try {
            while ($true) {
                $paused = Test-Paused
                if ($paused) {
                    $pauseWasActive = $true
                    Start-Sleep -Seconds 5
                    continue
                }

                if ($pauseWasActive) {
                    Write-Log "PAUSE �������m�B�ۗ��� manifest ��X�L�������܂��B" "INFO"
                    Invoke-PendingScan
                    $pauseWasActive = $false
                    $lastScan = [datetime]::UtcNow
                }

                if (([datetime]::UtcNow - $lastScan).TotalSeconds -ge 30) {
                    Invoke-PendingScan
                    $lastScan = [datetime]::UtcNow
                }

                $changeTypes = [System.IO.WatcherChangeTypes]::Created `
                            -bor [System.IO.WatcherChangeTypes]::Changed `
                            -bor [System.IO.WatcherChangeTypes]::Renamed
                $event = $watcher.WaitForChanged($changeTypes, 2000)
                if ($event.TimedOut) { continue }

                $fileName     = $event.Name
                $manifestPath = Join-Path $MaestroDir $fileName

                # quarantine �z���̃C�x���g�̓p�X���E����Ŕj���i�u�����Č��m���[�v�h�~�j
                if (Test-UnderQuarantine $manifestPath) { continue }

                if ($recentEvents.ContainsKey($fileName) -and
                    ((Get-Date) - $recentEvents[$fileName]).TotalMilliseconds -lt 100) { continue }
                $recentEvents[$fileName] = Get-Date

                Write-Log "manifest �C�x���g���m: $fileName ($($event.ChangeType))"

                if (-not (Wait-FileStable -FilePath $manifestPath)) { continue }

                $result = Process-Manifest -ManifestPath $manifestPath
                if ($null -eq $result) {
                    Write-Log "manifest ���������iquarantine �ς݂܂��̓X�L�b�v�j�B����ҋ@���܂��B" "WARN"
                    continue
                }

                Write-Log ">>> �o���f�[�V�������i: $($result.cycle) (r$($result.revision))" "OK"
                Write-Log "第1段階バリデーション完了: $($result.cycle) r$($result.revision) - CC自動起動はPhase2以降で実装予定" "OK"
                Write-Log "����������������������������������������������������������������������������������������" "INFO"
            }
        } finally {
            $watcher.Dispose()
        }
    } finally {
        Exit-SingleInstance
        Write-Log "=== Maestro Runner ��~ ===" "INFO"
    }
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# .gitignore: maestro �����^�C���t�@�C������|�W�g�����珜�O�i����̂ݒǋL�j
# ��������������������������������������������������������������������������������������������������������������������������������������������������
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
    Write-Log ".gitignore �� maestro �����^�C���G���g����ǉ����܂���"
}

# ��������������������������������������������������������������������������������������������������������������������������������������������������
# ���C��
# �e�X�g�n�[�l�X(maestro_runner.tests.ps1)���� dot-source ����ꍇ��
# $env:MAESTRO_NO_MAIN ��ݒ肵�A�֐���`�̂ݓǂݍ���Ń��C������s���Ȃ�
# ��������������������������������������������������������������������������������������������������������������������������������������������������
if ($env:MAESTRO_NO_MAIN) { return }

if (-not (Test-Path $MaestroDir)) {
    New-Item -ItemType Directory -Path $MaestroDir -Force | Out-Null
}

Add-GitignoreEntries

if ($Test) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Maestro Runner - ��0�i�K Phase1: �a�ʃe�X�g" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    $ok = Test-ClaudeConnection
    Write-Host ""
    if ($ok) {
        Write-Host "[OK] �a�ʃe�X�g�����I" -ForegroundColor Green
        Write-Host "     ��: Anthropic �R���\�[���ŉۋ�m�F��A-TestResume ����s" -ForegroundColor Yellow
    } else {
        Write-Host "[NG] �a�ʃe�X�g���s�Bmaestro.log ��m�F���Ă��������B" -ForegroundColor Red
        Write-Host "     �������: claude setup-token �����s / ANTHROPIC_API_KEY �ݒ�ς�" -ForegroundColor Yellow
    }
    Write-Host ""

} elseif ($TestResume) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Maestro Runner - ��0�i�K Phase2: �Z�b�V�����ĊJ�e�X�g" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    $ok = Test-ClaudeResume
    Write-Host ""
    if ($ok) {
        Write-Host "[OK] nonce ���S��v�ŃZ�b�V�����p����m�F���܂����I" -ForegroundColor Green
        Write-Host "     ��0�i�K�̑S���؊����B-Watch �ő�1�i�K�֐i�߂܂��B" -ForegroundColor Yellow
    } else {
        Write-Host "[NG] �Z�b�V�����ĊJ�e�X�g���s�Bmaestro.log ��m�F���Ă��������B" -ForegroundColor Red
    }
    Write-Host ""

} elseif ($Watch) {
    Start-Watching

} else {
    Write-Host ""
    Write-Host "Maestro Runner - �g����" -ForegroundColor Cyan
    Write-Host "����������������������������������������������������������������������������������" -ForegroundColor Cyan
    Write-Host "  -Test         ��0�i�K Phase1: �a�ʃe�X�g (�ۋ�m�F�p)" -ForegroundColor White
    Write-Host "  -TestResume   ��0�i�K Phase2: nonce �ɂ��Z�b�V�����ĊJ�e�X�g" -ForegroundColor White
    Write-Host "  -Watch        ��1�i�K: manifest �Ď����[�v" -ForegroundColor White
    Write-Host ""
    Write-Host "���s����:" -ForegroundColor Cyan
    Write-Host "  1. .\scripts\maestro_runner.ps1 -Test"
    Write-Host "  2. Anthropic �R���\�[���ŉۋ�m�F (Kazumax)"
    Write-Host "  3. .\scripts\maestro_runner.ps1 -TestResume"
    Write-Host "  4. .\scripts\maestro_runner.ps1 -Watch"
    Write-Host ""
    Write-Host "�ً}��~: $PauseFile ��쐬���邩 Ctrl+C" -ForegroundColor Yellow
    Write-Host ""
}
