package shenyf.p5engine.scene;

import shenyf.p5engine.math.Rect;
import shenyf.p5engine.rendering.Camera2D;
import shenyf.p5engine.rendering.IRenderer;
import shenyf.p5engine.rendering.Renderable;
import shenyf.p5engine.util.Logger;

import java.util.*;

public class Scene {
    private final String name;
    private final List<GameObject> gameObjects;
    private final List<GameObject> addQueue;
    private final List<GameObject> destroyQueue;
    private boolean running;
    private int collisionCheckCount;
    private Camera2D camera;

    public Scene(String name) {
        this.name = name;
        this.gameObjects = new ArrayList<>();
        this.addQueue = new ArrayList<>();
        this.destroyQueue = new ArrayList<>();
        this.running = false;
    }

    public void load() {
        running = true;
        Logger.info("Scene '" + name + "' loaded with " + gameObjects.size() + " objects");
    }

    public void unload() {
        running = false;
        Logger.info("Scene '" + name + "' unloaded");
    }

    public boolean isRunning() {
        return running;
    }

    public void update(float deltaTime) {
        if (!running) return;
        collisionCheckCount = 0;
        for (GameObject go : gameObjects) {
            if (go.isActive()) {
                go.update(deltaTime);
            }
        }
        processDestroyQueue();
        processAddQueue();
        checkCollisions();
    }

    public void render(IRenderer renderer) {
        if (!running) return;
        renderWorld(renderer, camera);
        renderScreen(renderer);
    }

    /**
     * Render only the world layer (renderLayer < 100) with the specified camera.
     */
    public void renderWorld(IRenderer renderer, Camera2D camera) {
        if (!running) return;

        List<RenderCommand> worldCommands = new ArrayList<>();
        for (GameObject go : gameObjects) {
            if (!go.isActive()) continue;
            // Viewport culling (only for world layer)
            if (go.getRenderLayer() < 100 && go.isCullEnabled() && camera != null) {
                Rect viewport = camera.getViewport();
                if (viewport != null && !viewport.intersects(go.getRenderBounds())) {
                    continue;
                }
            }
            for (Component c : go.getComponents()) {
                if (c instanceof Renderable && c.isEnabled()) {
                    if (go.getRenderLayer() < 100) {
                        worldCommands.add(new RenderCommand(go.getRenderLayer(), go.getZIndex(), (Renderable) c));
                    }
                }
            }
        }

        worldCommands.sort(cmdSort);

        if (camera != null) camera.begin(renderer);
        for (RenderCommand cmd : worldCommands) {
            cmd.renderable.render(renderer);
        }
        if (camera != null) camera.end(renderer);
    }

    /**
     * Render only the screen layer (renderLayer >= 100) without camera transform.
     */
    public void renderScreen(IRenderer renderer) {
        if (!running) return;

        List<RenderCommand> screenCommands = new ArrayList<>();
        for (GameObject go : gameObjects) {
            if (!go.isActive()) continue;
            for (Component c : go.getComponents()) {
                if (c instanceof Renderable && c.isEnabled()) {
                    if (go.getRenderLayer() >= 100) {
                        screenCommands.add(new RenderCommand(go.getRenderLayer(), go.getZIndex(), (Renderable) c));
                    }
                }
            }
        }

        screenCommands.sort(cmdSort);

        for (RenderCommand cmd : screenCommands) {
            cmd.renderable.render(renderer);
        }
    }

    private static final Comparator<RenderCommand> cmdSort = (a, b) -> {
        int layerCmp = Integer.compare(a.layer, b.layer);
        if (layerCmp != 0) return layerCmp;
        return Float.compare(a.zIndex, b.zIndex);
    };

    public void setCamera(Camera2D camera) {
        this.camera = camera;
    }

    public Camera2D getCamera() {
        return camera;
    }

    private static final class RenderCommand {
        final int layer;
        final float zIndex;
        final Renderable renderable;

        RenderCommand(int layer, float zIndex, Renderable renderable) {
            this.layer = layer;
            this.zIndex = zIndex;
            this.renderable = renderable;
        }
    }

    public void addGameObject(GameObject gameObject) {
        gameObject.setScene(this);
        if (!gameObjects.contains(gameObject) && !addQueue.contains(gameObject)) {
            addQueue.add(gameObject);
            // Logger.debug("Scene '" + name + "': addGameObject queued '" + gameObject.getName() + "', addQueue size=" + addQueue.size());
        }
    }

    private void processAddQueue() {
        if (addQueue.isEmpty()) return;
        Logger.debug("Scene '" + name + "': processAddQueue processing " + addQueue.size() + " objects");
        for (GameObject go : addQueue) {
            gameObjects.add(go);
        }
        addQueue.clear();
    }

    public void removeGameObject(GameObject gameObject) {
        gameObjects.remove(gameObject);
        gameObject.setScene(null);
    }

