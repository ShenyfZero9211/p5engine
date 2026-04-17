package shenyf.p5engine.scene;

import shenyf.p5engine.rendering.IRenderer;
import shenyf.p5engine.rendering.Renderable;
import shenyf.p5engine.util.Logger;

import java.util.*;

public class Scene {
    private final String name;
    private final List<GameObject> gameObjects;
    private boolean running;

    public Scene(String name) {
        this.name = name;
        this.gameObjects = new ArrayList<>();
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
        if (!gameObjects.contains(gameObject)) {
            gameObjects.add(gameObject);
        }
    }

    public void removeGameObject(GameObject gameObject) {
        gameObjects.remove(gameObject);
        gameObject.setScene(null);
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
        for (GameObject go : gameObjects) {
            go.setScene(null);
        }
        gameObjects.clear();
    }
}
