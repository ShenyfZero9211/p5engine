# p5engine 图片渲染系统技术报告

> **版本**：p5engine v1.x  
> **日期**：2026-05-05  
> **关联计划**：`groot-rogue-bobbi-morse.md`

---

## 1. 概述

本文档总结 p5engine 引擎新增的 **Texture / ImageManager** 图片渲染子系统。该子系统在原有 `PImage` 直接绘制的基础上，引入了一层轻量纹理抽象、全局资源 LRU 缓存、组件式精灵渲染器以及序列帧动画组件，解决了以下问题：

| 问题 | 原有方案 | 新方案 |
|------|---------|--------|
| 子图切割性能差 | `PImage.get(x,y,w,h)` 像素拷贝 | `Texture.getRegion()` 共享原图 + UV 绘制 |
| 资源无统一管理 | 各处直接 `loadImage()`，重复加载 | `ImageManager` 全局缓存 + 懒加载 |
| 精灵渲染与场景系统脱节 | 手工在 `draw()` 中 `image()` | `SpriteRenderer` 作为 `Component` 自动渲染 |
| 动画帧管理繁琐 | 手写帧索引计时 | `AnimatedSpriteRenderer` 内置 FPS 驱动 |

---

## 2. 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                        P5Engine                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ SceneManager│  │ ImageManager│  │  ProcessingRenderer │  │
│  │  (场景树)    │  │ (资源缓存)   │  │    (底层绘制)        │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              GameObject + Component                  │   │
│  │  ┌──────────────┐    ┌──────────────────────────┐  │   │
│  │  │SpriteRenderer│    │AnimatedSpriteRenderer    │  │   │
│  │  │  (静态精灵)   │    │  (序列帧动画)             │  │   │
│  │  └──────┬───────┘    └────────────┬─────────────┘  │   │
│  │         │                         │                │   │
│  │         ▼                         ▼                │   │
│  │  ┌─────────────────────────────────────────────┐  │   │
│  │  │              Texture (零拷贝 UV 绘制)         │  │   │
│  │  └─────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

外部数据源
    ├── data/ 目录 (PNG/JPG/GIF)  ← PApplet.loadImage()
    └── .ppak 资源包              ← PPakImage.load()
```

---

## 3. 核心组件

### 3.1 Texture — 轻量纹理抽象

**文件**：`src/main/java/shenyf/p5engine/rendering/Texture.java`

`Texture` 是本系统的最小原子。它**不持有像素数据**，而是封装了对一张共享 `PImage` 的引用，加上可选的 UV 子区域（`sx, sy, sw, sh`）和翻转标志。

#### 关键特性

- **不可变（Immutable）**：所有字段均为 `final`，修改行为（如裁剪、翻转）返回新实例，原实例安全共享。
- **零拷贝子区域**：`getRegion(x, y, w, h)` 不调用 `PImage.get()`，而是生成新的 `Texture` 指向同一 `PImage` 的不同 UV 区域。
- **硬件级 UV 翻转**：`flipX` / `flipY` 通过交换 UV 坐标实现，无需修改像素或创建镜像副本。

#### 核心 API

```java
// 全图纹理
Texture tex = new Texture(pImage, "player.png");

// 子区域（共享原图）
Texture head = tex.getRegion(0, 0, 32, 32);
Texture body = tex.getRegion(32, 0, 32, 32);

// 水平翻转（共享原图）
Texture leftHead = head.withFlip(true, false);

// 绘制（内部自动处理 UV + 翻转）
tex.draw(renderer, x, y, w, h);
```

#### UV 绘制原理

```java
public void draw(IRenderer renderer, float x, float y, float w, float h) {
    int u1 = sx, v1 = sy, u2 = sx + sw, v2 = sy + sh;
    if (flipX) { swap(u1, u2); }
    if (flipY) { swap(v1, v2); }
    renderer.drawImage(image, x, y, w, h, u1, v1, u2, v2);
}
```

底层通过 `PGraphics.image(image, dx, dy, dw, dh, sx, sy, sw, sh)` 直接由 OpenGL 采样对应 UV 区域，**无 CPU 像素复制**。

---

### 3.2 ImageManager — 全局资源管理器

**文件**：`src/main/java/shenyf/p5engine/rendering/ImageManager.java`

引擎级单例资源管理器，为所有 `Texture` 提供统一的加载、缓存和生命周期管理。

#### 缓存策略

- **数据结构**：`LinkedHashMap<String, Texture>`，启用 `accessOrder = true`，天然实现 LRU（最近最少使用）。
- **淘汰机制**：基于内存预算（默认 **64MB**），超出时自动驱逐最久未访问的条目。
- **内存估算**：`width × height × 4` bytes（ARGB 32-bit）。

```java
// 64MB 默认上限
private long maxMemory = 64 * 1024 * 1024;

