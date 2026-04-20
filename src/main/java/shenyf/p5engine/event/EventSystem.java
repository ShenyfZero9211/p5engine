package shenyf.p5engine.event;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Global publish/subscribe event system.
 * No game-specific concepts — purely string-based event routing.
 */
public class EventSystem {

    private final Map<String, List<EventListener>> listeners = new HashMap<>();
    private final Map<String, List<EventListener>> onceListeners = new HashMap<>();

    public void on(String eventName, EventListener listener) {
        listeners.computeIfAbsent(eventName, k -> new ArrayList<>()).add(listener);
    }

    public void once(String eventName, EventListener listener) {
        onceListeners.computeIfAbsent(eventName, k -> new ArrayList<>()).add(listener);
    }

    public void off(String eventName, EventListener listener) {
        List<EventListener> list = listeners.get(eventName);
        if (list != null) {
            list.remove(listener);
        }
        List<EventListener> onceList = onceListeners.get(eventName);
        if (onceList != null) {
            onceList.remove(listener);
        }
    }

    public void emit(String eventName) {
        emit(eventName, new GameEvent(eventName));
    }

    public void emit(String eventName, GameEvent event) {
        if (event.getName() == null) {
            event.setName(eventName);
        }

        List<EventListener> list = listeners.get(eventName);
        if (list != null) {
            for (EventListener listener : new ArrayList<>(list)) {
                listener.onEvent(event);
            }
        }

        List<EventListener> onceList = onceListeners.remove(eventName);
        if (onceList != null) {
            for (EventListener listener : onceList) {
                listener.onEvent(event);
            }
        }
    }

    public void clear() {
        listeners.clear();
        onceListeners.clear();
    }
}
