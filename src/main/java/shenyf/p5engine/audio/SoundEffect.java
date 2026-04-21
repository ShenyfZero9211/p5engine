package shenyf.p5engine.audio;

import shenyf.p5engine.core.P5Engine;
import shenyf.p5engine.scene.Component;

/**
 * Component that plays a one-shot sound effect.
 * Can be attached to any GameObject (e.g., a paddle that makes a sound on hit).
 *
 * <p>Usage:
 * <pre>
 *   SoundEffect se = new SoundEffect("sfx/hit.wav");
 *   se.volume = 0.8f;
 *   paddle.addComponent(se);
 *   se.play(); // manual trigger
 * </pre>
 */
public class SoundEffect extends Component {

    public String clipPath;
    public boolean playOnStart = false;
    public String group = "sfx";
    public float volume = 1.0f;
    public float pan = 0.0f;

    public SoundEffect() {
    }

    public SoundEffect(String clipPath) {
        this.clipPath = clipPath;
    }

    @Override
    public void start() {
        if (playOnStart) {
            play();
        }
    }

    /** Play the sound effect once. */
    public void play() {
        if (clipPath == null || clipPath.isEmpty()) {
            return;
        }
        AudioManager am = P5Engine.getInstance().getAudio();
        if (am == null) {
            return;
        }
        TinySfxClip clip = am.loadSoundFromPPak(clipPath);
        if (clip != null) {
            AudioGroup g = am.getGroup(group);
            clip.setGroupVolume(g != null ? g.getVolume() : 1.0f);
            clip.play(volume, pan);
        }
    }
}
