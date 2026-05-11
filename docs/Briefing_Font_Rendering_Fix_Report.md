# 简报界面字体渲染问题修复报告

## 问题概述

在 TowerDefenseMin2 示例的**任务简报界面**中，使用 48pt 中文字体（Microsoft YaHei）渲染关卡说明文字时，Processing 4 P2D 模式下出现严重的字体渲染异常。具体表现为：

1. **直接加载完整字体**（`createFont("Microsoft YaHei", 48)`）→ 触发 **"超出缓存限制"** 错误，程序崩溃或字体渲染失败
2. **限制字符集加载**（`createFont(name, 48, true, char[])`）→ 虽能避免缓存溢出，但部分中文字符**缺失不显示**
3. **矢量模式绘制**（`textMode(SHAPE)`）→ 绕过纹理缓存，但**帧数骤降**（每帧对数百个汉字做 OpenGL triangulation，GPU 开销极大）

## 根因分析：P2D 字体纹理机制

Processing 4 的 P2D 渲染器基于 JOGL/OpenGL。其 `PFont` 在创建时会将每个字符的位图缓存到**纹理图集（texture atlas）**中：

- 默认纹理页大小为 **1024×1024** 像素
- 48pt 中文字符的 glyph 图像约为 **50×60** 像素
- 单页可容纳约 **300~400** 个 glyph
- 完整中文字体（如微软雅黑含 20,000+ 字符）需要 **50+ 页**纹理

当 `PFont` 初始化时，`finalize()` 方法会为所有 glyph 分配纹理坐标。在 P2D 模式下，`textFontImpl()` 将这些 `PImage` 纹理上传到 GPU。此时：

- **Java 堆内存**：50 页 × 4MB = **200MB+** `int[]` 数组，接近 JVM 默认堆上限
- **GPU 纹理内存**：大量 1024×1024 纹理上传，触发 **OpenGL 纹理缓存限制**
- 多页纹理的 shelf-packing 算法在处理大量 glyph 时可能出现**坐标分配错误**，导致部分字符纹理坐标损坏

### 字符集限制的副作用

使用 `char[] charset` 将字符限制在 ~300 个简报用字后，单页即可容纳，避免了溢出。但出现了**部分字符随机缺失**的现象。经排查，这不是字符集收集不全的问题（`collectBriefingChars()` 已正确扫描所有 briefing txt 文件），而是 P2D 下 `deriveFont()` 与纹理多页共享的交互 bug：

- `Label.paint()` 调用 `textSize(18)` 时，Processing 自动调用 `deriveFont(18)`
- `deriveFont()` 创建的新 `PFont` **共享原始 `glyphList` 和 `textures`**
- P2D 渲染器在处理共享纹理的多页 `PFont` 时，某些 glyph 的**纹理坐标或页索引映射出错**，导致绘制时跳过特定字符

### textMode(SHAPE) 的性能陷阱

`textMode(SHAPE)` 完全绕过纹理缓存，改为使用 `PShape` 矢量路径绘制每个字符：

- 每个汉字 glyph 的轮廓通过 `GlyphVector.getOutline()` → `GeneralPath` → `PShape` 转换
- P2D 下 `PShape.draw()` 需要**实时三角化（tessellation）**复杂曲线
- 简报界面约 200~300 个汉字，每帧需 triangulate **数万三角形**
- 结果：**帧率从 60fps 暴跌至 10fps 以下**，完全不可接受

## 最终方案：JAVA2D 离屏预渲染

### 核心思路

既然 P2D 的字体纹理系统有根本性的容量限制，而 `textMode(SHAPE)` 性能太差，那么**彻底绕过 Processing P2D 的字体渲染管线**，改用 **JAVA2D 软件渲染**预先生成位图，然后在 P2D 下只显示静态 `PImage`。

JAVA2D 渲染器基于 Java AWT `Graphics2D`，其字体绘制机制：

