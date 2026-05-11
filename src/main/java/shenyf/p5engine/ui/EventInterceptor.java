package shenyf.p5engine.ui;

import processing.event.MouseEvent;

/**
 * Interface for intercepting UI mouse events before they are dispatched to components.
 *
 * <p>Used by the tutorial system to enforce click-locking: clicks outside the target
 * area are intercepted and rejected with visual feedback, while clicks inside the
 * target area are allowed to pass through.
 *
 * <p>Register with {@link UIManager#setEventInterceptor(EventInterceptor)}.
 */
public interface EventInterceptor {

    /**
     * Called before a mouse event is dispatched to the hit-tested component.
     *
     * @param event the raw Processing mouse event
     * @param hit   the UI component under the mouse (may be null)
     * @return true if the event should be intercepted and NOT dispatched further;
     *         false to allow normal event dispatch
     */
    boolean interceptMouseEvent(MouseEvent event, UIComponent hit);
}
