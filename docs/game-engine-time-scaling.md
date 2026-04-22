# 游戏引擎时间缩放系统：帧率与游戏速度的解耦

> 本文档整理自与 Kimi Code CLI 的技术讨论，面向使用 Processing/p5.js 或自研 Java 游戏引擎的开发者。
>
> 核心问题：**如何让游戏世界加速或减速，同时保持渲染帧率稳定？**

---

## 目录

1. [问题背景](#一问题背景)
2. [核心概念：真实时间 vs 游戏时间](#二核心概念真实时间-vs-游戏时间)
3. [基础实现：可变时间步长方案](#三基础实现可变时间步长方案)
4. [进阶实现：固定时间步长 + 插值渲染](#四进阶实现固定时间步长--插值渲染)
5. [时间缩放的控制接口](#五时间缩放的控制接口)
6. [实际应用场景](#六实际应用场景)
7. [常见陷阱与解决方案](#七常见陷阱与解决方案)
8. [与 p5engine 的整合建议](#八与-p5engine-的整合建议)
9. [参考实现代码](#九参考实现代码)

---

## 一、问题背景

在传统游戏循环中，常见的做法是每帧更新一次逻辑：

```java
void draw() {
    update();  // 更新逻辑
    render();  // 渲染画面
}
```

这种方式的问题是：**逻辑更新与渲染帧率强绑定**。如果你把 `frameRate` 从 60 降到 30，游戏世界会慢一半；如果某帧渲染耗时变长，游戏节奏就会被打乱。

更棘手的是，当你想做以下效果时，这种架构无法胜任：

- **慢动作（Bullet Time）**：游戏减速，但画面仍然流畅
- **暂停**：游戏停止，但菜单 UI 继续动画
- **快进**：模拟经营游戏中加速时间流逝
- **网络同步**：不同玩家帧率不同，需要统一的游戏时间

**解耦的关键**：把"逻辑更新"和"画面渲染"分离，让两者使用不同的时间基准。

---

## 二、核心概念：真实时间 vs 游戏时间

```
┌─────────────────────────────────────────────────────────────┐
│                      时间系统架构                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   真实时间 (Real Time)          游戏时间 (Game Time)          │
│   ───────────────────          ───────────────────          │
│                                                             │
│   • System.currentTimeMillis()   • 受 timeScale 控制           │
│   • 不可控，由硬件决定            • 可控，由设计者决定          │
│   • 用于测量真实经过时间          • 用于驱动游戏逻辑            │
│                                                             │
│   关系：gameDelta = realDelta × timeScale                   │
│                                                             │
│   timeScale = 1.0  → 正常速度                                │
│   timeScale = 0.5  → 半速（慢动作）                           │
│   timeScale = 2.0  → 双倍速                                  │
│   timeScale = 0.0  → 暂停                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 两个循环的分离

| 循环类型 | 驱动时间 | 职责 | 帧率 |
|---------|---------|------|------|
| **渲染循环** | 真实时间 | 绘制画面、呈现结果 | 固定 60 FPS（或显示器刷新率） |
| **更新循环** | 游戏时间 | 物理模拟、AI 决策、动画推进 | 可变，由 timeScale 控制 |

**关键洞察**：渲染循环每帧都执行（为了画面流畅），但更新循环使用"缩放后的时间增量"来计算世界状态的推进。

---

## 三、基础实现：可变时间步长方案

这是最容易理解的实现方式，适合 Physics-lite 的游戏或原型开发。

### 3.1 核心代码结构

```java
public class TimeManager {
    
    // ========== 时间缩放控制 ==========
    
    /** 时间缩放因子：1.0=正常, 0.5=慢动作, 2.0=快进, 0.0=暂停 */
    private float timeScale = 1.0f;
    
    /** 是否完全暂停（与 timeScale=0 等效，但语义更清晰） */
    private boolean isPaused = false;
    
    // ========== 时间管理内部状态 ==========
    
    /** 上一帧的真实时间戳（毫秒） */
    private long lastRealTime;
    
    /** 游戏累计运行时间（受 timeScale 影响） */
    private float gameTime = 0.0f;
    
    /** 真实世界累计运行时间（不受 timeScale 影响） */
    private float realTime = 0.0f;
    
    /** 当前帧的游戏时间增量 */
    private float deltaTime = 0.0f;
    
    /** 当前帧的真实时间增量 */
    private float realDeltaTime = 0.0f;
    
    // ========== 初始化 ==========
    
    public void init() {
        lastRealTime = System.currentTimeMillis();
    }
    
    // ========== 每帧调用：在主循环开始处执行 ==========
    
    public void update() {
        // 1. 获取当前真实时间
        long currentRealTime = System.currentTimeMillis();
        
        // 2. 计算真实时间增量（上一帧到现在过了多少毫秒）
        realDeltaTime = (currentRealTime - lastRealTime) / 1000.0f; // 转为秒
        
        // 3. 防卡顿保护：如果一帧耗时过长（如窗口被最小化后恢复），限制最大增量
        // 避免物理模拟爆炸（比如一个物体穿越了一面墙）
        if (realDeltaTime > 0.25f) {
            realDeltaTime = 0.25f; // 最大允许 250ms 的跳变
        }
        
        // 4. 计算游戏时间增量 = 真实增量 × 时间缩放
        if (isPaused) {
            deltaTime = 0.0f;
        } else {
            deltaTime = realDeltaTime * timeScale;
        }
        
        // 5. 累计总时间
        realTime += realDeltaTime;
        gameTime += deltaTime;
        
        // 6. 更新上一帧时间戳
        lastRealTime = currentRealTime;
    }
    
    // ========== 控制接口 ==========
    
    /** 设置时间缩放 */
    public void setTimeScale(float scale) {
        this.timeScale = Math.max(0.0f, scale);
    }
    
    public float getTimeScale() {
        return timeScale;
    }
    
    /** 暂停游戏 */
    public void pause() {
        this.isPaused = true;
    }
    
    /** 恢复游戏 */
    public void resume() {
        this.isPaused = false;
    }
    
    public boolean isPaused() {
        return isPaused;
    }
    
    // ========== 查询接口 ==========
    
    /** 获取当前帧的游戏时间增量（秒），用于所有逻辑更新 */
    public float getDeltaTime() {
        return deltaTime;
    }
    
    /** 获取当前帧的真实时间增量（秒），用于 UI 动画等不受 timeScale 影响的内容 */
    public float getRealDeltaTime() {
        return realDeltaTime;
    }
    
    /** 获取游戏累计运行时间 */
    public float getGameTime() {
        return gameTime;
    }
    
    /** 获取真实累计运行时间 */
    public float getRealTime() {
        return realTime;
    }
}
```

### 3.2 使用方式

```java
public class GameEngine extends PApplet {
    
    private TimeManager time;
    private List<GameObject> objects;
    
    public void setup() {
        size(800, 600);
        frameRate(60);  // 锁定渲染帧率
        
        time = new TimeManager();
        time.init();
        
        objects = new ArrayList<>();
        // ... 初始化游戏对象
    }
    
    public void draw() {
        // 1. 更新时间（必须在每帧最开始调用）
        time.update();
        
        // 2. 更新游戏逻辑（使用游戏时间）
        updateGameLogic();
        
        // 3. 渲染画面（使用真实时间做 UI 动画）
        render();
    }
    
    private void updateGameLogic() {
        float dt = time.getDeltaTime();  // 获取缩放后的时间增量
        
        for (GameObject obj : objects) {
            // 位置更新：使用游戏时间
            obj.position.x += obj.velocity.x * dt;
            obj.position.y += obj.velocity.y * dt;
            
            // 旋转更新
            obj.rotation += obj.angularVelocity * dt;
            
            // 动画帧推进
            obj.animation.update(dt);
            
            // 生命周期倒计时
            obj.lifeTime -= dt;
        }
    }
    
    private void render() {
        background(0);
        
        // 游戏世界渲染（使用当前状态，不依赖时间）
        for (GameObject obj : objects) {
            obj.draw(this);
        }
        
        // UI 渲染（使用真实时间做动画，不受 timeScale 影响）
        float uiDt = time.getRealDeltaTime();
        hud.update(uiDt);
        hud.draw(this);
    }
    
    // 按键控制时间缩放
    public void keyPressed() {
        if (key == '1') time.setTimeScale(0.1f);  // 超慢动作
        if (key == '2') time.setTimeScale(0.5f);  // 慢动作
        if (key == '3') time.setTimeScale(1.0f);  // 正常
        if (key == '4') time.setTimeScale(2.0f);  // 快进
        if (key == '5') time.setTimeScale(5.0f);  // 极速
        if (key == ' ') {
            if (time.isPaused()) time.resume();
            else time.pause();
        }
    }
}
```

### 3.3 方案优缺点

| 优点 | 缺点 |
|------|------|
| 实现简单直观 | 物理模拟不稳定（可变步长导致不同帧率下结果不同） |
| 适合原型开发 | 碰撞检测可能漏检（物体在高速移动时穿越薄墙） |
| 资源消耗低 | 帧率骤降时物理精度下降 |

---

## 四、进阶实现：固定时间步长 + 插值渲染

如果你的引擎有物理模拟（如自定义碰撞系统、刚体动力学），可变步长会导致**确定性问题**——同样的输入在不同帧率下产生不同结果。这时需要固定逻辑更新频率。

这是 [Gaffer on Games](https://gafferongames.com/post/fix_your_timestep/) 的经典方案，加上时间缩放支持。

### 4.1 核心思想

```
真实时间线：|----|----|----|----|----|----|  (不规则，由硬件决定)
                ↓
逻辑更新：     |----|----|----|----|  (固定间隔，如 1/60 秒)
                ↓
渲染：         |--|--|--|--|--|--|  (每帧一次，在逻辑状态之间插值)
```

### 4.2 实现代码

```java
public class FixedTimeManager {
    
    // ========== 配置 ==========
    
    /** 固定逻辑更新频率（Hz） */
    private static final float FIXED_FPS = 60.0f;
    
    /** 固定时间步长（秒） */
    private static final float FIXED_DELTA = 1.0f / FIXED_FPS;
    
    // ========== 时间控制 ==========
    
    private float timeScale = 1.0f;
    private boolean isPaused = false;
    
    // ========== 内部状态 ==========
    
    private long lastRealTime;
    
    /** 时间累积器：存储"待处理"的游戏时间 */
    private float accumulator = 0.0f;
    
    /** 当前逻辑帧的游戏时间 */
    private float gameTime = 0.0f;
    
    // ========== 插值用状态 ==========
    
    /**
     * 为了渲染插值，需要保存上一帧和当前帧的状态。
     * 这里用简单的位置/旋转示例，实际项目中需要为所有可插值属性做双缓冲。
     */
    private Map<GameObject, Transform> previousState = new HashMap<>();
    private Map<GameObject, Transform> currentState = new HashMap<>();
    
    // ========== 初始化 ==========
    
    public void init() {
        lastRealTime = System.currentTimeMillis();
    }
    
    // ========== 主更新循环 ==========
    
    /**
     * 返回需要执行多少次固定步长的逻辑更新，以及用于渲染的插值比例。
     */
    public UpdateResult update() {
        long currentRealTime = System.currentTimeMillis();
        float realDelta = (currentRealTime - lastRealTime) / 1000.0f;
        lastRealTime = currentRealTime;
        
        // 防卡顿保护
        if (realDelta > 0.25f) realDelta = 0.25f;
        
        // 计算游戏时间增量
        float gameDelta = isPaused ? 0.0f : realDelta * timeScale;
        
        // 累加到 accumulator
        accumulator += gameDelta;
        
        // 计算需要执行多少次固定步长更新
        int steps = 0;
        while (accumulator >= FIXED_DELTA && steps < 5) {  // 最大 5 步防止螺旋死亡
            // 保存上一帧状态（用于插值）
            savePreviousState();
            
            // 执行固定步长的逻辑更新
            fixedUpdate(FIXED_DELTA);
            
            // 推进游戏时间
            gameTime += FIXED_DELTA;
            accumulator -= FIXED_DELTA;
            steps++;
        }
        
        // 计算插值比例：accumulator 中剩余的时间 / 固定步长
        // 表示"当前渲染时刻在两帧逻辑更新之间的位置"
        float alpha = accumulator / FIXED_DELTA;
        
        return new UpdateResult(steps, alpha);
    }
    
    // ========== 固定步长更新 ==========
    
    /**
     * 以固定步长更新逻辑。这是确定性模拟的核心。
     * 无论渲染帧率如何，这个方法的调用间隔永远是 FIXED_DELTA。
     */
    private void fixedUpdate(float dt) {
        // 物理模拟、碰撞检测、AI 决策...
        for (GameObject obj : gameObjects) {
            obj.physicsUpdate(dt);
        }
    }
    
    // ========== 插值渲染 ==========
    
    /**
     * 使用插值比例在两帧逻辑状态之间做平滑过渡。
     * 这让低帧率下的运动看起来仍然流畅。
     */
    public void render(float alpha) {
        for (GameObject obj : gameObjects) {
            Transform prev = previousState.get(obj);
            Transform curr = currentState.get(obj);
            
            if (prev != null && curr != null) {
                // 线性插值：rendered = prev + (curr - prev) * alpha
                float x = lerp(prev.x, curr.x, alpha);
                float y = lerp(prev.y, curr.y, alpha);
                float rotation = lerpAngle(prev.rotation, curr.rotation, alpha);
                
                obj.drawAt(x, y, rotation);
            } else {
                obj.draw();
            }
        }
    }
    
    // ========== 辅助方法 ==========
    
    private float lerp(float a, float b, float t) {
        return a + (b - a) * t;
    }
    
    /** 角度插值（处理 359° 到 0° 的环绕） */
    private float lerpAngle(float a, float b, float t) {
        float diff = b - a;
        while (diff > 180) diff -= 360;
        while (diff < -180) diff += 360;
        return a + diff * t;
    }
    
    private void savePreviousState() {
        previousState.clear();
        for (GameObject obj : gameObjects) {
            previousState.put(obj, obj.getTransform().copy());
        }
    }
    
    // ========== 控制接口 ==========
    
    public void setTimeScale(float scale) {
        this.timeScale = Math.max(0.0f, scale);
    }
    
    public void pause() { isPaused = true; }
    public void resume() { isPaused = false; }
    
    // ========== 数据结构 ==========
    
    public static class UpdateResult {
        public final int steps;      // 执行了多少次固定更新
        public final float alpha;    // 渲染插值比例 (0.0 ~ 1.0)
        
        public UpdateResult(int steps, float alpha) {
            this.steps = steps;
            this.alpha = alpha;
        }
    }
    
    public static class Transform {
        public float x, y, rotation;
        
        public Transform(float x, float y, float rotation) {
            this.x = x;
            this.y = y;
            this.rotation = rotation;
        }
        
        public Transform copy() {
            return new Transform(x, y, rotation);
        }
    }
}
```

### 4.3 方案优缺点

| 优点 | 缺点 |
|------|------|
| 物理模拟完全确定性 | 实现复杂度高 |
| 不同帧率下结果一致 | 需要状态双缓冲（内存增加） |
| 低帧率下运动仍然平滑（插值） | 逻辑更新频率固定，无法自适应 |
| 适合网络同步和回放系统 | 一帧可能触发多次 update |

---

## 五、时间缩放的控制接口

为了便于调试和玩法设计，建议暴露以下控制接口：

### 5.1 预设时间缩放档位

```java
public enum TimeScalePreset {
    PAUSED(0.0f, "暂停"),
    SUPER_SLOW(0.05f, "超级慢动作"),
    SLOW_MOTION(0.2f, "慢动作"),
    HALF_SPEED(0.5f, "半速"),
    NORMAL(1.0f, "正常"),
    DOUBLE_SPEED(2.0f, "双倍速"),
    FAST_FORWARD(5.0f, "快进"),
    TIME_LAPSE(10.0f, "延时");
    
    public final float scale;
    public final String label;
    
    TimeScalePreset(float scale, String label) {
        this.scale = scale;
        this.label = label;
    }
}
```

### 5.2 平滑过渡（Ease In/Out）

直接切换 timeScale 会导致突兀的速度跳变。建议加入插值过渡：

```java
public class SmoothTimeManager extends TimeManager {
    
    private float targetTimeScale = 1.0f;
    private float transitionSpeed = 3.0f;  // 每秒变化 3 倍
    
    @Override
    public void update() {
        super.update();
        
        // 平滑过渡到目标值
        float current = getTimeScale();
        if (Math.abs(current - targetTimeScale) > 0.001f) {
            float newScale = lerp(current, targetTimeScale, 
                                  1.0f - exp(-transitionSpeed * getRealDeltaTime()));
            setTimeScale(newScale);
        }
    }
    
    public void setTargetTimeScale(float target) {
        this.targetTimeScale = Math.max(0.0f, target);
    }
}
```

### 5.3 局部时间缩放（可选高级功能）

某些游戏需要**特定区域内**的时间缩放（如时间膨胀场）：

```java
public interface TimeZone {
    boolean contains(GameObject obj);
    float getLocalTimeScale();
}

// 使用时：
float dt = time.getDeltaTime();
for (GameObject obj : objects) {
    float localDt = dt;
    for (TimeZone zone : timeZones) {
        if (zone.contains(obj)) {
            localDt *= zone.getLocalTimeScale();
        }
    }
    obj.update(localDt);
}
```

---

## 六、实际应用场景

### 6.1 慢动作（Bullet Time）

```java
// 玩家触发技能时
time.setTargetTimeScale(0.1f);
time.setTransitionSpeed(5.0f);

// 2秒后恢复
delay(2000, () -> {
    time.setTargetTimeScale(1.0f);
});
```

**注意**：UI 和特效应该使用 `getRealDeltaTime()` 更新，保证在慢动作中菜单操作仍然跟手。

### 6.2 暂停菜单

```java
public void togglePauseMenu() {
    if (menu.isOpen()) {
        menu.close();
        time.resume();
    } else {
        menu.open();
        time.pause();
        // 或者 time.setTargetTimeScale(0.0f); 如果想做模糊背景动画
    }
}
```

### 6.3 模拟经营快进

```java
// 快进按钮
public void onFastForwardClick() {
    switch (currentSpeed) {
        case NORMAL: setSpeed(DOUBLE_SPEED); break;
        case DOUBLE_SPEED: setSpeed(FAST_FORWARD); break;
        case FAST_FORWARD: setSpeed(NORMAL); break;
    }
}
```

### 6.4 网络同步

在多人游戏中，服务器以固定逻辑帧率运行，客户端渲染帧率各不相同。时间缩放可以用于：

- **追赶机制**：客户端落后时加速到 1.2x 赶上服务器状态
- **平滑回滚**：检测到不同步时，减速到 0.5x 给状态同步争取时间

---

## 七、常见陷阱与解决方案

### 7.1 陷阱一：物理爆炸（Physics Explosion）

**现象**：timeScale 从 0 恢复时，物体速度瞬间变得极大。

**原因**：暂停期间速度持续累积，恢复时一次性释放。

**解决**：
```java
public void setTimeScale(float scale) {
    if (this.timeScale == 0.0f && scale > 0.0f) {
        // 从暂停恢复时，重置时间戳避免 delta 爆炸
        lastRealTime = System.currentTimeMillis();
    }
    this.timeScale = scale;
}
```

### 7.2 陷阱二：输入响应延迟

**现象**：慢动作时按键感觉有延迟。

**原因**：输入事件也按游戏时间处理。

**解决**：输入检测和 UI 响应始终使用**真实时间**。

```java
// 错误：用 deltaTime 做输入冷却
cooldown -= deltaTime;  // 慢动作时冷却也变慢！

// 正确：用 realDeltaTime 做输入冷却
cooldown -= realDeltaTime;  // 玩家操作不受 timeScale 影响
```

### 7.3 陷阱三：动画抖动

**现象**：timeScale 频繁变化时动画抖动。

**原因**：动画系统在不同 deltaTime 下采样不一致。

**解决**：
1. 动画更新使用平滑后的 deltaTime
2. 或者使用基于"游戏时间"的动画采样，而非基于"帧数"

```java
// 基于游戏时间的动画采样
float animationTime = sprite.getAnimationTime();  // 累计游戏时间
int frameIndex = (int)(animationTime * fps) % totalFrames;
```

### 7.4 陷阱四：音频不同步

**现象**：timeScale 变化时音频节奏乱了。

**解决**：
- 背景音乐：不受 timeScale 影响（用真实时间）
- 游戏音效（脚步、射击）：音调随 timeScale 变化（如慢动作时低沉）
- 使用音频引擎的播放速率控制（如 OpenAL 的 `alSourcef(source, AL_PITCH, timeScale)`）

---

## 八、与 p5engine 的整合建议

如果你要把这套系统整合进 p5engine，建议这样设计：

### 8.1 新增 Time 类

```java
// engine/core/Time.java
package engine.core;

public class Time {
    private static float timeScale = 1.0f;
    private static float deltaTime = 0.0f;
    private static float realDeltaTime = 0.0f;
    private static float gameTime = 0.0f;
    
    // 由引擎主循环每帧更新
    public static void update(float dt) {
        realDeltaTime = dt;
        deltaTime = dt * timeScale;
        gameTime += deltaTime;
    }
    
    public static float deltaTime() { return deltaTime; }
    public static float realDeltaTime() { return realDeltaTime; }
    public static float gameTime() { return gameTime; }
    public static float timeScale() { return timeScale; }
    public static void setTimeScale(float scale) { timeScale = Math.max(0, scale); }
}
```

### 8.2 修改 GameObject 基类

```java
// 让所有游戏对象默认使用 Time.deltaTime()
public void update() {
    position.add(velocity.copy().mult(Time.deltaTime()));
}
```

### 8.3 主循环修改

```java
public void draw() {
    // 计算真实 delta
    long now = System.currentTimeMillis();
    float dt = (now - lastTime) / 1000.0f;
    lastTime = now;
    
    // 更新时间系统
    Time.update(dt);
    
    // 更新场景（内部自动使用 Time.deltaTime()）
    scene.update();
    
    // 渲染
    scene.render();
}
```

### 8.4 关键设计决策

| 模块 | 使用什么时间 | 理由 |
|------|-------------|------|
| 物理/运动 | `Time.deltaTime()` | 受 timeScale 控制 |
| 粒子系统 | `Time.deltaTime()` | 慢动作时粒子也慢 |
| UI 动画 | `Time.realDeltaTime()` | 暂停时菜单还能动 |
| 输入冷却 | `Time.realDeltaTime()` | 玩家操作不能卡 |
| 网络超时 | `Time.realDeltaTime()` | 真实世界的等待 |
| 音频频率 | `Time.timeScale()` | 慢动作时音调降低 |

---

## 九、参考实现代码

以下是一个可直接使用的完整 Time 类实现，兼容 Processing：

```java
/**
 * Time.java - 游戏时间管理器
 * 
 * 使用方式：
 * 1. 在 setup() 中调用 Time.init()
 * 2. 在 draw() 开头调用 Time.update()
 * 3. 所有逻辑更新使用 Time.deltaTime()
 * 4. UI/输入使用 Time.realDeltaTime()
 * 5. 用 Time.setTimeScale() 控制游戏速度
 */
public class Time {
    
    // ========== 静态状态 ==========
    
    private static float _timeScale = 1.0f;
    private static float _deltaTime = 0.0f;
    private static float _realDeltaTime = 0.0f;
    private static float _gameTime = 0.0f;
    private static float _realTime = 0.0f;
    private static long _lastFrameTime = 0;
    private static boolean _initialized = false;
    
    // 防卡顿：最大允许的时间增量（秒）
    private static float MAX_DELTA_TIME = 0.25f;
    
    // ========== 初始化 ==========
    
    public static void init() {
        _lastFrameTime = System.currentTimeMillis();
        _initialized = true;
    }
    
    // ========== 每帧更新 ==========
    
    public static void update() {
        if (!_initialized) {
            init();
            return;
        }
        
        long currentTime = System.currentTimeMillis();
        float realDelta = (currentTime - _lastFrameTime) / 1000.0f;
        _lastFrameTime = currentTime;
        
        // 防卡顿
        if (realDelta > MAX_DELTA_TIME) {
            realDelta = MAX_DELTA_TIME;
        }
        
        _realDeltaTime = realDelta;
        _deltaTime = realDelta * _timeScale;
        
        _realTime += realDelta;
        _gameTime += _deltaTime;
    }
    
    // ========== 控制接口 ==========
    
    public static void setTimeScale(float scale) {
        _timeScale = Math.max(0.0f, scale);
    }
    
    public static float getTimeScale() {
        return _timeScale;
    }
    
    public static void pause() {
        setTimeScale(0.0f);
    }
    
    public static void resume() {
        setTimeScale(1.0f);
    }
    
    public static boolean isPaused() {
        return _timeScale == 0.0f;
    }
    
    // ========== 查询接口 ==========
    
    /** 游戏时间增量（受 timeScale 影响），用于所有游戏逻辑 */
    public static float deltaTime() {
        return _deltaTime;
    }
    
    /** 真实时间增量（不受 timeScale 影响），用于 UI/输入 */
    public static float realDeltaTime() {
        return _realDeltaTime;
    }
    
    /** 游戏累计时间（受 timeScale 影响） */
    public static float gameTime() {
        return _gameTime;
    }
    
    /** 真实累计时间（不受 timeScale 影响） */
    public static float realTime() {
        return _realTime;
    }
    
    // ========== 辅助方法 ==========
    
    /** 将游戏秒数转换为真实秒数 */
    public static float gameToRealSeconds(float gameSeconds) {
        if (_timeScale == 0) return Float.POSITIVE_INFINITY;
        return gameSeconds / _timeScale;
    }
    
    /** 将真实秒数转换为游戏秒数 */
    public static float realToGameSeconds(float realSeconds) {
        return realSeconds * _timeScale;
    }
}
```

---

## 总结

时间缩放的核心只有一句话：**渲染用真实时间，逻辑用游戏时间。**

实现上有两个层级：
1. **可变步长**：简单直接，适合 Physics-lite 的游戏
2. **固定步长 + 插值**：物理稳定，适合需要确定性的项目

对于 p5engine 这种 2D 引擎，建议先实现基础版本（第三章），需要物理确定性时再升级到固定步长方案（第四章）。

---

*整理时间：2026-04-21*
*适用引擎：Processing / p5.js / 自研 Java 2D 引擎*
