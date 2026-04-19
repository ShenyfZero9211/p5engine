# p5engine UI 系统：开发经过、特点、使用技巧与 Agent 指南

本文档总结 `shenyf.p5engine.ui` 包的设计与落地过程，面向人类维护者与 **AI 编程助手（Agent）** 使用。

---

## 1. 背景与目标

在 Processing 库 **p5engine** 中增加一套 **游戏向 / 工具向** 的轻量 UI：不依赖 Swing/JavaFX，直接在 `PApplet` 上绘制与处理输入，便于与现有 `P5Engine` 循环（`update` / `draw`）集成。

设计目标包括：

- **类名与包结构清晰**（`Button`、`Window`、`Theme` 等），与早期草稿中的 `Ui*` 命名脱钩，**不提供旧名兼容层**。
- **内部保留组件树**（便于布局、焦点、裁剪、状态），**对外支持「每帧声明」的池化 API**（稳定字符串 ID 复用控件实例）。
- **单路径输入与绘制**：命中测试、焦点、拖拽、主题绘制顺序确定，避免难以复现的竞态。
- **可替换主题**：`Theme` 接口 + `DefaultTheme` 默认实现，控件只负责状态与逻辑，外观集中在主题。

源码根目录：`src/main/java/shenyf/p5engine/ui/`。  
构建入口：仓库根目录 `sources.txt` + `compile-jar.ps1`（默认会覆盖 Processing 库目录下的 `p5engine.jar`，见脚本内说明）。

---

## 2. 开发经过（概要时间线）

### 2.1 基线与清理

- 仓库中原 `sources.txt` 曾引用不存在的 `UiButton`、`UiTheme` 等路径；实际实现统一为 **新类名** 下的 Java 源文件，并 **重写 `sources.txt` 列表**，保证 `javac @sources.txt` 可重复通过。
- 引擎主体 `P5Engine` **不内置** UI 子系统；UI 通过用户在 sketch 中创建 `UIManager` 并调用 `attach/update/render` 接入。

### 2.2 分层实现顺序（与计划一致）

