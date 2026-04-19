# ImageLab — defect log (phase D)

Use this list while exercising the sketch. Each entry: **repro**, **expected**, **actual**, **classes**, **priority** (P0–P3).

## API design

_(none logged yet)_

## UI behavior

### D-UI-001 — Keyboard: P5Engine vs UIManager

- **Repro**: Focus a `TextInput` (if added) or type while UI has focus; also hold Space for pan over canvas.
- **Expected**: Documented, predictable order: either UI consumes first or global shortcuts are suppressed when a text field is focused.
- **Actual**: Both `P5Engine` and `UIManager` register `keyEvent` on the applet; consumption order is not defined in engine API. ImageLab uses Space+drag for pan only when the pointer is over the canvas; conflicts with focused text fields are still possible if extended.
- **Classes**: `P5Engine`, `UIManager`, `FocusManager`
- **Priority**: P2 (documented in `docs/ImageLab-README.md`; long-term: optional `InputRouter` / chord priority table)

### D-UI-002 — Mouse wheel: canvas zoom vs ScrollPane

- **Repro**: Hover PPak `ScrollPane` vs canvas; scroll wheel.
- **Expected**: One clear behavior per region (scroll list vs zoom image).
- **Actual**: ImageLab zoom applies only when `mouseX` is right of the west strip and below the toolbar; list scroll uses UI handling. Edge cases on strip boundaries may feel ambiguous.
- **Classes**: `UIManager`, `ScrollPane`, sketch `mouseWheel`
- **Priority**: P3

## Performance

### D-PERF-001 — Large images + undo stack

- **Repro**: Open a very large PNG; paint many strokes; use Undo repeatedly.
- **Expected**: Stable frame time or documented limits.
- **Actual**: Each undo pushes a full `PGraphics` snapshot (capped at 24). Memory grows with image size × stack depth.
- **Classes**: sketch `pushUndoSnapshot`, `UNDO_MAX`
- **Priority**: P2

## Docs & examples

### D-DOC-001 — Tool sketch vs `engine.render()`

- **Repro**: Compare ImageLab with scene-based HelloWorld-style sketches.
- **Expected**: Clear template for “tool mode”: own `background`, no scene clear conflict.
- **Actual**: ImageLab calls `engine.update()` for time only and does not use `engine.render()`; documented in README.
- **Classes**: `P5Engine`, `ProcessingRenderer`
- **Priority**: P3

## Processing limitations

### D-PRC-001 — `blendMode(ERASE)` on JAVA2D PGraphics

- **Repro**: Select Eraser; paint over semi-transparent brush strokes on `editLayer`.
- **Expected**: Pixels become transparent in a predictable way.
- **Actual**: Depends on Processing/JAVA2D blend implementation; may differ from GPU renderers.
- **Classes**: sketch `paintAt`
- **Priority**: P3

---

_Add new rows under the right heading; keep IDs sequential per category._
