package shenyf.p5engine.ui;

import processing.core.PApplet;
import processing.core.PFont;
import processing.event.KeyEvent;
import processing.event.MouseEvent;
import shenyf.p5engine.input.AsyncInput;
import shenyf.p5engine.platform.win32.ImeHelper;
import shenyf.p5engine.rendering.DisplayManager;
import shenyf.p5engine.rendering.ScaleMode;
import shenyf.p5engine.util.Logger;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.function.Supplier;

public final class UIManager {

    private static UIManager paintingUi;
    private static UIManager lastInstance;
    private static float designMouseX;
    private static float designMouseY;

    public static boolean isPaintingContext(UIComponent c) {
        return paintingUi != null && paintingUi.focusManager.getFocused() == c;
    }

    public static boolean isFocusRingVisible() {
        return paintingUi != null && paintingUi.focusRingVisible;
    }

    public static PApplet getActiveApplet() {
        return lastInstance != null ? lastInstance.applet : null;
    }

    /** Returns the current mouse X in design-resolution coordinates (for hover detection). */
    public static float getDesignMouseX() {
        return designMouseX;
    }

    /** Returns the current mouse Y in design-resolution coordinates (for hover detection). */
    public static float getDesignMouseY() {
        return designMouseY;
    }

    private final PApplet applet;
    private final Panel root;
    private Theme theme = new DefaultTheme();
    /** When non-null, applied at the start of each {@link #render()} (after {@code pushStyle}) for P2D/CJK-safe text. */
    private PFont uiFont;
    private final FocusManager focusManager = new FocusManager();
    private final DragManager dragManager = new DragManager();
    private boolean focusRingVisible = false;
    private processing.core.PImage customCursor;
    /** Cursor-state deduplication: avoids redundant native cursor() calls. */
    private int currentCursorType = -1;
    private processing.core.PImage currentCursorImage;

    // Key-repeat state
    private int heldKeyCode = -1;
    private char heldKeyChar;
    private boolean heldShiftDown;
    private float heldTime = 0;
    private float keyRepeatAccumulator = 0;
    private static final float KEY_REPEAT_DELAY = 1.0f;
    private static final float KEY_REPEAT_INTERVAL = 0.05f;
    private final Map<String, UIComponent> pool = new HashMap<>();
    private final Set<String> frameSeen = new HashSet<>();
    private boolean inFrame;
    private boolean attached;
    private UIComponent pressedTarget;
    private Window resizeWindow;
    private Window mouseOverWindow;
    private UIComponent mouseOverComponent;
    private DisplayManager displayManager;

    // IME window handle for toggling input method on TextInput focus
    private long imeHwnd;
    private UIComponent lastFocusedForIme;

    // AsyncInput fallback for UI navigation when AWT events are lost
    private final AsyncInput asyncInput = new AsyncInput();
    private final Map<Integer, Boolean> lastAsyncDown = new HashMap<>();

    // Deduplicate AWT key events vs AsyncInput synthesized events
    private int lastAwtKeyCode = -1;
    private long lastAwtKeyTime = 0;
    private static final long AWT_ASYNC_DEDUP_MS = 100;

    // Time-based deduplication for duplicate KEY_PRESSED from any source
    private int lastDispatchKeyCode = -1;
    private long lastDispatchTime = 0;
    private static final long DISPATCH_DEDUP_MS = 40;

    // When true, navigation keys are reserved for game input (camera scroll etc.)
    private boolean gameInputActive = false;

    // Event interceptor for tutorial system (click locking)
    private EventInterceptor eventInterceptor;

    public UIManager(PApplet applet) {
        this.applet = applet;
        this.root = new Panel("ui_root");
        this.root.setLayoutManager(null);
        this.root.setPaintBackground(false);
        this.root.markLayoutDirtyUp();
        lastInstance = this;
    }

    public void attach() {
        if (attached) return;
        applet.registerMethod("mouseEvent", this);
        applet.registerMethod("keyEvent", this);
        attached = true;
    }

    public void detach() {
        if (!attached) return;
        applet.unregisterMethod("mouseEvent", this);
        applet.unregisterMethod("keyEvent", this);
        attached = false;
    }

