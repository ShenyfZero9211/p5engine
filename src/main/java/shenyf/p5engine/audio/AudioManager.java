package shenyf.p5engine.audio;

import kuusisto.tinysound.TinySound;
import processing.core.PApplet;
import shenyf.p5engine.resource.ppak.PPak;
import shenyf.p5engine.util.Logger;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
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

    private final PApplet applet;
    private float masterVolume = 1.0f;
    private final Map<String, AudioGroup> groups = new HashMap<>();
    private final Map<String, TinySfxClip> sfxCache = new HashMap<>();
    private final List<TinyMusicClip> activeMusics = new ArrayList<>();

    public AudioManager(PApplet applet) {
        this.applet = applet;
        // Default groups
        groups.put("bgm", new AudioGroup("bgm"));
        groups.put("sfx", new AudioGroup("sfx"));
        groups.put("ui", new AudioGroup("ui"));
    }

    private String resolvePath(String path) {
        if (applet != null) {
            String resolved = applet.sketchPath(path);
            Logger.debug("Audio", "resolvePath: " + path + " -> " + resolved);
            return resolved;
        }
        return path;
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

    /** Load a music clip (PPAK preferred, fallback to sketch data). */
    public TinyMusicClip loadMusic(String path) {
        return loadMusic(path, true); // streaming by default for BGM
    }

    /** Load a music clip (PPAK preferred, fallback to sketch data). */
    public TinyMusicClip loadMusic(String path, boolean stream) {
        String tempPath = null;
        PPak ppak = PPak.getInstance();
        if (ppak.isReady()) {
            tempPath = ppak.audioFile(path);
        }
        if (tempPath == null) {
            tempPath = resolvePath(path);
            File file = new File(tempPath);
            Logger.info("Audio", "loadMusic: resolved=" + tempPath + " exists=" + file.exists());
            if (!file.exists()) {
                Logger.warn("Audio: music file not found: " + tempPath);
                return null;
            }
        }
        kuusisto.tinysound.Music music = TinySound.loadMusic(new File(tempPath), stream);
        if (music == null) {
            Logger.warn("Audio: failed to load music: " + tempPath);
            return null;
        }
        Logger.info("Audio", "loadMusic success: " + tempPath);
        TinyMusicClip clip = new TinyMusicClip(music);
        clip.setGroupVolume(getGroup("bgm").getVolume());
        activeMusics.add(clip);
        return clip;
    }

    /** Alias for loadMusic (backward compatibility). */
    public TinyMusicClip loadMusicFromPPak(String path) {
        return loadMusic(path, true);
    }

    /** Alias for loadMusic (backward compatibility). */
    public TinyMusicClip loadMusicFromPPak(String path, boolean stream) {
        return loadMusic(path, stream);
    }

    /** Load a sound effect (PPAK preferred, fallback to sketch data). Cached per path. */
    public TinySfxClip loadSound(String path) {
        TinySfxClip cached = sfxCache.get(path);
        if (cached != null) return cached;

        String tempPath = null;
        PPak ppak = PPak.getInstance();
        if (ppak.isReady()) {
            tempPath = ppak.audioFile(path);
        }
        if (tempPath == null) {
            tempPath = resolvePath(path);
            File file = new File(tempPath);
            Logger.info("Audio", "loadSound: resolved=" + tempPath + " exists=" + file.exists());
            if (!file.exists()) {
                Logger.warn("Audio: sound file not found: " + tempPath);
                return null;
            }
        }
        kuusisto.tinysound.Sound sound = TinySound.loadSound(new File(tempPath), false);
        if (sound == null) {
            Logger.warn("Audio: failed to load sound: " + tempPath);
            return null;
        }
        Logger.info("Audio", "loadSound success: " + tempPath);
        TinySfxClip clip = new TinySfxClip(sound);
        clip.setGroupVolume(getGroup("sfx").getVolume());
        sfxCache.put(path, clip);
        return clip;
    }

    /** Alias for loadSound (backward compatibility). */
    public TinySfxClip loadSoundFromPPak(String path) {
        return loadSound(path);
    }

    // ===== Fire-and-forget shortcuts =====

    /** Play a one-shot sound effect from data/ folder. */
    public void playOneShot(String path, String groupName) {
        // Logger.info("Audio", "playOneShot: " + path + " group=" + groupName);
        TinySfxClip clip = loadSound(path);
        if (clip != null) {
            AudioGroup g = getGroup(groupName);
            clip.setGroupVolume(g != null ? g.getVolume() : 1.0f);
            // Logger.info("Audio", "playOneShot playing: " + path);
            clip.play();
        } else {
            Logger.warn("Audio", "playOneShot failed to load: " + path);
        }
    }

    /** Alias for playOneShot (backward compatibility). */
    public void playOneShotFromPPak(String path, String groupName) {
        playOneShot(path, groupName);
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

    public void setGroupVolume(String name, float volume) {
        AudioGroup g = groups.get(name);
        if (g == null) {
            g = new AudioGroup(name);
            groups.put(name, g);
        }
        g.setVolume(volume);
    }

    public void addGroup(String name, float volume) {
        AudioGroup g = new AudioGroup(name);
        g.setVolume(volume);
        groups.put(name, g);
    }

    // ===== Global control =====

    public void update() {
        for (int i = activeMusics.size() - 1; i >= 0; i--) {
            TinyMusicClip clip = activeMusics.get(i);
            clip.update();
        }
    }

    public void registerMusic(TinyMusicClip clip) {
        activeMusics.add(clip);
    }

    public void unregisterMusic(TinyMusicClip clip) {
        activeMusics.remove(clip);
    }

    public void stopAll() {
        activeMusics.clear();
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
