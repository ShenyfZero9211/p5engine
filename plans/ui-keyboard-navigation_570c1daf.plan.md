# UI Keyboard Navigation Research & Enhancement Plan

## 目标
为 p5engine 的轻量级 UI 系统引入完整的键盘导航支持（方向键 + Tab/Shift+Tab），提升游戏的可访问性和手柄适配能力。

## 背景
当前 p5engine 的 UI 系统已有基础焦点管理：
- `FocusManager` 维护全局单一焦点组件
- 支持 Tab/Shift+Tab 按容器树文档顺序循环切换
- 键盘事件直接派发给当前焦点组件
- **缺失**：方向键导航、显式邻居配置、焦点视觉反馈标准化

## 调研结果：主流引擎/框架的键盘导航实现

### 1. Godot Engine — 显式邻居 + 空间回退
| 维度 | 实现方式 |
|------|----------|
| 焦点追踪 | 每个 Control 节点可拥有焦点，Viewport 维护当前焦点持有者 |
| Tab 导航 | `focus_next` / `focus_previous` 显式 NodePath；未设置时按场景树顺序猜测 |
| 方向键导航 | `focus_neighbor_left/right/top/bottom` 显式 NodePath；未设置时按**空间最近**算法自动查找 |
| 焦点视觉 | `focus_entered` / `focus_exited` 信号驱动；控件自行绘制高亮 |
| 事件分发 | `_gui_input()` 事件驱动；方向键映射为 `ui_left`/`ui_right`/`ui_up`/`ui_down` 动作 |
| API 设计 | 声明式属性（Inspector 中设置邻居路径）+ 命令式 `grab_focus()` |

**优点**：控制器/手柄导航原生支持；自动空间搜索对简单布局够用；显式邻居可精确控制复杂菜单。
**缺点**：自动空间搜索在复杂非对齐布局下可能猜错（需显式覆盖）。

### 2. Unity uGUI — 导航模式枚举
| 维度 | 实现方式 |
|------|----------|
| 焦点追踪 | 全局 `EventSystem.current.SetSelectedGameObject()` |
| Tab 导航 | Navigation.Mode: `None`/`Horizontal`/`Vertical`/`Automatic`/`Explicit` |
| 方向键导航 | 与 Tab 共用 Navigation 配置；`Automatic` 按几何位置+重叠面积计算；`Explicit` 逐个指定 |
| 焦点视觉 | Selectable 组件的 `selected` 状态触发过渡动画（颜色/精灵缩放） |
| 事件分发 | IPointerClickHandler / ISelectHandler / IDeselectHandler 接口回调 |
| API 设计 | Inspector 可视化连线 + 脚本设置 `Selectable.navigation` |

**优点**：`Automatic` 模式对网格/列表布局效果很好；可视化调试（Visualize）。
**缺点**：`Automatic` 算法是黑箱，特殊布局常需切到 `Explicit` 手动配置。

### 3. Dear ImGui — 全局即时模式导航
| 维度 | 实现方式 |
|------|----------|
| 焦点追踪 | 全局 `NavId`（窗口作用域内唯一 ID），无持久组件对象 |
| Tab/方向键 | 开启 `NavEnableKeyboard` 后**自动工作**；Tab 按声明顺序，方向键按空间位置 |
| 焦点视觉 | 框架统一绘制 focus rectangle（可配置颜色/粗细） |
| 事件分发 | 即时模式：每帧 `ImGui::Button()` 内部判断 `ImGuiItemFlags_NavFlattened` |
| API 设计 | 全局开关 + 少量 push/pop 标志（如 `ImGui::SetItemDefaultFocus()`） |

**优点**：零配置对大多数布局有效；统一视觉反馈；极轻量。
**缺点**：需要 IMGUI 编程模型；对非矩形/重叠布局控制有限。

### 4. libGDX Scene2D — 最小化焦点 + 第三方扩展
| 维度 | 实现方式 |
|------|----------|
| 焦点追踪 | `Stage.setKeyboardFocus(actor)` 单焦点 |
| Tab/方向键 | **原生不支持**；需第三方库 `gdx-controllerutils` 或自实现 InputProcessor 拦截方向键 |
| 焦点视觉 | 无内置；需监听 `FocusEvent` 自行绘制 |
| 事件分发 | `InputListener.keyDown()`（仅焦点 Actor 接收） |
| API 设计 | 命令式 `setKeyboardFocus()` |

**结论**：libGDX 因过于轻量化反而需要大量自实现，不适合作为 p5engine 的参考目标。

