# LevelCarousel 边缘透明渐隐技术实现记录

> 文档记录 `TowerDefenseMin2` 选关界面中水平滚动关卡列表（`LevelCarousel`）边缘 fade-out 效果的完整技术演进，包括 P2D offscreen buffer 闪烁问题、黑底问题的根因分析与最终解决方案。

---

## 1. 需求背景

选关界面需要展示一个水平滚动的关卡卡片轮播：
- 中心卡片最大，两侧卡片缩小到 `0.77x`
- 左右边缘需要**透明渐隐**（fade-out），让卡片自然融入背景星空
- 整体随窗口 `fadeIn` 动画联动（`getEffectiveAlpha()`）
- 支持点击、滑动、键盘导航

-carousel 区域尺寸：`700 × 290`（设计分辨率）
- fade 区域：左右各约 `12%`（`84px`）的 `smoothstep` 渐变

---

## 2. 方案演进

### 2.1 方案 A：纯过程式 mask shader（无 offscreen buffer）

**思路**：参考 `flashlight_grid.glsl` 的做法，不用 `sampler2D`，直接用 `blendMode(MULTIPLY)` + 一个输出 `vec4(1,1,1,fade)` 的 shader 画全屏遮罩。

**问题**：
- `blendMode(MULTIPLY)` 在 P2D/OpenGL 下的 alpha 混合公式是 `glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA)`
- 该 blend 函数的 **alpha 通道不变**（`resultA = dstA`），mask 只影响 RGB，无法真正改变 alpha
- 边缘看起来是"变暗"而不是"淡出到透明"
- 无法与背景星空正确混合

**结论**：`MULTIPLY` 不能用于 alpha mask。纯过程式 shader 只有在不依赖外部 texture、直接计算最终 RGBA 时才可靠（如 `flashlight_grid.glsl` 的 ADD 混合光效）。

---

### 2.2 方案 B：CPU 逐像素 mask（`get()` + 手动 alpha）

**思路**：先 `get()` 保存背景 → `drawCards()` 画到主画布 → 再 `get()` 捕获区域 → CPU 上逐像素乘以 `smoothstep` mask → `image()` 叠回。

**问题**：
- `drawCards()` 使用绝对坐标直接画到主画布，超出 carousel 边界的卡片内容会残留在画布上
- `get()` 只能捕获 carousel 区域内的像素，超出部分无法被 mask
- 左右两侧出现"穿帮"（卡片硬切边）
- 每帧两次 `get()`（`glReadPixels`），对 P2D 有 GPU→CPU 同步开销

**结论**：可行但边缘处理复杂，且 `get()` 频繁读写 framebuffer 性能不佳。

---

### 2.3 方案 C：P2D offscreen buffer + `sampler2D` shader

**思路**：标准方案——`createGraphics(w, h, P2D)` 创建离屏 buffer，绘制卡片后采样到 `carousel_fade.glsl`。

**问题 1：闪烁（flickering）**
- P2D 的 `PGraphicsOpenGL` 底层使用 **OpenGL FBO 双缓冲**（`swapOffscreenTextures()`）
- `endDraw()` 后 FBO 的 texture 内容**不会立即同步**到 GPU texture cache
- `image(buffer)` 时 Processing 优先使用 cache 中的旧 texture，导致偶发读取空白/旧帧
- 尝试 `removeCache(buffer)`、`loadPixels()`、`buffer.get()` 等多种强制同步手段，P2D FBO 的双缓冲机制仍导致不稳定

**问题 2：黑底**
- `PGraphicsOpenGL.backgroundImpl()` 强制把 `backgroundA` 设为 `1`
- `endOffscreenDraw()` 中有一段固定逻辑：
  ```java
  if (backgroundA == 1) {
      pgl.colorMask(false, false, false, true);
      pgl.clearColor(0, 0, 0, backgroundA);
      pgl.clear(PGL.COLOR_BUFFER_BIT);
      pgl.colorMask(true, true, true, true);
  }
  ```
