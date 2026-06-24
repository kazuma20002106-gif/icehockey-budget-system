# [C10: CC(P3)] Cycle 10 Take 4 実装報告書

作成日: 2026-06-24
作成者: CC (Claude Code)
バージョン: v2.1.11
対象: `scripts/maestro_runner.ps1` / `scripts/maestro_runner.tests.ps1`

---

## 1. 対象と背景

Cycle 10 は「Maestro Runner Phase 2 (CC自動起動とサンドボックス確認)」の実装サイクルです。  
Take 1〜3 では Air が実装を試みましたが、Dex のレビュー(P4)で 7 件の必須修正が指摘されました。  
Take 4 として CC が Air 実装を引き取り、P4 指摘に従って全修正を実施しました。

---

## 2. 実装した関数・変更一覧

### 2.1 `Invoke-ClaudeRaw` (Fix4 関連)

- **追加パラメータ**: `[string]$WorkingDirectory = ''`
- `$WorkingDirectory` が指定された場合、`ProcessStartInfo.WorkingDirectory` に明示設定
- これにより `Push-Location` に頼らず、サブプロセスの作業ディレクトリを確実に制御可能

### 2.2 `Invoke-ClaudeAgent` (Fix3 / Fix4 / Fix5)

**Fix3: git ベースライン比較**
- Claude 起動「前」に `git status --porcelain` を取得してベースライン化
- Claude 終了「後」に再取得し、ベースライン差分のみを許可パス監査の対象とする
- 既存の未追跡ファイルや他AI作業中の差分を誤検知しない設計

**Fix4: Push-Location / Pop-Location の例外安全化**
- git status 用の `Push-Location` は `try/finally` で囲み、どの経路でも `Pop-Location` を保証
- Claude 呼び出し用の `Push-Location` は廃止し、`Invoke-ClaudeRaw -WorkingDirectory $sandboxDir` に変更
  - 理由: PS5.1 では `Push-Location` がサブプロセスの Win32 作業ディレクトリに反映されない場合がある

**Fix5: cc.done.json 内容検証**
- JSON パース (ConvertFrom-Json)
- `cycle` / `revision` が manifest と一致することを検証
- `source_p1_sha256` が P1 ファイルの実際の SHA-256 と一致することを検証
- `p3_file` が許可された相対パスであることを検証
- `p3_sha256` が実際の P3 ファイルの SHA-256 と一致することを検証
- `completed_at` が ISO 8601 + タイムゾーン形式であることを検証
- `result` が許可値 (`success`) のみであることを検証

### 2.3 起動ガード (Fix7)

**変更前**:
```powershell
if ($result.cycle -match "test|dummy" -or $TestPhase2) {
    Invoke-ClaudeAgent ...
}
```

**変更後**:
```powershell
if ($TestPhase2) {
    if ($result.cycle -match "test|dummy") {
        Invoke-ClaudeAgent ...
    } else {
        Write-Log ">>> 本番P1の自動起動は禁止: cycle名が test/dummy 系ではありません" "WARN"
    }
} else {
    Write-Log ">>> -TestPhase2 なしでは自動起動しません" "WARN"
}
```

`-TestPhase2` は Phase2 機能の有効化スイッチに留め、cycle 名ガードは必ず通る設計に修正。

---

## 3. テスト結果

```
結果: PASS=42  FAIL=0
```

### セクション別内訳
| セクション | テスト名 | 件数 | 結果 |
|---|---|---|---|
| A | 検知・一回性 | 3 | 全PASS |
| B | 重複防止・再起動・二重起動 | 4 | 全PASS |
| C | 形式不正の隔離・停止 | 11 | 全PASS |
| D | PAUSE・quarantine後の再起動 | 2 | 全PASS |
| E | 安全装置失敗時の致命停止 | 4 | 全PASS |
| F | 文字コード検証 | 4 | 全PASS |
| G | Invoke-ClaudeRaw 実行テスト | 8 | 全PASS |
| **H** | **Invoke-ClaudeAgent スタブテスト** | **6** | **全PASS** |

### H セクション詳細

| ケース | 内容 | 結果 |
|---|---|---|
| H1 | 正常系: P3+done.json のみ作成 → PAUSE なし | PASS |
| H2 | 不正差分系: src/ に不正ファイル作成 → PAUSE 停止 | PASS |
| H3 | git reset/restore/clean が Invoke-ClaudeAgent に含まれないこと（静的チェック） | PASS |
| H4 | 許可パス判定: tmp/ 配下ファイルも許可 → PAUSE なし | PASS |
| H5 | WorkingDirectory がサンドボックス (`docs/handoff/maestro/sandbox/`) | PASS |
| H6 | プロンプトに P1・P3・done.json の絶対パスが含まれること | PASS |

---

## 4. 安全設計の証明

### git reset/restore/clean の不在
H3 テストおよびソースコードの静的確認により、`Invoke-ClaudeAgent` に以下のコマンドが含まれないことを確認済み:
- `git reset --hard`
- `git restore .`
- `git clean -f`

### 自動ロールバックの禁止
不正差分検知時は `Require-Pause` を呼んで停止するだけで、変更ファイルの自動消去は行わない。

### 許可パス判定ロジック
Claude (自動起動 CC) が書き込んでよいパスは以下の 3 種類のみ:
1. `docs/handoff/P3_CC_Report/{cycle}.md`
2. `docs/handoff/maestro/{cycle}/revision_{revision}/cc.done.json`
3. `docs/handoff/maestro/{cycle}/revision_{revision}/tmp/` 配下

git ベースライン差分のうち、上記に一致しないパスを検知した場合のみ PAUSE。

---

## 5. 実 Claude 呼び出しについて

本 Take 4 の実装・テストは **外部通信なしのスタブ** で実施しました。  
実際の Claude (CC) の自動起動テストは、Dex レビュー通過後に Kazumax/Air 管理下で実施します。

---

## 6. 変更ファイル一覧

| ファイル | 変更概要 |
|---|---|
| `scripts/maestro_runner.ps1` | Invoke-ClaudeRaw: WorkingDirectory パラメータ追加 |
| `scripts/maestro_runner.ps1` | Invoke-ClaudeAgent: Fix3/Fix4/Fix5/Fix7 修正 |
| `scripts/maestro_runner.tests.ps1` | Fix1: 末尾構文エラー除去 |
| `scripts/maestro_runner.tests.ps1` | Fix2: H1〜H6 スタブテスト追加 |
| `src/main/resources/application.properties` | v2.1.10 → v2.1.11 |
| `docs/handoff/P3_CC_Report/cycle_10.md` | 本ファイル（新規作成） |
| `docs/handoff/CURRENT_STATUS.md` | 現在地更新 |