    /** Remove the first GameObject with the given name. Returns true if found and removed. */
    public boolean removeGameObject(String name) {
        Iterator<GameObject> it = gameObjects.iterator();
        while (it.hasNext()) {
            GameObject go = it.next();
            if (go.getName().equals(name)) {
                it.remove();
                go.setScene(null);
                for (Component c : go.getComponents()) {
                    c.onDestroy();
                }
                return true;
            }
        }
        return false;
    }

    /** Remove all GameObjects with the given name. Returns the number removed. */
    public int removeGameObjects(String name) {
        int count = 0;
        Iterator<GameObject> it = gameObjects.iterator();
        while (it.hasNext()) {
            GameObject go = it.next();
            if (go.getName().equals(name)) {
                it.remove();
                go.setScene(null);
                for (Component c : go.getComponents()) {
                    c.onDestroy();
                }
                count++;
            }
        }
        return count;
    }

    public void markForDestroy(GameObject gameObject) {
        if (!destroyQueue.contains(gameObject)) {
            destroyQueue.add(gameObject);
        }
    }

    private void processDestroyQueue() {
        if (destroyQueue.isEmpty()) return;
        for (GameObject go : destroyQueue) {
            gameObjects.remove(go);
            go.setScene(null);
            for (Component c : go.getComponents()) {
                c.onDestroy();
            }
        }
        destroyQueue.clear();
    }

    private void checkCollisions() {
        for (int i = 0; i < gameObjects.size(); i++) {
            GameObject a = gameObjects.get(i);
            if (!a.isActive()) continue;
            for (Component c : a.getComponents()) {
                if (c instanceof shenyf.p5engine.collision.Collider) {
                    ((shenyf.p5engine.collision.Collider) c).checkCollisions(gameObjects);
                }
            }
        }
    }

    public GameObject findGameObject(String name) {
        for (GameObject go : gameObjects) {
            if (go.getName().equals(name)) {
                return go;
            }
        }
        return null;
    }

    public List<GameObject> findGameObjects(String name) {
        List<GameObject> results = new ArrayList<>();
        for (GameObject go : gameObjects) {
            if (go.getName().equals(name)) {
                results.add(go);
            }
        }
        return results;
    }

    public <T extends Component> GameObject findObjectWithComponent(Class<T> componentClass) {
        for (GameObject go : gameObjects) {
            if (go.hasComponent(componentClass)) {
                return go;
            }
        }
        return null;
    }

    public List<GameObject> findGameObjectsWithComponent(Class<? extends Component> componentClass) {
        List<GameObject> results = new ArrayList<>();
        for (GameObject go : gameObjects) {
            if (go.hasComponent(componentClass)) {
                results.add(go);
            }
        }
        return results;
    }

    public List<GameObject> findGameObjectsWithTag(String tag) {
        List<GameObject> results = new ArrayList<>();
        for (GameObject go : gameObjects) {
            if (go.getTag().equals(tag)) {
                results.add(go);
            }
        }
        return results;
    }

    public String getName() {
        return name;
    }

    public List<GameObject> getGameObjects() {
        return new ArrayList<>(gameObjects);
    }

    public int getObjectCount() {
        return gameObjects.size();
    }

    public int getCollisionCheckCount() {
        return collisionCheckCount;
    }

    public void incrementCollisionCheckCount() {
        collisionCheckCount++;
    }

    /**
     * Release all GameObjects with the given tag, invoking an optional callback for each.
     * Useful for bulk-recycling pooled objects (e.g. bullets) without individual markForDestroy.
     */
    public void releaseAllWithTag(String tag, java.util.function.Consumer<GameObject> releaseCallback) {
        for (int i = gameObjects.size() - 1; i >= 0; i--) {
            GameObject go = gameObjects.get(i);
            if (go.getTag().equals(tag)) {
                gameObjects.remove(i);
                go.setScene(null);
                if (releaseCallback != null) {
                    releaseCallback.accept(go);
                }
            }
        }
        addQueue.removeIf(go -> go.getTag().equals(tag));
        destroyQueue.removeIf(go -> go.getTag().equals(tag));
    }

    public void clear() {
        Logger.info("Scene '" + name + "': clear() — gameObjects=" + gameObjects.size()
            + ", addQueue=" + addQueue.size() + ", destroyQueue=" + destroyQueue.size());

        // 清理延迟添加队列（关键修复：防止旧对象在场景重启后被加入）
        for (GameObject go : addQueue) {
            go.setScene(null);
        }
        addQueue.clear();

        // 清理延迟销毁队列
        destroyQueue.clear();

        // 清理活跃对象
        for (GameObject go : gameObjects) {
            go.setScene(null);
        }
        gameObjects.clear();

        Logger.info("Scene '" + name + "': clear() completed");
    }
}
