# TowerDefenseMin

Minimal **tower defense** sketch for **Processing 4** + **p5engine** (`P5Engine`, `SceneManager` / `Scene`, `GameObject` / `Component`, `UIManager`). It is meant to validate the engine loop and UI input split, not to match commercial TD visuals.

## Sketch layout (tabs)

| File | Role |
|------|------|
| `TowerDefenseMin.pde` | `settings` / `setup` / `draw`, engine + UI glue, save/load entrypoints |
| `TdConfig.pde` | Layout and balance constants |
| `TdTowerModel.pde` | `TowerKind`, `TowerDef` |
| `TdPathModel.pde` | `TdPath` |
| `TdEntities.pde` | `TdEnemy`, `TdRollingOrb` |
| `TdGameWorld.pde` | Match state: waves, orbs, combat, drawing the battlefield |
| `TowerController.pde` | `Component` on tower `GameObject` (must stay `public static` for reflection) |
| `TdUiLayout.pde` | `null`-layout `setBounds` for all panels |
| `TdUiFonts.pde` | CJK-safe `PFont` + `UIManager.setUiFont` (P2D text fix) |
| `TdSciFiTheme.pde` | Custom `Theme` (Defense Grid–style panels / buttons / sliders) |

## Run

1. Build or copy `p5engine.jar` into this sketch’s `code/` folder (same pattern as other `examples/` sketches).
2. Open `TowerDefenseMin.pde` in Processing and run.

**UI / font:** The sketch uses `P2D` and `TdUiFonts` + `UIManager.setUiFont` so Chinese labels render; `TdSciFiTheme` supplies the dark sci-fi HUD look. Engine `UIManager.setUiFont` is optional for other sketches—see `docs/p5engine-UI系统说明与Agent指南.md` §5.1.1.

## Controls

- **主菜单**: 开始游戏 / 载入游戏 / 设置 / 退出（退出调用 `exit()`）。
- **局内**: 右侧选塔类型，在**战场区**（左侧，非顶栏、非右栏）左键点击网格放置。顶栏 **保存** 写入 `save.json`（`sketchPath()`），**菜单** 返回主菜单。
- **胜负**: 基地有 `INITIAL_ORBS`（默认 3）个能量球；敌人经过基地会取球，带到**撤离点**则永久丢失。`lostOrbs >= INITIAL_ORBS` 失败。打五波敌人且仍有球未全部丢失则胜利。携带者被击杀时球沿路径**回滚**向基地，途中可被其他敌人再次拾取。

## Extending towers

1. Add an enum value to `TowerKind`.
2. Extend `TowerDef.forKind(...)` with `cost`, `range`, `firePeriod`, `damage`, `aoeRadius`, `slowFactor`, copy text blurb.
3. Add a `Button` in `buildUi()` / `mkTowerBtn(...)` for the new type.
4. If behavior is not covered by `TowerController.tick` / `damageEnemyNearest`, extend that logic (still sketch-local).

`TowerKind` + `TowerDef` + `TowerController` on `GameObject` is the extension point; no engine core changes are required for new tower types.

## Engine relationship

- **`settings()`**: `size`, `smooth`, `P5Engine.applyRecommendedPixelDensity(this)` only — do not call `smooth()` from `setup()` with `P2D` (Preprocessor / duplicate `settings()` issue; see `ImageLab`).
- **Loop**: `background` → `engine.update()` (updates `Scene` + `GameObject` components) → custom battlefield `draw` → `layoutUi()` + `ui.update(dt)` + `ui.render()`. **`engine.render()` is intentionally not used** so the renderer does not clear over the sketch background (see `P5Engine.render()` + `ProcessingRenderer.clear`).
- **Scenes**: `Menu` and `Game` scenes exist; towers live only on the `Game` scene. State machine uses `appMode` for menu / settings / playing / end overlays.
- **UI**: `UIManager` root uses `null` layout; bounds are set every frame like `ImageLab`.

## Save format (`save.json`)

Minimal fields: `version`, `money`, `baseOrbs`, `lostOrbs`, `wave`, `toSpawn`, `betweenWaves`, `interWaveDelay`, `allWavesSpawned`, `spawnCooldown`, `matchElapsed`, slider placeholders, `towers` array `{ kind, x, y }`.

## DEFECTS / friction (optional)

| Topic | Note |
|--------|------|
| `engine.render()` vs sketch | Clearing the framebuffer conflicts with custom layered drawing; documented workaround: custom draw + `engine.update()` only. |
| Win / lose | Shown once via `appMode`; game logic stops updating when not in play mode `2`. |
| Hit testing | Tower placement uses geometry only (battlefield x range, y below HUD); full modal routing could be tightened later. |