- **无论 `background(0, 0)` 传入什么 alpha，P2D offscreen buffer 的 alpha 通道最终都会被强制清除为 1（完全不透明）**
- 因此 `image(buffer)` 时 buffer 的背景是黑色不透明，会盖住后面的星空

**结论**：P2D offscreen buffer 同时存在 **闪烁** 和 **透明不可行** 两个根本问题，必须换渲染器。

---

### 2.4 方案 D（最终）：JAVA2D buffer + `buffer.get()` + `sampler2D` shader

**思路**：
1. `createGraphics(w, h, JAVA2D)` — 使用 Java2D `BufferedImage` 软件渲染
2. `drawCards(buffer)` — 在 buffer 上绘制所有卡片（透明背景）
3. `buffer.get()` — 从 `BufferedImage` 复制 pixels 到一个全新的 `PImage`
4. `image(snapshot)` + `carousel_fade.glsl` — 主画布用 shader 采样 snapshot 做边缘 fade

**为什么有效**：

| 问题 | P2D buffer | JAVA2D buffer |
|------|-----------|---------------|
| 双缓冲/闪烁 | OpenGL FBO front/back swap，`endDraw()` 后 texture 不同步 | `BufferedImage` 是 CPU 内存位图，无 FBO，内容始终一致 |
| 透明背景 | `endOffscreenDraw()` 强制 alpha → 1 | `background(0, 0)` 就是画 alpha=0 的矩形，真正透明 |
| 上传 texture | 依赖 OpenGL texture cache，可能 stale | `get()` 生成新 `PImage`，`image()` 时 Processing 创建全新 texture 上传 |

**代价**：
- JAVA2D 是软件渲染，但 `700×290` 小 buffer 每帧开销可忽略
- `buffer.get()` 每帧创建新 `PImage` 对象（约 200KB），现代 JVM GC 可轻松承受

---

## 3. 关键代码

### 3.1 `carousel_fade.glsl`

```glsl
uniform sampler2D texture;
uniform float edgeWidth;
uniform float globalAlpha;

varying vec4 vertColor;
varying vec4 vertTexCoord;

void main() {
    vec4 texColor = texture2D(texture, vertTexCoord.st);
    float s = vertTexCoord.s;
    float edge = smoothstep(0.0, edgeWidth, s) * (1.0 - smoothstep(1.0 - edgeWidth, 1.0, s));
    texColor.a *= edge * globalAlpha;
    gl_FragColor = texColor;
}
```

- `vertTexCoord.s` 从 0 到 1 横跨 texture 宽度
- `smoothstep(0, edgeWidth, s)`：左边缘从 0 渐变到 1
- `1.0 - smoothstep(1.0 - edgeWidth, 1.0, s)`：右边缘从 1 渐变到 0
- `globalAlpha` 联动窗口/组件的 `fadeIn` 动画

### 3.2 `LevelCarousel.paintSelf()`

```java
@Override
protected void paintSelf(PApplet applet, Theme theme) {
    float ax = getAbsoluteX();
    float ay = getAbsoluteY();
    float w = getWidth();
    float h = getHeight();
    if (w <= 0 || h <= 0) return;

    // JAVA2D 彻底避开 P2D FBO 闪烁 + 黑底问题
    if (buffer == null || buffer.width != (int) w || buffer.height != (int) h) {
        buffer = applet.createGraphics((int) w, (int) h, JAVA2D);
        fadeShader = applet.loadShader("shaders/carousel_fade.glsl");
    }

    buffer.beginDraw();
    buffer.background(0, 0); // 真正透明
    // ... 绘制卡片 ...
    buffer.endDraw();

    // 从 BufferedImage 复制到全新 PImage，确保 pixels 最新
    PImage snapshot = buffer.get();

    applet.shader(fadeShader);
    fadeShader.set("edgeWidth", FADE_EDGE);
    fadeShader.set("globalAlpha", getEffectiveAlpha());
    applet.image(snapshot, ax, ay);
    applet.resetShader();
}
```

### 3.3 `drawCards()` 坐标系

