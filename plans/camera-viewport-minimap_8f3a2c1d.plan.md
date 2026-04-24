> **状态：已完成** ✅

# 塔防游戏地图区域限制与小地图修复

## 目标
将 TowerDefenseMin 的地图画面限制在左侧矩形区域（扣除顶部 HUD 和右侧建造面板），并把小地图移至右侧面板下方并正确显示塔、敌人等对象。

## 背景
- 当前 Camera2D viewport 为全屏 1280×720，世界层渲染覆盖整个画布。
- 小地图（Minimap）位于 `setRect(1000, 520, 220, 220)`，但在 P2D 模式下背景色几乎不可见，且只追踪名为 `"ship"` 的对象，塔防游戏中没有 ship。
- 用户期望：地图区域框定在左侧红色矩形内（宽 1280−240=1040，高 720−40=680，顶部偏移 40），UI 占据其余区域；小地图放在右侧面板下方（绿色框）。

## 实施步骤
1. **扩展 Camera2D**：增加 `viewportOffsetX/Y`，让相机坐标系以子区域为中心，修改 `begin()`、`worldToScreen()`、`screenToWorld()`、`zoomAt()`。
2. **扩展 Minimap**：
   - 支持按名称前缀追踪任意 GameObject（`addTrackedName`）。
   - 修复 `setFillRGB` 为 `setFillRGBA`，在 P2D 下保留 alpha。
   - 调亮默认颜色，提升可见度。
3. **修改 TowerDefenseMin 示例**：
   - 设置相机 viewport 为 1040×680，偏移 (0, 40)。
   - 重设小地图位置到右侧面板下方，配置追踪 `Tower_`、`Enemy_`、`Orb_`。
   - 在 `windowResized()` 中同步更新相机 viewport。
4. **编译验证**：编译引擎 jar，复制到示例 code 目录，用 Processing CLI 编译示例。

## 验收标准
- [ ] 世界层（地图、敌人、塔、特效）只渲染在左侧 1040×680 区域内，不覆盖右侧面板。
- [ ] 小地图可见，位于右侧面板下方，显示世界边界、相机视口（绿色框）、塔（蓝点）、敌人（红点）、基地球（黄点）。
- [ ] 鼠标缩放/平移/建造在限制后的地图区域内正常工作。
- [ ] 引擎 jar 编译通过，示例 PDE 编译通过。

## 相关文件
- `src/main/java/shenyf/p5engine/rendering/Camera2D.java`
- `src/main/java/shenyf/p5engine/rendering/Minimap.java`
- `examples/TowerDefenseMin/TdFlowController.pde`
- `examples/TowerDefenseMin/TowerDefenseMin.pde`
- `examples/TowerDefenseMin/TdUiLayout.pde`

