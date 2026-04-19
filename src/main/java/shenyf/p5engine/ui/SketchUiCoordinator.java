package shenyf.p5engine.ui;

import java.util.Objects;

import processing.core.PApplet;

/**
 * Thin facade for the usual per-frame pair {@link UIManager#update(float)} and
 * {@link UIManager#render()}, plus an optional hook that runs immediately before
 * {@link UIManager#render()} (for example {@code textFont(...)} when using {@code P2D}).
 *
 * <p><b>Suggested draw order</b> (typical game sketch using {@link shenyf.p5engine.core.P5Engine}):</p>
 * <ol>
 *   <li>Clear background and draw world layers that sit under the UI</li>
 *   <li>{@link shenyf.p5engine.core.P5Engine#update()} — time step and scene updates owned by the engine</li>
 *   <li>Game simulation tick (enemies, physics, etc.)</li>
 *   <li>Optional: sketch-specific bounds on panels, then {@code layout(applet)} on custom roots</li>
 *   <li>{@link #updateFrame(float)} — resizes the UI root, runs measure/layout if dirty, propagates hover</li>
 *   <li>Optional: update label text from game state</li>
 *   <li>{@link #setPreRenderHook(Runnable)} once (or per frame if needed), then {@link #renderFrame()}</li>
 * </ol>
 *
 * <p>This class does <em>not</em> call {@link shenyf.p5engine.core.P5Engine}; orchestration stays in the sketch.</p>
 */
public final class SketchUiCoordinator {

    private final PApplet applet;
    private final UIManager ui;
    private Runnable preRenderHook;

    public SketchUiCoordinator(PApplet applet, UIManager ui) {
        this.applet = Objects.requireNonNull(applet, "applet");
        this.ui = Objects.requireNonNull(ui, "ui");
    }

    /**
     * The sketch surface; retained for API symmetry and future extensions (hit-testing helpers, etc.).
     */
    public PApplet getApplet() {
        return applet;
    }

    public UIManager getUi() {
        return ui;
    }

    /**
     * Runs immediately before {@link UIManager#render()} each {@link #renderFrame()} call; use for
     * {@code textFont} / theme tweaks that must apply to the paint pass. Pass {@code null} to clear.
     */
    public void setPreRenderHook(Runnable hook) {
        this.preRenderHook = hook;
    }

    public void clearPreRenderHook() {
        this.preRenderHook = null;
    }

    /**
     * Delegates to {@link UIManager#update(float)} (root bounds, measure/layout, widget update).
     */
    public void updateFrame(float dt) {
        ui.update(dt);
    }

    /**
     * Runs the optional pre-render hook, then {@link UIManager#render()}.
     */
    public void renderFrame() {
        if (preRenderHook != null) {
            preRenderHook.run();
        }
        ui.render();
    }
}
