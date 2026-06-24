# Cycle 10 実機確認手順書（改訂版）

今回は、Dexの修正（cc.done.json出力のフォーマット厳格化・revision整合性担保）が正しく機能するかを、**「意図的な異常系（PAUSE発動）」**と**「正常系（完走）」**の2つに分けて確認します。

## 事前準備（環境リセット）
前回のPAUSEファイルが残っている場合はリセットします。現在RunnerのPAUSE待機ループが動いているターミナルはそのまま起動しておいてください。

別のPowerShellターミナルを開き、以下を実行します。
```powershell
cd C:\Users\kazum\OneDrive\デスクトップ\フォルダー\アイスホッケー書類関連\budget-system
Remove-Item docs\handoff\maestro\PAUSE -ErrorAction SilentlyContinue
```
*(※すでに私が実行してPAUSEを解除済みですが、もし再度PAUSEメッセージが出ている場合は実行してください)*

> [!WARNING]
> **OneDriveの警告について:**
> テスト中に大量のファイル操作（作成・削除・隔離・sandboxの初期化）が発生するため、OneDriveから「大量のファイルが削除されました」という警告が出ることがあります。その際は必ず**「保持する」**を選択してください。

---

## 🟢 テストケース 1: 異常系（PAUSE発動の確認）

安全装置（防衛線）が確実に稼働することを確認するための意図的な失敗テストです。

### 1. P1ファイルとmanifestの準備（Airが完了済み！）
本来は `P1作成` → `SHA-256取得` → `manifestへ記入` という順序を踏みますが、**今回は私がすでに以下のファイルを作成し、ハッシュ値も計算して `revision: 4` のmanifestを用意しました！**
- `docs/handoff/P1_Air_Blueprint/dummy_fail.md`
- `docs/handoff/maestro/test_manifests/dummy_fail_r4.ready.json`

### 2. テストの実行（Kazumaxの操作）
ターミナルに以下をコピペして実行してください。
```powershell
Copy-Item docs\handoff\maestro\test_manifests\dummy_fail_r4.ready.json docs\handoff\maestro\
```

**✅ 期待する結果（成功）**
- CCが `automation_fail.txt` を作成する。
- 終了後、Runnerが許可外のパスへの変更（`git diff`）を検知する。
- `PAUSE 自動生成: CC異常終了 または 不正差分検知。自動ロールバックはしません。` と表示され、処理が停止することを確認できれば**大成功**です！

### 3. 次のテストへの復旧作業
異常系の確認が取れたら、以下のコマンドで不正に作られたファイルとPAUSEを消去します。
```powershell
Remove-Item automation_fail.txt -ErrorAction SilentlyContinue
Remove-Item docs\handoff\maestro\PAUSE -ErrorAction SilentlyContinue
```

---

## 🟢 テストケース 2: 正常系（完全完走の確認）

### 1. P1ファイルとmanifestの準備（Airが完了済み！）
こちらも私がすでに用意しています。
- `docs/handoff/P1_Air_Blueprint/dummy_success.md`
- `docs/handoff/maestro/test_manifests/dummy_success_r4.ready.json`

### 2. テストの実行（Kazumaxの操作）
異常系の復旧が終わった状態で、ターミナルに以下をコピペして実行してください。
```powershell
Copy-Item docs\handoff\maestro\test_manifests\dummy_success_r4.ready.json docs\handoff\maestro\
```

**✅ 期待する結果**
- CCが起動し、製品コードには一切触れず、P3レポートと正しいフォーマット（`revision: 4`, `result: "success"`）の `cc.done.json` を出力して終了する。
- Runnerがそれを「合格」と判定し、PAUSEを出すことなく `dummy_success/revision_4/` へ処理済みファイルを移動させてクリーンに終了する。
- ターミナルに `サイクル処理完了` が表示されれば**大成功**です！
