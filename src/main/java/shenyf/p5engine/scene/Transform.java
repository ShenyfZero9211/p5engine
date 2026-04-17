package shenyf.p5engine.scene;

import shenyf.p5engine.math.Vector2;

public class Transform {
    private Vector2 position;
    private float rotation;
    private Vector2 scale;
    private Transform parent;
    private GameObject gameObject;

    Transform() {
        this.position = new Vector2(0, 0);
        this.rotation = 0f;
        this.scale = new Vector2(1, 1);
    }

    void setGameObject(GameObject go) {
        this.gameObject = go;
    }

    public Vector2 getPosition() {
        return position.copy();
    }

    public void setPosition(float x, float y) {
        this.position.set(x, y);
    }

    public void setPosition(Vector2 position) {
        this.position.set(position);
    }

    public void translate(float x, float y) {
        this.position.add(x, y);
    }

    public void translate(Vector2 delta) {
        this.position.add(delta);
    }

    public float getRotation() {
        return rotation;
    }

    public void setRotation(float radians) {
        this.rotation = radians;
    }

    public float getRotationDegrees() {
        return (float) Math.toDegrees(rotation);
    }

    public void setRotationDegrees(float degrees) {
        this.rotation = (float) Math.toRadians(degrees);
    }

    public void rotate(float deltaRadians) {
        this.rotation += deltaRadians;
    }

    public Vector2 getScale() {
        return scale.copy();
    }

    public void setScale(float x, float y) {
        this.scale.set(x, y);
    }

    public void setScale(Vector2 scale) {
        this.scale.set(scale);
    }

    public Transform getParent() {
        return parent;
    }

    public void setParent(Transform parent) {
        if (this.parent != null && this.parent != parent) {
            // Remove from old parent
        }
        this.parent = parent;
    }

    public Vector2 getWorldPosition() {
        if (parent == null) {
            return position.copy();
        }
        Vector2 worldPos = parent.getWorldPosition();
        worldPos.add(position);
        return worldPos;
    }

    public float getWorldRotation() {
        if (parent == null) {
            return rotation;
        }
        return parent.getWorldRotation() + rotation;
    }

    public GameObject getGameObject() {
        return gameObject;
    }
}
