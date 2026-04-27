# 建塔按钮选中音效

## 目标
为右侧建造面板中的四个塔按钮（TowerButton）添加**点击选中时**的音效触发。

## 背景
- `TdUiHud.pde` 中 `TowerButton` 继承自 p5engine 的 `Button` 类。
- `Button.onEvent()` 在 `MOUSE_RELEASED` 且命中时执行 `action.run()`，但引擎基类没有内置音效钩子。
- `TdSound` 已封装了 `playClick()` 等快捷方法，可直接复用。
- 取消按钮（`btn_cancel`）也是 `Button`，但用户明确说"建塔按钮"，所以只给塔按钮加。

## 实施步骤

1. **在 TowerButton 的 action 中播放音效**
   - `TdUiHud.pde` 中 `TdBuildPanel` 构造塔按钮时，`btn.setAction()` 的 lambda 里在设置 `app.buildMode = mode` 之后，调用 `TdSound.playClick()`（或 `TdAssets.playSfx(...)`）。
   - 这是最简洁的方式，不需要修改引擎源码或 TowerButton 类本身。

2. **编译验证**
   - 用 Processing CLI 编译示例验证通过。

## 验收标准
- [ ] 点击任意塔按钮（机枪/导弹/激光/减速）时播放一次选中音效
- [ ] 取消按钮不播放该音效
- [ ] 示例工程编译通过

## 相关文件
- `examples/TowerDefenseMin2/TdUiHud.pde`
