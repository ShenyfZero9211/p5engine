package shenyf.p5engine.pool;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

/**
 * Generic object pool for reusing arbitrary types.
 * Works alongside {@link ObjectPool} (GameObject-specific) for different use cases.
 *
 * <p>Typical usage:</p>
 * <pre>
 * GenericObjectPool&lt;Bullet&gt; pool = new GenericObjectPool<>(
 *     () -> new Bullet(),
 *     b -> { b.dead = true; }
 * );
 * Bullet b = pool.acquire();   // reuse or create
 * // ... use b ...
 * pool.release(b);             // return to pool
 * </pre>
 */
public class GenericObjectPool<T> {
    private final List<T> pool = new ArrayList<>();
    private final Supplier<T> factory;
    private final Consumer<T> resetter;

    public GenericObjectPool(Supplier<T> factory) {
        this(factory, null);
    }

    public GenericObjectPool(Supplier<T> factory, Consumer<T> resetter) {
        this.factory = factory;
        this.resetter = resetter;
    }

    /** Acquire an object from the pool, or create a new one if empty. */
    public T acquire() {
        if (!pool.isEmpty()) {
            T obj = pool.remove(pool.size() - 1);
            if (resetter != null) {
                resetter.accept(obj);
            }
            return obj;
        }
        return factory.get();
    }

    /** Release an object back to the pool for reuse. */
    public void release(T obj) {
        if (obj != null) {
            pool.add(obj);
        }
    }

    /** Pre-create objects to avoid runtime allocation spikes. */
    public void preload(int count) {
        for (int i = 0; i < count; i++) {
            pool.add(factory.get());
        }
    }

    /** Current number of pooled objects available. */
    public int size() {
        return pool.size();
    }

    /** Clear all pooled objects. */
    public void clear() {
        pool.clear();
    }
}
