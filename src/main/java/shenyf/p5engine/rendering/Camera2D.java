package shenyf.p5engine.rendering;

import shenyf.p5engine.math.Rect;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.Transform;
import shenyf.p5engine.util.Logger;

/**
 * A 2D camera that transforms world coordinates to screen coordinates.
 * Supports zoom, smooth follow, world bounds clamping, and viewport culling.
 * Automatically applied during scene rendering when attached to a Scene.
 */
public class Camera2D extends Component {
    private float viewportWidth;
    private float viewportHeight;
    private float viewportOffsetX;
    private float viewportOffsetY;
    private Vector2 targetOffset;
    private Transform followTarget;
    private float followSpeed = 5.0f;
    private boolean smoothFollow = true;

    // Zoom
    private float zoom = 1.0f;
    private float minZoom = 0.2f;
    private float maxZoom = 5.0f;
    private float wheelZoomStep = 1.08f;

    // World bounds (optional)
    private Rect worldBounds;

    public Camera2D() {
        this.targetOffset = new Vector2(0, 0);
    }

    public void setViewportOffset(float x, float y) {
        this.viewportOffsetX = x;
        this.viewportOffsetY = y;
    }

    public float getViewportOffsetX() {
        return viewportOffsetX;
    }

    public float getViewportOffsetY() {
        return viewportOffsetY;
    }

    @Override
    public void start() {
    }

    @Override
    public void update(float deltaTime) {
        if (followTarget != null) {
            Vector2 currentPos = getTransform().getPosition();
            Vector2 targetPos = followTarget.getPosition().copy().add(targetOffset);
            if (smoothFollow) {
                currentPos.lerp(targetPos, Math.min(1.0f, followSpeed * deltaTime));
            } else {
                currentPos.set(targetPos);
            }
            getTransform().setPosition(currentPos);
        }
        clampToBounds();
    }

    /**
     * Begin camera transform for rendering.
     * Transform order: translate to screen center -> scale by zoom -> rotate -> translate by -cameraPos
     * Must be paired with {@link #end(IRenderer)}.
     */
    public void begin(IRenderer renderer) {
        Vector2 pos = getTransform().getPosition();
        float rot = getTransform().getRotation();
        renderer.pushTransform();
        renderer.translate(viewportOffsetX + viewportWidth / 2, viewportOffsetY + viewportHeight / 2);
        renderer.scale(zoom, zoom);
        renderer.rotate(rot);
        renderer.translate(-pos.x, -pos.y);
    }

    /**
     * End camera transform for rendering.
     */
    public void end(IRenderer renderer) {
        renderer.popTransform();
    }

    // ── Viewport ──

    public void setViewportSize(float width, float height) {
        this.viewportWidth = width;
        this.viewportHeight = height;
        // Logger.debug("Camera", String.format("setViewportSize %.0fx%.0f offset(%.0f,%.0f)",
        //     viewportWidth, viewportHeight, viewportOffsetX, viewportOffsetY));
    }

    public float getViewportWidth() {
        return viewportWidth;
    }

    public float getViewportHeight() {
        return viewportHeight;
    }

    /** Returns the camera's view rectangle in world coordinates. */
    public Rect getViewport() {
        Vector2 pos = getTransform().getPosition();
        float visibleW = viewportWidth / zoom;
        float visibleH = viewportHeight / zoom;
        return new Rect(
            pos.x - visibleW / 2,
            pos.y - visibleH / 2,
            visibleW,
            visibleH
        );
    }

    // ── Follow ──

    public void follow(Transform target) {
        this.followTarget = target;
    }

    public void stopFollow() {
        this.followTarget = null;
    }

    public void setFollowSpeed(float speed) {
        this.followSpeed = speed;
    }

    public void setSmoothFollow(boolean smooth) {
        this.smoothFollow = smooth;
    }

    public Transform getFollowTarget() {
        return followTarget;
    }

    // ── Zoom ──

    public float getZoom() {
        return zoom;
    }

    public void setZoom(float zoom) {
        this.zoom = zoom;
        clampToBounds();
    }

    public float getMinZoom() {
        return minZoom;
    }

    public void setMinZoom(float minZoom) {
        this.minZoom = minZoom;
        clampToBounds();
    }

    public float getMaxZoom() {
        return maxZoom;
    }

    public void setMaxZoom(float maxZoom) {
        this.maxZoom = maxZoom;
        clampToBounds();
    }

    public float getWheelZoomStep() {
        return wheelZoomStep;
    }

    public void setWheelZoomStep(float step) {
        this.wheelZoomStep = step;
    }

