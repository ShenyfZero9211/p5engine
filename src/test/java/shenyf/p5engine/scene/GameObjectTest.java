package shenyf.p5engine.scene;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class GameObjectTest {

    @Test
    void testCreate() {
        GameObject go = GameObject.create("TestObject");
        assertNotNull(go);
        assertEquals("TestObject", go.getName());
        assertNotNull(go.getGuid());
        assertTrue(go.isActive());
    }

    @Test
    void testAddComponent() {
        GameObject go = GameObject.create("TestObject");
        TestComponent component = go.addComponent(TestComponent.class);
        assertNotNull(component);
        assertEquals(go, component.getGameObject());
    }

    @Test
    void testGetComponent() {
        GameObject go = GameObject.create("TestObject");
        TestComponent tc = go.addComponent(TestComponent.class);
        TestComponent retrieved = go.getComponent(TestComponent.class);
        assertSame(tc, retrieved);
    }

    @Test
    void testHasComponent() {
        GameObject go = GameObject.create("TestObject");
        assertFalse(go.hasComponent(TestComponent.class));
        go.addComponent(TestComponent.class);
        assertTrue(go.hasComponent(TestComponent.class));
    }

    @Test
    void testRemoveComponent() {
        GameObject go = GameObject.create("TestObject");
        go.addComponent(TestComponent.class);
        assertTrue(go.hasComponent(TestComponent.class));
        go.removeComponent(TestComponent.class);
        assertFalse(go.hasComponent(TestComponent.class));
    }

    @Test
    void testTransform() {
        GameObject go = GameObject.create("TestObject");
        assertNotNull(go.getTransform());
        assertEquals(go, go.getTransform().getGameObject());
    }

    @Test
    void testActive() {
        GameObject go = GameObject.create("TestObject");
        assertTrue(go.isActive());
        go.setActive(false);
        assertFalse(go.isActive());
    }

    @Test
    void testSetName() {
        GameObject go = GameObject.create("Original");
        go.setName("Renamed");
        assertEquals("Renamed", go.getName());
    }

    public static class TestComponent extends Component {
        public boolean started = false;

        @Override
        public void start() {
            started = true;
        }

        @Override
        public void update(float dt) {
        }
    }
}
