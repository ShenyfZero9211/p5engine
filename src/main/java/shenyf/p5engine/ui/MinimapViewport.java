package shenyf.p5engine.ui;

import processing.core.PGraphics;
import shenyf.p5engine.rendering.Camera2D;
import shenyf.p5engine.rendering.Minimap;
import shenyf.p5engine.rendering.OffscreenRenderer;
import shenyf.p5engine.scene.Scene;
import shenyf.p5engine.util.Logger;

/**
 * A {@link WorldViewport} that delegates rendering to an existing {@link Minimap} component.
 * This allows the minimap to be positioned and sized by the UI layout system.
 */
public class MinimapViewport extends WorldViewport {
    private final Minimap minimap;

    public MinimapViewport(String id, Minimap minimap) {
        super(id);
        this.minimap = minimap;
    }

    @Override
    protected void renderContent(PGraphics buffer, int w, int h, Camera2D camera, Scene scene) {
        if (minimap == null) return;
        // Logger.debug("MinimapViewport", String.format("renderContent ENTER camPos=%s zoom=%.2f vp=%.0fx%.0f offset=(%.0f,%.0f)",
        //     camera != null ? camera.getTransform().getPosition().toString() : "null",
        //     camera != null ? camera.getZoom() : 0,
        //     camera != null ? camera.getViewportWidth() : 0,
        //     camera != null ? camera.getViewportHeight() : 0,
        //     camera != null ? camera.getViewportOffsetX() : 0,
        //     camera != null ? camera.getViewportOffsetY() : 0));

        float oldX = minimap.getX();
        float oldY = minimap.getY();
        float oldW = minimap.getW();
        float oldH = minimap.getH();
        try {
            minimap.setRect(0, 0, w, h);
            OffscreenRenderer offscreen = new OffscreenRenderer(buffer, w, h);
            minimap.render(offscreen);
        } finally {
            minimap.setRect(oldX, oldY, oldW, oldH);
            // Logger.debug("MinimapViewport", String.format("renderContent EXIT  camPos=%s zoom=%.2f vp=%.0fx%.0f offset=(%.0f,%.0f)",
            //     camera != null ? camera.getTransform().getPosition().toString() : "null",
            //     camera != null ? camera.getZoom() : 0,
            //     camera != null ? camera.getViewportWidth() : 0,
            //     camera != null ? camera.getViewportHeight() : 0,
            //     camera != null ? camera.getViewportOffsetX() : 0,
            //     camera != null ? camera.getViewportOffsetY() : 0));
        }
    }
}
