import shenyf.p5engine.config.*;
import shenyf.p5engine.config.annotation.*;
import shenyf.p5engine.config.env.EnvironmentDetector;
import shenyf.p5engine.core.*;
import shenyf.p5engine.scene.*;
import shenyf.p5engine.math.*;

P5Engine engine;

public void setup() {
    size(800, 600);

    engine = P5Engine.create(this);

    ConfigManager cm = ConfigManager.getInstance();

    cm.addSource(new FileConfigSource("test", "E:/projects/opencode/processing/p5engine/examples/ConfigTest/test.config", 50));

    println("=== Config Test ===");
    println("Platform: " + EnvironmentDetector.getPlatformName());
    println("Java Version: " + EnvironmentDetector.getJavaVersion());
    println("");
    println("=== Loaded Config ===");
    println("engine.name: " + cm.getString("p5engine.name"));
    println("engine.version: " + cm.getString("p5engine.version"));
    println("engine.debug: " + cm.getBoolean("p5engine.debug", false));
    println("");
    println("window.width: " + cm.getInt("window.width", 800));
    println("window.height: " + cm.getInt("window.height", 600));
    println("window.title: " + cm.getString("window.title", "p5engine"));
    println("");
    println("cache.memory_mb: " + cm.getInt("cache.memory_mb", 512));
    println("cache.enabled: " + cm.getBoolean("cache.enabled", false));
    println("");
    println("script.lua_path: " + cm.getString("script.lua_path"));
    println("script.hot_reload: " + cm.getBoolean("script.hot_reload", false));

    println("");
    println("=== System Info ===");
    println(EnvironmentDetector.getSystemInfo());
}

public void draw() {
    background(50);

    engine.update();

    fill(255);
    textAlign(CENTER);
    text("Config Test - Press R to reload config", width / 2, 30);

    ConfigManager cm = ConfigManager.getInstance();
    text("window.width: " + cm.getInt("window.width", 800), width / 2, 60);
    text("FPS: " + (int) engine.getGameTime().getFrameRate(), width / 2, 90);
}

public void keyPressed() {
    if (key == 'r' || key == 'R') {
        ConfigManager.getInstance().reload();
        println("Config reloaded!");
    }
}