// 淘汰回调（LinkedHashMap.removeEldestEntry 覆盖）
protected boolean removeEldestEntry(Map.Entry<String, Texture> eldest) {
    if (currentMemory > maxMemory && !cache.isEmpty()) {
        Texture evicted = eldest.getValue();
        currentMemory -= estimateMemory(evicted);
        return true; // 允许移除
    }
    return false;
}
```

#### 加载来源

| 方法 | 数据来源 | 缓存 Key 格式 |
|------|---------|--------------|
| `load(String path)` | `data/` 目录 | `sprites/player.png` |
| `load(String path, PPakDecoder decoder)` | `.ppak` 资源包 | `ppak:sprites/player.png` |

`ImageManager` 与已有的 `PPakImage` **形成双层缓存**：
- **PPakImage 层**：缓存从 `.ppak` 解压/解码后的原始 `PImage`（避免重复 IO 和解码）。
- **ImageManager 层**：缓存 `Texture` 包装对象（避免重复构造，支持跨场景共享）。

#### 关键 API

```java
// 懒加载 + 缓存
Texture tex = engine.getImages().load("ui/button.png");

// 批量预加载（场景切换时 warming up）
engine.getImages().preload(
    "sprites/player.png",
    "sprites/enemy.png",
    "ui/panel.png"
);

// 按 key 取已缓存（用于 SpriteRenderer 懒解析）
Texture cached = engine.getImages().get("sprites/player.png");

// 卸载 / 清空
engine.getImages().unload("sprites/player.png");
engine.getImages().clear(); // 通常在 P5Engine.destroy() 中调用
```

---

### 3.3 IRenderer & ProcessingRenderer — 底层绘制扩展

**文件**：
- `src/main/java/shenyf/p5engine/rendering/IRenderer.java`
- `src/main/java/shenyf/p5engine/rendering/ProcessingRenderer.java`

为支持 `Texture` 的 UV 子区域绘制，`IRenderer` 新增重载：

```java
// 原有：全图绘制
void drawImage(PImage image, float x, float y, float w, float h);

// 新增：UV 子区域绘制（dx/dy/dw/dh = 目标屏幕矩形, sx/sy/sw/sh = 源图 UV）
void drawImage(PImage image, float dx, float dy, float dw, float dh,
               int sx, int sy, int sw, int sh);
```

`ProcessingRenderer` 直接委托给 `PGraphics.image(...)`，该 API 在 P2D（JOGL）模式下由 GPU 完成纹理采样，性能开销极小。

---

### 3.4 SpriteRenderer — 组件式精灵渲染器

**文件**：`src/main/java/shenyf/p5engine/rendering/SpriteRenderer.java`

继承自 `Component` 并实现 `Renderable` 接口，可直接挂载到 `GameObject` 上，由场景系统自动调用 `render()`。

#### 懒加载模式

```java
public void setTexture(String key) {
    this.textureKey = key;   // 记录 key，暂不加载
    this.texture = null;
}

private Texture resolveTexture() {
    if (texture != null) return texture;
    if (textureKey != null && P5Engine.isInitialized()) {
        texture = P5Engine.getInstance().getImages().get(textureKey);
        if (texture != null) textureKey = null; // 解析完成
    }
    return texture;
}
```

此模式解决了**组件构造时引擎尚未初始化**的时序问题（例如在游戏对象的 `start()` 之前就设置了纹理 key）。

#### 向后兼容

保留了对原始 `PImage` 的支持（标记为 `@Deprecated`），旧代码可平滑迁移：

```java
// 旧方式（仍可用，但已弃用）
sprite.setImage(pImage);

// 新方式
sprite.setTexture(texture);
sprite.setTexture("sprites/player.png"); // 懒加载
```

#### 子区域与染色

```java
// 设置子区域（基于当前 texture 裁剪）
sprite.setRegion(32, 0, 32, 32);

