# P2D 模式下 ScrollPane 多行文本渲染技术总结

> 适用项目：`TowerDefenseMin2` 简报界面  
> 引擎版本：p5engine (Processing 4.5.2, P2D, JOGL/OpenGL)  
> 文档日期：2026-05-12  
> 关联文件：`examples/TowerDefenseMin2/TdFlow.pde`、`TdAppCore.pde`

---

## 1. 需求背景

`TowerDefenseMin2` 的关卡简报界面需要在 P2D 渲染器下显示一段多行中文文本（含 CJK/英文混排），并支持垂直滚动浏览。文本区域嵌入在引擎的 `ScrollPane` 组件内，窗口尺寸 780×450，位于 1280×720 的游戏画面中。

核心约束：
- **渲染器锁定为 P2D**（JOGL/OpenGL 后端），不可回退到 JAVA2D
- **支持 125% Windows DPI 缩放**（`System DPI scale detected: 1.25`）
- **中文字体**（Microsoft YaHei），字号 20px，需要清晰无模糊
- **滚动时文本必须严格裁剪**，不能溢出 ScrollPane 边界

---

## 2. 问题总览

在实现过程中，按顺序遇到以下 4 类问题：

| # | 问题 | 现象 | 根因 |
|---|------|------|------|
| 1 | 缺字/空白字符 | 简报文本中大量汉字显示为空白方框或完全缺失 | `createFont(charset)` 的字符集限制导致 PFont 纹理分配错误 |
| 2 | `clip()` 失效 | 使用 `applet.clip()` 后文本完全不显示 | P2D 的 `clip()` 映射到 `glScissor`，与 `text()` 的纹理渲染管线冲突 |
| 3 | 离屏缓冲拉伸 | 滚动时文字内容不变，垂直方向被拉长 | `image()` 9 参数重载在 PDE 预处理器下发生歧义 |
| 4 | 离屏缓冲闪烁 | 滚动时背景亮白闪烁 | `PGraphics.get()` 每帧触发 `glReadPixels`，GPU-CPU 同步延迟 |
| 5 | 逐行绘制溢出 | 文本在 ScrollPane 上下边界外各溢出约一行 | 宽松裁剪条件（部分可见即绘制）导致整行溢出 |

---

## 3. 方案演进与逐一排除

### 3.1 初始方案：JAVA2D 离屏预渲染

早期代码在 `showBriefing()` 中使用 `createGraphics(w, h, JAVA2D)` 预先渲染文本为 `PImage`，再贴到 P2D 主画布上。

```java
// 早期代码（已废弃）
PGraphics pg = createGraphics((int)contentW, (int)textH, JAVA2D);
pg.beginDraw();
pg.text("...", 0, y);
pg.endDraw();
```

**失败原因**：Processing 4.5.2 在 P2D 模式下混合 JAVA2D `PGraphics` 会出现不可预期的渲染错误（纹理格式不匹配、上下文切换失败），在 125% DPI 下表现为图像空白或色彩错乱。

---

### 3.2 方案二：P2D 离屏缓冲 + `image()` 9 参数

改用 P2D `createGraphics(w, h, P2D)` 创建离屏缓冲，每帧用 `image(img, dx, dy, dw, dh, sx, sy, sw, sh)` 截取可见区域贴到主画布。

```java
// BriefingText.paint() — 第二版（已废弃）
applet.image(offscreen, ax, ay + localTop, getWidth(), srcH,
             0, srcY, (int)getWidth(), srcH);
```

**现象**：文字正常显示，但滚动时**不移动，而是垂直拉伸**。

**根因分析**：Processing Java API 中存在两个 9 参数 `image()` 重载：
```java
// 重载 A：source 为 (sx, sy, sw, sh)
void image(PImage, float dx, float dy, float dw, float dh,
           int sx, int sy, int sw, int sh);

// 重载 B：source 为 (sx1, sy1, sx2, sy2)
void image(PImage, float dx, float dy, float dw, float dh,
           float sx1, float sy1, float sx2, float sy2);
```

PDE 预处理器在处理 `image(offscreen, ax, ay+localTop, getWidth(), srcH, 0, srcY, (int)getWidth(), srcH)` 时，可能将末尾的 `int` 参数提升为 `float`，导致实际调用的是**重载 B**。此时 `sy2 = srcH`，source 高度 = `sy2 - sy1 = srcH - srcY`，而 destination 高度 = `dh = srcH`。当 `srcY > 0`（滚动中）时，`srcH - srcY ≠ srcH`，产生垂直拉伸。

---

### 3.3 方案三：`offscreen.get()` 提取子图

为了避免 `image()` 重载歧义，改用 `offscreen.get(sx, sy, sw, sh)` 提取可见区域为 `PImage`，再用 3 参数 `image()` 绘制。

