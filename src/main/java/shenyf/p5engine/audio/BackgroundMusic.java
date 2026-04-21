package shenyf.p5engine.audio;

import shenyf.p5engine.core.P5Engine;
import shenyf.p5engine.scene.Component;
import shenyf.p5engine.util.Logger;

/**
 * Component that manages background music with optional fade-in.
 *
 * <p>Usage:
 * <pre>
 *   BackgroundMusic bgm = new BackgroundMusic("music/level1.wav");
 *   bgm.loop = true;
 *   bgm.fadeInDuration = 2.0f;
 *   scene.addComponent(bgm);
 * </pre>
 */
public class BackgroundMusic extends Component {

    public String clipPath;
    public boolean loop = true;
    public boolean playOnStart = true;
    public float fadeInDuration = 1.0f;
    public String group = "bgm";
    public float volume = 1.0f;

    private transient TinyMusicClip clip;

    public BackgroundMusic() {
    }

    public BackgroundMusic(String clipPath) {
        this.clipPath = clipPath;
    }

    @Override
    public void start() {
        // Lazy init in update() so caller has time to set clipPath after addComponent()
    }

    @Override
    public void update(float deltaTime) {
        if (clipPath != null && clip == null && playOnStart) {
            initClip();
        }
    }

    private void initClip() {
        Logger.info("Audio", "BackgroundMusic.initClip() clipPath=" + clipPath);
        AudioManager am = P5Engine.getInstance().getAudio();
        if (am == null) {
            Logger.warn("Audio", "BackgroundMusic.initClip() AudioManager is null");
            return;
        }
        clip = am.loadMusicFromPPak(clipPath);
        if (clip == null) {
            Logger.warn("Audio", "BackgroundMusic.initClip() loadMusicFromPPak returned null");
            return;
        }

        AudioGroup g = am.getGroup(group);
        clip.setGroupVolume(g != null ? g.getVolume() : 1.0f);

        clip.volume(volume);
        if (loop) {
            Logger.info("Audio", "BackgroundMusic.initClip() looping");
            clip.loop();
        } else {
            Logger.info("Audio", "BackgroundMusic.initClip() playing");
            clip.play();
        }
    }

    @Override
    public void onDestroy() {
        if (clip != null) {
            clip.stop();
            clip.unload();
            clip = null;
        }
    }

    public void stopMusic() {
        if (clip != null) {
            clip.stop();
        }
    }

    public void pauseMusic() {
        if (clip != null) {
            clip.pause();
        }
    }

    public void resumeMusic() {
        if (clip != null) {
            clip.resume();
        }
    }

    public boolean isPlaying() {
        return clip != null && clip.isPlaying();
    }
}
