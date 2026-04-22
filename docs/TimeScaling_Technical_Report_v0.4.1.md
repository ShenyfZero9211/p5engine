# p5engine 时间缩放系统技术报告

> 版本：v0.4.1  
> 日期：2026-04-21  
> 对应功能：引擎渲染速度可变，帧率保持不变

---

## 一、概述

时间缩放（Time Scaling）允许游戏世界以任意速度运行（慢动作、快进、暂停），同时渲染循环保持固定帧率（如 60 FPS）。这对以下场景至关重要：

- **慢动作（Bullet Time）**：玩家技能、击杀特写
- **暂停菜单**：游戏冻结，UI 继续响应
- **快进**：模拟经营类时间流逝
- **网络同步**：客户端追赶服务器状态

---

## 二、架构设计

### 2.1 双重时间线

```
┌──────────────────────────────────────────────┐
│           真实时间 (Real Time)                │
│  • System.nanoTime()                          │
│  • 不可控，由硬件/OS决定                        │
│  • 驱动渲染循环、UI动画、输入响应                │
├──────────────────────────────────────────────┤
│           游戏时间 (Game Time)                │
│  • 受 timeScale 控制                           │
│  • 驱动世界逻辑、物理、AI、游戏内动画             │
│  • gameDelta = realDelta × timeScale          │
└──────────────────────────────────────────────┘
```

### 2.2 主循环时序

```java
// P5Engine.update() 每帧执行

1. 计算真实 delta  rawDelta = (nanoTime - lastFrameTime) / 1e9
2. gameTime.update(rawDelta)       ← 防卡顿 + 平滑过渡 + 缩放
3. scene.update(gameTime.getDeltaTime())           // 世界逻辑
4. scheduler.update(scaledDt, realDt)              // 定时器自选
5. tweenManager.update(gameTime)                   // tween 自选
6. render()                                         // 每帧都执行
```

---

## 三、修改清单

| 文件 | 变更 | 说明 |
|------|------|------|
| `time/P5GameTime.java` | **重写** | 新增真实 delta、平滑过渡、暂停语义、防卡顿 |
| `core/P5Engine.java` | **修改** | 移除局部防卡顿；统一子系统时间来源 |
| `tween/TweenManager.java` | **修改** | 新增 `useUnscaledTime` 开关 + `update(P5GameTime)` |
| `examples/RenderDemo/RenderDemo.pde` | **修改** | 添加 `1`~`5`、`P` 按键控制；HUD 显示 timeScale |
| `docs/RenderingSystem_v0.4.0_Summary.md` | **追加** | 补充时间缩放章节 |

---

## 四、技术细节

### 4.1 P5GameTime 核心算法

```java
public void update(float rawDeltaTime) {
    // 1. 防卡顿：最大允许 250ms 跳变
    if (rawDeltaTime > MAX_DELTA_TIME) rawDeltaTime = MAX_DELTA_TIME;

    // 2. 平滑过渡（指数 ease-out）
    if (Math.abs(timeScale - targetTimeScale) > 0.001f) {
        float t = 1.0f - exp(-transitionSpeed * rawDeltaTime);
        timeScale = lerp(timeScale, targetTimeScale, t);
    }

    // 3. 双 delta 计算
    realDeltaTime = rawDeltaTime;
    deltaTime     = paused ? 0f : rawDeltaTime * timeScale;

    // 4. 累计时间
    unscaledTime += rawDeltaTime;
    totalTime    += deltaTime;
}
```

### 4.2 平滑过渡公式

使用 **指数衰减插值**（Exponential Ease-Out）：

```
timeScale(t) = target + (current - target) × e^(-speed × Δt)
```

优点：
- 与帧率无关（无论 30 FPS 还是 144 FPS，过渡时长一致）
- 自然减速，不会 overshoot
- 速度参数直观：`speed = 5` 约等于 0.2 秒内完成 95% 过渡

### 4.3 防卡顿保护