```java
// BriefingText.paint() — 第三版（已废弃）
PImage visible = offscreen.get(0, srcY, (int)getWidth(), srcH);
applet.image(visible, ax, ay + localTop);
```

**现象**：滚动正常，但背景出现**亮白色闪烁**。

**根因分析**：`PGraphicsOpenGL.get()` 底层调用 `glReadPixels`，将 FBO 像素从 GPU 显存读回 CPU 内存。每帧执行此操作会导致：
1. GPU 流水线 stall（等待读取完成）
2. CPU-GPU 同步延迟，与 OpenGL 双缓冲交换冲突
3. 表现为背景亮白闪烁（读取到的像素 alpha 通道或未初始化的背景色被错误混合）

---

### 3.4 方案四：手动纹理四边形

绕过 `image()`，直接用 `beginShape(QUADS)` + `texture()` + `vertex()` 手动贴图。

```java
// BriefingText.paint() — 第四版（已废弃）
applet.beginShape(PApplet.QUADS);
applet.texture(offscreen);
// ... uv 坐标计算 ...
applet.vertex(ax, ay + localTop, u0, v0);
applet.vertex(...);
applet.endShape();
```

**现象**：**文本完全不显示**，且仍有闪烁。

**根因分析**：`texture()` 在 P2D 下对 `PGraphics`（FBO 纹理）的支持有特殊要求（需要 `loadPixels()` 或特定状态标记）。`PGraphicsOpenGL` 作为动态纹理，在未正确绑定或格式不匹配时，`beginShape/texture` 无法采样到有效像素。

---

### 3.5 方案五：逐行判断 + 宽松裁剪

彻底放弃离屏缓冲，直接在主画布上逐行绘制，用宽松条件判断可见性。

```java
// BriefingText.paint() — 第五版（已废弃）
float viewTop = clipTop;
float viewBottom = clipBottom;
float y = ay + 4;
for (String line : wrappedLines) {
    if (y + lineHeight > viewTop && y < viewBottom) {
        applet.text(line, ax + 4, y);
    }
    y += lineHeight;
}
```

**现象**：不闪烁，文字正常滚动，但**上下边界各溢出约一行**。

**根因分析**：条件 `y + lineHeight > viewTop && y < viewBottom` 的含义是"只要行与可视区域有任何重叠，就整行绘制"。由于 P2D 下 `clip()` 不可用，部分位于可视区域外的行也会被**完整绘制**出来：
- 顶部：某行底部刚露出一小截（`y + lineHeight > viewTop`），整行从 `y`（可能在 `viewTop` 上方 30px）开始绘制
- 底部：某行顶部刚露出一小截（`y < viewBottom`），整行绘制到 `y + lineHeight`（可能在 `viewBottom` 下方 30px）

溢出量恰好接近 `lineHeight`（本例中为 34px，即"一行"）。

---

### 3.6 最终方案：逐行判断 + 严格裁剪

将可见性条件收紧为**整行完全位于可视区域内**才绘制。

```java
// BriefingText.paint() — 最终版 ✅
void paint(PApplet applet, Theme theme) {
    if (wrappedLines == null || wrappedLines.length == 0) return;

    float ax = getAbsoluteX();
    float ay = getAbsoluteY();
    float viewTop = clipTop;       // 由 ScrollPane 传播
    float viewBottom = clipBottom; // 由 ScrollPane 传播

    applet.pushStyle();
    if (font != null) applet.textFont(font);
    applet.textSize(fontSize);
    applet.textAlign(LEFT, TOP);
    applet.fill(textColor);
    applet.noStroke();

    float y = ay + 4; // 上 padding
    for (String line : wrappedLines) {
        // 严格裁剪：仅当整行完全落在 ScrollPane 可视区域时才绘制
        if (y >= viewTop && y + lineHeight <= viewBottom) {
            applet.text(line, ax + 4, y);
        }
        y += lineHeight;
    }
    applet.popStyle();
}
```

**效果**：
- ✅ 文字清晰，无模糊
- ✅ 滚动流畅，无闪烁
- ✅ 严格限制在 ScrollPane 边界内，无溢出
- ✅ 无离屏缓冲，每帧直接绘制，内存开销最小

**副作用**：ScrollPane 的顶部和底部边缘在滚动时会出现"半行空白"（因为部分进入视野的行被隐藏了）。对于纯文本滚动场景，这是可接受的视觉折中。

---

## 4. 关键技术原理

### 4.1 为什么 `clip()` 与 P2D `text()` 不兼容

Processing P2D 的 `clip()` 映射为 OpenGL `glScissor`：
```
glScissor((int)x, (int)y, (int)w, (int)h)
```

该坐标使用**屏幕像素空间**，不经过 `pixelDensity` 缩放，也不应用 FIT 模式的变换矩阵。而 `text()` 在 P2D 下通过**纹理四边形**渲染字体位图，其顶点坐标处于**逻辑/设计坐标空间**（经 `uniformScale` 和 `offset` 变换后）。

