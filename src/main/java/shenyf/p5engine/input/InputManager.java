package shenyf.p5engine.input;

import processing.core.PApplet;
import processing.event.KeyEvent;

import java.util.HashMap;
import java.util.Map;

/**
 * Generic input manager for tracking key states and axis input.
 * No game-specific concepts — purely maps hardware input to abstract states.
 */
public class InputManager {

    private final Map<Integer, KeyState> keyStates = new HashMap<>();

    private float mouseX;
    private float mouseY;
    private boolean mousePressed;
    private int mouseButton;
    private float mouseWheelDelta;
    private float mouseDragDX;
    private float mouseDragDY;
    private boolean mouseJustPressed;
    private boolean mouseJustReleased;

    /** Tracks whether mouse-wheel events arrived since last updateMouse(). */
    private boolean wheelDirty;
    /** Tracks whether mouse-drag events arrived since last updateMouse(). */
    private boolean dragDirty;

    public InputManager() {
    }

    public void updateMouse(float x, float y, boolean pressed, int button) {
        // Clear accumulated deltas only if no new events arrived since last frame.
        // This preserves values set by callbacks (onMouseWheel/onMouseDragged)
        // so they remain readable after engine.update() returns.
        if (!wheelDirty) {
            mouseWheelDelta = 0;
        }
        wheelDirty = false;

        if (!dragDirty) {
            mouseDragDX = 0;
            mouseDragDY = 0;
        }
        dragDirty = false;

        this.mouseX = x;
        this.mouseY = y;
        this.mouseJustPressed = pressed && !this.mousePressed;
        this.mouseJustReleased = !pressed && this.mousePressed;
        this.mousePressed = pressed;
        this.mouseButton = button;
    }

    public void onMouseWheel(float delta) {
        wheelDirty = true;
        this.mouseWheelDelta += delta;
    }

    public void onMouseDragged(float dx, float dy) {
        dragDirty = true;
        this.mouseDragDX += dx;
        this.mouseDragDY += dy;
    }

    public float getMouseWheelDelta() {
        return mouseWheelDelta;
    }

    public float getMouseDragDX() {
        return mouseDragDX;
    }

    public float getMouseDragDY() {
        return mouseDragDY;
    }

    public boolean isMouseJustPressed() {
        return mouseJustPressed;
    }

    public boolean isMouseJustReleased() {
        return mouseJustReleased;
    }

    public void onKeyEvent(KeyEvent event) {
        int code = event.getKeyCode();
        KeyState state = keyStates.get(code);
        if (state == null) {
            state = new KeyState();
            keyStates.put(code, state);
        }
        if (event.getAction() == KeyEvent.PRESS) {
            if (!state.held) {
                state.pressed = true;
            }
            state.held = true;
            state.released = false;
        } else if (event.getAction() == KeyEvent.RELEASE) {
            state.held = false;
            state.released = true;
        }
    }

    public void postUpdate() {
        for (KeyState state : keyStates.values()) {
            state.pressed = false;
            state.released = false;
        }
        // mouseWheelDelta / mouseDragDX/DY are cleared lazily in updateMouse()
        // when no new events arrived since the last frame.
        // mouseJustPressed / mouseJustReleased are recomputed every frame in updateMouse().
    }

    public boolean isKeyDown(int keyCode) {
        KeyState state = keyStates.get(keyCode);
        return state != null && state.held;
    }

    public boolean isKeyPressed(int keyCode) {
        KeyState state = keyStates.get(keyCode);
        return state != null && state.pressed;
    }

    public boolean isKeyReleased(int keyCode) {
        KeyState state = keyStates.get(keyCode);
        return state != null && state.released;
    }

    /**
     * Returns an axis value in range [-1, 1].
     * Built-in axes: "Horizontal" (A/D or Left/Right), "Vertical" (W/S or Up/Down).
     */
    public float getAxis(String axisName) {
        if ("Horizontal".equals(axisName)) {
            float value = 0;
            if (isKeyDown(java.awt.event.KeyEvent.VK_A) || isKeyDown(PApplet.LEFT)) value -= 1;
            if (isKeyDown(java.awt.event.KeyEvent.VK_D) || isKeyDown(PApplet.RIGHT)) value += 1;
            return value;
        }
        if ("Vertical".equals(axisName)) {
            float value = 0;
            if (isKeyDown(java.awt.event.KeyEvent.VK_W) || isKeyDown(PApplet.UP)) value -= 1;
            if (isKeyDown(java.awt.event.KeyEvent.VK_S) || isKeyDown(PApplet.DOWN)) value += 1;
            return value;
        }
        return 0;
    }

    public float getMouseX() {
        return mouseX;
    }

    public float getMouseY() {
        return mouseY;
    }

    public boolean isMousePressed() {
        return mousePressed;
    }

    public int getMouseButton() {
        return mouseButton;
    }

    private static class KeyState {
        boolean pressed;
        boolean held;
        boolean released;
    }
}
