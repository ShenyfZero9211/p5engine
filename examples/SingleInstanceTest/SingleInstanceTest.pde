import shenyf.p5engine.core.*;
import shenyf.p5engine.config.SketchConfig;
import processing.core.PSurface;
import java.awt.Frame;

P5Engine engine;
SketchConfig sketchConfig;

public void setup() {
    size(800, 600);

    engine = P5Engine.create(this);
    engine.setApplicationTitle("SingleInstanceTest");
    engine.setSketchVersion("0.0.1");
    sketchConfig = engine.getSketchConfig();

    println("=== Single Instance Test ===");
    println("Config file: " + sketchConfig.getConfigFilePath());
    println("");
    println("Single instance mode: " + sketchConfig.isSingleInstance());
    println("");
    println("Press 1 to enable single instance mode");
    println("Press 0 to disable single instance mode");
    println("Press S to save current position");
    println("Press L to load saved position");
    println("Press C to center window");
}

public void draw() {
    background(50);

    engine.update();

    fill(255);
    textAlign(CENTER);
    text("Single Instance Test", width / 2, 30);
    text("Press 1 to enable, 0 to disable single instance", width / 2, 60);
    text("Press S to Save, L to Load, C to Center", width / 2, 90);
    text("FPS: " + (int) engine.getGameTime().getFrameRate(), width / 2, 120);

    fill(0, 255, 0);
    if (sketchConfig.isSingleInstance()) {
        text("SINGLE INSTANCE MODE: ON", width / 2, 160);
    } else {
        text("SINGLE INSTANCE MODE: OFF", width / 2, 160);
    }

    fill(255);
    int[] pos = sketchConfig.getWindowPosition();
    if (pos != null) {
        text("Saved position: x=" + pos[0] + ", y=" + pos[1], width / 2, 200);
    } else {
        text("No saved position", width / 2, 200);
    }
}

public void keyPressed() {
    if (key == '1') {
        sketchConfig.setSingleInstance(true);
        println("Single instance mode ENABLED (requires restart to take effect)");
    }
    if (key == '0') {
        sketchConfig.setSingleInstance(false);
        println("Single instance mode DISABLED");
    }
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