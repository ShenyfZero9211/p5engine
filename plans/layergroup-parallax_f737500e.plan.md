# LayerGroup 视差背景扩展

## 目标
引擎级支持按 renderLayer 分组应用不同视差系数，实现多层星空背景的视差效果。

## 背景
当前 `Scene.renderWorld()` 对所有 renderLayer < 100 的对象只施加一套相机变换。需要将背景星星/星云/亮星拆分到不同 renderLayer，每层绑定不同 parallax 系数（0.08 / 0.25 / 0.45），形成深度感。

## 实施步骤
1. 新增 `LayerGroup` 类（layerMin/layerMax/parallaxX/parallaxY）
2. 修改 `Camera2D.begin()` 添加 parallax 重载
3. 修改 `Scene.renderWorld()` 按 LayerGroup 分组渲染
4. 编译引擎 JAR
5. PDE 侧拆分 `WorldBgRenderer` 为 4 层（far/mid/near/platforms）
6. PDE 侧配置 LayerGroup
7. 编译验证

## 验收标准
- [ ] 远景星星以 0.08 视差跟随相机
- [ ] 中景星云以 0.25 视差跟随相机
- [ ] 近景亮星以 0.45 视差跟随相机
- [ ] 平台/路径/游戏对象以 1.0 正常跟随相机
- [ ] 不配置 LayerGroup 时向后兼容（行为不变）
