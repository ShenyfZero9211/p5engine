package shenyf.p5engine;

/**
 * Built-in game state enumeration for common game lifecycle stages.
 * P5Engine holds the current state; games read/write it via {@code getGameState()} / {@code setGameState()}.
 */
public enum GameState {
    READY,
    PLAYING,
    PAUSED,
    GAME_OVER,
    VICTORY
}
