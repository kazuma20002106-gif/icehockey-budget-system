# Cycle 9 CC実装完了報告書 (Take 5)

作成日: 2026-06-19
実装者: CC (Claude Code)
バージョン: v2.1.0

## Take 5 差分（Dex P4 Take4 全修正必須対応）

| 修正必須 | 指摘内容 | 対応方法 |
|---|---|---|
| 修正必須1 | `Deny-Manifest` が `.ready.json` のまま quarantine へ移動し、FileSystemWatcher が再検知してループ。 | 隔離時に `.rejected.json`（監視Filter `*.ready.json` 外）へ改名。さらに `Test-UnderQuarantine`（パス境界判定）でスキャン・イベント両方で quarantine 配下を除外。 |
| 修正必須2 | quarantine 移動失敗時に原本を削除。PAUSE 作成失敗を警告のみで握り潰し。 | 移動/作成失敗時は原本を残し PAUSE＋throw で監視停止（自動削除を全廃）。`New-PauseFile` が成功/失敗を返し、失敗なら throw。GUID 一意名で `-Force` 上書きを廃止。 |
| 修正必須3 | `processed.log` の日時が `at=.+`、cycle非空のみ、revision が Int64 許可後に `[int]` 変換で範囲外例外、親 junction 未確認。 | 日時を ISO 8601 として `TryParse` 検証。cycle を `^[A-Za-z0-9_.\-]+$` に限定。schema_version/revision を `-is [int]`（Int32）のみ許可。`Test-ReparseInPath` で AllowedP1Root〜対象の全親 reparse point を確認。 |
| 修正必須4 | 第1段階の統合テスト（一回性・停止動作）が未実施。 | `scripts/maestro_runner.tests.ps1` を新設。外部通信なしで20ケースを自動検証し、全PASSを確認（下記）。 |

---

## 実機テスト結果（修正必須4 対応）

`scripts/maestro_runner.tests.ps1` を実行。maestro_runner.ps1 を `$env:MAESTRO_NO_MAIN` で dot-source し、一時領域で外部通信なしに自動検証。

**実行コマンド**: `.\scripts\maestro_runner.tests.ps1`
**総合結果**: **PASS=20 / FAIL=0**

### A. 検知と一回性

| # | テスト | 期待 | 実測 | 判定 |
|---|---|---|---|---|
| A1 | 起動前配置 → スキャン2回でも処理は1回 | processed.log=1行 | 1行 | **PASS** |
| A2 | サブディレクトリ `cycle_9/revision_1/air.ready.json` を検知 | ProcessedSet登録 | 登録 | **PASS** |
| A3 | temp→ready rename後、スキャン2回でも1回 | processed.log=1行 | 1行 | **PASS** |

### B. 重複防止・再起動・二重起動

| # | テスト | 期待 | 実測 | 判定 |
|---|---|---|---|---|
| B1 | 同一revision再通知 → 2回目スキップ | 1回目非null/2回目null/1行 | 一致 | **PASS** |
| B2 | Runner再起動(ProcessedSet復元) → 再処理しない | 2回目null/1行 | 一致 | **PASS** |
| B3 | 二重起動(別プロセスでmutex保持) → 2つ目取得失敗 | WaitOne=false | false | **PASS** |
| B4 | 起動時スキャン失敗後にmutex解放→再起動可能 | 再Enter成功 | 成功 | **PASS** |

### C. 形式不正で後続に進まない（quarantine / PAUSE）

| # | テスト | 期待 | 実測 | 判定 |
|---|---|---|---|---|
| C1 | JSON不正 | null+quarantine+PAUSE | 一致 | **PASS** |
| C2 | 必須値不足 | null+quarantine | 一致 | **PASS** |
| C3 | schema_version=1.5 (Decimal) | null+quarantine | 一致(型=Decimal) | **PASS** |
| C4 | revision=1.5 (Decimal) | null+quarantine | 一致(型=Decimal) | **PASS** |
| C5 | revision=2147483648 (Int32超/Int64) | 例外なくquarantine | 一致(型=Int64) | **PASS** |
| C6 | cycle不正文字 `bad:r9\|x` | null+quarantine | 一致 | **PASS** |
| C7 | created_at非ISO `June 19, 2026` | null+quarantine | 一致 | **PASS** |
| C8 | 許可外パス `../../../secret.md` | null+PAUSE | 一致 | **PASS** |
| C9 | P1がディレクトリ | null+quarantine | 一致 | **PASS** |
| C10 | SHA-256不一致 | null+PAUSE | 一致 | **PASS** |
| C11 | 履歴書込失敗(processed.logをディレクトリ化) | null+PAUSE | 一致 | **PASS** |

### D. PAUSE回収・隔離後の再処理防止

| # | テスト | 期待 | 実測 | 判定 |
|---|---|---|---|---|
| D1 | PAUSE中スキップ → 解除後に回収 | 中=未処理/後=処理 | 一致 | **PASS** |
| D2 | quarantine後に再スキャンしても再処理しない | 隔離件数1で不変 | after1=1 after3=1 | **PASS** |

