package shenyf.p5engine.audio;

import kuusisto.tinysound.Music;

/**
 * Wraps a TinySound Music object for background music playback.
 */
public class TinyMusicClip implements IAudioClip {
    private final Music music;
    private float baseVolume = 1.0f;
    private float groupVolume = 1.0f;
    private boolean looping = false;

    public TinyMusicClip(Music music) {
        this.music = music;
    }

    @Override
    public void play() {
        applyVolume();
        music.play(looping);
    }

    public void loop() {
        this.looping = true;
        applyVolume();
        music.play(true);
    }

    @Override
    public void stop() {
        music.stop();
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
