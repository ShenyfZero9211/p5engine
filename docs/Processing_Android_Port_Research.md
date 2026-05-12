# Processing 移植安卓平台调研报告

> **文档日期**: 2026-05-12  
> **调研目标**: p5engine / TowerDefenseMin2 安卓移植可行性  
> **引擎版本**: Processing 4.5.2 / p5engine 0.1.0-M1  
> **JDK**: 17  
> **适用平台**: Android (OpenGL ES)

---

## 目录

1. [Processing Android 生态概述](#1-processing-android-生态概述)
2. [三条移植路径对比](#2-三条移植路径对比)
3. [Processing PDE Android Mode 导出 APK 流程](#3-processing-pde-android-mode-导出-apk-流程)
4. [桌面端 vs Android 端 核心差异](#4-桌面端-vs-android-端-核心差异)
5. [p5engine 移植可行性分析](#5-p5engine-移植可行性分析)
6. [如果决定移植，需要做的工作](#6-如果决定移植需要做的工作)
7. [推荐方案](#7-推荐方案)

---

## 1. Processing Android 生态概述

Processing 官方提供了 **Android Mode**（`processing-android`），允许将 PDE 草图编译为 Android APK。生态中有三个主要工具：

| 工具 | 定位 | 适用场景 |
|------|------|----------|
| **Processing Android Mode** | Processing PDE 的内置模式切换 | 从桌面草图快速移植到安卓 |
| **APDE** | Android 设备上的 Processing IDE | 无需电脑，直接在手机上开发 |
| **Android Studio + processing-core.jar** | 标准 Android 开发 + Processing 图形库 | 需要深度集成 Android API |

**官方资源**：
- 官网：https://android.processing.org/
- GitHub：https://github.com/processing/processing-android
- 教程：https://android.processing.org/tutorials/

**已知问题**：
- Processing 4.4.1 的 Android Mode 存在严重 Gradle daemon 兼容问题（[issue #777](https://github.com/processing/processing-android/issues/777)）
- Processing 4.5.3 已修复部分 Android Mode 切换问题

---

## 2. 三条移植路径对比

### 路径 A：Processing PDE + Android Mode（推荐用于快速原型）

在 PDE 中切换到 Android Mode，代码基本无需修改即可运行。

**改动点**：
```java
// 桌面端
void setup() {
    size(1280, 720, P2D);
}

// Android 端
void setup() {
    fullScreen(P2D);  // 或 fullScreen()
}
```

**优点**：
- 代码改动最小
- 内置传感器 API（加速度计、陀螺仪、GPS）
- 一键运行到设备/模拟器
- 支持导出签名 APK

**缺点**：
- 无法使用桌面版的核心库（Serial、Network、Video、Sound）
- P2D 在 Android 上性能较差（stroke tessellation 纯 Java 实现）
- 无法深度集成 Android 原生 UI

---

### 路径 B：APDE（纯移动端开发）

APDE (Android Processing Development Environment) 是一个在 Android 设备上运行的 Processing IDE。

**获取方式**：
- Google Play 商店搜索 "APDE"
- GitHub Releases：https://github.com/Calsign/APDE/releases

**功能**：
- 完整的编辑-编译-运行循环
- 支持导出签名 APK
- 支持导入第三方库
- 支持 Wallpaper、Watch Face、VR 构建目标

**限制**：
- Alpha 阶段，存在 bug
- 不支持桌面 Processing 的核心库
- 无法使用 JOGL 特定功能

---

### 路径 C：Android Studio + processing-core.jar（推荐用于正式发布）

将 Processing 作为图形库嵌入标准 Android Studio 项目。

**步骤**：
1. 创建 Android Studio Empty Activity 项目
2. 从 Processing 的 AndroidMode 文件夹复制 `processing-core.zip` → 重命名为 `processing-core.jar`
3. 放入 `app/libs/`，添加为 `implementation` 依赖
4. 创建 Sketch 类继承 `PApplet`

```java
// Sketch.java
public class Sketch extends PApplet {
    public void settings() {
        fullScreen(P2D);
    }
    public void setup() {
        background(0);
    }
    public void draw() {
        ellipse(mouseX, mouseY, 50, 50);
    }
}
```

5. 在 MainActivity 中通过 `PFragment` 嵌入：

```java
public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        FrameLayout frame = new FrameLayout(this);
        frame.setId(CompatUtils.getUniqueViewId());
        setContentView(frame);
        
        PApplet sketch = new Sketch();
        PFragment fragment = new PFragment(sketch);
        fragment.setView(frame, this);
    }
}
```

**优点**：
- 完全访问 Android SDK API
- 可以混合原生 Android UI 和 Processing 画布
- 标准的 APK 构建流程
- 支持 ProGuard 混淆、多架构 so 库

**缺点**：
- 需要重写项目结构
- 不能直接使用 PDE 文件（需要手动转换为 Java 类）

---

## 3. Processing PDE Android Mode 导出 APK 流程

### 3.1 安装 Android Mode

```
Processing PDE → 右上角 Mode 下拉 → Add Mode... → 选择 Android Mode → Install
```

### 3.2 安装 Android SDK

首次切换 Android Mode 时，PDE 会自动引导下载 Android SDK（API 33）。

手动安装路径：
```
C:\Users\<User>\Documents\Processing\android\sdk
```

### 3.3 代码适配清单

| 桌面代码 | Android 适配 | 说明 |
|----------|-------------|------|
| `size(w, h)` | `fullScreen()` | Android 用全屏 |
| `size(w, h, P2D)` | `fullScreen(P2D)` | 显式指定 P2D |
| `size(w, h, P3D)` | `fullScreen(P3D)` | 显式指定 P3D |
| `mousePressed()` | `mousePressed()` + `touchStarted()` | Android 支持多点触控 |
| `loadImage("data/a.png")` | `loadImage("a.png")` | 路径前缀差异 |
| `createFont("Arial", 20)` | `createFont("arial.ttf", 20)` | 必须使用 TTF/OTF |
| `loadFont("xxx.vlw")` | ❌ 不推荐 | VLW 字体在 Android 上 OOM 风险高 |

### 3.4 运行与导出

**运行到设备**：
1. 连接 Android 设备，开启 USB 调试
2. PDE 点击 Run 按钮（▶）
3. 或使用 Tools → Emulator 启动模拟器

**导出 APK**：
```
File → Export Android Project    → 导出为 Android Studio 项目
File → Export Signed Package     → 直接导出签名 APK（需配置 keystore）
```

**签名配置**：
```
Tools → Android → Keystore → 创建或选择 .jks 文件
```

---

## 4. 桌面端 vs Android 端 核心差异

### 4.1 渲染器架构差异（最关键）

| 特性 | 桌面 Processing | Android Processing |
|------|----------------|-------------------|
| **P2D 后端** | JOGL (OpenGL) | OpenGL ES |
| **P3D 后端** | JOGL (OpenGL) | OpenGL ES |
| **默认 2D** | JAVA2D (AWT) | `PGraphicsAndroid2D` |
| **Shader** | 完整 GLSL | GLSL ES (简化版) |
| **stroke 性能** | 快（ native ） | 慢（纯 Java tessellation）|

**性能陷阱**：
- Android 的 P2D stroke tessellation 是纯 Java 实现，大量 `stroke()` 调用会导致帧率暴跌
- **解决方案**：使用 `PShape` 缓存几何，或改用 `noStroke()` + `fill()`

### 4.2 API 兼容性差异

| 桌面 API | Android 支持？ | 替代方案 |
|----------|---------------|----------|
| `java.awt.*` | ❌ 不存在 | Android SDK 对应类 |
| `javax.swing.*` | ❌ 不存在 | Android View 系统 |
| `java.desktop` 模块 | ❌ 不存在 | 移除依赖 |
| JOGL 特定 API | ❌ 不存在 | OpenGL ES API |
| `processing.sound.*` | ❌ 不支持 | `processing-audio` 库或 Android MediaPlayer |
| `processing.serial.*` | ❌ 不支持 | `AndroidSerial` 库 |
| `processing.video.*` | ❌ 不支持 | `video_android` 库 |
| `loadFont(.vlw)` | ⚠️ OOM 风险 | `createFont(.ttf)` |
| `createGraphics(w, h, JAVA2D)` | ❌ 不支持 | `createGraphics(w, h, P2D)` |

### 4.3 文件系统差异

| 桌面 | Android |
|------|---------|
| `sketchPath("data/xxx")` | `getActivity().getAssets().open("xxx")` |
| `saveFrame()` | 需要 WRITE_EXTERNAL_STORAGE 权限 |
| 相对路径自由访问 | 受 Android 沙盒限制 |

---

## 5. p5engine 移植可行性分析

### 5.1 结论：**不能直接移植**

p5engine 是基于**桌面 Processing 4** 构建的完整 2D 游戏引擎，与 Android 环境存在**结构性不兼容**。

### 5.2 不兼容项清单

| p5engine 组件 | 桌面依赖 | Android 状态 | 工作量 |
|--------------|---------|-------------|--------|
| **核心渲染** | `core-4.5.2.jar` (JOGL/P2D) | ❌ 需替换为 `processing-android-core` | 极大 |
| **引擎架构** | Java 17 SE + `java.desktop` | ❌ Android SDK 无此模块 | 极大 |
| **UI 系统** | 自定义 Container/ScrollPane/Window | ❌ 基于 AWT 概念，Android 需重写 | 大 |
| **音频系统** | TinySound (桌面音频) | ❌ 需替换为 Android MediaPlayer | 中 |
| **窗口管理** | `WindowManager` + JOGL GLWindow | ❌ Android 使用 Activity/Fragment | 极大 |
| **资源加载** | PPAK + 文件系统 | ⚠️ 可适配为 Android Assets | 小 |
| **输入处理** | 鼠标/键盘事件 | ⚠️ 需适配为触摸/多点触控 | 中 |
| **显示管理** | `DisplayManager` (FIT 缩放) | ⚠️ Android 密度适配逻辑不同 | 中 |
| **字体渲染** | `createFont()` + PFont | ⚠️ 需适配 Android 字体加载 | 小 |
| **Tween 动画** | 纯 Java 逻辑 | ✅ 可直接使用 | 无 |
| **游戏逻辑** | TowerDefenseMin2 游戏代码 | ⚠️ 需重写文件 I/O 和平台 API | 大 |

### 5.3 为什么 JOGL → OpenGL ES 是致命障碍

p5engine 的 P2D 渲染深度依赖 JOGL（Java OpenGL Binding）：
- `PGraphicsOpenGL` 使用 JOGL 的 `GL` 上下文
- p5engine 的 `ImageManager`、`TweenManager` 的渲染回调与 JOGL 管线耦合
- Android 没有 JOGL，只有 OpenGL ES（通过 Android SDK 的 `GLES20`/`GLES30`）

这意味着 p5engine 的**整个渲染层**需要重写。

---

## 6. 如果决定移植，需要做的工作

### 方案一：用 Android Studio 完全重写（推荐，但工作量大）

1. **创建 Android Studio 项目**
   - minSdk: 21 (Android 5.0)
   - targetSdk: 33
   - 导入 `processing-android-core.jar`

2. **重写渲染层**
   - 移除所有 JOGL 依赖
   - 使用 Processing Android 的 `PApplet` 作为画布
   - 游戏画面用 `PFragment` 嵌入 `MainActivity`

3. **重写 UI 层**
   - 移除 p5engine 的 `UIComponent`/`Container`/`ScrollPane`
   - 使用 Android 原生 View 或 Jetpack Compose
   - 简报界面用 `ScrollView` + `TextView`

4. **重写音频层**
   - 移除 TinySound
   - 使用 Android `MediaPlayer` + `SoundPool`

5. **重写资源加载**
   - PPAK 系统可保留，适配为 Android AssetManager 读取
   - 或直接使用 Android `res/raw` 和 `assets/`

6. **重写输入层**
   - 鼠标事件 → 触摸事件（`onTouchEvent`）
   - 键盘事件 → Android 输入法/物理键盘

7. **适配游戏逻辑**
   - 塔防网格坐标系统（适配手机屏幕比例）
   - 存档系统（Android `SharedPreferences` 或 SQLite）

**预估工作量**：2-3 个月（全职）

---

### 方案二：用 Processing Android Mode 重写（快速但不专业）

1. 在 PDE 中创建新的 Android Mode 草图
2. 将 TowerDefenseMin2 的 PDE 代码复制过去
3. 逐文件修复不兼容 API
4. 使用 Android 原生 UI 叠加层（通过 `getActivity()`）

**预估工作量**：3-4 周

**限制**：
- 无法使用 p5engine 的任何功能（需要完全移除）
- 性能受限（Android P2D 的 stroke 性能问题）
- 无法发布到 Google Play（缺乏专业打包流程）

---

### 方案三：使用游戏框架替代（推荐如果目标是多平台）

如果最终目标是发布安卓版，**不建议**继续基于 Processing 移植，而是使用跨平台游戏引擎：

| 框架 | 语言 | Processing 相似度 | 安卓支持 |
|------|------|------------------|----------|
| **libGDX** | Java/Kotlin | ⭐⭐⭐ 高（2D 渲染、PShape 类似） | ✅ 原生 |
| **Godot** | GDScript/C# | ⭐⭐ 中 | ✅ 原生 |
| **Unity** | C# | ⭐⭐ 中 | ✅ 原生 |
| **Heaps.io** | Haxe | ⭐⭐⭐ 高 | ✅ 原生 |

**libGDX** 是最接近 Processing 生态的 Java 游戏框架，且原生支持 Android。

---

## 7. 推荐方案

### 短期（如果必须跑在 Android 上）

使用 **Processing Android Mode + PDE** 快速原型验证：

```
1. 安装 Android Mode
2. 新建 Android 草图
3. 复制 TowerDefenseMin2 的核心游戏逻辑（移除 p5engine 依赖）
4. 用 Android 原生 View 替代 UI 系统
5. 导出 APK 测试
```

### 长期（如果计划正式发布）

**不建议基于 Processing 做安卓移植**。推荐：

1. **保留桌面版**：继续用 p5engine + Processing 4 维护 Windows/Mac/Linux 版
2. **安卓版使用 libGDX 重写**：libGDX 的 API 与 Processing 非常接近（`SpriteBatch`、`ShapeRenderer`、`OrthographicCamera`）
3. **共享资源**：贴图、音频、配置文件可在两个版本间复用

### 风险提醒

| 风险 | 说明 |
|------|------|
| Processing Android Mode 维护状态 | 官方维护缓慢，Processing 4 的 Android 支持仍有 bug |
| OpenGL ES 性能 | Android 设备性能差异大，低端机可能无法流畅运行 |
| Google Play 64位要求 | Android 9+ 必须提供 64 位 so 库，Processing 的 native 库需确认 |
| 内存限制 | Android 设备内存有限，大型贴图/音频容易 OOM |

---

## 参考资源

- [Processing for Android 官网](https://android.processing.org/)
- [Processing Android GitHub](https://github.com/processing/processing-android)
- [APDE GitHub](https://github.com/Calsign/APDE)
- [Android Studio + Processing 教程](https://android.processing.org/tutorials/android_studio/)
- [libGDX 官网](https://libgdx.com/)
- [Processing Android Issue #777](https://github.com/processing/processing-android/issues/777)
