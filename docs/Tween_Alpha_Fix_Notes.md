# Tween Alpha 动画修复记录

## 问题描述

v0.2.0 引入的 Tween 动画系统在所有示例（TweenDemo）中验证通过，但在 **TowerDefenseMin** 中完全看不到动画效果：

- 主菜单面板、按钮的淡入动画不生效
- 关卡选择面板、结束界面的淡入动画不生效
- Tween 数值本身正常计算（日志确认），但视觉上无变化

## 根本原因

### 1. TdSciFiTheme 不响应 `setCurrentAlpha()`

Tween 系统通过以下链路工作：

```
Tween.update() → target.setAlpha(v)
                 → UIComponent.getEffectiveAlpha()
                 → theme.setCurrentAlpha(alpha)
                 → Theme.drawXxx() 使用 currentAlpha 绘制
```

**问题**：`TdSciFiTheme` 使用了大量硬编码的 `g.color(r,g,b,a)` 和 `g.fill(r,g,b,a)`，且没有覆盖 `Theme.setCurrentAlpha()` 方法（继承了默认空实现）。因此：

- Tween 确实每帧修改了 `UIComponent.alpha`
- `UIComponent.paint()` 也确实调用了 `theme.setCurrentAlpha(getEffectiveAlpha())`
- 但 `TdSciFiTheme` 完全忽略了这个值，继续用原始透明度绘制
- 结果：**数学上在动，视觉上没动**

### 2. DefaultTheme.drawLabel 单行模式导致多行文本偏移

`DefaultTheme.drawLabel()` 原来使用 `g.text(str, tx, y + h*0.5f)` 单行绘制：

- 当文本包含 `\n` 时，第一行基线被放在垂直中心
- 后续行向下延伸，导致整个文本块**偏下**，不是真正的垂直居中

### 3. Label 默认对齐为 CENTER

`Label` 默认 `textAlign = PApplet.CENTER`，对数字列表等多行内容不友好，视觉上看起来"偏"。

## 修复内容

### 一、TdSciFiTheme 全面支持 Alpha

在 `TdSciFiTheme.pde` 中：

1. 添加 `currentAlpha` 字段和 `setCurrentAlpha()` 方法
2. 添加 `ca()` 辅助方法，将颜色 alpha 通道乘上 `currentAlpha`：
   ```java
   private int ca(PApplet g, int r, int gr, int b) {
       return g.color(r, gr, b, (int)(255 * currentAlpha));
   }
   private int ca(PApplet g, int r, int gr, int b, int a) {
       return g.color(r, gr, b, (int)(a * currentAlpha));
   }
   ```
3. 将 **所有** `drawPanel`、`drawButton`、`drawLabel`、`drawSliderTrack`、`drawWindowChrome` 中的颜色调用替换为 `ca()` 版本

**修改前后对比**（以 drawButton 为例）：

```java
// 修改前
int fillBg = disabled ? g.color(28, 28, 32, 200)
  : (pressed ? g.color(24, 48, 72, 240) : ...);

// 修改后
int fillBg = disabled ? ca(g, 28, 28, 32, 200)
  : (pressed ? ca(g, 24, 48, 72, 240) : ...);
```

### 二、DefaultTheme.drawLabel 改用 text box 模式

```java
// 修改前
g.text(text, tx, y + h * 0.5f);

// 修改后
g.text(text, x, y, w, h);
```

配合 `textAlign(textAlign, CENTER)`，Processing 会自动将**整个文本块**在 `x,y,w,h` 矩形内水平和垂直居中，多行文本不再偏下。

### 三、Label 默认对齐改为 LEFT

```java
// 修改前
private int textAlign = PApplet.CENTER;

// 修改后
private int textAlign = PApplet.LEFT;
```

如需居中，代码中手动设置：
```java
label.setTextAlign(PApplet.CENTER);
```

### 四、新增 TweenDemo 示例

新建 `examples/TweenDemo/`，独立验证四种 Tween 动画：

| 动画类型 | 目标 | 效果 |
|---------|------|------|
| Alpha | UI Panel | 延迟 1s 后淡入 2s |
| Position | GameObject (方块) | 左右往返，无限循环 |
| Scale | GameObject (圆形) | 每 2s 弹跳一次 (outBack) |
| Rotation | GameObject (指针) | 持续旋转 |

### 五、TowerDefenseMin 新增 Tween Test 按钮

在主菜单新增独立按钮 `"Tween Test"`，延迟 3s 后缓慢淡入，用于在复杂主题环境中验证 alpha tween。

## 验证结果

- **TweenDemo**：编译运行通过，四种动画全部可见
- **TowerDefenseMin**：主菜单面板、标题、按钮、载入提示、Tween Test 按钮的依次淡入动画全部正常显示
- **关卡选择**、**结束界面**的淡入动画也恢复正常

## 经验总结

1. **自定义 Theme 必须响应 `setCurrentAlpha()`**：只要 Theme 使用硬编码颜色，alpha tween 就必然失效。
2. **UI Layout 会覆盖 position/size tween**：`TdUiLayout.layout()` 每帧调用 `setBounds()`，会覆盖 `toX/toY/toWidth/toHeight`。如需位置动画，应作用于 **GameObject**（不受 UI layout 管理）或暂停 layout。
3. **Alpha tween 是最安全的 UI 动画类型**：因为它不触及位置/尺寸，不会被 layout 系统干扰。
4. **PDE 语法限制**：访问 Java 静态方法时，在 PDE 中必须用方法引用 `Ease::outQuad`，不能写 `Ease.outQuad`（会被预处理器错误解析为字段访问）。
