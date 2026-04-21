import shenyf.p5engine.core.*;
import shenyf.p5engine.audio.*;

P5Engine engine;

void setup() {
    size(800, 600);
    engine = P5Engine.create(this, P5Config.defaults().logToFile(true));

    // Play background music (loops automatically)
    BackgroundMusic bgm = new BackgroundMusic("data/bgm.wav");
    bgm.loop = true;
    bgm.fadeInDuration = 1.5f;
    engine.getActiveScene().addComponent(bgm);

    println("AudioDemo ready. Press SPACE to play SFX.");
}

void draw() {
    engine.update();
    engine.render(#1a1a2e);

    fill(255);
    textSize(24);
    text("AudioDemo v0.3.0", 20, 40);
    textSize(16);
    text("SPACE - play beep SFX", 20, 80);
    text("UP/DOWN - master volume", 20, 105);
    text("1/2/3 - switch BGM/SFX/UI group volume", 20, 130);
    text("M - mute/unmute", 20, 155);
    text("Master: " + nf(engine.getAudio().getMasterVolume(), 1, 2), 20, 190);
}

void keyPressed() {
    AudioManager audio = engine.getAudio();

    if (key == ' ') {
        // Fire-and-forget SFX
        audio.playOneShot("data/beep.wav", "sfx");
    }
    else if (keyCode == UP) {
        audio.setMasterVolume(audio.getMasterVolume() + 0.1f);
    }
    else if (keyCode == DOWN) {
        audio.setMasterVolume(audio.getMasterVolume() - 0.1f);
    }
    else if (key == 'm' || key == 'M') {
        audio.setMasterVolume(audio.getMasterVolume() > 0 ? 0 : 1.0f);
    }
    else if (key == '1') {
        audio.getGroup("bgm").setVolume(audio.getGroup("bgm").getVolume() + 0.1f);
        println("BGM group volume: " + audio.getGroup("bgm").getVolume());
    }
    else if (key == '2') {
        audio.getGroup("sfx").setVolume(audio.getGroup("sfx").getVolume() + 0.1f);
        println("SFX group volume: " + audio.getGroup("sfx").getVolume());
    }
    else if (key == '3') {
        audio.getGroup("ui").setVolume(audio.getGroup("ui").getVolume() + 0.1f);
        println("UI group volume: " + audio.getGroup("ui").getVolume());
    }
}

void stop() {
    if (engine != null) {
        engine.destroy();
    }
}
