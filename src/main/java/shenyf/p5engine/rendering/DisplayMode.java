package shenyf.p5engine.rendering;

/**
 * Window display modes for the engine sketch.
 *
 * <ul>
 *   <li>{@code WINDOWED} — Normal resizable window with title bar and borders.</li>
 *   <li>{@code BORDERLESS_FULLSCREEN} — Undecorated window positioned at (0,0) and sized to the
 *       full screen. This is the preferred fullscreen mode on Windows because it avoids
 *       exclusive-mode flicker and allows instant alt-tab.</li>
 *   <li>{@code EXCLUSIVE_FULLSCREEN} — Uses the native display's exclusive fullscreen via
 *       JOGL/NEWT {@code setFullscreen(true)}. Falls back to borderless if unsupported.</li>
 * </ul>
 */
public enum DisplayMode {
    WINDOWED,
    BORDERLESS_FULLSCREEN,
    EXCLUSIVE_FULLSCREEN
}
