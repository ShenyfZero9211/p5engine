package shenyf.p5engine.platform.win32;

import com.sun.jna.Native;
import com.sun.jna.Pointer;
import com.sun.jna.platform.win32.WinDef;
import com.sun.jna.platform.win32.User32;
import com.sun.jna.win32.StdCallLibrary;

import java.awt.Frame;
import java.util.HashMap;
import java.util.Map;

/**
 * Windows IME (Input Method Editor) helper using JNA.
 * <p>
 * Detaches/restores the input method context from a window via
 * {@code imm32.ImmAssociateContext}. This bypasses IME interception for
 * game controls (arrow keys, Space, Tab, WASD) while allowing TextInput
 * components to re-enable IME on demand.
 * <p>
 * Designed to be used as a Processing library dependency: place
 * {@code jna.jar} and {@code jna-platform.jar} alongside {@code p5engine.jar}
 * in the library's {@code library/} folder.
 */
public class ImeHelper {

    private static final Map<Long, Long> CACHED_HIMC = new HashMap<>();

    public interface Imm32 extends StdCallLibrary {
        Imm32 INSTANCE = Native.load("imm32", Imm32.class);

        Pointer ImmGetContext(WinDef.HWND hwnd);

        boolean ImmAssociateContext(WinDef.HWND hwnd, Pointer himc);

        boolean ImmReleaseContext(WinDef.HWND hwnd, Pointer himc);
    }

    /**
     * Disables IME for the given window handle, caching the previous IME context.
     *
     * @param hwnd native window handle (HWND)
     * @return true if successful
     */
    public static boolean disableIme(long hwnd) {
        if (hwnd == 0) return false;
        WinDef.HWND hWnd = new WinDef.HWND(new Pointer(hwnd));
        Pointer himc = Imm32.INSTANCE.ImmGetContext(hWnd);
        if (himc != null) {
            long himcValue = Pointer.nativeValue(himc);
            if (himcValue != 0) {
                CACHED_HIMC.put(hwnd, himcValue);
            }
            Imm32.INSTANCE.ImmReleaseContext(hWnd, himc);
        }
        return Imm32.INSTANCE.ImmAssociateContext(hWnd, null);
    }

    /**
     * Restores the previously cached IME context for the given window handle.
     *
     * @param hwnd native window handle (HWND)
     * @return true if successful
     */
    public static boolean restoreIme(long hwnd) {
        if (hwnd == 0) return false;
        Long himcValue = CACHED_HIMC.get(hwnd);
        Pointer himc = (himcValue == null || himcValue == 0) ? null : new Pointer(himcValue);
        WinDef.HWND hWnd = new WinDef.HWND(new Pointer(hwnd));
        return Imm32.INSTANCE.ImmAssociateContext(hWnd, himc);
    }

    /**
     * Attempts to obtain the native window handle (HWND) using multiple strategies.
     *
     * @param nativeSurface the object returned by {@code applet.getSurface().getNative()}
     * @param frame         the AWT Frame, if available
     * @param title         window title, used as fallback for FindWindow
     * @return HWND value, or 0 if not found
     */
    public static long getHwnd(Object nativeSurface, Frame frame, String title) {
        // Strategy 1: JOGL NEWT window handle (P2D/P3D)
        if (nativeSurface != null) {
            try {
                java.lang.reflect.Method m = nativeSurface.getClass().getMethod("getWindowHandle");
                Object result = m.invoke(nativeSurface);
                if (result instanceof Number) {
                    long hwnd = ((Number) result).longValue();
                    if (hwnd != 0) return hwnd;
                }
            } catch (Exception ignored) {
            }
        }

        // Strategy 2: AWT Frame peer hwnd (JAVA2D)
        if (frame != null) {
            try {
                Object peer = frame.getClass().getMethod("getPeer").invoke(frame);
                if (peer != null) {
                    java.lang.reflect.Field hwndField = peer.getClass().getDeclaredField("hwnd");
                    hwndField.setAccessible(true);
                    Object hwndObj = hwndField.get(peer);
                    if (hwndObj instanceof Number) {
                        long hwnd = ((Number) hwndObj).longValue();
                        if (hwnd != 0) return hwnd;
                    }
                }
            } catch (Exception ignored) {
            }
        }

        // Strategy 3: FindWindow by title
        if (title != null && !title.isEmpty()) {
            try {
                WinDef.HWND hwnd = User32.INSTANCE.FindWindow(null, title);
                if (hwnd != null) {
                    long value = Pointer.nativeValue(hwnd.getPointer());
                    if (value != 0) return value;
                }
            } catch (Exception ignored) {
            }
        }

        return 0;
    }
}