### 5. WPF / WinUI — TabIndex + XYFocus
| 维度 | 实现方式 |
|------|----------|
| 焦点追踪 | 可视化树中的单一焦点元素 |
| Tab 导航 | `TabIndex` 整数排序 + `IsTabStop`；`KeyboardNavigationMode` (Continue/Local/Cycle/Once) |
| 方向键导航 | `XYFocusKeyboardNavigation="Enabled"` 时按空间位置导航 |
| 焦点视觉 | 系统/主题统一 `FocusVisualStyle`（虚线边框） |
| 事件分发 | 冒泡/隧道路由事件 |
| API 设计 | 声明式 XAML 附加属性 |

**优点**：TabIndex 精确控制；容器级导航模式（Local/Cycle）适合嵌套对话框。
**缺点**：API 重量级；对游戏引擎来说过于复杂。

---

## 推荐方案：Godot 式显式邻居 + 空间自动搜索（混合模式）

针对 p5engine 的轻量级定位和现有架构，推荐在现有 `FocusManager` 基础上进行最小扩展：

### 核心设计
1. **保持全局焦点管理**（现有 `FocusManager.focused` 不变）
2. **Tab 导航增强**：保留现有文档顺序，新增 `tabIndex` 整数字段覆盖默认顺序（类似 WPF）
3. **方向键导航**：新增空间自动搜索算法（类似 Godot/Unity Automatic）+ 可选显式邻居（类似 Godot `focus_neighbor_*`）
4. **焦点视觉**：主题层统一支持 `drawFocusRing(applet, x, y, w, h)`，组件通过 `isFocused()` 判断
5. **事件分发**：保持现有直接派发模型（键盘事件直送焦点组件）

### 新增 API（最小化）
```java
// UIComponent.java
public void setTabIndex(int tabIndex);
public int getTabIndex();
public void setFocusNeighbor(Direction dir, UIComponent neighbor); // 显式邻居
public UIComponent getFocusNeighbor(Direction dir);
public boolean isFocused(); // 快捷判断

// FocusManager.java
public void focusUp/Down/Left/Right(Container root); // 方向键导航入口

// Direction enum
UP, DOWN, LEFT, RIGHT
```

### 空间搜索算法（方向键回退）
当显式邻居未设置时，遍历所有可见/可聚焦组件，筛选位于当前组件目标方向扇形区域内的候选，取屏幕中心距离最近者。这是 Godot 和 Unity Automatic 的共同策略。

### 焦点视觉
- `DefaultTheme` 新增 `drawFocusRing()`：绘制 2px 主题色外框 + 2px 间隙
- `Button`/`Checkbox`/`RadioButton`/`Slider`/`TextInput` 等交互组件在 `paint()` 中补充焦点环
- 非交互组件（`Label`/`Image`/`Panel`）默认 `focusable = false`，不参与导航

## 实施步骤
1. 新增 `Direction` 枚举；扩展 `UIComponent` 添加 `tabIndex` 和显式邻居字段
2. 扩展 `FocusManager`：新增 `focusDirection()` 方法（显式邻居优先 → 空间搜索回退）
3. 扩展 `UIManager.keyEvent()`：拦截方向键，调用 `focusManager.focusDirection()`
4. 扩展 `Theme` / `DefaultTheme`：新增 `drawFocusRing()` 方法
5. 修改交互组件（Button、Checkbox 等）：在 paint 中调用 focus ring 绘制
6. 示例工程验证：在 HelloWorld 或 ConfigTest 中添加纯键盘可操作的菜单

## 验收标准
- [ ] Tab/Shift+Tab 可按 `tabIndex` 顺序导航（未设置则按文档顺序）
- [ ] 方向键可在可见可聚焦组件间按空间位置导航
- [ ] 显式设置 `setFocusNeighbor(Direction.LEFT, otherBtn)` 后方向键优先走显式链路
- [ ] 焦点组件有清晰的视觉反馈（主题色 focus ring）
- [ ] 隐藏或禁用的组件自动被跳过
- [ ] 编译通过，现有示例不受影响

## 相关文件
- `src/main/java/shenyf/p5engine/ui/FocusManager.java`
- `src/main/java/shenyf/p5engine/ui/UIComponent.java`
- `src/main/java/shenyf/p5engine/ui/UIManager.java`
- `src/main/java/shenyf/p5engine/ui/Theme.java`
- `src/main/java/shenyf/p5engine/ui/DefaultTheme.java`
- `src/main/java/shenyf/p5engine/ui/Button.java`
- `src/main/java/shenyf/p5engine/ui/Checkbox.java`
- `src/main/java/shenyf/p5engine/ui/RadioButton.java`
- `src/main/java/shenyf/p5engine/ui/Slider.java`
- `src/main/java/shenyf/p5engine/ui/TextInput.java`
- `examples/HelloWorld/HelloWorld.pde`
