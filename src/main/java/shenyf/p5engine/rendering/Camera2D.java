package shenyf.p5engine.rendering;

import shenyf.p5engine.math.Rect;
import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.Transform;

/**
 * A 2D camera that transforms world coordinates to screen coordinates.
 * Automatically applied during scene rendering when attached to a Scene.
 */
public class Camera2D extends Component {
    private float viewportWidth;
    private float viewportHeight;
    private Vector2 targetOffset;
    private Transform followTarget;
    private float followSpeed = 5.0f;
    private boolean smoothFollow = true;

    public Camera2D() {
        this.targetOffset = new Vector2(0, 0);
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
    }

    /**
     * Begin camera transform for rendering.
     * Must be paired with {@link #end(IRenderer)}.
     */
    public void begin(IRenderer renderer) {
        Vector2 pos = getTransform().getPosition();
        float rot = getTransform().getRotation();
        Vector2 scl = getTransform().getScale();
        renderer.pushTransform();
        renderer.translate(-pos.x + viewportWidth / 2, -pos.y + viewportHeight / 2);
        renderer.rotate(rot);
        renderer.scale(scl.x, scl.y);
    }

    /**
     * End camera transform for rendering.
     */
    public void end(IRenderer renderer) {
        renderer.popTransform();
    }

    public void setViewportSize(float width, float height) {
        this.viewportWidth = width;
        this.viewportHeight = height;
    }

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

    public Vector2 worldToScreen(Vector2 worldPos) {
        Vector2 screenPos = worldPos.copy();
        Transform transform = getTransform();
        screenPos.sub(transform.getPosition());
        screenPos.add(viewportWidth / 2, viewportHeight / 2);
        return screenPos;
    }

    public Vector2 screenToWorld(Vector2 screenPos) {
        Vector2 worldPos = screenPos.copy();
        worldPos.sub(new Vector2(viewportWidth / 2, viewportHeight / 2));
        worldPos.add(getTransform().getPosition());
        return worldPos;
    }

    /** Returns the camera's view rectangle in world coordinates. */
    public Rect getViewport() {
        Vector2 pos = getTransform().getPosition();
        return new Rect(
            pos.x - viewportWidth / 2,
            pos.y - viewportHeight / 2,
            viewportWidth,
            viewportHeight
        );
    }

    public float getViewportWidth() {
        return viewportWidth;
    }

    public float getViewportHeight() {
        return viewportHeight;
    }

    public Transform getFollowTarget() {
        return followTarget;
    }
}
