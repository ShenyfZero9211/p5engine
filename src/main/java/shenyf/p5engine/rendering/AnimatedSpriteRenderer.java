package shenyf.p5engine.rendering;

import shenyf.p5engine.scene.Component;
import shenyf.p5engine.scene.Transform;

/**
 * A sprite renderer that plays a sequence of textures as an animation.
 */
public class AnimatedSpriteRenderer extends Component implements Renderable {
    private Texture[] frames;
    private float fps = 12f;
    private boolean loop = true;
    private boolean playing = true;
    private int currentFrame;
    private float frameTimer;
    private boolean finished;
    private float width = -1;
    private float height = -1;
    private int tintColor = -1;

    @Override
    public void update(float dt) {
        if (!playing || frames == null || frames.length == 0) {
            return;
        }

        frameTimer += dt;
        float frameDuration = 1f / fps;

        while (frameTimer >= frameDuration) {
            frameTimer -= frameDuration;
            currentFrame++;

            if (currentFrame >= frames.length) {
                if (loop) {
                    currentFrame = 0;
                } else {
                    currentFrame = frames.length - 1;
                    playing = false;
                    finished = true;
                }
            }
        }
    }

    @Override
    public void render(IRenderer renderer) {
        if (frames == null || frames.length == 0 || !enabled) {
            return;
        }

        Texture tex = frames[currentFrame];
        if (tex == null) return;

        Transform transform = getTransform();
        float w = width > 0 ? width : tex.getWidth();
        float h = height > 0 ? height : tex.getHeight();

        renderer.setTransform(transform);
        if (tintColor != -1) {
            renderer.setColor(tintColor);
        }
        tex.draw(renderer, 0, 0, w, h);
        renderer.resetTransform();
    }

    public void setFrames(Texture[] frames) {
        this.frames = frames;
        this.currentFrame = 0;
        this.frameTimer = 0;
        this.finished = false;
        this.playing = true;
    }

    public Texture[] getFrames() {
        return frames;
    }

    public void setFps(float fps) {
        this.fps = fps;
    }

    public float getFps() {
        return fps;
    }

    public void setLoop(boolean loop) {
        this.loop = loop;
    }

    public boolean isLoop() {
        return loop;
    }

    public void play() {
        this.playing = true;
        if (finished) {
            finished = false;
            currentFrame = 0;
            frameTimer = 0;
        }
    }

    public void pause() {
        this.playing = false;
    }

    public void stop() {
        this.playing = false;
        this.currentFrame = 0;
        this.frameTimer = 0;
        this.finished = false;
    }

    public boolean isPlaying() {
        return playing;
    }

    public boolean isFinished() {
        return finished;
    }

    public void setWidth(float width) {
        this.width = width;
    }

    public float getWidth() {
        return width;
    }

    public void setHeight(float height) {
        this.height = height;
    }

    public float getHeight() {
        return height;
    }

    public void setTintColor(int color) {
        this.tintColor = color;
    }

    public int getTintColor() {
        return tintColor;
    }
}
