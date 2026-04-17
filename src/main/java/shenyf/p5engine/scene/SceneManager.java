package shenyf.p5engine.scene;

import shenyf.p5engine.util.Logger;

import java.util.*;

public class SceneManager {
    private final Map<String, Scene> scenes;
    private Scene activeScene;

    public SceneManager() {
        this.scenes = new HashMap<>();
    }

    public Scene createScene(String name) {
        if (scenes.containsKey(name)) {
            Logger.warn("Scene '" + name + "' already exists, returning existing scene");
            return scenes.get(name);
        }
        Scene scene = new Scene(name);
        scenes.put(name, scene);
        Logger.debug("Scene '" + name + "' created");
        return scene;
    }

    public Scene getScene(String name) {
        return scenes.get(name);
    }

    public void loadScene(String name) {
        Scene scene = scenes.get(name);
        if (scene == null) {
            Logger.warn("Scene '" + name + "' not found, creating new scene");
            scene = createScene(name);
        }

        if (activeScene != null) {
            activeScene.unload();
        }

        activeScene = scene;
        activeScene.load();
        Logger.info("Loaded scene: " + name);
    }

    public void unloadScene(String name) {
        Scene scene = scenes.get(name);
        if (scene == null) {
            Logger.warn("Scene '" + name + "' not found");
            return;
        }

        if (activeScene == scene) {
            activeScene.unload();
            activeScene = null;
        }
        scenes.remove(name);
        Logger.info("Unloaded scene: " + name);
    }

    public Scene getActiveScene() {
        if (activeScene == null) {
            activeScene = createScene("Default");
            activeScene.load();
        }
        return activeScene;
    }

    public void destroy() {
        if (activeScene != null) {
            activeScene.clear();
            activeScene = null;
        }
        scenes.clear();
        Logger.info("SceneManager destroyed");
    }

    public Set<String> getSceneNames() {
        return new HashSet<>(scenes.keySet());
    }
}
