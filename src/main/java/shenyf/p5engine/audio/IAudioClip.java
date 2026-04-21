package shenyf.p5engine.audio;

/**
 * Abstraction over audio playback backends.
 * Allows swapping TinySound for Processing Sound / Minim / Java Sound in the future.
 */
public interface IAudioClip {
    void play();
    void stop();
    boolean isPlaying();
    void volume(float v);
    void pan(float p);
}
