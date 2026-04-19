package shenyf.p5engine.ui;

import processing.core.PApplet;
import processing.event.KeyEvent;
import processing.event.MouseEvent;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.function.Supplier;

public final class UIManager {

    private static UIManager paintingUi;
    private static UIManager lastInstance;

    public static boolean isPaintingContext(UIComponent c) {
        return paintingUi != null && paintingUi.focusManager.getFocused() == c;
    }

    public static PApplet getActiveApplet() {
        return lastInstance != null ? lastInstance.applet : null;
    }

    private final PApplet applet;
    private final Panel root;
    private Theme theme = new DefaultTheme();
    private final FocusManager focusManager = new FocusManager();
    private final DragManager dragManager = new DragManager();
    private final Map<String, UIComponent> pool = new HashMap<>();
    private final Set<String> frameSeen = new HashSet<>();
    private boolean inFrame;
    private boolean attached;
    private UIComponent pressedTarget;

    public UIManager(PApplet applet) {
        this.applet = applet;
        this.root = new Panel("ui_root");
        this.root.setLayoutManager(null);
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

    public Panel getRoot() {
        return root;
    }

    public void update(float dt) {
        root.setBounds(0, 0, applet.width, applet.height);
        if (root.isLayoutDirty()) {
            root.measure(applet);
            root.layout(applet);
        }
        root.update(applet, dt);
    }

    public void render() {
        paintingUi = this;
        try {
            root.paint(applet, theme);
        } finally {
            paintingUi = null;
        }
    }

    public void mouseEvent(MouseEvent e) {
        int act = e.getAction();
        float mx = e.getX();
        float my = e.getY();
        UIComponent hit = root.hitTest(mx, my);

        if (act == MouseEvent.WHEEL) {
            float delta = e.getCount();
            dispatchBubble(hit, UIEvent.wheel(mx, my, delta), mx, my);
            return;
        }

        if (act == MouseEvent.PRESS) {
            UIComponent fhit = hit;
            while (fhit != null && !fhit.isFocusable()) {
                fhit = fhit.getParent();
            }
            focusManager.setFocused(fhit);

            if (hit instanceof Window) {
                Window w = (Window) hit;
                if (w.isTitleBarHit(mx, my) && e.getButton() == PApplet.LEFT) {
                    dragManager.beginDrag(w, mx, my);
                }
            }
            pressedTarget = hit;
            dispatchBubble(hit, UIEvent.mouse(UIEvent.Type.MOUSE_PRESSED, mx, my, e.getButton()), mx, my);
            return;
        }

        if (act == MouseEvent.DRAG) {
            if (dragManager.isDragging()) {
                dragManager.updateDrag(mx, my);
            }
            if (pressedTarget != null) {
                pressedTarget.onEvent(UIEvent.mouse(UIEvent.Type.MOUSE_DRAGGED, mx, my, e.getButton()), mx, my);
            }
            return;
        }

        if (act == MouseEvent.RELEASE) {
            if (dragManager.isDragging() && e.getButton() == PApplet.LEFT) {
                dragManager.endDrag();
            }
            dispatchBubble(pressedTarget, UIEvent.mouse(UIEvent.Type.MOUSE_RELEASED, mx, my, e.getButton()), mx, my);
            pressedTarget = null;
        }
    }

    public void keyEvent(KeyEvent e) {
        int act = e.getAction();
        UIComponent f = focusManager.getFocused();
        if (act == KeyEvent.PRESS) {
            int kc = e.getKeyCode();
            if (kc == PApplet.TAB) {
                if (e.isShiftDown()) {
                    focusManager.focusPrevious(root);
                } else {
                    focusManager.focusNext(root);
                }
                return;
            }
            if (f != null) {
                f.onEvent(UIEvent.key(UIEvent.Type.KEY_PRESSED, e.getKey(), kc), applet.mouseX, applet.mouseY);
            }
        } else if (act == KeyEvent.TYPE) {
            if (f != null) {
                f.onEvent(UIEvent.key(UIEvent.Type.KEY_TYPED, e.getKey(), e.getKeyCode()), applet.mouseX, applet.mouseY);
            }
        } else if (act == KeyEvent.RELEASE) {
            if (f != null) {
                f.onEvent(UIEvent.key(UIEvent.Type.KEY_RELEASED, e.getKey(), e.getKeyCode()), applet.mouseX, applet.mouseY);
            }
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
}
