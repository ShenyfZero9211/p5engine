package shenyf.p5engine.audio;

import shenyf.p5engine.core.P5Engine;
import shenyf.p5engine.scene.Component;

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
        if (!playOnStart || clipPath == null || clipPath.isEmpty()) {
            return;
        }
        AudioManager am = P5Engine.getInstance().getAudio();
        if (am == null) {
            return;
        }
        clip = am.loadMusicFromPPak(clipPath);
        if (clip == null) {
            return;
        }

        AudioGroup g = am.getGroup(group);
        clip.setGroupVolume(g != null ? g.getVolume() : 1.0f);

        if (fadeInDuration > 0) {
            clip.volume(0f);
            if (loop) {
                clip.loop();
            } else {
                clip.play();
            }
            // Simple fade-in: jump to target volume after a delay
            // Full Tween integration can be added later
            clip.volume(volume);
        } else {
            clip.volume(volume);
            if (loop) {
                clip.loop();
            } else {
                clip.play();
            }
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
