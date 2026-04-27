# TowerDefenseMin2 v0.7.0 核心机制重构总结

## 问题描述

原游戏机制过于简单：
- 只有单一敌人类型，通过波次缩放 HP/Speed
- 关卡配置扁平，无法表达复杂波次组合
- 无能量球系统，游戏目标单一
- 无多种关卡类型

## 重构内容

### 1. 能量球系统 (Orb System)

**规则：**
- **DEFEND_BASE 模式**：基地持有能量球，敌人到达基地后窃取（最多 `orbCapacity` 个）
- 携带能量球的敌人死亡时，能量球掉落在路径上，缓慢返回基地
- 返回中的能量球可被其他敌人截获
- 敌人携带能量球逃出出口，能量球永久丢失
- 胜利条件：所有波次完成、所有敌人被消灭，且至少还有 1 个能量球在基地或返回途中
- 失败条件：基地空了 + 没有能量球在返回途中 + 场上没有携带能量球的敌人（所有带能量球的都已撤离）

**新增文件：**
- `Orb.pde` — 能量球实体（返回路径、被截获检测）
- `OrbRenderer` — 能量球渲染（金色光球 + 高光）

**修改文件：**
- `Enemy.pde` — 新增 `orbsCarried`、`enemyDef` 字段，STEAL 状态窃取能量球
- `TdGameWorld.pde` — 新增 `orbs` 列表、`releaseOrb()`、`checkWinLose()` 适配
- `TdSaveData.pde` — `incOrbsLost()` 改为接受 `int count` 参数

### 2. 双关卡类型 (LevelType)

| 类型 | 目标 | 胜利条件 | 失败条件 |
|------|------|----------|----------|
| DEFEND_BASE | 保护基地能量球 | 波次完成+敌人全灭，且还有能量球 | 所有能量球被窃取且全部丢失 |
| SURVIVAL | 控制敌人逃离数量 | 波次完成+敌人全灭，且逃离数<上限 | 逃离敌人数量达到上限 |

**修改文件：**
- `TdConfig.pde` — 新增 `LevelType` enum，`LevelDef` 增加 `levelType`、`baseOrbs`、`maxEscapeCount`
- `levels.yaml` — 每个关卡增加 `levelType` 字段，`DEFEND_BASE` 用 `baseOrbs`，`SURVIVAL` 用 `maxEscapeCount`
- `TdHUD.pde`、`TdUiHud.pde` — 根据关卡类型显示不同状态（♦ 能量球 / 逃 逃离计数）

### 3. 四种敌人类型 (Enemy Types via YAML)

`data/config/enemies.yaml` 定义：

| 类型 | 速度倍率 | HP 倍率 | 能量球容量 | 半径 |
|------|----------|---------|-----------|------|
| level1 | 1.0x | 1.0x | 1 | 14 |
| level2 | 1.5x | 1.5x | 2 | 16 |
| level3 | 2.0x | 2.0x | 1 | 14 |
| level4 | 0.5x | 3.5x | 3 | 20 |

**修改文件：**
- `TdConfig.pde` — 新增 `EnemyDef` 类
- `TdAssets.pde` — 新增 `loadEnemyDef()` 方法
- `TdGameWorld.pde` — `spawnEnemy()` 改为按类型键生成
- `TdRenderers.pde` — `EnemyRenderer` 增强：
  - 携带能量球的敌人显示金色
  - 能量球容量 > 1 的敌人在身后显示容量指示点

### 4. 灵活波次生成系统 (Wave Spawn System)

`levels.yaml` 新格式：
```yaml
waves:
  - delay: 2.0
    spawns:
      - type: level1
        count: 5
        interval: 0.6
  - delay: 5.0
    spawns:
      - type: level1
        count: 8
        interval: 0.5
      - type: level2
        count: 2
        interval: 1.0
```

**修改文件：**
- `TdConfig.pde` — 新增 `WaveSpawn`、`WaveDef` 类
- `TdAssets.pde` — `parseLevel()` 解析新 wave 格式
- `TdGameWorld.pde` — `update()` 中迭代 `waves[]` 和 `spawns[]` 生成敌人

### 5. 关卡 YAML 扩展配置

新增可选字段：
- `allowedTowers` — 限定本关可建造的塔类型，默认全部
- `earnMoneyOnKill` — 击杀是否获得金钱，默认 true

第 2 关示例：`allowedTowers: [MG, LASER]` + `earnMoneyOnKill: false`

### 6. 多路径分叉/重叠系统 (Multi-Path System)

将单条 polyline 路径重构为支持多路径网络的系统：

**新 YAML 格式：**
```yaml
paths:
  - id: north_in
    type: INBOUND
    points:
      - { x: 200, y: 200 }
      - { x: 600, y: 200 }
      - { x: 1000, y: 800 }
  - id: south_in
    type: INBOUND
    points:
      - { x: 200, y: 1400 }
      - { x: 600, y: 1400 }
      - { x: 1000, y: 800 }
  - id: east_out
    type: OUTBOUND
    points:
      - { x: 1000, y: 800 }
      - { x: 1400, y: 400 }
      - { x: 1800, y: 400 }
  - id: southeast_out
    type: OUTBOUND
    points:
      - { x: 1000, y: 800 }
      - { x: 1400, y: 1200 }
      - { x: 1800, y: 1400 }
```

- `INBOUND`：从出生点到基地的路径
- `OUTBOUND`：从基地到撤离点的路径
- `DIRECT`：独立路径（不经过基地，用于 SURVIVAL）

波次 spawn 可指定 `route`（path id）控制敌人生成路径。

旧格式 `pathPoints` 保持兼容：自动拆分为 INBOUND + OUTBOUND（DEFEND_BASE）或 DIRECT（SURVIVAL）。

**新增数据结构：**
- `RouteType` enum — INBOUND / OUTBOUND / DIRECT
- `PathRoute` 类 — 复用 `TdPath` 作为底层 polyline，含 `baseDistance`

**核心逻辑变更：**
- `Enemy`：持有 `inboundRoute` + `outboundRoute` + `activeRoute`，STEAL 后自动切换到随机 OUTBOUND route
- `Orb`：记录所属 `PathRoute`，沿该 route 返回基地
- `TdGameWorld.spawnEnemy()`：根据波次 `route` 配置或关卡类型随机选择 route
- `WorldBgRenderer`：绘制所有 route 的路径段

**新增关卡：**
- Level 3（DEFEND_BASE）：2 条 INBOUND + 2 条 OUTBOUND，展示分叉路径

### 7. 小地图增强

- `TdMinimap.pde` — 新增能量球显示（金色小点）

## 验证结果

- **编译**：Processing CLI `exit code 0`，无编译错误
- **运行测试**：游戏正常启动，主菜单/音频/UI 交互无异常
- **无 Java 异常**：stderr 仅包含 libpng 警告（已知无害）

## 相关文件

- `examples/TowerDefenseMin2/data/config/enemies.yaml`
- `examples/TowerDefenseMin2/data/config/levels.yaml`
- `examples/TowerDefenseMin2/TdConfig.pde`
- `examples/TowerDefenseMin2/TdAssets.pde`
- `examples/TowerDefenseMin2/Enemy.pde`
- `examples/TowerDefenseMin2/Orb.pde`
- `examples/TowerDefenseMin2/TdGameWorld.pde`
- `examples/TowerDefenseMin2/TdRenderers.pde`
- `examples/TowerDefenseMin2/TdHUD.pde`
- `examples/TowerDefenseMin2/TdUiHud.pde`
- `examples/TowerDefenseMin2/TdMinimap.pde`
- `examples/TowerDefenseMin2/TdSaveData.pde`
