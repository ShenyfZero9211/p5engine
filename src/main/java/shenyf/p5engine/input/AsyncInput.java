package shenyf.p5engine.input;

import com.sun.jna.Native;
import com.sun.jna.platform.win32.WinDef;
import com.sun.jna.win32.StdCallLibrary;

import java.util.HashMap;
import java.util.Map;

/**
 * Low-level asynchronous keyboard input via JNA {@code GetAsyncKeyState}.
 * <p>
 * Polls the physical keyboard state directly, bypassing the AWT event queue
 * and IME. Used as a fallback/supplement to normal {@link InputManager}
 * key events so game controls remain responsive even when an input method
 * is active.
 * <p>
 * JNA is already on the classpath (bundled with Processing 4.5.2).
 */
public class AsyncInput {

    public interface User32 extends StdCallLibrary {
        User32 INSTANCE = Native.load("user32", User32.class);

        /**
         * Retrieves the asynchronous key state for a virtual-key code.
         * The high-order bit is set if the key is currently down.
         *
         * @param nVirtKey virtual-key code
         * @return short with bit 15 = down, bit 0 = pressed since last call
         */
        short GetAsyncKeyState(int nVirtKey);
    }

    private static final int VK_CODES[] = {
        // Navigation
        java.awt.event.KeyEvent.VK_UP,
        java.awt.event.KeyEvent.VK_DOWN,
        java.awt.event.KeyEvent.VK_LEFT,
        java.awt.event.KeyEvent.VK_RIGHT,
        java.awt.event.KeyEvent.VK_TAB,
        java.awt.event.KeyEvent.VK_ENTER,
        java.awt.event.KeyEvent.VK_ESCAPE,
        java.awt.event.KeyEvent.VK_SPACE,
        java.awt.event.KeyEvent.VK_BACK_SPACE,
        java.awt.event.KeyEvent.VK_DELETE,
        java.awt.event.KeyEvent.VK_HOME,
        java.awt.event.KeyEvent.VK_END,
        java.awt.event.KeyEvent.VK_PAGE_UP,
        java.awt.event.KeyEvent.VK_PAGE_DOWN,
        // Modifier
        java.awt.event.KeyEvent.VK_SHIFT,
        java.awt.event.KeyEvent.VK_CONTROL,
        java.awt.event.KeyEvent.VK_ALT,
        // WASD
        java.awt.event.KeyEvent.VK_W,
        java.awt.event.KeyEvent.VK_A,
        java.awt.event.KeyEvent.VK_S,
        java.awt.event.KeyEvent.VK_D,
        // Numbers (top row and numpad)
        java.awt.event.KeyEvent.VK_0,
        java.awt.event.KeyEvent.VK_1,
        java.awt.event.KeyEvent.VK_2,
        java.awt.event.KeyEvent.VK_3,
        java.awt.event.KeyEvent.VK_4,
        java.awt.event.KeyEvent.VK_5,
        java.awt.event.KeyEvent.VK_6,
        java.awt.event.KeyEvent.VK_7,
        java.awt.event.KeyEvent.VK_8,
        java.awt.event.KeyEvent.VK_9,
        java.awt.event.KeyEvent.VK_NUMPAD0,
        java.awt.event.KeyEvent.VK_NUMPAD1,
        java.awt.event.KeyEvent.VK_NUMPAD2,
        java.awt.event.KeyEvent.VK_NUMPAD3,
        java.awt.event.KeyEvent.VK_NUMPAD4,
        java.awt.event.KeyEvent.VK_NUMPAD5,
        java.awt.event.KeyEvent.VK_NUMPAD6,
        java.awt.event.KeyEvent.VK_NUMPAD7,
        java.awt.event.KeyEvent.VK_NUMPAD8,
        java.awt.event.KeyEvent.VK_NUMPAD9,
        // Function keys
        java.awt.event.KeyEvent.VK_F1,
        java.awt.event.KeyEvent.VK_F2,
        java.awt.event.KeyEvent.VK_F3,
        java.awt.event.KeyEvent.VK_F4,
        java.awt.event.KeyEvent.VK_F5,
        java.awt.event.KeyEvent.VK_F6,
        java.awt.event.KeyEvent.VK_F7,
        java.awt.event.KeyEvent.VK_F8,
        java.awt.event.KeyEvent.VK_F9,
        java.awt.event.KeyEvent.VK_F10,
        java.awt.event.KeyEvent.VK_F11,
        java.awt.event.KeyEvent.VK_F12,
        // Letters used in shortcuts
        java.awt.event.KeyEvent.VK_E,
        java.awt.event.KeyEvent.VK_F,
        java.awt.event.KeyEvent.VK_G,
        java.awt.event.KeyEvent.VK_P,
        java.awt.event.KeyEvent.VK_R,
        java.awt.event.KeyEvent.VK_Q,
        java.awt.event.KeyEvent.VK_M,
        java.awt.event.KeyEvent.VK_N,
        java.awt.event.KeyEvent.VK_Z,
        java.awt.event.KeyEvent.VK_X,
        java.awt.event.KeyEvent.VK_C,
        java.awt.event.KeyEvent.VK_V,
        java.awt.event.KeyEvent.VK_B,
        // Punctuation
        java.awt.event.KeyEvent.VK_COMMA,
        java.awt.event.KeyEvent.VK_PERIOD,
        java.awt.event.KeyEvent.VK_SLASH,
        java.awt.event.KeyEvent.VK_SEMICOLON,
        java.awt.event.KeyEvent.VK_QUOTE,
        java.awt.event.KeyEvent.VK_OPEN_BRACKET,
        java.awt.event.KeyEvent.VK_CLOSE_BRACKET,
        java.awt.event.KeyEvent.VK_BACK_SLASH,
        java.awt.event.KeyEvent.VK_MINUS,
        java.awt.event.KeyEvent.VK_EQUALS,
        java.awt.event.KeyEvent.VK_MULTIPLY,
        java.awt.event.KeyEvent.VK_ADD,
        java.awt.event.KeyEvent.VK_SUBTRACT,
        java.awt.event.KeyEvent.VK_DIVIDE,
    };