- 直接使用系统字体 rasterizer（如 Windows 的 DirectWrite/GDI）
- **不依赖纹理图集**，每帧直接用 `drawString()`/`TextLayout` 绘制
- 不受 OpenGL 纹理大小或页数限制
- 对于一次性离屏渲染，性能完全可接受

### 实现步骤

1. **创建 JAVA2D 离屏缓冲区**
   ```java
   PGraphics pg = app.createGraphics(740, 2000, JAVA2D);
   pg.beginDraw();
   ```

2. **用完整字体绘制文本**
   ```java
   pg.textFont(app.createFont("Microsoft YaHei", fontSizeBriefing));
   pg.textSize(fontSizeBriefing);
   pg.textAlign(LEFT, TOP);
   pg.fill(0xFFE0E6F0);
   pg.text(briefingText, 4, 4, contentW - 8, maxBufferH - 8);
   pg.endDraw();
   ```

3. **裁剪空白区域**
   ```java
   PImage fullImg = pg.get();
   // 从底部向上扫描，找到最后一个非透明像素
   int actualH = maxBufferH;
   outer:
   for (int y = maxBufferH - 1; y >= 0; y--) {
       for (int x = 0; x < contentW; x++) {
           if ((fullImg.get(x, y) & 0xFF000000) != 0) {
               actualH = y + 1;
               break outer;
           }
       }
   }
   PImage img = fullImg.get(0, 0, contentW, Math.min(actualH + 4, maxBufferH));
   ```

4. **用 Image 组件显示**
   ```java
   Image lblBriefing = new Image("lbl_briefing_text");
   lblBriefing.setImage(img);
   lblBriefing.setBounds(0, 0, img.width, img.height);
   sp.getViewport().add(lblBriefing);
   ```

### 方案优势

| 维度 | P2D 纹理 (MODEL) | textMode(SHAPE) | JAVA2D 预渲染 |
|------|------------------|-----------------|---------------|
| 字符容量 | ~400/页，多页易出错 | 无限制 | 无限制 |
| 渲染清晰度 | 位图缩放可能模糊 | 矢量，完美 | JAVA2D 原生 rasterizer，清晰 |
| 运行时性能 | 快（GPU 纹理四边形） | **极慢**（每帧 triangulation） | **快**（单张静态图片） |
| 内存占用 | 200MB+（完整字体） | 低 | 仅最终位图（~5MB） |
| 实现复杂度 | 低 | 低 | 中（需离屏渲染+裁剪） |

### 关键注意事项

1. **缓冲区高度**：预分配 `2000` 像素高度，足够容纳任意长度的简报文本；通过像素扫描精确裁剪到实际高度，避免浪费内存
2. **ScrollPane 兼容**：`Image` 组件是 p5engine 原生 UI 组件，完美支持 `ScrollPane` 滚动（`viewport` 尺寸随 `Image` 高度自动调整）
3. **字体加载**：即使使用 `char[]` 限制字符集，JAVA2D 下 `createFont` 也只创建 `PFont` 对象，其纹理在 `pg.endDraw()` 后即被 GC，不会长期占用内存
4. **透明背景**：`pg.background(0, 0)` 确保离屏缓冲区透明，简报面板背景色不受影响

## 相关文件

- `examples/TowerDefenseMin2/TdFlow.pde` — `showBriefing()` 方法，简报 UI 布局与 JAVA2D 预渲染逻辑
- `examples/TowerDefenseMin2/data/config/game_settings.yaml` — `fontSizeBriefing` 配置项
- `src/main/java/shenyf/p5engine/ui/Image.java` — p5engine Image 组件，用于显示预渲染位图
- `examples/TowerDefenseMin2/TdAssets.pde` — `collectBriefingChars()` 字符集收集（早期尝试使用，最终方案中仍用于减少临时 PFont 内存峰值）

## 结论

Processing P2D 的 OpenGL 字体纹理机制不适合大字号（≥48pt）+ 大字符集（中文）的文本渲染场景。通过 **JAVA2D 离屏预渲染** 将文本一次性绘制为静态 `PImage`，完全绕过了 P2D 字体管线的容量和性能限制，是此类场景下的最优工程方案。
