# Cycle 9 CC実装完了報告書 (Take 10)

作成日: 2026-06-22
実装者: CC (Claude Code)
バージョン: v2.1.5

## Take 10: Dex差し戻し（Take 9 NG）への対応

Dex（P4）から Take 9 に対して3件の修正必須指摘が届いた。本 Take 10 はその全件に対応した。

---

## 修正必須1 対応: `Invoke-ClaudeRaw` 共通関数で `--tools ""` を確実に渡す

**問題**: Take 9 では PowerShell のネイティブ引数変換で空文字列引数が落ちることを回避するため `--tools "default"` を使用していた。これは最小権限要件に違反し、ログ表示（「ツール無効」）と実態が逆だった。

**対応**: `Invoke-ClaudeRaw` 共通関数を新設し、`System.Diagnostics.ProcessStartInfo.Arguments` に引数文字列を直接構築する。空文字列 → `""` としてOS層のコマンドラインに渡すため、PowerShellの変換を経由しない。

- `Test-ClaudeConnection`: `Invoke-ClaudeRaw @('-p', 'OKとだけ答えて', '--output-format', 'json', '--tools', '', '--no-session-persistence')`
- `Test-ClaudeResume` Step A: `Invoke-ClaudeRaw @('-p', "...", '--output-format', 'json', '--tools', '')`
- `Test-ClaudeResume` Step B: `Invoke-ClaudeRaw @('-p', '...', '--output-format', 'json', '--tools', '', '--resume', $sessionId)`

3経路すべてが `Invoke-ClaudeRaw` を通る。`default` へのフォールバックは一切ない。

テスト用スタブ差し替えのため `$Script:ClaudeExeOverride = $null` を定数セクションに追加。

---

## 修正必須2 対応: `Test-ReparseInPath` を OneDrive対応版へ置き換え

**問題**: Take 9 では OneDrive がすべてのファイルに `ReparsePoint` 属性を付与するため `Test-ReparseInPath` が正規パスを拒否した。対策として検証ロジックを丸ごとコメントアウトしていた。

**対応**: `ReparsePoint` 属性があっても `LinkType` と `Target` が両方空ならば OneDrive クラウドプレースホルダーと判定して継続。`LinkType` または `Target` が設定されていれば実リンク（Junction/Symlink）として拒否＋PAUSE する。

```
OneDriveプレースホルダー: ReparsePoint=true, LinkType="", Target="" → 許可候補（上位ノードを継続確認）
実リンク (Junction/Symlink): LinkType or Target が非空 → 拒否＋PAUSE
```

`Process-Manifest` 内のリンク検証コードを復元し、OneDrive対応版 `Test-ReparseInPath` で実装。

---

## 修正必須3 対応: Take 9 の Phase 0 実機テストを「無効」と記録

**問題**: Take 9 の Phase 0 実機テスト4回（Phase1×2、Phase2×2）は `--tools "default"`（全ツール使用可能）で実行されており、最小権限要件を満たしていなかった。

**記録**: Take 9 の実機テスト結果は「引数不正」のため安全テスト合格とみなさない。`--tools ""` を確実に渡す Invoke-ClaudeRaw への修正後に、Air による Phase 0 再実機確認が必要。

---

## 統合テスト結果（外部通信なし）

`maestro_runner.tests.ps1` の実行結果: **PASS=35 / FAIL=0**

### G1-G7 新規テスト（Take 10 追加分）

| テストID | 種別 | 内容 | 結果 |
|---|---|---|---|
| G1 | ソース検証 | `Invoke-ClaudeRaw` が `ProcessStartInfo` を使用 | **PASS** |
| G2 | ソース検証 | `Test-ClaudeConnection` の呼び出しに `'--tools', ''` がある | **PASS** |
| G3 | ソース検証 | Phase1 呼び出しに `--no-session-persistence` がある | **PASS** |
| G4 | ソース検証 | Step B に `--resume` あり・Step A にはなし | **PASS** |
| G5 | 機能テスト | 通常 temp パスに `Test-ReparseInPath` → `$false` | **PASS** |
| G6 | 機能テスト | junction 経由パスに `Test-ReparseInPath` → `$true` | **PASS** |
| G7 | 機能テスト | SHA-256 不一致が reparse 判定と独立して PAUSE される | **PASS** |

### 既存テスト（A1-A3, B1-B4, C1-C11, D1-D2, E1-E4, F1-F4）

全 PASS。Take 10 の変更により既存テストへの影響なし。

---

## Take 10 変更ファイル一覧

| ファイル | 種別 | 説明 |
|---|---|---|
| `scripts/maestro_runner.ps1` | **更新** | `Invoke-ClaudeRaw` 新設・`$Script:ClaudeExeOverride` 追加・OneDrive対応 `Test-ReparseInPath` 実装・3呼び出し経路を `Invoke-ClaudeRaw` へ統一・`$outB` → `$rB.Output` 修正 |
| `scripts/maestro_runner.tests.ps1` | **更新** | G1-G7 テスト追加（合計 35 テスト） |
| `src/main/resources/application.properties` | **更新** | v2.1.5 へバージョンアップ |
| `docs/handoff/P3_CC_Report/cycle_9.md` | **更新** | 本報告書（Take 10: Dex差し戻し全件対応） |
| `docs/TEAM_CHAT.md` | **更新** | CC Take 10 完了エントリ追加 |

---

## セルフQA（CLAUDE.md準拠）

1. **変更対象確認**: Take 10 の変更は上記5ファイルのみ。巻き添え変更なし。

2. **P1 Verification Plan 照合**:
   - Phase 0 Step 1-4（疎通テスト・最小権限）: `--tools ''` を確実に渡す `Invoke-ClaudeRaw` を実装。Air による再実機確認が必要。
   - Phase 0 Step 5（課金確認）: Kazumax 手動確認待ち（スクリプト外）。
   - Phase 0 Step 6（nonce 完全一致）: `Invoke-ClaudeRaw` で Step B も修正完了。Air による再実機確認が必要。
   - Phase 1 Step 1-4: 統合テスト PASS=35 確認。実リンク検証も G6 で確認。

3. **セキュリティ注記**: OneDrive対応 `Test-ReparseInPath` を復元。Junction/Symlink（LinkType または Target が非空）は拒否＋PAUSE。OneDrive クラウドプレースホルダー（LinkType/Target 空）は通過。`AllowedP1Root` prefix チェックは引き続き有効。

4. **バージョン同期**: `application.properties` と `target/classes/application.properties` 両方 v2.1.5 を確認。

5. **統合テスト**: PASS=35 / FAIL=0（G1-G7 追加。F4 U+FFFD 0件も引き続き確認済み）。

---

## Dexへの確認・依頼事項

1. **Phase 0 再実機確認（Air担当）**: Take 10 修正後の `Invoke-ClaudeRaw` で `--tools ''` が確実に渡ることを Air に実機で再確認してもらう必要がある（`-Test` / `-TestResume` の再実行。Dex Stop Conditions の解除が前提）。
2. **課金確認**: `claude auth status` で `loggedIn: true`, `authMethod: claude.ai`, `subscriptionType: pro`（APIキー認証でない）を確認済みだが、Anthropic Usage/請求画面の目視確認が終わるまで「第0段階完了」とは記録しない。

---

## 現在のステータス

**Take 10: 実装完了。Dex（P4）レビュー待ち。**

Dex の Stop Conditions（`-Test` / `-TestResume` 追加実行禁止・`-Watch` 本番禁止・第2段階禁止・`maestro_loop.ps1` 実行禁止）は引き続き有効。Dex のレビュー合格後に Air による Phase 0 再実機確認へ進む。
