# Sketch UI bootstrap (p5engine)

This note summarizes **recurring patterns** when a Processing sketch grows, how to split responsibilities (**Bootstrap vs Flow vs UiBuilder**), and what belongs **in the engine jar vs in the sketch**. It pairs with **`SketchUiCoordinator`** in `shenyf.p5engine.ui` (see Javadoc for the canonical per-frame ordering).

---

## Recurring patterns (what goes wrong)

1. **Main `.pde` tab bloat**  
   `settings`, `setup`, and `draw` accumulate: menu modes, save/load, scene switches, HUD text updates, and input handling — all on one class, hard to navigate and test.

2. **Callbacks pinned to the sketch**  
   `Button.setAction(() -> sketch.someMethod())` keeps navigation and rules on the main tab. Prefer **`setAction(() -> flow.someMethod())`** so the sketch tab stays a thin entrypoint.

3. **Unclear draw order**  
   A stable frame is usually: clear / world underlay → **`P5Engine.update()`** → simulation tick → world draw → optional manual **`setBounds` / `layout`** on extra roots → **`UIManager.update(dt)`** → sync labels from state → **optional `textFont` / theme** → **`UIManager.render()`**. Skipping or reordering steps causes layout glitches or wrong hover hit-tests.

4. **`P2D` + CJK / custom fonts**  
   Font setup often must run **immediately before** the UI paint pass. **`SketchUiCoordinator.setPreRenderHook`** centralizes that instead of scattering `ensureFont` before `ui.render()`.

5. **Pooled widgets (`beginFrame` / `endFrame`)**  
   If you build transient widgets from a pool each frame, keep that block **adjacent** to `update`/`render`; **`SketchUiCoordinator`** does not replace `beginFrame`/`endFrame` — it only wraps the common **`update` + pre-render + `render`** path (see `examples/UIDemo`).

---

## Recommended layers (sketch-side)

Three sketch-side roles keep **`p5engine.jar`** free of game-specific types (tower enums, your save JSON shape, world sim classes, etc.).

| Layer | Role | Typical location | Should not |
|-------|------|------------------|------------|
| **Bootstrap** | One-time lifecycle: `settings()` / `size`, **`P5Engine.create`**, **`UIManager` + `attach`**, scene registration, wiring **`SketchUiCoordinator`**, constructing **Flow** and calling **`UiBuilder.build(...)`** once | Main sketch tab — **stay thin** | Host long `draw` bodies or game rules |
| **Flow controller** | **State machine** (menu / play / pause / end), save/load orchestration, **routing** `mousePressed` / `keyPressed`, HUD copy, ordering: engine → tick → world draw → layout helpers → **`sketchUi.updateFrame` / `renderFrame`** | Extra `.pde` tab(s), e.g. `TdFlowController` | Build the full widget tree (delegate to builder) |
| **Ui builder** | **Widget tree only**: panels, labels, sliders; **`setAction`** delegates to **Flow** (or tiny lambdas that only call **Flow**) | Extra `.pde` tab, e.g. `TdMainUiBuilder` | Encode win/lose rules or file I/O |

**Mnemonic:** Bootstrap *starts* the app; Flow *runs* modes and glue; UiBuilder *lays out* controls and points buttons at Flow.

---

## What belongs in the engine vs the sketch

| Prefer **in engine** (`p5engine.jar`) | Prefer **in sketch** |
|----------------------------------------|----------------------|
| **`UIManager`**, themes, layout managers, generic widgets | Which panels exist, copy, z-order for *your* game |
| **`SketchUiCoordinator`** (generic update + pre-render + render) | **When** you call it relative to your simulation and world drawing |
| **`P5Engine`**, game time, **generic** scene manager API | Scene contents, `GameObject` graphs, level rules |
| Reusable math / rendering helpers with no domain knowledge | Domain enums, save schema, `JSONObject` field names for *your* title |

**Hard boundary:** do not put **tower kinds**, **tower save JSON**, or **your** `TdGameWorld`-style types inside `src/main/java` for this library if they are not meant to be shared infrastructure.

---

## Minimal draw loop (pseudo-code)

```text
void draw() {
  float dt = engine.getGameTime().getDeltaTime();
  background(...);

  engine.update();
  // simulationTick(dt);
  // drawWorldUnderUi();

  // Optional: TdUiLayout.layout(app) or manual bounds + panel.layout(this)
  sketchUi.updateFrame(dt);
  // Optional: push HUD label text from game state
  sketchUi.renderFrame();  // preRender hook (e.g. textFont) then ui.render()
}
```

Construct once after **`UIManager.attach()`**:

```java
sketchUi = new SketchUiCoordinator(this, ui);
sketchUi.setPreRenderHook(() -> { /* textFont / theme tweaks */ });
```

For **manual chrome** that must run after `update` but before `paint`, use **`setPreRenderHook`** (see `examples/ImageLab`: bounds + `layout` on top chrome before `render`).

---

## See also

- Javadoc: [`SketchUiCoordinator`](../src/main/java/shenyf/p5engine/ui/SketchUiCoordinator.java) — full suggested ordering.
- [`UIManager`](../src/main/java/shenyf/p5engine/ui/UIManager.java) — `update` resizes root and runs measure/layout when dirty.
- Examples: `examples/TowerDefenseMin` (Flow + builder + coordinator), `examples/UIDemo` (coordinator + pooled UI), `examples/ImageLab` (coordinator + pre-render layout).