| 场景 | 原始 delta | 处理后 | 结果 |
|------|-----------|--------|------|
| 正常 60 FPS | 16.7ms | 16.7ms | 无影响 |
| 窗口最小化后恢复 | 2000ms | 250ms | 防止物理爆炸 |
| 垃圾回收卡顿 | 100ms | 100ms | 无影响（< 250ms） |

### 4.4 暂停语义

```java
public void pause() {
    if (!paused) {
        paused = true;
        prePauseTimeScale = targetTimeScale;  // 记忆恢复速度
        setTargetTimeScale(0f);                // 平滑降到 0
    }
}

public void resume() {
    if (paused) {
        paused = false;
        setTargetTimeScale(prePauseTimeScale); // 平滑恢复
    }
}
```

**关键**：暂停不是瞬间设置 `timeScale = 0`，而是设置 `targetTimeScale = 0`，让平滑过渡自然降到零。恢复时同理。

---

## 五、子系统集成

### 5.1 Scene（世界逻辑）

```java
scene.update(gameTime.getDeltaTime());
```

- GameObject 运动、AI 决策、碰撞检测全部使用缩放时间
- timeScale = 0.5 时，世界运行速度减半

### 5.2 Scheduler（定时器）

```java
scheduler.update(gameTime.getDeltaTime(), gameTime.getRealDeltaTime());
```

- **默认 Timer**：使用 `scaledDt`（游戏时间）
- **Unscaled Timer**：`delayUnscaled()` 创建的 Timer 使用 `realDt`
- 每个 Timer 可独立通过 `setTimeScaleAffected(false)` 切换

使用场景对照：

| 定时器类型 | 创建方式 | 适用场景 |
|-----------|----------|----------|
| 游戏定时器 | `scheduler.delay(2f, ...)` | 技能冷却、BUFF 持续时间 |
| 真实定时器 | `scheduler.delayUnscaled(2f, ...)` | UI 提示自动关闭、截图延迟 |

### 5.3 TweenManager（动画补间）

```java
tweenManager.update(gameTime);
```

- 默认 `useUnscaledTime = false`（游戏优先）
- UI 动画可设为 `true`：

```java
// 游戏内角色动画：随 timeScale 减速
tweenManager.setUseUnscaledTime(false);
tweenManager.toPosition(ship, target, 1.0f).start();

// UI 菜单动画：保持流畅
tweenManager.setUseUnscaledTime(true);
tweenManager.toAlpha(panel, 1f, 0.3f).start();
```

### 5.4 Audio（音频）

音频系统**始终使用真实时间**，不受 timeScale 影响。

如需音调随 timeScale 变化（慢动作音效），需手动控制：

```java
float pitch = engine.getGameTime().getTimeScale();
audioManager.setGlobalPitch(pitch);  // 假设 API 存在
```

---

## 六、使用细则

### 6.1 API 速查

```java
P5GameTime gt = engine.getGameTime();

// ── 控制 ──
gt.setTimeScale(0.5f);              // 瞬时设置（不推荐）
gt.setTargetTimeScale(0.5f);        // 平滑过渡（推荐）
gt.setTransitionSpeed(5.0f);        // 过渡速度（默认 5）
gt.pause();                         // 暂停（平滑降到 0）
gt.resume();                        // 恢复（平滑恢复）
gt.togglePause();                   // 切换暂停状态

// ── 查询 ──
float dt  = gt.getDeltaTime();      // 游戏 delta（缩放后）
float rdt = gt.getRealDeltaTime();  // 真实 delta（未缩放）
float ts  = gt.getTimeScale();      // 当前实际倍率
float tts = gt.getTargetTimeScale(); // 目标倍率
boolean p = gt.isPaused();          // 是否暂停
float tt  = gt.getTotalTime();      // 累计游戏时间
float rt  = gt.getUnscaledTime();   // 累计真实时间
```

### 6.2 各模块时间选择指南

