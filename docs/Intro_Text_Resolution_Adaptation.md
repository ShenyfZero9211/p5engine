# 片头文字分辨率自适应技术文档

> 文档版本: 1.0  
> 适用版本: p5engine 0.9.8+  
> 创建时间: 2026-05-05

---

## 1. 概述

本文档记录 p5engine 片头系统（Intro System）中文字渲染从**固定像素大小**演进为**基于设计分辨率动态自适应**的完整过程，包括问题分析、方案设计、实现细节以及踩坑记录。

**核心结论**：引擎层自定义渲染器（不经过 UI 框架的 `UIManager`）若希望文字/图形在不同分辨率下保持视觉一致性，必须手动实现与设计分辨率挂钩的缩放计算，不能依赖 FIT 矩阵的自动缩放。

---

## 2. 问题背景

### 2.1 片头系统的渲染位置

片头序列 (`IntroSequence`) 在 `TdAppLoop.run()` 的最开头渲染，**早于**全局 FIT 缩放矩阵的 `pushMatrix/translate/scale`：

```java
// TdAppLoop.run() — 片头渲染在 FIT 矩阵之前
shenyf.p5engine.intro.IntroSequence intro = app.engine.getIntroSequence();
if (intro != null && !intro.isComplete()) {
    app.background(0);
    intro.update(dtReal);
    intro.render(app);   // ← 此时没有 pushMatrix/scale 包裹
    ...
    return;
}

// 之后才是 UI 层的 FIT 缩放
app.pushMatrix();
app.translate(dm.getOffsetX(), dm.getOffsetY());
app.scale(dm.getUniformScale(), dm.getUniformScale());
// ... UI 渲染
app.popMatrix();
```

### 2.2 固定字号的视觉问题

`FadeTextSegment` 最初使用固定字号 `textSize = 72`：

| 实际分辨率 | 物理像素字号 | 相对 720p 比例 | 视觉效果 |
|-----------|------------|--------------|---------|
| 1280×720 | 72px | 1.0× | ✅ 适中 |
| 1920×1080 | 72px | 0.67× | ❌ 偏小 |
| 3840×2160 | 72px | 0.33× | ❌ 极小 |
| 800×600 | 72px | 1.2× | ❌ 偏大 |

在 4K 屏幕上，72px 的文字几乎看不清；在低分辨率屏幕上又显得过于臃肿。

---

## 3. 根因分析

### 3.1 为什么 UI 框架中的文字能自适应？

p5engine 的 UI 框架 (`UIManager`) 通过以下机制实现分辨率自适应：

1. `UIManager` 的 `render()` 被包裹在全局 FIT 缩放矩阵中
2. 所有 Panel/Label/Button 的坐标和尺寸都是**设计坐标**（基于 1280×720）
3. `DisplayManager` 计算 `uniformScale = min(actualW/designW, actualH/designH)`
4. OpenGL 的 `scale(uniformScale)` 将整个 UI 层统一放大/缩小

因此，UI 框架中的 `theme.setFontSize(14)` 虽然在设计分辨率下是 14px，但在 1080p 下会被 OpenGL 自动放大到 21px，视觉上始终保持一致。

### 3.2 为什么片头文字不能自适应？

片头渲染器 `FadeTextSegment` 是一个**独立的引擎层组件**，不通过 `UIManager` 渲染。它的 `render(PApplet g)` 直接在原始画布坐标系中绘制：

```java
// FadeTextSegment.render() — 直接操作 PApplet，无 FIT 矩阵
g.textSize(72);           // ← 72 物理像素，不会被任何矩阵缩放
g.text("SharpEye Presents", cx, cy);
```

由于渲染发生在 FIT 矩阵之前，OpenGL 不会对文字进行任何缩放，导致字号在不同分辨率下固定不变。

### 3.3 两种渲染路径对比

| 特性 | UI 框架渲染 | 独立渲染器（片头） |
|------|-----------|------------------|
| 坐标系 | 设计坐标（1280×720） | 物理像素坐标 |
| 缩放方式 | `pushMatrix/scale` 全局缩放 | 无自动缩放 |
| 文字大小 | 设计字号 × `uniformScale` | 固定物理像素 |
| 分辨率自适应 | ✅ 自动 | ❌ 需手动实现 |

---

## 4. 解决方案

### 4.1 设计思路

将 `FadeTextSegment` 中传入的 `textSize` 定义为**设计分辨率下的字号**，在 `render()` 时根据实际窗口尺寸与设计分辨率的比例动态计算实际字号：

```
actualTextSize = designTextSize × min(actualWidth / designWidth, actualHeight / designHeight)
```

这与 `DisplayManager` 的 FIT 缩放计算完全一致，确保文字缩放比例与 UI 层同步。

### 4.2 核心代码