    public void beginFrame() {
        inFrame = true;
        frameSeen.clear();
    }

    public void endFrame() {
        inFrame = false;
        Iterator<Map.Entry<String, UIComponent>> it = pool.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<String, UIComponent> e = it.next();
            if (!frameSeen.contains(e.getKey())) {
                UIComponent c = e.getValue();
                if (c.getParent() != null) {
                    c.getParent().remove(c);
                }
                it.remove();
            }
        }
    }

    private void touch(String id) {
        if (inFrame) {
            frameSeen.add(id);
        }
    }

    private <T extends UIComponent> T poolGet(String id, Supplier<T> factory) {
        touch(id);
        UIComponent existing = pool.get(id);
        if (existing != null) {
            @SuppressWarnings("unchecked")
            T t = (T) existing;
            return t;
        }
        T created = factory.get();
        if (created.getId().isEmpty()) {
            created.setId(id);
        }
        pool.put(id, created);
        ensureOnRoot(created);
        return created;
    }

    private void ensureOnRoot(UIComponent c) {
        if (c.getParent() == null) {
            root.add(c);
            root.markLayoutDirtyUp();
        }
    }

    public Panel panel(String id) {
        return poolGet(id, () -> new Panel(id));
    }

    public Frame frame(String id) {
        return poolGet(id, () -> new Frame(id));
    }

    public Window window(String id) {
        return poolGet(id, () -> new Window(id));
    }

    public ScrollPane scrollPane(String id) {
        return poolGet(id, () -> new ScrollPane(id));
    }

    public TabPane tabPane(String id) {
        return poolGet(id, () -> new TabPane(id));
    }

    public Button button(String id) {
        return poolGet(id, () -> new Button(id));
    }

    public Label label(String id) {
        return poolGet(id, () -> new Label(id));
    }

    public Checkbox checkbox(String id) {
        return poolGet(id, () -> new Checkbox(id));
    }

    public RadioButton radio(String id) {
        return poolGet(id, () -> new RadioButton(id));
    }

    public Slider slider(String id) {
        return poolGet(id, () -> new Slider(id));
    }

    public ScrollBar scrollBar(String id) {
        return poolGet(id, () -> new ScrollBar(id));
    }

    public TextInput textInput(String id) {
        return poolGet(id, () -> new TextInput(id));
    }

    public List list(String id) {
        return poolGet(id, () -> new List(id));
    }

    public MenuBar menuBar(String id) {
        return poolGet(id, () -> new MenuBar(id));
    }

    public Image image(String id) {
        return poolGet(id, () -> new Image(id));
    }

    public ProgressBar progressBar(String id) {
        return poolGet(id, () -> new ProgressBar(id));
    }

    public FocusManager getFocusManager() {
        return focusManager;
    }

    public Theme getTheme() {
        return theme;
    }

    public void setTheme(Theme theme) {
        this.theme = theme != null ? theme : new DefaultTheme();
    }

    /** Sets the native window handle for IME toggle (TextInput focus). */
    public void setImeHwnd(long hwnd) {
        this.imeHwnd = hwnd;
    }

    /**
     * When true, navigation keys (arrows, Tab) are consumed by game input
     * and will not trigger UI focus changes. Call from the game loop based on state.
     */
    public void setGameInputActive(boolean active) {
        this.gameInputActive = active;
    }

    public void setCustomCursor(processing.core.PImage cursor) {
        this.customCursor = cursor;
    }

    /**
     * Sets an event interceptor that can block mouse events before they reach UI components.
     * Used by the tutorial system to enforce click-locking. Pass null to remove.
     */
    public void setEventInterceptor(EventInterceptor interceptor) {
        this.eventInterceptor = interceptor;
    }

    /** Returns the current event interceptor, or null if none is set. */
    public EventInterceptor getEventInterceptor() {
        return eventInterceptor;
    }

    /**
     * Sets a font applied around the UI paint pass. Use with {@code createFont(...)} on the sketch
     * so themes that only set {@code textSize} still render CJK under {@code P2D}. Pass {@code null} to disable.
     */
    public void setUiFont(PFont font) {
        this.uiFont = font;
    }

    public PFont getUiFont() {
        return uiFont;
    }

    /**
     * Sets the {@link DisplayManager} used for resolution scaling.
     * When set, UI coordinates are interpreted in the design resolution space
     * and automatically scaled to the actual window size during rendering.
     */
    public void setDisplayManager(DisplayManager displayManager) {
        this.displayManager = displayManager;
    }

    public DisplayManager getDisplayManager() {
        return displayManager;
    }

    public Panel getRoot() {
        return root;
    }

    /**
     * Converts physical screen pixel coordinates to UI root internal coordinates.
     * The returned values can be passed directly to {@link UIComponent#setBounds}
     * or {@link UIComponent#setPosition} to place components at the given screen position.
     * When no DisplayManager is set or scale mode is NO_SCALE, returns the input unchanged.
     */
    public shenyf.p5engine.math.Vector2 screenToUi(float screenX, float screenY) {
        if (displayManager != null && displayManager.getScaleMode() != ScaleMode.NO_SCALE) {
            float scale = displayManager.getUniformScale();
            float ox = displayManager.getOffsetX() / scale;
            float oy = displayManager.getOffsetY() / scale;
            shenyf.p5engine.math.Vector2 design = displayManager.actualToDesign(
                new shenyf.p5engine.math.Vector2(screenX, screenY));
            return new shenyf.p5engine.math.Vector2(design.x + ox, design.y + oy);
        }
        return new shenyf.p5engine.math.Vector2(screenX, screenY);
    }

    /**
     * Converts UI root internal coordinates to physical screen pixel coordinates.
     * When no DisplayManager is set or scale mode is NO_SCALE, returns the input unchanged.
     */
    public shenyf.p5engine.math.Vector2 uiToScreen(float uiX, float uiY) {
        if (displayManager != null && displayManager.getScaleMode() != ScaleMode.NO_SCALE) {
            float scale = displayManager.getUniformScale();
            float ox = displayManager.getOffsetX() / scale;
            float oy = displayManager.getOffsetY() / scale;
            return displayManager.designToActual(
                new shenyf.p5engine.math.Vector2(uiX - ox, uiY - oy));
        }
        return new shenyf.p5engine.math.Vector2(uiX, uiY);
    }

    /** Returns the current UI root width in design-resolution units (covers the full physical window). */
    public float getUiWidth() {
        return root.getWidth();
    }

    /** Returns the current UI root height in design-resolution units (covers the full physical window). */
    public float getUiHeight() {
        return root.getHeight();
    }

    /** Returns the current UI root X offset in design-resolution units (negative when letterboxed). */
    public float getUiOffsetX() {
        return root.getX();
    }

    /** Returns the current UI root Y offset in design-resolution units (negative when letterboxed). */
    public float getUiOffsetY() {
        return root.getY();
    }

    /**
     * Creates a panel placed at the given physical screen pixel coordinates,
     * automatically converting to UI design coordinates with root offset compensation.
     */
    public Panel createPanelAtScreen(String id, float screenX, float screenY, float w, float h) {
        shenyf.p5engine.math.Vector2 uiPos = screenToUi(screenX, screenY);
        Panel p = panel(id);
        p.setBounds(uiPos.x, uiPos.y, w, h);
        return p;
    }

    public void update(float dt) {
        if (displayManager != null && displayManager.getScaleMode() != ScaleMode.NO_SCALE) {
            float scale = displayManager.getUniformScale();
            float ox = displayManager.getOffsetX() / scale;
            float oy = displayManager.getOffsetY() / scale;
            float fullW = displayManager.getActualWidth() / scale;
            float fullH = displayManager.getActualHeight() / scale;
            root.setBounds(-ox, -oy, fullW, fullH);
            shenyf.p5engine.math.Vector2 design = displayManager.actualToDesign(
                new shenyf.p5engine.math.Vector2(applet.mouseX, applet.mouseY));
            designMouseX = design.x;
            designMouseY = design.y;

        } else {
            root.setBounds(0, 0, applet.width, applet.height);
            designMouseX = applet.mouseX;
            designMouseY = applet.mouseY;
        }
        // Apply anchor constraints for adaptive layout
        if (displayManager != null && displayManager.getScaleMode() != ScaleMode.NO_SCALE) {
            float ox = displayManager.getOffsetX() / displayManager.getUniformScale();
            float oy = displayManager.getOffsetY() / displayManager.getUniformScale();
            float fullW = displayManager.getActualWidth() / displayManager.getUniformScale();
            float fullH = displayManager.getActualHeight() / displayManager.getUniformScale();
            float designW = displayManager.getDesignWidth();
            float designH = displayManager.getDesignHeight();
            for (UIComponent c : root.getChildren()) {
                int anchor = c.getAnchor();
                if (anchor == 0) continue;
                float cx = c.getAnchorBaseX();
                float cy = c.getAnchorBaseY();
                float cw = c.getAnchorBaseWidth();
                float ch = c.getAnchorBaseHeight();
                if (c.hasAnchor(UIComponent.ANCHOR_LEFT)) {
                    cx = 0;
                    if (c.hasAnchor(UIComponent.ANCHOR_RIGHT)) {
                        cw = fullW;
                    }
                } else if (c.hasAnchor(UIComponent.ANCHOR_RIGHT)) {
                    cx = fullW - cw;
                } else if (c.hasAnchor(UIComponent.ANCHOR_HCENTER)) {
                    cx = (fullW - cw) / 2;
                }
                if (c.hasAnchor(UIComponent.ANCHOR_TOP)) {
                    // If component was originally placed below top edge (cy > 0), preserve offset
                    // so it stays relative to the top edge after shifting to -oy
                    cy = Math.max(0, cy);
                    if (c.hasAnchor(UIComponent.ANCHOR_BOTTOM)) {
                        // Stretch from adjusted top to bottom edge
                        ch = fullH - cy;
                    }
                } else if (c.hasAnchor(UIComponent.ANCHOR_BOTTOM)) {
                    // Stretch from current y to window bottom (account for offset)
                    ch = fullH - cy;
                } else if (c.hasAnchor(UIComponent.ANCHOR_VCENTER)) {
                    cy = (fullH - ch) / 2;
                }
                c.setBounds(cx, cy, cw, ch);
            }
        }

        if (root.isLayoutDirty()) {
            root.measure(applet);
            root.layout(applet);
        }
        root.update(applet, dt);

        // Clear focus if the focused component is no longer in the UI hierarchy
        UIComponent curFocused = focusManager.getFocused();
        if (curFocused != null && !isInHierarchy(curFocused, root)) {
            focusManager.clearFocus();
        }

        // Key-repeat: after initial delay, fire repeated KEY_PRESSED events
        if (heldKeyCode >= 0) {
            heldTime += dt;
            if (heldTime >= KEY_REPEAT_DELAY) {
                keyRepeatAccumulator += dt;
                while (keyRepeatAccumulator >= KEY_REPEAT_INTERVAL) {
                    keyRepeatAccumulator -= KEY_REPEAT_INTERVAL;
                    dispatchKeyPress(heldKeyChar, heldKeyCode, heldShiftDown);
                }
            }
        }

        // IME toggle on TextInput focus change
        if (imeHwnd != 0) {
            UIComponent imeFocused = focusManager.getFocused();
            if (imeFocused != lastFocusedForIme) {
                if (imeFocused instanceof TextInput) {
                    ImeHelper.restoreIme(imeHwnd);
                } else if (lastFocusedForIme instanceof TextInput) {
                    ImeHelper.disableIme(imeHwnd);
                }
                lastFocusedForIme = imeFocused;
            }
        }

        // AsyncInput fallback: synthesize KEY_PRESSED / KEY_RELEASED for navigation keys
        // when AWT events are lost (e.g. stubborn IME still intercepting)
        asyncInput.update();
        for (int vk : AsyncInput.getTrackedKeys()) {
            boolean down = asyncInput.isDown(vk);
            Boolean prev = lastAsyncDown.get(vk);
            if (prev == null) prev = false;
            if (!prev && down) {
                // Skip if AWT already handled this key very recently
                if (vk == lastAwtKeyCode && System.currentTimeMillis() - lastAwtKeyTime < AWT_ASYNC_DEDUP_MS) {
                    continue;
                }
                // Synthesize KEY_PRESSED for navigation / action keys only
                if (vk == java.awt.event.KeyEvent.VK_UP || vk == java.awt.event.KeyEvent.VK_DOWN
                        || vk == java.awt.event.KeyEvent.VK_LEFT || vk == java.awt.event.KeyEvent.VK_RIGHT
                        || vk == java.awt.event.KeyEvent.VK_TAB || vk == java.awt.event.KeyEvent.VK_ENTER
                        || vk == java.awt.event.KeyEvent.VK_SPACE || vk == java.awt.event.KeyEvent.VK_ESCAPE) {
                    dispatchKeyPress((char) 0, vk, false);
                }
            }
            lastAsyncDown.put(vk, down);
        }
    }

    public void render() {
        paintingUi = this;
        applet.pushStyle();
        try {
            if (uiFont != null) {
                applet.textFont(uiFont);
            }
            root.paint(applet, theme);
        } finally {
            applet.popStyle();
            paintingUi = null;
        }
    }

    public void mouseEvent(MouseEvent e) {
        int act = e.getAction();
        float mx = e.getX();
        float my = e.getY();

        // Convert screen coordinates to design-resolution coordinates
        if (displayManager != null) {
            shenyf.p5engine.math.Vector2 design = displayManager.actualToDesign(
                new shenyf.p5engine.math.Vector2(mx, my));
            mx = design.x;
            my = design.y;

        }

        UIComponent hit = root.hitTest(mx, my);
        mouseOverComponent = hit;
        mouseOverWindow = findWindowInHierarchy(hit);

        // Event interception (e.g. tutorial click-locking)
        if (eventInterceptor != null && act != MouseEvent.MOVE) {
            if (eventInterceptor.interceptMouseEvent(e, hit)) {
                if (act == MouseEvent.PRESS) {
                    pressedTarget = null;
                }
                return;
            }
        }

        if (act == MouseEvent.WHEEL) {
            float delta = e.getCount();
            dispatchBubble(hit, UIEvent.wheel(mx, my, delta), mx, my);
            return;
        }

        if (act == MouseEvent.MOVE) {
            updateCursor(mx, my, hit);
            return;
        }

        if (act == MouseEvent.PRESS) {
            UIComponent fhit = hit;
            while (fhit != null && !fhit.isFocusable()) {
                fhit = fhit.getParent();
            }
            focusManager.setFocused(fhit);
            focusRingVisible = false;

            // Window-specific handling (buttons, resize, drag, double-click)
            Window win = findWindowInHierarchy(hit);
            if (win != null && e.getButton() == PApplet.LEFT) {
                // Double-click on title bar (not buttons) -> maximize/restore
                if (e.getCount() >= 2 && win.isTitleBarHit(mx, my)
                        && !win.isCloseButtonHit(mx, my)
                        && !win.isMaxButtonHit(mx, my)
                        && !win.isMinButtonHit(mx, my)) {
                    if (dragManager.isDragging()) dragManager.endDrag();
                    if (win.isMaximized()) win.restore(); else win.maximize();
                    pressedTarget = null;
                    return;
                }

                // Buttons
                if (win.isCloseButtonHit(mx, my)) {
                    win.close();
                    pressedTarget = null;
                    return;
                }
                if (win.isMaxButtonHit(mx, my)) {
                    if (win.isMaximized()) win.restore(); else win.maximize();
                    pressedTarget = null;
                    return;
                }
                if (win.isMinButtonHit(mx, my)) {
                    if (win.isMinimized()) win.restore(); else win.minimize();
                    pressedTarget = null;
                    return;
                }

                // Resize edge
                Window.ResizeEdge edge = win.getResizeEdge(mx, my);
                if (edge != Window.ResizeEdge.NONE) {
                    resizeWindow = win;
                    win.beginResize(edge, mx, my);
                    pressedTarget = hit;
                    return;
                }

                // Title bar drag
                if (win.isMovable() && win.isTitleBarHit(mx, my)) {
                    dragManager.beginDrag(win, mx, my);
                }
            }
            pressedTarget = hit;
            dispatchBubble(hit, UIEvent.mouse(UIEvent.Type.MOUSE_PRESSED, mx, my, e.getButton()), mx, my);
            return;
        }

        if (act == MouseEvent.DRAG) {
            if (resizeWindow != null) {
                resizeWindow.updateResize(mx, my);
            } else if (dragManager.isDragging()) {
                dragManager.updateDrag(mx, my);
            }
            if (pressedTarget != null) {
                pressedTarget.onEvent(UIEvent.mouse(UIEvent.Type.MOUSE_DRAGGED, mx, my, e.getButton()), mx, my);
            }
            return;
        }

        if (act == MouseEvent.RELEASE) {
            if (resizeWindow != null && e.getButton() == PApplet.LEFT) {
                resizeWindow.endResize();
                resizeWindow = null;
            }
            if (dragManager.isDragging() && e.getButton() == PApplet.LEFT) {
                dragManager.endDrag();
            }
            dispatchBubble(pressedTarget, UIEvent.mouse(UIEvent.Type.MOUSE_RELEASED, mx, my, e.getButton()), mx, my);
            pressedTarget = null;
        }
    }

    public boolean isMouseOverWindow() {
        return mouseOverWindow != null;
    }

    public boolean isFocusInsideWindow() {
        UIComponent f = focusManager.getFocused();
        return f != null && findWindowInHierarchy(f) != null;
    }

    /**
     * Returns true if the mouse is currently over a MenuPopup or an expanded Dropdown.
     * Used by sketches to avoid processing world-editor interactions when a UI popup is active.
     */
    public boolean isMouseOverPopup() {
        if (mouseOverComponent == null) return false;
        UIComponent c = mouseOverComponent;
        while (c != null) {
            if (c instanceof MenuPopup) return true;
            if (c instanceof Dropdown && ((Dropdown) c).isExpanded()) return true;
            c = c.getParent();
        }
        return false;
    }

    /** Returns the deepest UI component currently under the mouse (updated during mouse events). */
    public UIComponent getMouseOverComponent() {
        return mouseOverComponent;
    }

    /**
     * Closes any open MenuBar popups if the given coordinates are outside the popup and menu titles.
     * Returns true if a popup was closed.
     */
    public boolean closeMenuPopupsIfOutside(float mx, float my) {
        for (UIComponent c : root.getChildren()) {
            if (c instanceof MenuBar) {
                if (((MenuBar) c).closePopupsIfClickOutside(mx, my)) {
                    return true;
                }
            }
        }
        return false;
    }

    /** Walk up the hierarchy to find the nearest Window ancestor. */
    private Window findWindowInHierarchy(UIComponent start) {
        UIComponent c = start;
        while (c != null) {
            if (c instanceof Window) return (Window) c;
            c = c.getParent();
        }
        return null;
    }

    /** Update mouse cursor based on hover/resize state. */
    private void updateCursor(float mx, float my, UIComponent hit) {
        int targetType = PApplet.ARROW;
        processing.core.PImage targetImg = null;

        if (resizeWindow != null) {
            targetType = PApplet.CROSS;
        } else {
            Window w = findWindowInHierarchy(hit);
            if (w != null) {
                Window.ResizeEdge edge = w.getResizeEdge(mx, my);
                if (edge != Window.ResizeEdge.NONE) {
                    targetType = PApplet.CROSS;
                } else if (w.isMovable() && w.isTitleBarHit(mx, my)) {
                    targetType = PApplet.MOVE;
                }
            }
            if (targetType == PApplet.ARROW && customCursor != null) {
                targetImg = customCursor;
            }
        }

        // Only call cursor() when state actually changes (avoids P2D overhead)
        if (targetImg != null) {
            if (targetImg != currentCursorImage) {
                currentCursorImage = targetImg;
                currentCursorType = -2; // sentinel for custom image
                applet.cursor(targetImg, 0, 0);
            }
        } else if (targetType != currentCursorType) {
            currentCursorType = targetType;
            currentCursorImage = null;
            applet.cursor(targetType);
        }
    }

    public void keyEvent(KeyEvent e) {
        if (!applet.focused) return;
        int act = e.getAction();
        if (act == KeyEvent.PRESS) {
            heldKeyCode = e.getKeyCode();
            heldKeyChar = e.getKey();
            heldShiftDown = e.isShiftDown();
            heldTime = 0;
            keyRepeatAccumulator = 0;
            lastAwtKeyCode = heldKeyCode;
            lastAwtKeyTime = System.currentTimeMillis();
            dispatchKeyPress(heldKeyChar, heldKeyCode, heldShiftDown);
        } else if (act == KeyEvent.TYPE) {
            UIComponent f = focusManager.getFocused();
            if (f != null) {
                f.onEvent(UIEvent.key(UIEvent.Type.KEY_TYPED, e.getKey(), e.getKeyCode()), designMouseX, designMouseY);
            }
        } else if (act == KeyEvent.RELEASE) {
            int kc = e.getKeyCode();
            if (kc == heldKeyCode) {
                heldKeyCode = -1;
                heldTime = 0;
                keyRepeatAccumulator = 0;
            }
            UIComponent f = focusManager.getFocused();
            if (f != null) {
                f.onEvent(UIEvent.key(UIEvent.Type.KEY_RELEASED, e.getKey(), kc), designMouseX, designMouseY);
            }
        }
    }

    /** Core key-press handling used for both initial press and auto-repeat. */
    private void dispatchKeyPress(char keyChar, int keyCode, boolean shiftDown) {
        // Deduplicate duplicate KEY_PRESSED events from any source (AWT duplicate, AsyncInput overlap, etc.)
        long now = System.currentTimeMillis();
        if (keyCode == lastDispatchKeyCode && now - lastDispatchTime < DISPATCH_DEDUP_MS) {
            return;
        }
        lastDispatchKeyCode = keyCode;
        lastDispatchTime = now;

        // During gameplay, navigation keys control the game (camera scroll) not UI focus
        if (gameInputActive) {
            if (keyCode == PApplet.TAB
                    || keyCode == java.awt.event.KeyEvent.VK_UP
                    || keyCode == java.awt.event.KeyEvent.VK_DOWN
                    || keyCode == java.awt.event.KeyEvent.VK_LEFT
                    || keyCode == java.awt.event.KeyEvent.VK_RIGHT) {
                return;
            }
        }

        UIComponent f = focusManager.getFocused();
        if (keyCode == PApplet.TAB) {
            if (shiftDown) {
                focusManager.focusPrevious(root);
            } else {
                focusManager.focusNext(root);
            }
            focusRingVisible = true;
            return;
        }
        // Directional navigation
        int dir = -1;
        if (keyCode == java.awt.event.KeyEvent.VK_UP) dir = 0;
        else if (keyCode == java.awt.event.KeyEvent.VK_DOWN) dir = 1;
        else if (keyCode == java.awt.event.KeyEvent.VK_LEFT) dir = 2;
        else if (keyCode == java.awt.event.KeyEvent.VK_RIGHT) dir = 3;
        if (dir >= 0) {
            // Let focused component consume arrow keys first (e.g. Slider uses LEFT/RIGHT)
            if (f != null && f.onEvent(UIEvent.key(UIEvent.Type.KEY_PRESSED, keyChar, keyCode), designMouseX, designMouseY)) {
                return;
            }
            focusManager.focusDirection(root, dir);
            focusRingVisible = true;
            return;
        }
        if (f != null) {
            f.onEvent(UIEvent.key(UIEvent.Type.KEY_PRESSED, keyChar, keyCode), designMouseX, designMouseY);
        }
    }

    private void dispatchBubble(UIComponent start, UIEvent ev, float mx, float my) {
        UIComponent c = start;
        while (c != null) {
            if (c.onEvent(ev, mx, my)) {
                break;
            }
            c = c.getParent();
        }
    }

    private boolean isInHierarchy(UIComponent c, Container root) {
        while (c != null) {
            if (c == root) return true;
            Container parent = c.getParent();
            if (parent == null) return false;
            c = parent;
        }
        return false;
    }
}