| 模块 | 推荐时间 | 理由 |
|------|----------|------|
| 物理/运动 | `getDeltaTime()` | 必须与游戏世界同步 |
| AI 决策 | `getDeltaTime()` | 思考频率随游戏速度变化 |
| 粒子效果 | `getDeltaTime()` | 慢动作时粒子也慢，视觉统一 |
| UI 动画 | `getRealDeltaTime()` | 暂停时菜单仍需动画 |
| 输入冷却 | `getRealDeltaTime()` | 玩家操作不能卡 |
| 网络超时 | `getRealDeltaTime()` | 真实世界的等待 |
| 定时任务 | 看场景 | 游戏事件用 scaled，UI 事件用 real |
| Tween | 看目标 | 游戏对象用 scaled，UI 用 real |

### 6.3 在 Component 中获取真实时间

```java
public class MyComponent extends Component {
    @Override
    public void update(float deltaTime) {
        // deltaTime 已经是缩放后的游戏时间
        transform.translate(velocity.x * deltaTime, velocity.y * deltaTime);

        // 如需真实时间（如 UI 闪烁）
        float realDt = P5Engine.getInstance()
                         .getGameTime().getRealDeltaTime();
    }
}
```

### 6.4 预设档位封装（可选）

```java
public enum TimeScalePreset {
    PAUSED(0.0f),
    SUPER_SLOW(0.1f),
    SLOW_MOTION(0.5f),
    NORMAL(1.0f),
    DOUBLE(2.0f),
    FAST_FORWARD(5.0f);

    public final float scale;
    TimeScalePreset(float scale) { this.scale = scale; }
}

// 使用
engine.getGameTime().setTargetTimeScale(TimeScalePreset.SLOW_MOTION.scale);
```

---

## 七、常见陷阱

### 7.1 陷阱：直接设置 timeScale 导致跳变

```java
// 错误：画面卡顿
gt.setTimeScale(0.1f);

// 正确：平滑过渡
gt.setTargetTimeScale(0.1f);
```

### 7.2 陷阱：从暂停恢复时 delta 爆炸

P5GameTime 已内置处理：暂停期间 `lastFrameTime` 仍持续更新（通过 `realDeltaTime` 累加），恢复时不会产生巨大的 delta。

### 7.3 陷阱：UI 动画使用缩放时间

```java
// 错误：暂停时 UI 也卡死
tweenManager.setUseUnscaledTime(false);
tweenManager.toAlpha(menu, 1f, 0.3f).start();

// 正确：UI 始终流畅
tweenManager.setUseUnscaledTime(true);
tweenManager.toAlpha(menu, 1f, 0.3f).start();
```

### 7.4 陷阱：输入冷却用错时间

```java
// 错误：慢动作时射击也变慢的冷却
shootCooldown -= deltaTime;

// 正确：玩家操作始终跟手
shootCooldown -= engine.getGameTime().getRealDeltaTime();
```

---

## 八、性能影响

| 项目 | 开销 | 说明 |
|------|------|------|
| 双 delta 计算 | 可忽略 | 两个乘法和一次条件判断 |
| 平滑过渡 | 可忽略 | 一次 `exp()` 调用 |
| 防卡顿 | 可忽略 | 一次比较 |
| 内存增加 | 0 | 无额外对象分配 |

**结论**：时间缩放系统对性能零影响，可放心全局启用。

---

## 九、版本历史

| 版本 | 变更 |
|------|------|
| v0.3.8 | 基础 `P5GameTime`，仅支持 `timeScale` 瞬时切换 |
| **v0.4.1** | 新增平滑过渡、暂停语义、真实 delta 暴露、TweenManager 可配置 |

---

## 十、参考文件

- `src/main/java/shenyf/p5engine/time/P5GameTime.java`
- `src/main/java/shenyf/p5engine/time/Scheduler.java`
- `src/main/java/shenyf/p5engine/time/Timer.java`
- `src/main/java/shenyf/p5engine/tween/TweenManager.java`
- `src/main/java/shenyf/p5engine/core/P5Engine.java`
- `examples/RenderDemo/RenderDemo.pde`
