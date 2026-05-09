package shenyf.p5engine.intro;

import processing.core.PApplet;

/**
 * An intro segment that shows one or more lines of text with a
 * per-character fade-in and fade-out effect.
 * <p>
 * Each character fades in individually; once the whole line is fully visible
 * it holds, then each character fades out individually in the same order.
 * While the first line is fading out, the next line begins its own per-character
 * reveal, creating an overlapping cinematic feel.
 */
public class FadeTextSegment implements IntroSegment {

    private final String[] lines;
    private final float charFadeInDuration;
    private final float charGap;
    private final float holdDuration;
    private final float charFadeOutDuration;
    private final float delay;
    private final float postDelay;
    private final int textColor;
    private final int bgColor;
    private final float textSize;
    private final float lineSpacing;

    private float[] lineStartTimes;
    private float totalDuration;

    private float elapsed = 0;
    private boolean active = false;
    private boolean skipped = false;

    // Cached character measurements — only recalculated when text size or window size changes
    private float lastMeasuredTextSize = -1f;
    private int lastMeasuredWidth = -1;
    private int lastMeasuredHeight = -1;
    private float[][] cachedCharCenterX;

    public FadeTextSegment(String text, float charFadeIn, float charGap, float hold, float fadeOut) {
        this(new String[]{text}, charFadeIn, charGap, hold, fadeOut);
    }

    public FadeTextSegment(String[] lines, float charFadeIn, float charGap,
                           float holdDuration, float fadeOutDuration) {
        this(lines, charFadeIn, charGap, holdDuration, fadeOutDuration, 0f, 0f,
             0xFFFFFFFF, 0xFF000000, 48, 1.6f);
    }

    public FadeTextSegment(String[] lines, float charFadeIn, float charGap,
                           float holdDuration, float fadeOutDuration,
                           int textColor, int bgColor, float textSize, float lineSpacing) {
        this(lines, charFadeIn, charGap, holdDuration, fadeOutDuration, 0f, 0f,
             textColor, bgColor, textSize, lineSpacing);
    }

    public FadeTextSegment(String[] lines, float charFadeIn, float charGap,
                           float holdDuration, float fadeOutDuration, float delay,
                           int textColor, int bgColor, float textSize, float lineSpacing) {
        this(lines, charFadeIn, charGap, holdDuration, fadeOutDuration, delay, 0f,
             textColor, bgColor, textSize, lineSpacing);
    }

    public FadeTextSegment(String[] lines, float charFadeIn, float charGap,
                           float holdDuration, float fadeOutDuration, float delay, float postDelay,
                           int textColor, int bgColor, float textSize, float lineSpacing) {
        this.lines = lines != null ? lines : new String[0];
        this.charFadeInDuration = Math.max(0.01f, charFadeIn);
        this.charGap = Math.max(0, charGap);
        this.holdDuration = Math.max(0, holdDuration);
        this.charFadeOutDuration = Math.max(0.01f, fadeOutDuration);
        this.delay = Math.max(0, delay);
        this.postDelay = Math.max(0, postDelay);
        this.textColor = textColor;
        this.bgColor = bgColor;
        this.textSize = textSize;
        this.lineSpacing = lineSpacing;
        this.cachedCharCenterX = new float[this.lines.length][];
        computeTimings();
    }

    private void computeTimings() {
        lineStartTimes = new float[lines.length];
        if (lines.length == 0) {
            totalDuration = 0;
            return;
        }
        lineStartTimes[0] = 0;
        for (int i = 1; i < lines.length; i++) {
            int prevLastIdx = Math.max(0, lines[i - 1].length() - 1);
            float prevFadeInComplete = prevLastIdx * charGap + charFadeInDuration;
            lineStartTimes[i] = lineStartTimes[i - 1] + prevFadeInComplete + holdDuration;
        }
        int lastLastIdx = Math.max(0, lines[lines.length - 1].length() - 1);
        float lastFadeInComplete = lastLastIdx * charGap + charFadeInDuration;
        float lastFadeOutStart = lastFadeInComplete + holdDuration + lastLastIdx * charGap;
        totalDuration = lineStartTimes[lines.length - 1] + lastFadeOutStart + charFadeOutDuration;
    }

    @Override
    public void onStart() {
        elapsed = 0;
        active = true;
        skipped = false;
    }

    @Override
    public boolean update(float dt) {
        if (!active || skipped) return true;
        elapsed += dt;
        return elapsed >= delay + totalDuration + postDelay;
    }