结果：`glScissor` 截断的区域与 `text()` 实际绘制区域在空间上错位，且 `glScissor` 会截断字体纹理四边形的几何，导致文字完全不显示或残缺的像素级 artifact。

### 4.2 `createFont(charset)` 的字符集陷阱

早期代码：
```java
char[] briefingChars = TdAssets.collectBriefingChars();
PFont cnFontBriefing = createFont("Microsoft YaHei", fontSizeBriefing, true, briefingChars);
```

Processing 的 `createFont(name, size, smooth, charset)` 会根据 `charset` 预先生成字形纹理图集（glyph atlas）。在 P2D 模式下，如果字符集包含大量 CJK 字符，纹理图集可能超出 GPU 纹理尺寸限制或分配失败，导致部分字形映射为空，显示为空白。

**修复**：移除 `charset` 参数，让 Processing 使用动态字形缓存：
```java
PFont cnFontBriefing = createFont("Microsoft YaHei", fontSizeBriefing, true);
```

### 4.3 `clipTop` / `clipBottom` 的传播机制

引擎 UI 框架中，`ScrollPane.paint()` 计算内容区域的绝对坐标后，通过 `viewport.setClipBounds(iy, iy + ih)` 设置裁剪边界。`Container.paintChildren()` 将父容器的 `clipTop`/`clipBottom` 传播给所有子组件：

```java
// Container.java
protected void paintChildren(PApplet applet, Theme theme) {
    for (UIComponent c : sorted) {
        if (c.isVisible()) {
            c.setClipBounds(clipTop, clipBottom);
            c.paint(applet, theme);
            c.clearClipBounds();
        }
    }
}
```

`BriefingText` 因此可以直接读取 `this.clipTop` 和 `this.clipBottom`，获得 ScrollPane 内容区域的**屏幕绝对坐标**，无需自己遍历父组件链计算。

**注意**：`ScrollPane.getAbsoluteY()` 已经通过 `UIComponent.getAbsoluteY()` 的递归计算（含 `getContentOffsetY()` 和 root 的 `-ox/-oy` FIT 偏移）得出正确值，因此 `clipTop`/`clipBottom` 在 125% DPI 和 FIT 缩放下均准确。

### 4.4 PDE 预处理器与 `image()` 重载

PDE 预处理器将 `.pde` 转换为 `.java` 时，对数值字面量不做显式类型标注。在调用 `image(PImage, float, float, float, float, int, int, int, int)` 时，若参数是 `int` 变量，Java 编译器本可正确匹配。但在某些 PDE 预处理路径中，末尾参数可能被统一提升为 `float`，导致绑定到 `(float, float, float, float)` 的 source 坐标版本，引发坐标语义错误。

**教训**：在 PDE 中避免使用存在 `int`/`float` 歧义的重载方法处理关键渲染路径。

---

## 5. 最终架构

```
ScrollPane (780×450)
└── viewport (Container)
    └── BriefingText (contentW × actualH)
        ├── measure()      // 逐字 textWidth() 折行，缓存 wrappedLines
        └── paint()        // 逐行严格裁剪绘制，无 offscreen，无 clip()
```

**数据流**：
1. `TdFlow.showBriefing()` 创建 `BriefingText`，传入文本、字体、字号、颜色
2. `bt.measure(app)` 进行折行计算，设置组件尺寸
3. `bt` 被加入 `ScrollPane` 的 `viewport`
4. 每帧 `ScrollPane.paint()` → `viewport.setClipBounds(iy, iy+ih)` → `BriefingText.paint()` 读取 `clipTop`/`clipBottom`，只绘制完全可见的行

---

## 6. 关键结论

| 方案 | 是否可行 | 核心障碍 |
|------|---------|---------|
| JAVA2D 离屏缓冲 | ❌ | P2D 与 JAVA2D 上下文不兼容 |
| P2D 离屏 + `image()` 9参数 | ❌ | PDE 重载歧义导致拉伸 |
| P2D 离屏 + `get()` | ❌ | `glReadPixels` 每帧闪烁 |
| 手动纹理四边形 | ❌ | `PGraphics` 纹理绑定失败，不显示 |
| 逐行宽松裁剪 | ❌ | 无 `clip()` 时整行溢出 |
| **逐行严格裁剪** | **✅** | **无溢出、无闪烁、实现最简单** |

**设计原则**：在 P2D 下处理文本裁剪时，如果 `clip()` 不可用，**优先使用逻辑裁剪（逐行判断）而非像素级裁剪（离屏缓冲/纹理采样）**。离屏缓冲在 OpenGL 管线中引入了额外的 FBO、纹理同步和坐标转换复杂度，而逐行判断只需 CPU 端的几何比较，简单且可靠。