    private final Map<Integer, KeyState> keyStates = new HashMap<>();
    private boolean windowFocused = true;

    private static class KeyState {
        boolean pressed;  // just pressed this frame
        boolean held;     // currently down
        boolean released; // just released this frame
    }

    /** Polls the hardware keyboard state for all tracked keys. Call once per frame. */
    public void update() {
        if (!windowFocused) {
            clear();
            return;
        }
        for (int vk : VK_CODES) {
            short state = User32.INSTANCE.GetAsyncKeyState(vk);
            boolean down = (state & 0x8000) != 0;

            KeyState ks = keyStates.get(vk);
            if (ks == null) {
                ks = new KeyState();
                keyStates.put(vk, ks);
            }

            ks.pressed = !ks.held && down;
            ks.released = ks.held && !down;
            ks.held = down;
        }
    }

    public boolean isDown(int keyCode) {
        KeyState ks = keyStates.get(keyCode);
        return ks != null && ks.held;
    }

    public boolean isPressed(int keyCode) {
        KeyState ks = keyStates.get(keyCode);
        return ks != null && ks.pressed;
    }

    public boolean isReleased(int keyCode) {
        KeyState ks = keyStates.get(keyCode);
        return ks != null && ks.released;
    }

    /** Returns the list of virtual-key codes that this instance tracks. */
    public static int[] getTrackedKeys() {
        return VK_CODES.clone();
    }

    /** Sets whether the application window currently has focus.
     * When false, {@link #update()} will clear all states and return immediately. */
    public void setWindowFocused(boolean focused) {
        this.windowFocused = focused;
    }

    /** Clears all tracked states (useful on window focus loss). */
    public void clear() {
        for (KeyState ks : keyStates.values()) {
            ks.pressed = false;
            ks.held = false;
            ks.released = false;
        }
    }
}
