package shenyf.p5engine.audio;

import kuusisto.tinysound.TinySound;
import shenyf.p5engine.resource.ppak.PPak;
import shenyf.p5engine.util.Logger;

import java.io.File;
import java.util.HashMap;
import java.util.Map;

/**
 * Central audio hub. Manages TinySound lifecycle, audio groups, and resource loading.
 *
 * <p>Usage:
 * <pre>
 *   engine.getAudio().playOneShot("sfx/hit.wav", "sfx");
 *   engine.getAudio().loadMusic("music/bgm.wav").loop();
 * </pre>
 */
public class AudioManager {

    private float masterVolume = 1.0f;
    private final Map<String, AudioGroup> groups = new HashMap<>();

    public AudioManager() {
        // Default groups
        groups.put("bgm", new AudioGroup("bgm"));
        groups.put("sfx", new AudioGroup("sfx"));
        groups.put("ui", new AudioGroup("ui"));
    }

    /** Initialize TinySound. Must be called before any audio operations. */
    public void init() {
        if (!TinySound.isInitialized()) {
            TinySound.init();
            Logger.info("Audio: TinySound initialized");
        }
    }

    /** Shutdown TinySound and release all audio resources. */
    public void shutdown() {
        if (TinySound.isInitialized()) {
            TinySound.shutdown();
            Logger.info("Audio: TinySound shutdown");
        }
    }

    // ===== Loaders =====

    /** Load a music clip from the sketch's data/ folder. */
    public TinyMusicClip loadMusic(String path) {
        return loadMusic(path, true); // streaming by default for BGM
    }

    /** Load a music clip from the sketch's data/ folder. */
    public TinyMusicClip loadMusic(String path, boolean stream) {
        File file = new File(path);
        if (!file.exists()) {
            Logger.warn("Audio: music file not found: " + path);
            return null;
        }
        kuusisto.tinysound.Music music = TinySound.loadMusic(file, stream);
        if (music == null) {
            Logger.warn("Audio: failed to load music: " + path);
            return null;
        }
        TinyMusicClip clip = new TinyMusicClip(music);
        clip.setGroupVolume(getGroup("bgm").getVolume());
        return clip;
    }

    /** Load a music clip from a PPAK resource. */
    public TinyMusicClip loadMusicFromPPak(String path) {
        return loadMusicFromPPak(path, true);
    }

    /** Load a music clip from a PPAK resource. */
    public TinyMusicClip loadMusicFromPPak(String path, boolean stream) {
        String tempPath = PPak.getInstance().audioFile(path);
        if (tempPath == null) {
            Logger.warn("Audio: PPAK music not found: " + path);
            return null;
        }
        kuusisto.tinysound.Music music = TinySound.loadMusic(new File(tempPath), stream);
        if (music == null) {
            Logger.warn("Audio: failed to load PPAK music: " + path);
            return null;
        }
        TinyMusicClip clip = new TinyMusicClip(music);
        clip.setGroupVolume(getGroup("bgm").getVolume());
        return clip;
    }

    /** Load a sound effect from the sketch's data/ folder. */
    public TinySfxClip loadSound(String path) {
        File file = new File(path);
        if (!file.exists()) {
            Logger.warn("Audio: sound file not found: " + path);
            return null;
        }
        kuusisto.tinysound.Sound sound = TinySound.loadSound(file, false);
        if (sound == null) {
            Logger.warn("Audio: failed to load sound: " + path);
            return null;
        }
        TinySfxClip clip = new TinySfxClip(sound);
        clip.setGroupVolume(getGroup("sfx").getVolume());
        return clip;
    }

    /** Load a sound effect from a PPAK resource. */
    public TinySfxClip loadSoundFromPPak(String path) {
        String tempPath = PPak.getInstance().audioFile(path);
        if (tempPath == null) {
            Logger.warn("Audio: PPAK sound not found: " + path);
            return null;
        }
        kuusisto.tinysound.Sound sound = TinySound.loadSound(new File(tempPath), false);
        if (sound == null) {
            Logger.warn("Audio: failed to load PPAK sound: " + path);
            return null;
        }
        TinySfxClip clip = new TinySfxClip(sound);
        clip.setGroupVolume(getGroup("sfx").getVolume());
        return clip;
    }

    // ===== Fire-and-forget shortcuts =====

    /** Play a one-shot sound effect from data/ folder. */
    public void playOneShot(String path, String groupName) {
        TinySfxClip clip = loadSound(path);
        if (clip != null) {
            AudioGroup g = getGroup(groupName);
            clip.setGroupVolume(g != null ? g.getVolume() : 1.0f);
            clip.play();
        }
    }

    /** Play a one-shot sound effect from a PPAK resource. */
    public void playOneShotFromPPak(String path, String groupName) {
        TinySfxClip clip = loadSoundFromPPak(path);
        if (clip != null) {
            AudioGroup g = getGroup(groupName);
            clip.setGroupVolume(g != null ? g.getVolume() : 1.0f);
            clip.play();
        }
    }

    // ===== Volume / Groups =====

    public void setMasterVolume(float v) {
        this.masterVolume = Math.max(0.0f, v);
        TinySound.setGlobalVolume(masterVolume);
    }

    public float getMasterVolume() {
        return masterVolume;
    }

    public AudioGroup getGroup(String name) {
        return groups.get(name);
    }

    public void addGroup(String name, float volume) {
        AudioGroup g = new AudioGroup(name);
        g.setVolume(volume);
        groups.put(name, g);
    }

    // ===== Global control =====

    public void stopAll() {
        TinySound.shutdown();
        TinySound.init();
        TinySound.setGlobalVolume(masterVolume);
    }

    public void pauseAll() {
        // TinySound doesn't have a global pause; individual clips can be paused
    }

    public void resumeAll() {
        // TinySound doesn't have a global resume
    }
}
