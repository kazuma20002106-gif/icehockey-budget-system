# [C10: CC(P3)] Cycle 10 実機テスト診断対応 実装報告書

作成日: 2026-06-24
作成者: CC (Claude Code)
バージョン: v2.1.14
対象: `scripts/maestro_runner.ps1` / `scripts/maestro_runner.tests.ps1`

---

## 1. 対象と背景

Cycle 10 Phase 2 の実機テストで、実Claudeが `cc.done.json` に不正値を書き Maestro Runner がPAUSE停止しました。

```text
done.json.revision 不一致: 'revision_2' vs manifest '2'
done.json.result が許可値ではありません: 'sandbox_compliant'
```

Maestro Runner の安全装置は**正しく動作**しています（仕様違反を検知してPAUSE）。  
Dex 診断 (`docs/handoff/P4_Dex_Review/cycle_10_live_test_diagnosis.md`) の方針に従い、根本原因である「自動起動CCへの `cc.done.json` 契約の曖昧さ」をプロンプト側の小修正で解消しました。

---

## 2. 修正内容

### 2.1 `Invoke-ClaudeAgent` プロンプトに cc.done.json 厳密契約を明記

`scripts/maestro_runner.ps1` のプロンプト生成部に、`cc.done.json` の各フィールドの厳密な値規則と完成形JSONテンプレートを追加しました。

**追加した契約**:
- `cycle`: manifestの cycle と完全一致
- `revision`: **manifestの revision と完全一致。数値のみ。`revision_2` / `r2` のような文字列・接頭辞付きは禁止**
- `source_p1_sha256`: P1ファイルのSHA-256（**プロンプト生成時に事前計算して直接埋め込み**、曖昧さを排除）
- `p3_file`: 相対パス文字列
- `p3_sha256`: 実際に作成したP3のSHA-256（小文字）
- `completed_at`: ISO 8601 + タイムゾーン
- `result`: **必ず `"success"`。`sandbox_compliant` / `ok` / `done` 等の独自値は一切禁止**

さらに、`<...>` 部分だけ埋めれば完成する **JSONテンプレート全文** をプロンプトに埋め込みました。

### 2.2 安全監査(git)の実行順序を是正（副次的な堅牢化）

P1のSHA-256事前計算を追加したことに伴い、処理順序を以下に整理しました。

1. **git status 安全監査**（失敗時は即PAUSE）
2. **P1ファイル存在チェック**（不在ならPAUSE）
3. P1のSHA-256計算 → プロンプト生成

これにより、git監査という安全ゲートを最優先で通すようになり、P1不在時も無言終了せず確実にPAUSEします（従来は `Get-FileHash` がEAP=Stopで例外→無言離脱する経路がありました）。

---

## 3. 追加・修正テスト

| テスト | 内容 | 結果 |
|--------|------|------|
| H9 | git status 失敗時PAUSE（実行順序是正後も維持） | PASS |
| H14 | プロンプトに revision数値・result success・禁止例(revision_2/sandbox_compliant)・P1ハッシュが含まれる | PASS |
| H14(b) | 契約強化後も正常完了しPAUSEなし | PASS |

全テスト: **PASS=54 FAIL=0**

---

## 4. テスト実行コマンド

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\maestro_runner.tests.ps1
```

---

## 5. 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|----------|----------|------|
| `scripts/maestro_runner.ps1` | 修正 | done.json厳密契約をプロンプトに明記・git監査順序是正・P1不在チェック追加 |
| `scripts/maestro_runner.tests.ps1` | 修正 | H14テスト追加 |
| `src/main/resources/application.properties` | バージョン更新 | v2.1.13 → v2.1.14 |

---

## 6. 次回実機テスト時の注意（Dex診断より）

- `test_automation:r2` は `processed.log` に記録済み → 同じrevisionは再利用せず revision を上げること。
- `dummy_success.md` / `dummy_fail.md` が存在しない状態でmanifestを投入しないこと（P1→SHA-256→manifest→.ready.json の順序厳守）。
- 実Claude自動起動は Kazumax 承認後に1ケースずつ実行すること。

---

## 7. Stop Conditions 遵守確認

- `git reset --hard` / `git restore .` / `git clean` の自動実行: **なし**
- 実 Claude 自動起動 (`-Watch -TestPhase2`): **実施していない**（外部通信なしスタブのみ）
- 本番 P1 での自動起動: **なし**
- 第3段階への進行: **なし**
- ANTHROPIC_API_KEY の設定・変更: **なし**