```java
// FadeTextSegment.render() — 分辨率自适应
float designW = 1280f;
float designH = 720f;
float fitScale = Math.min(g.width / designW, g.height / designH);
float actualTextSize = textSize * fitScale;

g.textSize(actualTextSize);
```

### 4.3 不同分辨率下的效果

| 实际分辨率 | `fitScale` | `actualTextSize` (设计值=72) | 视觉效果 |
|-----------|-----------|------------------------------|---------|
| 1280×720 | 1.00 | 72px | ✅ 与设计一致 |
| 1920×1080 | 1.50 | 108px | ✅ 与 UI 同比例放大 |
| 2560×1440 | 2.00 | 144px | ✅ 与 UI 同比例放大 |
| 3840×2160 | 3.00 | 216px | ✅ 与 UI 同比例放大 |
| 2560×1080 (21:9) | 1.50 | 108px | ✅ 按高度 FIT，与 UI 一致 |
| 1280×960 (4:3) | 1.00 | 72px | ✅ 按宽度 FIT，黑边区域无内容 |

---

## 5. 实现细节

### 5.1 完整 render() 方法中的自适应部分

```java
@Override
public void render(PApplet g) {
    if (!active) return;

    g.noStroke();
    g.fill(bgColor);
    g.rect(0, 0, g.width, g.height);

    if (elapsed < delay) return;
    float effectiveTime = elapsed - delay;
    if (effectiveTime > totalDuration) return;

    float cx = g.width * 0.5f;
    float cy = g.height * 0.5f;

    // ---- 分辨率自适应 ----
    float designW = 1280f;
    float designH = 720f;
    float fitScale = Math.min(g.width / designW, g.height / designH);
    float actualTextSize = textSize * fitScale;
    // ---------------------

    g.textSize(actualTextSize);
    float lineH = actualTextSize * lineSpacing;
    float blockH = lines.length * lineH;
    float startY = cy - blockH * 0.5f + lineH * 0.5f;

    for (int li = 0; li < lines.length; li++) {
        float lineTime = effectiveTime - lineStartTimes[li];
        if (lineTime < 0) continue;

        String line = lines[li];
        if (line.isEmpty()) continue;

        float lineY = startY + li * lineH;
        // ... 逐字动画渲染（使用 actualTextSize 计算的所有尺寸）
    }
}
```

### 5.2 关键注意事项

**1. 测量必须在设置 textSize 之后**

```java
g.textSize(actualTextSize);  // 必须先设置，否则 textWidth() 返回错误值
float totalW = 0;
for (...) {
    totalW += g.textWidth(line.substring(ci, ci + 1));
}
```

**2. 所有基于字号的衍生值必须使用 `actualTextSize`**

```java
// 行高、起始 Y、字符宽度等全部用 actualTextSize
float lineH = actualTextSize * lineSpacing;
float startY = cy - blockH * 0.5f + lineH * 0.5f;
```

**3. 动画缩放因子与分辨率缩放是乘法关系**

片头文字还有独立的动画缩放（匀速推近效果）：

```java
float baseScale = 0.6f + 0.03f * lineStartTimes[li];
float lineScale = baseScale + 0.03f * lineTime;

g.pushMatrix();
g.translate(cx, lineY);
g.scale(lineScale);     // ← 动画缩放
g.translate(-cx, -lineY);
// 文字在动画缩放基础上，已经被 g.textSize(actualTextSize) 放大了
// 总效果 = actualTextSize × lineScale
```

这两个缩放是**正交的**：
- `actualTextSize` — 分辨率适配（静态，每帧根据窗口大小重新计算）
- `lineScale` — 动画效果（动态，随时间线性变化）

---

## 6. 踩坑记录

### 坑 1：修改引擎源码后未复制 jar 到示例工程

**现象**：修改 `FadeTextSegment.java` 后编译引擎通过，但运行示例时文字大小没有任何变化。

**原因**：Processing 示例工程（PDE）运行时加载的是示例目录 `code/` 下的 `p5engine.jar`，而非引擎根目录 `library/` 下的 jar。

**根目录结构**：
```
p5engine/
├── library/
│   └── p5engine.jar          ← compile-jar.ps1 输出
└── examples/
    └── TowerDefenseMin2/
        └── code/
            └── p5engine.jar  ← 示例实际运行时加载的 jar
```

**解决方案**：每次修改引擎源码后，必须执行：

```powershell
Copy-Item -Path "library\p5engine.jar" -Destination "examples\TowerDefenseMin2\code\p5engine.jar" -Force
```

**建议**：在 `compile-jar.ps1` 中考虑增加 `-CopyToExamples` 参数，或在 AGENTS.md 中强化这一要求的提醒级别。

### 坑 2：textWidth() 在 pushMatrix/scale 内部的抖动问题