// 染色（通过 renderer.setColor / tint 实现）
sprite.setTintColor(0xFFFF0000); // 红色染色
```

---

### 3.5 AnimatedSpriteRenderer — 序列帧动画

**文件**：`src/main/java/shenyf/p5engine/rendering/AnimatedSpriteRenderer.java`

同样是 `Component` + `Renderable`，专用于播放 `Texture[]` 帧序列。

#### 帧驱动机制

```java
@Override
public void update(float dt) {
    if (!playing) return;
    frameTimer += dt;
    float frameDuration = 1f / fps;
    while (frameTimer >= frameDuration) {
        frameTimer -= frameDuration;
        currentFrame++;
        if (currentFrame >= frames.length) {
            if (loop) currentFrame = 0;
            else { currentFrame = frames.length - 1; playing = false; finished = true; }
        }
    }
}
```

- **时间驱动**：基于 `dt`（秒）而非固定帧率，确保不同机器上播放速度一致。
- **支持循环/单次播放**：`loop = false` 时播放到末尾自动停止并标记 `finished`。

#### 使用示例

```java
// 从 ImageManager 加载帧序列
Texture[] frames = new Texture[4];
for (int i = 0; i < 4; i++) {
    frames[i] = engine.getImages().load("anim/explosion_" + i + ".png");
}

AnimatedSpriteRenderer anim = new AnimatedSpriteRenderer();
anim.setFrames(frames);
anim.setFps(12f);
anim.setLoop(false);
gameObject.addComponent(anim);
```

---

## 4. 引擎集成

### 4.1 P5Engine 生命周期

**文件**：`src/main/java/shenyf/p5engine/core/P5Engine.java`

| 阶段 | 操作 |
|------|------|
| **构造** | `this.imageManager = new ImageManager(applet);` |
| **运行期** | 通过 `engine.getImages()` 对外暴露，供场景内组件懒加载纹理 |
| **销毁** | `imageManager.clear();` 在 `destroy()` 中调用，释放所有缓存的 `Texture` 引用 |

```java
// P5Engine.java 关键代码
private final ImageManager imageManager;

private P5Engine(PApplet applet, P5Config config) {
    // ...
    this.imageManager = new ImageManager(applet);
    // ...
}

public ImageManager getImages() {
    return imageManager;
}

public void destroy() {
    // ...
    imageManager.clear();
    // ...
}
```

---

## 5. 与现有子系统的关系

### 5.1 TextureAtlas（已有）

`TextureAtlas` 通过 `PImage.get()` 获取子图副本，适合需要**独立修改像素**的场景（如动态染色、逐像素碰撞检测）。

`Texture` + `ImageManager` 则适合**只读渲染**场景，通过 UV 子区域实现零拷贝，性能更优。

两者可协同工作：

```java
// 用 TextureAtlas 解析 JSON 描述，再转为 Texture 缓存
TextureAtlas atlas = new TextureAtlas(applet, "atlas.png", "atlas.json");
TextureAtlas.Region r = atlas.getRegion("coin");
Texture coinTex = engine.getImages().load("atlas.png")
                             .getRegion(r.x, r.y, r.width, r.height);
