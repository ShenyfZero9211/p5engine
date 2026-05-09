# Processing P2D 字体纹理图集溢出导致字符缺失的技术报告

## 1. 问题现象

在 TowerDefenseMin2 项目中，任务简报界面（Briefing UI）使用 `ScrollPane` + `Label` 显示多行中文文本时，出现严重的字符渲染异常：

- **字符缺失**：部分中文字符完全不显示，留下空白占位。例如"你的基地正**面临敌人**的**首次**进攻"中，"面临敌人"、"首次"等常用字丢失。
- **字形错位**：部分字符只显示一半（如按钮上的"务"字仅显示左半边）。
- **逐行 Label 也受影响**：即使将文本拆分为每行独立的 `Label`，使用单点 `text()` 绘制，问题依然存在，说明不是 `text(str, x, y, w, h)` 文本框模式的 bug。
- **主菜单标题模糊**：将全局字体从 128px 降至 16px 后， briefing 文本恢复正常，但主菜单标题（渲染尺寸 84px）变得极其模糊。

## 2. 根因定位

### 2.1 P2D 字体渲染管线

Processing 4 P2D 渲染器基于 JOGL/OpenGL。文字渲染采用**纹理图集（Texture Atlas）**方案：

```
PGraphicsOpenGL.textLineImpl()
  └─ FontTexture (纹理图集管理)
       └─ textCharImpl() 逐字形渲染
            └─ textCharModelImpl() QUAD + 纹理采样
```

每个字形（Glyph）被缓存到一张或多张 OpenGL 纹理中，后续渲染时通过 UV 坐标采样，避免逐字生成纹理的开销。

### 2.2 纹理图集的尺寸限制

根据 Processing 源码 `processing.opengl.PGL`：

```java
protected static int MIN_FONT_TEX_SIZE = 256;
protected static int MAX_FONT_TEX_SIZE = 1024;
```

**关键公式**（`FontTexture.initTexture()`）：

```java
int spow = PGL.nextPowerOfTwo(font.getSize());
minSize = min(maxTextureSize, max(MIN_FONT_TEX_SIZE, spow));
maxSize = min(maxTextureSize, max(MAX_FONT_TEX_SIZE, 2 * spow));
```

- 无论字体原始大小是 16px 还是 128px，**纹理图集的最大尺寸上限始终是 1024×1024**。
- 初始纹理高度为 `minSize`，当一行放不下时会 resize（高度翻倍，不超过 maxSize），若已达到 maxSize 则创建新的纹理页。

### 2.3 纹理空间占用的定量分析

`FontTexture.addToTexture()` 中，每个字形的实际纹理占用为：

```java
int w = 1 + glyph.width + 1;   // 左右各 1px padding（抗锯齿采样保护）
int h = 1 + glyph.height + 1;  // 上下各 1px padding
```

| 字体大小 | 典型中文字形尺寸 | 单字纹理占用 | 1024×1024 可容纳字数 |
|---------|----------------|------------|-------------------|
| 16px    | ~16×16         | ~18×18     | ~2500+            |
| 32px    | ~32×32         | ~34×34     | ~900              |
| 64px    | ~64×64         | ~66×66     | ~240              |
| 128px   | ~128×128       | ~130×130   | **~60**           |

当使用 `createFont("Microsoft YaHei", 128)` 时， briefing 文本包含大量不同汉字（约 50~80 个不重复字符），**极易超过单张 1024 纹理的容量上限**。

### 2.4 溢出时的扩容逻辑与缺陷

`FontTexture.addToTexture()` 的溢出处理：

```java
if (offsetY + lineHeight > textures[lastTex].glHeight) {
    boolean resized = addTexture(pg);
    if (resized) {
        // 当前纹理被 resize 为更大尺寸，更新所有在该纹理中的字形 UV
        updateGlyphsTexCoords();
    } else {
        // 已达到 maxSize，创建全新纹理页
        offsetX = 0;
        offsetY = 0;
        lineHeight = 0;
    }
}
```

**风险点：**