```java
private void drawCards(PGraphics g) {
    float centerX = g.width / 2f;  // 相对 buffer 中心
    // ...
    g.pushMatrix();
    g.translate(x, y);  // x, y 是相对于 buffer 左上角
    g.fill(bgColor);
    g.rect(0, 0, cardW, cardH, 4);
    // ...
    g.popMatrix();
}
```

- 在 offscreen buffer 内绘制，使用 **相对 buffer 的坐标系**
- 不涉及绝对屏幕坐标，不会污染主画布

---

## 4. 交互设计

### 4.1 滚动与缓动

```java
void update(PApplet applet, float dt) {
    if (Math.abs(scrollX - targetScrollX) > 0.5f) {
        scrollX += (targetScrollX - scrollX) * Math.min(1f, 12f * dt);
    } else {
        scrollX = targetScrollX;
    }
}
```

- `selectedIndex` 改变 → `targetScrollX = selectedIndex * SLOT_W`
- 12× 指数缓动，约 0.1s 内完成滚动

### 4.2 缩放逻辑

```java
float dist = Math.abs(offsetIndex);
float scale;
if (dist < 0.5f) {
    scale = 1.0f;
} else if (dist < 1.5f) {
    float t = (dist - 0.5f);
    scale = 1.0f - t * (1.0f - SIDE_SCALE);
} else {
    scale = SIDE_SCALE;  // 0.77f
}
```

- 中心 0.5 槽距内：完全不缩放
- 0.5～1.5 槽距：线性插值到 `SIDE_SCALE`
- 1.5 槽距外：固定 `SIDE_SCALE`

### 4.3 点击反馈

- `MOUSE_PRESSED`：记录 `pressedCardIndex`
- `MOUSE_RELEASED`：如果释放位置和按下位置在同一张卡片上
  - 中心卡片 → 触发 `onEnterAction`（进入关卡）
  - 侧边卡片 → `selectedIndex = pressedCardIndex`，触发滚动
- 按下时卡片缩放 `0.96x` + 背景色变暗

---

## 5. 踩坑总结

| 坑 | 根因 | 解决 |
|---|---|---|
| P2D offscreen 闪烁 | OpenGL FBO 双缓冲 `swapOffscreenTextures()`，`endDraw()` 后 texture cache 不同步 | 改用 `JAVA2D`，无 FBO |
| P2D offscreen 黑底 | `PGraphicsOpenGL.endOffscreenDraw()` 强制 `pgl.clearColor(..., backgroundA)` 把 alpha 清为 1 | 改用 `JAVA2D`，`BufferedImage` 真正支持 ARGB 透明 |
| `blendMode(MULTIPLY)` 无法 mask alpha | OpenGL `glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA)` 的 alpha 混合不变 | 改用 `sampler2D` shader 直接修改 `gl_FragColor.a` |
| `removeCache` 调用位置 | `PApplet` 没有 `removeCache`，实际在 `PGraphics` / `PGraphicsOpenGL` 中 | 正确路径是 `applet.g.removeCache(buffer)`，但最终未解决 P2D FBO 问题 |
| `buffer.get()` 在 P2D 下也闪烁 | `get()` 会触发 `loadPixels()`，但 P2D `loadPixels()` 受双缓冲影响可能读到旧帧 | `JAVA2D` 的 `get()` 直接从 `BufferedImage` 读取，不受 GPU 双缓冲影响 |
| 卡片超出边界"穿帮" | `drawCards()` 直接画到主画布，`get()` 只捕获区域内像素 | 使用 offscreen buffer（无论 P2D 还是 JAVA2D），卡片绘制在 buffer 内部 |

---

## 6. 相关文件

- `examples/TowerDefenseMin2/LevelCarousel.pde` — 轮播组件主代码
- `examples/TowerDefenseMin2/data/shaders/carousel_fade.glsl` — 边缘 fade fragment shader
- `examples/TowerDefenseMin2/TdFlow.pde` — `showLevelSelect()` 组装选关界面
- `examples/TowerDefenseMin2/TdAppCore.pde` — 键盘导航（← → Enter）