```

### 5.2 SpriteBatch（已有）

`SpriteBatch` 通过 `PShape` 批量提交同纹理四边形，减少 draw call，适合粒子、 tilemap 等大量同图元渲染。

`Texture` / `SpriteRenderer` 走的是 `IRenderer.drawImage()` 单次绘制路径，更灵活（支持逐精灵旋转、缩放、染色），但 draw call 更多。**两者使用同一张 `PImage` 底层纹理，可在不同场景按需选用**。

### 5.3 PPak（已有）

`ImageManager.load(path, PPakDecoder)` 复用了 `PPakImage.load()` 的解码和 LRU 缓存。PPak 负责**资源包 IO 与解压**，`ImageManager` 负责**纹理对象的封装与引擎级生命周期管理**，职责清晰分离。

---

## 6. 关键设计决策

### 6.1 为什么 Texture 是不可变的？

- **线程安全**：多 `SpriteRenderer` 共享同一 `Texture` 实例无竞态风险。
- **缓存友好**：`ImageManager` 缓存的 `Texture` 可被任意组件引用，无需担心某个组件修改后影响其他组件。
- **函数式语义**：`withFlip()` / `getRegion()` 返回新实例，符合现代 Java 不可变对象设计。

### 6.2 为什么使用 PGraphics.image(sx, sy, sw, sh) 而非 PImage.get()？

| 方案 | 时间复杂度 | 内存影响 | GPU 纹理缓存 |
|------|-----------|---------|-------------|
| `PImage.get(x,y,w,h)` | O(w×h) 像素拷贝 | 新建 PImage + GPU 纹理上传 | 可能重复上传 |
| `PGraphics.image(..., sx, sy, sw, sh)` | O(1) 仅设置 UV | 零拷贝 | 复用原图纹理 |

在 P2D（JOGL）模式下，后者直接由 OpenGL 纹理采样完成，是性能最优解。

### 6.3 为什么 SpriteRenderer 支持懒加载（String key）？

游戏对象常在场景初始化时构造，但此时 `P5Engine` 可能尚未完成初始化（例如在游戏配置读取阶段预创建对象）。通过 `setTexture(String key)` 将实际加载推迟到首次 `render()` 调用时，解决了**构造时序**与**资源可用性**的耦合问题。

---

## 7. 性能考量

| 场景 | 建议方案 | 说明 |
|------|---------|------|
| 大量同纹理静态精灵（tilemap、粒子） | `SpriteBatch` | 批量绘制，draw call 最少 |
| 少量/中等数量不同纹理精灵 | `SpriteRenderer` + `Texture` | 灵活，代码简洁 |
| 序列帧动画 | `AnimatedSpriteRenderer` | 自动帧管理，时间驱动 |
| 需要逐像素读写的子图 | `TextureAtlas.get()` | `PImage.get()` 返回独立副本 |
| 内存受限设备 | 调低 `ImageManager.setMaxMemory()` | LRU 自动驱逐冷数据 |

---

## 8. 使用示例

### 8.1 基本纹理加载与渲染

```java
// 在场景 setup 中预加载
Texture bg = engine.getImages().load("bg/forest.png");
Texture player = engine.getImages().load("sprites/player.png");

// 创建游戏对象并挂载 SpriteRenderer
GameObject go = new GameObject("Player");
SpriteRenderer sr = new SpriteRenderer(player);
sr.setWidth(64);
sr.setHeight(64);
go.addComponent(sr);
scene.addGameObject(go);
```

### 8.2 子区域与翻转

```java
Texture sheet = engine.getImages().load("sprites/hero_sheet.png");

// 取第 2 帧（假设每帧 32×32）
Texture frame2 = sheet.getRegion(64, 0, 32, 32);
// 朝左走 = 水平翻转
Texture leftFrame2 = frame2.withFlip(true, false);

sprite.setTexture(leftFrame2);
```

### 8.3 动画

```java
Texture[] runFrames = new Texture[6];
for (int i = 0; i < 6; i++) {
    runFrames[i] = sheet.getRegion(i * 32, 0, 32, 32);
}

AnimatedSpriteRenderer anim = new AnimatedSpriteRenderer();
anim.setFrames(runFrames);
anim.setFps(10f);
anim.setLoop(true);
go.addComponent(anim);
```

### 8.4 资源清理

```java
// 场景切换时卸载旧场景专属资源
engine.getImages().unload("bg/forest.png");
engine.getImages().unload("sprites/enemy_boss.png");

// 或应用退出时一次性清空（P5Engine.destroy() 已自动调用）
engine.getImages().clear();
```

---

## 9. 文件清单

| 文件 | 说明 |
|------|------|
| `src/main/java/shenyf/p5engine/rendering/Texture.java` | 轻量纹理抽象，UV 子区域 + 翻转 |
| `src/main/java/shenyf/p5engine/rendering/ImageManager.java` | 全局 LRU 缓存资源管理器 |
| `src/main/java/shenyf/p5engine/rendering/SpriteRenderer.java` | 组件式精灵渲染器（静态） |
| `src/main/java/shenyf/p5engine/rendering/AnimatedSpriteRenderer.java` | 组件式序列帧动画渲染器 |
| `src/main/java/shenyf/p5engine/rendering/IRenderer.java` | 新增 UV 子区域绘制接口 |
| `src/main/java/shenyf/p5engine/rendering/ProcessingRenderer.java` | UV 接口的 PGraphics 实现 |
| `src/main/java/shenyf/p5engine/core/P5Engine.java` | 集成 `ImageManager` 生命周期 |

---

## 10. 验证结果

- **引擎编译**：`compile-jar.ps1` ✅
- **示例编译**：`TowerDefenseMin2` Processing CLI build ✅
- **向后兼容**：旧 `PImage` API 仍可用（标记 `@Deprecated`）
