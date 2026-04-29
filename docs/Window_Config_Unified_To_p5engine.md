# window_size / window_position 统一归 p5engine.ini 管理

## 变更概述
`window_size` 和 `window_position` 从"引擎 + 开发程序双轨管理"改为"引擎单一管理"。开发程序（TowerDefenseMin2）不再在 `TowerDefenseMin2.ini` 中维护窗口配置，所有持久化、读取、恢复由 `p5engine.ini` 统一负责。

## 核心改动

### 引擎层

**1. `P5Config.java` — 移除 `autoManageWindowState`**
窗口状态始终由引擎自动管理，开发程序不再干预。移除了 `autoManageWindowState(boolean)` 和 `isAutoManageWindowState()` 方法。

**2. `P5Engine.init()` — 区分"未保存"与"已保存"**
原来使用 `sketchConfig.getWindowWidth()`（键不存在时返回默认值 800），导致 `P5Config` 的默认值（如 1280×720）被引擎默认值 800×600 覆盖。

改为使用 `sketchConfig.get(SECTION, KEY)`（键不存在时返回 null）：
```java
String savedW = sketchConfig.get(SECTION_WINDOW_SIZE, KEY_WIDTH);
if (savedW != null) {
    config.width(Integer.parseInt(savedW));
}
```
这样 `P5Config` 的默认值只在首次运行时生效。

**3. `P5Engine.destroy()` — 全屏退出时保存窗口模式尺寸**
原来全屏退出时保存 `applet.width=3440` 到 `p5engine.ini`，下次启动窗口初始化为 3440×1440，再 `toggleFullscreen()` 重复全屏，导致启动闪烁。

改为检测当前是否全屏，如果是，使用 `WindowManager` 保存的窗口状态：
```java
if (windowManager != null && windowManager.isFullscreen()) {
    int[] savedSize = windowManager.getSavedWindowSize();
    sketchConfig.setWindowSize(savedSize[0], savedSize[1]);
}
```

**4. `WindowManager.java` — 暴露保存的窗口状态**
添加公共方法：
```java
public int[] getSavedWindowSize() { return new int[]{savedW, savedH}; }
public int[] getSavedWindowPosition() { return new int[]{savedX, savedY}; }
```

### 开发程序层

**1. `TdSaveData.pde` — 移除窗口配置**
删除了 `getWindowWidth()`、`getWindowHeight()`、`setWindowSize()`、`getWindowX()`、`getWindowY()`、`setWindowPosition()`。`load()` 中不再初始化 `window_size` 和 `window_position`。

**2. `TdAppCore.pde` — 简化 `TdAppSetup.run()`**
- 移除了 `ownManaged` 分支逻辑
- 移除了 `winW`/`winH`/`winX`/`winY` 的读取
- `P5Config` 不再手动设置 `.width()` / `.height()` / `.windowPosition()` / `.windowedSize()`
- 移除了 dispose listener 中保存窗口状态的代码
- 保留 `engine.centerWindow()`（当 `p5engine.ini` 没有位置时显式居中）

**3. `TdFlow.pde` — 分辨率切换**
移除了 `TdSaveData.setWindowSize(targetW, targetH)`，引擎在 `destroy()` 时自动保存。

**4. `TowerDefenseMin2.pde` — `settings()`**
- 移除了从 `TowerDefenseMin2.ini` 读取窗口尺寸的代码
- `P5Config` 通过 `.width(1280).height(720)` 设置默认偏好

## 验证结果

### 全屏模式测试
```
Window: 1280x720
WindowManager: switching WINDOWED -> BORDERLESS_FULLSCREEN
WindowManager: borderless fullscreen 3440x1440 @ 0,0
```
退出后 `p5engine.ini`：
```ini
[window_size]
width=1280
height=720
```
✅ 全屏退出保存的是窗口模式尺寸，不是全屏尺寸

### 窗口模式测试
```
Window: 1280x720
Loaded window size from p5engine.ini: 1280x720
Window positioned: 1080, 360
```
退出后 `p5engine.ini`：
```ini
[window_position]
x=1080
y=360
```
✅ 窗口模式保存实际尺寸和居中位置

### `TowerDefenseMin2.ini`
不再包含 `[window_size]` 和 `[window_position]` 的新写入。旧数据保留在文件中但不再被代码读取。

## 相关文件
- `src/main/java/shenyf/p5engine/core/P5Config.java`
- `src/main/java/shenyf/p5engine/core/P5Engine.java`
- `src/main/java/shenyf/p5engine/core/WindowManager.java`
- `examples/TowerDefenseMin2/TdSaveData.pde`
- `examples/TowerDefenseMin2/TdAppCore.pde`
- `examples/TowerDefenseMin2/TdFlow.pde`
- `examples/TowerDefenseMin2/TowerDefenseMin2.pde`
