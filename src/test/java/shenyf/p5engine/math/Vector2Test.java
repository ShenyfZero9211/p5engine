package shenyf.p5engine.math;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class Vector2Test {

    @Test
    void testDefaultConstructor() {
        Vector2 v = new Vector2();
        assertEquals(0, v.x);
        assertEquals(0, v.y);
    }

    @Test
    void testParameterizedConstructor() {
        Vector2 v = new Vector2(3, 4);
        assertEquals(3, v.x);
        assertEquals(4, v.y);
    }

    @Test
    void testCopy() {
        Vector2 v1 = new Vector2(3, 4);
        Vector2 v2 = v1.copy();
        assertEquals(v1.x, v2.x);
        assertEquals(v1.y, v2.y);
        assertNotSame(v1, v2);
    }

    @Test
    void testSet() {
        Vector2 v = new Vector2();
        v.set(5, 6);
        assertEquals(5, v.x);
        assertEquals(6, v.y);
    }

    @Test
    void testAdd() {
        Vector2 v = new Vector2(1, 2);
        v.add(new Vector2(3, 4));
        assertEquals(4, v.x);
        assertEquals(6, v.y);
    }

    @Test
    void testSub() {
        Vector2 v = new Vector2(5, 6);
        v.sub(new Vector2(2, 3));
        assertEquals(3, v.x);
        assertEquals(3, v.y);
    }

    @Test
    void testMult() {
        Vector2 v = new Vector2(2, 3);
        v.mult(2);
        assertEquals(4, v.x);
        assertEquals(6, v.y);
    }

    @Test
    void testDiv() {
        Vector2 v = new Vector2(4, 6);
        v.div(2);
        assertEquals(2, v.x);
        assertEquals(3, v.y);
    }

    @Test
    void testMagnitude() {
        Vector2 v = new Vector2(3, 4);
        assertEquals(5, v.magnitude(), 0.0001);
    }

    @Test
    void testNormalize() {
        Vector2 v = new Vector2(3, 4);
        v.normalize();
        assertEquals(1, v.magnitude(), 0.0001);
    }

    @Test
    void testDot() {
        Vector2 a = new Vector2(1, 2);
        Vector2 b = new Vector2(3, 4);
        assertEquals(11, a.dot(b), 0.0001);
    }

    @Test
    void testDistance() {
        Vector2 a = new Vector2(0, 0);
        Vector2 b = new Vector2(3, 4);
        assertEquals(5, a.distance(b), 0.0001);
    }

    @Test
    void testLerp() {
        Vector2 a = new Vector2(0, 0);
        Vector2 b = new Vector2(10, 10);
        Vector2 result = Vector2.lerp(a, b, 0.5f);
        assertEquals(5, result.x, 0.0001);
        assertEquals(5, result.y, 0.0001);
    }
}
