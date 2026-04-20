package shenyf.p5engine.pool;

import shenyf.p5engine.scene.GameObject;
import shenyf.p5engine.scene.Scene;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.function.Supplier;

/**
 * Generic object pool for reusing GameObjects.
 * Register a factory per prefab name, then acquire/release objects to avoid GC pressure.
 */
public class ObjectPool {

    private final Map<String, List<GameObject>> pools = new HashMap<>();
    private final Map<String, Supplier<GameObject>> factories = new HashMap<>();
    private final Map<String, Consumer<GameObject>> resetters = new HashMap<>();

    public void register(String prefabName, Supplier<GameObject> factory) {
        factories.put(prefabName, factory);
    }

    public void register(String prefabName, Supplier<GameObject> factory, Consumer<GameObject> resetter) {
        factories.put(prefabName, factory);
        resetters.put(prefabName, resetter);
    }

    public GameObject acquire(String prefabName) {
        List<GameObject> pool = pools.get(prefabName);
        if (pool != null && !pool.isEmpty()) {
            GameObject go = pool.remove(pool.size() - 1);
            Consumer<GameObject> resetter = resetters.get(prefabName);
            if (resetter != null) {
                resetter.accept(go);
            }
            go.setActive(true);
            return go;
        }
        Supplier<GameObject> factory = factories.get(prefabName);
        if (factory != null) {
            return factory.get();
        }
        return null;
    }

    public void release(String prefabName, GameObject go) {
        if (go == null) return;
        go.setActive(false);
        pools.computeIfAbsent(prefabName, k -> new ArrayList<>()).add(go);
    }

    public void preload(String prefabName, int count) {
        Supplier<GameObject> factory = factories.get(prefabName);
        if (factory == null) return;
        List<GameObject> pool = pools.computeIfAbsent(prefabName, k -> new ArrayList<>());
        for (int i = 0; i < count; i++) {
            pool.add(factory.get());
        }
    }

    public void clear() {
        pools.clear();
    }

    public int getPoolSize(String prefabName) {
        List<GameObject> pool = pools.get(prefabName);
        return pool != null ? pool.size() : 0;
    }
}