1. **UV 坐标漂移**：当纹理 resize 时，`updateGlyphsTexCoords()` 只更新 `texIndex == lastTex` 的字形。如果某字形在 resize 过程中被异步访问（多线程环境或渲染中断），可能读取到旧的 UV 坐标，导致采样到错误的纹理区域。
2. **新纹理页的上下文切换**：创建新纹理页后，旧纹理页中的字形仍然有效，但 `textCharModelImpl()` 每次只绑定当前字形的纹理。如果相邻字符分布在不同纹理页，理论上每次 `beginShape(QUADS)/endShape()` 都会切换纹理绑定，Processing 源码中这部分逻辑是正确的，但在某些显卡驱动下，频繁切换小尺寸纹理页可能引发状态同步问题。
3. **字形遗漏**：更直接的可能是，当纹理图集满时，新字形的 `TextureInfo` 虽然被创建，但 `updateTex()` 写入的纹理数据因空间竞争被覆盖或截断，导致字形图像不完整。

### 2.5 主菜单标题模糊的独立问题

将全局字体统一改为 16px 后， briefing 文本恢复正常，但主菜单标题使用了 `textSize(84)`。由于 PFont 位图只有 16px 分辨率，Processing 在 P2D 下通过 UV 放大（`bwidth * textSize`，其中 `bwidth = glyph.width / fontSize`）将 16px 位图拉伸到 84px，导致严重的像素拉伸模糊。

## 3. 解决方案

### 3.1 方案一：减小全局字体尺寸（已采用）

将 `createFont("Microsoft YaHei", 128)` 改为 `createFont("Microsoft YaHei", 16)`：

- **优点**：16px 字形在 1024 纹理中可容纳 2500+ 汉字，彻底消除纹理溢出问题； briefing 文本渲染完全正常。
- **缺点**：任何需要大于 16px 的文本（如主菜单标题 84px）都会被像素拉伸，严重模糊。

### 3.2 方案二：分离字体——大字标题 + 小字正文（最终方案）

在 `TdAppCore` 中创建两个字体对象：

```java
PFont cnFontSmall = createFont("Microsoft YaHei", 16);  // UI 正文
PFont cnFontLarge = createFont("Microsoft YaHei", 128); // 主菜单标题

// UI 框架使用小字体
theme.setFont(cnFontSmall);
ui.setTheme(theme);

// 菜单背景：正文用小字体，标题用大字体
TdMenuBg.setFont(cnFontSmall);
TdMenuBg.setTitleFont(cnFontLarge);
```

**渲染时按需切换：**

```java
// TdMenuBg 标题绘制
if (titleFont != null) g.textFont(titleFont);
g.textSize(84 * scale);  // 128px 位图缩放到 84px，质量优秀

// TdMenuBg 底部小字
if (font != null) g.textFont(font);
g.textSize(14 * uiScale); // 16px 位图缩放到 14px，质量可接受
```

**权衡：**
- 标题只使用约 5~10 个不同汉字，128px 字体的 60 字容量上限完全够用，不会触发纹理扩容。
- 正文使用 16px 字体，2500+ 容量，安全余量极大。

### 3.3 其他可选方案（未采用）

| 方案 | 原理 | 未采用原因 |
|-----|------|----------|
| `textMode(SHAPE)` | 将文字转为几何网格渲染，完全不使用纹理图集 | 性能开销大，大量中文字符时帧率显著下降 |
| 离屏 JAVA2D Buffer | 用 `createGraphics(w, h, JAVA2D)` 绘制文本，再贴到 P2D | 引入额外的图形上下文切换，代码复杂度高 |
| 升级 Processing / JOGL | 期望官方修复纹理管理 bug | Processing 4.5.2 已是最新版，且问题与具体显卡驱动相关，不可控 |
| 使用 `.vlw` 位图字体 | 预烘焙固定字形，避免动态纹理分配 | 中文字符集庞大，预烘焙所有字不现实 |

## 4. 源码级证据

### 4.1 FontTexture 初始化与限制

`processing/opengl/FontTexture.java` (line 87~99):

