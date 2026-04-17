package shenyf.p5engine.scene;

import org.junit.jupiter.api.Test;
import shenyf.p5engine.math.Vector2;
import static org.junit.jupiter.api.Assertions.*;

class TransformTest {

    @Test
    void testDefaultValues() {
        Transform transform = new Transform();
        Vector2 pos = transform.getPosition();
        assertEquals(0, pos.x);
        assertEquals(0, pos.y);
        assertEquals(0, transform.getRotation());
    }

    @Test
    void testSetPosition() {
        Transform transform = new Transform();
        transform.setPosition(10, 20);
        assertEquals(10, transform.getPosition().x);
        assertEquals(20, transform.getPosition().y);
    }

    @Test
    void testTranslate() {
        Transform transform = new Transform();
        transform.setPosition(5, 5);
        transform.translate(3, 2);
        assertEquals(8, transform.getPosition().x);
        assertEquals(7, transform.getPosition().y);
    }

    @Test
    void testRotation() {
        Transform transform = new Transform();
        transform.setRotationDegrees(90);
        assertEquals(90, transform.getRotationDegrees(), 0.0001);
        assertEquals(Math.PI / 2, transform.getRotation(), 0.0001);
    }

    @Test
    void testScale() {
        Transform transform = new Transform();
        transform.setScale(2, 3);
        assertEquals(2, transform.getScale().x);
        assertEquals(3, transform.getScale().y);
    }

    @Test
    void testRotate() {
        Transform transform = new Transform();
        transform.setRotation(0);
        transform.rotate((float) Math.PI / 2);
        assertEquals(Math.PI / 2, transform.getRotation(), 0.0001);
    }

    @Test
    void testSetParent() {
        Transform parent = new Transform();
        Transform child = new Transform();

        child.setPosition(5, 5);
        child.setParent(parent);

        assertEquals(parent, child.getParent());
    }

    @Test
    void testWorldPositionWithoutParent() {
        Transform transform = new Transform();
        transform.setPosition(10, 20);
        Vector2 worldPos = transform.getWorldPosition();
        assertEquals(10, worldPos.x);
        assertEquals(20, worldPos.y);
    }
}
