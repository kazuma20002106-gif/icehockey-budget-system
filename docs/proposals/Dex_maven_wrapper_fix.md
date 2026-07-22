# Dex提案 — Maven Wrapper起動問題の修正

## 提案

Dex環境で毎回発生している `Cannot index into a null array. Cannot start maven from wrapper` を解消するため、`mvnw.cmd` のPowerShell部分を修正する。

## 原因候補

`mvnw.cmd` 内で以下の判定がある。

```powershell
if ((Get-Item $MAVEN_M2_PATH).Target[0] -eq $null) {
  $MAVEN_WRAPPER_DISTS = "$MAVEN_M2_PATH/wrapper/dists"
} else {
  $MAVEN_WRAPPER_DISTS = (Get-Item $MAVEN_M2_PATH).Target[0] + "/wrapper/dists"
}
```

通常のディレクトリでは `.Target` が `$null` になり得るため、`.Target[0]` で `Cannot index into a null array` が発生する。

## 修正案

`Target` を一度変数に入れ、null/空配列の場合は通常パスを使う。

```powershell
$m2Item = Get-Item $MAVEN_M2_PATH
$m2Target = $m2Item.Target
if (!$m2Target -or $m2Target.Count -eq 0) {
  $MAVEN_WRAPPER_DISTS = "$MAVEN_M2_PATH/wrapper/dists"
} else {
  $MAVEN_WRAPPER_DISTS = $m2Target[0] + "/wrapper/dists"
}
```

## 期待効果

Dex環境でも `.\mvnw.cmd -q -DskipTests compile` を毎回実行できるようになり、P4レビュー時の「CC報告のみ」依存を減らせる。

## 注意

初回実行時にMaven distributionをダウンロードするため、ネットワーク制限がある環境では別途承認または既存Mavenキャッシュが必要。
