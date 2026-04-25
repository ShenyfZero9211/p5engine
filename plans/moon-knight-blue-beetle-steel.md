# 子弹对象池优化

## 目标
将 Bullet 的创建/销毁改为对象池机制，减少每帧的 GC 压力。塔防游戏中机枪塔射速快，子弹数量多且生命周期短（3秒或命中即销毁），是对象池的最佳应用场景。

## 背景

当前 `Tower.fireAt()` 每次射击都 `new Bullet()` + `GameObject.create()` + `new BulletRenderer()`：

```java
void fireAt(Enemy target) {
    Bullet b = new Bullet();
    b.pos = new Vector2(worldX, worldY);
    // ... 初始化字段 ...
    TdGameWorld.bullets.add(b);

    GameObject bGo = GameObject.create("Bullet");
    bGo.addComponent(new BulletRenderer(b));
    TowerDefenseMin2.inst.gameScene.addGameObject(bGo);
    b.gameObject = bGo;
}
```

销毁时 `Bullet.markDead()` 调用 `gameObject.markForDestroy()`，由 Scene 在帧末清理。这意味着每颗子弹产生：
- 1 个 Bullet 实例
- 1 个 GameObject 实例
- 1 个 BulletRenderer 实例
- 若干 Vector2 实例

机枪塔射速 0.1s/发，10 座塔同时射击 = 100 颗子弹/秒，GC 压力显著。

## 方案

### 设计思路

引擎的 `ObjectPool` 只管理 `GameObject`，不管理自定义 PDE 类（如 `Bullet`）。因此采用**两层池化**：

1. **GameObject 层**：使用引擎 `ObjectPool` 复用 `GameObject` + `BulletRenderer`
2. **Bullet 数据层**：在 `Bullet` 类中实现 `reset()` 方法，复用 Bullet 实例

### 步骤 1：改造 Bullet 类支持复用

```java
static class Bullet {
    Vector2 pos = new Vector2();
    Vector2 vel = new Vector2();
    float damage;
    float aoeRadius;
    float laserBonus;
    float slowFactor;
    float life;
    boolean dead;
    GameObject gameObject;

    // 重置用于对象池复用
    void reset(float x, float y, float vx, float vy, float dmg, float aoe, float laser, float slow) {
        pos.set(x, y);
        vel.set(vx, vy);
        damage = dmg;
        aoeRadius = aoe;
        laserBonus = laser;
        slowFactor = slow;
        life = 3.0f;
        dead = false;
    }

    void markDead() {
        dead = true;
        if (gameObject != null) {
            // 不再 markForDestroy，而是回收到对象池
            TowerDefenseMin2.inst.engine.getObjectPool().release("bullet", gameObject);
            gameObject = null;
        }
    }
    // ... update() / hit() 保持不变 ...
}
```

### 步骤 2：改造 Tower.fireAt() 使用对象池

```java
void fireAt(Enemy target) {
    TowerDefenseMin2 app = TowerDefenseMin2.inst;
    ObjectPool pool = app.engine.getObjectPool();

    // 从池中获取或创建 GameObject
    GameObject bGo = pool.acquire("bullet");
    if (bGo == null) {
        // 首次使用：创建并注册到池
        bGo = GameObject.create("Bullet");
        bGo.setRenderLayer(15);
        BulletRenderer renderer = new BulletRenderer();
        bGo.addComponent(renderer);
        app.gameScene.addGameObject(bGo);
        // 注册到对象池（只需一次）
        pool.register("bullet", () -> {
            GameObject go = GameObject.create("Bullet");
            go.setRenderLayer(15);
            go.addComponent(new BulletRenderer());
            app.gameScene.addGameObject(go);
            return go;
        }, go -> {
            // resetter：重置 GameObject 状态
            go.setActive(true);
            go.getTransform().setPosition(0, 0);
        });
    }

    // 获取或创建 Bullet 数据对象
    BulletRenderer renderer = bGo.getComponent(BulletRenderer.class);
    Bullet b = renderer.bullet;
    if (b == null) {
        b = new Bullet();
        renderer.bullet = b;
    }

    // 初始化子弹数据
    Vector2 dir = target.pos.copy().sub(worldX, worldY).normalize().mult(400);
    b.reset(worldX, worldY, dir.x, dir.y, def.damage, def.aoeRadius, def.laserBonus, def.slowFactor);
    b.gameObject = bGo;
    bGo.getTransform().setPosition(b.pos.x, b.pos.y);

    TdGameWorld.bullets.add(b);
    TdAssets.playSfx(def.sfxFire);
}
```

### 步骤 3：改造 BulletRenderer 支持动态绑定

```java
static class BulletRenderer extends RendererComponent {
    Bullet bullet;  // 由 Tower.fireAt() 动态绑定

    @Override
    protected void renderShape(PGraphics g) {
        if (bullet == null || bullet.dead) return;
        // ... 原有渲染代码 ...
    }
}
```

### 步骤 4：改造 TdGameWorld 更新循环

当前 `bullets.remove(i)` 只是从 ArrayList 移除，现在需要确保死掉的子弹被正确回收：

```java
for (int i = bullets.size() - 1; i >= 0; i--) {
    Bullet b = bullets.get(i);
    b.update(dt);
    if (b.dead) {
        // markDead() 内部已经调用 pool.release()
        // 只需从列表移除
        bullets.remove(i);
    }
}
```

### 步骤 5：关卡切换时清理

```java
static void startLevel(...) {
    // ... 现有清理代码 ...
    for (Bullet b : bullets) {
        if (b.gameObject != null) {
            b.gameObject.markForDestroy();  // 彻底销毁，不归池
        }
    }
    bullets.clear();
    // 清空对象池（避免旧关卡子弹残留）
    app.engine.getObjectPool().clear();
}
```

### 步骤 6：预加载（可选）

在关卡开始时预创建一批子弹：

```java
static void startLevel(TowerDefenseMin2 app, int levelId) {
    // ... 现有初始化 ...
    // 预加载 50 颗子弹到池中
    app.engine.getObjectPool().preload("bullet", 50);
}
```

## 验收标准

- [ ] 子弹使用对象池复用，不再频繁 new/delete
- [ ] 机枪塔快速射击时无 GC 卡顿
- [ ] 子弹命中/超时后正确回收到池
- [ ] 关卡切换时对象池正确清理
- [ ] 子弹渲染正常，无视觉异常
- [ ] 性能对比：对象池版本 vs 原版的子弹创建数量（可通过日志统计）

## 相关文件

- `examples/TowerDefenseMin2/Bullet.pde`
- `examples/TowerDefenseMin2/Tower.pde`
- `examples/TowerDefenseMin2/TdGameWorld.pde`
- `examples/TowerDefenseMin2/TdRenderers.pde`（BulletRenderer）
