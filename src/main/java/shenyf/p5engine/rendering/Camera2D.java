package shenyf.p5engine.rendering;

import shenyf.p5engine.math.Vector2;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.Transform;

public class Camera2D extends Component {
    private float viewportWidth;
    private float viewportHeight;
    private Vector2 targetOffset;
    private Transform followTarget;

    public Camera2D() {
        this.targetOffset = new Vector2(0, 0);
    }

    @Override
    public void start() {
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

    public Vector2 worldToScreen(Vector2 worldPos) {
        Vector2 screenPos = worldPos.copy();
        Transform transform = getTransform();
        screenPos.sub(transform.getPosition());
        return screenPos;
    }

    public Vector2 screenToWorld(Vector2 screenPos) {
        Vector2 worldPos = screenPos.copy();
        Transform transform = getTransform();
        worldPos.add(transform.getPosition());
        return worldPos;
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
