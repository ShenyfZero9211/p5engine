/**
 * Sound & BGM manager (Observer pattern).
 * Only one BGM stream plays at a time. Playlist advances via onComplete callback.
 */
static final class TdSound {

    static final String SFX_CLICK = "sounds/synthetic-select.wav";
    static final String SFX_SHOT  = "sounds/synthetic-spike.wav";
    static final String SFX_LASER = "sounds/resonant-twang.wav";
    static final String SFX_PLACE = "sounds/percussive-knock.wav";
    static final String BGM_MENU  = "music/TopGun.ogg";

    static TinyMusicClip currentBgm = null;
    static String currentBgmPath = null;
    static String[] gameTracks = null;
    static int currentTrackIndex = -1;

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

    /** Stop and unload current BGM. */
    static void stopBgm() {
        if (currentBgm != null) {
            P5Engine.getInstance().getAudio().unregisterMusic(currentBgm);
            currentBgm.stop();
            currentBgm.unload();
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
        currentBgm = P5Engine.getInstance().getAudio().loadMusic(BGM_MENU);
        if (currentBgm != null) {
            currentBgm.loop();
        }
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
        currentBgm = P5Engine.getInstance().getAudio().loadMusic(gameTracks[currentTrackIndex]);
        if (currentBgm != null) {
            // Observer: when this track finishes, play the next one
            currentBgm.setOnComplete(() -> {
                stopBgm();
                playTrack(currentTrackIndex + 1);
            });
            currentBgm.play();
        }
    }

    static void playClick() { TdAssets.playSfx(SFX_CLICK); }
    static void playShot()  { TdAssets.playSfx(SFX_SHOT); }
    static void playPlace() { TdAssets.playSfx(SFX_PLACE); }
}
