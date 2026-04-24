package shenyf.p5engine.audio;

import kuusisto.tinysound.Music;
import shenyf.p5engine.util.Logger;

/**
 * Wraps a TinySound Music object for background music playback.
 */
public class TinyMusicClip implements IAudioClip {
    private final Music music;
    private float baseVolume = 1.0f;
    private float groupVolume = 1.0f;
    private boolean looping = false;
    private boolean wasPlaying = false;
    private Runnable onComplete;

    public TinyMusicClip(Music music) {
        this.music = music;
    }

    public void setOnComplete(Runnable callback) {
        this.onComplete = callback;
    }

    /** Call every frame by AudioManager to detect playback completion. */
    public void update() {
        boolean playing = isPlaying();
        if (wasPlaying && !playing && onComplete != null) {
            onComplete.run();
        }
        wasPlaying = playing;
    }

    @Override
    public void play() {
        Logger.info("Audio", "TinyMusicClip.play() looping=" + looping);
        applyVolume();
        wasPlaying = false;
        music.play(looping);
    }

    public void loop() {
        Logger.info("Audio", "TinyMusicClip.loop()");
        this.looping = true;
        applyVolume();
        wasPlaying = false;
        music.play(true);
    }

    @Override
    public void stop() {
        music.stop();
        wasPlaying = false;
    }

    public void pause() {
        music.pause();
    }

    public void resume() {
        music.resume();
    }

    @Override
    public boolean isPlaying() {
        return music.playing();
    }

    @Override
    public void volume(float v) {
        this.baseVolume = v;
        applyVolume();
    }

    @Override
    public void pan(float p) {
        music.setPan(p);
    }

    public void setGroupVolume(float gv) {
        this.groupVolume = gv;
        applyVolume();
    }

    private void applyVolume() {
        if (music != null) {
            music.setVolume(baseVolume * groupVolume);
        }
    }

    public void unload() {
        if (music != null) {
            music.unload();
        }
    }

    public Music getMusic() {
        return music;
    }
}