1. **核心抽象**：`UIComponent`、`Container`、`UIEvent`、`LayoutManager`、`Theme`、`DefaultTheme`。
2. **布局器**：`AbsoluteLayout`、`FlowLayout`、`GridLayout`、`BorderLayout`（`BorderLayout` 使用字符串约束常量，如 `BorderLayout.CENTER`）。
3. **管理器**：`FocusManager`、`DragManager`、`UIManager`（注册 `mouseEvent` / `keyEvent`，驱动布局脏检测与池化帧）。
4. **容器**：`Panel`、`Frame`、`Window`、`ScrollPane`、`TabPane`。
5. **控件**：交互类与展示类；其中 `List` 为控件类名（与 `java.util.List` 区分，代码中集合类型多写全限定名或 `ArrayList`）。
6. **菜单条**：`MenuBar` / `Menu` / `MenuPopup`（单下拉、单开菜单），见 [3.5 MenuBar 与 MenuPopup](#35-menubar-与-menupopup)。
7. **HiDPI**：`P5Engine.applyRecommendedPixelDensity(this)` 仅在 `settings()`、`size` 之后，见 [3.7 HiDPI 与像素密度](#37-hidpi-与像素密度文字--细线清晰度)。
8. **示例**：`examples/UIDemo/UIDemo.pde` 覆盖主要控件与布局；后续迭代增加第二窗口、布局 Tab、池化按钮等。

### 2.3 迭代中修复的典型问题

| 问题 | 处理 |
|------|------|
| Sketch 无法调用 `protected` 的 `markLayoutDirtyUp()` | 对外提供 `public void invalidateLayout()`，内部仍用 `markLayoutDirtyUp()` 冒泡脏标记。 |
| Processing 默认字体下中文显示为方框 | Demo 与主题示例优先使用 **ASCII 文案**；若需中文需自行 `createFont` / `textFont` 并在 `Theme` 中统一设置。 |
| `TextInput` 光标不随左右键移动 | `Theme.drawTextField` 增加 **`caretIndex`**，用前缀子串的 `textWidth` 画插入线；点击定位光标依赖 `PApplet` 与 `textSize` 一致，必要时通过 `UIManager.getActiveApplet()` 兜底。 |
| `ScrollPane` 裁剪 API | 使用 `clip` / `noClip`（避免使用不存在的 `pushClip`/`popClip`）。 |

---

## 3. 架构特点

### 3.1 双模式：保留树 + 池化即时声明

- **保留模式**：在 `setup` 或初始化逻辑里 `new Window(...)`、`add(...)`，树结构长期存在。
- **池化模式**：每帧（通常在 `draw` 开头）`ui.beginFrame()` → 多次 `ui.button("id")` 等 → `ui.endFrame()`。  
  - 本帧通过工厂方法访问过的 ID 记入 `frameSeen`；**未再出现的池内控件会从父节点移除并从池中删除**，避免泄漏与幽灵控件。
  - 首次创建的池控件若父为空，会被 **`ensureOnRoot` 挂到 `UIManager` 根 `Panel`** 下；注意与手动构建的树 **并存时的 z-order**（见技巧）。

### 3.2 坐标系

- 子组件的 `(x, y, width, height)` 相对于 **父容器的内容区**（扣除 `Container.Insets`）。
- 屏幕/画布坐标使用 `getAbsoluteX()` / `getAbsoluteY()`，沿父链累加 **内容区偏移**（`getContentOffsetX/Y`）与子坐标。

### 3.3 布局与脏标记

- 尺寸或结构变化会 `invalidateLayout()`（或内部 `markLayoutDirtyUp()`），向上冒泡至根。
- `UIManager.update(dt)` 中若根 `isLayoutDirty()`，对根执行 **`measure` → `layout`**（子类如 `ScrollPane`、`TabPane` 重写布局与绘制行为）。

### 3.4 输入与事件

- `UIEvent` 封装鼠标按下/抬起/拖拽、键盘、滚轮（`MOUSE_WHEEL` + `scrollDelta`）、焦点等。
- 鼠标事件：自顶向下 `hitTest`，再按需在 **按下目标** 上派发 `RELEASED`/`DRAGGED` 等。
- **Tab** 在 `KEY_PRESSED` 中切换焦点（`FocusManager.focusNext/Previous`）。
- **Window** 标题栏命中 + 左键拖拽走 `DragManager`。
- **ScrollPane / List** 可消费滚轮事件。

**与 `P5Engine` 的键盘竞争**：`P5Engine` 与 `UIManager` 都会在 `PApplet` 上注册 `keyEvent`，引擎层尚未规定统一消费顺序。工具类 sketch（如画布快捷键 + `TextInput`）需在 sketch 层约定策略；示例与说明见 [`docs/ImageLab-README.md`](ImageLab-README.md) 与 `examples/ImageLab/DEFECTS.md`（D-UI-001）。

### 3.5 MenuBar 与 MenuPopup

- **`MenuBar`**：横向一排 `Menu`；内部共享一个 **`MenuPopup`**（高 `zOrder`），任意时刻最多展开一个菜单。`addMenu(String title)` 返回 `Menu`，链式 `menu.addItem("Label", runnable)` 或 `addItem(..., false)` 禁用项。
- **`UIManager.menuBar(id)`**：与 `button`/`panel` 相同池化语义；也可在 sketch 中 `new MenuBar(id)` 后手动 `parent.add(menuBar)`。
- **主题**：`Theme` 提供 `default` 的 `drawMenuTitle` / `drawMenuPopupBackground` / `drawMenuItem`（委托 `drawButton`/`drawPanel`）；`DefaultTheme` 可覆盖以微调菜单顶钮「打开」态等。
- **布局**：`MenuBar` 在 `layout` 阶段根据当前打开菜单的标题按钮 `getAbsoluteX/Y` 放置 `MenuPopup`，并对右、下边界用 `PApplet.width/height` 做简单夹紧。根布局为 `null` 时，请在本帧已对 `MenuBar` 调用 `setBounds` 之后再进入 `UIManager.update`（与 `examples/ImageLab/ImageLab.pde` 一致），否则绝对坐标不准。
- **与同级工具条的叠绘**：下拉画在菜单栏子树里，会伸到父容器内其它兄弟区域（例如 `BorderLayout` 里 NORTH 菜单 + CENTER 工具条）。兄弟间 `zOrder` 相同时后添加的子控件后绘制，会盖住弹出层。**首次打开**菜单时 `MenuBar` 会把自身 `zOrder` 提到高于当前父节点下所有兄弟，**关闭弹出**后恢复原 `zOrder`（绘制与 `hitTest` 一致）。
- **命中**：下拉在几何上常超出 `MenuBar` 自身高度（面板只包住标题行）。`MenuBar` 对可见的 `MenuPopup` **先于**本栏 `containsPoint` 做 `hitTest`；否则点击会落到下层兄弟（如第二行工具条），项上的 `Runnable` 不会执行。
- **在 sketch 中关闭菜单**：`MenuBar.closePopupsIfClickOutside(mx, my)` 在点击落在弹出层与所有菜单标题之外时关闭并返回 `true`；典型用法是在 `mousePressed` 开头调用，若返回 `true` 则 `return` 以避免同帧画布逻辑与菜单竞争。
- **与侧栏叠绘**：若根下既有全宽 `topChrome` 又有左侧 `west` 条，且下拉会延伸到两者重叠的竖条区域，请为 **`topChrome` 设置高于 `westStrip` 的 `zOrder`**，避免侧栏盖住下拉（见 ImageLab）。

### 3.6 绘制与焦点高亮

- `UIManager.render()` 设置静态绘制上下文，供 `TextInput`、`List`、`TabPane` 等通过 **`UIManager.isPaintingContext(component)`** 判断是否「当前键盘焦点在此控件」，以绘制高亮边框或插入符。
- 主题方法接收几何与状态参数，避免 `Theme` 与具体控件类型强耦合。

### 3.7 HiDPI 与像素密度（文字 / 细线清晰度）

在 **125%/150% Windows 缩放** 或 **macOS Retina** 上，若未匹配物理像素，整帧（含 UI 文字与 1px 边框）可能被系统放大而显得发糊。

- **做法**：在 sketch 的 **`settings()`** 里、**`size(...)` / `fullScreen(...)` 之后** 调用 **`P5Engine.applyRecommendedPixelDensity(this)`**（等价于 `pixelDensity(max(displayDensity(), 1))`）。**不要**放在 `setup()` 或 `P5Engine.create(this)` 之后——Processing 要求此时机，晚调常无效。
- **仍糊（尤其 Windows 125%/150%）**：可先试 **`size(..., P2D)`** 与在 **`settings()`** 里 **`smooth(...)`**（勿把 **`smooth()`** 放在 **`setup()`**，否则预处理器会再生成一个 **`settings()`** 导致重复方法错误）。**`pixelDensity` 不得超过 `displayDensity()`**：若系统报 **`pixelDensity(2) is not available for this display`**，说明当前显示器/驱动只接受密度 1，勿再强制 2（会缩小窗口）。两参数 **`applyRecommendedPixelDensity(this, n)`** 在 **`n > displayDensity()`** 时会退回单参数行为并打 **`WARN`**。
- **坐标**：`width` / `height` 与 `mouseX` / `mouseY`、`UIManager` 的 `hitTest` 仍按 **逻辑像素** 工作；缓冲区分辨率由 `pixelWidth` / `pixelHeight` 体现。可在 `setup()` 里 **`println(pixelWidth, width)`** 自查：`pixelWidth` 应约为 **`width * pixelDensity`**。
- **代价**：帧缓冲约为 `pixelDensity²` 倍内存；超大 `size()` 时自行权衡。
- **多屏**：`displayDensity()` 与窗口所在显示器可能不完全一致，属 Processing/OS 行为。
- **渲染器**：主画布用 **`P2D`/`P3D`** 时文字/线框常比默认 **JAVA2D** 更利落，但与显卡驱动相关；`smooth()` 可在 `setup()` 中调节。离屏 `PGraphics` 仍可单独选 `JAVA2D`（见 ImageLab 编辑层）。

---

## 4. 类与职责一览（速查）

| 类别 | 类名 | 说明 |
|------|------|------|
| 根抽象 | `UIComponent` | 边界、可见、启用、z-order、焦点、`paint`/`onEvent`/`hitTest` |
| 容器 | `Container` | 子列表、`Insets`、`LayoutManager`、统一 `measure`/`layout` |
| 布局 | `AbsoluteLayout` | 子控件自行 `setBounds` |
| | `FlowLayout` | 流式排布，可选换行 |
| | `GridLayout` | 近似网格划分单元格 |
| | `BorderLayout` | 五区约束字符串常量 |
| 容器控件 | `Panel` | 带面板背景绘制 |
| | `Frame` | 线框式内容框 |
| | `Window` | 标题栏 + 内容区 insets，可标题栏拖拽 |
| | `ScrollPane` | 视口 + 竖条滚动 + 裁剪 |
| | `TabPane` | 页签头 + 单页可见 |
| 交互控件 | `Button`、`Checkbox`、`RadioButton`、`Slider`、`ScrollBar`、`TextInput`、`List` | 各自 `onEvent`/`update` |
| | `MenuBar`、`Menu`（+ 内部 `MenuPopup`） | 顶栏菜单与单例下拉 |
| 展示 | `Label`、`Image`、`ProgressBar` | 轻量绘制 |
| 管理 | `UIManager` | 根面板、主题、焦点、拖拽、池、Processing 事件桥 |
| | `FocusManager`、`DragManager` | 焦点链与标题栏拖拽位移 |
| 主题 | `Theme`、`DefaultTheme` | 所有控件的默认外观 |
| 核心（非 UI 包） | `P5Engine` | `create` / 时间 / 渲染；HiDPI 用 `applyRecommendedPixelDensity`，见 §3.7 |

---

## 5. 使用技巧（面向 sketch 作者）

### 5.1 最小集成循环

```text
setup:  new UIManager(this);  ui.attach();
draw:   background(...);
        ui.update(deltaTime);   // 例如 engine.getGameTime().getDeltaTime()
        ui.render();
```

- 若同时使用 **`P5Engine`**：在 **`settings()`** 里 **`size(...)` 之后** 调用 **`P5Engine.applyRecommendedPixelDensity(this)`**（§3.7），再于 `setup()` 中 `P5Engine.create(this)`。

### 5.2 在 sketch 中修改树之后

- 调用 **`someContainer.invalidateLayout()`**（勿在 sketch 中调用 `protected` 方法）。

### 5.3 池化与保留树混用

- **同一帧**内若使用 `beginFrame`/`endFrame`，则本帧仍要出现的池 ID **必须**再次通过 `ui.button(id)` 等访问，否则会被回收。
- 池控件默认挂 **`ui.getRoot()`**；与 `new Window` 等并列时，用 **`setZOrder`** 控制叠放顺序（数值大后绘制、在上层）。

### 5.4 `BorderLayout` 约束

- 使用 `BorderLayout.NORTH` 等 **字符串常量** 作为 `add(child, constraint)` 的第二参数。

### 5.5 `ScrollPane` 与 `List`

- 内容加在 **`scrollPane.getViewport()`** 上；大内容可 `setBounds` 超出视口高度以触发滚动。
- `List` 滚轮与选中行依赖内部行高常量，Demo 中已展示基本用法。

### 5.6 `RadioButton` 分组

- 同一 `groupId` 内互斥；组选中状态为静态映射，注意 **跨 sketch 重启** 时若需清空应自行扩展 API（当前为演示级实现）。

### 5.7 文本与国际化

- 默认主题使用 Processing 默认字体绘制英文较稳；中文需自行加载字体并在绘制前 `textFont`，或扩展 `Theme` 在 `drawLabel`/`drawButton` 等处统一设字体。

### 5.8 编译与 Processing 库同步

- 修改 `src/main/java` 后执行仓库根目录 **`compile-jar.ps1`**（默认覆盖 `E:\projects\processing_env\libraries\p5engine\library\p5engine.jar`，详见脚本注释）。仅验证本地 jar 可用 **`-NoCopy`**。

---

## 6. 专章：供 AI Agent 如何使用本 UI 系统

本章面向 **Cursor / 其他 AI 编程 Agent**：在 p5engine 仓库内接到「改 UI / 加界面 / 修交互」类任务时，建议按下列约定执行，减少返工与安全风险。

### 6.1 接到任务后应先读什么

1. **本文件**（全局约定与坑）。
2. **拟修改或扩展的类**：`src/main/java/shenyf/p5engine/ui/<ClassName>.java`。
3. **入口与事件总线**：`UIManager.java`（鼠标/键盘/池化帧/根布局）。
4. **示例**：`examples/UIDemo/UIDemo.pde`（集成方式、常见布局组合）。
5. **构建清单**：`sources.txt`（新增 `.java` 必须追加路径，否则 jar 不包含）。

### 6.2 修改代码时的硬性检查清单

- **可见性**：Sketch 默认包 **不能**调用 `UIComponent` 的 `protected` 方法；对外扩展 API 请用 **`public`**（例如已有 `invalidateLayout()`）。
- **新增类**：必须加入 **`sources.txt`**，并建议在本文件或 README 中补一行类表（若用户要求文档）。
- **编译验证**：Java 变更后应运行 **`compile-jar.ps1`**（除非用户明确要求不打包）；与用户约定「默认覆盖 Processing 库 jar」时 **不要擅自加 `-NoCopy`**。
- **命名冲突**：控件类名 `List`、`Image` 与 JDK/AWT 或习惯用法易混；新增代码中 `java.util.List` 与 `shenyf.p5engine.ui.List` 注意 **import 与全限定名**。
- **Processing API 版本**：使用 `javac` 所针对的 `core-x.x.x.jar` 中 **确实存在** 的 API（例如裁剪用 `clip`/`noClip`）。
- **主题签名变更**：若修改 `Theme` 接口，必须 **同步** 所有实现类（当前为 `DefaultTheme`）及所有调用点。

### 6.3 Agent 应优先采用的实现策略

- **小步修改**：单 PR/单次提交聚焦一个交互点（例如只修 `TextInput` 光标），避免大面积重排与无关格式化。
- **行为放在控件或 UIManager 一侧**：避免在 sketch 里复制复杂命中逻辑；若通用，提炼到 `UIComponent` 子类或 `UIManager` 私有方法。
- **状态单一来源**：例如 `TextInput` 的 `caretIndex` 仅由控件自身与 `onEvent` 修改；绘制只读该字段。
- **池化 ID 稳定**：池化模式下 ID 必须是 **稳定字符串**（常量或枚举名），禁止每帧 `random` 或拼接帧号作为 ID，否则等价于每帧泄漏式创建。

### 6.4 Agent 应避免的反模式

- 在 sketch 中调用 **`markLayoutDirtyUp()`** 等 `protected`/`package` 方法（会编译失败）。
- 在未同步 `sources.txt` / 未编译 jar 的情况下，声称「已可在 Processing 中验证」。
- 为「工业感」引入 **过重抽象**（事件总线插件化、反射扫描等）而不经用户明确要求。
- 在 `Theme` 中 **硬编码业务字符串**（应来自控件或外部配置）。

### 6.5 与用户沟通时的建议话术

- 明确说明：**改了哪些 Java 文件、是否已更新 `sources.txt`、是否已执行 `compile-jar.ps1`**。
- 若涉及中文显示：主动说明 **默认主题 + 默认字体** 的局限，并给出「加载字体 + `textFont`」或「英文文案」两种可选路径。
- 若同时使用 **池化** 与 **手动构建树**：提醒用户注意 **`beginFrame`/`endFrame` 回收规则** 与 **`zOrder`**。

### 6.6 推荐的任务分解模板（Agent 自用）

1. 复现路径：UIDemo 或用户 sketch 最小步骤。  
2. 定位：`UIManager` / 具体控件 / `Theme` 哪一层。  
3. 修改 + `sources.txt`（若新增文件）。  
4. 本地 `javac` 或 `compile-jar.ps1` 通过。  
5. 向用户交付：**行为变化说明**、**是否需要重装库 jar**、**已知限制**。

---

## 7. 参考路径（仓库内）

| 用途 | 路径 |
|------|------|
| UI 源码 | `src/main/java/shenyf/p5engine/ui/` |
| 编译列表 | `sources.txt` |
| 打包脚本 | `compile-jar.ps1` |
| 输出 jar | `library/p5engine.jar` |
| 示例 sketch | `examples/UIDemo/UIDemo.pde` |

---

*文档版本：与当前仓库实现一致；若 API 变更，请同步更新本章「检查清单」与路径表。*