    /**
     * Zoom in or out centered on a specific screen position.
     * After zooming, the world point under the focus screen position remains at the same screen location.
     *
     * @param amount positive = zoom in, negative = zoom out
     * @param focusScreenPos the screen point to keep stable (typically mouse position)
     */
    public void zoomAt(float amount, Vector2 focusScreenPos) {
        Vector2 posBefore = getTransform().getPosition();
        float zoomBefore = zoom;
        // 1. Remember what world point is under the focus screen position
        Vector2 focusWorldBefore = screenToWorld(focusScreenPos);
        Logger.debug("Camera", String.format("zoomAt start amount=%.3f focusScreen=(%.1f,%.1f) focusWorld=(%.1f,%.1f) pos=(%.2f,%.2f) zoom=%.3f",
            amount, focusScreenPos.x, focusScreenPos.y, focusWorldBefore.x, focusWorldBefore.y, posBefore.x, posBefore.y, zoomBefore));

        // 2. Apply zoom change
        zoom *= (float) Math.pow(wheelZoomStep, amount);

        // 3. Clamp zoom
        float effectiveMin = effectiveMinZoom();
        zoom = constrain(zoom, effectiveMin, maxZoom);

        // 4. Adjust camera position so the same world point maps back to the same screen position
        Vector2 pos = getTransform().getPosition();
        pos.x = focusWorldBefore.x - (focusScreenPos.x - viewportOffsetX - viewportWidth / 2) / zoom;
        pos.y = focusWorldBefore.y - (focusScreenPos.y - viewportOffsetY - viewportHeight / 2) / zoom;
        getTransform().setPosition(pos);

        clampToBounds();
        Vector2 posAfter = getTransform().getPosition();
        Logger.debug("Camera", String.format("zoomAt end zoom %.3f->%.3f (min=%.3f) pos (%.2f,%.2f)->(%.2f,%.2f)",
            zoomBefore, zoom, effectiveMin, posBefore.x, posBefore.y, posAfter.x, posAfter.y));
    }

    /**
     * Jump camera center to a specific world position.
     */
    public void jumpCenterTo(float worldX, float worldY) {
        Vector2 pos = getTransform().getPosition();
        Logger.debug("Camera", String.format("jumpCenterTo (%.1f,%.1f) from (%.2f,%.2f)", worldX, worldY, pos.x, pos.y));
        pos.x = worldX;
        pos.y = worldY;
        getTransform().setPosition(pos);
        clampToBounds();
        Vector2 posAfter = getTransform().getPosition();
        Logger.debug("Camera", String.format("jumpCenterTo result (%.2f,%.2f)", posAfter.x, posAfter.y));
    }

    // ── World Bounds ──

    public void setWorldBounds(Rect bounds) {
        this.worldBounds = bounds;
        Logger.debug("Camera", String.format("setWorldBounds (%.0f,%.0f %.0fx%.0f)",
            bounds.x, bounds.y, bounds.width, bounds.height));
        clampToBounds();
    }

    public Rect getWorldBounds() {
        return worldBounds;
    }

    /**
     * Clamp camera position and zoom so the viewport never shows outside the world bounds.
     */
    public void clampToBounds() {
        if (worldBounds == null) {
            float oldZoom = zoom;
            zoom = constrain(zoom, minZoom, maxZoom);
            if (zoom != oldZoom) {
                Logger.debug("Camera", String.format("clamp (no bounds) zoom %.3f->%.3f", oldZoom, zoom));
            }
            return;
        }

        float effectiveMin = effectiveMinZoom();
        float oldZoom = zoom;
        zoom = constrain(zoom, effectiveMin, maxZoom);

        float visibleW = viewportWidth / zoom;
        float visibleH = viewportHeight / zoom;

        float minX = worldBounds.x + visibleW / 2;
        float maxX = worldBounds.x + worldBounds.width - visibleW / 2;
        float minY = worldBounds.y + visibleH / 2;
        float maxY = worldBounds.y + worldBounds.height - visibleH / 2;

        Vector2 pos = getTransform().getPosition();
        float oldX = pos.x;
        float oldY = pos.y;
        pos.x = constrain(pos.x, minX, maxX);
        pos.y = constrain(pos.y, minY, maxY);
        getTransform().setPosition(pos);

        if (oldX != pos.x || oldY != pos.y || oldZoom != zoom) {
            Logger.debug("Camera", String.format("clamp pos (%.2f,%.2f)->(%.2f,%.2f) zoom %.3f->%.3f vis=%.1fx%.1f bounds=[%.1f,%.1f]x[%.1f,%.1f] world=(%.0fx%.0f)",
                oldX, oldY, pos.x, pos.y, oldZoom, zoom, visibleW, visibleH, minX, maxX, minY, maxY, worldBounds.width, worldBounds.height));
        }
    }

    /**
     * The minimum zoom that still shows the entire world (no black borders).
     */
    public float effectiveMinZoom() {
        if (worldBounds == null) {
            return minZoom;
        }
        float fitX = viewportWidth / Math.max(1f, worldBounds.width);
        float fitY = viewportHeight / Math.max(1f, worldBounds.height);
        return Math.max(minZoom, Math.max(fitX, fitY));
    }

    // ── Coordinate Conversion ──

    public Vector2 worldToScreen(Vector2 worldPos) {
        Vector2 offset = worldPos.copy().sub(getTransform().getPosition());
        float rot = getTransform().getRotation();
        if (rot != 0) {
            float cos = (float) Math.cos(rot);
            float sin = (float) Math.sin(rot);
            float nx = offset.x * cos - offset.y * sin;
            float ny = offset.x * sin + offset.y * cos;
            offset.set(nx, ny);
        }
        offset.mult(zoom);
        offset.add(viewportOffsetX + viewportWidth / 2, viewportOffsetY + viewportHeight / 2);
        return offset;
    }

    public Vector2 screenToWorld(Vector2 screenPos) {
        Vector2 offset = screenPos.copy().sub(viewportOffsetX + viewportWidth / 2, viewportOffsetY + viewportHeight / 2);
        offset.div(zoom);
        float rot = getTransform().getRotation();
        if (rot != 0) {
            float cos = (float) Math.cos(-rot);
            float sin = (float) Math.sin(-rot);
            float nx = offset.x * cos - offset.y * sin;
            float ny = offset.x * sin + offset.y * cos;
            offset.set(nx, ny);
        }
        offset.add(getTransform().getPosition());
        return offset;
    }

    // ── Helpers ──

    private static float constrain(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }
}