### git check-ignore 実測（root・サブディレクトリ・quarantine）

| パス | 結果 | パターン |
|---|---|---|
| `docs/handoff/maestro/test.ready.json` | IGNORED | `**/*.ready.json` |
| `docs/handoff/maestro/cycle_9/revision_1/air.ready.json` | IGNORED | `**/*.ready.json` |
| `docs/handoff/maestro/quarantine/x.rejected.json` | IGNORED | `quarantine/` |
| `docs/handoff/maestro/maestro.log` | IGNORED | `*.log` |
| `docs/handoff/maestro/PAUSE` | IGNORED | `PAUSE` |

### 外部Claude接続テスト（Phase1/Phase2）

Kazumaxによる課金経路の目視確認が完了していないため未実施（Dex も承認前の未実施を許容）。

---

## 実装ファイル一覧

| ファイル | 種別 | 説明 |
|---|---|---|
| `scripts/maestro_runner.ps1` | **更新** | Take5: Dex P4 Take4 全4修正必須対応 |
| `scripts/maestro_runner.tests.ps1` | **新規作成** | 第1段階 統合テストハーネス（外部通信なし・20ケース） |
| `.gitignore` | 既存 | `*.ready.json`・`quarantine/` パターンは Take4 で追加済み |

---

## Take 5 主要変更点（関数別）

#### `Test-UnderQuarantine`（新設）
- `GetFullPath` でパス境界判定。quarantine 配下を文字列一致でなく正規化パスで判定。
- `Invoke-PendingScan`（スキャン）と `Start-Watching`（イベント受信）の両方で使用。

#### `Test-ReparseInPath`（新設）
- LeafPath から BoundaryRoot(AllowedP1Root) までの全ノード（leaf含む）の `ReparsePoint` 属性を確認。
- 親 junction/symlink 経由で許可外を参照する攻撃を防止。

#### `Deny-Manifest`（全面改修）
- 隔離先を `.rejected.json` に改名（監視Filter `*.ready.json` 外 → 再検知ループ根絶）。
- GUID 一意名で衝突回避（`-Force` 廃止）。
- quarantine 作成失敗・移動失敗時は**原本を削除せず**残し、PAUSE＋throw で監視停止。

#### `New-PauseFile`（戻り値追加）
- 成功 `$true` / 失敗 `$false` を返す。Deny-Manifest が失敗を検知して throw。

#### `Initialize-ProcessedSet`（厳密化）
- キーを `^[A-Za-z0-9_.\-]+:r\d+$` に限定。日時を `[datetimeoffset]::TryParse` で ISO 8601 検証。不正→PAUSE。

#### `Process-Manifest`（厳密化）
- schema_version/revision を `-is [int]`（Int32）のみに（Int64=Int32範囲外を弾き、例外で落ちない）。
- cycle を `^[A-Za-z0-9_.\-]+$` に限定（改行・`|`・`:` で履歴形式へ干渉させない）。
- P1 ファイルと親ディレクトリの reparse point を `Test-ReparseInPath` で確認。

#### メインブロックガード
- `if ($env:MAESTRO_NO_MAIN) { return }` を追加。テストハーネスから関数のみ dot-source 可能に。

---

## 構文チェック結果

```
[System.Management.Automation.Language.Parser]::ParseFile → エラー0件 (OK)（両スクリプト）
```

---

## Dexへの確認依頼事項

1. `Deny-Manifest` の `.rejected.json` 改名＋`Test-UnderQuarantine` の二重防御が再検知ループ対策として十分か確認
2. quarantine/PAUSE 失敗時の throw による監視停止（原本保全）が安全装置として妥当か確認
3. `Test-ReparseInPath` の親ディレクトリ走査範囲（AllowedP1Root まで）が要件通りか確認
4. テストハーネス `maestro_runner.tests.ps1` の20ケースが前回P4の回帰確認項目を網羅しているか確認
5. **第0段階の疎通テスト実施可否**: Kazumaxの承認が必要。OKであれば `.\scripts\maestro_runner.ps1 -Test` を実行してもらう

---

## 次のステップ

**第1段階 統合テスト（いつでも実行可・外部通信なし）:**
```powershell
.\scripts\maestro_runner.tests.ps1
```

**第0段階 Phase1（Kazumaxの承認後）:**
```powershell
$claude = (Get-Item "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code\*\claude.exe" | Sort-Object { [version]($_.Directory.Name) } -Descending | Select-Object -First 1).FullName
& $claude setup-token
.\scripts\maestro_runner.ps1 -Test
```

**第0段階 Phase2（課金なし確認後）:** `.\scripts\maestro_runner.ps1 -TestResume`
**第1段階（疎通テスト成功後）:** `.\scripts\maestro_runner.ps1 -Watch`

現在のステータス：Take 5 実装完了・統合テスト全20件PASS。Dex (P4) 再レビュー待ち。
