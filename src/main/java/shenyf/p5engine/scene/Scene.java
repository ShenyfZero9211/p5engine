package shenyf.p5engine.scene;

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

    public void update(float deltaTime) {
        if (!running) return;
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
        for (GameObject go : gameObjects) {
            if (go.isActive()) {
                go.render(renderer);
            }
        }
    }

    public void addGameObject(GameObject gameObject) {
        gameObject.setScene(this);
        if (!gameObjects.contains(gameObject) && !addQueue.contains(gameObject)) {
            addQueue.add(gameObject);
            Logger.debug("Scene '" + name + "': addGameObject queued '" + gameObject.getName() + "', addQueue size=" + addQueue.size());
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
