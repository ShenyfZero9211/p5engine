# Processing P2D 窗口模式死锁根因分析与修复

## 问题描述

TowerDefenseMin2 在**窗口模式**（windowed）下启动时，程序会死锁/冻结（窗口显示但无响应，必须强制结束进程）。**Borderless 全屏模式**下启动完全正常。

## 根因分析

死锁触发点是 `surface.setResizable(true)`。

这是 **Processing 已知 bug**（[processing/processing#5579](https://github.com/processing/processing/issues/5579)）：
- Windows 10/11 + P2D/P3D 渲染器 + `surface.setResizable(true)`
- JOGL/NEWT 的 `GLWindow` 在窗口创建后改变 resizable 属性时，触发 NEWT Event Dispatch Thread (EDT) 与 AWT EDT 的 `RecursiveToolkitLock` 死锁
- Borderless 全屏模式不调用 `setResizable(true)`，因此不受此 bug 影响

### 为什么后台运行不死锁

用户观察到"后台运行不死锁"，是因为：
- 窗口在后台时，NEWT/AWT 的 Event Dispatch Thread 不处理输入/焦点事件，EDT 之间无竞争
- 窗口前台化后，鼠标移动、焦点变化等事件立即涌入，与 `setResizable(true)` 触发的 native window 状态变更形成死锁

### 为什么移除 `setResizable(true)` 后功能不受影响

窗口 resize 功能由 **P5Engine `WindowManager`** 通过 **NEWT 反射**直接实现：
- `WindowManager.setWindowSize()` → `nativeSurface.setSize(w, h)`
- `WindowManager.setWindowPosition()` → `nativeSurface.setPosition(x, y)`
- `WindowManager.toggleFullscreen()` → `nativeSurface.setUndecorated()` / `setFullscreen()`

这些操作直接修改 NEWT `GLWindow` 的 native 属性，**不依赖 Processing 的 `surface.setResizable(true)`**。`setResizable(true)` 只是让 Processing 在窗口边框上显示 resize 手柄，而 NEWT 反射可以直接改变窗口尺寸。

## 排查过程

为精确定位触发点，逐个移除了 P5Engine 和 sketch 中的候选操作：

| 版本 | 移除的操作 | 结果 |
|------|-----------|------|
| 版本1 | `applyWindowPosition()`（窗口居中/定位） | 仍然死锁 ❌ |
| 版本2 | `registerFocusListener()`（JOGL 焦点监听） | 仍然死锁 ❌ |
| 版本3 | `setMouseConfined(true)`（鼠标限制） | 仍然死锁 ❌ |
| 版本4 | `surface.setResizable(true)`（Processing 层面） | **不再死锁** ✅ |

## 最终修改

### TowerDefenseMin2.pde

```java
public void setup() {
  inst = this;
  TdSaveData.load(this);
  // NOTE: surface.setResizable(true) is intentionally removed to avoid a
  // Processing P2D deadlock on Windows (processing/processing#5579).
  // Window resizing is handled by P5Engine WindowManager via NEWT reflection
  // (setSize/setPosition), which does not trigger the deadlock.
  new TdAppSetup().run();
}
```

### P5Engine.java

无修改。`applyWindowPosition()`、`registerFocusListener()`、`setMouseConfined()` 均保留，它们不是触发点。

## 相关文件

- `examples/TowerDefenseMin2/TowerDefenseMin2.pde`
- `src/main/java/shenyf/p5engine/core/WindowManager.java`
- `src/main/java/shenyf/p5engine/core/P5Engine.java`

## 参考

- [processing/processing#5579 - Window freezes on resize in Windows 10 (Default & P2D renderers)](https://github.com/processing/processing/issues/5579)
- [jogamp/jogl bug #756 - Spurious freeze and/or NullPointerException when running a JOGL NEWT application](https://jogamp.org/bugzilla/show_bug.cgi?id=756)
- [jogamp/jogl bug #1478 - macOS 14.0 JOGL freezes when opening other JFrame before JOGL frame](https://jogamp.org/bugzilla/show_bug.cgi?id=1478)
