# 工业级分辨率适配方案（Industrial Resolution Adaptation）

## 目标
重构 p5engine 分辨率系统，支持任意宽高比（4:3、16:9、16:10、21:9 等），实现 3A 游戏标准行为：
- **无黑边**：世界内容铺满全屏
- **UI 不变形**：UI 保持 1280×720 设计比例
- **世界内容完整可见**：不同比例下自动调整可见范围（而非裁剪）
- **动态分辨率列表**：从显示器枚举所有可用分辨率

## 背景

当前系统使用单一全局 FIT 缩放（`TowerDefenseMin2.draw()` 中的 `pushMatrix → scale → popMatrix`），将所有内容（世界+UI+背景）统一缩放到一个居中矩形内。这导致：
- 21:9 屏幕左右出现大面积黑边
- 4:3 屏幕上下出现黑边
- 分辨率列表为固定枚举（720p/1080p/1440p/4K），无法枚举显示器实际支持的模式

## 核心设计：分层渲染（Layered Rendering）

将单一全局缩放拆分为两层独立策略：

### 层1 — 世界层（World Layer）
| 属性 | 值 |
|------|-----|
| 坐标系 | 实际屏幕像素（1:1） |
| 缩放策略 | 无缩放 |
| 视口尺寸 | 实际窗口像素尺寸 |
| 效果 | 世界铺满全屏；21:9 横向可见更多，4:3 纵向可见更多 |

### 层2 — UI 层（UI Layer）
| 属性 | 值 |
|------|-----|
| 坐标系 | 设计分辨率 1280×720 |
| 缩放策略 | FIT（保持比例，居中） |
| 效果 | UI 不变形，悬浮在世界层之上 |

**为什么无黑边**：世界层先铺满全屏，UI 层的 FIT "空白"区域已被世界内容填充，视觉上没有黑边。

---

## 实施步骤

### 步骤1：修改 TowerDefenseMin2 渲染管线（PDE）

**文件**：`examples/TowerDefenseMin2/TowerDefenseMin2.pde`、`TdAppCore.pde`

1. `draw()` 中**移除**全局 `pushMatrix → translate(offset) → scale(uniformScale) → popMatrix`
2. 在 `TdAppLoop.run()` 内部分层渲染：
   - 先渲染世界层（`worldViewport` 直接绘制到屏幕像素坐标，不经过全局缩放矩阵）
   - 再 `pushMatrix → FIT → 渲染其余 UI → popMatrix`
3. `TdAppUtils.syncCameraToWindow()` 改为同步到实际像素尺寸（而非设计分辨率）

### 步骤2：增强 WorldViewport 支持直接屏幕渲染

**文件**：`src/main/java/shenyf/p5engine/ui/WorldViewport.java`、`SceneViewport.java`

1. 新增 `renderDirect(PApplet, float screenX, float screenY, float screenW, float screenH)`
2. Buffer 大小使用传入的 `screenW × screenH`（实际像素），而非 `getWidth() × getHeight()`（设计分辨率）
3. `SceneViewport.renderContent()` 中相机视口设为实际像素尺寸
4. `paintSelf()` 保持原有行为（供 UI 树内部渲染时使用），`renderDirect()` 供分层渲染调用

### 步骤3：增强 DisplayManager — SafeArea 计算

**文件**：`src/main/java/shenyf/p5engine/rendering/DisplayManager.java`

1. 保留 FIT 模式（用于 UI 层）
2. 新增：
   - `getSafeAreaRect()` → 返回 FIT 区域（UI 安全渲染区域）
   - `getWorldAreaRect()` → 返回整个窗口区域（世界渲染区域）
   - `getScreenToDesign()` / `getDesignToScreen()` 便捷转换
3. 新增 `ScaleMode.ADAPTIVE`（运行时自动为 UI 选 FIT，为世界选 NO_SCALE）

### 步骤4：WindowManager — 动态分辨率枚举

**文件**：`src/main/java/shenyf/p5engine/core/WindowManager.java`

1. 新增 `ResolutionInfo` 数据类（width, height, refreshRate, bitDepth）
2. 新增 `listAvailableResolutions()`：
   - 使用 `GraphicsEnvironment.getLocalGraphicsEnvironment().getScreenDevices()`
   - 遍历 `getDisplayModes()`，去重、按分辨率排序
   - 返回 `List<ResolutionInfo>`
