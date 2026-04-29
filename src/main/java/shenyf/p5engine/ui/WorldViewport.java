package shenyf.p5engine.ui;

import processing.core.PApplet;
import processing.core.PGraphics;
import shenyf.p5engine.rendering.Camera2D;
import shenyf.p5engine.scene.Scene;
import shenyf.p5engine.util.Logger;

/**
 * Abstract base class for UI components that render a Scene (or part of it) into an off-screen buffer.
 * Subclasses implement {@link #renderContent} to define what gets drawn (e.g. full world layer, minimap, etc.).
 *
 * <p>Supports multiple instances with independent cameras. The component manages a {@link PGraphics}
 * buffer whose size matches the component bounds, and blits it during {@link #paintSelf}.</p>
 */
public abstract class WorldViewport extends Panel {
    protected Scene scene;
    protected Camera2D camera;
    protected PGraphics buffer;
    protected int bgColor = 0xFF0E1222; // 14, 18, 30

    // When true, skip renderContent() and reuse the existing buffer scaled to current bounds.
    // Used during Window resize to avoid expensive per-frame re-rendering.
    private boolean freezeRender = false;

    public WorldViewport(String id) {
        super(id);
        setPaintBackground(false);
    }

    public void setScene(Scene scene) {
        this.scene = scene;
    }

    public Scene getScene() {
        return scene;
    }

    public void setCamera(Camera2D camera) {
        this.camera = camera;
    }

    public Camera2D getCamera() {
        return camera;
    }

    public void setBgColor(int color) {
        this.bgColor = color;
    }

    public boolean isFreezeRender() {
        return freezeRender;
    }

    public void setFreezeRender(boolean freezeRender) {
        this.freezeRender = freezeRender;
    }

    @Override
    protected void paintSelf(PApplet applet, Theme theme) {
        if (scene == null || !scene.isRunning()) {
            super.paintSelf(applet, theme);
            return;
        }

        int w = Math.max(1, (int) getWidth());
        int h = Math.max(1, (int) getHeight());

        float ax = getAbsoluteX();
        float ay = getAbsoluteY();
        float alpha = getEffectiveAlpha();

        if (freezeRender && buffer != null) {
            // Reuse existing buffer scaled to current bounds — no re-render
            applet.pushStyle();
            try {
                if (alpha < 1f) {
                    applet.tint(255, Math.round(255 * alpha));
                }
                applet.image(buffer, ax, ay, w, h);
            } finally {
                applet.popStyle();
            }
            return;
        }

        ensureBuffer(applet, w, h);

        Camera2D cam = (camera != null) ? camera : scene.getCamera();
        Logger.debug("WorldViewport", String.format("paintSelf id=%s bounds=%.0fx%.0f@(%.0f,%.0f) buffer=%dx%d camPos=%s",
            getId(), getWidth(), getHeight(), getAbsoluteX(), getAbsoluteY(), w, h,
            cam != null ? cam.getTransform().getPosition().toString() : "null"));

        buffer.beginDraw();
        buffer.background(bgColor);
        renderContent(buffer, w, h, cam, scene);
        buffer.endDraw();

        applet.pushStyle();
        try {
            if (alpha < 1f) {
                applet.tint(255, Math.round(255 * alpha));
            }
            applet.image(buffer, ax, ay);
        } finally {
            applet.popStyle();
        }
    }

    /**
     * Render this viewport directly to the screen at the given pixel coordinates,
     * bypassing any UI-level scaling transforms.
     *
     * <p>Use this for layered rendering where the world layer draws at 1:1 screen
     * pixels and the UI layer draws separately with FIT scaling.</p>
     *
     * @param applet   the PApplet to draw into
     * @param screenX  screen X coordinate (actual pixels)
     * @param screenY  screen Y coordinate (actual pixels)
     * @param screenW  width in actual screen pixels
     * @param screenH  height in actual screen pixels
     */
    public void renderDirect(PApplet applet, float screenX, float screenY, float screenW, float screenH) {
        if (scene == null || !scene.isRunning()) {
            return;
        }

        int w = Math.max(1, (int) screenW);
        int h = Math.max(1, (int) screenH);

        Camera2D cam = (camera != null) ? camera : scene.getCamera();
        Logger.debug("WorldViewport", String.format("renderDirect id=%s screen=%.0fx%.0f@(%.0f,%.0f) buffer=%dx%d",
            getId(), screenW, screenH, screenX, screenY, w, h));

        ensureBuffer(applet, w, h);

        buffer.beginDraw();
        buffer.background(bgColor);
        renderContent(buffer, w, h, cam, scene);
        buffer.endDraw();

        applet.pushStyle();
        try {
            applet.image(buffer, screenX, screenY);
        } finally {
            applet.popStyle();
        }
    }

    /**
     * Subclasses implement this to draw into the provided buffer.
     * The buffer has already been cleared to {@link #bgColor}.
     *
     * @param buffer  the PGraphics to draw into
     * @param w       buffer width in pixels
     * @param h       buffer height in pixels
     * @param camera  the camera (viewport already set to w/h, offset at 0,0)
     * @param scene   the scene being rendered
     */
    protected abstract void renderContent(PGraphics buffer, int w, int h, Camera2D camera, Scene scene);

    private static final int MAX_BUFFER_DIM = 4096;

    private void ensureBuffer(PApplet applet, int w, int h) {
        w = Math.min(Math.max(1, w), MAX_BUFFER_DIM);
        h = Math.min(Math.max(1, h), MAX_BUFFER_DIM);
        if (buffer == null || buffer.width != w || buffer.height != h) {
            buffer = applet.createGraphics(w, h, PApplet.P2D);
        }
    }
}
