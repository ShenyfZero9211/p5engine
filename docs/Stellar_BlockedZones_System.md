# 星空星系不可建造区域系统

## 问题描述

游戏原有地图为纯色背景 + 网格线，所有区域均可建造防御塔（除路径附近自动 blocked 外）。为了让关卡设计更有策略深度，需要引入**不可建造区域**机制，同时将世界观升级为星空星系风格。

## 解决方案概述

引入 `BlockedZone` 系统：在关卡 YAML 中定义任意数量/形状的不可建造区域，并在视觉上以四种环境危害类型呈现，与星空平台世界观融为一体。

---

## 世界观设定：星域防线 (Stellar Perimeter)

公元 2847 年，人类联邦边疆前哨站接连失联。深空探测器传回的最后影像显示——被称为**"虚空虫群"(Void Swarm)** 的生物机械混合体正从星系裂隙中涌出。

玩家扮演星际联邦的**防御工程官**，在合金甲板上部署自动防御阵列。但并非所有区域都能承载防御塔：

| 可建造区域 | 不可建造区域 | 说明 |
|-----------|-------------|------|
| 合金平台甲板（带发光网格） | **虚空裂隙 (Void)** | 平台缺失，下方是深空 |
| | **小行星带 (Asteroid)** | 漂浮陨石占据空间 |
| | **能量湍流 (Energy)** | 不稳定离子风暴，电子设备失效 |
| | **残骸区 (Ruins)** | 旧时代建筑残骸，结构不可靠 |

---

## 技术实现

### 1. 数据层

**新增数据结构（TdConfig.pde）：**
```java
enum BlockedZoneType { RECT, CIRCLE }
enum BlockedVisualType { VOID, ASTEROID, ENERGY, RUINS }

static final class BlockedZone {
    final BlockedZoneType type;
    final float x, y, w, h;        // RECT
    final float cx, cy, radius;    // CIRCLE
    final BlockedVisualType visualType;
}
```

**LevelDef 新增字段：**
```java
BlockedZone[] blockedZones;  // optional, null = no extra blocked zones
```

### 2. 解析层（TdAssets.pde）

`parseLevel()` 读取可选的 `blockedZones` YAML 列表，支持：
- `type: rect` → `x, y, w, h`
- `type: circle` → `cx, cy, radius`
- `visual: asteroid | energy | void | ruins`（默认 void）

### 3. 逻辑层（TdGameWorld.pde）

`computeBlockedGrids()` 在原有"路径附近 grid 自动 blocked"逻辑之后，遍历 `level.blockedZones`：
- **RECT**：遍历包围盒内 grid，判断中心点是否在矩形内
- **CIRCLE**：遍历包围盒内 grid，判断中心点到圆心距离 ≤ radius

被 zone 覆盖的 grid 同时加入 `blockedGrids`（统一 blocked 集合）和 `zoneBlockedGrids`（环境危害来源标记）。

### 4. 渲染层（TdRenderers.pde）

**WorldBgRenderer 绘制顺序改造：**

1. **深空背景** `#080A14`
2. **星星场** — 固定种子随机分布，亮度 160-255，大小 1-3px
3. **星云** — 2-3 个大半透明色块（青色/紫色/橙色），alpha 5-8，缓慢漂移
4. **平台金属底色** `#14182B` — 覆盖整个世界矩形
5. **不可建造区域** — 根据 `visualType` 绘制不同效果：
   - **VOID**：用深空色覆盖平台（"挖空"效果），边缘绘制断裂虚线边框
   - **ASTEROID**：灰色不规则多边形岩石群（3 个重叠的不规则形状）
   - **ENERGY**：脉动半透明青色光晕 + 内部旋转十字线
   - **RUINS**：暗色不规则矩形块（倒塌的建筑残骸）
6. **网格线** — 颜色 `#354A6B`（在平台底色上清晰可见）
7. **路径/基地/出口/出生点** — 原有逻辑保持不变

**GhostRenderer 增强（TdGhost.pde）：**
- 环境危害 blocked grid：半透明橙色 `#55FF8844`
- 路径 blocked grid：半透明红色 `#55FF4444`

---

## 关卡配置示例

```yaml
blockedZones:
  - type: rect
    x: 600
    y: 400
    w: 120
    h: 120
    visual: asteroid
  - type: circle
    cx: 900
    cy: 400
    radius: 80
    visual: energy
  - type: rect
    x: 200
    y: 800
    w: 160
    h: 120
    visual: void
  - type: rect
    x: 1300
    y: 500
    w: 100
    h: 100
    visual: ruins
```

---

## 向后兼容

- 不写 `blockedZones` 的关卡完全正常运行，行为与之前一致
- 所有新增字段/逻辑均为 optional，不影响现有关卡

---

## 已配置 blockedZones 的关卡

| 关卡 | blockedZones |
|------|-------------|
| level_1 | asteroid (200,350,100,80) |
| level_3 | asteroid + energy + void + ruins（4 个区域）|
| level_4 | void + ruins |

---

## 验证结果

- ✅ Java 引擎编译通过 (`compile-jar.ps1`)
- ✅ PDE 示例编译通过 (`processing.exe cli --build`)
- ✅ 游戏运行正常，FPS 稳定 60
- ✅ 截图验证：星空背景 + 平台底色 + 小行星带视觉效果正确呈现
- ✅ 向后兼容：未配置 blockedZones 的关卡正常运行