3. 新增 `applyResolution(ResolutionInfo)`：切换窗口/全屏分辨率

### 步骤5：DisplayConfig / P5Config — 动态分辨率支持

**文件**：`src/main/java/shenyf/p5engine/rendering/DisplayConfig.java`、`P5Config.java`

1. `ResolutionPreset` 保留固定预设，新增 `CUSTOM` 可传入任意 `ResolutionInfo`
2. `DisplayConfig` 支持 `availableResolutions(List<ResolutionInfo>)`
3. `P5Config` fluent API 支持 `.resolution(ResolutionInfo)` 和 `.resolutionPreset(ResolutionPreset)`

### 步骤6：UI 组件 — 锚点化布局

**文件**：`examples/TowerDefenseMin2/TdUiHud.pde`

将硬编码坐标的 UI 组件改为使用 `AnchorLayout` 锚点定位：

| 组件 | 当前硬编码 | 改为锚点 |
|------|-----------|---------|
| `TdTopBar` | `setBounds(0, 0, 1280, TOP_HUD)` | `STRETCH_TOP`（宽度填满安全区域） |
| `TdBuildPanel` | `setBounds(1280-RIGHT_W, TOP_HUD, ...)` | `STRETCH_RIGHT`（高度填满） |
| `TdMinimapComponent` | 绝对坐标 | `BOTTOM_RIGHT`（右下角） |

`AnchorLayout` 已存在于引擎中（`src/main/java/shenyf/p5engine/rendering/AnchorLayout.java`），支持 9 点锚点 + 5 种 stretch 模式，只需在 PDE 代码中使用即可。

### 步骤7：设置菜单 — 分辨率选择 UI

**文件**：`examples/TowerDefenseMin2/`（新增或修改现有设置面板）

1. 新增分辨率下拉框，数据源为 `WindowManager.listAvailableResolutions()`
2. 显示模式切换：窗口化 / 无边框全屏 / 独占全屏
3. 应用分辨率时调用 `WindowManager.applyResolution()`
4. 分辨率变更后触发 `windowResize` 回调，重新计算 `DisplayManager` 和 `Camera2D` 视口

---

## 验收标准

- [ ] 在 16:9、16:10、21:9、4:3 比例下运行，均无黑边
- [ ] UI 元素（TopBar、BuildPanel、Minimap）不变形、位置正确
- [ ] 世界内容铺满全屏，不同比例下可见范围自然调整
- [ ] 分辨率列表包含当前显示器的所有可用分辨率
- [ ] 切换分辨率后相机、UI、鼠标坐标均正确同步
- [ ] 编译验证：`compile-jar.ps1` + Processing CLI build 通过

## 相关文件

- `src/main/java/shenyf/p5engine/rendering/DisplayManager.java`
- `src/main/java/shenyf/p5engine/rendering/ScaleMode.java`
- `src/main/java/shenyf/p5engine/rendering/Camera2D.java`
- `src/main/java/shenyf/p5engine/ui/WorldViewport.java`
- `src/main/java/shenyf/p5engine/ui/SceneViewport.java`
- `src/main/java/shenyf/p5engine/core/WindowManager.java`
- `src/main/java/shenyf/p5engine/rendering/DisplayConfig.java`
- `src/main/java/shenyf/p5engine/core/P5Config.java`
- `examples/TowerDefenseMin2/TowerDefenseMin2.pde`
- `examples/TowerDefenseMin2/TdAppCore.pde`
- `examples/TowerDefenseMin2/TdUiHud.pde`
- `examples/TowerDefenseMin2/TdAppUtils.pde`

## 技术备注

- **JOGL NEWT 限制**：`setResizable()` 仍须在 PDE `setup()` 中调用，避免 EDT 死锁
- **Buffer 尺寸上限**：`WorldViewport.ensureBuffer()` 已有 4096 像素上限保护
- **P2D fill/stroke 状态冲突**：`WorldViewport` 已使用 `pushStyle()/popStyle()` 隔离
- **PDE 内部类**：所有 UI 组件在 PDE 中定义为 `static class`，需注意 static 方法中 `new` 需 enclosing instance