```java
protected void initTexture(PGraphicsOpenGL pg, PFont font) {
    int spow = PGL.nextPowerOfTwo(font.getSize());
    minSize = PApplet.min(PGraphicsOpenGL.maxTextureSize,
                          PApplet.max(PGL.MIN_FONT_TEX_SIZE, spow));
    maxSize = PApplet.min(PGraphicsOpenGL.maxTextureSize,
                          PApplet.max(PGL.MAX_FONT_TEX_SIZE, 2 * spow));
    // MAX_FONT_TEX_SIZE = 1024
}
```

### 4.2 字形纹理写入

`processing/opengl/FontTexture.java` (line 257~334):

```java
protected void addToTexture(PGraphicsOpenGL pg, int idx, PFont.Glyph glyph) {
    int w = 1 + glyph.width + 1;   // +2 padding
    int h = 1 + glyph.height + 1;
    // ...
    if (offsetX + w > textures[lastTex].glWidth) {
        offsetX = 0;
        offsetY += lineHeight;
    }
    if (offsetY + lineHeight > textures[lastTex].glHeight) {
        resized = addTexture(pg);  // resize 或新建纹理页
    }
    TextureInfo tinfo = new TextureInfo(lastTex, offsetX, offsetY, w, h, rgba);
    // ...
}
```

### 4.3 P2D 字符渲染

`processing/opengl/PGraphicsOpenGL.java` (line 3544~3570):

```java
protected void textCharImpl(char ch, float x, float y) {
    PFont.Glyph glyph = textFont.getGlyph(ch);
    if (glyph != null) {
        FontTexture.TextureInfo tinfo = textTex.getTexInfo(glyph);
        if (tinfo == null) {
            tinfo = textTex.addToTexture(this, glyph);  // 动态添加，可能触发扩容
        }
        float bwidth = glyph.width / (float) textFont.getSize();
        float x1 = x + lextent * textSize;
        float x2 = x1 + bwidth * textSize;
        textCharModelImpl(tinfo, x1, y1, x2, y2);
    }
}
```

## 5. 验证结果

| 场景 | 修改前 (128px 全局) | 修改后 (16px 正文 + 128px 标题) |
|-----|-------------------|-------------------------------|
| Briefing 多行文本 | 大量字符缺失/错位 | ✅ 完整显示，无缺失 |
| 按钮文字 | "务"等字显示不全 | ✅ 清晰完整 |
| 主菜单标题 (84px) | 清晰（使用 128px 字体） | ✅ 清晰（继续使用 128px 字体） |
| 主菜单底部小字 (14px) | 清晰 | ✅ 清晰（使用 16px 字体） |
| Processing CLI Build | — | ✅ 通过 |

## 6. 经验总结

1. **P2D 不是万能的**：OpenGL 纹理图集方案对大字库、大字号场景有天然容量限制。中文项目尤其需要关注 `MAX_FONT_TEX_SIZE = 1024` 的硬性上限。
2. **字号分离优于全局降级**：不要试图用一个大字体覆盖所有场景。标题大字、正文小字分离，既能保证视觉质量，又能避免纹理溢出。
3. **Processing `text()` 换行是可靠的**：源码证实 `text(str, x, y, w, h)` 内部通过 `textSentence()` 实现了完整的 `
` 支持和自动 word-wrap。问题出在字体纹理层，而非文本布局层。
4. **调试方向**：当 P2D 文字出现"部分字符缺失"而非"全部乱码"时，优先怀疑 **FontTexture 溢出/UV 坐标错误**，而非编码、clip 或 `text()` 逻辑问题。

## 7. 相关文件

- `src/main/java/shenyf/p5engine/ui/ScrollPane.java`（引擎层 ScrollPane 增强）
- `examples/TowerDefenseMin2/TdAppCore.pde`（字体创建与分发）
- `examples/TowerDefenseMin2/TdMenuBg.pde`（标题/正文分离渲染）
- `examples/TowerDefenseMin2/TdFlow.pde`（Briefing UI 实现）
- Processing 源码参考：`processing/opengl/FontTexture.java`、`processing/opengl/PGraphicsOpenGL.java`
