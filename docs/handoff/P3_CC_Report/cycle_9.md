# Cycle 9 CC実装完了報告書 (Take 11)

作成日: 2026-06-22
実装者: CC (Claude Code)
バージョン: v2.1.6

## Take 11: Dex差し戻し（Take 10 NG）への対応

Dex（P4）から Take 10 に対して3件の修正必須指摘が届いた。本 Take 11 はその全件に対応した。

---

## 修正必須1 対応: `Invoke-ClaudeRaw` が結果オブジェクトを1個だけ返す

**問題**: `$proc.WaitForExit($TimeoutSec * 1000)` が `bool` を返すが、戻り値を変数に代入していなかったため PowerShell パイプラインに `bool` が流れ出ていた。関数の戻り値が `[bool, PSCustomObject]` の配列になり、呼び出し側が `$r.ExitCode` を取得できなかった。

**対応**: `$exited = $proc.WaitForExit($TimeoutSec * 1000)` として `bool` を変数に捕捉。戻り値は `PSCustomObject` 1個のみ。また `$proc.Start()` の `bool` も `$null = $proc.Start()` で抑止。`finally` ブロックで `$proc.Dispose()` を確実に実行。

---

## 修正必須2 対応: タイムアウトを実際に機能させる

**問題**: `ReadToEnd()` (同期) を先に実行してからタイムアウト付き `WaitForExit()` を呼ぶ構造だった。プロセスが終了しなければ `ReadToEnd()` で先に無期限停止するため 60 秒タイムアウトが機能しなかった。stdout → stderr の順に同期読みするとバッファ満杯でデッドロックが起きうる。

**対応**:
1. `ReadToEndAsync()` で stdout/stderr を非同期で並行読み始める
2. `$exited = $proc.WaitForExit(TimeoutSec * 1000)` でタイムアウト付き終了待ち
3. タイムアウトなら `$proc.Kill()` して `throw "タイムアウト: claude が N秒以内に終了しませんでした"`
4. 正常終了後 `$proc.WaitForExit()` (void・パイプライン汚染なし) で非同期バッファをフラッシュ
5. `$stdoutTask.GetAwaiter().GetResult()` で stdout を回収

---

## 修正必須3 対応: G1-G7 をソース検索から実行テストへ置き換え

**問題**: Take 10 の G1-G4 はソース内に文字列が存在するか確認するだけで `Invoke-ClaudeRaw` を一度も実行しておらず、複数戻り値バグを検出できなかった。

**対応**: 外部通信なしのスタブ実行ファイル（`.cmd`）を一時生成し、実際に `Invoke-ClaudeRaw` を動的に実行して検証する。

| テストID | 内容 | スタブ |
|---|---|---|
| G1 | 戻り値が PSCustomObject 1個（配列でない） | 通常スタブ |
| G2 | ExitCode が整数型として取得できる | 通常スタブ |
| G3 | OS層実引数に `--tools ""` あり・`default` なし | 通常スタブ+args記録 |
| G4 | Phase1 実引数に `--no-session-persistence` あり | 通常スタブ+args記録 |
| G5 | Step A 実引数に `--resume` なし | 通常スタブ+args記録 |
| G6 | Step B 実引数に `--resume <sessionId>` あり | 通常スタブ+args記録 |
| G7 | タイムアウトで `throw` かつ 5秒以内に返る | sleepスタブ(ping -n 35) |

スタブ設計:
- 通常スタブ (`stub.cmd`): `if defined STUB_RECORD_FILE (echo %* > "%STUB_RECORD_FILE%")` で OS 受け取り引数を記録、JSON を stdout 出力
- sleep スタブ (`stub_sleep.cmd`): `ping -n 35 127.0.0.1 > nul` で 30 秒以上待機
- `$Script:ClaudeExeOverride` でスタブ差し替え。`STUB_RECORD_FILE` 環境変数で記録先ファイルを指定
- G3/G4/G5/G6 はファイルに記録された args 文字列に正規表現でアサート

---

## 統合テスト結果（外部通信なし）

`maestro_runner.tests.ps1` の実行結果: **PASS=35 / FAIL=0**

G1-G7 全件 PASS（実行テストに昇格）。A1-A3, B1-B4, C1-C11, D1-D2, E1-E4, F1-F4 も変化なし PASS。

---

## Take 11 変更ファイル一覧

| ファイル | 種別 | 説明 |
|---|---|---|
| `scripts/maestro_runner.ps1` | **更新** | `Invoke-ClaudeRaw` を非同期読み取り・タイムアウト対応版に修正 |
| `scripts/maestro_runner.tests.ps1` | **更新** | G1-G7 をスタブ実行テストに置き換え |
| `src/main/resources/application.properties` | **更新** | v2.1.6 へバージョンアップ |
| `docs/handoff/P3_CC_Report/cycle_9.md` | **更新** | 本報告書（Take 11: Dex差し戻し全件対応） |
| `docs/TEAM_CHAT.md` | **更新** | CC Take 11 完了エントリ追加 |

---

## セルフQA（CLAUDE.md準拠）

1. **変更対象確認**: Take 11 の変更は上記5ファイルのみ。巻き添え変更なし。

2. **P1 Verification Plan 照合**:
   - Phase 0 Step 1-4（疎通テスト・最小権限）: `Invoke-ClaudeRaw` の非同期修正完了。Air による再実機確認待ち（Dex Stop Conditions 解除後）。
   - Phase 0 Step 5（課金確認）: Kazumax 手動確認待ち。
   - Phase 1 Step 1-4: 統合テスト PASS=35 確認。

3. **セキュリティ注記**: OneDrive 対応 `Test-ReparseInPath` は Take 10 から変更なし。Junction/Symlink 拒否・OneDrive プレースホルダー通過は継続維持。

4. **バージョン同期**: `application.properties` と `target/classes/application.properties` 両方 v2.1.6 確認。

5. **統合テスト**: PASS=35 / FAIL=0（F4 U+FFFD 0件も引き続き確認済み）。

---

## Dexへの確認事項

1. **G3 arg記録方式の妥当性**: `echo %*` でバッチの受け取り引数をファイルに記録し `--tools ""` を正規表現で検証している。OS 層で `""` が保持されていることの確認になっているか確認をお願いしたい。
2. **Phase 0 再実機確認（Air担当）**: `Invoke-ClaudeRaw` の非同期版で `--tools ''` が確実に渡ることを Air に再実機確認してもらう必要がある（Dex Stop Conditions 解除後）。
3. **課金確認**: Kazumax 手動確認待ち。確認完了まで「第0段階完了」とは記録しない。

---

## 現在のステータス

**Take 11: 実装完了。Dex（P4）レビュー待ち。**

Dex の Stop Conditions（`-Test` / `-TestResume` / `-Watch` 禁止・第2段階禁止・`maestro_loop.ps1` 禁止）は引き続き有効。
