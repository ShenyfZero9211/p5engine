# 任务简报界面重构与 ScrollPane 引擎增强

## 问题描述
1. 任务简报文本硬编码在 `data/i18n/zh.json` 和 `en.json` 中，关卡策划修改不便。
2. 简报界面 `Window` 无背景边框，视觉层级单薄。
3. 简报 `Label` 固定高度 240px，长文本直接截断，无法翻阅。
4. 引擎层 `ScrollPane` 仅支持鼠标滚轮，滚动条 thumb 不可拖拽交互。

## 根本原因
- 内容管理：i18n JSON 不适合存放大段多行文本，且需要转义换行符。
- UI 设计：`showBriefing()` 中 `Window.setPaintBackground(false)` 屏蔽了主题背景绘制。
- 引擎能力：`ScrollPane.onEvent()` 只处理了 `MOUSE_WHEEL`，缺少 `MOUSE_PRESSED/DRAGGED/RELEASED` 的 thumb 拖拽逻辑。

## 修复内容

### 1. 独立 briefing 文本文件
- 新建 `data/config/levels/brief/` 目录。
- 从 `zh.json` 提取 level 1~4 的中文 briefing，创建 `level_1.txt` ~ `level_4.txt`。
- 为 level 5~10 创建占位文件。
- `levels.yaml` 每关新增 `briefFile` 字段索引对应 txt。

### 2. TdAssets 加载回退
- 新增 `TdAssets.loadBriefingText(int levelId)`：
  - 解析 `levels.yaml` 获取 `briefFile` 路径。
  - 使用 `createInput()` + `BufferedReader(UTF-8)` 读取文本。
  - 加载失败或文件不存在时，自动回退到 i18n 键 `level.{id}.briefing`，保证英文等多语言场景不崩溃。

### 3. 简报界面视觉与交互重构（TdFlow.showBriefing）
- **背景边框**：`win.setPaintBackground(true)`，启用 `TdTheme.drawWindowChrome()` 的深蓝面板背景与青色边框。
- **可滚动文本区**：
  - 使用 `ScrollPane`（480×240）替换固定高度 `Label`。
  - 内部 `Label` 设置 `wrapWidth = 460`，通过 `estimateBriefingHeight()`（基于 `textSize(14)` 与换行算法）动态计算内容高度。
  - `ScrollPane.getViewport().setSize()` 设为内容高度，确保 `ScrollPane.layout()` 能正确检测溢出并渲染滚动条。
  - `viewport.setPaintBackground(false)` 避免双重背景叠加。

### 4. 引擎层 ScrollPane 增强（Java）
- **提取 thumb 几何计算**：新增私有内部类 `ThumbMetrics` 与方法 `calcThumbMetrics(float viewH)`，`paint()` 与交互检测共用同一逻辑，避免漂移。
- **状态字段**：`draggingBar`、`dragStartMouseY`、`dragStartScrollY`、`barHover`。
- **命中检测**：`isOverThumb()` 精确判断鼠标是否在 thumb 区域内（非整个槽道）。
- **事件增强**：
  - `MOUSE_PRESSED`：命中 thumb 时记录拖拽起点，消费事件。
  - `MOUSE_DRAGGED`：按 `(deltaMouse / trackLen) * maxScroll` 比例映射 scrollY，边界 clamp 到 `[0, maxScrollY]`。
  - `MOUSE_RELEASED`：清除拖拽态。
  - `hitTest` 中同步更新 `barHover`。
- **渲染反馈**：`theme.drawScrollBar()` 的 `hover` 参数传 `barHover || draggingBar`，thumb 悬停/拖拽时高亮。
- **扩展性**：所有新增字段均为 `private`，外部调用方式不变；垂直滚动条逻辑已封装为私有方法，未来可对称扩展水平滚动条。

## 验证结果
- `compile-jar.ps1` 编译通过 ✅
- `library\p5engine.jar` 已复制到 `examples\TowerDefenseMin2\code\` ✅
- Processing CLI build 通过 ✅

## 相关文件
- `src/main/java/shenyf/p5engine/ui/ScrollPane.java`
- `examples/TowerDefenseMin2/data/config/levels/levels.yaml`
- `examples/TowerDefenseMin2/data/config/levels/brief/level_*.txt`
- `examples/TowerDefenseMin2/TdAssets.pde`
- `examples/TowerDefenseMin2/TdFlow.pde`
