import shenyf.p5engine.config.*;
import shenyf.p5engine.config.annotation.*;
import shenyf.p5engine.config.env.EnvironmentDetector;
import shenyf.p5engine.config.WindowConfigSource;
import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;
import processing.core.PSurface;
import java.awt.Frame;

P5Engine engine;
WindowConfigSource winConfig;

public void setup() {
    size(800, 600);

    engine = P5Engine.create(this);

    winConfig = new WindowConfigSource("window", 10);

    println("=== Window Position Test ===");
    println("Config file: " + winConfig.getConfigFile());
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

    // SmoothCanvas has getFrame() method
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

    // Fallback: nativeObj itself might be a Frame
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
            winConfig.savePosition(x, y);
            println("Saved: x=" + x + ", y=" + y);
        } else {
            println("Could not get Frame from surface");
        }
    } catch (Exception e) {
        println("Error: " + e.getClass().getSimpleName() + " " + e.getMessage());
    }
}

private void loadPosition() {
    int[] pos = winConfig.getSavedPosition();
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
            int[] center = WindowConfigSource.getCenterPosition(800, 600);
            frame.setLocation(center[0], center[1]);
            println("Centered window");
        }
    } catch (Exception e) {
        println("Error: " + e.getMessage());
    }
}
