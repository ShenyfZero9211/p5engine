package shenyf.p5engine.debug;

import processing.core.PApplet;
import shenyf.p5engine.collision.Collider;
import shenyf.p5engine.core.P5Engine;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.scene.Scene;
import shenyf.p5engine.input.InputManager;
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

    // Scene Tree panel position (draggable)
    private float treeX = 10;
    private float treeY = 190;
    private static final float TREE_W = 280;
    private static final float TREE_TITLE_H = 22;

    // Dragging state
    private boolean isDraggingTree;
    private float dragOffsetX;
    private float dragOffsetY;

    // Scrolling state
    private float treeScrollY;

    public void toggle() {
        enabled = !enabled;
        System.out.println("[DEBUGOVERLAY] " + (enabled ? "enabled" : "disabled"));
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

    public void update(InputManager input, int screenW, int screenH) {
        if (!enabled) return;

        float mx = input.getMouseX();
        float my = input.getMouseY();
        boolean pressed = input.isMousePressed();

        float titleBarH = TREE_TITLE_H;
        boolean overTitle = mx >= treeX && mx <= treeX + TREE_W
                         && my >= treeY && my <= treeY + titleBarH;

        if (input.isMouseJustPressed() && overTitle) {
            isDraggingTree = true;
            dragOffsetX = mx - treeX;
            dragOffsetY = my - treeY;
        }

        if (isDraggingTree) {
            if (pressed) {
                treeX = mx - dragOffsetX;
                treeY = my - dragOffsetY;
                treeX = Math.max(0, Math.min(treeX, screenW - TREE_W));
                treeY = Math.max(0, Math.min(treeY, screenH - titleBarH));
            } else {
                isDraggingTree = false;
            }
        }

        float wheel = input.getMouseWheelDelta();
        if (wheel != 0) {
            float treeH = screenH - treeY - 10;
            if (treeH < 60) treeH = 60;
            boolean overContent = mx >= treeX && mx <= treeX + TREE_W
                               && my >= treeY + titleBarH && my <= treeY + treeH;
            if (overContent) {
                treeScrollY -= wheel * 20;
            }
        }
    }

    public void render(PApplet g, P5Engine engine) {
        if (!enabled) {
            return;
        }
        Scene scene = engine.getActiveScene();
        if (scene == null) {
            return;
        }

        g.pushStyle();
        try {
            if (showHud) renderHud(g, engine, scene);
            if (showGizmos) renderGizmos(g, scene);
            if (showTree) renderTree(g, scene);
        } finally {
            g.popStyle();
        }
    }

    // ==================== HUD ====================

    private void renderHud(PApplet g, P5Engine engine, Scene scene) {
        float x = 10, y = 10, w = 260;
        float lineH = 18;
        int rowCount = 7;
        if (shenyf.p5engine.util.Logger.isFileLogging()) rowCount++;
        float h = lineH * rowCount + 16;

        g.fill(0, 0, 0, 160);
        g.stroke(80, 80, 80);
        g.strokeWeight(1);
        g.rect(x, y, w, h);

        g.fill(200, 255, 200);
        g.textAlign(PApplet.LEFT, PApplet.TOP);
        g.textSize(12);
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
        float x = treeX;
        float y = treeY;
        float w = TREE_W;
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
        if (isDraggingTree) {
            g.fill(60, 60, 60, 220);
        } else {
            g.fill(30, 30, 30, 220);
        }
        g.rect(x, y, w, TREE_TITLE_H);
        g.fill(200, 255, 200);
        g.textAlign(PApplet.LEFT, PApplet.CENTER);
        g.textSize(12);
        g.text("Scene Tree (" + scene.getObjectCount() + ")", x + 8, y + TREE_TITLE_H * 0.5f);

        // Content clip area
        float contentY = y + TREE_TITLE_H + 4;
        float contentH = h - TREE_TITLE_H - 8;
        g.pushMatrix();
        g.clip((int) x, (int) contentY, (int) w, (int) contentH);

        // Calculate total content height and clamp scroll
        float totalContentH = calcTreeContentHeight(roots, tree);
        float maxScroll = Math.max(0, totalContentH - contentH);
        treeScrollY = Math.max(0, Math.min(treeScrollY, maxScroll));

        float cy = contentY - treeScrollY;
        for (GameObject root : roots) {
            cy = drawTreeNode(g, root, tree, x, cy, 0);
        }

        g.noClip();
        g.popMatrix();
    }

    private float calcTreeContentHeight(List<GameObject> roots, Map<GameObject, List<GameObject>> tree) {
        float h = 0;
        for (GameObject root : roots) {
            h += calcNodeHeight(root, tree);
        }
        return h;
    }

    private float calcNodeHeight(GameObject go, Map<GameObject, List<GameObject>> tree) {
        float h = 14;
        List<GameObject> children = tree.get(go);
        if (children != null) {
            for (GameObject child : children) {
                h += calcNodeHeight(child, tree);
            }
        }
        return h;
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
