/**
 * Sound & BGM manager (Observer pattern).
 * Only one BGM stream plays at a time. Playlist advances via onComplete callback.
 * BGM clips are loaded asynchronously in background threads to avoid frame drops.
 */

import kuusisto.tinysound.Music;
import kuusisto.tinysound.TinySound;

static final class TdSound {

    static final String SFX_CLICK = "sounds/synthetic-select.wav";
    static final String SFX_SHOT  = "sounds/synthetic-spike.wav";
    static final String SFX_LASER = "sounds/resonant-twang.wav";
    static final String SFX_PLACE = "sounds/percussive-knock.wav";
    static final String SFX_DEATH = "sounds/synthetic-gib.wav";
    static final String SFX_TOWER_SELECT = "sounds/keypunch.wav";
    static final String BGM_MENU  = "music/TopGun.ogg";

    static TinyMusicClip currentBgm = null;
    static String currentBgmPath = null;
    static String[] gameTracks = null;
    static int currentTrackIndex = -1;
    static java.util.HashMap<String, TinyMusicClip> bgmCache = new java.util.HashMap<>();

    // Background loading
    static class LoadResult {
        String path;
        Music music;
        boolean loop;
        LoadResult(String path, Music music, boolean loop) {
            this.path = path;
            this.music = music;
            this.loop = loop;
        }
    }
    static java.util.concurrent.ConcurrentLinkedQueue<LoadResult> bgmLoadQueue = new java.util.concurrent.ConcurrentLinkedQueue<>();
    static java.util.HashSet<String> bgmLoading = new java.util.HashSet<>();

    /** Scan music/ folder for Track*.ogg files (call once in setup). */
    static void initTracks(PApplet app) {
        if (gameTracks != null) return;
        java.io.File dir = new java.io.File(app.sketchPath("music"));
        java.util.ArrayList<String> list = new java.util.ArrayList<>();
        if (dir.exists() && dir.isDirectory()) {
            java.io.File[] files = dir.listFiles();
            if (files != null) {
                for (java.io.File f : files) {
                    String name = f.getName();
                    if (name.startsWith("Track") && name.endsWith(".ogg")) {
                        list.add("music/" + name);
                    }
                }
            }
        }
        java.util.Collections.sort(list);
        gameTracks = list.toArray(new String[0]);
    }

    /** Stop current BGM (do NOT unload — clips are cached for reuse). */
    static void stopBgm() {
        if (currentBgm != null) {
            currentBgm.stop();
            currentBgm = null;
        }
        currentBgmPath = null;
    }

    /** Menu BGM: TopGun.ogg, loop forever. */
    static void playBgmMenu() {
        if (BGM_MENU.equals(currentBgmPath) && currentBgm != null && currentBgm.isPlaying()) {
            return; // already playing menu BGM
        }
        stopBgm();
        currentBgmPath = BGM_MENU;
        playFromCacheOrLoad(BGM_MENU, true);
    }

    /** Game BGM: pick a random Track*.ogg, auto-advance on completion. */
    static void playBgmGame() {
        stopBgm();
        if (gameTracks == null || gameTracks.length == 0) return;
        currentTrackIndex = (int)(Math.random() * gameTracks.length);
        playTrack(currentTrackIndex);
    }

    static void playTrack(int index) {
        if (gameTracks == null || gameTracks.length == 0) return;
        currentTrackIndex = index % gameTracks.length;
        currentBgmPath = gameTracks[currentTrackIndex];
        playFromCacheOrLoad(currentBgmPath, false);
    }

    static void playFromCacheOrLoad(String path, boolean loop) {
        TinyMusicClip cached = bgmCache.get(path);
        if (cached != null) {
            currentBgm = cached;
            if (loop) {
                cached.loop();
            } else {
                cached.setOnComplete(() -> {
                    stopBgm();
                    playTrack(currentTrackIndex + 1);
                });
                cached.play();
            }
            return;
        }

        // Not cached — start background loading if not already loading
        synchronized (bgmLoading) {
            if (bgmLoading.contains(path)) return;
            bgmLoading.add(path);
        }

        new Thread(() -> {
            try {
                TowerDefenseMin2 app = TowerDefenseMin2.inst;
                String resolved = app.sketchPath(path);
                java.io.File file = new java.io.File(resolved);
                Music music = TinySound.loadMusic(file, true);
                if (music != null) {
                    bgmLoadQueue.offer(new LoadResult(path, music, loop));
                }
            } catch (Exception e) {
                e.printStackTrace();
            } finally {
                synchronized (bgmLoading) {
                    bgmLoading.remove(path);
                }
            }
        }).start();
    }

    /** Call every frame from main thread to process loaded BGM. */
    static void update() {
        LoadResult result;
        while ((result = bgmLoadQueue.poll()) != null) {
            if (result.music == null) continue;
            // Wrap and register on main thread
            TinyMusicClip clip = new TinyMusicClip(result.music);
            clip.setGroupVolume(P5Engine.getInstance().getAudio().getGroup("bgm").getVolume());
            P5Engine.getInstance().getAudio().registerMusic(clip);
            bgmCache.put(result.path, clip);

            // If this loaded BGM is the one currently requested, play it
            if (currentBgmPath != null && currentBgmPath.equals(result.path)) {
                currentBgm = clip;
                if (result.loop) {
                    clip.loop();
                } else {
                    clip.setOnComplete(() -> {
                        stopBgm();
                        playTrack(currentTrackIndex + 1);
                    });
                    clip.play();
                }
            }
        }
    }

    static void playClick() { TdAssets.playSfx(SFX_CLICK); }
    static void playShot()  { TdAssets.playSfx(SFX_SHOT); }
    static void playPlace() { TdAssets.playSfx(SFX_PLACE); }
}
