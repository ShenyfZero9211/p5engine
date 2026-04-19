# ImageLab example

`examples/ImageLab/ImageLab.pde` is a **tool-style** sketch: image viewer, light paint layer, optional PPak file list, and `UIManager` toolbar. It exists to stress-test p5engine **time**, **UI**, **rendering size sync**, and optional **PPak** loading.

## Run

1. Build `library/p5engine.jar` (see repo `compile-jar.ps1`) and ensure Processing has the p5engine library installed.
2. Open the `ImageLab` sketch folder in Processing and run.

If the compiler reports **`Duplicate method settings() in type ImageLab`**: Processing merges **every** `.pde` in that folder into one class. Keep **only one** `void settings()` in the whole sketch (typically only [`ImageLab.pde`](../examples/ImageLab/ImageLab.pde)). Remove or rename extra tabs (for example a copied `ImageLab - 副本.pde` or a helper tab that also defines `settings()`), or delete a second `void settings() { ... }` block if you pasted HiDPI setup twice in the same file.

## PPak sample

If `data/data.ppak` is present under the sketch, the west panel lists image entries from the pack. The sketch also tries `../PPakDemo/data/data.ppak` when the local file is missing.

## Frame loop (no scene render)

Order each frame:

1. `background(...)` and draw the image stack (base + edit layer) **under** the UI.
2. `engine.update()` — updates game time and syncs `ProcessingRenderer` size from `applet.width` / `applet.height`.
3. `ui.update(dt)` then `ui.render()`.

`engine.render()` is intentionally **not** used so the default scene clear does not erase the custom canvas.

## Top chrome (Photoshop-style)

The sketch uses a **two-row** top area: **`MenuBar`** (`shenyf.p5engine.ui`) with **File / Edit / View** on the first row (narrow), and **Fit**, **1:1**, zoom and brush sliders, **Brush/Eraser**, and path label on the second row. **Open…** and **Export PNG…** live under **File**; **Undo** (and disabled **Redo**) under **Edit**; **Fit on screen** and **Actual pixels** under **View** (the second row still has the same quick controls).

The bar uses the engine’s shared **`MenuPopup`** (high `zOrder`). Click the same menu title again to close, choose an item to run an action and close, click the **canvas** to dismiss, or rely on `mainMenu.closePopupsIfClickOutside` in `mousePressed` for clicks outside titles and the open popup.

The sketch root uses a **null** `LayoutManager` and sets `topChrome` / `westStrip` bounds after `ui.update()` so the menu bar and dropdown use correct `getAbsoluteX/Y` for placement.

## Sharpness (HiDPI / Windows scaling)

ImageLab uses **`size(..., P2D)`**, **`smooth(8)`**, and **`P5Engine.applyRecommendedPixelDensity(this)`** — all in **`settings()`**, in that order. With **P2D**, putting **`smooth()` in `setup()`** makes the Processing preprocessor append a **second** `settings()` and the sketch fails to compile (`Duplicate method settings()`). Do not force **`pixelDensity` above `displayDensity()`** (e.g. old `applyRecommendedPixelDensity(this, 2)` on a display that only supports 1): you may get **`pixelDensity(2) is not available for this display`** and a shrunken window. If you still see softness, print `pixelWidth` vs `width` in `setup()`; when supported, `pixelWidth` is about `width * pixelDensity`.

## Transparent UI root

The engine `UIManager` root panel uses `setPaintBackground(false)` so the sketch background and image remain visible outside child panels (toolbar, west strip).

## Input note (engine backlog)

`P5Engine` and `UIManager` both register `keyEvent` on the `PApplet`. There is **no single input router** yet. For tools that mix **global shortcuts** (e.g. Space, Ctrl+S) with **text fields**, choose a sketch-level policy, for example:

- When a component that accepts typing has focus, disable global shortcuts, or
- Handle shortcuts only when the pointer is over the canvas.

See `examples/ImageLab/DEFECTS.md` (D-UI-001).

## Export

**Export PNG…** (under the **File** menu) composites `baseImage` and `editLayer` into a new `PGraphics` and saves PNG. JPEG would flatten transparency; stick to PNG for edited layers.
