# 建塔按钮图标替换为实际塔渲染样式

## 目标
将右侧建造面板中各塔按钮的蓝色方块+字母图标，替换为对应塔类型在世界中的实际渲染样式（颜色、形状一致）。

## 背景
当前 `TowerButton.paint()` 中的图标绘制代码：
```java
applet.fill(TdConfig.C_ACCENT);
applet.rect(iconX, iconY, iconSize, iconSize);
applet.fill(TdTheme.BG_DARK);
applet.text(initial, iconX + iconSize * 0.5f, iconY + iconSize * 0.5f);
```
所有塔按钮都是统一的蓝色方块加字母（M/W/L/S），无法直观区分塔类型。

世界中 `TowerRenderer.renderShape()` 对各塔的实际渲染：
- **MG**: 圆角矩形主体 + 顶部一条白色短横线
- **MISSILE**: 圆形主体 + 中心白色小圆
- **LASER**: 旋转45°的圆角矩形 + 中心白色小圆
- **SLOW**: 六边形主体 + 中心白色小圆

## 实施步骤
1. **修改 `TdUiHud.pde`** — 在 `TowerButton` 类中：
   - 将 `paint()` 中的图标绘制部分替换为按 `towerType` 绘制实际塔形状
   - 使用 `def.iconColor` 作为主体填充色
   - 在 32×32 的图标区域内居中绘制，保留各塔类型的特征细节（白线/中心圆）
   - 添加辅助方法绘制六边形（SLOW塔需要）
2. **编译验证** — 运行 `compile-jar.ps1` 和 Processing CLI 构建，确认按钮正常显示且可点击

## 验收标准
- [ ] 机枪塔按钮显示圆角矩形+顶部白线的图标
- [ ] 导弹塔按钮显示圆形+中心小圆的图标
- [ ] 激光塔按钮显示旋转45°的矩形+中心小圆的图标
- [ ] 减速塔按钮显示六边形+中心小圆的图标
- [ ] 各按钮图标颜色与 `def.iconColor` 一致
- [ ] 按钮的选中/悬停/按下状态不受影响
- [ ] 编译通过，游戏可正常运行

## 相关文件
- `examples/TowerDefenseMin2/TdUiHud.pde`（TowerButton.paint 方法）
- `examples/TowerDefenseMin2/TdRenderers.pde`（TowerRenderer.renderShape 参考实现）
