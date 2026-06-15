# CC提案 — Cycle 5.3

## 提案1: P2指示書に「removeShape代替手段」を必ず記載するルール

**背景**: 今回、P2が `drawing.removeShape(shape)` を指示したが、このPOIバージョンに `removeShape()` は存在せず、コンパイルエラーになった。CTDrawing経由の `removeTwoCellAnchor(i)` で解決したが1往復ロスが生じた。

**提案**: `XSSFDrawing` のメソッドを使う際は、P2作成時に事前にPOIバージョン確認を行い、実際に使えるAPIを明記する。もしくは「試す順序：まず高レベルAPI、失敗なら `getCTDrawing()` の低レベルAPIへフォールバック」をP2チェックリストに常時記載する。

## 提案2: CLAUDE.mdへの「CTDrawing代替パターン」追記

`clearExistingShapes()` のコードパターン（CTDrawing経由削除）は今後も再利用される可能性がある。CLAUDE.mdの「Excel帳票実装ルール」にPOI低レベルAPIのパターンをスニペットとして1箇所記載しておくと、CC・DexともにAPIを調べる時間を節約できる。

```java
// 低レベル図形削除パターン（removeShape()が使えない場合）
CTDrawing ctd = ((XSSFSheet) sheet).getDrawingPatriarch().getCTDrawing();
for (int i = ctd.sizeOfTwoCellAnchorArray() - 1; i >= 0; i--) {
    CTTwoCellAnchor anchor = ctd.getTwoCellAnchorArray(i);
    // ... 判定 ...
    ctd.removeTwoCellAnchor(i);
}
```
