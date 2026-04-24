package shenyf.p5engine.ui;

import processing.core.PGraphics;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.rendering.Camera2D;
import shenyf.p5engine.rendering.OffscreenRenderer;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.scene.Scene;
import shenyf.p5engine.util.Logger;

/**
 * A {@link WorldViewport} that renders the full world layer of a Scene,
 * optionally with a background grid.
 *
 * <p>Uses an independent render camera so the shared Camera2D state is never
 * modified during off-screen rendering. This eliminates race conditions and
 * ensures interactive code (mouse picking, zoom, placement ghost) always sees
 * a stable viewport configuration.</p>
 */
public class SceneViewport extends WorldViewport {
    private boolean drawGrid = true;

    // Independent render camera (created on first use, reused thereafter)
    private Camera2D renderCam;
    private GameObject renderCamGo;

    public SceneViewport(String id) {
        super(id);
    }

    public void setDrawGrid(boolean drawGrid) {
        this.drawGrid = drawGrid;
    }

    /** Lazily create a standalone Camera2D attached to a temporary GameObject. */
    private void ensureRenderCamera(Camera2D mainCam) {
        if (renderCam == null) {
            renderCamGo = GameObject.create("_scene_vp_cam");
            renderCam = renderCamGo.addComponent(Camera2D.class);
        }
        // Sync dynamic state from the shared camera
        renderCam.getTransform().setPosition(mainCam.getTransform().getPosition());
        renderCam.setZoom(mainCam.getZoom());
        renderCam.setWorldBounds(mainCam.getWorldBounds());
    }

    @Override
    protected void renderContent(PGraphics buffer, int w, int h, Camera2D camera, Scene scene) {
        if (camera == null || scene == null) {
            if (drawGrid) {
                buffer.stroke(40, 90, 120, 22);
                buffer.strokeWeight(1);
                int step = 48;
                for (float x = 0; x < w; x += step) buffer.line(x, 0, x, h);
                for (float y = 0; y < h; y += step) buffer.line(0, y, w, y);
                buffer.noStroke();
            }
            return;
        }

        ensureRenderCamera(camera);
        renderCam.setViewportSize(w, h);
        renderCam.setViewportOffset(0, 0);
        // Sync render camera from main camera
        Vector2 mainPos = camera.getTransform().getPosition();
        Vector2 renderPos = renderCam.getTransform().getPosition();
        boolean posDiff = Math.abs(mainPos.x - renderPos.x) > 0.01f || Math.abs(mainPos.y - renderPos.y) > 0.01f;
        boolean zoomDiff = Math.abs(camera.getZoom() - renderCam.getZoom()) > 0.001f;
        boolean vpDiff = camera.getViewportWidth() != renderCam.getViewportWidth() || camera.getViewportHeight() != renderCam.getViewportHeight();
        if (posDiff || zoomDiff || vpDiff) {
            renderCam.getTransform().setPosition(mainPos.x, mainPos.y);
            renderCam.setZoom(camera.getZoom());
        }

        if (drawGrid) {
            buffer.stroke(40, 90, 120, 22);
            buffer.strokeWeight(1);
            int step = 48;
            for (float x = 0; x < w; x += step) buffer.line(x, 0, x, h);
            for (float y = 0; y < h; y += step) buffer.line(0, y, w, y);
            buffer.noStroke();
        }

        OffscreenRenderer offscreen = new OffscreenRenderer(buffer, w, h);
        scene.renderWorld(offscreen, renderCam);
    }
}