在修复分辨率自适应之前，还存在一个导致文字"一卡一卡"的独立问题：

**错误代码**：
```java
g.pushMatrix();
g.scale(lineScale);
// ...
float charW = g.textWidth(ch);  // ← 在缩放坐标系中调用！
```

`textWidth()` 在 `pushMatrix/scale` 内部调用时，返回值会被 `lineScale` 放大。由于 `lineScale` 每帧都在线性增大（`0.03/s`），字符中心点 `charCx` 每帧都有微小浮动，导致视觉抖动。

**修复**：所有 `textWidth()` 调用必须在 `pushMatrix` 之前完成：

```java
// 在 pushMatrix 之前预计算所有字符中心点
float[] charCenterX = new float[line.length()];
float totalW = 0;
for (int ci = 0; ci < line.length(); ci++) {
    totalW += g.textWidth(line.substring(ci, ci + 1));
}
float offsetX = cx - totalW * 0.5f;
float acc = 0;
for (int ci = 0; ci < line.length(); ci++) {
    String ch = line.substring(ci, ci + 1);
    float w = g.textWidth(ch);
    charCenterX[ci] = offsetX + acc + w * 0.5f;
    acc += w;
}

g.pushMatrix();
g.scale(lineScale);
// 绘制时直接使用预计算的 charCenterX，不再调用 textWidth()
```

---

## 7. 通用最佳实践

### 7.1 独立渲染器的分辨率自适应 checklist

对于任何不经过 `UIManager` 的自定义渲染器（片头、特效、覆盖层等），若需要文字或图形在不同分辨率下保持一致的视觉比例，请检查：

| 检查项 | 正确做法 | 错误做法 |
|--------|---------|---------|
| 字号 | `g.textSize(designSize * fitScale)` | `g.textSize(fixedPixelSize)` |
| 图形尺寸 | `rect(x*fitScale, y*fitScale, w*fitScale, h*fitScale)` | `rect(x, y, w, h)` |
| 坐标定位 | 基于 `g.width/g.height` 动态计算 | 硬编码固定像素值 |
| 行间距 | `lineHeight = designLineHeight * fitScale` | 固定像素行间距 |
| textWidth 测量 | 在 `pushMatrix/scale` 之前 | 在 `pushMatrix/scale` 内部 |

### 7.2 FIT 缩放因子的复用

如果渲染器能访问 `DisplayManager`，可以直接复用 `uniformScale`：

```java
DisplayManager dm = engine.getDisplayManager();
float fitScale = dm.getUniformScale();
float actualTextSize = designTextSize * fitScale;
```

如果渲染器是纯引擎层组件（如 `FadeTextSegment`），无法访问 `DisplayManager`，则手动计算：

```java
float fitScale = Math.min(g.width / designW, g.height / designH);
```

两者计算结果完全一致。

### 7.3 设计分辨率常量管理

建议将设计分辨率作为引擎常量统一管理，避免散落在各处的魔法数字：

```java
// 建议新增：
public class DisplayConfig {
    public static final float DEFAULT_DESIGN_WIDTH = 1280f;
    public static final float DEFAULT_DESIGN_HEIGHT = 720f;
}
```

当前 `FadeTextSegment` 中硬编码了 `1280f` 和 `720f`，未来如果设计分辨率变更，需要同步修改。考虑在引擎层暴露这些常量供各模块引用。

---

## 8. 相关文件

| 路径 | 说明 |
|------|------|
| `src/main/java/shenyf/p5engine/intro/FadeTextSegment.java` | 片头文字片段（核心修改文件） |
| `src/main/java/shenyf/p5engine/intro/IntroSegment.java` | 片头片段接口 |
| `src/main/java/shenyf/p5engine/intro/IntroSequence.java` | 片头队列管理器 |
| `src/main/java/shenyf/p5engine/core/P5Engine.java` | 引擎核心（片头集成） |
| `examples/TowerDefenseMin2/TdAppCore.pde` | 游戏主循环（片头调用方） |
| `examples/TowerDefenseMin2/code/p5engine.jar` | 示例运行时加载的引擎 jar |

---

## 9. 总结

| 要点 | 说明 |
|------|------|
| **问题** | 片头文字使用固定像素字号，在不同分辨率下视觉比例不一致 |
| **根因** | 片头渲染在全局 FIT 矩阵之前，无法享受 UI 框架的自动缩放 |
| **方案** | 在 `render()` 中按 `min(actualW/1280, actualH/720)` 动态缩放字号 |
| **关键** | 所有基于字号的衍生值（行高、测量、位置）必须使用缩放后的实际值 |
| **教训** | 修改引擎后必须同步复制 jar 到示例工程的 `code/` 目录 |
| **扩展** | 该方案适用于所有不经过 UIManager 的独立渲染器 |
