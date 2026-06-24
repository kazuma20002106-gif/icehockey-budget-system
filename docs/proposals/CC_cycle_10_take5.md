# 提案: `--untracked-files=all` の性能影響と代替案

作成者: CC  
作成日: 2026-06-24  
対象: Take5の Fix3 で導入した `git status --porcelain --untracked-files=all`

## 背景

Take5 の Fix3 では、ディレクトリ単位（`?? src/`）ではなく個別ファイル（`?? src/foo.txt`）を列挙するために `--untracked-files=all` を追加した。これにより既存 dirty ファイルへの追記・変更を SHA-256 で正確に検知できる。

## 懸念点

`--untracked-files=all` は大規模リポジトリ（untracked ファイルが数千件以上）で遅くなる。本番 P1 実行時にリポジトリが大きくなった場合、baseline/after 両方の git status が数秒かかる可能性がある。

## 代替案

1. **現状維持**: 開発フェーズでは問題にならない規模なので、パフォーマンスに問題が出てから対応する（推奨）。

2. **対象ディレクトリを `git ls-files --others` で絞り込む**: `--exclude-standard` と組み合わせて特定のパスのみスキャン。実装が複雑になる。

3. **ディレクトリエントリを `Get-ChildItem -Recurse` で展開**: git status のディレクトリエントリを検知したら、PS 側でファイルを列挙してハッシュ計算。git との整合性が取りにくい。

## 結論

現状維持（案1）を推奨。パフォーマンス問題が顕在化したタイミングで案2を検討する。
