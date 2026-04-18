import shenyf.p5engine.core.*;
import shenyf.p5engine.config.SketchConfig;
import processing.core.PSurface;
import java.awt.Frame;

P5Engine engine;
SketchConfig sketchConfig;

public void setup() {
    size(800, 600);

    engine = P5Engine.create(this);
    sketchConfig = engine.getSketchConfig();

    println("=== Window Position Test ===");
    println("Config file: " + sketchConfig.getConfigFilePath());
    println("");
    println("Current config:");
    println("  [p5engine] name=" + sketchConfig.get(SketchConfig.SECTION_P5ENGINE, SketchConfig.KEY_NAME));
    println("  [p5engine] version=" + sketchConfig.get(SketchConfig.SECTION_P5ENGINE, SketchConfig.KEY_VERSION));
    println("  [p5engine] debug=" + sketchConfig.get(SketchConfig.SECTION_P5ENGINE, SketchConfig.KEY_DEBUG));
    println("  [window] width=" + sketchConfig.getWindowWidth());
    println("  [window] height=" + sketchConfig.getWindowHeight());
    println("  [window] title=" + sketchConfig.getWindowTitle());
    println("  [cache] memory_mb=" + sketchConfig.getInt(SketchConfig.SECTION_CACHE, SketchConfig.KEY_MEMORY_MB, 0));
    println("  [cache] enabled=" + sketchConfig.getBoolean(SketchConfig.SECTION_CACHE, SketchConfig.KEY_CACHE_ENABLED, false));
    println("  [script] lua_path=" + sketchConfig.get(SketchConfig.SECTION_SCRIPT, SketchConfig.KEY_LUA_PATH));
    println("  [script] hot_reload=" + sketchConfig.getBoolean(SketchConfig.SECTION_SCRIPT, SketchConfig.KEY_HOT_RELOAD, false));
    println("");
    println("Press S to save current position");
    println("Press L to load saved position");
    println("Press C to center window");
}

public void draw() {
    background(50);

    engine.update();

    fill(255);
    textAlign(CENTER);
    text("Window Position Test", width / 2, 30);
    text("Press S to Save, L to Load, C to Center", width / 2, 60);
    text("FPS: " + (int) engine.getGameTime().getFrameRate(), width / 2, 90);

    int[] pos = sketchConfig.getWindowPosition();
    if (pos != null) {
        text("Saved position: x=" + pos[0] + ", y=" + pos[1], width / 2, 120);
    } else {
        text("No saved position", width / 2, 120);
    }
}

public void keyPressed() {
    if (key == 's' || key == 'S') {
        savePositionNow();
    }
    if (key == 'l' || key == 'L') {
        loadPosition();
    }
    if (key == 'c' || key == 'C') {
        centerWindow();
    }
}

private Frame getFrameFromSurface(PSurface surface) {
    Object nativeObj = surface.getNative();
    if (nativeObj == null) return null;

    if (nativeObj.getClass().getSimpleName().contains("SmoothCanvas")) {
        try {
            java.lang.reflect.Method method = nativeObj.getClass().getMethod("getFrame");
            Object frame = method.invoke(nativeObj);
            if (frame instanceof Frame) {
                return (Frame) frame;
            }
        } catch (Exception e) {
            println("getFrame failed: " + e.getMessage());
        }
    }

    if (nativeObj instanceof Frame) {
        return (Frame) nativeObj;
    }

    return null;
}

private void savePositionNow() {
    try {
        PSurface surface = getSurface();
        Frame frame = getFrameFromSurface(surface);

        if (frame != null) {
            java.awt.Point loc = frame.getLocationOnScreen();
            int x = loc.x;
            int y = loc.y;
            sketchConfig.saveWindowPosition(x, y);
            println("Saved: x=" + x + ", y=" + y);
        } else {
            println("Could not get Frame from surface");
        }
    } catch (Exception e) {
        println("Error: " + e.getClass().getSimpleName() + " " + e.getMessage());
    }
}

private void loadPosition() {
    int[] pos = sketchConfig.getWindowPosition();
    if (pos != null) {
        try {
            PSurface surface = getSurface();
            Frame frame = getFrameFromSurface(surface);
            if (frame != null) {
                frame.setLocation(pos[0], pos[1]);
                println("Loaded position: x=" + pos[0] + ", y=" + pos[1]);
            }
        } catch (Exception e) {
            println("Error: " + e.getMessage());
        }
    } else {
        println("No saved position found");
    }
}

private void centerWindow() {
    try {
        PSurface surface = getSurface();
        Frame frame = getFrameFromSurface(surface);
        if (frame != null) {
            int[] center = SketchConfig.getCenterPosition(800, 600);
            frame.setLocation(center[0], center[1]);
            println("Centered window");
        }
    } catch (Exception e) {
        println("Error: " + e.getMessage());
    }
}