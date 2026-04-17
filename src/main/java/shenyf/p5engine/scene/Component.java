package shenyf.p5engine.scene;

import shenyf.p5engine.math.Vector2;

public abstract class Component {
    private final String instanceId;
    protected GameObject gameObject;
    protected boolean enabled;

    protected Component() {
        this.instanceId = java.util.UUID.randomUUID().toString();
        this.enabled = true;
    }

    public void start() {
    }

    public void update(float deltaTime) {
    }

    public void onEnable() {
    }

    public void onDisable() {
    }

    public void onDestroy() {
    }

    public String getInstanceId() {
        return instanceId;
    }

    public Transform getTransform() {
        return gameObject != null ? gameObject.getTransform() : null;
    }

    public Scene getScene() {
        return gameObject != null ? gameObject.getScene() : null;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        if (this.enabled != enabled) {
            this.enabled = enabled;
            if (enabled) {
                onEnable();
            } else {
                onDisable();
            }
        }
    }

    void setGameObject(GameObject go) {
        this.gameObject = go;
    }

    public GameObject getGameObject() {
        return gameObject;
    }

    protected Vector2 transformPoint(Vector2 localPoint) {
        return getTransform().getWorldPosition().add(localPoint);
    }
}
