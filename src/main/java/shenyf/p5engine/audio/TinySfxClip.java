package shenyf.p5engine.audio;

import kuusisto.tinysound.Sound;

/**
 * Wraps a TinySound Sound object for one-shot sound effects.
 */
public class TinySfxClip implements IAudioClip {
    private final Sound sound;
    private float baseVolume = 1.0f;
    private float groupVolume = 1.0f;

    public TinySfxClip(Sound sound) {
        this.sound = sound;
    }

    @Override
    public void play() {
        float vol = baseVolume * groupVolume;
        sound.play(vol, 0.0);
    }

    public void play(float volume, float pan) {
        float vol = volume * groupVolume;
        sound.play(vol, pan);
    }

    @Override
    public void stop() {
        sound.stop();
    }

    @Override
    public boolean isPlaying() {
        // TinySound Sound doesn't expose per-instance playing state
        return false;
    }

    @Override
    public void volume(float v) {
        this.baseVolume = v;
    }

    @Override
    public void pan(float p) {
        // Pan is set per-play for Sound, not globally
    }

    public void setGroupVolume(float gv) {
        this.groupVolume = gv;
    }

    public void unload() {
        if (sound != null) {
            sound.unload();
        }
    }

    public Sound getSound() {
        return sound;
    }
}
