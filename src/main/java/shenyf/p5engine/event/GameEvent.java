package shenyf.p5engine.event;

import shenyf.p5engine.scene.GameObject;

import java.util.HashMap;
import java.util.Map;

/**
 * Generic game event that can carry any data.
 */
public class GameEvent {

    private String name;
    private GameObject sender;
    private final Map<String, Object> data = new HashMap<>();

    public GameEvent() {
    }

    public GameEvent(String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public GameEvent setName(String name) {
        this.name = name;
        return this;
    }

    public GameObject getSender() {
        return sender;
    }

    public GameEvent setSender(GameObject sender) {
        this.sender = sender;
        return this;
    }

    public GameEvent set(String key, Object value) {
        data.put(key, value);
        return this;
    }

    @SuppressWarnings("unchecked")
    public <T> T get(String key) {
        return (T) data.get(key);
    }

    public boolean has(String key) {
        return data.containsKey(key);
    }

    public Map<String, Object> getData() {
        return new HashMap<>(data);
    }
}
