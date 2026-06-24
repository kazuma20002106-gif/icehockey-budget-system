# Cycle 10 Live Test: 異常系のみ実行結果（Dex）

## 結論

異常系テストは **PAUSE発動まで到達** しました。

ただし、Air手順書が期待していた
`automation_fail.txt` 作成 → 許可外差分検知 → PAUSE
ではなく、今回はその手前で **CC呼び出し60秒タイムアウト → PAUSE** になりました。

そのため、現時点の判定は以下です。

- 安全装置PAUSE: **機能している**
- 自動ロールバックなし: **守られている**
- `cc.done.json` 厳密フォーマット修正の実機確認: **未確認**
- 許可外差分検知の実機確認: **未確認**
- 正常系テスト: **未実行**

## 実行内容

Kazumax承認により、異常系のみ実行しました。

投入manifest:

- `docs/handoff/maestro/dummy_fail_r3.ready.json`

起動コマンド:

```powershell
.\scripts\maestro_runner.ps1 -Watch -TestPhase2
```

## 観測ログ

主なログ:

```text
[2026-06-25 06:39:25][INFO] manifest 処理開始: dummy_fail_r3.ready.json
[2026-06-25 06:39:25][INFO] 値・型バリデーション OK: cycle=dummy_fail, revision=3
[2026-06-25 06:39:26][INFO] SHA-256 一致 OK
[2026-06-25 06:39:26][INFO] 処理済みマーク: dummy_fail:r3 (validated)
[2026-06-25 06:39:26][INFO] CC(Claude Code) を自動起動します...
[2026-06-25 06:40:31][ERROR] CCプロセス呼び出し失敗: タイムアウト: claude が 60秒以内に終了しませんでした
[2026-06-25 06:40:31][PAUSE] PAUSE 自動生成: CC呼び出し失敗
```

## 現在の状態

- `docs/handoff/maestro/PAUSE`: **存在**
- `automation_fail.txt`: **存在しない**
- `cc.done.json`: **生成なし**
- `docs/handoff/P3_CC_Report/dummy_fail.md`: **生成なし**
- `docs/handoff/maestro/processed.log`: `dummy_fail:r3` が validated 済み
- Dexが起動した監視ランナー: **停止済み**
- 停止後に残った `maestro.lock`: **削除済み**

## 判断

今回の異常系は「安全に止まる」ことは確認できました。
しかし、本来見たかった「CCが完了出力した後にRunnerが不正差分を検知できるか」は、CCが60秒以内に完了しなかったため未検証です。

## 次に必要な対応案

CCまたはAirに確認・調整してほしい点:

1. `dummy_fail.md` の指示が、60秒以内に完了できるほど十分に短いか確認する。
2. 異常系テスト専用に、CCが最小出力だけで即完了するP1へ簡略化する。
3. それでも60秒を超える場合のみ、テスト用タイムアウト値を一時的に延長する案を検討する。
4. 再テスト時は `dummy_fail:r3` が処理済みのため、`revision: 4` 以上のmanifestを作成する。

## Dexの推奨

まずは **P1の簡略化 + revision 4化** を推奨します。

いきなりタイムアウトを伸ばすと、「CCが遅くても待てばよい」という方向に寄ってしまい、将来の自動運用で詰まりやすくなります。
異常系テストでは、CCに複雑な作業をさせず、最短で `automation_fail.txt` と `cc.done.json` を作らせる設計にした方が検証がきれいです。