    @Override
    public void render(PApplet g) {
        if (!active) return;

        g.noStroke();
        g.fill(bgColor);
        g.rect(0, 0, g.width, g.height);

        // During delay or post-delay period, show only black screen
        if (elapsed < delay) return;
        float effectiveTime = elapsed - delay;
        if (effectiveTime > totalDuration) return;
        float cx = g.width * 0.5f;
        float cy = g.height * 0.5f;

        // Adaptive text size: textSize is the design-resolution size (1280x720).
        // Scale it by the same FIT factor used for the UI layer so text looks
        // consistent at any window resolution.
        float designW = 1280f;
        float designH = 720f;
        float fitScale = Math.min(g.width / designW, g.height / designH);
        float actualTextSize = textSize * fitScale;

        g.textSize(actualTextSize);
        float lineH = actualTextSize * lineSpacing;
        float blockH = lines.length * lineH;
        float startY = cy - blockH * 0.5f + lineH * 0.5f;

        for (int li = 0; li < lines.length; li++) {
            float lineTime = effectiveTime - lineStartTimes[li];
            if (lineTime < 0) continue;

            String line = lines[li];
            if (line.isEmpty()) continue;

            float lineY = startY + li * lineH;

            int lastIdx = Math.max(0, line.length() - 1);
            float fadeInComplete = lastIdx * charGap + charFadeInDuration;

            // Cinematic line-scale: whole line zooms linearly and never stops.
            // Each subsequent line starts at the same scale the previous line had
            // at that moment, creating one continuous camera-push-in effect.
            float baseScale = 0.6f + 0.03f * lineStartTimes[li];
            float lineScale = baseScale + 0.03f * lineTime;

            // ---- Cached character measurements ----
            // textWidth() is expensive and its result only changes when textSize
            // or window dimensions change. Cache to avoid per-frame recomputation.
            boolean needsRemeasure = actualTextSize != lastMeasuredTextSize
                || g.width != lastMeasuredWidth
                || g.height != lastMeasuredHeight;

            if (needsRemeasure) {
                g.textSize(actualTextSize);
                for (int ml = 0; ml < lines.length; ml++) {
                    String mLine = lines[ml];
                    if (mLine.isEmpty()) continue;
                    cachedCharCenterX[ml] = new float[mLine.length()];
                    float totalW = 0;
                    for (int ci = 0; ci < mLine.length(); ci++) {
                        totalW += g.textWidth(mLine.substring(ci, ci + 1));
                    }
                    float offsetX = cx - totalW * 0.5f;
                    float acc = 0;
                    for (int ci = 0; ci < mLine.length(); ci++) {
                        String ch = mLine.substring(ci, ci + 1);
                        float w = g.textWidth(ch);
                        cachedCharCenterX[ml][ci] = offsetX + acc + w * 0.5f;
                        acc += w;
                    }
                }
                lastMeasuredTextSize = actualTextSize;
                lastMeasuredWidth = g.width;
                lastMeasuredHeight = g.height;
            }

            float[] charCenterX = cachedCharCenterX[li];

            g.pushMatrix();
            g.translate(cx, lineY);
            g.scale(lineScale);
            g.translate(-cx, -lineY);

            g.textAlign(PApplet.CENTER, PApplet.CENTER);

            // Draw each character with its own fade-in and fade-out timing
            for (int ci = 0; ci < line.length(); ci++) {
                float charFadeInStart = ci * charGap;
                float charFadeInEnd = charFadeInStart + charFadeInDuration;
                float charFadeOutStart = fadeInComplete + holdDuration + ci * charGap;
                float charFadeOutEnd = charFadeOutStart + charFadeOutDuration;

                float charAlpha;
                if (lineTime < charFadeInStart) {
                    charAlpha = 0f;
                } else if (lineTime < charFadeInEnd) {
                    charAlpha = easeOutQuad((lineTime - charFadeInStart) / charFadeInDuration);
                } else if (lineTime < charFadeOutStart) {
                    charAlpha = 1f;
                } else if (lineTime < charFadeOutEnd) {
                    charAlpha = 1f - easeInQuad((lineTime - charFadeOutStart) / charFadeOutDuration);
                } else {
                    charAlpha = 0f;
                }

                if (charAlpha <= 0.005f) continue;

                float charCx = charCenterX[ci];
                float charCy = lineY;

                String ch = line.substring(ci, ci + 1);

                int a = Math.round(255 * charAlpha);
                int c = (a << 24) | (textColor & 0x00FFFFFF);
                g.fill(c);
                g.text(ch, charCx, charCy);
            }

            g.popMatrix();
        }
    }

    @Override
    public boolean isSkippable() {
        return true;
    }

    @Override
    public void onSkip() {
        skipped = true;
    }

    private float easeOutQuad(float t) {
        return t * (2 - t);
    }

    private float easeInQuad(float t) {
        return t * t;
    }
}
