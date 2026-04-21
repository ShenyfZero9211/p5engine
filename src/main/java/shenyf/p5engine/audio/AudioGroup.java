package shenyf.p5engine.audio;

/**
 * A named volume group (e.g., "bgm", "sfx", "ui").
 * Volume values are multiplied into each clip's base volume at play time.
 */
public class AudioGroup {
    private final String name;
    private float volume = 1.0f;

    public AudioGroup(String name) {
        this.name = name;
    }

    public String getName() {
        return name;
    }

    public float getVolume() {
        return volume;
    }

    public void setVolume(float volume) {
        this.volume = Math.max(0.0f, volume);
    }
}
