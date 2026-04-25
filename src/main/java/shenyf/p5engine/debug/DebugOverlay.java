package shenyf.p5engine.debug;

import processing.core.PApplet;
import shenyf.p5engine.collision.Collider;
import shenyf.p5engine.core.P5Engine;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.scene.Scene;
import shenyf.p5engine.scene.Transform;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Runtime debug overlay for p5engine.
 * Provides collider gizmos, scene object tree, and performance HUD.
 *
 * Toggle with `~` (backtick). Individual panels: F2=gizmos, F3=tree, F4=HUD.
 */
public class DebugOverlay {

    private boolean enabled = false;
    private boolean showGizmos = true;
    private boolean showTree = true;
    private boolean showHud = true;

    public void toggle() {
        enabled = !enabled;
    }

    public void toggleGizmos() {
        showGizmos = !showGizmos;
    }

    public void toggleTree() {
        showTree = !showTree;
    }

    public void toggleHud() {
        showHud = !showHud;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void render(PApplet g, P5Engine engine) {
        System.out.println("[DEBUGOVERLAY] render called, enabled=" + enabled);
        if (!enabled) {
            System.out.println("[DEBUGOVERLAY] render skipped: not enabled");
            return;
        }
        Scene scene = engine.getActiveScene();
        if (scene == null) {
            System.out.println("[DEBUGOVERLAY] render skipped: scene is null");
            return;
        }

        g.pushStyle();
        try {
            System.out.println("[DEBUGOVERLAY] rendering overlay, showHud=" + showHud + ", showGizmos=" + showGizmos + ", showTree=" + showTree);
            if (showHud) renderHud(g, engine, scene);
            if (showGizmos) renderGizmos(g, scene);
            if (showTree) renderTree(g, scene);
        } finally {
            g.popStyle();
        }
    }

    // ==================== HUD ====================

    private void renderHud(PApplet g, P5Engine engine, Scene scene) {
        float x = 10, y = 10, w = 170, h = 130;

        g.fill(0, 0, 0, 160);
        g.stroke(80, 80, 80);
        g.strokeWeight(1);
        g.rect(x, y, w, h);

        g.fill(200, 255, 200);
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        g.textSize(12);
        float lineH = 18;
        float ty = y + 8;
        int fps = Math.round(engine.getGameTime().getFrameRate());
        g.text("FPS: " + fps, x + 10, ty);
        ty += lineH;
        g.text("Objects: " + scene.getObjectCount(), x + 10, ty);
        ty += lineH;
        g.text("Collisions: " + scene.getCollisionCheckCount(), x + 10, ty);
        ty += lineH;
        g.text("Tweens: " + engine.getTweenManager().getActiveCount(), x + 10, ty);
        ty += lineH;
        g.text("Delta: " + String.format(java.util.Locale.US, "%.3f", engine.getGameTime().getDeltaTime()), x + 10, ty);
        ty += lineH;
        g.text("Time: x" + String.format(java.util.Locale.US, "%.1f", engine.getGameTime().getTimeScale()), x + 10, ty);
        ty += lineH;
        g.text("Log: " + shenyf.p5engine.util.Logger.getLevel(), x + 10, ty);
        if (shenyf.p5engine.util.Logger.isFileLogging()) {
            ty += lineH;
            String path = shenyf.p5engine.util.Logger.getCurrentLogFilePath();
            g.text("File: " + (path != null ? new java.io.File(path).getName() : "-"), x + 10, ty);
        }
    }

    // ==================== Gizmos ====================

    private void renderGizmos(PApplet g, Scene scene) {
        g.noFill();
        g.strokeWeight(1);
        for (GameObject go : scene.getGameObjects()) {
            if (!go.isActive()) continue;
            Collider collider = null;
            for (Component comp : go.getComponents()) {
                if (comp instanceof Collider) {
                    collider = (Collider) comp;
                    break;
                }
            }
            if (collider == null) continue;
            float cx = collider.getCenterX();
            float cy = collider.getCenterY();
            float r = collider.getCollisionRadius();

            // Circle outline
            g.stroke(0, 255, 120, 180);
            g.ellipse(cx, cy, r * 2, r * 2);

            // Center dot
            g.stroke(0, 255, 120, 255);
            g.point(cx, cy);

            // Radius text
            g.fill(0, 255, 120, 220);
            g.textAlign(PApplet.CENTER, PApplet.BOTTOM);
            g.textSize(10);
            g.text(String.format(java.util.Locale.US, "r=%.1f", r), cx, cy - r - 2);
        }
    }

    // ==================== Scene Tree ====================

    private void renderTree(PApplet g, Scene scene) {
        float x = 10, y = 120, w = 280;
        float h = g.height - y - 10;
        if (h < 60) h = 60;

        // Build parent -> children map
        Map<GameObject, List<GameObject>> tree = new HashMap<>();
        List<GameObject> roots = new ArrayList<>();
        for (GameObject go : scene.getGameObjects()) {
            Transform t = go.getTransform();
            Transform parent = t.getParent();
            if (parent == null || parent.getGameObject() == null) {
                roots.add(go);
            } else {
                GameObject parentGo = parent.getGameObject();
                List<GameObject> list = tree.get(parentGo);
                if (list == null) {
                    list = new ArrayList<>();
                    tree.put(parentGo, list);
                }
                list.add(go);
            }
        }

        // Background panel
        g.fill(0, 0, 0, 180);
        g.noStroke();
        g.rect(x, y, w, h);

        // Title bar
        g.fill(30, 30, 30, 220);
        g.rect(x, y, w, 22);
        g.fill(200, 255, 200);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(12);
        g.text("Scene Tree (" + scene.getObjectCount() + ")", x + 8, y + 11);

        // Content clip area
        float contentY = y + 26;
        float contentH = h - 30;
        g.pushMatrix();
        g.clip((int) x, (int) contentY, (int) w, (int) contentH);

        float cy = contentY;
        for (GameObject root : roots) {
            cy = drawTreeNode(g, root, tree, x, cy, 0);
        }

        g.noClip();
        g.popMatrix();
    }

    private float drawTreeNode(PApplet g, GameObject go,
                               Map<GameObject, List<GameObject>> tree,
                               float baseX, float startY, int depth) {
        float lineH = 14;
        float indent = 14;
        float tx = baseX + 8 + depth * indent;
        float ty = startY;

        if (go.isActive()) {
            g.fill(255);
        } else {
            g.fill(150);
        }
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        g.textSize(11);

        StringBuilder compNames = new StringBuilder();
        List<Component> comps = go.getComponents();
        for (int i = 0; i < comps.size(); i++) {
            if (i > 0) compNames.append(",");
            compNames.append(comps.get(i).getClass().getSimpleName());
        }

        String text = go.getName();
        if (!go.getTag().isEmpty()) {
            text += " [" + go.getTag() + "]";
        }
        g.text(text, tx, ty);

        // Component count hint
        if (comps.size() > 0) {
            g.fill(180, 220, 180);
            g.textAlign(PApplet.RIGHT, PApplet.TOP);
            g.text(String.valueOf(comps.size()), baseX + 270, ty);
        }

        float nextY = startY + lineH;
        List<GameObject> children = tree.get(go);
        if (children != null) {
            for (GameObject child : children) {
                nextY = drawTreeNode(g, child, tree, baseX, nextY, depth + 1);
            }
        }
        return nextY;
    }
}
