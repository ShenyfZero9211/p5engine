# Label 文本渲染对齐修复记录

## 问题描述
`DefaultTheme.drawLabel()` 使用 `g.text(str, x, y, w, h)` 矩形框模式 + `textAlign(..., CENTER)` 时，中文和数字混排的文本不在同一水平线上。中文在正确位置，但数字/英文会偏移。

## 根本原因
Processing 的矩形文本框模式 `g.text(str, x, y, w, h)` 对 `textAlign(horizontal, CENTER)` 的垂直中心计算基于字体行高（line height），不同字符（中文 vs 数字）的字形度量（ascent/descent）不同，导致混排时视觉基线不一致。

## 修复方案
改为单行 `BASELINE` 对齐模式，手动通过 `textAscent()` / `textDescent()` 计算视觉中心，确保所有字符共享同一基线。

## 代码对比

### 原代码（矩形框模式）
```java
@Override
public void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled, int textAlign) {
    g.fill(a(disabled ? TEXT_DIM : TEXT));
    g.noStroke();
    g.textAlign(textAlign, PApplet.CENTER);
    g.textSize(Math.min(14, h * 0.5f));
    g.text(text != null ? text : "", x, y, w, h);
}
```

### 修复后代码（单行 BASELINE 模式）
```java
@Override
public void drawLabel(PApplet g, float x, float y, float w, float h, String text, boolean disabled, int textAlign) {
    g.fill(a(disabled ? TEXT_DIM : TEXT));
    g.noStroke();
    g.textSize(Math.min(14, h * 0.5f));
    float tx;
    if (textAlign == PApplet.CENTER) {
        tx = x + w * 0.5f;
    } else if (textAlign == PApplet.RIGHT) {
        tx = x + w - 4;
    } else {
        tx = x + 4;
    }
    g.textAlign(textAlign, PApplet.BASELINE);
    float ty = y + h * 0.5f + (g.textAscent() - g.textDescent()) * 0.5f;
    g.text(text != null ? text : "", tx, ty);
}
```

## 关键变更点
| 项目 | 原代码 | 修复后 |
|------|--------|--------|
| 绘制模式 | 矩形框 `g.text(str, x, y, w, h)` | 单行 `g.text(str, tx, ty)` |
| 垂直对齐 | `CENTER` | `BASELINE` |
| 水平 x 计算 | 由 `textAlign` 自动处理 | 手动根据 `textAlign` 计算 `tx` |
| 垂直 y 计算 | 由矩形框自动居中 | `ty = y + h/2 + (ascent - descent)/2` |

## 影响范围
- 所有使用 `Label` 组件的 UI 文本渲染
- 包括：`TdTopBar` 的状态栏、时间、速度、下一波倒计时等 Label

## 恢复方法
如需恢复原来的矩形框模式，将 `DefaultTheme.java` 的 `drawLabel` 方法替换回上面的"原代码"即可，然后重新编译 `p5engine.jar`。

## 相关文件
- `src/main/java/shenyf/p5engine/ui/DefaultTheme.java`
