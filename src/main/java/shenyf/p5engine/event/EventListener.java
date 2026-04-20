package shenyf.p5engine.event;

/**
 * Listener interface for game events.
 */
@FunctionalInterface
public interface EventListener {
    void onEvent(GameEvent event);
}
